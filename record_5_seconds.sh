#!/bin/bash

# Script to record for 5 seconds and automatically transcribe
echo "Starting 5-second recording..."

# Clean up any existing recordings or flags
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper_recording_pid
rm -f /tmp/whisper_helper_transcript.txt

# Start recording
bash "$(dirname "$0")/whisper_helper.sh" start

# Check if recording process is running
sleep 1
if [ ! -f "/tmp/whisper_helper.lock" ] && [ ! -f "/tmp/whisper_helper_recording_pid" ]; then
  echo "ERROR: Recording failed to start properly."
  exit 1
fi

# Wait for 5 seconds
echo "Recording for 5 seconds..."
sleep 5

# Note the current log file size to check for new content later
LOG_SIZE_BEFORE=$(wc -l < /tmp/whisper_helper.log 2>/dev/null || echo "0")

# Stop recording and process
echo "Stopping recording and processing audio..."
bash "$(dirname "$0")/whisper_helper.sh" stop

# Give a moment for logs to be updated
sleep 1

# Check for transcription success in recent log entries
if grep -q "Text successfully inserted" /tmp/whisper_helper.log; then
  echo "Transcription successful and text inserted."
elif grep -q "Text copied to clipboard" /tmp/whisper_helper.log; then
  echo "Transcription successful and copied to clipboard."
elif grep -q "Transcription failed" /tmp/whisper_helper.log; then
  echo "Transcription failed. Check log file for details."
else
  echo "Process completed. Check log file for details."
fi

# Clean up any remaining files
rm -f /tmp/whisper_helper_transcript.txt

echo "5-second recording completed" 