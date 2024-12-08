#!/bin/bash
set -e

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Extract network from CIDR
if [ -n "$SERVER_CIDR" ]; then
    NETWORK=$(echo $SERVER_CIDR | cut -d'/' -f1 | cut -d'.' -f1-3)".0/24"
else
    NETWORK=$(echo $CLIENT_CIDR | cut -d'/' -f1 | cut -d'.' -f1-3)".0/24"
fi

# Flush existing rules
iptables -F
iptables -t nat -F
iptables -t mangle -F

# Set default policies
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Enable NAT
iptables -t nat -A POSTROUTING -s $NETWORK ! -d $NETWORK -j MASQUERADE

# Allow established connections
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow TUN interface traffic
iptables -A FORWARD -i tun0 -j ACCEPT
iptables -A FORWARD -o tun0 -j ACCEPT

# Run the go-vpn application
exec /app/go-vpn "$@"