#!/bin/bash

# Script for press-to-hold recording (triggered by key press)
# This script starts recording and creates a flag file to indicate recording is in progress

# Clean up any existing recordings or flags
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper_recording_pid
rm -f /tmp/whisper_helper_transcript.txt

# Start recording
echo "Starting recording (press-and-hold mode)..."
bash "$(dirname "$0")/whisper_helper.sh" start

# Check if recording started properly
sleep 0.5
if [ ! -f "/tmp/whisper_helper.lock" ] && [ ! -f "/tmp/whisper_helper_recording_pid" ]; then
  echo "ERROR: Recording failed to start properly."
  exit 1
fi

echo "Recording in progress... Release key to stop and transcribe." 