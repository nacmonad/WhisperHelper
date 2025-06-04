#!/bin/bash

# Stop WhisperHelper service - Cross-platform version
# This script will stop the appropriate hotkey manager for each platform

# Detect operating system
detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*)  echo "linux" ;;
    *)       echo "unknown" ;;
  esac
}

OS_TYPE=$(detect_os)

case "$OS_TYPE" in
  "linux")
    echo "Stopping WhisperHelper for Linux..."
    
    # Kill xbindkeys process
    pkill xbindkeys || true
    
    # Stop SoX daemon if running
    if [ -f "/tmp/whisper_helper_daemon_pid" ]; then
      daemon_pid=$(cat "/tmp/whisper_helper_daemon_pid" 2>/dev/null)
      if [ -n "$daemon_pid" ] && kill -0 "$daemon_pid" 2>/dev/null; then
        echo "Stopping SoX daemon (PID: $daemon_pid)..."
        kill "$daemon_pid" 2>/dev/null || true
        sleep 0.5
      fi
    fi
    
    # Clean up any lingering files
    rm -f /tmp/whisper_helper_recording.wav
    rm -f /tmp/whisper_helper_stop_recording
    rm -f /tmp/whisper_helper.lock
    rm -f /tmp/whisper_helper_recording_pid
    rm -f /tmp/whisper_helper_transcript.txt
    rm -f /tmp/whisper_helper_initializing
    rm -f /tmp/whisper_helper_continuous.wav
    rm -f /tmp/whisper_helper_daemon_pid
    rm -f /tmp/whisper_helper_start_marker
    
    # Notify user
    notify-send "WhisperHelper" "WhisperHelper stopped." -t 2000
    
    echo "WhisperHelper stopped."
    ;;
    
  "macos")
    echo "Stopping WhisperHelper for macOS..."
    
    # Stop Hammerspoon first
    echo "Stopping Hammerspoon..."
    pkill -f "Hammerspoon" 2>/dev/null || true
    sleep 1
    
    # Stop SoX daemon if running
    if [ -f "/tmp/whisper_helper_daemon_pid" ]; then
      daemon_pid=$(cat "/tmp/whisper_helper_daemon_pid" 2>/dev/null)
      if [ -n "$daemon_pid" ] && kill -0 "$daemon_pid" 2>/dev/null; then
        echo "Stopping SoX daemon (PID: $daemon_pid)..."
        kill "$daemon_pid" 2>/dev/null || true
        sleep 0.5
      fi
    fi
    
    # Clear Hammerspoon configuration
    HAMMERSPOON_INIT_FILE="$HOME/.hammerspoon/init.lua"
    if [ -f "$HAMMERSPOON_INIT_FILE" ]; then
      cat > "$HAMMERSPOON_INIT_FILE" << 'EOL'
-- WhisperHelper has been stopped
-- Restart it by running start_whisper_helper.sh

print("WhisperHelper is stopped. Run start_whisper_helper.sh to restart.")

-- Clear any existing hotkeys
hs.hotkey.deleteAll()

-- Show notification that WhisperHelper is stopped
hs.notify.new({
    title = "WhisperHelper",
    informativeText = "WhisperHelper has been stopped.\n\nRun start_whisper_helper.sh to restart.",
    autoWithdraw = true,
    withdrawAfter = 3
}):send()
EOL
      echo "Hammerspoon configuration cleared"
    fi
    
    # Clean up any lingering files
    rm -f /tmp/whisper_helper_recording.wav
    rm -f /tmp/whisper_helper_stop_recording
    rm -f /tmp/whisper_helper.lock
    rm -f /tmp/whisper_helper_recording_pid
    rm -f /tmp/whisper_helper_transcript.txt
    rm -f /tmp/whisper_helper_initializing
    rm -f /tmp/whisper_helper_continuous.wav
    rm -f /tmp/whisper_helper_daemon_pid
    rm -f /tmp/whisper_helper_start_marker
    
    # Restart Hammerspoon with the cleared config if it was running
    if command -v "/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon" >/dev/null 2>&1; then
        echo "Restarting Hammerspoon with cleared configuration..."
        nohup "/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon" >/dev/null 2>&1 &
        sleep 1
    fi
    
    # Notify user
    osascript -e 'display notification "WhisperHelper stopped." with title "WhisperHelper"' 2>/dev/null || true
    
    echo "WhisperHelper stopped successfully."
    ;;
    
  *)
    echo "Unsupported operating system: $(uname -s)"
    echo "WhisperHelper currently supports Linux and macOS."
    exit 1
    ;;
esac 