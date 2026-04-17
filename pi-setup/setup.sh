#!/bin/bash
#
# MitM-Pi Setup Script
# Configures Raspberry Pi 5 with Kali Linux as a transparent MITM device
# for IoT security testing
#
# Usage: sudo ./setup.sh [--passive]
#   --passive: Passive monitoring mode (no proxy redirection, all traffic monitored on Pi)
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
echo "║                   MitM-Pi Setup Script                    ║"
echo "║     Transparent MITM Device for IoT Security Testing     ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Parse command line arguments
PASSIVE_MODE=false
if [ "$1" = "--passive" ]; then
    PASSIVE_MODE=true
    echo -e "${BLUE}Running in PASSIVE MONITORING mode${NC}"
    echo -e "${YELLOW}⚠ No proxy redirection - all traffic monitored on Pi${NC}"
    echo ""
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] Running as root${NC}"
echo ""

# Function to detect WiFi interfaces
detect_wifi_interfaces() {
    echo -e "${BLUE}Detecting WiFi interfaces...${NC}"
    
    # Get all wireless interfaces
    wifi_interfaces=$(iw dev | grep Interface | awk '{print $2}')
    
    if [ -z "$wifi_interfaces" ]; then
        echo -e "${RED}Error: No WiFi interfaces detected!${NC}"
        echo -e "${YELLOW}Please ensure WiFi hardware is properly connected${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Found WiFi interface(s):${NC}"
    for iface in $wifi_interfaces; do
        # Get interface info
        driver=$(readlink /sys/class/net/$iface/device/driver 2>/dev/null | awk -F'/' '{print $NF}')
        mac=$(cat /sys/class/net/$iface/address 2>/dev/null)
        echo -e "  - $iface (Driver: ${driver:-unknown}, MAC: ${mac:-unknown})"
    done
    echo ""
    
    # Check for ALFA AWUS1900 (rtl88XXau driver or similar)
    # ALFA adapters often use Realtek chipsets
    for iface in $wifi_interfaces; do
        driver=$(readlink /sys/class/net/$iface/device/driver 2>/dev/null | awk -F'/' '{print $NF}')
        if [[ "$driver" == *"88"* ]] || [[ "$driver" == *"rtl"* ]]; then
            echo -e "${GREEN}[✓] Detected external WiFi adapter (likely ALFA): $iface${NC}"
            WLAN_INTERFACE="$iface"
            return
        fi
    done
    
    # If no external adapter found, use first wireless interface
    WLAN_INTERFACE=$(echo "$wifi_interfaces" | head -n 1)
    echo -e "${YELLOW}[!] Using built-in WiFi interface: $WLAN_INTERFACE${NC}"
    echo -e "${YELLOW}[!] For better performance, consider using ALFA AWUS1900${NC}"
}

# Function to update system
update_system() {
    echo -e "${BLUE}[1/7] Updating system packages...${NC}"
    apt update -qq
    echo -e "${GREEN}[✓] System package list updated${NC}"
    echo ""
}

# Function to install required packages
install_packages() {
    echo -e "${BLUE}[2/7] Installing required packages...${NC}"
    
    PACKAGES="hostapd dnsmasq iptables iptables-persistent net-tools iw wireless-tools"
    
    echo -e "${YELLOW}Packages to install: $PACKAGES${NC}"
    
    # Install packages
    DEBIAN_FRONTEND=noninteractive apt install -y $PACKAGES
    
    echo -e "${GREEN}[✓] All required packages installed${NC}"
    echo ""
}

# Function to stop conflicting services
stop_services() {
    echo -e "${BLUE}[3/7] Stopping conflicting services...${NC}"
    
    # Stop Network Manager if running (can interfere with hostapd)
    if systemctl is-active --quiet NetworkManager; then
        echo -e "${YELLOW}[!] Stopping NetworkManager${NC}"
        systemctl stop NetworkManager
        systemctl disable NetworkManager
    fi
    
    # Stop services before configuration
    systemctl stop hostapd 2>/dev/null || true
    systemctl stop dnsmasq 2>/dev/null || true
    
    echo -e "${GREEN}[✓] Services stopped${NC}"
    echo ""
}

