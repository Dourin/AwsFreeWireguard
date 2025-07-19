#!/bin/bash

# Update system and wait for lock
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install WireGuard and QR code tools (with automatic responses)
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
apt-get install -y wireguard wireguard-tools qrencode iptables-persistent

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

# Detect the main network interface
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Detected main interface: $MAIN_INTERFACE"

# Generate proper server and client keys
cd /home/ubuntu

# Generate server keys
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)
echo "$SERVER_PRIVATE_KEY" > server_private.key
echo "$SERVER_PUBLIC_KEY" > server_public.key
chmod 600 server_private.key

# Get public IP using multiple methods
SERVER_IP=""
# Try AWS metadata service first
SERVER_IP=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
# If metadata service fails, try external service
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
fi
# If both fail, try another external service
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -s --max-time 5 https://checkip.amazonaws.com 2>/dev/null | tr -d '\n')
fi

echo "Server public IP: $SERVER_IP"

# If we still don't have an IP, we'll fix it later in the correction script
if [ -z "$SERVER_IP" ]; then
    echo "Warning: Could not determine public IP, will be corrected later"
    SERVER_IP="PLACEHOLDER_IP"
fi

# Generate client keys and configurations with corrected subnet
for i in {1..5}; do
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
    CLIENT_IP="192.168.100.$((i+1))"
    
    echo "$CLIENT_PRIVATE_KEY" > client${i}_private.key
    echo "$CLIENT_PUBLIC_KEY" > client${i}_public.key
    chmod 600 client${i}_private.key
done

# Create WireGuard server configuration with dedicated subnet
cat > /etc/wireguard/wg0.conf << WGCONF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 192.168.100.1/24
ListenPort = 51820
PostUp = iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o $MAIN_INTERFACE -j MASQUERADE; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; ip route del 192.168.100.0/24 via $(ip route | grep default | awk '{print $3}') dev $MAIN_INTERFACE 2>/dev/null || true
PostDown = iptables -t nat -D POSTROUTING -s 192.168.100.0/24 -o $MAIN_INTERFACE -j MASQUERADE; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT

WGCONF

# Add client peers to server config
for i in {1..5}; do
    CLIENT_PUBLIC_KEY=$(cat client${i}_public.key)
    cat >> /etc/wireguard/wg0.conf << WGPEER

# Client $i
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = 192.168.100.$((i+1))/32

WGPEER
done

# Set proper permissions
chmod 600 /etc/wireguard/wg0.conf

# Start and enable WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Clean up any conflicting routes that might have been added by DHCP
sleep 5
ip route del 10.0.0.0/24 via $(ip route | grep default | awk '{print $3}') dev $MAIN_INTERFACE 2>/dev/null || true
ip route del 10.0.0.2 via $(ip route | grep default | awk '{print $3}') dev $MAIN_INTERFACE 2>/dev/null || true

# Verify service started correctly, if not, apply manual fix
sleep 5
if ! systemctl is-active wg-quick@wg0 >/dev/null 2>&1; then
    echo "WireGuard failed to start, applying manual configuration..." >> /home/ubuntu/setup.log
    
    # Stop the service and clean configuration
    systemctl stop wg-quick@wg0 >/dev/null 2>&1
    
    # Create a simpler configuration file with corrected subnet
    cat > /etc/wireguard/wg0.conf << WGFIX
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 192.168.100.1/24
ListenPort = 51820
PostUp = iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o $MAIN_INTERFACE -j MASQUERADE; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; ip route del 192.168.100.0/24 via $(ip route | grep default | awk '{print $3}') dev $MAIN_INTERFACE 2>/dev/null || true
PostDown = iptables -t nat -D POSTROUTING -s 192.168.100.0/24 -o $MAIN_INTERFACE -j MASQUERADE; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT

WGFIX

    # Add peers again with corrected subnet
    for i in {1..5}; do
        CLIENT_PUBLIC_KEY=$(cat client${i}_public.key)
        cat >> /etc/wireguard/wg0.conf << WGFIX

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = 192.168.100.$((i+1))/32

WGFIX
    done
    
    chmod 600 /etc/wireguard/wg0.conf
    systemctl start wg-quick@wg0
fi

# Create client configuration files with proper settings and corrected subnet
for i in {1..5}; do
    CLIENT_PRIVATE_KEY=$(cat client${i}_private.key)
    CLIENT_IP="192.168.100.$((i+1))"
    
    cat > client${i}.conf << CLIENTCONF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CLIENTCONF

    # Generate QR codes
    qrencode -t ansiutf8 < client${i}.conf > client${i}_qr.txt 2>/dev/null || echo "QR generation failed for client $i" >> setup.log
    qrencode -t png -o client${i}_qr.png < client${i}.conf 2>/dev/null || echo "PNG QR generation failed for client $i" >> setup.log
done

# Set ownership
chown -R ubuntu:ubuntu /home/ubuntu/

# Create enhanced status script
cat > /home/ubuntu/vpn_status.sh << 'EOF'
#!/bin/bash
echo "=== WireGuard VPN Status ==="
echo "Server Status:"
systemctl status wg-quick@wg0 --no-pager
echo ""
echo "Connected Clients:"
sudo wg show
echo ""
echo "Server Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Client configs available in /home/ubuntu/"
ls -la /home/ubuntu/*.conf 2>/dev/null || echo "No client configs found"
echo ""
echo "QR codes available in /home/ubuntu/"
ls -la /home/ubuntu/*_qr.* 2>/dev/null || echo "No QR codes found"
echo ""
echo "Network interfaces:"
ip addr show wg0 2>/dev/null || echo "wg0 interface not found"
echo ""
echo "Routing table:"
ip route | grep -E "(wg0|default)"
echo ""
echo "IPTables NAT rules:"
sudo iptables -t nat -L POSTROUTING -n | head -10
EOF

chmod +x /home/ubuntu/vpn_status.sh
chown ubuntu:ubuntu /home/ubuntu/vpn_status.sh

# Create simple restart script
cat > /home/ubuntu/restart_vpn.sh << 'EOF'
#!/bin/bash
echo "Restarting WireGuard VPN..."
sudo systemctl restart wg-quick@wg0
echo "VPN restarted. Status:"
sudo systemctl status wg-quick@wg0 --no-pager
EOF

chmod +x /home/ubuntu/restart_vpn.sh
chown ubuntu:ubuntu /home/ubuntu/restart_vpn.sh

# Signal completion
touch /home/ubuntu/setup_complete
echo "WireGuard VPN setup completed at $(date)" > /home/ubuntu/setup.log
