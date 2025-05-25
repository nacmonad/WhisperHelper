#!/bin/bash

# Record a speech sample and test it with the Whisper API
WHISPER_API_URL="http://10.0.0.60:8080/inference"
SPEECH_FILE="/tmp/whisper_speech_test.wav"
LOG_FILE="/tmp/whisper_speech_test.log"

echo "=== WhisperHelper Speech Recording Test ==="
echo "This will record 5 seconds of audio and send it to the Whisper API"

# Check for sox
if ! command -v sox > /dev/null; then
  echo "ERROR: sox is not installed. Cannot record audio."
  exit 1
fi

# Record audio
echo "Recording will start in 3 seconds..."
echo "Please speak clearly into your microphone"
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1
echo "Recording now... (5 seconds)"

# Record 5 seconds of audio
sox -d -r 16000 -c 1 -b 16 "$SPEECH_FILE" trim 0 5

echo "Recording completed: $SPEECH_FILE ($(du -h "$SPEECH_FILE" | cut -f1))"
echo

# Send to API
echo "Sending to Whisper API at $WHISPER_API_URL"
echo "This may take a few seconds..."

# Use a longer timeout for this test
curl -v -X POST \
  "$WHISPER_API_URL" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$SPEECH_FILE" \
  -F "model=whisper-1" \
  --connect-timeout 5 \
  --max-time 30 2>&1 | tee "$LOG_FILE"

CURL_STATUS=$?
if [ $CURL_STATUS -ne 0 ]; then
  echo "ERROR: curl failed with status code $CURL_STATUS"
  exit 1
fi

echo
echo "=== Results ==="
echo "If you received a valid transcription, the API is working correctly!"
echo "If you received an empty transcription (\"text\":\"\"), check:"
echo "1. Make sure you spoke clearly during the recording"
echo "2. Check your microphone is working properly"
echo "3. The server might need more time to process longer audio"
echo "4. The server's whisper.cpp might need to be restarted or reconfigured"

echo
echo "=== Next Steps ==="
echo "1. If this test worked, try using the regular WhisperHelper hotkeys"
echo "2. If it failed, you may need to contact the server administrator"
echo "3. If you keep getting timeouts, consider reducing the WHISPER_API_TIMEOUT in whisper_helper.sh"

echo
echo "=== Test completed ===" 