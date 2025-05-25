#!/bin/bash

# Test server status script for WhisperHelper
SERVER_HOST="10.0.0.60"
SERVER_PORT="8080"
BASE_URL="http://${SERVER_HOST}:${SERVER_PORT}"

echo "=== WhisperHelper Server Status Check ==="
echo "Testing server at ${BASE_URL}"

# Check basic connectivity
echo -n "Basic connectivity: "
if ping -c 1 -W 2 "$SERVER_HOST" > /dev/null 2>&1; then
  echo "SUCCESS - Host is reachable"
else
  echo "FAILED - Cannot ping host"
fi

# Test server root endpoint
echo -n "Server root endpoint: "
RESP=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "${BASE_URL}/" 2>/dev/null || echo "FAILED")
if [[ "$RESP" == "200" ]]; then
  echo "SUCCESS - Server responded with 200 OK"
elif [[ "$RESP" == "FAILED" ]]; then
  echo "FAILED - No response from server"
else
  echo "RECEIVED - Server responded with code ${RESP}"
fi

# Test server health endpoint
echo -n "Server health endpoint: "
RESP=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "${BASE_URL}/health" 2>/dev/null || echo "FAILED")
if [[ "$RESP" == "200" ]]; then
  echo "SUCCESS - Server responded with 200 OK"
elif [[ "$RESP" == "FAILED" ]]; then
  echo "FAILED - No response from server"
else
  echo "RECEIVED - Server responded with code ${RESP}"
fi

# Try to get server info without sending an actual transcription request
echo -n "Server info: "
INFO=$(curl -s -m 5 "${BASE_URL}/info" 2>/dev/null || echo "FAILED")
if [[ "$INFO" != "FAILED" ]]; then
  echo "SUCCESS - Received server info:"
  echo "$INFO"
else
  echo "FAILED - No response from server"
fi

# Check memory/CPU usage on the server
echo
echo "=== Checking resource usage (requires password) ==="
echo "Enter password for ssh to ${SERVER_HOST} or press Ctrl+C to skip:"
ssh "${SERVER_HOST}" 'echo "CPU usage:"; top -b -n 1 | head -15; echo; echo "Memory usage:"; free -m; echo; echo "Disk usage:"; df -h'

echo
echo "=== Debugging transcription issue ==="
echo "1. Your server seems to hang during transcription processing"
echo "2. Check for these possible issues:"
echo "   - Server CPU/memory limitations during processing"
echo "   - Audio file format/size issues"
echo "   - Whisper.cpp configuration problems"
echo "3. Try these troubleshooting steps:"
echo "   - Try a very small (1-2 second) audio file"
echo "   - Check server logs for errors"
echo "   - Check if server needs to be restarted"
echo "   - Verify whisper.cpp is properly installed"

echo
echo "=== Test completed ===" 