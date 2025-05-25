#!/bin/bash

# Test script for WhisperHelper
echo "Testing WhisperHelper functionality..."

# Clean up any previous state
rm -f /tmp/whisper_helper_recording.wav
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper.lock
rm -f /tmp/whisper_helper_recording_pid
rm -f /tmp/whisper_helper.log

# Start recording
echo "Starting recording (will record for 5 seconds)..."
bash "$(dirname "$0")/whisper_helper.sh" start

# Give the process some time to start
echo "Waiting a moment for recording to start..."
sleep 1

# Wait for 5 seconds to record
echo "Recording for 5 seconds..."
sleep 5

# Stop recording and process
echo "Stopping recording and processing audio..."
bash "$(dirname "$0")/whisper_helper.sh" stop

# Wait to ensure processing completes
sleep 2

# Display log file
echo -e "\nDebug log contents:"
echo "----------------------------------------------"
cat /tmp/whisper_helper.log
echo "----------------------------------------------"

# Check if audio file was created during the process
if [ -f "/tmp/whisper_helper_recording.wav" ]; then
  echo -e "\nAudio file exists and has size: $(du -h /tmp/whisper_helper_recording.wav | cut -f1)"
else
  echo -e "\nNo audio file found after recording."
fi

echo -e "\nTest completed." 