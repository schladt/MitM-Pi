#!/bin/bash
#
# Install CA Certificate as System Certificate on Android 14+
# Uses bind mount approach to inject certificate into APEX module
#
# Usage: ./install-android-cert.sh <certificate-file>
# Example: ./install-android-cert.sh burp-ca-cert.pem
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No certificate file specified${NC}"
    echo "Usage: $0 <certificate-file>"
    echo "Example: $0 burp-ca-cert.pem"
    exit 1
fi

CERT_FILE="$1"

if [ ! -f "$CERT_FILE" ]; then
    echo -e "${RED}Error: Certificate file '$CERT_FILE' not found${NC}"
    exit 1
fi

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Android System Certificate Installer (Android 14+)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Generate certificate hash
echo -e "${YELLOW}[1/6]${NC} Generating certificate hash..."
CERT_HASH=$(openssl x509 -inform PEM -subject_hash_old -in "$CERT_FILE" | head -1)
CERT_NAME="${CERT_HASH}.0"
echo -e "${GREEN}✓${NC} Certificate hash: ${CERT_HASH}"
echo ""

# Step 2: Wait for device and enable root
echo -e "${YELLOW}[2/6]${NC} Connecting to device..."
adb wait-for-device
sleep 2
adb root > /dev/null 2>&1
sleep 2
echo -e "${GREEN}✓${NC} Device connected with root access"
echo ""

# Step 3: Push certificate to device
echo -e "${YELLOW}[3/6]${NC} Pushing certificate to device..."
adb push "$CERT_FILE" "/data/local/tmp/${CERT_NAME}" > /dev/null
adb shell "chmod 644 /data/local/tmp/${CERT_NAME}"
echo -e "${GREEN}✓${NC} Certificate uploaded as ${CERT_NAME}"
echo ""

# Step 4: Create certificate overlay
echo -e "${YELLOW}[4/6]${NC} Creating certificate overlay..."
adb shell "rm -rf /data/local/tmp/cacerts_overlay"
adb shell "mkdir -p /data/local/tmp/cacerts_overlay"

# Find APEX version
APEX_VERSION=$(adb shell "ls -d /apex/com.android.conscrypt@* | head -1" | sed 's/.*@//' | tr -d '\r')
echo -e "      APEX version: ${APEX_VERSION}"

# Copy all system certs + new cert
adb shell "cp /apex/com.android.conscrypt@${APEX_VERSION}/cacerts/* /data/local/tmp/cacerts_overlay/" 2>/dev/null || {
    echo -e "${RED}Error: Failed to copy system certificates${NC}"
    exit 1
}
adb shell "cp /data/local/tmp/${CERT_NAME} /data/local/tmp/cacerts_overlay/"
adb shell "chmod 644 /data/local/tmp/cacerts_overlay/*"

CERT_COUNT=$(adb shell "ls /data/local/tmp/cacerts_overlay/ | wc -l" | tr -d ' \r')
echo -e "${GREEN}✓${NC} Created overlay with ${CERT_COUNT} certificates"
echo ""

# Step 5: Install to user certificate store
echo -e "${YELLOW}[5/6]${NC} Installing certificate to user trust store..."
adb shell "mkdir -p /data/misc/user/0/cacerts-added"
adb shell "cp /data/local/tmp/${CERT_NAME} /data/misc/user/0/cacerts-added/${CERT_NAME}"
adb shell "chmod 644 /data/misc/user/0/cacerts-added/${CERT_NAME}"
adb shell "chown system:system /data/misc/user/0/cacerts-added/${CERT_NAME}"
echo -e "${GREEN}✓${NC} Certificate installed to user store"
echo ""

# Step 6: Bind mount overlay to APEX (system store)
echo -e "${YELLOW}[6/7]${NC} Installing certificate to system trust store..."

# Unmount if already mounted
adb shell "umount /apex/com.android.conscrypt/cacerts" 2>/dev/null || true

# Mount the new overlay
adb shell "mount -o bind,ro /data/local/tmp/cacerts_overlay /apex/com.android.conscrypt/cacerts" 2>/dev/null || {
    echo -e "${RED}Error: Failed to mount certificate overlay${NC}"
    exit 1
}

# Verify installation
if adb shell "ls /apex/com.android.conscrypt/cacerts/${CERT_NAME}" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Certificate installed to system store"
else
    echo -e "${RED}Error: Certificate not found after installation${NC}"
    exit 1
fi
echo ""

# Step 7: Restart Android runtime
echo -e "${YELLOW}[7/7]${NC} Restarting Android runtime to activate certificate..."
adb shell "killall system_server" > /dev/null 2>&1
echo -e "${GREEN}✓${NC} System restarting (screen will go black for ~20 seconds)..."
echo ""

# Wait for system to come back
echo -e "${BLUE}Waiting for system to restart...${NC}"
sleep 25
adb wait-for-device
sleep 5

echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Certificate Details:${NC}"
echo -e "  Name: ${CERT_NAME}"
echo -e "  User Store: /data/misc/user/0/cacerts-added/${CERT_NAME}"
echo -e "  System Store: /apex/com.android.conscrypt/cacerts/${CERT_NAME}"
echo ""
echo -e "${BLUE}Verification:${NC}"
echo -e "  Settings → Security → Trusted credentials"
echo -e "  - User tab: Check for your certificate"
echo -e "  - System tab: Check for your certificate"
echo ""
echo -e "${YELLOW}⚠ Note: System certificate will NOT persist after reboot.${NC}"
echo -e "   Re-run this script after each reboot:"
echo -e "   ${GREEN}./$(basename $0) $CERT_FILE${NC}"
echo ""
