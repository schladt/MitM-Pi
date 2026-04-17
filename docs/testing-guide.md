# MitM-Pi Testing Guide

Quick reference guide for testing the MitM-Pi setup with IoT devices.

## Pre-Test Checklist

Before testing, verify:

- [ ] Pi is powered on and accessible via SSH
- [ ] Setup script completed successfully
- [ ] WiFi AP "MitM-Pi" is broadcasting (check with your phone)
- [ ] Burp Suite (or mitmproxy) is running on analysis machine
- [ ] Analysis machine firewall allows incoming connections on port 8080
- [ ] You have an IoT device or phone to test with

## Quick Test Procedure

### 1. Verify Pi Status

SSH to the Pi and check services:

```bash
ssh kali@kali-raspberrypi

# Check hostapd (WiFi AP)
sudo systemctl status hostapd
# Should show: active (running)

# Check dnsmasq (DHCP)
sudo systemctl status dnsmasq
# Should show: active (running)

# Check WiFi interface
ip addr show wlan1
# Should show: inet 192.168.100.1/24

# Check iptables routing
sudo iptables -t nat -L -n -v | grep DNAT
# Should show rules redirecting to analysis machine
```

### 2. Configure Burp Suite

See: [Burp Suite Setup Guide](burp-setup.md)

**Quick steps:**
1. Launch Burp Suite
2. Proxy → Proxy settings → Add listener
3. Port: `8080`, Interface: `All interfaces`
4. Enable: **"Support invisible proxying"**
5. Turn intercept OFF (for initial testing)

**Verify Burp is listening:**
```bash
# On your Mac
lsof -i :8080
# Should show Burp Suite process
```

### 3. Connect Test Device

**Option A: Use your phone (easiest)**
1. Open WiFi settings
2. Connect to: `MitM-Pi`
3. Password: `changeme123`
4. Wait for IP assignment (should get 192.168.100.x)

**Option B: Use IoT device**
- Follow device-specific WiFi setup procedure
- Connect to MitM-Pi network
- May need QR code or app for some devices

**Verify connection on Pi:**
```bash
# Watch DHCP assignments
sudo tail -f /var/log/dnsmasq.log

# Check connected clients  
cat /var/lib/misc/dnsmasq.leases

# Example output:
# 1713321600 aa:bb:cc:dd:ee:ff 192.168.100.10 TestPhone *
```

### 4. Generate Test Traffic

**Test 1: Simple HTTP (should work perfectly)**

From connected device, visit:
- `http://example.com` - Simple test page
- `http://httpforever.com` - Forces HTTP
- `http://info.cern.ch` - First website ever, guaranteed HTTP

**Expected:** Request appears in Burp HTTP history

**Test 2: HTTPS (may show certificate errors)**

From connected device, visit:
- `https://example.com`
- `https://httpbin.org/ip`

**Expected:** 
- Traffic appears in Burp (possibly with SSL errors)
- Device may show certificate warning (normal)

**Test 3: IoT Device Normal Operation**

Let the IoT device do its normal thing:
- App communication
- Firmware updates
- API calls

**Watch for:**
- API endpoints
- Update servers
- Data being sent
- Authentication methods

### 5. Analyze Traffic in Burp

**Check HTTP History:**
1. Go to **Proxy → HTTP history**
2. Look for requests from IoT device
3. Click on request to see details:
   - Headers
   - Body/parameters
   - Responses

**Useful filters:**
- Show only: `HTTP protocol`
- Hide: `images, CSS, JS` (for cleaner view)
- Search: specific domains or keywords

### 6. Test Internet Connectivity

Verify device has internet access through MITM setup:

```bash
# From connected device (if it has a terminal)
ping 8.8.8.8

# Or just open any website
# Should work normally (except HTTPS cert warnings)
```

## Common Test Scenarios

### Useful Test URLs

**HTTP-Only Sites (for testing unencrypted traffic):**
- `http://example.com` - IANA test domain
- `http://httpforever.com` - Intentionally HTTP-only
- `http://info.cern.ch` - First website ever created
- `http://http.rip` - HTTP test site
- `http://portquiz.net:8080` - Port/connectivity testing

**HTTPS Sites (for testing encrypted traffic):**
- `https://example.com` - Simple HTTPS test
- `https://httpbin.org/ip` - Returns your IP (useful for verifying routing)
- `https://httpbin.org/headers` - Shows request headers
- `https://api.ipify.org` - Simple IP check

