#!/bin/bash

# Start WhisperHelper service
# This script will start xbindkeys with the configuration in the WhisperHelper directory

# Kill any existing xbindkeys instance
pkill xbindkeys || true

# Clean up any lingering temporary files
rm -f /tmp/whisper_helper_recording.wav
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper.lock

# Copy the configuration file to the home directory
cp "$(dirname "$0")/.xbindkeysrc" "$HOME/.xbindkeysrc"

# Start xbindkeys
xbindkeys

# Notify user that WhisperHelper is running
notify-send "WhisperHelper" "WhisperHelper is now running. Press Alt+r to record and automatically transcribe in 5 seconds." -t 5000

echo "WhisperHelper is now running."
echo "Press Alt+r to record for 5 seconds and automatically transcribe." 