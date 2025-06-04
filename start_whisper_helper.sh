#!/bin/bash

# Start WhisperHelper service - Cross-platform version
# This script will start the appropriate hotkey manager for each platform

# Get the absolute path to the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Detect operating system
detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*)  echo "linux" ;;
    *)       echo "unknown" ;;
  esac
}

OS_TYPE=$(detect_os)

# Clean up any lingering temporary files
rm -f /tmp/whisper_helper_recording.wav
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper.lock
rm -f /tmp/whisper_helper_recording_pid
rm -f /tmp/whisper_helper_transcript.txt
rm -f /tmp/whisper_helper_initializing
rm -f /tmp/whisper_helper_continuous.wav
rm -f /tmp/whisper_helper_daemon_pid

# Function to start the SoX daemon for instant recording
start_sox_daemon() {
  echo "Starting SoX daemon for instant recording..."
  
  # Kill any existing SoX daemon
  if [ -f "/tmp/whisper_helper_daemon_pid" ]; then
    local daemon_pid=$(cat "/tmp/whisper_helper_daemon_pid" 2>/dev/null)
    if [ -n "$daemon_pid" ] && kill -0 "$daemon_pid" 2>/dev/null; then
      kill "$daemon_pid" 2>/dev/null || true
      sleep 0.5
    fi
  fi
  
  # Remove old continuous recording file
  rm -f /tmp/whisper_helper_continuous.wav
  
  # Start continuous recording to a temporary file
  sox -d -r 16000 -c 1 -b 16 /tmp/whisper_helper_continuous.wav &
  local sox_pid=$!
  echo "$sox_pid" > /tmp/whisper_helper_daemon_pid
  
  # Wait for SoX to initialize (this happens only once during startup)
  echo "Initializing audio driver (one-time setup)..."
  sleep 2
  
  # Verify SoX daemon is running
  if kill -0 "$sox_pid" 2>/dev/null; then
    echo "SoX daemon started successfully (PID: $sox_pid)"
    echo "Audio recording is now ready with zero-delay startup!"
    return 0
  else
    echo "Failed to start SoX daemon"
    rm -f /tmp/whisper_helper_daemon_pid
    return 1
  fi
}

case "$OS_TYPE" in
  "linux")
    echo "Starting WhisperHelper for Linux..."
    
    # Kill any existing xbindkeys instance
    pkill xbindkeys || true

    # Start SoX daemon for instant recording
    start_sox_daemon

    # Copy the configuration file to the home directory
    cp "$SCRIPT_DIR/.xbindkeysrc" "$HOME/.xbindkeysrc"

    # Start xbindkeys
    xbindkeys

    # Notify user that WhisperHelper is running
    notify-send "WhisperHelper" "WhisperHelper is now running. Press Alt+r for 5-second recording or Alt+Shift+r (press and hold) for variable-length recording." -t 5000

    echo "WhisperHelper is now running."
    echo "Press Alt+r for 5-second recording"
    echo "Press and hold Alt+Shift+r for variable-length recording (release to transcribe)"
    ;;
    
  "macos")
    echo "Starting WhisperHelper for macOS..."
    
    # Start SoX daemon for instant recording
    start_sox_daemon

    # Write the Hammerspoon configuration
    HAMMERSPOON_INIT_FILE="$HOME/.hammerspoon/init.lua"
    WHISPER_HELPER_PATH="$SCRIPT_DIR/whisper_helper.sh"
    
    echo "Loading WhisperHelper configuration..."
    cat > "$HAMMERSPOON_INIT_FILE" << EOL
-- WhisperHelper Hammerspoon Configuration
-- This sets up hotkeys for speech-to-text functionality

print("=== WhisperHelper Configuration Loading ===")

local whisperPath = "$WHISPER_HELPER_PATH"

-- Global variable to track recording state
local isRecording = false
local recordingStartTime = nil

-- Function to run WhisperHelper commands
function runWhisperHelper(command)
    print("DEBUG: runWhisperHelper called with command: " .. command)
    local task = hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
        print("DEBUG: Task completed with exit code: " .. exitCode)
        if stdOut then print("DEBUG: stdout: " .. stdOut) end
        if stdErr then print("DEBUG: stderr: " .. stdErr) end
    end, {whisperPath, command})
    
    if task then
        task:start()
        return true
    else
        print("ERROR: Failed to create task for command: " .. command)
        return false
    end
