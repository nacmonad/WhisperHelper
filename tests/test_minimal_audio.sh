#!/bin/bash

# Generate and test minimal audio file for WhisperHelper
WHISPER_API_URL="http://10.0.0.60:8080/inference"
TEMP_AUDIO_FILE="/tmp/whisper_minimal_test.wav"
LOG_FILE="/tmp/whisper_minimal_test.log"

echo "=== WhisperHelper Minimal Audio Test ==="

# Create a very small audio file (0.5 seconds of sine wave)
echo "Creating minimal test audio file..."
if command -v sox > /dev/null; then
  # Generate a simple 0.5 second sine wave at 440Hz
  sox -n -r 16000 -c 1 "$TEMP_AUDIO_FILE" synth 0.5 sine 440
  echo "Created minimal test audio file: $TEMP_AUDIO_FILE ($(du -h "$TEMP_AUDIO_FILE" | cut -f1))"
else
  echo "ERROR: sox is not installed. Cannot create test audio file."
  exit 1
fi

# Test API with curl, using a very short timeout
echo "Testing API with minimal audio file..."
echo "Sending request to $WHISPER_API_URL with 10-second timeout"

curl -v -X POST \
  "$WHISPER_API_URL" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$TEMP_AUDIO_FILE" \
  -F "model=whisper-1" \
  --connect-timeout 5 \
  --max-time 10 2>&1 | tee "$LOG_FILE"

CURL_STATUS=$?
if [ $CURL_STATUS -ne 0 ]; then
  echo "ERROR: curl failed with status code $CURL_STATUS"
  case $CURL_STATUS in
    28) 
      echo "Error: Connection timed out. The server is likely hanging during processing."
      echo "Possible causes:"
      echo "1. Server is overloaded or has insufficient resources"
      echo "2. Whisper.cpp model loading issues"
      echo "3. Server configuration problems"
      ;;
    *) echo "Error: Curl failed with code $CURL_STATUS" ;;
  esac
else
  echo "API request completed!"
  echo "Check the output above for any response data"
fi

echo "Test log saved to: $LOG_FILE"

# Let's try with different content type and parameters
echo
echo "Trying alternative request format..."
curl -v -X POST \
  "$WHISPER_API_URL" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$TEMP_AUDIO_FILE" \
  -F "language=en" \
  --connect-timeout 5 \
  --max-time 10 2>&1 | tee -a "$LOG_FILE"

echo
echo "=== Test completed ==="

# Clean up
rm -f "$TEMP_AUDIO_FILE" 