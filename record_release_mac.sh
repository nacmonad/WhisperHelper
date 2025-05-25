#!/bin/bash

# Script for handling key release (triggered when key is released) for macOS
# This script stops recording and triggers transcription

# Get the absolute path to the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Add a short delay to ensure everything is ready
sleep 0.2

# Check if recording is in progress
if [ ! -f "/tmp/whisper_helper.lock" ] && [ ! -f "/tmp/whisper_helper_recording_pid" ]; then
  echo "No recording in progress. Nothing to stop."
  osascript -e 'display notification "No recording in progress." with title "WhisperHelper"'
  exit 1
fi

# Stop recording and trigger transcription
echo "Key released. Stopping recording and transcribing..."
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