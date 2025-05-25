#!/bin/bash

# Test script for WhisperHelper with sample audio
WHISPER_API_URL="http://10.0.0.60:8080/inference"
TEMP_AUDIO_FILE="/tmp/whisper_sample_test.wav"
LOG_FILE="/tmp/whisper_sample_test.log"

echo "=== WhisperHelper Sample Audio Test ==="

# Create a test audio file with speech (tone + speech simulation)
echo "Creating sample test audio file with speech pattern..."
if command -v sox > /dev/null; then
  # Generate a simple 2 second audio with varying tones to simulate speech
  sox -n -r 16000 -c 1 "$TEMP_AUDIO_FILE" synth 0.3 sine 440 synth 0.3 sine 880 synth 0.3 sine 660 synth 0.3 sine 550 synth 0.3 sine 770 synth 0.5 sine 330
  echo "Created sample test audio file: $TEMP_AUDIO_FILE ($(du -h "$TEMP_AUDIO_FILE" | cut -f1))"
else
  echo "ERROR: sox is not installed. Cannot create test audio file."
  exit 1
fi

# Test API with curl
echo "Testing API with sample audio file..."
echo "Sending request to $WHISPER_API_URL with 15-second timeout"

curl -v -X POST \
  "$WHISPER_API_URL" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$TEMP_AUDIO_FILE" \
  -F "model=whisper-1" \
  --connect-timeout 5 \
  --max-time 15 2>&1 | tee "$LOG_FILE"

CURL_STATUS=$?
if [ $CURL_STATUS -ne 0 ]; then
  echo "ERROR: curl failed with status code $CURL_STATUS"
else
  echo "API request completed!"
fi

echo
echo "=== Debugging Info ==="
echo "If the server returned an empty transcription (\"text\":\"\"), it means:"
echo "1. The server is working correctly but could not detect speech in the audio"
echo "2. The sample tone file might not be recognized as speech"
echo "3. Try the test with a real speech recording"

echo
echo "=== Potential Solutions ==="
echo "1. Create a real speech recording using: sox -d -r 16000 -c 1 /tmp/real_speech.wav trim 0 5"
echo "2. Test it with: curl -v -X POST \"$WHISPER_API_URL\" -H \"Content-Type: multipart/form-data\" -F \"file=@/tmp/real_speech.wav\""
echo "3. Consider checking the server's whisper.cpp configuration"
echo "4. Try restarting the whisper.cpp server"

echo
echo "=== Test completed ==="

# Clean up
rm -f "$TEMP_AUDIO_FILE" 