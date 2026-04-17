# mitmproxy Setup for MitM-Pi

mitmproxy is an open-source alternative to Burp Suite with excellent command-line tools and better export options for automated analysis.

## Installation

### macOS:
```bash
brew install mitmproxy
```

### Linux:
```bash
sudo apt install mitmproxy
# or
pip3 install mitmproxy
```

## Tool Options

mitmproxy includes three tools:

1. **mitmproxy** - Interactive console interface
2. **mitmweb** - Web-based GUI (easiest to start)
3. **mitmdump** - Non-interactive for automation/logging

## Setup for MitM-Pi

### 1. Start mitmproxy in Transparent Mode

```bash
# Option 1: Web interface (recommended for beginners)
mitmweb --mode transparent --listen-host 0.0.0.0 --listen-port 8080

# Option 2: Console interface
mitmproxy --mode transparent --listen-host 0.0.0.0 --listen-port 8080

# Option 3: Headless with flow logging
mitmdump --mode transparent --listen-host 0.0.0.0 --listen-port 8080 \
  --save-stream-file ~/Desktop/mitm-flows.dump
```

**Access mitmweb**: http://localhost:8081

### 2. Export CA Certificate

```bash
# Certificate is automatically created at:
~/.mitmproxy/mitmproxy-ca-cert.pem  # PEM format
~/.mitmproxy/mitmproxy-ca-cert.cer  # CER format for Android

# Convert to Android format
cd ~/.mitmproxy
openssl x509 -inform PEM -subject_hash_old -in mitmproxy-ca-cert.pem | head -1
# Output: certificate hash (e.g., c8750f0d)

# Create Android-compatible cert
HASH=$(openssl x509 -inform PEM -subject_hash_old -in mitmproxy-ca-cert.pem | head -1)
cat mitmproxy-ca-cert.pem > $HASH.0

# Install on Android
adb push $HASH.0 /sdcard/
# Then install via Settings → Security → Install from SD card
```

### 3. Configure Pi Routing for mitmproxy

If you're switching from Burp Suite, no changes needed! The same iptables rules work:

```bash
# On Pi - routing rules already configured
# Traffic on port 80 and 443 redirects to analysis machine port 8080
```

### 4. Test Connection

```bash
# On tablet connected to MitM-Pi WiFi:
# Open browser → http://mitm.it
# You should see mitmproxy certificate installation page
```

## Flow Export and Analysis

### Export Flows for Analysis

```bash
# After capturing with mitmdump:
mitmdump -r ~/Desktop/mitm-flows.dump -w ~/Desktop/filtered.dump \
  '~d example.com'  # Filter by domain

# Export to different formats
mitmdump -r ~/Desktop/mitm-flows.dump --save-stream-content \
  -w ~/Desktop/export/

# Export to HAR (HTTP Archive)
mitmdump -r ~/Desktop/mitm-flows.dump --set hardump=~/Desktop/flows.har

# Export requests as curl commands
mitmdump -r ~/Desktop/mitm-flows.dump -q \
  -s /usr/local/Cellar/mitmproxy/*/libexec/lib/python*/site-packages/mitmproxy/tools/console/defaultkeys.py
```

### View Flows in mitmweb

```bash
# Load saved flows in web interface
mitmweb -r ~/Desktop/mitm-flows.dump
# Opens browser to http://localhost:8081
```

### Filter Flows

```bash
# By domain
mitmdump -r flows.dump '~d example.com'

# By URL pattern
mitmdump -r flows.dump '~u /api/'

# By method
mitmdump -r flows.dump '~m POST'

# By status code
mitmdump -r flows.dump '~c 200'

# By response body content
mitmdump -r flows.dump '~bs "password"'

# Combine filters
mitmdump -r flows.dump '~d api.example.com & ~m POST'
```

## Scripting with mitmproxy

### Custom Request/Response logging

Create a script `log-script.py`:
```python
from mitmproxy import http

def request(flow: http.HTTPFlow) -> None:
    # Log all requests
    print(f"Request: {flow.request.method} {flow.request.pretty_url}")
    
def response(flow: http.HTTPFlow) -> None:
    # Log responses
    print(f"Response: {flow.response.status_code} {flow.request.pretty_url}")
    
    # Save sensitive data
    if "password" in flow.response.text.lower():
        with open("/tmp/passwords.txt", "a") as f:
            f.write(f"{flow.request.pretty_url}\n")
            f.write(f"{flow.response.text}\n\n")
```

Run with script:
```bash
mitmdump -s log-script.py --mode transparent --listen-host 0.0.0.0 --listen-port 8080
```

