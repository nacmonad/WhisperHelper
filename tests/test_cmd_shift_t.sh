#!/bin/bash

# Specific test for Cmd+Shift+T hotkey functionality
# This test will attempt to trigger the test hotkey and verify it works

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "============================================"
echo "Testing Cmd+Shift+T Hotkey Functionality"
echo "============================================"
echo

# Check if Hammerspoon is running
echo -e "${BLUE}Checking Hammerspoon status...${NC}"
if ! pgrep -f "Hammerspoon" > /dev/null; then
    echo -e "${RED}❌ Hammerspoon is not running${NC}"
    echo "Please start Hammerspoon and try again"
    exit 1
fi
echo -e "${GREEN}✓ Hammerspoon is running${NC}"
echo

# Check configuration
echo -e "${BLUE}Checking Hammerspoon configuration...${NC}"
CONFIG_FILE="$HOME/.hammerspoon/init.lua"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file not found${NC}"
    exit 1
fi

if grep -q "testHotkey" "$CONFIG_FILE"; then
    echo -e "${GREEN}✓ testHotkey function found in configuration${NC}"
else
    echo -e "${RED}❌ testHotkey function not found${NC}"
    echo "Configuration may not be loaded properly"
    exit 1
fi
echo

# Method 1: Direct AppleScript simulation
echo -e "${BLUE}Method 1: Simulating Cmd+Shift+T keypress...${NC}"
echo "Watch for the alert: 'Hotkey test - this means hotkeys are working!'"
echo "Press Enter when ready to test..."
read -r

# Simulate the exact key combination
osascript -e '
tell application "System Events"
    -- Key code 17 is T, using command and shift modifiers
    key code 17 using {command down, shift down}
end tell
'

echo "Did you see the alert? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}✓ Manual verification: Hotkey works!${NC}"
    MANUAL_SUCCESS=true
else
    echo -e "${RED}❌ Manual verification: Hotkey not working${NC}"
    MANUAL_SUCCESS=false
fi
echo

# Method 2: Direct Hammerspoon execution via AppleScript
echo -e "${BLUE}Method 2: Calling testHotkey function directly...${NC}"
RESULT=$(osascript -e '
tell application "Hammerspoon"
    execute lua code "
        if testHotkey then 
            testHotkey() 
            return \"HOTKEY_FUNCTION_EXECUTED\"
        else 
            return \"HOTKEY_FUNCTION_NOT_FOUND\"
        end
    "
end tell
' 2>/dev/null)

if echo "$RESULT" | grep -q "HOTKEY_FUNCTION_EXECUTED"; then
    echo -e "${GREEN}✓ testHotkey function executed directly${NC}"
    DIRECT_SUCCESS=true
elif echo "$RESULT" | grep -q "HOTKEY_FUNCTION_NOT_FOUND"; then
    echo -e "${RED}❌ testHotkey function not found in Hammerspoon${NC}"
    DIRECT_SUCCESS=false
else
    echo -e "${YELLOW}⚠ Unable to execute function directly (may still work with hotkeys)${NC}"
    echo "Result: $RESULT"
    DIRECT_SUCCESS=false
fi
echo

# Method 3: Check for accessibility permissions
echo -e "${BLUE}Method 3: Checking accessibility permissions...${NC}"
echo "Please verify manually:"
echo "1. Go to System Settings/Preferences"
echo "2. Navigate to Privacy & Security > Accessibility"
echo "3. Ensure Hammerspoon is in the list and checked"
echo
echo "Is Hammerspoon enabled in Accessibility? (y/n)"
read -r accessibility_response
if [[ "$accessibility_response" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}✓ Accessibility permissions confirmed${NC}"
    ACCESSIBILITY_OK=true
else
    echo -e "${RED}❌ Accessibility permissions issue${NC}"
    echo "This is likely why your hotkeys aren't working!"
    ACCESSIBILITY_OK=false
fi
echo

# Summary and recommendations
echo "============================================"
echo "Test Results Summary"
echo "============================================"

if [ "$MANUAL_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ Manual hotkey test: PASSED${NC}"
elif [ "$MANUAL_SUCCESS" = false ]; then
    echo -e "${RED}❌ Manual hotkey test: FAILED${NC}"
else
    echo -e "${YELLOW}⚠ Manual hotkey test: NOT TESTED${NC}"
fi

if [ "$DIRECT_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ Direct function test: PASSED${NC}"
else
    echo -e "${RED}❌ Direct function test: FAILED${NC}"
fi

if [ "$ACCESSIBILITY_OK" = true ]; then
    echo -e "${GREEN}✓ Accessibility permissions: OK${NC}"
else
    echo -e "${RED}❌ Accessibility permissions: ISSUE${NC}"
fi

echo
echo "============================================"
echo "Troubleshooting Steps"
echo "============================================"

if [ "$ACCESSIBILITY_OK" != true ]; then
    echo -e "${YELLOW}1. Fix Accessibility Permissions:${NC}"
    echo "   - Open System Settings/Preferences"
    echo "   - Go to Privacy & Security > Accessibility"
    echo "   - Add Hammerspoon if not present"
    echo "   - Enable the checkbox for Hammerspoon"
    echo
fi

if [ "$MANUAL_SUCCESS" != true ]; then
    echo -e "${YELLOW}2. Restart Hammerspoon:${NC}"
    echo "   - Click Hammerspoon menu bar icon"
    echo "   - Select 'Quit Hammerspoon'"
    echo "   - Restart Hammerspoon"
    echo "   - Or run: killall Hammerspoon && open -a Hammerspoon"
    echo
    
    echo -e "${YELLOW}3. Reload Configuration:${NC}"
    echo "   - Click Hammerspoon menu bar icon"
    echo "   - Select 'Reload Config'"
    echo
    
    echo -e "${YELLOW}4. Check for Conflicts:${NC}"
    echo "   - Make sure no other apps are using Cmd+Shift+T"
    echo "   - Check if any system shortcuts conflict"
    echo
fi

if [ "$DIRECT_SUCCESS" != true ]; then
    echo -e "${YELLOW}5. Verify Configuration:${NC}"
    echo "   - Run: ./start_whisper_helper.sh"
    echo "   - Check Hammerspoon console for errors"
    echo
fi

echo -e "${BLUE}Next step: After following troubleshooting steps, press Cmd+Shift+T${NC}"
echo -e "${BLUE}You should see: 'Hotkey test - this means hotkeys are working!'${NC}" 