#!/bin/bash

# Test script for SoX recording on macOS
# This script tests recording functionality without involving any transcription

# Set up test variables
TEST_DURATION=3
TEST_AUDIO_FILE="/tmp/whisper_test_recording.wav"
LOG_FILE="/tmp/sox_test.log"

echo "=== SoX Recording Test ===" | tee -a "$LOG_FILE"
echo "Testing if SoX can record audio properly on macOS" | tee -a "$LOG_FILE"
echo "Recording for $TEST_DURATION seconds..." | tee -a "$LOG_FILE"

# Check if SoX is installed
if ! command -v sox &> /dev/null; then
    echo "ERROR: SoX is not installed. Please install with 'brew install sox'" | tee -a "$LOG_FILE"
    exit 1
fi

# Remove any existing test file
rm -f "$TEST_AUDIO_FILE"

# Start recording
echo "Starting recording with SoX..." | tee -a "$LOG_FILE"
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

# Check if file was created
if [ -f "$TEST_AUDIO_FILE" ]; then
    FILE_SIZE=$(du -k "$TEST_AUDIO_FILE" | cut -f1)
    echo "Recording saved to $TEST_AUDIO_FILE (size: ${FILE_SIZE}KB)" | tee -a "$LOG_FILE"
    
    if [ "$FILE_SIZE" -eq 0 ]; then
        echo "WARNING: Recording file exists but is empty. No audio was captured." | tee -a "$LOG_FILE"
        echo "Check your microphone settings in System Preferences." | tee -a "$LOG_FILE"
        exit 1
    else
        echo "SUCCESS: Recording file has data ($FILE_SIZE KB)" | tee -a "$LOG_FILE"
        echo "Playing back the recording..." | tee -a "$LOG_FILE"
        afplay "$TEST_AUDIO_FILE"
        exit 0
    fi
else
    echo "ERROR: Recording file was not created!" | tee -a "$LOG_FILE"
    echo "SoX failed to create the audio file." | tee -a "$LOG_FILE"
    exit 1
fi 