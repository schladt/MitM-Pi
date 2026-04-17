#!/bin/bash
#
# MitM-Pi Passive Traffic Routing Configuration
# Sets up NAT routing WITHOUT proxy redirection for passive traffic capture
# Use this to capture encrypted traffic on the Pi for later analysis
#

# Exit on error
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
ETH_INTERFACE="eth0"             # Upstream network interface
AP_NETWORK="192.168.100.0/24"    # Access Point network range
AP_IP="192.168.100.1"            # Access Point IP address

echo -e "${GREEN}=== MitM-Pi Passive Routing Setup ===${NC}"

# Auto-detect WiFi interface with AP IP
WLAN_INTERFACE=$(ip addr show | grep -B 2 "$AP_IP" | head -n 1 | awk '{print $2}' | tr -d ':')

if [ -z "$WLAN_INTERFACE" ]; then
    echo -e "${RED}Error: Could not detect WiFi AP interface with IP $AP_IP${NC}"
    echo -e "${YELLOW}Available interfaces:${NC}"
    ip addr show | grep -E "^[0-9]+:" | awk '{print $2}' | tr -d ':'
    exit 1
fi

echo -e "${GREEN}Detected AP interface: $WLAN_INTERFACE${NC}"

echo -e "${GREEN}Configuration:${NC}"
echo "  WiFi Interface: $WLAN_INTERFACE (auto-detected)"
echo "  Ethernet Interface: $ETH_INTERFACE"
echo "  AP Network: $AP_NETWORK"
echo "  Mode: Passive routing (NO proxy redirection)"
echo ""

# Enable IP forwarding
echo -e "${GREEN}[1/4] Enabling IP forwarding...${NC}"
echo 1 > /proc/sys/net/ipv4/ip_forward

# Make IP forwarding permanent
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo -e "  ${GREEN}✓${NC} IP forwarding enabled permanently"
else
    echo -e "  ${GREEN}✓${NC} IP forwarding already configured"
fi

# Flush existing rules
echo -e "${GREEN}[2/4] Flushing existing iptables rules...${NC}"
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
echo -e "  ${GREEN}✓${NC} Rules flushed"

# Set default policies
echo -e "${GREEN}[3/4] Setting default policies...${NC}"
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo -e "  ${GREEN}✓${NC} Default policies set"

# NAT configuration for internet access
echo -e "${GREEN}[4/4] Configuring NAT (passive mode)...${NC}"
iptables -t nat -A POSTROUTING -o $ETH_INTERFACE -j MASQUERADE
iptables -A FORWARD -i $ETH_INTERFACE -o $WLAN_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $WLAN_INTERFACE -o $ETH_INTERFACE -j ACCEPT
echo -e "  ${GREEN}✓${NC} NAT configured"

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow DHCP
iptables -A INPUT -i $WLAN_INTERFACE -p udp --dport 67:68 -j ACCEPT

# Allow DNS
iptables -A INPUT -i $WLAN_INTERFACE -p udp --dport 53 -j ACCEPT
iptables -A INPUT -i $WLAN_INTERFACE -p tcp --dport 53 -j ACCEPT

# Allow SSH (be careful with this in production!)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Save iptables rules
echo -e "${GREEN}Saving iptables rules...${NC}"
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
    echo -e "  ${GREEN}✓${NC} Rules saved with netfilter-persistent"
elif command -v iptables-save &> /dev/null; then
    iptables-save > /etc/iptables/rules.v4
    echo -e "  ${GREEN}✓${NC} Rules saved to /etc/iptables/rules.v4"
else
    echo -e "  ${YELLOW}⚠${NC} Warning: Could not find method to persist iptables rules"
    echo -e "  ${YELLOW}⚠${NC} Rules will be lost on reboot unless you install iptables-persistent"
fi

echo ""
echo -e "${GREEN}=== Passive Routing Configuration Complete ===${NC}"
echo ""
echo -e "Current iptables rules:"
echo -e "${YELLOW}NAT table:${NC}"
iptables -t nat -L -n -v
echo ""
echo -e "${YELLOW}Filter table:${NC}"
iptables -L -n -v

echo ""
echo -e "${GREEN}✓ Passive routing enabled - all traffic routes normally through NAT${NC}"
echo -e "${GREEN}✓ No proxy redirection - capture traffic directly on this Pi${NC}"
echo -e "${YELLOW}💡 To capture traffic, run: tcpdump -i $WLAN_INTERFACE -w /tmp/capture.pcap${NC}"
echo ""
