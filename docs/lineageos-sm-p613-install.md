# LineageOS Installation Guide for Samsung Galaxy Tab S6 Lite 2022 (SM-P613)

**Device:** Samsung Galaxy Tab S6 Lite 2022 (Qualcomm Snapdragon 720G)  
**Model:** SM-P613 (WiFi) / SM-P619 (LTE)  
**Codename:** gta4xlveu  
**LineageOS Version:** 22.2 (Android 15) - Unofficial  
**Developer:** daniml3  
**Last Updated:** 2026-04-20

---

## Overview

This guide covers installing LineageOS 22.2 on your existing SM-P613 tablet to enable system-level certificate installation for MITM pentesting. LineageOS avoids Samsung's Knox security framework that caused certificate trust issues with your previous Magisk setup.

**XDA Thread:** https://xdaforums.com/t/rom-unofficial-2022-model-lineageos-22-2-for-galaxy-tab-s6-lite-2022-qualcomm.4699445/

---

## What's Working

✅ **Fully Functional:**
- Audio
- Bluetooth
- Display
- WiFi
- Charging
- Location
- Encryption
- Camera
- S-Pen
- SELinux (Enforcing)
- LTE (on P619 model)

⚠️ **Known Issues:**
- Some S-Pen features may have limited support (azimuth direction)
- Minor UI alignment issues reported by some users

---

## Prerequisites

### Required Tools

**On macOS (your setup):**
- Android SDK Platform-Tools (adb and fastboot)
  ```bash
  brew install --cask android-platform-tools
  # Or download: https://developer.android.com/tools/releases/platform-tools
  ```
- **Heimdall** (Samsung flashing tool for macOS)
  ```bash
  # ARM64 build for Apple Silicon
  # Download from: https://github.com/fathonix/heimdall-osx-arm64
  # Or use original: https://github.com/Benjamin-Dobell/Heimdall
  ```

**Alternative: Use Odin on Windows (if available):**
- Odin v3.14.1: https://xdaforums.com/t/patched-odin-3-13-1.3762572/

### Required Files

Download all files before starting:

1. **LineageOS ROM:** `lineage-22.2-*-UNOFFICIAL-gta4xlveu.zip`
   - https://github.com/danielml3/releases/releases

2. **LineageOS Recovery:** `lineage-22.2-*-recovery-gta4xlveu.img`
   - Same link as above

3. **Patched vbmeta:** `vbmeta.img.tar`
   - Same link as above

4. **GApps (Optional):** MindTheGapps for Android 15
   - https://github.com/MindTheGapps/15.0.0-arm64/releases
   - Download: `MindTheGapps-15.0.0-arm64-*.zip`

5. **Root Access (for system certificates) - Choose ONE:**
   
   **Option A: Magisk (Recommended - easier):**
   - Download latest Magisk APK: https://github.com/topjohnwu/Magisk/releases
   - Rename `.apk` to `.zip` for sideloading in recovery
   
   **Option B: LineageOS su add-on (if available):**
   - Check developer's GitHub releases: https://github.com/danielml3/releases/releases
   - Look for file named like: `addonsu-*-arm64-signed.zip`
   - Note: May not be available for all unofficial builds

---

## Installation Process

### Step 0: Backup Your Data

⚠️ **CRITICAL: Unlocking the bootloader wipes all data!**

```bash
# Backup via ADB (if already unlocked)
adb backup -all -f backup-$(date +%Y%m%d).ab

# Or use Samsung Smart Switch on another computer
# Or manually copy files via USB
```

---

### Step 1: Unlock Bootloader

**Enable Developer Options:**
1. Go to **Settings → About tablet**
2. Tap **Build number** 7 times
3. Go back to **Settings → Developer options**
4. Enable **OEM unlocking**
5. Enable **USB debugging**

**Unlock Bootloader:**
1. Power off tablet
2. Boot to Download Mode:
   - Hold **Volume Down + Volume Up** while connecting USB cable
   - Press **Volume Up** to confirm unlock warning

