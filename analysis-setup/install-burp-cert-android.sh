#!/bin/bash
#
# Install Burp CA Certificate to Android System
# Works with unlocked bootloader devices and custom ROMs
#
# Usage: ./install-burp-cert-android.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║    Install Burp CA Certificate to Android System         ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

CERT_DER="burp-ca-cert.der"

# Check if certificate exists
if [ ! -f "$CERT_DER" ]; then
    echo -e "${RED}Error: $CERT_DER not found!${NC}"
    echo ""
    echo -e "${YELLOW}Please export the certificate from Burp Suite:${NC}"
    echo "  1. Open Burp Suite"
    echo "  2. Go to: Proxy → Proxy settings"
    echo "  3. Click: 'Import / export CA certificate'"
    echo "  4. Select: 'Export Certificate in DER format'"
    echo "  5. Save as: burp-ca-cert.der (in this directory)"
    echo ""
    exit 1
fi

echo -e "${GREEN}[✓] Found certificate: $CERT_DER${NC}"

# Check if ADB is installed
if ! command -v adb &> /dev/null; then
    echo -e "${RED}Error: ADB not found!${NC}"
    echo ""
    echo -e "${YELLOW}Install with:${NC}"
    echo "  macOS:  brew install android-platform-tools"
    echo "  Linux:  sudo apt install adb"
    echo ""
    exit 1
fi

echo -e "${GREEN}[✓] ADB is installed${NC}"

# Check if device is connected
DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l)
if [ "$DEVICES" -eq 0 ]; then
    echo -e "${RED}Error: No Android device connected!${NC}"
    echo ""
    echo -e "${YELLOW}Please:${NC}"
    echo "  1. Connect your Android device via USB"
    echo "  2. Enable 'Developer Options' (Settings → About → Tap Build number 7x)"
    echo "  3. Enable 'USB Debugging' (Settings → Developer options)"
    echo "  4. Accept the USB debugging prompt on your device"
    echo ""
    exit 1
fi

echo -e "${GREEN}[✓] Android device connected${NC}"
echo ""

# Convert certificate to PEM format
echo -e "${BLUE}[1/6] Converting certificate to PEM format...${NC}"
openssl x509 -inform DER -in "$CERT_DER" -out burp-ca-cert.pem
echo -e "${GREEN}[✓] Certificate converted${NC}"

# Get certificate hash for Android
echo -e "${BLUE}[2/6] Calculating certificate hash...${NC}"
HASH=$(openssl x509 -inform PEM -subject_hash_old -in burp-ca-cert.pem | head -1)
cat burp-ca-cert.pem > ${HASH}.0

echo -e "${GREEN}[✓] Certificate file: ${HASH}.0${NC}"
echo ""

# Try to get root access
echo -e "${BLUE}[3/6] Attempting to get root access...${NC}"
adb root 2>&1 | tee /tmp/adb_root.log

