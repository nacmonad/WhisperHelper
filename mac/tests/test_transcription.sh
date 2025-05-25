#!/bin/bash

# Test script for Whisper API transcription on macOS
# This script tests the full recording and transcription process

# Get the absolute path to the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Configuration
TEST_DURATION=3
TEST_AUDIO_FILE="/tmp/whisper_test_recording.wav"
LOG_FILE="/tmp/transcription_test.log"
WHISPER_API_URL="http://10.0.0.60:8080/inference"
TRANSCRIPT_FILE="/tmp/whisper_test_transcript.txt"

echo "=== Whisper Transcription Test ===" | tee -a "$LOG_FILE"
echo "Testing full recording and transcription process" | tee -a "$LOG_FILE"

# Check if SoX is installed
if ! command -v sox &> /dev/null; then
    echo "ERROR: SoX is not installed. Please install with 'brew install sox'" | tee -a "$LOG_FILE"
    exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "ERROR: curl is not installed. This should be available by default on macOS" | tee -a "$LOG_FILE"
    exit 1
fi

# Remove any existing test files
rm -f "$TEST_AUDIO_FILE"
rm -f "$TRANSCRIPT_FILE"

echo "Step 1: Recording audio for $TEST_DURATION seconds..." | tee -a "$LOG_FILE"
echo "Please speak into your microphone during recording!"

# Start recording
sox -d -r 16000 -c 1 -b 16 "$TEST_AUDIO_FILE" trim 0 $TEST_DURATION &
SOX_PID=$!

# Show countdown
for i in $(seq $TEST_DURATION -1 1); do
    echo -ne "\rRecording: $i seconds remaining..."
    sleep 1
done
echo -e "\rRecording complete!            " | tee -a "$LOG_FILE"

# Wait for SoX to finish
wait $SOX_PID

# Check if recording file exists and has content
if [ ! -f "$TEST_AUDIO_FILE" ]; then
    echo "ERROR: Recording file was not created!" | tee -a "$LOG_FILE"
    exit 1
fi

FILE_SIZE=$(du -k "$TEST_AUDIO_FILE" | cut -f1)
if [ "$FILE_SIZE" -eq 0 ]; then
    echo "ERROR: Recording file is empty!" | tee -a "$LOG_FILE"
    echo "Check your microphone settings in System Preferences." | tee -a "$LOG_FILE"
    exit 1
fi

echo "Recording saved: $TEST_AUDIO_FILE (size: ${FILE_SIZE}KB)" | tee -a "$LOG_FILE"

echo "Step 2: Sending audio to Whisper API for transcription..." | tee -a "$LOG_FILE"

# Send to API using curl
echo "Sending request to $WHISPER_API_URL..." | tee -a "$LOG_FILE"

# Create temporary files for response and headers
CURL_OUTPUT="/tmp/whisper_test_response.txt"
CURL_HEADERS="/tmp/whisper_test_headers.txt"

# Use curl with timeout
curl -s -X POST \
  "$WHISPER_API_URL" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$TEST_AUDIO_FILE" \
  -F "model=whisper-1" \
  --connect-timeout 5 \
  --max-time 30 \
  -D "$CURL_HEADERS" \
  -o "$CURL_OUTPUT" || CURL_STATUS=$?

if [ -n "$CURL_STATUS" ] && [ "$CURL_STATUS" -ne 0 ]; then
    echo "ERROR: API request failed with curl error code: $CURL_STATUS" | tee -a "$LOG_FILE"
    case $CURL_STATUS in
        6) echo "Could not resolve host. Check your network connection or API URL." | tee -a "$LOG_FILE" ;;
        7) echo "Failed to connect to host. Server may be down or wrong port." | tee -a "$LOG_FILE" ;;
        28) echo "Connection timed out. Server may be overloaded or unreachable." | tee -a "$LOG_FILE" ;;
        *) echo "Curl failed with code $CURL_STATUS." | tee -a "$LOG_FILE" ;;
    esac
    exit 1
fi

# Check if response file exists and has content
if [ ! -f "$CURL_OUTPUT" ]; then
    echo "ERROR: No response received from API!" | tee -a "$LOG_FILE"
    exit 1
fi

if [ ! -s "$CURL_OUTPUT" ]; then
    echo "ERROR: Received empty response from API!" | tee -a "$LOG_FILE"
    exit 1
fi

# Extract the text from the JSON response
RESPONSE=$(cat "$CURL_OUTPUT")
echo "Raw API response: $RESPONSE" | tee -a "$LOG_FILE"

# Parse the JSON response to extract the transcription
if ! echo "$RESPONSE" | grep -q '"text"'; then
    echo "ERROR: Invalid response format. Expected JSON with 'text' field." | tee -a "$LOG_FILE"
    exit 1
fi

TRANSCRIPTION=$(echo "$RESPONSE" | grep -o '"text":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TRANSCRIPTION" ]; then
    echo "WARNING: Empty transcription received from API." | tee -a "$LOG_FILE"
    echo "No speech was detected in the audio." | tee -a "$LOG_FILE"
else
    echo "SUCCESS: Received transcription from API:" | tee -a "$LOG_FILE"
    echo "$TRANSCRIPTION" | tee -a "$LOG_FILE" | tee "$TRANSCRIPT_FILE"
    echo "Transcription saved to $TRANSCRIPT_FILE" | tee -a "$LOG_FILE"
fi

# Clean up
rm -f "$CURL_OUTPUT"
rm -f "$CURL_HEADERS"

echo "Test completed successfully." | tee -a "$LOG_FILE"
exit 0 