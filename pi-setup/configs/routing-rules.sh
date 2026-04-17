#!/bin/bash
#
# MitM-Pi Traffic Routing Configuration
# Sets up iptables rules for transparent proxy and traffic forwarding
#

# Exit on error
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
# Modify these based on your network setup
WLAN_INTERFACE="wlan0"          # WiFi AP interface
ETH_INTERFACE="eth0"             # Upstream network interface
AP_NETWORK="192.168.100.0/24"    # Access Point network range
ANALYSIS_MACHINE_IP=""           # Will be prompted during setup
PROXY_PORT="8080"                # Proxy port on analysis machine

echo -e "${GREEN}=== MitM-Pi Traffic Routing Setup ===${NC}"

# Prompt for analysis machine IP if not set
if [ -z "$ANALYSIS_MACHINE_IP" ]; then
    echo -e "${YELLOW}Enter the IP address of your analysis machine:${NC}"
    read -p "Analysis Machine IP: " ANALYSIS_MACHINE_IP
    
    if [ -z "$ANALYSIS_MACHINE_IP" ]; then
        echo -e "${RED}Error: Analysis machine IP is required${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Configuration:${NC}"
echo "  WiFi Interface: $WLAN_INTERFACE"
echo "  Ethernet Interface: $ETH_INTERFACE"
echo "  AP Network: $AP_NETWORK"
echo "  Analysis Machine: $ANALYSIS_MACHINE_IP"
echo "  Proxy Port: $PROXY_PORT"
echo ""

# Enable IP forwarding
echo -e "${GREEN}[1/5] Enabling IP forwarding...${NC}"
echo 1 > /proc/sys/net/ipv4/ip_forward

# Make IP forwarding permanent
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo -e "  ${GREEN}✓${NC} IP forwarding enabled permanently"
else
    echo -e "  ${GREEN}✓${NC} IP forwarding already configured"
fi

# Flush existing rules
echo -e "${GREEN}[2/5] Flushing existing iptables rules...${NC}"
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
echo -e "  ${GREEN}✓${NC} Rules flushed"

# Set default policies
echo -e "${GREEN}[3/5] Setting default policies...${NC}"
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo -e "  ${GREEN}✓${NC} Default policies set"

# NAT configuration for internet access
echo -e "${GREEN}[4/5] Configuring NAT...${NC}"
iptables -t nat -A POSTROUTING -o $ETH_INTERFACE -j MASQUERADE
iptables -A FORWARD -i $ETH_INTERFACE -o $WLAN_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $WLAN_INTERFACE -o $ETH_INTERFACE -j ACCEPT
echo -e "  ${GREEN}✓${NC} NAT configured"

# Transparent proxy redirect to analysis machine
echo -e "${GREEN}[5/5] Configuring transparent proxy redirect...${NC}"

# Redirect HTTP traffic (port 80) to analysis machine proxy
iptables -t nat -A PREROUTING -i $WLAN_INTERFACE -p tcp --dport 80 \
    -j DNAT --to-destination $ANALYSIS_MACHINE_IP:$PROXY_PORT

# Redirect HTTPS traffic (port 443) to analysis machine proxy  
iptables -t nat -A PREROUTING -i $WLAN_INTERFACE -p tcp --dport 443 \
    -j DNAT --to-destination $ANALYSIS_MACHINE_IP:$PROXY_PORT

# Additional common ports for IoT devices
# MQTT (if needed, uncomment)
# iptables -t nat -A PREROUTING -i $WLAN_INTERFACE -p tcp --dport 1883 \
#     -j DNAT --to-destination $ANALYSIS_MACHINE_IP:1883
# iptables -t nat -A PREROUTING -i $WLAN_INTERFACE -p tcp --dport 8883 \
#     -j DNAT --to-destination $ANALYSIS_MACHINE_IP:8883

# CoAP (if needed, uncomment)
# iptables -t nat -A PREROUTING -i $WLAN_INTERFACE -p udp --dport 5683 \
#     -j DNAT --to-destination $ANALYSIS_MACHINE_IP:5683

echo -e "  ${GREEN}✓${NC} Transparent proxy redirect configured"

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
echo -e "${GREEN}=== Traffic Routing Configuration Complete ===${NC}"
echo ""
echo -e "Current iptables rules:"
echo -e "${YELLOW}NAT table:${NC}"
iptables -t nat -L -n -v
echo ""
echo -e "${YELLOW}Filter table:${NC}"
iptables -L -n -v

echo ""
echo -e "${GREEN}✓ All traffic from $AP_NETWORK will be forwarded to $ANALYSIS_MACHINE_IP:$PROXY_PORT${NC}"
echo -e "${YELLOW}⚠ Ensure your proxy on $ANALYSIS_MACHINE_IP is listening on port $PROXY_PORT${NC}"
echo ""