# Function to configure network interface
configure_network() {
    echo -e "${BLUE}[4/7] Configuring network interface...${NC}"
    
    # Detect WiFi interfaces
    detect_wifi_interfaces
    
    echo -e "${GREEN}Selected interface: $WLAN_INTERFACE${NC}"
    
    # Configure static IP for access point
    echo -e "${YELLOW}Configuring static IP 192.168.100.1 for $WLAN_INTERFACE${NC}"
    
    # Backup existing interfaces file
    if [ -f /etc/network/interfaces ]; then
        cp /etc/network/interfaces /etc/network/interfaces.backup
    fi
    
    # Add static IP configuration
    cat > /etc/network/interfaces.d/$WLAN_INTERFACE << EOF
# MitM-Pi WiFi AP Interface
auto $WLAN_INTERFACE
iface $WLAN_INTERFACE inet static
    address 192.168.100.1
    netmask 255.255.255.0
    network 192.168.100.0
    broadcast 192.168.100.255
EOF
    
    # Bring interface up with static IP
    ip addr flush dev $WLAN_INTERFACE
    ip addr add 192.168.100.1/24 dev $WLAN_INTERFACE
    ip link set $WLAN_INTERFACE up
    
    echo -e "${GREEN}[✓] Network interface configured${NC}"
    echo ""
}

# Function to configure hostapd
configure_hostapd() {
    echo -e "${BLUE}[5/7] Configuring hostapd (WiFi Access Point)...${NC}"
    
    # Update interface in hostapd.conf
    sed -i "s/^interface=.*/interface=$WLAN_INTERFACE/" configs/hostapd.conf
    
    # Copy configuration
    cp configs/hostapd.conf /etc/hostapd/hostapd.conf
    
    # Tell hostapd where to find the config
    sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
    
    # Unmask and enable hostapd
    systemctl unmask hostapd
    systemctl enable hostapd
    
    echo -e "${GREEN}[✓] hostapd configured${NC}"
    echo -e "${YELLOW}  SSID: MitM-Pi${NC}"
    echo -e "${YELLOW}  Password: changeme123 ${RED}(CHANGE THIS!)${NC}"
    echo ""
}

# Function to configure dnsmasq
configure_dnsmasq() {
    echo -e "${BLUE}[6/7] Configuring dnsmasq (DHCP/DNS)...${NC}"
    
    # Backup original config
    if [ -f /etc/dnsmasq.conf ]; then
        mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
    fi
    
    # Update interface in dnsmasq.conf
    sed -i "s/^interface=.*/interface=$WLAN_INTERFACE/" configs/dnsmasq.conf
    
    # Copy configuration
    cp configs/dnsmasq.conf /etc/dnsmasq.conf
    
    # Create log directory
    mkdir -p /var/log
    touch /var/log/dnsmasq.log
    
    # Enable dnsmasq
    systemctl enable dnsmasq
    
    echo -e "${GREEN}[✓] dnsmasq configured${NC}"
    echo -e "${YELLOW}  DHCP Range: 192.168.100.10 - 192.168.100.250${NC}"
    echo ""
}

# Function to configure routing
configure_routing() {
    echo -e "${BLUE}[7/7] Configuring traffic routing...${NC}"
    
    if [ "$PASSIVE_MODE" = true ]; then
        # Passive monitoring mode - no proxy redirection
        echo -e "${YELLOW}Configuring passive monitoring mode...${NC}"
        
        # Make routing script executable
        chmod +x configs/routing-rules-passive.sh
        
        # Run passive routing configuration
        bash configs/routing-rules-passive.sh
        
        echo -e "${GREEN}[✓] Passive routing configured (no proxy redirection)${NC}"
        echo -e "${YELLOW}  All traffic monitored on Pi, use tcpdump for capture${NC}"
    else
        # Active MITM mode with proxy redirection
        echo -e "${YELLOW}Configuring active MITM mode with proxy redirection...${NC}"
        
        # Make routing script executable
        chmod +x configs/routing-rules.sh
        
        # Update interface names in routing script
        sed -i "s/^WLAN_INTERFACE=.*/WLAN_INTERFACE=\"$WLAN_INTERFACE\"/" configs/routing-rules.sh
        
        # Ask for analysis machine IP
        echo -e "${YELLOW}Enter the IP address of your analysis machine${NC}"
        echo -e "${YELLOW}(the machine running Burp Suite, mitmproxy, etc.):${NC}"
        read -p "Analysis Machine IP: " ANALYSIS_IP
        
        if [ -z "$ANALYSIS_IP" ]; then
            echo -e "${RED}Error: Analysis machine IP cannot be empty${NC}"
            exit 1
        fi
        
        # Update analysis machine IP in routing script
        sed -i "s/^ANALYSIS_MACHINE_IP=.*/ANALYSIS_MACHINE_IP=\"$ANALYSIS_IP\"/" configs/routing-rules.sh
        
        # Run routing configuration
        bash configs/routing-rules.sh
        
        echo -e "${GREEN}[✓] Active MITM routing configured${NC}"
        echo -e "${YELLOW}  HTTP/HTTPS redirected to $ANALYSIS_IP:8080${NC}"
    fi
    
    echo ""
}

