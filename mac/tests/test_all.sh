#!/bin/bash

# Master test script for WhisperHelper on macOS
# This script runs all component tests and reports results

# Get the absolute path to the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Configuration
LOG_FILE="/tmp/whisper_helper_tests.log"
FAILED_TESTS=0
PASSED_TESTS=0
TOTAL_TESTS=0

# Function to run a test and track results
run_test() {
    local test_script="$1"
    local test_name="$2"
    
    echo
    echo "======================================================"
    echo "Running test: $test_name"
    echo "======================================================"
    echo
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ -f "$test_script" ]; then
        # Make sure test script is executable
        chmod +x "$test_script"
        
        # Run the test
        "$test_script"
        local result=$?
        
        if [ $result -eq 0 ]; then
            echo
            echo "✅ Test PASSED: $test_name"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo
            echo "❌ Test FAILED: $test_name (Exit code: $result)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        echo "❌ Test script not found: $test_script"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    echo
    echo "------------------------------------------------------"
    echo
}

# Initialize log file
echo "=== WhisperHelper Test Suite Started at $(date) ===" > "$LOG_FILE"
echo "Running all component tests for WhisperHelper on macOS" | tee -a "$LOG_FILE"

# Make all test scripts executable
chmod +x "$SCRIPT_DIR"/*.sh

# Run individual tests
run_test "$SCRIPT_DIR/test_sox_recording.sh" "SoX Recording"
run_test "$SCRIPT_DIR/test_api_connection.sh" "API Connection"
run_test "$SCRIPT_DIR/test_transcription.sh" "Transcription"
run_test "$SCRIPT_DIR/test_hammerspoon_hotkeys.sh" "Hammerspoon Hotkeys"

# Print test summary
echo
echo "======================================================"
echo "Test Summary"
echo "======================================================"
echo "Total tests:  $TOTAL_TESTS"
echo "Passed tests: $PASSED_TESTS"
echo "Failed tests: $FAILED_TESTS"
echo

if [ $FAILED_TESTS -eq 0 ]; then
    echo "✅ All tests PASSED!"
    echo "All WhisperHelper components are working correctly."
else
    echo "❌ Some tests FAILED!"
    echo "Check individual test logs for details:"
    echo "- SoX Recording: /tmp/sox_test.log"
    echo "- API Connection: /tmp/api_test.log"
    echo "- Transcription: /tmp/transcription_test.log"
    echo "- Hammerspoon Hotkeys: /tmp/hammerspoon_test.log"
    echo
    echo "Summary log: $LOG_FILE"
fi

echo
echo "======================================================"
echo "Test Run Complete at $(date)"
echo "======================================================"

# Log final results
echo "Test Summary: $PASSED_TESTS passed, $FAILED_TESTS failed, $TOTAL_TESTS total" >> "$LOG_FILE"
echo "=== WhisperHelper Test Suite Completed at $(date) ===" >> "$LOG_FILE"

# Return appropriate exit code
if [ $FAILED_TESTS -eq 0 ]; then
    exit 0
else
    exit 1
fi 