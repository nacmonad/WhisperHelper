#!/bin/bash

# Test script to verify the timing fix for quick press-and-hold recordings
echo "=== WhisperHelper Timing Fix Test ==="
echo "This script will test quick press-and-hold scenarios to verify the fix"

# Clean up any existing state
rm -f /tmp/whisper_helper_recording.wav
rm -f /tmp/whisper_helper_stop_recording
rm -f /tmp/whisper_helper.lock
rm -f /tmp/whisper_helper_recording_pid
rm -f /tmp/whisper_helper_transcript.txt
rm -f /tmp/whisper_helper_initializing

echo
echo "Test 1: Very quick press-and-hold (simulating t_ph < t_init)"
echo "Starting recording..."
bash ./whisper_helper.sh start &
START_PID=$!

# Wait only a very short time before stopping (simulating quick release)
sleep 0.3
echo "Stopping recording after 0.3 seconds (before SoX initialization complete)..."
bash ./whisper_helper.sh stop

wait $START_PID 2>/dev/null || true

echo
echo "Test 1 Results:"
if [ -f "/tmp/whisper_helper.log" ]; then
  echo "Log output (last 10 lines):"
  tail -10 /tmp/whisper_helper.log
fi

echo
echo "=== Test 2: Normal press-and-hold (simulating t_ph > t_init) ==="
echo "Starting recording..."
bash ./whisper_helper.sh start &
START_PID=$!

# Wait longer before stopping (normal usage)
sleep 2.0
echo "Stopping recording after 2.0 seconds (normal timing)..."
bash ./whisper_helper.sh stop

wait $START_PID 2>/dev/null || true

echo
echo "Test 2 Results:"
if [ -f "/tmp/whisper_helper.log" ]; then
  echo "Log output (last 15 lines):"
  tail -15 /tmp/whisper_helper.log
fi

echo
echo "=== Test Summary ==="
echo "Check the log output above for:"
echo "1. 'SoX is still initializing' messages in Test 1"
echo "2. 'minimum recording time' enforcement"
echo "3. Proper audio file creation and size"
echo "4. No 'Recording failed to start' errors"

echo
echo "If you see these behaviors, the timing fix is working correctly!" 