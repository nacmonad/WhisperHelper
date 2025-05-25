#!/bin/bash

# Test script for Hammerspoon hotkey configuration on macOS
# This script checks Hammerspoon configuration and simulates hotkey execution

# Get the absolute path to the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Configuration
LOG_FILE="/tmp/hammerspoon_test.log"
HS_CONFIG_FILE="$HOME/.hammerspoon/init.lua"

echo "=== Hammerspoon Hotkey Test ===" | tee -a "$LOG_FILE"
echo "Testing Hammerspoon configuration for WhisperHelper" | tee -a "$LOG_FILE"

# Check if Hammerspoon is installed
if ! command -v hammerspoon &> /dev/null; then
    echo "ERROR: Hammerspoon is not installed. Please install with 'brew install --cask hammerspoon'" | tee -a "$LOG_FILE"
    exit 1
fi

# Check if Hammerspoon is running
if ! pgrep -q Hammerspoon; then
    echo "WARNING: Hammerspoon is not running. Starting Hammerspoon..." | tee -a "$LOG_FILE"
    open -a Hammerspoon
    sleep 3  # Give it time to start
fi

# Check if Hammerspoon config file exists
if [ ! -f "$HS_CONFIG_FILE" ]; then
    echo "WARNING: Hammerspoon configuration file not found at $HS_CONFIG_FILE" | tee -a "$LOG_FILE"
    echo "This may be normal if WhisperHelper uses a separate configuration approach" | tee -a "$LOG_FILE"
else
    echo "Hammerspoon configuration file found at $HS_CONFIG_FILE" | tee -a "$LOG_FILE"
    
    # Check if WhisperHelper configuration is in the file
    if grep -q "WhisperHelper" "$HS_CONFIG_FILE"; then
        echo "SUCCESS: WhisperHelper configuration found in Hammerspoon config" | tee -a "$LOG_FILE"
    else
        echo "INFO: No direct WhisperHelper configuration found in main Hammerspoon config" | tee -a "$LOG_FILE"
        echo "This may be normal if WhisperHelper uses a different loading mechanism" | tee -a "$LOG_FILE"
    fi
fi

# Create a temporary test Lua script to check hotkey binding
TEMP_LUA_SCRIPT="/tmp/whisper_helper_hotkey_test.lua"

cat > "$TEMP_LUA_SCRIPT" << EOF
-- Test script to check WhisperHelper hotkey registration
print("WhisperHelper Hotkey Test")

-- Attempt to detect registered hotkeys for WhisperHelper
local registered_hotkeys = hs.hotkey.getHotkeys()
local found_whisper_hotkeys = 0

print("Checking registered hotkeys...")
for _, hotkey in ipairs(registered_hotkeys) do
    if hotkey.msg and hotkey.msg:find("WhisperHelper") then
        print("Found WhisperHelper hotkey: " .. hotkey.msg)
        found_whisper_hotkeys = found_whisper_hotkeys + 1
    else
        print("Other hotkey: " .. (hotkey.msg or "unnamed"))
    end
end

if found_whisper_hotkeys > 0 then
    print("SUCCESS: Found " .. found_whisper_hotkeys .. " WhisperHelper hotkeys")
else
    print("WARNING: No WhisperHelper hotkeys found. This could indicate a problem with registration")
    
    -- Create test hotkeys to verify system capability
    print("Testing if hotkey registration works at all...")
    local test_hotkey = hs.hotkey.new({"cmd", "option"}, "t", function()
        print("Test hotkey works!")
    end)
    
    if test_hotkey then
        print("SUCCESS: Test hotkey creation successful")
        test_hotkey:delete()
    else
        print("ERROR: Failed to create test hotkey. System may have issues with hotkey registration")
    end
end

-- Test OS version for Sequoia compatibility
local version = hs.host.operatingSystemVersion()
print("macOS version: " .. version.major .. "." .. version.minor .. "." .. version.patch)
if version.major >= 15 then
    print("NOTICE: Running on macOS Sequoia (15+)")
    print("Option/Alt only hotkeys may not work correctly on this version")
    print("Use Cmd+Option or other modifier combinations instead")
end

print("Test completed")
EOF

echo "Step 1: Running Hammerspoon diagnostic script..." | tee -a "$LOG_FILE"
HS_OUTPUT=$(osascript -e 'tell application "Hammerspoon" to execute lua code "dofile(\"/tmp/whisper_helper_hotkey_test.lua\")"')

echo "Hammerspoon diagnostic results:" | tee -a "$LOG_FILE"
echo "$HS_OUTPUT" | tee -a "$LOG_FILE"

echo "Step 2: Testing WhisperHelper scripts..." | tee -a "$LOG_FILE"

# Check WhisperHelper scripts
if [ -f "$PARENT_DIR/whisper_helper_mac.sh" ]; then
    echo "WhisperHelper main script found: $PARENT_DIR/whisper_helper_mac.sh" | tee -a "$LOG_FILE"
else
    echo "ERROR: WhisperHelper main script not found!" | tee -a "$LOG_FILE"
    exit 1
fi

if [ -f "$PARENT_DIR/start_whisper_helper_mac.sh" ]; then
    echo "WhisperHelper start script found: $PARENT_DIR/start_whisper_helper_mac.sh" | tee -a "$LOG_FILE"
else
    echo "ERROR: WhisperHelper start script not found!" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Step 3: Simulating hotkey execution (This will be logged but not actually trigger the keys)..." | tee -a "$LOG_FILE"
echo "To trigger Command+Option+r hotkey, you would run:" | tee -a "$LOG_FILE"
echo "  osascript -e 'tell application \"System Events\" to key code 15 using {command down, option down}'" | tee -a "$LOG_FILE"
echo "NOTE: This is not executed automatically to avoid unexpected behavior" | tee -a "$LOG_FILE"

echo "Test completed successfully." | tee -a "$LOG_FILE"
exit 0 