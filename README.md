# MikroTik CHR Installer

Runs a MikroTik Cloud Hosted Router (CHR) inside a Debian VPS using QEMU. Handles everything automatically: QEMU setup, TAP interface, IP forwarding, NAT rules, and a systemd background service.

## Install

```bash
chmod +x install.sh
./install.sh
```

Select **Option 1** to install, **Option 2** to uninstall.

## Post-Install Setup

The CHR boots with a blank image — no IP configured yet. You need to access the console once to set it up.

### Step 1: Open the Console

```bash
systemctl stop mikrotik-chr.service
eval $(grep ExecStart /etc/systemd/system/mikrotik-chr.service | cut -d '=' -f 2-)
```

Wait for it to boot, then login as `admin` with a blank password.

### Step 2: Configure RouterOS

#### MUST RUN (run this first)
```routeros
/ip address add address=100.64.0.2/24 interface=ether1
/interface ethernet set ether1 arp=proxy-arp
/ip route add dst-address=0.0.0.0/0 gateway=100.64.0.1
```

#### SERVER Commands
```routeros
/ip pool add name=sstp-pool ranges=10.100.0.10-10.100.0.254
/ppp profile add name=sstp-profile local-address=10.100.0.1 remote-address=sstp-pool use-encryption=yes dns-server=8.8.8.8,8.8.4.4
/interface sstp-server server set enabled=yes default-profile=sstp-profile port=443 certificate=none authentication=mschap2
/ppp secret add name=testuser password=testpass profile=sstp-profile service=sstp
/ip firewall nat add chain=srcnat dst-address=10.100.0.0/24 action=masquerade
```

<!--
#### CLIENT Commands
```routeros
/interface sstp-client add connect-to=SERVER_IP disabled=no name=sstp-out1 port=4443 profile=default-encryption user=testuser password=testpass verify-server-certificate=no
```
-->

### Step 3: Exit & Restart

Press `Ctrl + A` then `X` to exit the console, then:

```bash
systemctl start mikrotik-chr.service
```

CHR is now running in the background. Manage it via Winbox on port `7001` or WebFig on port `7002`.

## Port Mapping

| External Port | Service         |
|---------------|-----------------|
| 4443          | SSTP VPN        |
| 7001          | Winbox          |
| 7002          | WebFig          |