3. **Using Heimdall (macOS):**
   ```bash
   # Check device detected
   heimdall detect
   
   # Unlock bootloader (this wipes data!)
   # Note: Heimdall may not have unlock command, use Odin if possible
   ```

4. **Using Odin (Windows - Recommended):**
   - Download Mode should show "OEM Unlock" available
   - The unlock happens automatically on first boot
   - Device will factory reset

5. **Complete setup:**
   - Go through initial Android setup
   - Re-enable **Developer options** and **USB debugging**
   - Verify OEM unlock is still enabled

---

### Step 2: Install LineageOS Recovery and Patched vbmeta

**Boot to Download Mode:**
- Power off → Hold **Volume Down + Volume Up** + connect USB

**Using Odin (Windows - Easier):**
1. Open Odin v3.14.1
2. Click **AP** → Select `lineage-22.2-*-recovery-gta4xlveu.img`
3. Click **USERDATA** → Select `vbmeta.img.tar`
4. Ensure **Auto Reboot** is UNCHECKED
5. Click **Start**
6. Wait for "PASS" message
7. **Manually boot to recovery:**
   - Unplug USB
   - Hold **Volume Down + Power** to force shutdown
   - Hold **Volume Up + Power** until LineageOS logo appears
   - Release when you see LineageOS Recovery

**Using Heimdall (macOS):**
```bash
# Flash recovery
heimdall flash --RECOVERY lineage-22.2-*-recovery-gta4xlveu.img

# Flash patched vbmeta (if Heimdall supports it)
heimdall flash --VBMETA vbmeta.img

# Or extract vbmeta.img from vbmeta.img.tar first:
tar -xvf vbmeta.img.tar
heimdall flash --VBMETA vbmeta.img

# Boot to recovery manually:
# Power off, then hold Volume Up + Power
```

**⚠️ Important:** Do NOT reboot to system! Boot directly to recovery mode after flashing.

---

### Step 3: Install LineageOS ROM

**In LineageOS Recovery:**

1. **Factory Reset (Required for clean install):**
   - Select **Factory reset**
   - Select **Format data / factory reset**
   - Confirm by typing `yes`

2. **Install LineageOS ROM:**
   - Select **Apply update**
   - Select **Appl(for system certificates):**
   
   **Option A: Install Magisk (Recommended):**
   - Stay in recovery, select **Apply update → Apply from ADB**
   ```bash
   # On your Mac (rename Magisk APK to ZIP first):
   mv Magisk-v27.0.apk Magisk-v27.0.zip
   adb sideload Magisk-v27.0.zip
   ```
   
   **Option B: Install LineageOS su add-on (if available):**
   - Stay in recovery, select **Apply update → Apply from ADB**
   ```bash
   # On your Mac:
   adb sideload addonsu-22.2-arm64-signed

3. **Install Root Add-on (for system certificates):**
   - Stay in recovery, select **Apply update → Apply from ADB**
   
   ```bash
   # On your Mac:
   adb sideload lineage-22.2-arm64-su.zip
   ```

4. **Install GApps (Optional):**
   - If you need Google Play Store
   - Stay in recovery, select **Apply update → Apply from ADB**
   
   ```bash
   # On your Mac:
   adb sideload MindTheGapps-15.0.0-arm64-*.zip
   ```

5. **Reboot System:**
   - Select **Reboot system now**
   - First boot takes 5-10 minutes

---

### Step 4: Verify Installation

**After first boot:**

   ```

3. **If using Magisk:**
   - First boot will take longer (Magisk setup)
   - Open Magisk app and complete setup
   - Grant root permission when prompted

4  - Should show "LineageOS 22.2" and Android 15

2. **Verify root access:**
   ```bash
   adb shell
   su
   # Should grant root access if root add-on installed
   ```

3. **Check root in terminal app:**
   - Install Termux from F-Droid
   - Run: `su`
   - Should show `root@gta4xlveu:/ #`

---

## Post-Installation: System Certificate Setup

Now that you have LineageOS with root, installing system certificates is straightforward:

### Install Burp CA Certificate

