# Kali Linux Installation on Raspberry Pi 5

This guide covers the complete installation process for Kali Linux ARM64 on the Raspberry Pi 5, including headless setup via SSH.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Download Kali ARM Image](#download-kali-arm-image)
3. [Flash the Image](#flash-the-image)
4. [Initial Boot](#initial-boot)
5. [Finding the Pi's IP Address](#finding-the-pis-ip-address)
6. [First SSH Connection](#first-ssh-connection)
7. [Initial Configuration](#initial-configuration)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Hardware
- Raspberry Pi 5 (4GB or 8GB RAM recommended)
- MicroSD card (32GB minimum, 64GB recommended)
- MicroSD card reader
- Ethernet cable
- Network with DHCP (router/switch)
- Power supply (official RPi 5 power supply recommended - 5.1V/5A USB-C)

### Software (macOS)
- [Raspberry Pi Imager](https://www.raspberrypi.com/software/) (official imaging tool)
- Terminal access
- Network scanning tools (optional but helpful):
  ```bash
  # Install via Homebrew
  brew install nmap
  brew install arp-scan
  ```

## Download Kali ARM Image

### Official Kali Downloads

1. Visit the [Kali Linux ARM Images page](https://www.kali.org/get-kali/#kali-arm)

2. Download the **Raspberry Pi (64-bit)** image:
   - Look for: `kali-linux-YYYY.X-raspberry-pi-arm64.img.xz`
   - Example: `kali-linux-2026.1-raspberry-pi-arm64.img.xz`
   - File size: ~2-3GB compressed

3. Verify the SHA256 checksum (optional but recommended):
   ```bash
   cd ~/Downloads
   shasum -a 256 kali-linux-2026.1-raspberry-pi-arm64.img.xz
   # Compare with checksum on Kali website
   ```

### Image Details

- **Compressed format:** .xz
- **Extracted size:** ~8-10GB
- **Default filesystem:** ext4
- **Architecture:** ARM64 (aarch64)

## Flash the Image

### Using Raspberry Pi Imager (Recommended)

1. **Launch Raspberry Pi Imager**
   ```bash
   # Or open from Applications
   open -a "Raspberry Pi Imager"
   ```

2. **Choose Device**
   - Click "CHOOSE DEVICE"
   - Select "Raspberry Pi 5"

3. **Choose OS**
   - Click "CHOOSE OS"
   - Scroll down to "Use custom"
   - Navigate to `~/Downloads/kali-linux-2026.1-raspberry-pi-arm64.img.xz`
   - Select the .xz file (no need to extract it first)

4. **Choose Storage**
   - Insert your MicroSD card
   - Click "CHOOSE STORAGE"
   - Select your MicroSD card (be careful to select the correct device!)

5. **Customize Settings (If Available)**
   - **Note:** The "Customize" option may be grayed out for Kali images
   - This is normal - Kali images come pre-configured
   - You'll configure hostname, SSH, and WiFi after first boot

6. **Write the Image**
   - Click "NEXT"
   - Confirm you want to erase the SD card
   - Click "YES"
   - Enter your macOS password if prompted
   - Wait for writing and verification to complete (5-15 minutes)

7. **Eject the SD Card**
   - Click "CONTINUE" when done
   - Safely eject the SD card

### Alternative: Command Line (Advanced)

If you prefer the command line:

```bash
# Extract the image
cd ~/Downloads
xz -d kali-linux-2026.1-raspberry-pi-arm64.img.xz

# Identify your SD card
diskutil list
# Look for your SD card (e.g., /dev/disk4)

# Unmount the disk (replace diskN with your disk number)
diskutil unmountDisk /dev/diskN

# Write the image (this will take several minutes)
sudo dd if=kali-linux-2026.1-raspberry-pi-arm64.img of=/dev/rdiskN bs=4m status=progress

# Eject the card
diskutil eject /dev/diskN
```

## Initial Boot

### Hardware Setup

1. **Insert the flashed MicroSD card** into the Raspberry Pi 5
2. **Connect ethernet cable** from Pi to your network (router/switch)
3. **Connect power** (official USB-C power supply)
4. **Wait 2-3 minutes** for first boot
   - First boot takes longer as the system expands the filesystem
   - You should see activity LEDs blinking on the Pi
   - The ethernet port LED should be active (link light)

### What's Happening During First Boot

- Filesystem expansion to use full SD card capacity
- Initial system configuration
- Network interface initialization (DHCP request)
- SSH service starting (enabled by default!)

## Finding the Pi's IP Address

Kali Linux ARM images have **SSH enabled by default**, but you need to find the Pi's IP address first.

### Method 1: Network Scan with arp-scan (Fastest)

**Install arp-scan** (if not already installed):
```bash
brew install arp-scan
```

**Scan your local network:**
```bash
# Replace en0 with your network interface if different
sudo arp-scan -I en0 --localnet
```

**Look for entries matching Raspberry Pi**:
- MAC prefix: `2c:cf:67` (Raspberry Pi Foundation)
- MAC prefix: `b8:27:eb`, `dc:a6:32`, `e4:5f:01` (older Pi models)
- Example output:
  ```
  192.168.50.235  2c:cf:67:92:9c:4b  (Unknown)
  ```

### Method 2: Nmap Scan

**Install nmap** (if not already installed):
```bash
brew install nmap
```

**Quick host discovery:**
```bash
# Adjust subnet to match your network (192.168.1.0/24, 192.168.50.0/24, etc.)
nmap -sn 192.168.50.0/24
```

**More detailed scan with SSH detection:**
```bash
# Scan for open SSH ports
nmap -p 22 --open 192.168.50.0/24
```

**OS fingerprinting** (may need sudo):
```bash
sudo nmap -O 192.168.50.0/24 | grep -B 5 "Linux"
```

### Method 3: mDNS/Bonjour Hostname

Kali responds to its hostname:

```bash
# Default Kali hostname on RPi
ssh kali@kali-raspberrypi
# or
ping kali-raspberrypi
```

**Note:** Depending on your network, you may be able to use `kali-raspberrypi.local` (with .local suffix), but on many networks the hostname alone works. Test both to see which works on your setup.

### Method 4: Check Router DHCP Leases

1. Log into your router's admin interface
2. Navigate to DHCP client list / connected devices
3. Look for:
   - Hostname: `kali`, `kali-raspberry-pi`, or similar
   - MAC address: `2c:cf:67:xx:xx:xx`
   - Recently connected device

### Method 5: ARP Cache Inspection

```bash
# After the Pi has been on the network for a minute
arp -a | grep -i "2c:cf:67\|b8:27:eb\|dc:a6:32\|e4:5f:01"
```

### Method 6: Watch Network Traffic

```bash
# Monitor for new DHCP requests
sudo tcpdump -i en0 -n port 67 or port 68
# Power cycle the Pi and watch for DHCP DISCOVER/REQUEST
```

## First SSH Connection

### Default Credentials

Kali Linux ARM comes with default credentials:

- **Username:** `kali`
- **Password:** `kali`
- **Root password:** `toor` (if needed)

⚠️ **Important:** Change these immediately after first login!

### Connect via SSH

Once you've found the IP address (e.g., 192.168.50.235):

```bash
ssh kali@192.168.50.235
```

**On first connection:**
- You'll see a warning about host authenticity
- Type `yes` to continue
- Enter password: `kali`

**Example:**
```
$ ssh kali@192.168.50.235
The authenticity of host '192.168.50.235 (192.168.50.235)' can't be established.
ED25519 key fingerprint is SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.50.235' (ED25519) to the list of known hosts.
kali@192.168.50.235's password: [type: kali]

Linux kali 6.1.0-kali7-arm64 #1 SMP Debian 6.1.20-2kali1 (2023-05-12) aarch64

The programs included with the Kali GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Kali GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
┏━(kali㉿kali)-[~]
┗━$ 
```

## Initial Configuration

### 1. Change Default Password (Critical!)

```bash
# Change kali user password
passwd
# Enter current password: kali
# Enter new password (twice)
```

### 2. Change Root Password

```bash
# Switch to root
sudo su -
# or use default root password: toor

# Change root password
passwd
# Enter new password (twice)

# Exit root shell
exit
```

### 3. Update System

```bash
# Update package lists
sudo apt update

# Upgrade all packages (this may take a while on first run)
sudo apt full-upgrade -y

# Clean up
sudo apt autoremove -y
sudo apt autoclean
```

### 4. Set Hostname (Optional)

```bash
# Change hostname from 'kali' to something descriptive
sudo hostnamectl set-hostname mitm-pi

# Update /etc/hosts
sudo nano /etc/hosts
# Change: 127.0.1.1  kali
# To:     127.0.1.1  mitm-pi

# Reboot to apply
sudo reboot
```

### 5. Configure SSH Keys (Recommended)

From your macOS machine:

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy public key to Pi
ssh-copy-id kali@192.168.50.235

# Test key-based login
ssh kali@192.168.50.235
# Should connect without password
```

### 6. Verify Network Interfaces

```bash
# List all network interfaces
ip link show

# Check IP addresses
ip addr show
```

You should see:
- `eth0` - Built-in Ethernet
- `wlan0` - Built-in WiFi
- `lo` - Loopback

### 7. Check System Info

```bash
# Verify Kali version
cat /etc/os-release

# Check kernel version
uname -a

# View hardware info
lscpu
cat /proc/cpuinfo | grep -i "model name"

# Check memory
free -h

# Check disk space
df -h
```

## Troubleshooting

### SSH Connection Refused

**Problem:** `ssh: connect to host X.X.X.X port 22: Connection refused`

**Solutions:**
1. Verify the Pi has booted (wait 3-5 minutes)
2. Check if SSH is running on the Pi (connect monitor/keyboard):
   ```bash
   sudo systemctl status ssh
   sudo systemctl enable ssh --now
   ```
3. Check firewall rules:
   ```bash
   sudo ufw status
   # If active, allow SSH:
   sudo ufw allow ssh
   ```

### Cannot Find Pi on Network

**Problem:** No device found in scans

**Solutions:**
1. Verify ethernet link light is active
2. Try a different ethernet cable
3. Connect to a different network port on your router
4. Check DHCP is enabled on your router
5. Wait longer (first boot can take 5+ minutes)
6. Try connecting a monitor to see if it booted

### Wrong Password

**Problem:** `Permission denied (publickey,password)`

**Solutions:**
1. Verify you're using: username `kali`, password `kali`
2. Make sure Caps Lock is off
3. Try manually typing instead of pasting
4. If you changed the password and forgot it, you'll need to reflash

### Slow Performance

**Problem:** System is slow or unresponsive

**Solutions:**
1. Use a high-quality MicroSD card (Class 10, UHS-I or better)
2. Consider using an SSD via USB 3.0 for better performance
3. Increase swap space if low on RAM
4. Disable unnecessary services

### Filesystem Not Expanded

**Problem:** Only 8GB available on 64GB card

**Solutions:**
```bash
# Manually expand filesystem
sudo raspi-config
# Go to: Advanced Options → Expand Filesystem
# Or run manually:
sudo resize2fs /dev/mmcblk0p2
```

### SSH Too Slow

**Problem:** SSH connection is very slow to establish

**Solutions:**
```bash
# On the Pi, disable DNS lookup for SSH
sudo nano /etc/ssh/sshd_config
# Add or change to:
UseDNS no

# Restart SSH
sudo systemctl restart ssh
```

**On your Mac**, add to `~/.ssh/config`:
```
Host 192.168.50.*
    GSSAPIAuthentication no
```

## Optional: ALFA AWUS1900 Driver Installation

If you're using the ALFA AWUS1900 USB WiFi adapter for better performance and range:

📖 **See:** [ALFA AWUS1900 Driver Installation Guide](alfa-awus1900-driver.md)

**Quick install:**
```bash
sudo apt update
sudo apt install -y build-essential dkms git bc linux-headers-$(uname -r)
cd ~
git clone https://github.com/morrownr/8814au.git
cd 8814au
sudo ./install-driver.sh
# Answer 'n' to editing driver options
sudo reboot

# After reboot, verify
iw dev
# Should show both wlan0 and wlan1
```

**Note:** The built-in WiFi (wlan0) works fine for basic MITM. The ALFA adapter provides extended range and advanced features.

## Next Steps

Once you have SSH access and completed initial configuration:

1. ✅ (Optional) Install ALFA AWUS1900 driver if using external adapter
2. ✅ Continue to [Raspberry Pi Setup](../pi-setup/README.md) to configure the MITM environment
3. ✅ Copy and run setup scripts (hostapd, dnsmasq, routing)
4. ✅ Configure proxy on analysis machine
5. ✅ Start testing!

---

**Tips:**
- Always use the official RPi 5 power supply (5.1V/5A)
- Use a quality MicroSD card from reputable brands (SanDisk, Samsung)
- Keep your Kali system updated regularly
- Document any custom configurations
- Take SD card backups before major changes

**Security Reminder:**
- Change default passwords immediately
- Use SSH keys instead of passwords when possible
- Only expose SSH to trusted networks
- This device is for authorized testing only
