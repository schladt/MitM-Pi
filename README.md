# MitM-Pi

A transparent Man-in-the-Middle (MITM) device for IoT penetration testing using Raspberry Pi 5.

## ⚠️ Legal Disclaimer

This tool is designed for **authorized security testing only**. Only use this device to test IoT devices that you own or have explicit written permission to test. Unauthorized interception of network traffic is illegal in most jurisdictions.

## Overview

MitM-Pi transforms a Raspberry Pi 5 into a transparent MITM proxy for analyzing and testing IoT device security. IoT devices connect to a WiFi access point hosted on the Pi, and traffic can be either:

1. **Active Mode (Default):** Routed to a proxy interceptor (Burp Suite, mitmproxy) on your analysis machine for decryption and modification
2. **Passive Mode:** All traffic monitored directly on the Pi for encrypted traffic analysis without decryption

### Key Features

- 🔒 **Transparent Operation** - IoT devices connect normally with no proxy configuration required
- 🎭 **Dual Operating Modes** - Active MITM with proxy OR passive monitoring without decryption
- 📡 **Multiple Network Interfaces** - Built-in ethernet, WiFi, and support for ALFA AWUS1900 USB adapter
- 🖥️ **Multi-Platform Analysis** - Supports macOS and Linux analysis machines
- 🔍 **Flexible Proxy Support** - Works with Burp Suite, mitmproxy, and other intercepting proxies
- 📦 **Packet Capture** - Built-in traffic capture scripts with multiple modes
- 🔐 **Security Analysis** - mitmproxy addon for detecting sensitive data leaks (API keys, tokens, passwords)
- 🚀 **Easy Setup** - Automated scripts for both Pi and analysis machine configuration
- 📱 **Mobile Device Support** - Certificate installation guides for Android devices

## Architecture

### Active Mode (Default)
```
IoT Device (WiFi) 
    ↓
Raspberry Pi 5 (WiFi AP)
    ↓ (HTTP/HTTPS redirect)
Analysis Machine (Ethernet) ← Burp Suite/mitmproxy
    ↓
Internet
```

### Passive Mode
```
IoT Device (WiFi) 
    ↓
Raspberry Pi 5 (WiFi AP + tcpdump)
    ↓ (NAT only, no redirect)
Internet
```

The Raspberry Pi 5 acts as a WiFi access point. In **active mode**, HTTP/HTTPS traffic is transparently forwarded to your analysis machine for interception. In **passive mode**, all traffic is routed normally while being monitored on the Pi (ideal for encrypted protocols like MQTT over TLS).

## Hardware Requirements

### Raspberry Pi 5 Setup
- Raspberry Pi 5 (4GB or 8GB recommended)
- MicroSD card (32GB+ recommended)
- Power supply (official RPi 5 power supply recommended)
- Ethernet cable
- **Optional but recommended:** ALFA AWUS1900 USB WiFi adapter (for better AP performance and monitor mode support)

### Analysis Machine
- macOS or Ubuntu Linux computer
- Ethernet connection to same network as Raspberry Pi
- Sufficient storage for packet captures

## Software Requirements

### Raspberry Pi
- Raspberry Pi OS (installation script provided)
- hostapd (WiFi AP daemon)
- dnsmasq (DHCP/DNS server)
- iptables (traffic routing)

### Analysis Machine
- Burp Suite (Community or Pro)
- OR mitmproxy
- OR other HTTP/HTTPS intercepting proxy
- tcpdump or Wireshark (for packet capture)

## Quick Start

### 0. Install Kali Linux on Raspberry Pi 5

📖 **Start here:** [Kali Linux Installation Guide](docs/kali-installation.md)

This comprehensive guide covers:
- Downloading and flashing Kali ARM image
- Headless setup via SSH
- Finding the Pi's IP address on your network
- Initial configuration and security hardening

**Quick connection:** `ssh kali@kali-raspberrypi`

### 1. Raspberry Pi Setup

After Kali is installed and you have SSH access:

```bash
# Clone this repository on your analysis machine
git clone https://github.com/schladt/MitM-Pi.git
cd MitM-Pi

# Copy setup scripts to the Pi
scp -r pi-setup/ kali@kali-raspberrypi:~/

# SSH to the Pi and run setup
ssh kali@kali-raspberrypi
cd ~/pi-setup

# Active mode (default) - with proxy redirection
sudo ./setup.sh

# OR: Passive mode - monitoring only, no proxy
sudo ./setup.sh --passive
```

### 2. Analysis Machine Setup

**For macOS:**
```bash
./analysis-setup/setup-macos.sh
```

**For Ubuntu:**
```bash
sudo ./analysis-setup/setup-ubuntu.sh
```

### 3. Configure Proxy

Follow the proxy-specific guides in the `docs/` directory:
- [Burp Suite Configuration](docs/burp-setup.md)
- [mitmproxy Configuration](docs/mitmproxy-setup.md)

### 4. Connect IoT Device

1. Power on your Raspberry Pi
2. Connect your IoT device to the WiFi AP (SSID: `MitM-Pi`, password: `changeme123`)
3. Start capturing traffic in your proxy tool
4. Interact with your IoT device

### 5. Install Certificate on Mobile Devices (Optional)

For testing mobile apps, install the proxy CA certificate:

```bash
# Automated installation for Android
cd analysis-setup
./install-burp-cert-android.sh
```

See [docs/android-certificate-install.md](docs/android-certificate-install.md) for complete instructions.

## Traffic Capture

### Capture Network Traffic

```bash
# Capture encrypted traffic between analysis machine and Pi
cd analysis-setup
./capture-traffic.sh network

# Capture proxy processing on loopback
./capture-traffic.sh proxy

# Capture both simultaneously
./capture-traffic.sh both
```

Captures are saved to `~/Desktop/mitm-captures/` and can be analyzed in Wireshark.

### Capture with mitmproxy (Recommended for Automation)

```bash
# Install mitmproxy
brew install mitmproxy  # macOS
# or: sudo apt install mitmproxy  # Linux

# Start capture with web interface (default)
cd analysis-setup
./capture-mitmproxy.sh

# Web interface automatically opens at: http://localhost:8081

# With security analysis (detects API keys, passwords, tokens)
./capture-mitmproxy.sh -s

# Console/headless mode (for automation)
./capture-mitmproxy.sh -c
```

Flows are saved in multiple formats:
- `.dump` - mitmproxy native format
- `.har` - HTTP Archive (standard)
- `_security.json` - Security findings (if `-s` used)

View saved flows:
```bash
mitmweb -r ~/Desktop/mitm-captures/flows-*.dump
```

## Project Structure

```
MitM-Pi/
├── README.md
├── .gitignore
├── pi-setup/                          # Raspberry Pi setup scripts and configs
│   ├── setup.sh                       # Automated Pi configuration (supports --passive)
│   ├── uninstall.sh                   # Reset Pi to normal configuration
│   └── configs/
│       ├── hostapd.conf              # WiFi AP configuration
│       ├── dnsmasq.conf              # DHCP/DNS configuration
│       ├── routing-rules.sh          # Active mode: HTTP/HTTPS proxy redirection
│       └── routing-rules-passive.sh  # Passive mode: NAT only, no proxy
├── analysis-setup/                    # Analysis machine scripts
│   ├── install-burp-cert-android.sh  # Android certificate installer
│   ├── capture-traffic.sh            # Packet capture (network/proxy modes)
│   └── capture-mitmproxy.sh          # mitmproxy with security analysis
├── docs/                              # Documentation
│   ├── kali-installation.md          # Complete Kali ARM setup guide
│   ├── alfa-awus1900-driver.md       # ALFA WiFi adapter driver installation
│   ├── burp-setup.md                 # Burp Suite configuration
│   ├── mitmproxy-setup.md            # mitmproxy setup and usage
│   ├── android-certificate-install.md # Android cert installation methods
│   └── testing-guide.md              # Testing procedures and test URLs
└── examples/                          # Example configurations (future)
```

## Configuration

### WiFi Access Point

The default configuration creates a WiFi AP with:
- **SSID:** `MitM-Pi`
- **Password:** `changeme123` (⚠️ **Change this in production!**)
- **IP Range:** 192.168.100.1/24
- **Channel:** 6 (2.4GHz)

