# MikroTik CHR QEMU Installer

A lightweight, automated installer for deploying a fresh MikroTik Cloud Hosted Router (CHR) inside a Debian VPS using QEMU/KVM. 

This installer strictly focuses on the Debian host configuration. It automatically installs QEMU, configures the `tap0` virtual interface, sets up IP Forwarding, creates all IPTables NAT rules (for VPN, Winbox, and WebFig), and sets up the background systemd service.

## Installation

1. Run the installer script:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
2. Select **Option 1 (Install)**.
3. The script will deploy the base MikroTik image (`chr.qcow2`), generate a unique random MAC address, and start it in the background as `mikrotik-chr.service`.

## Manual Configuration Guide (Post-Install)

Because this uses a completely fresh, blank MikroTik image, it will **not** have an IP address assigned yet. You must temporarily access the QEMU console to configure the initial IP address and VPN settings.

### Step 1: Access the Console
Stop the background service and run QEMU in the foreground to access the MikroTik console:

```bash
# Stop the background service
systemctl stop mikrotik-chr.service

# Start QEMU in the foreground using your server's unique random MAC address!
eval $(grep ExecStart /etc/systemd/system/mikrotik-chr.service | cut -d '=' -f 2-)
```
*(Wait a few seconds for it to boot. Login as `admin` with a blank password).*

### Step 2: Apply the Network & VPN Configuration
Once logged into the RouterOS terminal, apply the necessary configurations based on whether this is a Server or a Client.

#### 1. MUST RUN (Both Client & Server)
```routeros
# Assign Internal IP Address
/ip address add address=100.64.0.2/24 interface=etherX
/interface ethernet set etherX arp=proxy-arp
/ip route add dst-address=0.0.0.0/0 gateway=100.64.0.1
```

#### 2. SERVER ONLY Commands
```routeros
# Setup SSTP VPN Pool and Profile
/ip pool add name=sstp-pool ranges=10.100.0.10-10.100.0.254
/ppp profile add name=sstp-profile local-address=10.100.0.1 remote-address=sstp-pool use-encryption=yes dns-server=8.8.8.8,8.8.4.4

# Enable SSTP Server
/interface sstp-server server set enabled=yes default-profile=sstp-profile port=443 certificate=none authentication=mschap2

# Add a test user
/ppp secret add name=testuser password=testpass profile=sstp-profile service=sstp

# Add NAT masquerade rule
/ip firewall nat add chain=srcnat dst-address=10.100.0.0/24 action=masquerade
```

<!--
#### 3. CLIENT ONLY Commands
```routeros
# Connect to the SSTP Server (Replace SERVER_IP with the actual Server IP)
/interface sstp-client add connect-to=SERVER_IP disabled=no name=sstp-out1 port=4443 profile=default-encryption user=testuser password=testpass verify-server-certificate=no
```
-->

### Step 3: Exit and Restart the Background Service
After configuring RouterOS:
1. Press `Ctrl + A`, release, then press `X` to exit the QEMU console.
2. Start the background service again:
   ```bash
   systemctl start mikrotik-chr.service
   ```

Your Mikrotik CHR is now fully configured and running securely in the background! You can now manage it remotely via Winbox on port `7001` or WebFig on port `7002`.
