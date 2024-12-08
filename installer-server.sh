#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo bash script.sh)"
    exit 1
fi

# Check if system is Linux x64
if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "This installer only supports Linux x64 systems"
    exit 1
fi

# Function to get latest release version
get_latest_version() {
    curl -s https://api.github.com/repos/ariadata/go-vpn/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Stop existing service if running
if systemctl is-active --quiet go-vpn-server; then
    echo "Stopping existing VPN server service..."
    systemctl stop go-vpn-server
    sleep 2  # Wait for the service to fully stop
fi

# Download and install VPN server
echo "Downloading latest Go VPN Server..."
LATEST_VERSION=$(get_latest_version)
rm -f /usr/local/bin/go-vpn-server  # Remove existing binary
wget -O /usr/local/bin/go-vpn-server "https://github.com/ariadata/go-vpn/releases/download/${LATEST_VERSION}/go-vpn"
chmod +x /usr/local/bin/go-vpn-server

# Get user input
read -p "Enter server mapped port: " PORT
read -p "Enter server CIDR (like 172.18.0.1/24): " CIDR
read -p "Enter Secret Key: " SECRET

# Stop and remove existing service if it exists
if systemctl is-enabled --quiet go-vpn-server; then
    systemctl disable go-vpn-server
fi
rm -f /etc/systemd/system/go-vpn-server.service

# Create systemd service
cat > /etc/systemd/system/go-vpn-server.service << EOF
[Unit]
Description=Go VPN Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/go-vpn-server -S -l=:${PORT} -c=${CIDR} -k=${SECRET} -p=udp
Restart=always
RestartSec=5
WorkingDirectory=/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/99-ip-forward.conf
sysctl -p /etc/sysctl.d/99-ip-forward.conf

# Get the default network interface
DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}')
echo "Detected default interface: ${DEFAULT_IFACE}"

# Configure iptables
# Backup existing rules
iptables-save > /root/iptables-backup-$(date +%Y%m%d-%H%M%S)

# Add NAT rules
echo "Setting up iptables rules..."
# iptables -t nat -A POSTROUTING -s ${CIDR%/*}/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -s ${CIDR%/*}/24 -o ${DEFAULT_IFACE} -j MASQUERADE
iptables -A FORWARD -s ${CIDR%/*}/24 -j ACCEPT
iptables -A FORWARD -d ${CIDR%/*}/24 -j ACCEPT

# Make iptables rules persistent
if command -v iptables-persistent &> /dev/null; then
    iptables-save > /etc/iptables/rules.v4
else
    apt-get update && apt-get install -y iptables-persistent
    iptables-save > /etc/iptables/rules.v4
fi

# Start service
systemctl daemon-reload
systemctl enable go-vpn-server
systemctl start go-vpn-server

# Check status
if systemctl is-active --quiet go-vpn-server; then
    echo "VPN Server is running successfully!"
    echo "Use the following commands to manage the service:"
    echo "systemctl start go-vpn-server   - Start the server"
    echo "systemctl stop go-vpn-server    - Stop the server"
    echo "systemctl restart go-vpn-server - Restart the server"
    echo "systemctl status go-vpn-server  - Check server status"
else
    echo "Error: VPN Server failed to start. Check status with: systemctl status go-vpn-server"
    exit 1
fi