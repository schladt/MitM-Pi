#!/bin/bash
#
# mitmproxy capture script for MitM-Pi
# Starts mitmproxy in transparent mode with flow logging
#

set -e

CAPTURE_DIR="${CAPTURE_DIR:-$HOME/Desktop/mitm-captures}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PORT="${PORT:-8080}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if mitmproxy is installed
if ! command -v mitmdump &> /dev/null; then
    echo -e "${RED}Error: mitmproxy not installed${NC}"
    echo "Install with: brew install mitmproxy"
    exit 1
fi

# Show usage
usage() {
    echo -e "${GREEN}=== mitmproxy Capture Script ===${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -p PORT       Proxy port (default: 8080)"
    echo "  -d DIR        Capture directory (default: ~/Desktop/mitm-captures)"
    echo "  -w            Start mitmweb (web interface) instead of mitmdump"
    echo "  -s            Enable security analysis addon"
    echo "  -h            Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                    # Start with defaults"
    echo "  $0 -w                 # Start with web UI"
    echo "  $0 -p 8888 -s         # Custom port with security analysis"
    echo ""
    echo "Environment variables:"
    echo "  PORT          Proxy port (default: 8080)"
    echo "  CAPTURE_DIR   Output directory (default: ~/Desktop/mitm-captures)"
    echo ""
    exit 0
}

# Parse arguments
WEB_MODE=false
SECURITY_MODE=false

while getopts "p:d:wsh" opt; do
    case $opt in
        p) PORT="$OPTARG" ;;
        d) CAPTURE_DIR="$OPTARG" ;;
        w) WEB_MODE=true ;;
        s) SECURITY_MODE=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

echo -e "${GREEN}=== mitmproxy Capture ===${NC}"
echo "Timestamp: $TIMESTAMP"
echo "Port: $PORT"
echo "Capture directory: $CAPTURE_DIR"
echo ""

# Create capture directory
mkdir -p "$CAPTURE_DIR"

# Create addon directory
ADDON_DIR="$CAPTURE_DIR/.addons"
mkdir -p "$ADDON_DIR"

# Create security analysis addon if requested
if [ "$SECURITY_MODE" = true ]; then
    cat > "$ADDON_DIR/security_analysis.py" << 'PYTHON'
"""
Security analysis addon for mitmproxy
Detects sensitive data patterns and saves findings
"""

from mitmproxy import http, ctx
import re
import json
from datetime import datetime

class SecurityAnalyzer:
    def __init__(self):
        self.findings = []
        self.patterns = {
            'api_key': [
                r'api[_-]?key["\s:=]+([a-zA-Z0-9_\-]{16,})',
                r'apikey["\s:=]+([a-zA-Z0-9_\-]{16,})',
            ],
            'password': [
                r'password["\s:=]+([^"&\s]{6,})',
                r'passwd["\s:=]+([^"&\s]{6,})',
                r'pwd["\s:=]+([^"&\s]{6,})',
            ],
            'token': [
                r'["\s]token["\s:=]+([a-zA-Z0-9_\-\.]{16,})',
                r'bearer\s+([a-zA-Z0-9_\-\.]{16,})',
            ],
            'secret': [
                r'secret[_-]?key["\s:=]+([a-zA-Z0-9_\-]{16,})',
                r'client[_-]?secret["\s:=]+([a-zA-Z0-9_\-]{16,})',
            ],
            'aws_key': [
                r'AKIA[0-9A-Z]{16}',
            ],
            'private_key': [
                r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
            ],
            'jwt': [
                r'eyJ[a-zA-Z0-9_\-]+\.eyJ[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+',
            ],
        }
    
    def scan_text(self, text, url, context):
        """Scan text for sensitive patterns"""
        if not text:
            return
        
        for pattern_name, regexes in self.patterns.items():
            for regex in regexes:
                matches = re.finditer(regex, text, re.IGNORECASE)
                for match in matches:
                    finding = {
                        'timestamp': datetime.now().isoformat(),
                        'type': pattern_name,
                        'url': url,
                        'context': context,
                        'match': match.group(0)[:100] + ('...' if len(match.group(0)) > 100 else ''),
                        'position': match.start()
                    }
                    self.findings.append(finding)
                    
                    # Log to console
                    ctx.log.warn(
                        f"🚨 Security Finding: {pattern_name} in {context} "
                        f"at {url}"
                    )
    
    def request(self, flow: http.HTTPFlow):
        """Analyze request"""
        url = flow.request.pretty_url
        
        # Check URL
        self.scan_text(url, url, "URL")
        
        # Check headers
        for name, value in flow.request.headers.items():
            self.scan_text(f"{name}: {value}", url, "Request Headers")
        
        # Check body
        if flow.request.text:
            self.scan_text(flow.request.text, url, "Request Body")
    
    def response(self, flow: http.HTTPFlow):
        """Analyze response"""
        url = flow.request.pretty_url
        
        # Check headers
        for name, value in flow.response.headers.items():
            self.scan_text(f"{name}: {value}", url, "Response Headers")
        
        # Check body
        if flow.response.text:
            self.scan_text(flow.response.text, url, "Response Body")
    
    def done(self):
        """Save findings on exit"""
        if self.findings:
            output_file = ctx.options.save_stream_file.replace('.dump', '_security.json')
            with open(output_file, 'w') as f:
                json.dump(self.findings, f, indent=2)
            ctx.log.info(f"💾 Saved {len(self.findings)} security findings to {output_file}")
        else:
            ctx.log.info("✅ No security findings detected")

