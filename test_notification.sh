#!/bin/bash
# Quick test script for macOS notifications

# Test 1: Basic notification
echo "Testing basic macOS notification..."
osascript -e 'display notification "This is a test notification" with title "Test"'

# Test 2: Check if notifications are allowed
echo "Testing notification permissions..."
osascript -e 'tell application "System Events" to display notification "Permission test" with title "WhisperHelper"'

echo "Did you see any notifications? If not, check System Preferences > Notifications > Terminal" 