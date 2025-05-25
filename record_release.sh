#!/bin/bash

# Script for handling key release (triggered when key is released)
# This script stops recording and triggers transcription

# Add a short delay to ensure everything is ready
sleep 0.2

# Check if recording is in progress
if [ ! -f "/tmp/whisper_helper.lock" ] && [ ! -f "/tmp/whisper_helper_recording_pid" ]; then
  echo "No recording in progress. Nothing to stop."
  exit 1
fi

# Stop recording and trigger transcription
echo "Key released. Stopping recording and transcribing..."
bash "$(dirname "$0")/whisper_helper.sh" stop

# Check for transcription results
if [ -f "/tmp/whisper_helper_transcript.txt" ]; then
  # Get content of the transcript
  TRANSCRIPT=$(cat /tmp/whisper_helper_transcript.txt)
  if [ -z "$TRANSCRIPT" ]; then
    echo "Transcription completed but no speech was detected (empty response)."
  else
    echo "Transcription completed: $TRANSCRIPT"
  fi
elif grep -q "Text successfully inserted" /tmp/whisper_helper.log 2>/dev/null; then
  echo "Transcription successful and text inserted."
elif grep -q "Text copied to clipboard" /tmp/whisper_helper.log 2>/dev/null; then
  echo "Transcription successful and copied to clipboard."
elif grep -q "Transcription failed" /tmp/whisper_helper.log 2>/dev/null; then
  echo "Transcription failed. Check log file for details."
else
  echo "Process completed with unknown status. Check log file for details."
fi

echo "Press-and-hold recording completed." 