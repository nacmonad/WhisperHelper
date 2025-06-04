#!/bin/bash

echo "=== Reloading Hammerspoon Configuration ==="

# Kill and restart Hammerspoon to ensure clean reload
echo "Stopping Hammerspoon..."
pkill -f "Hammerspoon"
sleep 2

echo "Starting Hammerspoon..."
open -a Hammerspoon
sleep 3

echo "Hammerspoon should now be running with the updated configuration."
echo "Check the Hammerspoon console for debug messages."
echo ""
echo "To check console:"
echo "1. Click Hammerspoon icon in menu bar"
echo "2. Select 'Console'"
echo "3. Look for debug messages starting with 'DEBUG:'"
echo ""
echo "Try these hotkeys:"
echo "- Cmd+Shift+T (should show test alert)"
echo "- Cmd+Shift+Space (hold for push-to-talk)"
echo "- Cmd+Shift+R (5-second recording)" 