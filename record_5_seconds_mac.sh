#!/bin/bash

# Script for 5-second recording and automatic transcription for macOS
# This script records for 5 seconds then automatically stops and transcribes

# Get the absolute path to the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if recording is already in progress
if [ -f "/tmp/whisper_helper.lock" ] || [ -f "/tmp/whisper_helper_recording_pid" ]; then
  echo "Recording already in progress. Please wait for it to complete."
  osascript -e 'display notification "Recording already in progress. Please wait for it to complete." with title "WhisperHelper"'
  exit 1
fi

# Clean up any existing recordings or flags
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper_recording_pid
rm -f /tmp/whisper_helper_transcript.txt

# Notify user
osascript -e 'display notification "Recording for 5 seconds..." with title "WhisperHelper"'
echo "Recording for 5 seconds..."

# Start recording
bash "$SCRIPT_DIR/whisper_helper_mac.sh" start

# Check if recording started properly
sleep 0.5
if [ ! -f "/tmp/whisper_helper.lock" ] && [ ! -f "/tmp/whisper_helper_recording_pid" ]; then
  echo "ERROR: Recording failed to start properly."
  osascript -e 'display notification "Recording failed to start properly." with title "WhisperHelper"'
  exit 1
fi

# Wait for 5 seconds
echo "Recording in progress (5 seconds)..."
sleep 5

# Stop recording and trigger transcription
echo "Stopping recording and transcribing..."
bash "$SCRIPT_DIR/whisper_helper_mac.sh" stop

# Check for transcription results
if [ -f "/tmp/whisper_helper_transcript.txt" ]; then
  # Get content of the transcript
  TRANSCRIPT=$(cat /tmp/whisper_helper_transcript.txt)
  if [ -z "$TRANSCRIPT" ]; then
    echo "No speech detected in recording."
    osascript -e 'display notification "No speech detected in recording." with title "WhisperHelper"'
  else
    echo "Transcription complete: $TRANSCRIPT"
  fi
else
  echo "Transcription file not found. Transcription may have failed."
  osascript -e 'display notification "Transcription may have failed." with title "WhisperHelper"'
fi 