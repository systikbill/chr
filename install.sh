#!/bin/bash
set -e

echo "======================================"
echo "   MikroTik CHR Installer Menu"
echo "======================================"
echo "1. Install (Fresh Base Image)"
echo "2. Uninstall"
echo "3. Cancel"
echo "======================================"
read -p "Select an option [1-3]: " OPTION

if [ "$OPTION" = "2" ]; then
    echo "Uninstalling MikroTik CHR..."
    systemctl stop mikrotik-chr.service || true
    systemctl disable mikrotik-chr.service || true
    rm -f /etc/systemd/system/mikrotik-chr.service
    systemctl daemon-reload
    rm -rf /opt/chr
    rm -f /etc/qemu-ifup
    
    # Remove firewall rules
    iptables -t nat -D POSTROUTING -s 100.64.0.0/24 -j MASQUERADE 2>/dev/null || true
    iptables -t nat -D PREROUTING -p tcp --dport 4443 -j DNAT --to-destination 100.64.0.2:443 2>/dev/null || true
    iptables -t nat -D PREROUTING -p tcp --dport 7001 -j DNAT --to-destination 100.64.0.2:8291 2>/dev/null || true
    iptables -t nat -D PREROUTING -p tcp --dport 7002 -j DNAT --to-destination 100.64.0.2:80 2>/dev/null || true
    netfilter-persistent save || true

    echo "Uninstallation complete!"
    exit 0
elif [ "$OPTION" = "3" ]; then
    echo "Cancelled."
    exit 0
elif [ "$OPTION" != "1" ]; then
    echo "Invalid option. Exiting."
    exit 1
fi

echo "Starting MikroTik CHR Installation..."

# 1. Update and install dependencies
echo "[1/6] Installing dependencies..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y qemu-system-x86 qemu-utils uml-utilities iproute2 iptables iptables-persistent

# 2. Setup CHR Directory and Image
echo "[2/6] Preparing CHR image..."
mkdir -p /opt/chr

if [ -f "chr.qcow2" ]; then
    cp chr.qcow2 /opt/chr/chr.qcow2
else
    echo "Error: chr.qcow2 not found! Make sure you are inside the extracted installer folder."
    exit 1
fi

# 3. Enable IP Forwarding
echo "[3/6] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# 4. Setup qemu-ifup script
echo "[4/6] Configuring TAP network interface..."
cat << 'EOF' > /etc/qemu-ifup
#!/bin/sh
ip link set $1 up
ip addr add 100.64.0.1/24 dev $1
ip route add 10.100.0.0/24 via 100.64.0.2 || true
EOF
chmod +x /etc/qemu-ifup

# 5. Setup Systemd Service
echo "[5/6] Creating and starting the systemd service..."

# Generate a random MAC address so each VPS has a unique MAC
RANDOM_MAC=$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

cat << EOF > /etc/systemd/system/mikrotik-chr.service
[Unit]
Description=MikroTik CHR
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/qemu-system-x86_64 -nographic -m 512M -smp 2 -cpu kvm64 -machine pc -netdev tap,id=n1,ifname=tap0,script=/etc/qemu-ifup,downscript=no -device virtio-net-pci,netdev=n1,mac=$RANDOM_MAC -drive file=/opt/chr/chr.qcow2,if=ide,format=qcow2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mikrotik-chr.service

# 6. Setup IPTables rules
echo "[6/6] Configuring firewall and port forwarding..."
iptables -t nat -D POSTROUTING -s 100.64.0.0/24 -j MASQUERADE 2>/dev/null || true
iptables -t nat -D PREROUTING -p tcp --dport 4443 -j DNAT --to-destination 100.64.0.2:443 2>/dev/null || true
iptables -t nat -D PREROUTING -p tcp --dport 7001 -j DNAT --to-destination 100.64.0.2:8291 2>/dev/null || true
iptables -t nat -D PREROUTING -p tcp --dport 7002 -j DNAT --to-destination 100.64.0.2:80 2>/dev/null || true

iptables -t nat -A POSTROUTING -s 100.64.0.0/24 -j MASQUERADE
iptables -t nat -A PREROUTING -p tcp --dport 4443 -j DNAT --to-destination 100.64.0.2:443
iptables -t nat -A PREROUTING -p tcp --dport 7001 -j DNAT --to-destination 100.64.0.2:8291
iptables -t nat -A PREROUTING -p tcp --dport 7002 -j DNAT --to-destination 100.64.0.2:80

netfilter-persistent save

echo "=================================================="
echo " Installation Complete! "
echo " MikroTik CHR is running securely in the background."
echo " Please check README.md for manual setup commands."
echo "=================================================="
