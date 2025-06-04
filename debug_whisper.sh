#!/bin/bash

# Debug script for whisper.cpp server issues

echo "🔍 Whisper Server Debug Tool"
echo "=============================="

# Find whisper-server process
WHISPER_PID=$(pgrep -f "whisper-server")
if [ -z "$WHISPER_PID" ]; then
    echo "❌ Whisper server not running"
    exit 1
fi

echo "✅ Whisper server running (PID: $WHISPER_PID)"

# Get the TTY where whisper-server is running
WHISPER_TTY=$(lsof -p $WHISPER_PID | grep -E "CHR.*dev/tty" | head -1 | awk '{print $NF}')
echo "📺 Server logs on: $WHISPER_TTY"

# Check server working directory
WHISPER_CWD=$(lsof -p $WHISPER_PID | grep cwd | awk '{print $NF}')
echo "📁 Server working directory: $WHISPER_CWD"

# Show server command line
echo "🚀 Server command:"
ps -p $WHISPER_PID -o pid,ppid,args

echo ""
echo "🧪 Testing server endpoints..."

# Test health
echo "1. Health check:"
HEALTH_RESPONSE=$(curl -s --max-time 5 http://localhost:8080/health 2>&1)
HEALTH_STATUS=$?
if [ $HEALTH_STATUS -eq 0 ]; then
    echo "   ✅ Health: $HEALTH_RESPONSE"
else
    echo "   ❌ Health failed: $HEALTH_RESPONSE"
fi

# Create minimal test audio
echo ""
echo "2. Creating test audio..."
TEST_AUDIO="/tmp/debug_whisper_test.wav"
sox -n -r 16000 -c 1 "$TEST_AUDIO" trim 0 0.5 2>/dev/null
if [ -f "$TEST_AUDIO" ]; then
    echo "   ✅ Created 0.5s test audio"
else
    echo "   ❌ Failed to create test audio"
    exit 1
fi

echo ""
echo "3. Testing inference (with timeout)..."
echo "   💡 Watch the terminal where you started whisper-server for logs!"
echo "   💡 Terminal: $WHISPER_TTY"
echo ""

# Show system resources before test
echo "📊 System resources before test:"
echo "   Memory: $(vm_stat | grep "Pages free" | awk '{printf "%.1f MB free\n", $3 * 4096 / 1024 / 1024}')"
echo "   CPU load: $(uptime | awk -F'load averages:' '{print $2}')"

echo ""
echo "🚀 Sending inference request..."
START_TIME=$(date +%s)

# Send the request with detailed curl output
CURL_OUTPUT=$(curl -s -w "HTTP: %{http_code}\nTime: %{time_total}s\nSize: %{size_download} bytes\n" \
    -X POST http://localhost:8080/inference \
    -F "file=@$TEST_AUDIO" \
    -F "temperature=0.0" \
    -F "response_format=json" \
    --connect-timeout 5 \
    --max-time 15 \
    2>&1)

CURL_STATUS=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "📈 Results:"
echo "   Duration: ${DURATION}s"
echo "   Curl status: $CURL_STATUS"

if [ $CURL_STATUS -eq 0 ]; then
    echo "   ✅ Request completed successfully"
    echo "   Response details:"
    echo "$CURL_OUTPUT" | sed 's/^/     /'
else
    echo "   ❌ Request failed"
    if [ $CURL_STATUS -eq 28 ]; then
        echo "   💡 Timeout occurred - server is hanging"
        echo "   💡 Check the server terminal for error messages"
    else
        echo "   💡 Curl error code: $CURL_STATUS"
    fi
    echo "   Error output:"
    echo "$CURL_OUTPUT" | sed 's/^/     /'
fi

# Show system resources after test
echo ""
echo "📊 System resources after test:"
echo "   Memory: $(vm_stat | grep "Pages free" | awk '{printf "%.1f MB free\n", $3 * 4096 / 1024 / 1024}')"
echo "   CPU load: $(uptime | awk -F'load averages:' '{print $2}')"

# Check if server is still running
if kill -0 $WHISPER_PID 2>/dev/null; then
    echo "   ✅ Server still running"
else
    echo "   ❌ Server crashed during test!"
fi

# Cleanup
rm -f "$TEST_AUDIO"

echo ""
echo "🔧 Troubleshooting tips:"
echo "   1. Check the terminal where whisper-server is running for error messages"
echo "   2. Try restarting the server with verbose logging:"
echo "      whisper-server --host 0.0.0.0 --port 8080 --verbose"
echo "   3. Check if the model file is corrupted or missing"
echo "   4. Monitor system resources during inference"
echo "   5. Try a different model size if available" 