if grep -q "cannot run as root" /tmp/adb_root.log; then
    echo -e "${RED}[✗] Unable to get root via ADB${NC}"
    echo ""
    echo -e "${YELLOW}Your device doesn't support 'adb root'.${NC}"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  1. If rooted with Magisk: Use Method 3 from documentation"
    echo "  2. Flash a userdebug or eng ROM build"
    echo "  3. Some custom ROMs have 'Root debugging' in Developer Options"
    echo "  4. Install as user certificate (works for browsers but not all apps)"
    echo ""
    echo -e "${BLUE}Install as user certificate instead? (y/n)${NC}"
    read -p "> " install_user
    
    if [[ "$install_user" == "y" ]]; then
        echo ""
        echo -e "${BLUE}Installing as user certificate...${NC}"
        adb push ${HASH}.0 /sdcard/Download/burp-cert.crt
        echo ""
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                           ║${NC}"
        echo -e "${GREEN}║       Certificate Copied to Device Downloads!             ║${NC}"
        echo -e "${GREEN}║                                                           ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}  MANUAL INSTALLATION REQUIRED ON YOUR DEVICE${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${BLUE}Step-by-step instructions:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} On your Android device, open ${BLUE}Settings${NC}"
        echo ""
        echo -e "  ${GREEN}2.${NC} Navigate to: ${BLUE}Security${NC} (or ${BLUE}Security & Privacy${NC})"
        echo ""
        echo -e "  ${GREEN}3.${NC} Scroll down and tap: ${BLUE}Encryption & credentials${NC}"
        echo "     (May also be called 'More security settings' or 'Advanced')"
        echo ""
        echo -e "  ${GREEN}4.${NC} Tap: ${BLUE}Install a certificate${NC}"
        echo ""
        echo -e "  ${GREEN}5.${NC} Select: ${BLUE}CA certificate${NC}"
        echo "     (You may see a warning - tap 'Install anyway')"
        echo ""
        echo -e "  ${GREEN}6.${NC} Tap the ${BLUE}☰ menu${NC} (three lines) and select ${BLUE}Downloads${NC}"
        echo ""
        echo -e "  ${GREEN}7.${NC} Find and tap: ${BLUE}burp-cert.crt${NC}"
        echo ""
        echo -e "  ${GREEN}8.${NC} Enter a name (suggested): ${BLUE}Burp CA${NC}"
        echo ""
        echo -e "  ${GREEN}9.${NC} Tap ${BLUE}OK${NC} to confirm installation"
        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${BLUE}After installation:${NC}"
        echo "  • Verify: Settings → Security → Trusted credentials → USER tab"
        echo "  • Connect to MitM-Pi WiFi and test with: http://example.com"
        echo ""
        echo -e "${YELLOW}Note:${NC} User certificates work for browsers (Chrome, Firefox)"
        echo "      but many apps ignore them on Android 7+"
        echo ""
        echo -e "${BLUE}For full app coverage, you'll need:${NC}"
        echo "  • Root access (flash Magisk)"
        echo "  • Or a ROM with 'adb root' support"
        echo ""
        exit 0
    else
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}[✓] Root access granted${NC}"

# Remount system as read-write
echo -e "${BLUE}[4/6] Remounting system partition...${NC}"
adb remount

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}[!] Remount failed, trying alternative method...${NC}"
    adb shell mount -o rw,remount /system || {
        echo -e "${RED}[✗] Unable to remount system partition${NC}"
        exit 1
    }
fi

echo -e "${GREEN}[✓] System partition mounted as read-write${NC}"

# Push certificate to system
echo -e "${BLUE}[5/6] Installing certificate to system...${NC}"
adb push ${HASH}.0 /system/etc/security/cacerts/

if [ $? -ne 0 ]; then
    echo -e "${RED}[✗] Failed to push certificate${NC}"
    exit 1
fi

# Set proper permissions
adb shell chmod 644 /system/etc/security/cacerts/${HASH}.0
adb shell chown root:root /system/etc/security/cacerts/${HASH}.0 2>/dev/null || true

echo -e "${GREEN}[✓] Certificate installed with proper permissions${NC}"

# Verify installation
echo -e "${BLUE}[6/6] Verifying installation...${NC}"
adb shell ls -la /system/etc/security/cacerts/${HASH}.0

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║          Certificate Successfully Installed!              ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Rebooting device for changes to take effect...${NC}"
adb reboot

echo ""
echo -e "${GREEN}Done!${NC} Your device is rebooting."
echo ""
echo -e "${BLUE}After reboot:${NC}"
echo "  1. Connect to MitM-Pi WiFi"
echo "  2. Browse to https://example.com"
echo "  3. Should see NO certificate warnings"
echo "  4. Check Burp Suite → Proxy → HTTP history for decrypted traffic"
echo ""
echo -e "${BLUE}Verify installation:${NC}"
echo "  Settings → Security → Trusted credentials → SYSTEM tab"
echo "  Look for: PortSwigger CA"
echo ""
