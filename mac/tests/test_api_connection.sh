#!/bin/bash

# Test script for API connection on macOS
# This script tests connectivity to the Whisper API server

# Configuration
WHISPER_API_URL="http://10.0.0.60:8080/inference"
LOG_FILE="/tmp/api_test.log"

echo "=== Whisper API Connection Test ===" | tee -a "$LOG_FILE"
echo "Testing connectivity to Whisper API at $WHISPER_API_URL" | tee -a "$LOG_FILE"

# Extract host and port from URL
API_HOST=$(echo "$WHISPER_API_URL" | sed -E 's#^https?://##' | sed -E 's#/.*$##' | sed -E 's#:[0-9]+$##')
API_PORT=$(echo "$WHISPER_API_URL" | grep -oE ':[0-9]+' | cut -d':' -f2)

if [ -z "$API_PORT" ]; then
    if [[ "$WHISPER_API_URL" == https://* ]]; then
        API_PORT="443"
    else
        API_PORT="80"
    fi
fi

echo "API Host: $API_HOST" | tee -a "$LOG_FILE"
echo "API Port: $API_PORT" | tee -a "$LOG_FILE"

# Test network connectivity
echo "Testing network connectivity..." | tee -a "$LOG_FILE"
if ping -c 1 -W 2 "$API_HOST" > /dev/null 2>&1; then
    echo "SUCCESS: Host $API_HOST is reachable via ping" | tee -a "$LOG_FILE"
else
    echo "WARNING: Host $API_HOST is not responding to ping" | tee -a "$LOG_FILE"
    echo "This may be normal if the server blocks ICMP packets" | tee -a "$LOG_FILE"
fi

# Test port connectivity
echo "Testing port connectivity..." | tee -a "$LOG_FILE"
if nc -z -G 5 "$API_HOST" "$API_PORT" 2>/dev/null; then
    echo "SUCCESS: Port $API_PORT on $API_HOST is open and accepting connections" | tee -a "$LOG_FILE"
else
    echo "ERROR: Cannot connect to $API_HOST on port $API_PORT" | tee -a "$LOG_FILE"
    echo "Check if the server is running and accessible from this network" | tee -a "$LOG_FILE"
    exit 1
fi

# Test API endpoint with curl
echo "Testing API endpoint with HTTP request..." | tee -a "$LOG_FILE"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$WHISPER_API_URL" 2>/dev/null)

if [ -z "$HTTP_STATUS" ]; then
    echo "ERROR: Could not connect to API endpoint" | tee -a "$LOG_FILE"
    echo "Check if the server is running and the URL is correct" | tee -a "$LOG_FILE"
    exit 1
elif [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 405 ]; then
    # 405 Method Not Allowed is actually expected for POST-only endpoints when testing with GET
    echo "SUCCESS: API endpoint is responding (HTTP $HTTP_STATUS)" | tee -a "$LOG_FILE"
    echo "The API server appears to be working correctly" | tee -a "$LOG_FILE"
    exit 0
else
    echo "WARNING: API endpoint returned unexpected status code: $HTTP_STATUS" | tee -a "$LOG_FILE"
    echo "The server is reachable but may not be functioning correctly" | tee -a "$LOG_FILE"
    exit 1
fi 