**Export and prepare certificate:**
```bash
# On your Mac (in mitm-pi directory)
cd analysis-setup

# If you already have 9a5ba575.0, skip to installation
# Otherwise, generate from Burp Suite:
openssl x509 -inform DER -in burp-ca-cert.der -out burp-ca-cert.pem
HASH=$(openssl x509 -inform PEM -subject_hash_old -in burp-ca-cert.pem | head -1)
cat burp-ca-cert.pem > $HASH.0
echo "Certificate file: $HASH.0"
```

**Install via ADB root:**
```bash
# Enable ADB root access
adb root
adb remount

# Push certificate to system
adb push 9a5ba575.0 /system/etc/security/cacerts/
adb shell chmod 644 /system/etc/security/cacerts/9a5ba575.0
adb shell chown root:root /system/etc/security/cacerts/9a5ba575.0

# Set SELinux context
adb shell chcon u:object_r:system_security_cacerts_file:s0 /system/etc/security/cacerts/9a5ba575.0

# Reboot to apply
adb reboot
```

**Verify certificate:**
1. Settings → Security & privacy → More security settings → Trusted credentials
2. Go to **System** tab
3. Look for "PortSwigger CA" or "PortSwigger CA Certificate"
4. Certificate should be listed and enabled

---

## Testing Certificate with Apps

After certificate installation:

**Browser test:**
1. Connect tablet to MitM-Pi WiFi (SSID: MitM-Pi)
2. Open Chrome and visit: https://www.google.com
3. Should load without certificate warnings
4. Check Burp Suite - should see decrypted HTTPS traffic

**App test:**
1. Install Instagram, Twitter, or news apps from Play Store
2. Open app and browse content
3. Check Burp Suite for decrypted app traffic
4. If apps work without certificate errors → Success!

  - If using Magisk: Open Magisk app, verify it's installed correctly
  - If using su add-on: Reflash in recovery
  - Alternative: Flash Magisk instead (more reliable for unofficial builds)

## Troubleshooting

### Device won't boot after flashing
- **Solution:** Boot to recovery, factory reset, reinstall ROM
- Make sure you flashed patched vbmeta.img

### "Signature verification failed" in recovery
- **Solution:** You're in stock Samsung recovery, not LineageOS recovery
- Flash LineageOS recovery again via Odin/Heimdall

### Root not working
- **Solution:** Reflash root add-on (lineage-*-arm64-su.zip) in recovery
- Some builds may notnot installed or not working
- If using Magisk: Enable "ADB Root" in Magisk settings
- If using su add-on: Reinstall in recovery
- Alternative: Use Magisk which has better ADB root support
### Certificate not appearing in System tab
- **Solution:** Double-check SELinux context:
  ```bash
  adb shell ls -laZ /system/etc/security/cacerts/9a5ba575.0
  ```
- Should show: `u:object_r:system_security_cacerts_file:s0`

### Apps still showing certificate errors
- **Possible causes:**
  1. Certificate not in System tab (check Settings)
  2. App uses certificate pinning (bypass not possible)
  3. Wrong certificate hash (verify with `openssl x509 -subject_hash_old`)

### ADB root fails with "adbd cannot run as root in production builds"
- **Solution:** Root add-on not installed or not working
- Reinstall root add-on in recovery

---

## Keeping LineageOS Updated

**OTA Updates:**
- Settings → System → Updater
- LMagisk survives OTA updates automatically
6. Certificates persist across updthub.com/danielml3/releases/releases
- Updates can be installed directly from Updater app
- Root persists across OTA updates

**Manual Updates:**
1. Download new ROM from GitHub releases
2. Settings → System → Updater → ⋮ (menu) → Local update
3. Select downloaded .zip file
4. Updater will install and reboot
5. No need to reinstall root add-on or certificates