addons = [SecurityAnalyzer()]
PYTHON
    echo -e "${BLUE}Security analysis addon created${NC}"
fi

# Create basic logging addon
cat > "$ADDON_DIR/logger.py" << 'PYTHON'
"""
Basic logging addon for mitmproxy
Logs requests/responses with timing information
"""

from mitmproxy import http, ctx
import time

class RequestLogger:
    def __init__(self):
        self.request_count = 0
        self.start_time = time.time()
    
    def request(self, flow: http.HTTPFlow):
        """Log request"""
        self.request_count += 1
        ctx.log.info(
            f"→ {self.request_count:04d} "
            f"{flow.request.method:6s} "
            f"{flow.request.pretty_url}"
        )
    
    def response(self, flow: http.HTTPFlow):
        """Log response"""
        duration_ms = int(flow.response.timestamp_end - flow.request.timestamp_start) * 1000
        size_kb = len(flow.response.content) / 1024 if flow.response.content else 0
        
        ctx.log.info(
            f"← {flow.response.status_code} "
            f"{flow.request.pretty_url} "
            f"({duration_ms}ms, {size_kb:.1f}KB)"
        )
    
    def done(self):
        """Summary on exit"""
        duration = int(time.time() - self.start_time)
        ctx.log.info(
            f"📊 Session complete: {self.request_count} requests in {duration}s"
        )

addons = [RequestLogger()]
PYTHON

# Build addon list
ADDONS="$ADDON_DIR/logger.py"
if [ "$SECURITY_MODE" = true ]; then
    ADDONS="$ADDONS,$ADDON_DIR/security_analysis.py"
fi

# Output file paths
DUMP_FILE="$CAPTURE_DIR/flows-${TIMESTAMP}.dump"
HAR_FILE="$CAPTURE_DIR/flows-${TIMESTAMP}.har"

# Start mitmproxy
echo -e "${GREEN}Starting mitmproxy...${NC}"
echo ""

if [ "$WEB_MODE" = true ]; then
    echo -e "${BLUE}Web interface will be available at: http://localhost:8081${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    mitmweb \
        --mode transparent \
        --listen-host 0.0.0.0 \
        --listen-port "$PORT" \
        --save-stream-file "$DUMP_FILE" \
        --set hardump="$HAR_FILE" \
        -s "$ADDONS"
else
    echo -e "${YELLOW}Running in headless mode (mitmdump)${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    mitmdump \
        --mode transparent \
        --listen-host 0.0.0.0 \
        --listen-port "$PORT" \
        --save-stream-file "$DUMP_FILE" \
        --set hardump="$HAR_FILE" \
        --set flow_detail=2 \
        -s "$ADDONS"
fi

# Cleanup and summary
echo ""
echo -e "${GREEN}=== Capture Complete ===${NC}"
echo "Flows saved:"
echo "  Dump:  $DUMP_FILE"
echo "  HAR:   $HAR_FILE"

if [ "$SECURITY_MODE" = true ]; then
    SECURITY_FILE="${DUMP_FILE%.dump}_security.json"
    if [ -f "$SECURITY_FILE" ]; then
        echo "  Security: $SECURITY_FILE"
    fi
fi

echo ""
echo "View captured flows:"
echo "  mitmweb -r $DUMP_FILE"
echo ""
echo "Filter flows:"
echo "  mitmdump -r $DUMP_FILE '~d example.com'      # By domain"
echo "  mitmdump -r $DUMP_FILE '~m POST'             # By method"
echo "  mitmdump -r $DUMP_FILE '~c 200'              # By status code"
