#!/bin/bash

# Stop WhisperHelper service
echo "Stopping WhisperHelper..."

# Kill xbindkeys process
pkill xbindkeys

# Clean up any lingering temporary files
rm -f /tmp/whisper_helper_recording.wav
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper.lock
rm -f /tmp/whisper_helper_recording_pid
rm -f /tmp/whisper_helper_transcript.txt

# Notify user
notify-send "WhisperHelper" "WhisperHelper service stopped." -t 3000

echo "WhisperHelper has been stopped." 