end

-- Push-to-talk: Start recording on press, stop on release
-- Using a more reliable timer-based approach instead of keyUp callback
local pushToTalkHotkey = hs.hotkey.bind({"cmd", "shift"}, "space", function()
    if not isRecording then
        print("DEBUG: Starting push-to-talk recording")
        isRecording = true
        recordingStartTime = hs.timer.secondsSinceEpoch()
        runWhisperHelper("start")
        
        -- Show visual feedback
        hs.alert.show("🎤 Recording... (release to stop)", {
            textColor = {white = 1},
            fillColor = {red = 0.2, green = 0.7, blue = 0.2, alpha = 0.8},
            strokeColor = {white = 1},
            strokeWidth = 2,
            radius = 10,
            atScreenEdge = 0,
            fadeInDuration = 0.1,
            fadeOutDuration = 0.1
        }, "infinite")
    end
end, function()
    if isRecording then
        print("DEBUG: Stopping push-to-talk recording")
        isRecording = false
        local recordingDuration = hs.timer.secondsSinceEpoch() - recordingStartTime
        print("DEBUG: Recording duration: " .. recordingDuration .. " seconds")
        
        -- Clear the recording alert
        hs.alert.closeAll()
        
        runWhisperHelper("stop")
        
        -- Show processing feedback
        hs.alert.show("🔄 Processing...", {
            textColor = {white = 1},
            fillColor = {red = 0.2, green = 0.2, blue = 0.7, alpha = 0.8},
            strokeColor = {white = 1},
            strokeWidth = 2,
            radius = 10,
            atScreenEdge = 0,
            fadeInDuration = 0.1,
            fadeOutDuration = 2.0
        }, 3)
    end
end)

-- 5-second recording hotkey
local fiveSecondHotkey = hs.hotkey.bind({"cmd", "shift"}, "r", function()
    print("DEBUG: 5-second recording triggered")
    hs.alert.show("🎤 Recording for 5 seconds...", {
        textColor = {white = 1},
        fillColor = {red = 0.7, green = 0.2, blue = 0.2, alpha = 0.8},
        strokeColor = {white = 1},
        strokeWidth = 2,
        radius = 10,
        atScreenEdge = 0,
        fadeInDuration = 0.1,
        fadeOutDuration = 5.0
    }, 6)
    runWhisperHelper("record_5_seconds")
end)

print("=== WhisperHelper hotkeys loaded ===")
print("Push-to-talk: Cmd+Shift+Space (hold and release)")
print("5-second recording: Cmd+Shift+R")
print("WhisperHelper is ready!")

-- Notify that configuration is loaded
hs.notify.new({
    title = "WhisperHelper",
    informativeText = "Hotkeys loaded successfully!\\n\\nCmd+Shift+Space: Push-to-talk\\nCmd+Shift+R: 5-second recording",
    autoWithdraw = true,
    withdrawAfter = 3
}):send()
EOL

    echo "Hammerspoon configuration written to $HAMMERSPOON_INIT_FILE"
    
    # Stop any existing Hammerspoon process
    echo "Stopping existing Hammerspoon processes..."
    pkill -f "Hammerspoon" 2>/dev/null || true
    sleep 1
    
    # Start Hammerspoon
    echo "Starting Hammerspoon..."
    if command -v "/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon" >/dev/null 2>&1; then
        nohup "/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon" >/dev/null 2>&1 &
        sleep 2
        echo "Hammerspoon started successfully"
    else
        echo "WARNING: Hammerspoon not found at /Applications/Hammerspoon.app/"
        echo "Please install Hammerspoon from https://www.hammerspoon.org/"
        echo "Or manually start Hammerspoon and reload the config"
    fi
    
    echo ""
    echo "WhisperHelper is now running with zero-delay audio capture!"
    echo ""
    echo "🎤 Hotkeys available:"
    echo "  • Cmd+Shift+Space (hold): Push-to-talk recording"
    echo "  • Cmd+Shift+R: 5-second recording"
    echo ""
    echo "If hotkeys don't work:"
    echo "1. Grant Hammerspoon accessibility permissions in System Preferences"
    echo "2. Make sure Hammerspoon is running (check menu bar)"
    ;;
    
  *)
    echo "Unsupported operating system: $(uname -s)"
    echo "WhisperHelper currently supports Linux and macOS."
    exit 1
    ;;
esac 