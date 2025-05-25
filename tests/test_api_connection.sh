#!/bin/bash

# Test script for WhisperHelper API connection
WHISPER_API_URL="http://10.0.0.60:8080/inference"
TEMP_AUDIO_FILE="/tmp/whisper_helper_test_recording.wav"
LOG_FILE="/tmp/whisper_helper_test.log"

echo "=== WhisperHelper API Connection Test ==="
echo "Testing connection to: $WHISPER_API_URL"

# Extract hostname from URL
HOST=$(echo "$WHISPER_API_URL" | sed -E 's#^https?://##' | sed -E 's#/.*$##' | sed -E 's#:[0-9]+$##')
PORT=$(echo "$WHISPER_API_URL" | grep -o ':[0-9]\+' | grep -o '[0-9]\+' || echo "80")

echo "Target host: $HOST"
echo "Target port: $PORT"

# Test ping
echo -n "Ping test: "
if ping -c 1 -W 2 "$HOST" > /dev/null 2>&1; then
  echo "SUCCESS - Host is reachable"
else
  echo "FAILED - Cannot ping host"
  echo "This might be normal if the host blocks ICMP packets"
fi

# Test port
echo -n "Port test: "
if nc -z -w 2 "$HOST" "$PORT" > /dev/null 2>&1; then
  echo "SUCCESS - Port $PORT is open"
else
  echo "FAILED - Port $PORT is closed or unreachable"
  echo "Check if the server is running and the port is correct"
  exit 1
fi

# Create a test audio file (1 second of silence)
echo "Creating test audio file..."
if command -v sox > /dev/null; then
  sox -n -r 16000 -c 1 "$TEMP_AUDIO_FILE" trim 0.0 1.0
  echo "Created test audio file: $TEMP_AUDIO_FILE"
else
  echo "ERROR: sox is not installed. Cannot create test audio file."
  exit 1
fi

# Test API with curl
echo "Testing API with curl..."
echo "Sending request to $WHISPER_API_URL"

curl -v -X POST \
  "$WHISPER_API_URL" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$TEMP_AUDIO_FILE" \
  -F "model=whisper-1" \
  --connect-timeout 5 \
  --max-time 30 2>&1 | tee "$LOG_FILE"

CURL_STATUS=$?
if [ $CURL_STATUS -ne 0 ]; then
  echo "ERROR: curl failed with status code $CURL_STATUS"
  case $CURL_STATUS in
    6) echo "Error: Could not resolve host. Check your network connection or API URL." ;;
    7) echo "Error: Failed to connect to host. Server may be down or wrong port." ;;
    28) echo "Error: Connection timed out. Server may be overloaded or unreachable." ;;
    *) echo "Error: Curl failed with code $CURL_STATUS. Check log for details." ;;
  esac
else
  echo "API request completed with status $CURL_STATUS"
  echo "Check the output above for any API errors or response data"
fi

echo "Test log saved to: $LOG_FILE"
echo "=== Test completed ==="

# Clean up
rm -f "$TEMP_AUDIO_FILE" 