---Magisk/root):**
- ✅ Clean AOSP base without Samsung restrictions
- ✅ Direct system partition access
- ✅ `adb root` support via Magisk or su add-on
- ✅ Certificates installed in actual `/system` partition
- ✅ No Knox, no Samsung security complications
- ✅ Magisk provides additional features if needed
- ❌ Samsung Knox security framework
- ❌ Android 14 OEM-specific trust requirements
- ❌ Systemless modifications (sometimes don't work)

**New setup (LineageOS with root add-on):**
- ✅ Clean AOSP base without Samsung restrictions
- ✅ Direct system partition access
- ✅ `adb root` support out of the box
- ✅ Certificates installed in actual `/system` partition
- ✅ No Knox, no Samsung security complications

---

## Resources

### Official Links
- **XDA Thread:** https://xdaforums.com/t/rom-unofficial-2022-model-lineageos-22-2-for-galaxy-tab-s6-lite-2022-qualcomm.4699445/
- **Downloads (ROM + Recovery):** https://github.com/danielml3/releases/releases
- **Telegram Support:** https://t.me/lineagegta4xlve
- **Kernel Source:** https://github.com/gta4xlve-dev/android_kernel_samsung_gta4xlve
- **Device Source:** https://github.com/gta4xlve-dev/android_device_samsung_gta4xlveu

### Tools
- **Heimdall (macOS ARM64):** https://github.com/fathonix/heimdall-osx-arm64
- **Odin (Windows):** https://xdaforums.com/t/patched-odin-3-13-1.3762572/
- **Android Platform-Tools:** https://developer.android.com/tools/releases/platform-tools
- **GApps:** https://github.com/MindTheGapps/15.0.0-arm64/releases

---
Magisk or su
## Quick Reference Checklist

- [ ] **Prerequisites complete:**
  - [ ] Android SDK Platform-Tools installed
  - [ ] Heimdall or Odin ready
  - [ ] All files downloaded (ROM, Recovery, vbmeta, root add-on)
  - [ ] Data backed up

- [ ] **Bootloader unlocked:**
  - [ ] OEM unlocking enabled
  - [ ] Device unlocked in Download Mode
  - [ ] Factory reset completed
Magisk or su
- [ ] **LineageOS installed:**
  - [ ] LineageOS recovery flashed
  - [ ] Patched vbmeta flashed
  - [ ] Factory reset in recovery
  - [ ] ROM installed via ADB sideload
  - [ ] Root add-on installed
  - [ ] GApps installed (if desired)

- [ ] **System certificate installed:**
  - [ ] Certificate file prepared (9a5ba575.0)
  - [ ] Pushed to `/system/etc/security/cacerts/`
  - [ ] Permissions: 644, owner: root:root
  - [ ] SELinux context set correctly
  - [ ] Appears in Settings → Trusted credentials → System

- [ ] **Testing complete:**
  - [ ] Browser HTTPS works without warnings
  - [ ] Burp Suite shows decrypted traffic
  - [ ] Test apps work (Instagram, Twitter, etc.)
  - [ ] No certificate errors in apps

---

## Time Estimate

**Total time:** 2-3 hours

- Preparation and download: 30 minutes
- Bootloader unlock: 15 minutes
- LineageOS installation: 45 minutes
- Certificate setup: 15 minutes
- Testing and validation: 30 minutes

---

## Notes

- **Knox status:** Will trip Knox permanently (warranty void)
- **Updates:** Check XDA thread for new builds regularly
- **Support:** Ask in Telegram group or XDA thread
- **Compared to Pixel:** Slightly less community support, but works well for your use case
- **Cost:** $0 (using existing device vs. $300 for Pixel)

---

## Next Steps After Successful Installation

1. **Document your experience:**
   - Take screenshots of certificate in System tab
   - Note any quirks or issues encountered
   - Share in XDA thread to help others

2. **Update this guide:**
   - Add device-specific tips you learned
   - Document any troubleshooting steps needed
   - Note LineageOS build version used

3. **Test with engagement scenarios:**
   - Connect to MitM-Pi WiFi
   - Test various IoT apps
   - Verify certificate works across different app types
   - Document which apps work/don't work

4. **Keep updated:**
   - Join Telegram group for notifications
   - Check GitHub releases periodically
   - Install OTA updates as they come

---

## Revision History

- 2026-04-20: Initial guide created based on XDA thread and daniml3's instructions
- Based on LineageOS 22.2 builds as of April 2025
