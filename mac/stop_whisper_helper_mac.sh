#!/bin/bash

# Stop WhisperHelper service for macOS
echo "Stopping WhisperHelper..."

# Clean up any lingering temporary files
rm -f /tmp/whisper_helper_recording.wav
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper.lock
rm -f /tmp/whisper_helper_recording_pid
rm -f /tmp/whisper_helper_transcript.txt

# Notify user
osascript -e 'display notification "WhisperHelper service stopped." with title "WhisperHelper"'

# Kill any running sox processes (may be leftover recording sessions)
pkill -f sox || true

echo "WhisperHelper has been stopped." 