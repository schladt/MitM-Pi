# Installing Burp CA Certificate on Android

This guide covers installing the Burp Suite CA certificate on Android devices for HTTPS interception, including both user and system certificate installation.

**Tested on:** Samsung Galaxy S6 Lite (SM-P613) running Android 14 (unofficial ROM)

## Table of Contents

1. [Export Burp CA Certificate](#export-burp-ca-certificate)
2. [Method 1: User Certificate (Easy)](#method-1-user-certificate-easy)
3. [Method 2: System Certificate via ADB (Recommended)](#method-2-system-certificate-via-adb-recommended)
4. [Method 3: System Certificate with Root (Magisk)](#method-3-system-certificate-with-root-magisk)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

## Why Install Certificates?

- **Without certificate:** HTTPS traffic visible in Burp but encrypted, shows SSL errors
- **With user certificate:** HTTPS traffic decrypted in browser, some apps still fail
- **With system certificate:** HTTPS traffic decrypted for ALL apps (except pinned)

## Export Burp CA Certificate

### Step 1: Export from Burp Suite

**In Burp Suite:**

1. Go to **Proxy → Proxy settings**
2. Click **"Import / export CA certificate"**
3. Select **"Export Certificate in DER format"**
4. Save as: `burp-ca-cert.der`
5. Click **"Next"** and **"Close"**

### Step 2: Convert to PEM Format

Android prefers different formats for different methods:

```bash
# Convert DER to PEM (for user certificate)
openssl x509 -inform DER -in burp-ca-cert.der -out burp-ca-cert.pem

# Create Android system certificate format (with proper naming)
# Android requires certificates named by their hash
openssl x509 -inform DER -in burp-ca-cert.der -out burp-ca-cert.pem
HASH=$(openssl x509 -inform PEM -subject_hash_old -in burp-ca-cert.pem | head -1)
cat burp-ca-cert.pem > $HASH.0
echo "System cert: $HASH.0"
```

You should now have:
- `burp-ca-cert.der` - For user installation
- `burp-ca-cert.pem` - PEM format
- `9a5ba575.0` (or similar hash) - For system installation

## Method 1: User Certificate (Easy)

**Pros:** Easy, no root required
**Cons:** Doesn't work for all apps (many apps ignore user certificates on Android 7+)

### Via Web Browser

1. **Connect Android device to MitM-Pi WiFi**
   - SSID: `MitM-Pi`
   - Password: `changeme123`

2. **Host the certificate on your Mac:**
   ```bash
   # In the directory with burp-ca-cert.der
   python3 -m http.server 8000
   ```

3. **On Android device, open browser:**
   ```
   http://192.168.50.174:8000/burp-ca-cert.der
   ```
   (Replace with your Mac's IP)

4. **Install the certificate:**
   - Android will prompt to install
   - Give it a name: `Burp CA`
   - Select **"VPN and apps"** usage
   - Confirm with PIN/password/fingerprint

### Via ADB Push

```bash
# Push certificate to device
adb push burp-ca-cert.der /sdcard/Download/

# On device:
# Settings → Security → Encryption & credentials
# → Install a certificate → CA certificate
# Browse to Downloads and select burp-ca-cert.der
```

### Via Email/File Transfer

1. Email `burp-ca-cert.der` to yourself
2. Open on Android device
3. Tap the attachment
4. Follow installation prompts

## Method 2: System Certificate via ADB (Recommended)

**Pros:** Works for most apps, no root required (on unlocked bootloader devices)
**Cons:** Requires ADB, more technical

This method works great for custom ROMs with unlocked bootloaders.

### Prerequisites

**On your Mac:**
```bash
# Install ADB if not already installed
brew install android-platform-tools

# Verify ADB
adb version
```

**On Android:**
1. Enable **Developer Options**:
   - Settings → About phone → Tap "Build number" 7 times

2. Enable **USB Debugging**:
   - Settings → Developer options → USB debugging (ON)

3. Connect via USB and authorize the computer

### Installation Steps

```bash
# 1. Verify device is connected
adb devices
# Should show your device

# 2. Create the certificate in Android format
openssl x509 -inform DER -in burp-ca-cert.der -out burp-ca-cert.pem
HASH=$(openssl x509 -inform PEM -subject_hash_old -in burp-ca-cert.pem | head -1)
cat burp-ca-cert.pem > ${HASH}.0

echo "Certificate file: ${HASH}.0"
# Example output: 9a5ba575.0

# 3. Remount system as read-write (Android 10+)
adb root
# If "adbd cannot run as root" error, use Method 3 (Magisk) instead

adb remount
# or on some devices:
adb shell mount -o rw,remount /system

# 4. Push certificate to system
adb push ${HASH}.0 /system/etc/security/cacerts/

# 5. Set proper permissions
adb shell chmod 644 /system/etc/security/cacerts/${HASH}.0

# 6. Reboot device
adb reboot
```

### Alternative: One-Line Script

```bash
#!/bin/bash
# install-burp-cert-android.sh

# Export certificate from Burp first!
CERT_DER="burp-ca-cert.der"

if [ ! -f "$CERT_DER" ]; then
    echo "Error: $CERT_DER not found!"
    echo "Export from Burp: Proxy → Proxy settings → Import/export CA certificate"
    exit 1
fi

# Convert to PEM
openssl x509 -inform DER -in $CERT_DER -out burp-ca-cert.pem

# Get certificate hash
HASH=$(openssl x509 -inform PEM -subject_hash_old -in burp-ca-cert.pem | head -1)
cat burp-ca-cert.pem > ${HASH}.0

echo "Certificate: ${HASH}.0"

# Install to device
echo "Connecting to device..."
adb root
adb remount
adb push ${HASH}.0 /system/etc/security/cacerts/
adb shell chmod 644 /system/etc/security/cacerts/${HASH}.0

echo "Certificate installed! Rebooting device..."
adb reboot

echo "Done! Device will reboot and certificate will be active."
```

Save as `install-burp-cert-android.sh`, make executable, and run:

```bash
chmod +x install-burp-cert-android.sh
./install-burp-cert-android.sh
```

## Method 3: System Certificate with Root (Magisk)

**Pros:** Works on any rooted device
**Cons:** Requires root access

If you have Magisk installed:

### Using Magisk Module

1. **Install MagiskTrustUserCerts module:**
   - Download: https://github.com/NVISOsecurity/MagiskTrustUserCerts
   - Magisk Manager → Modules → Install from storage
   - Select downloaded zip
   - Reboot

2. **Install cert as user certificate** (Method 1 above)

3. **Module automatically promotes user certs to system certs**

### Manual Installation with Root

```bash
# 1. Prepare certificate (same as Method 2)
openssl x509 -inform DER -in burp-ca-cert.der -out burp-ca-cert.pem
HASH=$(openssl x509 -inform PEM -subject_hash_old -in burp-ca-cert.pem | head -1)
cat burp-ca-cert.pem > ${HASH}.0

# 2. Push to device
adb push ${HASH}.0 /sdcard/

# 3. Move to system (in adb shell or terminal on device)
adb shell
su  # Grant root when prompted

# Remount system as read-write
mount -o rw,remount /system

# Copy certificate
cp /sdcard/${HASH}.0 /system/etc/security/cacerts/
chmod 644 /system/etc/security/cacerts/${HASH}.0
chown root:root /system/etc/security/cacerts/${HASH}.0

# Remount as read-only
mount -o ro,remount /system

# Exit and reboot
exit
exit

adb reboot
```

## Verification

### Check User Certificates

**On Android:**
1. Settings → Security → Encryption & credentials
2. → Trusted credentials → **USER** tab
3. Look for "PortSwigger CA" or your custom name

### Check System Certificates

**On Android:**
1. Settings → Security → Encryption & credentials
2. → Trusted credentials → **SYSTEM** tab
3. Scroll to find "PortSwigger CA"

**Via ADB:**
```bash
adb shell ls -la /system/etc/security/cacerts/ | grep 9a5ba575
# Replace 9a5ba575 with your cert hash
```

### Test HTTPS Interception

1. **Connect to MitM-Pi WiFi**

2. **Open Chrome or any app**

3. **Visit HTTPS site:**
   ```
   https://example.com
   https://httpbin.org/ip
   ```

4. **Check Burp Suite:**
   - Should see decrypted HTTPS traffic
   - No SSL errors on device
   - Full request/response visible

5. **Check for certificate warning:**
   - **No warning** = Certificate properly installed! ✓
   - **Warning** = Certificate not trusted (try system install)

## Troubleshooting

### "Can't install certificate" Error

**Solution:**
- Ensure you have a screen lock (PIN, password, pattern)
- Android requires lock screen to install certificates

### "adb: no devices/emulators found"

**Solution:**
```bash
# Check USB debugging is enabled
# Revoke and re-grant USB debugging:
# Settings → Developer options → Revoke USB debugging authorizations

# Reconnect device and accept prompt
```

### "adbd cannot run as root"

**Cause:** Stock ROM or user builds don't allow `adb root`

**Solutions:**
1. Use Method 3 (Magisk) if rooted
2. Flash a userdebug or eng build of your ROM
3. Some custom ROMs have "Root debugging" in Developer Options

### Certificate Installed but Still SSL Errors

**For User Certificate:**
- Apps on Android 7+ ignore user certificates by default
- Use system certificate installation instead

**For System Certificate:**
- Some apps use **certificate pinning** (expects specific cert)
- These apps will fail even with system cert (by design)
- Examples: Banking apps, some Google apps

### Certificate Not Showing in System Tab

**Check:**
```bash
# Verify file exists
adb shell ls -la /system/etc/security/cacerts/ | grep -i portswigger

# Verify permissions (should be 644)
adb shell ls -la /system/etc/security/cacerts/ | grep 9a5ba575

# Should show: -rw-r--r-- 1 root root
```

### Apps Still Failing with Certificate Pinning

**Workaround options:**

1. **Use Frida** (advanced):
   - Bypass SSL pinning dynamically
   - See: https://github.com/frida/frida

2. **Patch APK** (advanced):
   - Decompile, modify network security config, recompile
   - Requires APK signing knowledge

3. **Use Xposed/LSPosed modules:**
   - TrustMeAlready
   - JustTrustMe
   - SSLUnpinning

4. **Accept limitation:**
   - Some apps (banking, etc.) are designed to resist MITM

## Android 14 Specific Notes

### Network Security Config

Some apps define their security in `res/xml/network_security_config.xml`:

```xml
<!-- Blocks user certificates -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

**System certificates work around this** (which is why Method 2/3 is preferred)

### SELinux Considerations

On some ROMs:
```bash
# Check SELinux status
adb shell getenforce
# If "Enforcing", certificates might not stick

# Temporary permissive mode (for testing)
adb shell su -c setenforce 0

# After certificate install
adb shell su -c setenforce 1
```

## Quick Reference Card

| Method | Difficulty | Root Required | Works With Apps | Persistence |
|--------|-----------|---------------|-----------------|-------------|
| User Cert | Easy | No | Browser only (mostly) | Yes |
| ADB System | Medium | No* | Most apps | Yes |
| Magisk System | Medium | Yes | All apps** | Yes |

\* Requires unlocked bootloader or userdebug ROM  
\** Except apps with certificate pinning

## Script Collection

Save these for easy re-installation:

**Export from Burp:**
```bash
# Already done in Burp UI
```

**Quick install (ADB method):**
```bash
./install-burp-cert-android.sh
```

**Verify installation:**
```bash
adb shell ls -la /system/etc/security/cacerts/ | grep 9a5ba575
```

**Remove certificate:**
```bash
adb root
adb remount
adb shell rm /system/etc/security/cacerts/9a5ba575.0
adb reboot
```

## Next Steps

After certificate installation:

1. Test with various apps on your device
2. Document which apps respect the certificate
3. Identify apps with certificate pinning
4. Analyze API traffic in Burp Suite
5. See [Testing Guide](testing-guide.md) for IoT testing procedures

---

**Pro Tip:** Keep the certificate files backed up. You'll need to reinstall if you:
- Factory reset device
- Update/change ROM
- Update Burp Suite (generates new CA)

**Security Note:** Installing a CA certificate allows full HTTPS interception. Only do this on test devices, never on your primary personal device.
