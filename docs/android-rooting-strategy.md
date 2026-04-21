# Android Rooting Strategy for MITM Testing

## Overview

This document outlines the strategy for preparing an Android device with system-level certificate installation capabilities for MITM penetration testing. User-level certificates are insufficient for modern Android apps (Android 7+ defaults to ignoring user certificates).

**Last Updated:** 2026-04-20

---

## Why System Certificates Are Required

### The Problem with User Certificates
- **Android 7+ behavior:** Apps ignore user certificates by default unless explicitly configured
- **Network Security Config:** Most production apps specify `cleartextTrafficPermitted="false"` and only trust system certificates
- **Real-world impact:** User certificates work in browsers but fail in 90%+ of apps
- **Previous engagement:** Samsung Galaxy S6 Lite with Magisk + user cert insufficient

### System Certificate Requirements
- Must be installed in `/system/etc/security/cacerts/`
- Requires root access or unlocked bootloader
- Must have correct:
  - Filename: `<subject_hash_old>.0` (e.g., `9a5ba575.0`)
  - Permissions: `644` (rw-r--r--)
  - SELinux context: `system_security_cacerts_file:s0`
  - Owner: `root:root`

---

## Device Selection Criteria

### Priority 1: Excellent LineageOS Support
Devices with official LineageOS support are the gold standard for pentesting.

**Recommended Current Devices (2026):**
1. **Google Pixel 7a / 8 / 8a** (codename: lynx, shiba, akita)
   - Best LineageOS support
   - Regular updates
   - Easy bootloader unlock
   - ~$300-500 USD
   
2. **OnePlus 9 / 10 / 11** (codename: lemonade, martini, salami)
   - Excellent custom ROM support
   - Fast performance
   - Easy unlock process
   - ~$250-450 USD

3. **Xiaomi Poco F5 / F5 Pro** (codename: marble, mondrian)
   - Good community support
   - Budget-friendly (~$200-350)
   - Unlocking requires Mi account + waiting period (7 days)

4. **Samsung Galaxy S10 / S20 FE** (codename: beyond*, r8*)
   - Widespread availability
   - Good hardware
   - **WARNING:** Snapdragon models only (Exynos harder to unlock)
   - May trip Knox (permanently voids warranty)

### Priority 2: Active Community & Custom ROM Options
- Check XDA Developers forums for device-specific activity
- Verify LineageOS official builds at: https://download.lineageos.org/devices
- Look for recent kernel updates and security patches

### Devices to Avoid
- **Huawei** (bootloader unlock banned since 2018)
- **Carrier-locked devices** (especially US carriers)
- **Samsung Exynos in some regions** (locked bootloaders)
- **Devices without recent ROM updates** (security risk)

---

## Rooting Methods Comparison

### Method 1: LineageOS + Root Add-on (Recommended)

**Pros:**
- Clean, stable, AOSP-based ROM
- Official root add-on maintained by LineageOS team
- Regular security updates
- Best balance of stability and features
- System certificate installation straightforward

**Cons:**
- Requires bootloader unlock (wipes device)
- Not all devices officially supported
- Initial setup takes 1-2 hours

**Process Overview:**
1. Unlock bootloader (manufacturer-specific process)
2. Install custom recovery (LineageOS Recovery recommended)
3. Flash LineageOS ROM
4. Flash LineageOS root add-on
5. Install Magisk app for root management (optional but recommended)

**Best For:** Dedicated pentesting device, professional use

---

### Method 2: Stock ROM + Magisk (Previous Attempt)

**Pros:**
- Keeps manufacturer ROM and features
- Systemless root (can hide root from apps)
- Relatively simple process
- Can be reversed easier than custom ROM

**Cons:**
- **Android 14+ challenges:** Certificate trust store changes
- **OEM restrictions:** Samsung Knox, Xiaomi anti-rollback
- **Update issues:** OTA updates often break root
- **Previous experience:** Certificate installed but not trusted by Android

