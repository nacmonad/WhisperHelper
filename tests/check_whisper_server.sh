#!/bin/bash

# Script to check if the Whisper server is running properly
# This helps diagnose connectivity issues and server status

# Load configuration (you can change these directly in this script)
WHISPER_API_URL="http://10.0.0.60:8080/inference"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Temporary files
CURL_OUTPUT="/tmp/whisper_server_check.json"

# Print with colors
print_ok() {
  echo -e "${GREEN}[OK]${NC} $1"
}

print_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Parse the API URL
API_HOST=$(echo "$WHISPER_API_URL" | sed -E 's#^https?://##' | sed -E 's#/.*$##' | sed -E 's#:[0-9]+$##')
API_PORT=$(echo "$WHISPER_API_URL" | grep -oE ':[0-9]+' | cut -d':' -f2)
if [ -z "$API_PORT" ]; then
  if [[ "$WHISPER_API_URL" == https://* ]]; then
    API_PORT=443
  else
    API_PORT=80
  fi
fi

echo "======= Whisper Server Connectivity Check ======="
echo "Testing connection to $WHISPER_API_URL"
echo "Server: $API_HOST:$API_PORT"
echo "-----------------------------------------------"

# Step 1: Test basic connectivity with ping
echo "Step 1: Testing basic network connectivity..."
if ping -c 1 -W 2 "$API_HOST" > /dev/null 2>&1; then
  print_ok "Host $API_HOST is reachable (ping successful)"
else
  print_error "Cannot ping $API_HOST - check if server is online and network is connected"
  echo "  - Verify that $API_HOST is the correct IP address"
  echo "  - Check your network connection"
  echo "  - Make sure the server is running"
  exit 1
fi

# Step 2: Test TCP connection to the port
echo "Step 2: Testing port connectivity..."
if timeout 3 bash -c "</dev/tcp/$API_HOST/$API_PORT" 2>/dev/null; then
  print_ok "Port $API_PORT on $API_HOST is open and accepting connections"
else
  print_error "Cannot connect to $API_HOST:$API_PORT - port may be closed or blocked"
  echo "  - Verify that the server is running on port $API_PORT"
  echo "  - Check if a firewall is blocking the connection"
  echo "  - Make sure the Whisper service is started"
  exit 1
fi

# Step 3: Send a simple HTTP request to check API
echo "Step 3: Testing API endpoint..."
if curl -s -o /dev/null -w "%{http_code}" "$WHISPER_API_URL" -m 5 | grep -q -E '40[0-9]|200'; then
  print_ok "API endpoint is responding"
else
  print_warn "API endpoint did not respond with expected status code"
  echo "  - The server may be running but the API endpoint might be different"
  echo "  - Check if '$WHISPER_API_URL' is the correct endpoint"
fi

# Step 4: Test with a minimal audio sample
echo "Step 4: Testing API with minimal audio sample..."

# Create a small test audio file if we have sox
if command -v sox &> /dev/null; then
  TEST_AUDIO="/tmp/whisper_test.wav"
  echo "Creating test audio file with sox..."
  sox -n -r 16000 -c 1 -b 16 "$TEST_AUDIO" synth 1 sine 400 > /dev/null 2>&1
  
  # Send a test request with a small audio file
  echo "Sending test request to API..."
  curl -s -X POST \
    "$WHISPER_API_URL" \
    -H "Content-Type: multipart/form-data" \
    -F "file=@$TEST_AUDIO" \
    -F "model=whisper-1" \
    --connect-timeout 3 \
    --max-time 10 \
    -o "$CURL_OUTPUT" > /dev/null 2>&1
  
  if [ -f "$CURL_OUTPUT" ] && [ -s "$CURL_OUTPUT" ]; then
    if grep -q '"text"' "$CURL_OUTPUT"; then
      print_ok "API successfully processed test audio"
      echo "Response: $(cat "$CURL_OUTPUT")"
    else
      print_warn "API responded but response format is unexpected"
      echo "Response: $(cat "$CURL_OUTPUT")"
    fi
  else
    print_error "API failed to process test audio or returned empty response"
    echo "  - Check server logs for errors"
    echo "  - Verify the server is properly configured"
  fi
  
  # Clean up
  rm -f "$TEST_AUDIO" "$CURL_OUTPUT"
else
  print_warn "sox not found - skipping audio test"
  echo "  - Install sox to enable audio testing: sudo apt-get install sox"
fi

echo "-----------------------------------------------"
echo "Diagnosis complete"
echo "If all tests passed, but you're still having issues, check:"
echo "1. The server might be overloaded or hanging"
echo "2. The API timeout might be too short"
echo "3. The audio file being sent might be too large"
echo "4. There might be issues with the server's configuration"
echo "5. Network conditions might be unstable"
echo "-----------------------------------------------" 