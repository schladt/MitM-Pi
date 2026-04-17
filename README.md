# MitM-Pi

A transparent Man-in-the-Middle (MITM) device for IoT penetration testing using Raspberry Pi 5.

## ⚠️ Legal Disclaimer

This tool is designed for **authorized security testing only**. Only use this device to test IoT devices that you own or have explicit written permission to test. Unauthorized interception of network traffic is illegal in most jurisdictions.

## Overview

MitM-Pi transforms a Raspberry Pi 5 into a transparent MITM proxy for analyzing and testing IoT device security. IoT devices connect to a WiFi access point hosted on the Pi, and all traffic is automatically routed to a proxy interceptor (Burp Suite, mitmproxy, etc.) running on your analysis machine.

### Key Features

- 🔒 **Transparent Operation** - IoT devices connect normally with minimal configuration
- 📡 **Multiple Network Interfaces** - Built-in ethernet, WiFi, and support for ALFA AWUS1900 USB adapter
- 🖥️ **Multi-Platform Analysis** - Supports macOS and Ubuntu Linux analysis machines
- 🔍 **Flexible Proxy Support** - Works with Burp Suite, mitmproxy, and other intercepting proxies
- 📦 **Packet Capture** - Built-in traffic capture capabilities
- 🚀 **Easy Setup** - Automated scripts for both Pi and analysis machine configuration

## Architecture

```
IoT Device (WiFi) 
    ↓
Raspberry Pi 5 (WiFi AP)
    ↓ (routing/forwarding)
Analysis Machine (Ethernet) ← Burp Suite/mitmproxy
    ↓
Internet
```

The Raspberry Pi 5 acts as a WiFi access point with transparent traffic forwarding to your analysis machine, where you can intercept, modify, and analyze all HTTP/HTTPS traffic.

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

### 1. Raspberry Pi Setup

```bash
# Clone this repository
git clone https://github.com/schladt/MitM-Pi.git
cd MitM-Pi

# Run the Pi setup script
sudo ./pi-setup/setup.sh
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
2. Connect your IoT device to the WiFi AP (SSID: `MitM-Pi` by default)
3. Start capturing traffic in your proxy tool
4. Interact with your IoT device

## Project Structure

```
MitM-Pi/
├── README.md
├── LICENSE
├── .gitignore
├── pi-setup/              # Raspberry Pi setup scripts and configs
│   ├── setup.sh
│   ├── configs/
│   │   ├── hostapd.conf
│   │   ├── dnsmasq.conf
│   │   └── routing-rules.sh
│   └── docs/
├── analysis-setup/        # Analysis machine setup scripts
│   ├── setup-macos.sh
│   ├── setup-ubuntu.sh
│   └── configs/
├── docs/                  # Documentation
│   ├── architecture.md
│   ├── burp-setup.md
│   ├── mitmproxy-setup.md
│   ├── troubleshooting.md
│   └── testing-guide.md
└── examples/              # Example configurations and test cases
```

## Configuration

### WiFi Access Point

The default configuration creates a WiFi AP with:
- **SSID:** `MitM-Pi`
- **Password:** `changeme123` (⚠️ Change this!)
- **IP Range:** 192.168.100.1/24

Edit `pi-setup/configs/hostapd.conf` to customize.

### Proxy Routing

By default, all traffic is forwarded to:
- **Analysis Machine IP:** 192.168.1.100 (configure in setup)
- **Proxy Port:** 8080 (Burp default) or 8080 (mitmproxy default)

Edit `pi-setup/configs/routing-rules.sh` to customize.

## Known Limitations

- **Certificate Pinning:** Apps with certificate pinning will fail unless you can install custom root certificates
- **Mutual TLS:** Client certificate authentication may not work in all scenarios
- **UDP Traffic:** Currently focused on TCP/HTTP/HTTPS traffic
- **Performance:** Not designed for high-bandwidth connections

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues and solutions.

## Contributing

Contributions are welcome! Please open an issue or pull request for:
- Bug fixes
- New features
- Documentation improvements
- Additional proxy tool integrations

## References

This project is inspired by and builds upon:
- [Pi-MITM by Gareth](https://www.gareth.co.uk/pi-mitm/)
- [YouTube: IoT MITM Setup](https://www.youtube.com/watch?v=e6yvNJnGRM8)

## License

[Choose appropriate license - MIT recommended for open source]

## Acknowledgments

- Raspberry Pi Foundation
- PortSwigger (Burp Suite)
- mitmproxy project
- The security research community

---

**Remember:** Only use this tool on devices you own or have explicit permission to test. Happy (ethical) hacking! 🔐
