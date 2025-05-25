#!/bin/bash

# Start WhisperHelper service for macOS
# This script will configure and start WhisperHelper

# Get the absolute path to the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Clean up any lingering temporary files
rm -f /tmp/whisper_helper_recording.wav
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper.lock
rm -f /tmp/whisper_helper_recording_pid
rm -f /tmp/whisper_helper_transcript.txt

# Create Hammerspoon configuration
HAMMERSPOON_CONFIG_DIR="$HOME/.hammerspoon"
HAMMERSPOON_INIT_FILE="$HAMMERSPOON_CONFIG_DIR/init.lua"

# Check if Hammerspoon is installed
if ! command -v hammerspoon &> /dev/null; then
    echo "Hammerspoon is not installed. Please install it with: brew install --cask hammerspoon"
    echo "After installation, run this script again."
    exit 1
fi

# Create Hammerspoon config directory if it doesn't exist
mkdir -p "$HAMMERSPOON_CONFIG_DIR"

# Create or update Hammerspoon configuration
cat > "$HAMMERSPOON_INIT_FILE" << EOL
-- WhisperHelper configuration for Hammerspoon
-- Cmd+Option+r records for 5 seconds and automatically transcribes
-- Cmd+Option+Shift+r for press-to-hold recording (release to transcribe)

local whisperHelperDir = "$SCRIPT_DIR"

-- Key bindings
local cmdOptionR = {{"cmd", "option"}, "r"}
local cmdOptionShiftR = {{"cmd", "option", "shift"}, "r"}

-- Cmd+Option+r to record for 5 seconds
hs.hotkey.bind(cmdOptionR[1], cmdOptionR[2], function()
    hs.execute(whisperHelperDir .. "/record_5_seconds_mac.sh")
end)

-- Cmd+Option+Shift+r press event (start recording)
local recordingHotkey = hs.hotkey.new(cmdOptionShiftR[1], cmdOptionShiftR[2], function()
    -- Check if recording is not in progress
    if not hs.fs.attributes("/tmp/whisper_helper.lock") then
        hs.execute(whisperHelperDir .. "/record_press_hold_mac.sh")
    end
end, function()
    -- On key release
    hs.execute(whisperHelperDir .. "/record_release_mac.sh")
end)

recordingHotkey:enable()

-- Show notification that WhisperHelper is running
hs.notify.new({title="WhisperHelper", informativeText="WhisperHelper is now running. Press Cmd+Option+r for 5-second recording or Cmd+Option+Shift+r (press and hold) for variable-length recording."}):send()
EOL

# Reload Hammerspoon configuration
osascript -e 'tell application "Hammerspoon" to reload config'

# Notify user that WhisperHelper is running
osascript -e 'display notification "WhisperHelper is now running. Press Cmd+Option+r for 5-second recording or Cmd+Option+Shift+r (press and hold) for variable-length recording." with title "WhisperHelper"'

echo "WhisperHelper is now running."
echo "Press Cmd+Option+r for 5-second recording"
echo "Press and hold Cmd+Option+Shift+r for variable-length recording (release to transcribe)" 