# Raspberry Pi Setup

Scripts and configurations for setting up the MitM-Pi device on Kali Linux ARM.

## Prerequisites

Before running these scripts, ensure you have:

1. ✅ Kali Linux ARM installed on Raspberry Pi 5
   - See: [Kali Installation Guide](../docs/kali-installation.md)
2. ✅ SSH access to the Pi
3. ✅ Internet connectivity on the Pi (ethernet connected)
4. ✅ Root/sudo access
5. ✅ (Optional) ALFA AWUS1900 driver installed if using external adapter
   - See: [ALFA Driver Installation](../docs/alfa-awus1900-driver.md)
   - Built-in WiFi (wlan0) works fine if you skip this step

## Hardware Requirements

- Raspberry Pi 5 (4GB or 8GB RAM)
- Built-in Ethernet (for upstream connectivity)
- Built-in WiFi OR ALFA AWUS1900 USB adapter (for AP)
- MicroSD card with Kali Linux ARM

## Installation

### Quick Setup

```bash
# Run the automated setup script
sudo ./setup.sh
```

This will:
1. Install required packages (hostapd, dnsmasq, iptables-persistent)
2. Configure network interfaces
3. Set up WiFi Access Point
4. Configure DHCP and DNS services
5. Set up traffic routing to analysis machine
6. Enable IP forwarding
7. Configure firewall rules

**Note:** All changes are persistent and survive reboots. You only need to run this once.

### What Happens on Reboot

After running setup, the Pi will automatically:
- Start WiFi Access Point (hostapd)
- Start DHCP server (dnsmasq)
- Restore iptables routing rules
- Enable IP forwarding
- Configure WiFi interface with static IP

No need to re-run the setup script after rebooting.

### Uninstall / Reset to Normal

To remove the MITM configuration and restore the Pi to normal:

```bash
# Run the uninstall script
sudo ./uninstall.sh
```

This will:
- Stop and disable services
- Remove/backup configuration files
- Clear iptables rules
- Disable IP forwarding
- Reset network interfaces
- Optionally remove installed packages

### Manual Setup

If you prefer to configure manually, follow the steps in:
- [Manual Configuration Guide](../docs/manual-setup.md) *(coming soon)*

## Configuration Files

### `configs/hostapd.conf`
WiFi Access Point configuration
- SSID, password, channel, encryption
- WiFi interface selection

### `configs/dnsmasq.conf`
DHCP and DNS server configuration
- IP address range for connected devices
- DNS settings
- DHCP lease time

### `configs/routing-rules.sh`
Traffic routing and iptables configuration
- Transparent proxy redirection
- NAT configuration
- Traffic forwarding rules

## Network Architecture

```
Internet
   ↑
   | (eth0)
   |
[Raspberry Pi 5 - MitM Device]
   |
   | (wlan0 or wlan1 - WiFi AP)
   |
   ↓
IoT Devices
```

All traffic from IoT devices is routed through the Pi and forwarded to your analysis machine for interception.

## Default Configuration

### WiFi Access Point
- **SSID:** `MitM-Pi`
- **Password:** `changeme123` ⚠️
- **Channel:** 6
- **Encryption:** WPA2-PSK
- **Interface:** Auto-detected (prefers ALFA AWUS1900 if present)

### Network Settings
- **AP Network:** 192.168.100.0/24
- **AP IP:** 192.168.100.1
- **DHCP Range:** 192.168.100.10 - 192.168.100.250

### Analysis Machine
- **Expected IP:** 192.168.50.100 (configure during setup)
- **Proxy Port:** 8080 (configurable)

## Customization

Edit configuration files before running setup:

```bash
# WiFi settings
nano configs/hostapd.conf

# DHCP/DNS settings
nano configs/dnsmasq.conf

# Routing rules
nano configs/routing-rules.sh
```

## Verification

After setup, verify the configuration:

```bash
# Check WiFi AP is running
sudo systemctl status hostapd

# Check DHCP server is running
sudo systemctl status dnsmasq

# Check IP forwarding is enabled
cat /proc/sys/net/ipv4/ip_forward
# Should output: 1

# View network interfaces
ip addr show

# Check iptables rules
sudo iptables -t nat -L -n -v
```

## Troubleshooting

### WiFi AP Not Starting

```bash
# Check hostapd status
sudo systemctl status hostapd
sudo journalctl -u hostapd -n 50

# Verify WiFi interface is not in use
sudo rfkill unblock all
ip link show wlan0  # or wlan1
```

### DHCP Not Working

```bash
# Check dnsmasq status
sudo systemctl status dnsmasq
sudo journalctl -u dnsmasq -n 50

# Verify configuration
dnsmasq --test
```

### Routing Issues

```bash
# Check IP forwarding
sudo sysctl net.ipv4.ip_forward

# View routing table
ip route show
 (backups saved)
- Clear iptables rules
- Disable IP forwarding
- Reset network interfaces
- Optionally remove packages

Backup files are saved as:
- `/etc/hostapd/hostapd.conf.mitm-backup`
- `/etc/dnsmasq.conf.mitm-backup`

Reboot after uninstall to ensure all changes take effect. -n -v
```

## Logs

View system logs for debugging:

```bash
# hostapd logs
sudo journalctl -u hostapd -f

# dnsmasq logs
sudo journalctl -u dnsmasq -f

# System logs
sudo tail -f /var/log/syslog
```

## Uninstall

To remove the MitM configuration:

```bash
sudo ./uninstall.sh
```

This will:
- Stop and disable services
- Remove configuration files
- Restore original network settings
- Remove iptables rules

## Next Steps

After Pi setup is complete:

1. Configure your analysis machine: [Analysis Setup](../analysis-setup/README.md)
2. Set up your proxy tool: [Burp Suite](../docs/burp-setup.md) or [mitmproxy](../docs/mitmproxy-setup.md)
3. Test the setup: [Testing Guide](../docs/testing-guide.md)

---

⚠️ **Remember:** Only use this for authorized testing on devices you own or have permission to test.
