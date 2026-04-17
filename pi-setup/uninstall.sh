#!/bin/bash
#
# MitM-Pi Uninstall Script
# Removes MITM configuration and restores Pi to normal state
#
# Usage: sudo ./uninstall.sh
#

# Exit on error
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║                 MitM-Pi Uninstall Script                  ║"
echo "║           Restore Pi to Normal Configuration              ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Confirmation prompt
echo -e "${YELLOW}This will remove the MitM-Pi configuration and restore normal settings.${NC}"
echo -e "${YELLOW}The following will be removed/restored:${NC}"
echo "  - WiFi Access Point (hostapd)"
echo "  - DHCP server (dnsmasq)"
echo "  - Traffic routing and iptables rules"
echo "  - Static IP configuration on WiFi interface"
echo ""
echo -e "${RED}Services will be stopped and disabled.${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo -e "${GREEN}Uninstall cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}[1/7] Stopping services...${NC}"

# Stop services
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

echo -e "${GREEN}[✓] Services stopped${NC}"
echo ""

echo -e "${BLUE}[2/7] Disabling services...${NC}"

# Disable services
systemctl disable hostapd 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true

echo -e "${GREEN}[✓] Services disabled${NC}"
echo ""

echo -e "${BLUE}[3/7] Removing configuration files...${NC}"

# Backup then remove configs
if [ -f /etc/hostapd/hostapd.conf ]; then
    mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.mitm-backup
    echo -e "  ${GREEN}✓${NC} hostapd config backed up to /etc/hostapd/hostapd.conf.mitm-backup"
fi

if [ -f /etc/dnsmasq.conf ]; then
    if [ -f /etc/dnsmasq.conf.backup ]; then
        mv /etc/dnsmasq.conf.backup /etc/dnsmasq.conf
        echo -e "  ${GREEN}✓${NC} Restored original dnsmasq config"
    else
        mv /etc/dnsmasq.conf /etc/dnsmasq.conf.mitm-backup
        echo -e "  ${GREEN}✓${NC} dnsmasq config backed up to /etc/dnsmasq.conf.mitm-backup"
    fi
fi

# Remove interface configuration
if [ -f /etc/network/interfaces.d/wlan* ]; then
    rm -f /etc/network/interfaces.d/wlan*
    echo -e "  ${GREEN}✓${NC} WiFi interface static IP configuration removed"
fi

if [ -f /etc/network/interfaces.backup ]; then
    mv /etc/network/interfaces.backup /etc/network/interfaces
    echo -e "  ${GREEN}✓${NC} Restored original interfaces file"
fi

echo -e "${GREEN}[✓] Configuration files removed/restored${NC}"
echo ""

echo -e "${BLUE}[4/7] Flushing iptables rules...${NC}"

# Flush all rules
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# Reset to default accept policies
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Save clean rules
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
    echo -e "  ${GREEN}✓${NC} iptables rules cleared and saved"
elif [ -f /etc/iptables/rules.v4 ]; then
    iptables-save > /etc/iptables/rules.v4
    echo -e "  ${GREEN}✓${NC} iptables rules cleared and saved"
fi

echo -e "${GREEN}[✓] iptables rules flushed${NC}"
echo ""

echo -e "${BLUE}[5/7] Disabling IP forwarding...${NC}"

# Disable IP forwarding
echo 0 > /proc/sys/net/ipv4/ip_forward

# Remove from sysctl.conf
if grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf
    echo -e "  ${GREEN}✓${NC} IP forwarding disabled permanently"
fi

echo -e "${GREEN}[✓] IP forwarding disabled${NC}"
echo ""

echo -e "${BLUE}[6/7] Resetting network interfaces...${NC}"

# Detect WiFi interfaces
wifi_interfaces=$(iw dev | grep Interface | awk '{print $2}')

for iface in $wifi_interfaces; do
    echo -e "  Resetting $iface..."
    
    # Flush IP addresses
    ip addr flush dev $iface 2>/dev/null || true
    
    # Bring interface down
    ip link set $iface down 2>/dev/null || true
    
    echo -e "  ${GREEN}✓${NC} $iface reset"
done

echo -e "${GREEN}[✓] Network interfaces reset${NC}"
echo ""

echo -e "${BLUE}[7/7] Optional: Remove packages...${NC}"

echo -e "${YELLOW}Do you want to remove installed packages (hostapd, dnsmasq)?${NC}"
echo -e "${YELLOW}Choose 'no' if you might use them for other purposes.${NC}"
read -p "Remove packages? (yes/no): " remove_packages

if [[ "$remove_packages" == "yes" ]]; then
    apt remove --purge -y hostapd dnsmasq 2>/dev/null || true
    apt autoremove -y 2>/dev/null || true
    echo -e "${GREEN}[✓] Packages removed${NC}"
else
    echo -e "${YELLOW}[!] Packages kept (can be manually removed later)${NC}"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║            MitM-Pi Configuration Removed!                 ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  ${GREEN}✓${NC} Services stopped and disabled"
echo -e "  ${GREEN}✓${NC} Configuration files backed up"
echo -e "  ${GREEN}✓${NC} iptables rules cleared"
echo -e "  ${GREEN}✓${NC} IP forwarding disabled"
echo -e "  ${GREEN}✓${NC} Network interfaces reset"
echo ""
echo -e "${YELLOW}Backup files saved (if needed for reference):${NC}"
echo "  /etc/hostapd/hostapd.conf.mitm-backup"
echo "  /etc/dnsmasq.conf.mitm-backup"
echo ""
echo -e "${BLUE}Recommended: Reboot the Pi to ensure all changes take effect.${NC}"
echo -e "${YELLOW}sudo reboot${NC}"
echo ""