**Previous Samsung Galaxy S6 Lite Issues (2026-04-16):**
- Magisk v30.7 installed successfully
- Certificate installed at `/system/etc/security/cacerts/9a5ba575.0`
- Correct permissions (644) and SELinux context
- **Problem:** Certificate didn't appear in Settings UI
- **Hypothesis:** Android 14 on Samsung may have additional certificate caching or trust requirements beyond file installation

**Process Overview:**
1. Unlock bootloader
2. Extract boot.img from firmware
3. Patch boot.img with Magisk
4. Flash patched boot via fastboot/Heimdall
5. Create Magisk module for certificate
6. **Additional step needed:** Investigate Android 14 certificate trust mechanisms

**Best For:** Keeping specific device/features, temporary root needs

---

### Method 3: GrapheneOS / DivestOS (Security-Focused)

**Pros:**
- Enhanced security features
- Privacy-focused
- Regular updates
- User certificate trust toggle (DivestOS)

**Cons:**
- Limited device support (Pixel only for GrapheneOS)
- Root not recommended (defeats security model)
- More complex certificate management

**Best For:** Privacy researchers, Pixel device owners

---

## Recommended Approach for Next Engagement

### Phase 1: Device Acquisition (Before Engagement)

**Option A: Buy Used Pentesting Device (Fastest)**
- **Device:** Google Pixel 7a or OnePlus 9
- **Budget:** $200-300 for used device
- **Time:** 2-3 hours setup
- **Justification:** Dedicated testing device, no personal data risk

**Option B: Use Existing Device (If Available)**
- Check LineageOS compatibility: https://wiki.lineageos.org/devices/
- Backup all data (bootloader unlock wipes device)
- Verify bootloader can be unlocked (check manufacturer site)

### Phase 2: Installation Process

**Recommended: LineageOS + Root Add-on**

**Day 1 (Setup):**
1. **Backup current device** (if reusing)
2. **Unlock bootloader**
   - Google Pixel: `fastboot flashing unlock`
   - OnePlus: Enable OEM unlocking, `fastboot oem unlock`
   - Xiaomi: Request unlock via Mi Unlock app (7-day wait)
   - Samsung: Enable OEM unlocking, flash via Odin/Heimdall