Edit `pi-setup/configs/hostapd.conf` to customize.

### Operating Modes

**Active Mode (Default):**
- HTTP (port 80) and HTTPS (port 443) redirected to analysis machine proxy on port 8080
- Requires running proxy (Burp Suite, mitmproxy) on analysis machine
- Best for: Mobile apps, web traffic, HTTP-based IoT devices
- Setup: `sudo ./setup.sh`

**Passive Mode:**
- All traffic routed through NAT without proxy redirection
- Traffic monitored directly on Pi using tcpdump
- Best for: Encrypted protocols (MQTT over TLS), traffic analysis, connection patterns
- Setup: `sudo ./setup.sh --passive`
- Monitor traffic: `ssh kali@kali-raspberrypi "sudo tcpdump -i wlan1 -w /tmp/capture.pcap"`

Edit `pi-setup/configs/routing-rules.sh` or `routing-rules-passive.sh` to customize routing behavior.

## Documentation

Complete guides available in the `docs/` directory:

- **[Kali Installation](docs/kali-installation.md)** - Complete headless Kali ARM setup for RPi5
- **[ALFA AWUS1900 Driver](docs/alfa-awus1900-driver.md)** - WiFi adapter driver installation
- **[Burp Suite Setup](docs/burp-setup.md)** - Burp configuration for transparent proxying
- **[mitmproxy Setup](docs/mitmproxy-setup.md)** - mitmproxy installation, scripting, and automation
- **[Android Certificates](docs/android-certificate-install.md)** - User and system certificate installation
- **[Android Rooting Strategy](docs/android-rooting-strategy.md)** - Comprehensive guide for LineageOS/custom ROM setup for system certificates
- **[Testing Guide](docs/testing-guide.md)** - Test procedures and validation

## Known Limitations

- **Certificate Pinning:** Apps with strict certificate pinning require system-level certificate installation
  - User-level certificates work for most apps (browsers, many IoT apps)
  - System-level installation on modern Android (14+) requires custom ROM with root access
  - **Recommended:** Use LineageOS with root add-on for reliable system certificate support
  - See [Android Rooting Strategy](docs/android-rooting-strategy.md) for comprehensive device setup guide
  - See [Android Certificates](docs/android-certificate-install.md) for installation methods
- **Mutual TLS:** Client certificate authentication may not work in all scenarios
- **UDP Traffic:** Currently focused on TCP/HTTP/HTTPS traffic
- **Performance:** Not designed for high-bandwidth streaming; suitable for IoT device analysis

## Troubleshooting

**Common Issues:**

- **"Can't find Pi on network"** - Use `arp-scan` or check your router's DHCP leases
- **"WiFi AP not appearing"** - Check if ALFA driver is installed correctly with `iwconfig`
- **"No traffic in proxy"** - Verify routing rules with `sudo iptables -t nat -L -n -v`
- **"HTTPS errors"** - Ensure proxy CA certificate is installed on test device

For detailed troubleshooting, see the documentation in the `docs/` directory.

## Contributing

Contributions are welcome! Please open an issue or pull request for:
- Bug fixes
- New features
- Documentation improvements
- Additional proxy tool integrations
- New capture modes or analysis scripts

## References and Inspiration

This project builds upon excellent work by the security research community:
- [Pi-MITM by Gareth](https://www.gareth.co.uk/pi-mitm/)
- [YouTube: IoT MITM Setup](https://www.youtube.com/watch?v=e6yvNJnGRM8)
- [mitmproxy Project](https://mitmproxy.org/)
- [PortSwigger Burp Suite](https://portswigger.net/burp)

## License

MIT License - See LICENSE file for details.

This project is provided for educational and authorized security testing purposes only.

## Acknowledgments

- Raspberry Pi Foundation
- PortSwigger (Burp Suite)
- mitmproxy project
- The security research and ethical hacking community
- ALFA Network (AWUS1900 USB WiFi adapter)

---

**⚠️ Important:** Only use this tool on devices and networks you own or have explicit written permission to test. Unauthorized interception of network traffic may be illegal in your jurisdiction. Always follow responsible disclosure practices.

**Happy (ethical) hacking! 🔐**
