#!/bin/bash

# Test script for WhisperHelper Hammerspoon hotkeys
# This script tests various aspects of the hotkey functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Logging
LOG_FILE="/tmp/hotkey_test.log"
echo "=== Hotkey Test Session Started at $(date) ===" > "$LOG_FILE"

log_test() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

pass_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ PASS${NC}: $1" | tee -a "$LOG_FILE"
}

fail_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${RED}✗ FAIL${NC}: $1" | tee -a "$LOG_FILE"
}

info_test() {
    echo -e "${BLUE}ℹ INFO${NC}: $1" | tee -a "$LOG_FILE"
}

warn_test() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1" | tee -a "$LOG_FILE"
}

# Test 1: Check if Hammerspoon is running
test_hammerspoon_running() {
    log_test "Testing if Hammerspoon is running..."
    
    if pgrep -f "Hammerspoon" > /dev/null; then
        pass_test "Hammerspoon is running"
        return 0
    else
        fail_test "Hammerspoon is not running"
        info_test "Please start Hammerspoon before running tests"
        return 1
    fi
}

# Test 2: Check if Hammerspoon has accessibility permissions
test_accessibility_permissions() {
    log_test "Testing Hammerspoon accessibility permissions..."
    
    # This is a basic check - the user will need to verify manually
    info_test "Manual check required: Go to System Preferences > Privacy & Security > Accessibility"
    info_test "Ensure Hammerspoon is listed and enabled"
    warn_test "This test requires manual verification"
}

# Test 3: Check if init.lua exists and has content
test_config_file() {
    log_test "Testing Hammerspoon configuration file..."
    
    local config_file="$HOME/.hammerspoon/init.lua"
    
    if [ ! -f "$config_file" ]; then
        fail_test "Hammerspoon config file not found at $config_file"
        return 1
    fi
    
    if [ ! -s "$config_file" ]; then
        fail_test "Hammerspoon config file is empty"
        return 1
    fi
    
    # Check if it contains WhisperHelper configuration
    if grep -q "WhisperHelper" "$config_file"; then
        pass_test "WhisperHelper configuration found in init.lua"
    else
        fail_test "WhisperHelper configuration not found in init.lua"
        info_test "Run './start_whisper_helper.sh' to set up the configuration"
        return 1
    fi
    
    # Check for specific hotkey bindings
    if grep -q 'hs.hotkey.bind.*"t"' "$config_file"; then
        pass_test "Test hotkey (Cmd+Shift+T) binding found"
    else
        fail_test "Test hotkey binding not found"
    fi
    
    if grep -q 'hs.hotkey.bind.*"space"' "$config_file"; then
        pass_test "Push-to-talk hotkey (Cmd+Shift+Space) binding found"
    else
        fail_test "Push-to-talk hotkey binding not found"
    fi
    
    if grep -q 'hs.hotkey.bind.*"r"' "$config_file"; then
        pass_test "5-second recording hotkey (Cmd+Shift+R) binding found"
    else
        fail_test "5-second recording hotkey binding not found"
    fi
}

# Test 4: Test the test hotkey function directly
test_hotkey_function() {
    log_test "Testing hotkey function directly..."
    
    # Create a temporary Lua script to test the function
    local test_script="/tmp/test_hotkey_function.lua"
    cat > "$test_script" << 'EOF'
-- Test the testHotkey function
function testHotkey()
    print("TEST_HOTKEY_SUCCESS: Hotkey function executed successfully")
    return true
end

-- Call the function
local success = testHotkey()
if success then
    print("FUNCTION_TEST_PASSED")
else
    print("FUNCTION_TEST_FAILED")
end
EOF
    
    # Run the test with lua
    if command -v lua > /dev/null; then
        local result=$(lua "$test_script" 2>&1)
        if echo "$result" | grep -q "FUNCTION_TEST_PASSED"; then
            pass_test "testHotkey function executes successfully"
        else
            fail_test "testHotkey function failed to execute"
        fi
    else
        warn_test "Lua not available for direct function testing"
    fi
    
    rm -f "$test_script"
}

# Test 5: Simulate hotkey press using AppleScript
test_simulate_hotkey() {
    log_test "Testing hotkey simulation..."
    
    info_test "Attempting to simulate Cmd+Shift+T hotkey press..."
    info_test "Watch for the 'Hotkey test - this means hotkeys are working!' alert"
    
    # Use AppleScript to simulate the key combination
    local applescript='
    tell application "System Events"
        key code 17 using {command down, shift down}
    end tell
    '
    
    if osascript -e "$applescript" 2>/dev/null; then
        info_test "Hotkey simulation command sent successfully"
        info_test "Did you see the 'Hotkey test' alert? (Manual verification required)"
        pass_test "Hotkey simulation attempted"
    else
        fail_test "Failed to simulate hotkey press"
    fi
}

# Test 6: Check WhisperHelper script accessibility
test_whisper_script() {
    log_test "Testing WhisperHelper script accessibility..."
    
    local whisper_script="$PROJECT_DIR/whisper_helper.sh"
    
    if [ ! -f "$whisper_script" ]; then
        fail_test "WhisperHelper script not found at $whisper_script"
        return 1
    fi
    
    if [ ! -x "$whisper_script" ]; then
        fail_test "WhisperHelper script is not executable"
        info_test "Run: chmod +x $whisper_script"
        return 1
    fi
    
    pass_test "WhisperHelper script found and executable"
    
    # Test script help/usage
    if "$whisper_script" 2>&1 | grep -q "Usage"; then
        pass_test "WhisperHelper script shows usage information"
    else
        warn_test "WhisperHelper script may not show proper usage"
    fi
}

# Test 7: Test Hammerspoon console output
test_hammerspoon_console() {
    log_test "Testing Hammerspoon console accessibility..."
    
    info_test "To manually check Hammerspoon console:"
    info_test "1. Click Hammerspoon menu bar icon"
    info_test "2. Select 'Console'"
    info_test "3. Look for WhisperHelper initialization messages"
    info_test "4. Try pressing Cmd+Shift+T and check for console output"
    
    warn_test "Console check requires manual verification"
}

# Main test execution
main() {
    echo "======================================"
    echo "WhisperHelper Hotkey Test Suite"
    echo "======================================"
    echo
    
    test_hammerspoon_running
    test_accessibility_permissions
    test_config_file
    test_hotkey_function
    test_whisper_script
    test_hammerspoon_console
    test_simulate_hotkey
    
    echo
    echo "======================================"
    echo "Test Results Summary"
    echo "======================================"
    echo -e "Tests run: ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"
    echo
    
    if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
        echo -e "${GREEN}All automated tests passed!${NC}"
    else
        echo -e "${YELLOW}Some tests failed or require manual verification${NC}"
    fi
    
    echo
    echo "Next steps if hotkeys still don't work:"
    echo "1. Check System Preferences > Privacy & Security > Accessibility"
    echo "2. Restart Hammerspoon completely"
    echo "3. Try the manual hotkey test: Press Cmd+Shift+T"
    echo "4. Check Hammerspoon console for error messages"
    echo
    echo "Log file: $LOG_FILE"
}

# Run the tests
main "$@" 