3. **Download LineageOS**
   - ROM: https://download.lineageos.org/devices
   - Recovery: LineageOS Recovery (included)
   - Root: Use Magisk (https://github.com/topjohnwu/Magisk/releases) or check for su add-on in device-specific builds
4. **Flash LineageOS via recovery**
   - Boot to recovery mode
   - Factory reset
   - Sideload/install LineageOS ROM
   - Sideload/install Magisk or su add-on for root
5. **Setup Android and verify root**
   - Install Magisk app (if using Magisk)
   - Install terminal app and test: `su`

**Day 1 (Certificate Installation):**
1. **Generate/export Burp CA certificate**
   - Follow existing guide: `docs/android-certificate-install.md`
   - Create properly named cert: `9a5ba575.0` (subject_hash_old)
2. **Install via ADB root method:**
   ```bash
   adb root
   adb remount
   adb push 9a5ba575.0 /system/etc/security/cacerts/
   adb shell chmod 644 /system/etc/security/cacerts/9a5ba575.0
   adb shell chown root:root /system/etc/security/cacerts/9a5ba575.0
   adb reboot
   ```
3. **Verify installation:**
   - Settings → Security → Trusted credentials → System
   - Certificate should appear with CN=PortSwigger CA
4. **Test with multiple apps:**
   - Chrome browser
   - System WebView
   - Instagram or similar popular app
   - Custom test app (if available)

---

## Alternative: Android 14 Certificate Trust Issues

If certificate installation succeeds but trust issues persist (as with Samsung S6 Lite):

### Investigation Steps
1. **Check Android 14 changes:**
   - Research certificate validation changes in AOSP
   - Check for additional certificate attributes required
   
2. **Verify certificate format:**
   ```bash
   # Ensure PEM format with proper structure
   openssl x509 -in 9a5ba575.0 -text -noout
   # Verify subject hash matches filename
   openssl x509 -subject_hash_old -in 9a5ba575.0 | head -1
   ```

3. **Try certificate bundle method:**
   - Some ROMs require certificates in specific bundle format
   - Check `/system/etc/security/cacerts/` for format examples
   
4. **Check for certificate caching:**
   ```bash
   # Clear system certificate cache
   adb shell rm -rf /data/system/users/0/cacerts-added
   adb shell rm -rf /data/misc/keychain/cacerts-added
   adb reboot
   ```

5. **Investigate Samsung-specific requirements:**
   - Knox security framework may add additional layers
   - Samsung may have custom certificate validation
   - Consider LineageOS instead of Samsung ROM

---

## Testing & Validation Checklist

After rooting and certificate installation:

- [ ] Root access works: `adb shell su -c id` returns `uid=0(root)`
- [ ] Certificate file exists with correct permissions
- [ ] Certificate appears in Settings → Security → Trusted credentials → System
- [ ] Certificate shows correct details (CN=PortSwigger CA or mitmproxy)
- [ ] Browser HTTPS works without warnings
- [ ] System WebView uses certificate (test with embedded browser in app)
- [ ] Third-party apps accept certificate (Instagram, Twitter, news apps)
- [ ] Burp/mitmproxy successfully decrypts app traffic
- [ ] OTA updates disabled (to preserve root)

---

## Documentation & Scripts to Create

After successful setup, document:

1. **Device-specific guide** (e.g., `docs/lineageos-pixel7a.md`)
   - Exact model and build numbers
   - Bootloader unlock steps
   - ROM and recovery versions used
   - Any device-specific quirks

2. **Automated certificate installation script**
   - Update `analysis-setup/install-burp-cert-android.sh`
   - Add LineageOS/root add-on detection
   - Handle Android 14+ certificate trust

3. **Testing validation script**
   - Automate checklist verification
   - Test with common apps
   - Generate report of successful/failed apps

---

## Budget Estimate

**Minimum setup:**
- Used Google Pixel 7a: $250-300
- Time investment: 3-4 hours initial setup
- No additional software costs (LineageOS is free)

**Total: ~$300 + 1 afternoon**

**Alternative if rush:**
- Newer Pixel 8a: ~$400-450 (better long-term support)
- OnePlus 11: ~$400 (flagship performance)

---

## Next Steps

1. **Decide on device:**
   - [ ] Buy dedicated Pixel 7a/8a for pentesting (~$300)
   - [ ] Use existing compatible device (check LineageOS support)
   
2. **Schedule setup time:**
   - [ ] Block 3-4 hours for initial setup
   - [ ] Prepare backups if reusing device
   - [ ] Download LineageOS and tools in advance

3. **Prepare environment:**
   - [ ] Install Android SDK platform-tools (adb/fastboot)
   - [ ] Download LineageOS ROM for chosen device
   - [ ] Download LineageOS root add-on
   - [ ] Export fresh Burp CA certificate

4. **Execute installation:**
   - [ ] Follow device-specific unlock guide
   - [ ] Flash LineageOS + root add-on
   - [ ] Install system certificate
   - [ ] Validate with checklist

5. **Document results:**
   - [ ] Create device-specific guide
   - [ ] Update android-certificate-install.md if needed
   - [ ] Add troubleshooting notes

---

## Resources

### Official Documentation
- LineageOS devices: https://wiki.lineageos.org/devices/
- LineageOS installation: https://wiki.lineageos.org/devices/<device>/install
- Android certificate docs: https://developer.android.com/privacy-and-security/security-config

### Community Resources
- XDA Developers: https://forum.xda-developers.com/
- Reddit /r/LineageOS: https://reddit.com/r/LineageOS
- Magisk documentation: https://topjohnwu.github.io/Magisk/

### Tools
- Android SDK Platform-Tools: https://developer.android.com/tools/releases/platform-tools
- Heimdall (Samsung): https://github.com/Benjamin-Dobell/Heimdall
- Mi Unlock (Xiaomi): https://en.miui.com/unlock/

---

## Revision History

- 2026-04-20: Initial document created based on previous Samsung S6 Lite experience
- Previous attempt: 2026-04-16 - Magisk on Samsung S6 Lite (Android 14) - certificate installed but not trusted