### Modify Traffic (Advanced)

```python
from mitmproxy import http

def request(flow: http.HTTPFlow) -> None:
    # Inject headers
    flow.request.headers["X-Forwarded-For"] = "10.0.0.1"
    
    # Modify POST data
    if flow.request.method == "POST":
        flow.request.text = flow.request.text.replace("user@example.com", "test@test.com")

def response(flow: http.HTTPFlow) -> None:
    # Replace in response
    if "text/html" in flow.response.headers.get("content-type", ""):
        flow.response.text = flow.response.text.replace("Premium", "Free")
```

## Automated Testing Script

Create `capture-with-mitmproxy.sh`:
```bash
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CAPTURE_DIR="$HOME/Desktop/mitm-captures"

mkdir -p "$CAPTURE_DIR"

echo "Starting mitmproxy capture..."
mitmdump --mode transparent --listen-host 0.0.0.0 --listen-port 8080 \
  --save-stream-file "$CAPTURE_DIR/flows-${TIMESTAMP}.dump" \
  --set hardump="$CAPTURE_DIR/flows-${TIMESTAMP}.har"

echo "Capture saved:"
echo "  Flows: $CAPTURE_DIR/flows-${TIMESTAMP}.dump"
echo "  HAR: $CAPTURE_DIR/flows-${TIMESTAMP}.har"
```

## Comparison: mitmproxy vs Burp Suite

| Feature | mitmproxy | Burp Suite |
|---------|-----------|------------|
| **License** | Open source (MIT) | Commercial (Pro) / Limited (Community) |
| **CLI Tools** | Excellent (`mitmdump`) | Limited |
| **Automation** | Python scripting | Extensions (Java) |
| **Flow Export** | HAR, dump, many formats | XML, JSON |
| **Replay** | Built-in (`mitmdump -r`) | Built-in (Repeater) |
| **Intercept** | Manual intercept mode | Excellent intercept UI |
| **Scanning** | None | Excellent (Pro only) |
| **Performance** | Fast, lightweight | Heavier (Java) |
| **Learning Curve** | Moderate (CLI-focused) | Easier (GUI) |

## Best Practices

### For IoT Device Testing:
```bash
# Capture everything non-interactively
mitmdump --mode transparent --listen-host 0.0.0.0 --listen-port 8080 \
  --save-stream-file iot-device-${TIMESTAMP}.dump \
  --set flow_detail=3
```

### For API Testing:
```bash
# Filter API calls only
mitmdump --mode transparent --listen-host 0.0.0.0 --listen-port 8080 \
  '~u /api/' \
  --save-stream-file api-${TIMESTAMP}.dump
```

### For Security Analysis:
```python
# Script: security-check.py
from mitmproxy import http
import re

def response(flow: http.HTTPFlow):
    # Check for sensitive data in responses
    patterns = {
        'api_key': r'api[_-]?key["\s:=]+([a-zA-Z0-9_-]+)',
        'password': r'password["\s:=]+([^"&\s]+)',
        'token': r'token["\s:=]+([a-zA-Z0-9_-]+)',
        'secret': r'secret["\s:=]+([a-zA-Z0-9_-]+)'
    }
    
    for name, pattern in patterns.items():
        matches = re.findall(pattern, flow.response.text, re.IGNORECASE)
        if matches:
            print(f"🚨 Found {name} in {flow.request.pretty_url}: {matches}")
```

Run:
```bash
mitmdump -s security-check.py --mode transparent \
  --listen-host 0.0.0.0 --listen-port 8080
```

## Troubleshooting

### Certificate Not Working
```bash
# Regenerate certificates
rm -rf ~/.mitmproxy
mitmproxy  # Will regenerate on first run
```

### Port Already in Use
```bash
# Check what's using port 8080
lsof -i :8080

# Use different port
mitmproxy --listen-port 8888
```

### Invisible Proxying Not Working
Ensure Pi routing rules redirect to correct port:
```bash
# On Pi
sudo iptables -t nat -L -n -v | grep 8080
```

## Resources

- **Documentation**: https://docs.mitmproxy.org
- **Examples**: https://github.com/mitmproxy/mitmproxy/tree/main/examples
- **Community**: https://discourse.mitmproxy.org

## Integration with MitM-Pi

To switch from Burp Suite to mitmproxy:

1. Stop Burp Suite
2. Start mitmproxy on port 8080
3. Use same Android certificate installation process
4. Everything else stays the same!

Both tools work identically with the transparent proxy setup on MitM-Pi.
