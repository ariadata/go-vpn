#!/bin/bash

# Check for required environment variables
if [ -z "$SERVER_IP" ] || [ -z "$CLIENT_CIDR" ] || [ -z "$SHARED_KEY" ]; then
    echo "Error: Required environment variables are not set"
    echo "Required: SERVER_IP, CLIENT_CIDR, SHARED_KEY"
    exit 1
fi

# Auto-detect default interface if not set
if [ -z "$INTERFACE" ]; then
    INTERFACE=$(ip route | grep default | awk '{print $5}')
    if [ -z "$INTERFACE" ]; then
        echo "Error: Could not detect default interface"
        exit 1
    fi
fi
echo "Using network interface: $INTERFACE"

# Setup iptables rules
echo "Setting up iptables rules..."

# Get network prefix from CLIENT_CIDR
NETWORK_PREFIX=$(echo ${CLIENT_CIDR} | cut -d'/' -f1 | cut -d'.' -f1-3)

# Configure iptables
iptables -t nat -A POSTROUTING -s ${NETWORK_PREFIX}.0/24 -o ${INTERFACE} -j MASQUERADE
iptables -A FORWARD -s ${NETWORK_PREFIX}.0/24 -j ACCEPT
iptables -A FORWARD -d ${NETWORK_PREFIX}.0/24 -j ACCEPT

# Start the VPN client
echo "Starting VPN client..."
exec /app/go-vpn \
    -l=:47401 \
    -s="${SERVER_IP}:${SERVER_PORT}" \
    -c="${CLIENT_CIDR}" \
    -k="${SHARED_KEY}" \
    -p=udp
