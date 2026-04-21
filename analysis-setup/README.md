# MitM-Pi Analysis Setup

Tools and scripts for capturing and analyzing network traffic from IoT devices connected to the MitM-Pi WiFi access point.

## Quick Start

### 1. Install Burp Certificate on Android Device

```bash
# One-time certificate installation (run after each reboot)
./install-android-cert.sh 9a5ba575.0
```

This installs the Burp Suite CA certificate to both user and system trust stores on Android 14+ devices with root access.

### 2. Capture Traffic

```bash
# Capture all traffic through Burp Suite (manual analysis)
./capture-traffic.sh

# Or capture with mitmproxy for automated processing
./capture-mitmproxy.sh
```

## Files

### Certificate Management
- **install-android-cert.sh** - Automated certificate installer for Android 14+ (LineageOS with root)
- **9a5ba575.0** - Burp Suite CA certificate (PEM format, hashed filename)
- **burp-ca-cert.der** - Burp Suite CA certificate (DER format, from Burp export)
- **burp-ca-cert.pem** - Burp Suite CA certificate (PEM format, converted from DER)
- **README-cert-install.md** - Detailed certificate installation documentation

### Traffic Capture Scripts
- **capture-traffic.sh** - Routes traffic through Burp Suite for manual interception/analysis
- **capture-mitmproxy.sh** - Routes traffic through mitmproxy for automated capture
- **configs/** - Configuration files for traffic capture tools

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────────┐
│   Android   │  WiFi   │   MitM-Pi    │  Port   │   Analysis      │
│   Device    ├────────>│   (Router)   ├─ 8080──>│   Machine       │
│ 192.168.    │         │ 192.168.     │         │ (Burp/mitmproxy)│
│   100.135   │         │   100.1      │         │ 192.168.50.174  │
└─────────────┘         └──────────────┘         └─────────────────┘
       │                                                    │
       └────────────── Intercepted Traffic ────────────────┘
```

## Requirements

### Android Device
- LineageOS or similar ROM with root access (`adb root`)
- Android 14+ (for APEX certificate handling)
- Connected to MitM-Pi WiFi network

### Analysis Machine (macOS/Linux)
- adb (Android Debug Bridge)
- openssl
- Burp Suite (for manual analysis) or mitmproxy (for automated capture)
- Network access to MitM-Pi network

### MitM-Pi (Raspberry Pi 5)
- Kali Linux
- hostapd (WiFi AP)
- dnsmasq (DHCP/DNS)
- iptables (traffic routing)
- See `../pi-setup/` for setup instructions

## Workflows

### Manual Testing with Burp Suite

1. **Start Burp Suite** on analysis machine (192.168.50.174:8080)
2. **Configure Burp** to listen on all interfaces
3. **Install certificate** on Android device: `./install-android-cert.sh 9a5ba575.0`
4. **Connect device** to MitM-Pi WiFi
5. **Start capture** on Pi: `./capture-traffic.sh`
6. **Use device normally** - all HTTP/HTTPS traffic appears in Burp
7. **Analyze, modify, replay** traffic in Burp Suite

### Automated Capture with mitmproxy

1. **Install certificate** on Android device: `./install-android-cert.sh 9a5ba575.0`
2. **Connect device** to MitM-Pi WiFi
3. **Start capture** with logging: `./capture-mitmproxy.sh`
4. **Use device normally** - traffic captured to log files
5. **Analyze logs** with mitmproxy tools or custom scripts

## Certificate Installation Details

Chrome and most modern browsers on Android 14+ **require certificates in the user store**, not just system store. The `install-android-cert.sh` script installs to both:

- **User store**: `/data/misc/user/0/cacerts-added/` (persists, required for Chrome)
- **System store**: `/apex/com.android.conscrypt/cacerts` (via bind mount, for system apps)

**After reboot**: Re-run certificate script (user cert persists, but system bind mount is lost)

See [README-cert-install.md](README-cert-install.md) for detailed documentation.

## Troubleshooting

### Certificate errors in Chrome
```bash
# Clear Chrome cache (including HSTS)
adb shell "pm clear com.android.chrome"

# Force stop and restart Chrome
adb shell "am force-stop com.android.chrome"
```

### Device has no internet connectivity
```bash
# Check if device got default gateway from DHCP
adb shell "ip route"

# Should show: default via 192.168.100.1 dev wlan0
```

### Certificate not showing in Settings
```bash
# Verify both installations
adb shell "ls /data/misc/user/0/cacerts-added/9a5ba575.0"
adb shell "ls /apex/com.android.conscrypt/cacerts/9a5ba575.0"

# Restart Android runtime
adb shell "killall system_server"
```

### Apps using certificate pinning
Some apps implement certificate pinning and won't trust any CA certificate. Use Frida/Objection to bypass:
```bash
# Install Frida
pip install frida-tools objection

# Bypass SSL pinning
objection -g com.example.app explore
> android sslpinning disable
```

## Related Documentation

- **Pi Setup**: [../pi-setup/README.md](../pi-setup/README.md) - MitM-Pi router configuration
- **Certificate Install**: [README-cert-install.md](README-cert-install.md) - Detailed cert docs
- **Project Overview**: [../README.md](../README.md) - Overall project documentation
- **Testing Guide**: [../docs/testing-guide.md](../docs/testing-guide.md) - IoT security testing methodology

## Technical References

- [NVISO: Intercepting traffic on Android with Mainline and Conscrypt](https://blog.nviso.eu/2025/06/05/intercepting-traffic-on-android-with-mainline-and-conscrypt/)
- [HTTPToolkit: Installing System CA on Android 14](https://httptoolkit.com/blog/android-14-install-system-ca-certificate/)
- [AlwaysTrustUserCerts Magisk Module](https://github.com/NVISOsecurity/AlwaysTrustUserCerts)