**IoT/API Testing:**
- `http://httpbin.org/get` - HTTP GET test
- `http://httpbin.org/post` - HTTP POST test
- `http://httpbin.org/delay/2` - Delayed response (2 seconds)

### Scenario 1: Smart Home Device

**Device:** Smart bulb, plug, thermostat, etc.

**Test:**
1. Connect device to MitM-Pi
2. Use phone app to control device
3. Watch Burp for:
   - Control commands
   - API endpoints
   - Authentication tokens
   - Device responses

### Scenario 2: IP Camera

**Device:** Security camera, baby monitor

**Test:**
1. Connect camera to MitM-Pi
2. Access via app or web interface
3. Watch for:
   - Video stream protocols
   - Authentication
   - Cloud service URLs
   - Firmware update checks

### Scenario 3: Smart Speaker

**Device:** Alexa, Google Home (experimental)

**Test:**
1. Connect speaker to MitM-Pi
2. Issue voice commands
3. Watch for:
   - Audio upload
   - Command processing
   - Response delivery
   - Analytics/telemetry

**Note:** May not work due to certificate pinning

### Scenario 4: Mobile App Testing

**Device:** Phone with IoT app

**Test:**
1. Connect phone to MitM-Pi
2. Use IoT control app
3. Watch for:
   - API calls
   - User data
   - Device communication
   - Third-party analytics

## Troubleshooting Tests

### Test: Can device get DHCP address?

```bash
# On Pi, watch DHCP
sudo tail -f /var/log/dnsmasq.log

# Try connecting device
# Should see: DHCPDISCOVER, DHCPOFFER, DHCPREQUEST, DHCPACK
```

### Test: Can device reach internet?

```bash
# On Pi, watch traffic
sudo tcpdump -i wlan1 -n

# Connect device and generate traffic
# Should see packets flowing
```

### Test: Is traffic reaching Burp?

```bash
# On Mac, check Burp is receiving connections
sudo tcpdump -i en0 port 8080 -n

# Connect device and generate traffic
# Should see SYN packets to port 8080
```

### Test: Are routing rules correct?

```bash
# On Pi, check packet counts
sudo iptables -t nat -L -n -v

# Look for DNAT rules with increasing packet counts
```

## Success Criteria

You know it's working when:

✅ Device connects to MitM-Pi WiFi
✅ Device gets IP address (192.168.100.x)
✅ Device can access internet
✅ HTTP requests appear in Burp
✅ HTTPS requests appear (even with cert errors)
✅ You can see API endpoints, headers, and data

## What to Document

When testing IoT devices, document:

1. **Device Information**
   - Make/model
   - Firmware version
   - MAC address

2. **Network Behavior**
   - API endpoints used
   - Protocols (HTTP, HTTPS, MQTT, etc.)
   - Connection frequency

3. **Security Observations**
   - Authentication methods
   - Certificate pinning (yes/no)
   - Data encryption
   - Plain text data

4. **API Structure**
   - Request/response formats
   - Authentication tokens
   - User data exposure
   - Device identifiers

## Advanced Testing

### Packet Capture

For deeper analysis alongside Burp:

```bash
# On Pi, capture all WiFi AP traffic
sudo tcpdump -i wlan1 -w /tmp/capture.pcap

# Let device communicate for a while
# Stop with Ctrl+C

# Copy to analysis machine
scp kali@kali-raspberrypi:/tmp/capture.pcap ~/Desktop/

# Analyze with Wireshark
wireshark ~/Desktop/capture.pcap
```

### Certificate Pinning Test

To identify devices using certificate pinning:

1. Try to access device through MitM
2. If HTTPS fails completely (no traffic), likely pinned
3. Check device documentation or forums

### Multiple Devices

Test with multiple IoT devices connected:

1. Connect several devices to MitM-Pi
2. Operate them simultaneously  
3. Use Burp filters to distinguish traffic
4. Look for cross-device communication

## Safety Reminders

⚠️ **Important:**
- Only test devices you own
- Don't test on production/critical devices
- Be aware that some tests may reset devices
- Backup device configs before testing
- Some devices may need re-setup after testing

## Next Steps

After successful testing:

1. Try different intercepting proxies (mitmproxy)
2. Test with various IoT device types
3. Document interesting findings
4. Experiment with modifying requests
5. Try replay attacks (responsibly!)

---

**Pro Tip:** Start with a simple HTTP-only IoT device or your phone to verify the basic setup works before testing complex devices.
