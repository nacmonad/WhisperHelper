#!/bin/bash

# Start WhisperHelper service
# This script will start xbindkeys with the configuration in the WhisperHelper directory

# Kill any existing xbindkeys instance
pkill xbindkeys || true

# Clean up any lingering temporary files
rm -f /tmp/whisper_helper_recording.wav
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper.lock
rm -f /tmp/whisper_helper_recording_pid
rm -f /tmp/whisper_helper_transcript.txt

# Copy the configuration file to the home directory
cp "$(dirname "$0")/.xbindkeysrc" "$HOME/.xbindkeysrc"

# Start xbindkeys
xbindkeys

# Notify user that WhisperHelper is running
notify-send "WhisperHelper" "WhisperHelper is now running. Press Alt+r for 5-second recording or Alt+Shift+r (press and hold) for variable-length recording." -t 5000

echo "WhisperHelper is now running."
echo "Press Alt+r for 5-second recording"
echo "Press and hold Alt+Shift+r for variable-length recording (release to transcribe)" 