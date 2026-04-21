# Android System Certificate Installer

Installs CA certificates as system-trusted certificates on Android 14+ devices with root access.

## Requirements

- Android device with `adb root` working (LineageOS or similar)
- macOS/Linux with `adb` and `openssl` installed
- CA certificate in PEM format

## Quick Start

### Install Burp Suite Certificate

```bash
# 1. Export certificate from Burp Suite as PEM (der format)
# 2. Convert to PEM if needed
openssl x509 -inform DER -in burp-ca-cert.der -out burp-ca-cert.pem

# 3. Run installer
./install-android-cert.sh burp-ca-cert.pem
```

### Install Any Certificate

```bash
./install-android-cert.sh /path/to/certificate.pem
```

## What It Does

1. **Generates certificate hash** using `openssl x509 -subject_hash_old`
2. **Pushes certificate** to device at `/data/local/tmp/{hash}.0`
3. **Creates overlay** with all system certs + your new cert
4. **Installs to user certificate store** at `/data/misc/user/0/cacerts-added/` (required for Chrome)
5. **Bind mounts** overlay to `/apex/com.android.conscrypt/cacerts` (system store)
6. **Restarts Android runtime** to activate certificate
7. **Verifies** installation was successful

**Important:** Chrome and many browsers only trust user certificates on Android 14+, so installing to both user and system stores is required for full compatibility.

## After Installation
  - **User tab**: Your certificate should appear here (required for Chrome)
  - **System tab**: Your certificate should also appear here (for system apps)
- Look for your certificate authority name (e.g., "PortSwigger CA")
**Verify in Settings:**
- Settings → Security & privacy → Encryption & credentials → Trusted credentials → System tab
- Look for your certificate authority name

**Test HTTPS Interception:**
- Configure proxy on device (if needed)
- Open System Certificate Does NOT Persist After Reboot

The system certificate bind mount is lost on reboot (user certificate persists)
## Important Notes

### ⚠️ Certificate Does NOT Persist After Reboot

The bind mount is lost on reboot. You must re-run the script after every reboot:
System Certificate Persist?

Android 14+ uses APEX modules for system certificates, and the bind mount is lost on reboot. The user certificate does persist. Proper system certificate persistence requires:
- Magisk with the AlwaysTrustUserCerts module, OR
- Custom SELinux policy to allow init scripts, OR
- Manual re-installation after each reboot

Since Magisk wouldn't install on this LineageOS build, manual re-installation is the simplest solution. However, the user certificate persists and is sufficient for Chrome and most apps
- Magisk with the AlwaysTrustUserCerts module, OR
- Custom SELinux policy to allow init scripts, OR
- Manual re-installation after each reboot

Since Magisk wouldn't install on this LineageOS build, manual re-installation is the simplest solution.

## Convert Certificate Formats

### DER to PEM
```bash
openssl x509 -inform DER -in cert.der -out cert.pem
```

### Extract from PKCS12
```bash
openssl pkcs12 -in cert.p12 -out cert.pem -nokeys
```

### From CRT
```bash
openssl x509 -inform DER -in cert.crt -out cert.pem
# or if already PEM
cp cert.crt cert.pem
```

## Troubleshooting

### "Error: No such file or directory"
- Ensure device is connected: `adb devices`
- Enable root: `adb root`

### "Error: Failed to mount certificate overlay"
- Check APEX path exists: `adb shell "ls /apex/com.android.conscrypt/cacerts/"`
- Verify overlay created: `adb shell "ls /data/local/tmp/cacerts_overlay/ | wc -l"`

### Certificate doesn't show in Settings
- Restart Android: `adb shell "killall system_server"`
- Or reboot device: `adb reboot`

### Apps still don't trust certificate
- Some apps use certificate pinning (can't be bypassed with system cert)
- Check app's network security config
- Use Frida/Objection to bypass pinning

## Uninstall

To remove the certificate:

```bash
adb root
adb reboot
```

The certificate is only mounted, not permanently installed, so a reboot removes it.

## Technical Detailss

- **User certificates**: `/data/misc/user/0/cacerts-added/` (persists across reboots, required for Chrome)
- **System certificates (old)**: `/system/etc/security/cacerts/` (Android 13 and below)
- **System certificates (new)**: `/apex/com.android.conscrypt/cacerts/` (Android 14+, requires bind mount)
- **Old location** (Android 13 and below): `/system/etc/security/cacerts/`
- **New location** (Android 14+): `/apex/com.android.conscrypt/cacerts/`
**User certificate**: Copied to `/data/misc/user/0/cacerts-added/` (persists, trusted by Chrome)
2. **System certificate via APEX**:
   - APEX modules are read-only
   - Create temporary directory with all certs + new cert
   - Bind mount temporary directory over APEX cert directory
   - Bind mount only exists in current mount namespace
   - Reboot clears mount (but user cert persists)rectory with all certs + new cert
3. Bind mount temporary directory over APEX cert directory
4. Bind mount only exists in current mount namespace
5. Reboot clears mount

### Proper Solution

The [AlwaysTrustUserCerts Magisk module](https://github.com/NVISOsecurity/AlwaysTrustUserCerts) handles:
- Automatic installation on boot
- Injection into Zygote process
- Propagation to all child processes
- Monitoring and re-injection on crashes

## Related Documentation

- [NVISO Blog: Intercepting traffic on Android with Mainline and Conscrypt](https://blog.nviso.eu/2025/06/05/intercepting-traffic-on-android-with-mainline-and-conscrypt/)
- [HTTPToolkit: Installing System CA on Android 14](https://httptoolkit.com/blog/android-14-install-system-ca-certificate/)
- [AlwaysTrustUserCerts Module](https://github.com/NVISOsecurity/AlwaysTrustUserCerts)
