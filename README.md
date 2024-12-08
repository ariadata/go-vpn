# Go VPN

A simple VPN server and client based on Go, featuring easy installation and systemd service management.

## Quick Install

### Server Side
```bash
bash <(curl -sSL https://raw.githubusercontent.com/ariadata/go-vpn/main/installer-server.sh)
```

The server installer will:
- Check system requirements (Linux x64 + root access)
- Install the latest version of VPN server
- Configure as a systemd service
- Set up IP forwarding and iptables rules
- Start the service automatically

### Client Side
```bash
bash <(curl -sSL https://raw.githubusercontent.com/ariadata/go-vpn/main/installer-client.sh)

# for whole system :
ip route add {VPN_SERVER_PUBLIC_IP} via {DEFAULT_GATEWAY} dev eth0
### example : ip route add 78.58.16.221 via 192.168.100.1 dev eth0
ip route del default
ip route add default via {VPN_SERVER_PRIVATE_IP} dev go-vpn
### example : ip route add default via 172.18.0.1 dev go-vpn
iptables -t nat -A POSTROUTING -o go-vpn -j MASQUERADE
iptables-save > /etc/iptables/rules.v4
netfilter-persistant save

```

The client installer will:
- Check system requirements (Linux x64 + root access)
- Install the latest version of VPN client
- Configure as a systemd service
- Set up required iptables rules
- Start the service automatically
- Test the connection

## Service Management

### Server Commands
```bash
systemctl start go-vpn-server    # Start the server
systemctl stop go-vpn-server     # Stop the server
systemctl restart go-vpn-server  # Restart the server
systemctl status go-vpn-server   # Check server status
```

### Client Commands
```bash
systemctl start go-vpn-client    # Start the client
systemctl stop go-vpn-client     # Stop the client
systemctl restart go-vpn-client  # Restart the client
systemctl status go-vpn-client   # Check client status
```

## Testing VPN Connection

After installing the client, you can test the connection using these commands:

### Ping Test
```bash
# Ping the VPN gateway (if your VPN CIDR is 172.18.0.10/24, this pings 172.18.0.1)
ping 172.18.0.1

# Ping other hosts in your VPN network
ping 172.18.0.2
```

### Check Your IP
```bash
# Check your IP through the VPN interface
curl --interface go-vpn myip4.ir

# Compare with your regular IP
curl myip4.ir
```

## Requirements
- Linux x64 system
- Root access
- systemd
- iptables

## Features
- Automated installation
- systemd service management
- Persistent iptables rules
- Automatic IP forwarding
- Connection testing
- Service auto-restart on failure

## Uninstallation
To completely remove the VPN server or client:

### Server
```bash
systemctl stop go-vpn-server
systemctl disable go-vpn-server
rm /etc/systemd/system/go-vpn-server.service
rm /usr/local/bin/go-vpn-server
systemctl daemon-reload
```

### Client
```bash
systemctl stop go-vpn-client
systemctl disable go-vpn-client
rm /etc/systemd/system/go-vpn-client.service
rm /usr/local/bin/go-vpn-client
systemctl daemon-reload
```

## License
MIT