# Function to start services
start_services() {
    echo -e "${BLUE}Starting services...${NC}"
    
    # Start hostapd
    echo -e "${YELLOW}Starting hostapd...${NC}"
    systemctl start hostapd
    
    if systemctl is-active --quiet hostapd; then
        echo -e "${GREEN}[✓] hostapd started successfully${NC}"
    else
        echo -e "${RED}[✗] hostapd failed to start${NC}"
        echo -e "${YELLOW}Check logs: journalctl -u hostapd -n 50${NC}"
    fi
    
    # Start dnsmasq
    echo -e "${YELLOW}Starting dnsmasq...${NC}"
    systemctl start dnsmasq
    
    if systemctl is-active --quiet dnsmasq; then
        echo -e "${GREEN}[✓] dnsmasq started successfully${NC}"
    else
        echo -e "${RED}[✗] dnsmasq failed to start${NC}"
        echo -e "${YELLOW}Check logs: journalctl -u dnsmasq -n 50${NC}"
    fi
    
    echo ""
}

# Function to display status
display_status() {
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║              MitM-Pi Setup Complete!                      ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}WiFi Access Point Details:${NC}"
    echo -e "  SSID: ${GREEN}MitM-Pi${NC}"
    echo -e "  Password: ${YELLOW}changeme123${NC} ${RED}(CHANGE THIS!)${NC}"
    echo -e "  IP Address: ${GREEN}192.168.100.1${NC}"
    echo -e "  Interface: ${GREEN}$WLAN_INTERFACE${NC}"
    echo ""
    echo -e "${BLUE}Network Configuration:${NC}"
    echo -e "  DHCP Range: ${GREEN}192.168.100.10 - 192.168.100.250${NC}"
    if [ "$PASSIVE_MODE" = true ]; then
        echo -e "  Mode: ${YELLOW}Passive Monitoring (no proxy)${NC}"
    else
        echo -e "  Analysis Machine: ${GREEN}$ANALYSIS_IP${NC}"
        echo -e "  Proxy Port: ${GREEN}8080${NC}"
    fi
    echo ""
    echo -e "${BLUE}Service Status:${NC}"
    systemctl status hostapd --no-pager | grep Active
    systemctl status dnsmasq --no-pager | grep Active
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "  1. ${GREEN}Change the WiFi password${NC} (edit /etc/hostapd/hostapd.conf)"
    if [ "$PASSIVE_MODE" = true ]; then
        echo -e "  2. ${GREEN}Connect an IoT device${NC} to the MitM-Pi WiFi network"
        echo -e "  3. ${GREEN}Monitor traffic on Pi${NC} with tcpdump or wireshark"
        echo -e "     Example: ${GREEN}sudo tcpdump -i wlan1 -w /tmp/capture.pcap${NC}"
    else
        echo -e "  2. ${GREEN}Configure your proxy${NC} on $ANALYSIS_IP:8080"
        echo -e "  3. ${GREEN}Connect an IoT device${NC} to the MitM-Pi WiFi network"
        echo -e "  4. ${GREEN}Start intercepting traffic${NC} in your proxy tool"
    fi
    echo ""
    echo -e "${YELLOW}Verification Commands:${NC}"
    echo -e "  Check hostapd: ${GREEN}sudo systemctl status hostapd${NC}"
    echo -e "  Check dnsmasq: ${GREEN}sudo systemctl status dnsmasq${NC}"
    echo -e "  View routing: ${GREEN}sudo iptables -t nat -L -n -v${NC}"
    echo -e "  Check logs: ${GREEN}sudo tail -f /var/log/syslog${NC}"
    echo ""
    echo -e "${RED}⚠ Remember: Only use for authorized testing!${NC}"
    echo ""
}

# Main execution
main() {
    update_system
    install_packages
    stop_services
    configure_network
    configure_hostapd
    configure_dnsmasq
    configure_routing
    start_services
    display_status
}

# Run main function
main
