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
if systemctl is-active --quiet go-vpn-client; then
    echo "Stopping existing VPN client service..."
    systemctl stop go-vpn-client
    sleep 2  # Wait for the service to fully stop
fi

# Download and install VPN client
echo "Downloading latest Go VPN Client..."
LATEST_VERSION=$(get_latest_version)
rm -f /usr/local/bin/go-vpn-client  # Remove existing binary
wget -O /usr/local/bin/go-vpn-client "https://github.com/ariadata/go-vpn/releases/download/${LATEST_VERSION}/go-vpn"
chmod +x /usr/local/bin/go-vpn-client

# Get user input
read -p "Enter VPN server IP address: " SERVER_IP
read -p "Enter VPN server port: " SERVER_PORT
read -p "Enter client IP with CIDR (like 172.18.0.10/24): " CLIENT_CIDR
read -p "Enter Secret Key: " SECRET

# Stop and remove existing service if it exists
if systemctl is-enabled --quiet go-vpn-client; then
    systemctl disable go-vpn-client
fi
rm -f /etc/systemd/system/go-vpn-client.service

# Create systemd service
cat > /etc/systemd/system/go-vpn-client.service << EOF
[Unit]
Description=Go VPN Client
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/go-vpn-client -l=:47401 -s=${SERVER_IP}:${SERVER_PORT} -c=${CLIENT_CIDR} -k=${SECRET} -p=udp
Restart=always
RestartSec=5
WorkingDirectory=/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF

# Get the default network interface
DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}')
echo "Detected default interface: ${DEFAULT_IFACE}"

# Configure iptables
# Save current iptables rules
iptables-save > /root/iptables-backup-$(date +%Y%m%d-%H%M%S)

# Add NAT rules
echo "Setting up iptables rules..."
# iptables -t nat -A POSTROUTING -s ${CLIENT_CIDR%/*}/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -s ${CLIENT_CIDR%/*}/24 -o ${DEFAULT_IFACE} -j MASQUERADE
iptables -A FORWARD -s ${CLIENT_CIDR%/*}/24 -j ACCEPT
iptables -A FORWARD -d ${CLIENT_CIDR%/*}/24 -j ACCEPT

# Make iptables rules persistent
if command -v iptables-persistent &> /dev/null; then
    iptables-save > /etc/iptables/rules.v4
else
    apt-get update && apt-get install -y iptables-persistent
    iptables-save > /etc/iptables/rules.v4
fi

# Start service
systemctl daemon-reload
systemctl enable go-vpn-client
systemctl start go-vpn-client

# Check status
if systemctl is-active --quiet go-vpn-client; then
    echo "VPN Client is running successfully!"
    echo "Use the following commands to manage the service:"
    echo "systemctl start go-vpn-client   - Start the client"
    echo "systemctl stop go-vpn-client    - Stop the client"
    echo "systemctl restart go-vpn-client - Restart the client"
    echo "systemctl status go-vpn-client  - Check client status"
else
    echo "Error: VPN Client failed to start. Check status with: systemctl status go-vpn-client"
    exit 1
fi

# Extract the network part of the CIDR and calculate the first usable IP
NETWORK_PREFIX=$(echo ${CLIENT_CIDR} | cut -d'.' -f1-3)
GATEWAY_IP="${NETWORK_PREFIX}.1"

# Wait a few seconds for the VPN connection to establish
echo "Waiting for VPN connection to establish..."
sleep 5

# Perform ping test to the gateway IP (first IP in the subnet)
echo "Testing connection to VPN gateway (${GATEWAY_IP})..."
for i in {1..4}; do
    echo "Ping test $i of 4:"
    ping -c 1 ${GATEWAY_IP}
    sleep 1
done