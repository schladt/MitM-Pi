# ALFA AWUS1900 Driver Installation for Kali Linux ARM64

## Troubleshooting Guide for ALFA AWUS1900 on Raspberry Pi 5

The ALFA AWUS1900 uses a Realtek RTL8814AU chipset which requires specific drivers that may not be included in Kali Linux ARM by default.

## Diagnosis Steps

### 1. Check USB Detection

First, verify the device is detected at the USB level:

```bash
# List USB devices
lsusb

# Look for Realtek device (should show vendor ID 0bda)
# Example output: Bus 001 Device 003: ID 0bda:8813 Realtek Semiconductor Corp.

# More detailed USB info
lsusb -v | grep -A 10 Realtek

# Check kernel messages
dmesg | tail -30

# Check if device appeared in USB subsystem
dmesg | grep -i "usb\|realtek\|8814"
```

### 2. Check Current Wireless Interfaces

```bash
# List wireless interfaces
iw dev

# List all network interfaces
ip link show

# Check for wireless extensions
iwconfig
```

### 3. Check Loaded Modules

```bash
# List loaded wireless modules
lsmod | grep 8814
lsmod | grep rtl
lsmod | grep wireless

# Check available modules
modinfo rtl8814au 2>/dev/null || echo "Driver not installed"
```

## Common Issues

### Issue 1: Driver Not Installed

If `lsusb` shows the device but no wireless interface appears, the driver is missing.

### Issue 2: Power Issue

The ALFA AWUS1900 requires significant power. The Pi 5 USB ports should provide enough, but try:
- Using a powered USB hub
- Different USB port (use USB 3.0 blue ports)
- Check power supply is adequate (5.1V/5A official adapter)

### Issue 3: Incompatible Driver

Some pre-compiled drivers may not work with Kali ARM64 kernel.

## Driver Installation

### Method 1: Install Pre-built Driver (Fastest)

```bash
# Update package lists
sudo apt update

# Try installing Realtek drivers from Kali repos
sudo apt install realtek-rtl88xxau-dkms -y

# Or try general Realtek driver package
sudo apt install rtl8814au-dkms -y

# Reboot after installation
sudo reboot
```

### Method 2: Compile Driver from Source (Most Reliable)

The RTL8814AU driver needs to be compiled for ARM64:

```bash
# Install build dependencies
sudo apt update
sudo apt install -y \
    build-essential \
    dkms \
    git \
    bc \
    linux-headers-$(uname -r)

# Clone the driver repository
cd ~
git clone https://github.com/morrownr/8814au.git

# Enter directory
cd 8814au

# Check if ARM64 is supported
grep -i "arm64\|aarch64" Makefile

# Install driver
sudo ./install-driver.sh

# If install script fails, try manual installation
sudo make clean
sudo make ARCH=arm64
sudo make install
sudo modprobe 8814au

# Reboot
sudo reboot
```

### Method 3: Alternative Driver Repository

If the above doesn't work, try this alternative:

```bash
cd ~
git clone https://github.com/aircrack-ng/rtl8814au.git
cd rtl8814au

# Compile and install
sudo make ARCH=arm64
sudo make install
sudo modprobe 8814au

sudo reboot
```

## Verification After Driver Installation

```bash
# Check if module loaded
lsmod | grep 8814au

# Check if wireless interface appeared
iw dev
iwconfig

# Should see wlan1 or similar
ip link show
```

## Alternative: Use Built-in WiFi

If the ALFA adapter continues to have issues, the Raspberry Pi 5's built-in WiFi (wlan0) can be used for the AP:

```bash
# The built-in WiFi should work without additional drivers
iw dev
# Should show wlan0

# Use wlan0 in the setup
# The setup.sh script will auto-detect it
```

**Note:** Built-in WiFi limitations:
- May have lower range than ALFA
- May not support monitor mode (needed for some advanced features)
- Should still work fine for basic MITM

## Power Consumption Check

The AWUS1900 can draw significant power:

```bash
# Check USB power delivery
# On Pi, check dmesg for power issues
dmesg | grep -i "power\|current"

# If seeing power errors:
# 1. Use official 5.1V/5A power supply
# 2. Use powered USB hub
# 3. Try different USB port
```

## Known Working Configuration

For Raspberry Pi 5 + Kali ARM64 + AWUS1900:
- Use USB 3.0 port (blue port)
- Official Pi 5 power supply (5.1V/5A)
- Driver: morrownr/8814au repository
- Kernel headers must match running kernel

## If All Else Fails

### Option 1: Use Different Adapter

Consider these alternatives with better Linux support:
- ALFA AWUS036ACM (MediaTek MT7612U - better driver support)
- ALFA AWUS036ACHM (MediaTek - excellent Linux support)
- Panda PAU09 (Ralink - good compatibility)

### Option 2: Use Built-in WiFi for Now

The setup script will work with built-in WiFi (wlan0):
```bash
cd ~/pi-setup
sudo ./setup.sh
# It will auto-detect wlan0 and use it
```

Can test MITM functionality while troubleshooting ALFA adapter.

## Diagnostic Commands Summary

Run these in order to diagnose:

```bash
# 1. USB detection
echo "=== USB Detection ==="
lsusb | grep -i realtek

# 2. Kernel messages
echo "=== Kernel Messages ==="
dmesg | grep -i "usb\|realtek\|8814" | tail -20

# 3. Wireless interfaces
echo "=== Wireless Interfaces ==="
iw dev
iwconfig

# 4. Loaded modules
echo "=== Loaded Modules ==="
lsmod | grep -E "8814|rtl|wireless"

# 5. Power status
echo "=== Power Status ==="
dmesg | grep -i "power\|current" | tail -10
```

## Next Steps

1. Run the diagnostic commands above via SSH
2. Share the output to determine exact issue
3. Install appropriate driver based on findings
4. Or proceed with built-in WiFi if ALFA troubleshooting takes time

---

**Remember:** The built-in WiFi on Pi 5 is quite capable for basic MITM work. The ALFA adapter is nice-to-have for extended range and advanced features, but not strictly required.
