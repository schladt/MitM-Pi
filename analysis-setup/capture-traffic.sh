#!/bin/bash
#
# Traffic capture script for MitM-Pi analysis
# Supports multiple capture modes for different analysis needs
#

set -e

PI_HOST="${PI_HOST:-kali-raspberrypi}"
CAPTURE_DIR="${CAPTURE_DIR:-$HOME/Desktop/mitm-captures}"
PROXY_PORT="${PROXY_PORT:-8080}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Show usage
usage() {
    echo -e "${GREEN}=== MitM-Pi Traffic Capture ===${NC}"
    echo ""
    echo "Usage: $0 [mode]"
    echo ""
    echo "Modes:"
    echo "  network   - Capture encrypted traffic between analysis machine and Pi (default)"
    echo "  proxy     - Capture loopback traffic on proxy port (see Burp processing)"
    echo "  both      - Capture both network and proxy traffic"
    echo ""
    echo "Examples:"
    echo "  $0              # Network capture only"
    echo "  $0 proxy        # Proxy loopback capture"
    echo "  $0 both         # Both captures simultaneously"
    echo ""
    echo "Environment variables:"
    echo "  PI_HOST       - Pi hostname (default: kali-raspberrypi)"
    echo "  PROXY_PORT    - Proxy port (default: 8080)"
    echo "  CAPTURE_DIR   - Output directory (default: ~/Desktop/mitm-captures)"
    echo ""
    exit 0
}

# Parse arguments
MODE="${1:-network}"
if [[ "$MODE" == "-h" ]] || [[ "$MODE" == "--help" ]]; then
    usage
fi

echo -e "${GREEN}=== MitM-Pi Traffic Capture ===${NC}"
echo "Mode: $MODE"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create capture directory
mkdir -p "$CAPTURE_DIR"

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Stopping captures...${NC}"
    
    # Stop network capture
    if [ ! -z "$NETWORK_PID" ]; then
        sudo kill $NETWORK_PID 2>/dev/null || true
    fi
    
    # Stop proxy capture
    if [ ! -z "$PROXY_PID" ]; then
        sudo kill $PROXY_PID 2>/dev/null || true
    fi
    
    echo -e "${GREEN}Captures saved to: $CAPTURE_DIR${NC}"
    ls -lh "$CAPTURE_DIR"/*${TIMESTAMP}.pcap 2>/dev/null || true
    
    echo -e "\n${GREEN}Open in Wireshark:${NC}"
    if [ -f "$CAPTURE_DIR/network-${TIMESTAMP}.pcap" ]; then
        echo "  wireshark $CAPTURE_DIR/network-${TIMESTAMP}.pcap"
    fi
    if [ -f "$CAPTURE_DIR/proxy-${TIMESTAMP}.pcap" ]; then
        echo "  wireshark $CAPTURE_DIR/proxy-${TIMESTAMP}.pcap"
    fi
    
    echo -e "\n${BLUE}Note: Network capture is encrypted. For decrypted traffic:${NC}"
    echo "  - Use Burp Suite HTTP history (Proxy → HTTP history → Right-click → Save items)"
    echo "  - Or check proxy capture for Burp processing patterns"
}

trap cleanup EXIT INT TERM

# Network capture
if [[ "$MODE" == "network" ]] || [[ "$MODE" == "both" ]]; then
    echo -e "${GREEN}Setting up network capture...${NC}"
    
    # Get Pi IP
    PI_IP=$(ping -c 1 "$PI_HOST" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    if [ -z "$PI_IP" ]; then
        echo -e "${RED}Could not resolve Pi IP. Using fallback 192.168.50.235${NC}"
        PI_IP="192.168.50.235"
    fi
    echo "Pi IP: $PI_IP"
    
    # Detect interface to Pi
    INTERFACE=$(route -n get "$PI_IP" 2>/dev/null | grep 'interface:' | awk '{print $2}')
    if [ -z "$INTERFACE" ]; then
        INTERFACE="en0"
    fi
    echo "Network interface: $INTERFACE"
    
    # Start network capture
    sudo tcpdump -i "$INTERFACE" host "$PI_IP" -w "$CAPTURE_DIR/network-${TIMESTAMP}.pcap" -U &
    NETWORK_PID=$!
    sleep 1
    echo -e "${GREEN}✓ Network capture started${NC}"
    echo ""
fi

# Proxy capture
if [[ "$MODE" == "proxy" ]] || [[ "$MODE" == "both" ]]; then
    echo -e "${GREEN}Setting up proxy loopback capture...${NC}"
    echo "Proxy port: $PROXY_PORT"
    
    # Start proxy capture on loopback
    sudo tcpdump -i lo0 -w "$CAPTURE_DIR/proxy-${TIMESTAMP}.pcap" -U port $PROXY_PORT &
    PROXY_PID=$!
    sleep 1
    echo -e "${GREEN}✓ Proxy capture started${NC}"
    echo ""
fi

# Show status
echo -e "${GREEN}=== Captures Running ===${NC}"
if [[ "$MODE" == "network" ]] || [[ "$MODE" == "both" ]]; then
    echo "📡 Network: Capturing encrypted traffic between Mac ↔ Pi"
fi
if [[ "$MODE" == "proxy" ]] || [[ "$MODE" == "both" ]]; then
    echo "🔍 Proxy: Capturing Burp Suite processing on loopback:$PROXY_PORT"
fi
echo ""
echo -e "${YELLOW}1. Connect tablet to MitM-Pi WiFi (SSID: MitM-Pi)${NC}"
echo -e "${YELLOW}2. Run tests on tablet${NC}"
echo -e "${YELLOW}3. Press Ctrl+C when done${NC}"
echo ""

# Wait for user to stop
wait
