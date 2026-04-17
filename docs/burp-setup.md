# Burp Suite Configuration for MitM-Pi

This guide covers setting up Burp Suite on your analysis machine (macOS or Linux) to intercept traffic from IoT devices connected to the MitM-Pi.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configure Burp Suite Listener](#configure-burp-suite-listener)
4. [SSL/TLS Certificate Setup](#ssltls-certificate-setup)
5. [Testing the Setup](#testing-the-setup)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Configuration](#advanced-configuration)

## Prerequisites

Before starting, ensure:

- ✅ MitM-Pi setup is complete and running
- ✅ Analysis machine is on the same network as the Pi
- ✅ You know your analysis machine's IP address
- ✅ Burp Suite is installed (Community or Pro)

### Check Your IP Address

**On macOS:**
```bash
ifconfig en0 | grep "inet " | awk '{print $2}'
# Should show something like 192.168.50.174
```

**On Linux:**
```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
# Or for specific interface:
ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
```

This is the IP you provided during Pi setup.

## Installation

### Burp Suite Community Edition (Free)

Download from: [https://portswigger.net/burp/communitydownload](https://portswigger.net/burp/communitydownload)

**macOS:**
```bash
# After downloading the DMG
open ~/Downloads/Burp\ Suite\ Community\ Edition*.dmg
# Drag to Applications folder
```

**Linux:**
```bash
# Download the Linux installer
chmod +x burpsuite_community_linux*.sh
sudo ./burpsuite_community_linux*.sh
```

### Burp Suite Professional (Paid)

If you have a Pro license, download from: [https://portswigger.net/burp/pro](https://portswigger.net/burp/pro)

## Configure Burp Suite Listener

### Step 1: Launch Burp Suite

```bash
# macOS
open -a "Burp Suite Community Edition"

# Linux (if installed system-wide)
burpsuite

# Or from installation directory
./BurpSuiteCommunity
```

### Step 2: Create Temporary Project

1. On startup, select **"Temporary project"**
2. Click **"Next"**
3. Select **"Use Burp defaults"**
4. Click **"Start Burp"**

### Step 3: Configure Proxy Listener

This is the **most important step** - configuring Burp to listen for traffic from the Pi.

1. Go to **Proxy → Proxy settings** (or **Proxy → Options** in older versions)

2. In the **Proxy Listeners** section, click **"Add"**

3. Configure the listener:
   - **Bind to port:** `8080`
   - **Bind to address:** Select **"All interfaces"** or **"Specific address"** and choose your machine's IP

4. Click **"OK"**

### Step 4: Verify Listener Configuration

Your listener should show:
- **Running:** ✓ (green checkmark)
- **Interface:** `0.0.0.0:8080` (all interfaces) or `192.168.50.174:8080` (specific IP)

**Important Settings:**

1. Go to **Proxy → Proxy settings → Request handling**

2. Enable these options:
   - ☑ **Support invisible proxying** (CRITICAL for transparent MITM)
   - ☑ **Process HTTP/2 messages**

3. In **Intercept Client Requests**, consider setting:
   - Intercept mode: **Initially off** (for testing, turn on later)
   - This prevents blocking traffic while you verify setup

### Visual Guide

```
┌─────────────────────────────────────────┐
│ Proxy Settings                          │
├─────────────────────────────────────────┤
│ Proxy Listeners                         │
│  ┌─────────────────────────────────┐   │
│  │ ✓ Running  0.0.0.0:8080         │   │
│  └─────────────────────────────────┘   │
│                                         │
│ Request Handling                        │
│  ☑ Support invisible proxying          │
│  ☑ Process HTTP/2 messages              │
│                                         │
│ Intercept Client Requests               │
│  ⚪ Intercept is off                    │
└─────────────────────────────────────────┘
```

## SSL/TLS Certificate Setup

For HTTPS interception, devices need to trust Burp's CA certificate.

### Export Burp CA Certificate

1. In Burp, go to **Proxy → Proxy settings**
2. Click **"Import / export CA certificate"**
3. Select **"Export Certificate in DER format"**
4. Save as `burp-ca-cert.der`

### Convert to PEM Format (for some devices)

```bash
openssl x509 -inform DER -in burp-ca-cert.der -out burp-ca-cert.pem
```

### Installing on Test Devices

**Note:** This varies by device. Many IoT devices cannot have custom certificates installed, which is why they'll see SSL errors (expected behavior).

**Android (for testing):**
1. Copy `burp-ca-cert.der` to device
2. Settings → Security → Install from storage
3. Select the certificate

**iOS (for testing):**
1. Email certificate to device or host via web server
2. Install profile when prompted
3. Settings → General → About → Certificate Trust Settings
4. Enable full trust for Burp

**IoT Devices:**
- Most IoT devices **cannot** import custom certificates
- Traffic will be visible but may show SSL errors
- Some apps with certificate pinning will fail (expected)

## Testing the Setup

### Test 1: Verify Burp is Listening

```bash
# From your Mac, test the listener
curl -x http://localhost:8080 http://example.com
```

You should see the request in Burp's HTTP history.

### Test 2: Check from Another Device

```bash
# From another machine on the network (or the Pi)
curl -x http://192.168.50.174:8080 http://example.com
```

### Test 3: Connect IoT Device to WiFi AP

1. **Scan for WiFi networks** on your test device (phone, IoT device, etc.)
2. **Connect to:** `MitM-Pi`
3. **Password:** `changeme123`
4. **Device should get IP:** 192.168.100.x (check Pi: `sudo tail -f /var/log/dnsmasq.log`)

### Test 4: Generate HTTP Traffic

From the connected device:
- Open a web browser
- Navigate to one of these HTTP-only sites:
  - `http://example.com` - Classic test domain
  - `http://httpforever.com` - Explicitly HTTP-only
  - `http://info.cern.ch` - The first website ever (still HTTP!)
- You should see traffic in Burp's **HTTP history** tab

### Test 5: Check HTTPS Traffic

Visit: `https://example.com`
- May see certificate warning (expected without cert installation)
- Traffic should appear in Burp (decrypted if cert is trusted)

## Troubleshooting

### Issue 1: No Traffic in Burp

**Check:**
```bash
# On Pi, verify WiFi AP is running
sudo systemctl status hostapd

# Check if device got DHCP lease
sudo tail -f /var/log/dnsmasq.log

# Verify routing rules
sudo iptables -t nat -L -n -v

# Check if Burp is listening
netstat -an | grep 8080
# Or on macOS:
lsof -i :8080
```

### Issue 2: Connection Timeout

**Possible causes:**
- Firewall blocking connections on analysis machine
- Wrong IP address configured during setup
- Burp not listening on all interfaces

**Fix - macOS Firewall:**
```bash
# Check firewall status
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Allow Burp through firewall
# System Settings → Network → Firewall → Options
# Click "+" and add Burp Suite
```

**Fix - Linux Firewall:**
```bash
# Check firewall
sudo ufw status

# Allow port 8080
sudo ufw allow 8080/tcp

# Or disable temporarily for testing
sudo ufw disable
```

### Issue 3: SSL/TLS Errors

**Expected behavior:** Most IoT devices will show SSL errors because they don't trust Burp's certificate.

**What you'll see:**
- HTTP traffic: ✓ Works perfectly
- HTTPS traffic: ⚠️ May fail or show errors
- Decrypted HTTPS: Only if device trusts Burp CA cert

**This is normal!** You can still see:
- Connection attempts
- SNI (Server Name Indication) - which domain they're trying to reach
- Certificate details
- Some may work if not using certificate pinning

### Issue 4: Device Won't Connect to WiFi

**Check:**
```bash
# On Pi, check hostapd logs
sudo journalctl -u hostapd -f

# Check if WiFi interface is up
ip link show wlan1
# Should show: state UP

# Try restarting hostapd
sudo systemctl restart hostapd
```

### Issue 5: Device Connects but No Internet

**Check routing:**
```bash
# On Pi, verify IP forwarding
cat /proc/sys/net/ipv4/ip_forward
# Should output: 1

# Check NAT rules
sudo iptables -t nat -L POSTROUTING -n -v
# Should show MASQUERADE rule
```

## Advanced Configuration

### Separate HTTPS Listener

For better HTTPS handling, create a second listener:

1. Add new listener on port `8443`
2. Enable **invisible proxying**
3. Update Pi routing rules to forward 443 → 8443

### Match and Replace Rules

Useful for modifying requests/responses:

1. Go to **Proxy → Proxy settings → Match and Replace**
2. Add rules to modify headers, bodies, etc.

Example: Remove security headers
- Type: `Response header`
- Match: `Strict-Transport-Security`
- Replace: (empty)

### Scope Control

Limit what Burp intercepts:

1. Go to **Target → Scope**
2. Add specific domains or IP ranges
3. Enable **"Use advanced scope control"**

### Logging and Reporting

**Save traffic for analysis:**
1. Go to **Proxy → HTTP history**
2. Select requests
3. Right-click → **"Save items"**
4. Choose format (XML, JSON, etc.)

**Export for external tools:**
```bash
# Burp can export to:
# - HAR (HTTP Archive)
# - XML
# - Plain text
```

## Burp Extensions for IoT Testing

Recommended extensions from **Extender → BApp Store**:

1. **JSON Web Tokens** - Decode/modify JWTs
2. **Flow** - Better HTTP history visualization
3. **Logger++** - Enhanced logging
4. **Autorize** - Authorization testing
5. **ActiveScan++** - Enhanced scanning

## Quick Reference

### Common Burp Tabs

- **Proxy → Intercept:** Pause and modify traffic in real-time
- **Proxy → HTTP history:** View all captured requests
- **Proxy → WebSockets history:** View WebSocket traffic
- **Target → Site map:** Organized view of tested sites
- **Repeater:** Manually modify and resend requests
- **Intruder:** Automated attacks (Pro only)
- **Decoder:** Encode/decode data

### Keyboard Shortcuts

- **Ctrl+R** - Send to Repeater
- **Ctrl+I** - Send to Intruder
- **Ctrl+Shift+B** - Base64 encode in Decoder
- **Ctrl+F** - Search
- **Ctrl+Space** - Toggle intercept

## Next Steps

Once Burp is configured and testing:

1. ✅ Document interesting IoT device behavior
2. ✅ Test with different IoT devices
3. ✅ Try mitmproxy as alternative to Burp
4. ✅ Set up packet capture for additional analysis
5. ✅ Review [Testing Guide](testing-guide.md) for systematic approach

---

## Summary

**Minimal Setup:**
1. Launch Burp Suite
2. Add listener: `0.0.0.0:8080` with invisible proxying
3. Turn intercept OFF for testing
4. Connect device to MitM-Pi WiFi
5. Watch traffic in HTTP history

**Pro Tip:** Start with intercept OFF, verify traffic is flowing, then enable intercept for detailed analysis.

⚠️ **Remember:** Only test devices you own or have permission to test!
