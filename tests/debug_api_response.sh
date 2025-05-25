#!/bin/bash

# Debug script to troubleshoot Whisper API response issues
# This script isolates the API call and provides detailed logs

# Configuration 
WHISPER_API_URL="http://10.0.0.60:8080/inference"
TEMP_AUDIO_FILE="/tmp/whisper_helper_recording.wav"
LOG_FILE="/tmp/whisper_api_debug.log"
CURL_OUTPUT="/tmp/whisper_api_response.txt"
CURL_HEADERS="/tmp/whisper_api_headers.txt"
DEBUG_TIMEOUT=15  # Longer timeout for debugging

# Initialize log file
echo "=== Whisper API Debug started at $(date) ===" > "$LOG_FILE"

# Function to log with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if audio file exists
if [ ! -f "$TEMP_AUDIO_FILE" ]; then
  log "Error: Audio file not found at $TEMP_AUDIO_FILE"
  log "Creating a test audio file using SoX..."
  
  # Generate a test audio file with SoX
  if command -v sox &> /dev/null; then
    sox -n -r 16000 -c 1 -b 16 "$TEMP_AUDIO_FILE" synth 2 sine 400
    log "Created test audio file: $TEMP_AUDIO_FILE"
  else
    log "Error: SoX not installed. Cannot create test audio."
    exit 1
  fi
fi

# Check audio file size
file_size=$(du -k "$TEMP_AUDIO_FILE" | cut -f1)
log "Audio file size: ${file_size}KB"

if [ "$file_size" -eq 0 ]; then
  log "Error: Audio file is empty."
  exit 1
fi

# Test connectivity to API server
log "Testing connection to API server..."
api_host=$(echo "$WHISPER_API_URL" | sed -E 's#^https?://##' | sed -E 's#/.*$##' | sed -E 's#:[0-9]+$##')
api_port=$(echo "$WHISPER_API_URL" | grep -oE ':[0-9]+' | cut -d':' -f2)

if [ -z "$api_port" ]; then
  api_port="80"
fi

log "API server: $api_host:$api_port"

if ! ping -c 1 -W 2 "$api_host" > /dev/null 2>&1; then
  log "Error: Cannot ping API server. Network connectivity issue."
  exit 1
fi

# Try a simple HTTP connection to the server/port
log "Testing HTTP connection to $api_host:$api_port..."
if ! timeout 5 bash -c "</dev/tcp/$api_host/$api_port" 2>/dev/null; then
  log "Error: Cannot connect to API server port. Server may be down."
  exit 1
fi

# Send request with increasing verbosity
log "Sending API request with curl..."
log "Command: curl -v -X POST \"$WHISPER_API_URL\" -H \"Content-Type: multipart/form-data\" -F \"file=@$TEMP_AUDIO_FILE\" -F \"model=whisper-1\""

# Run curl with verbose output and save headers
curl_start_time=$(date +%s)
log "Starting curl request at $(date)"

curl -v -X POST \
  "$WHISPER_API_URL" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$TEMP_AUDIO_FILE" \
  -F "model=whisper-1" \
  --connect-timeout 5 \
  --max-time $DEBUG_TIMEOUT \
  -D "$CURL_HEADERS" \
  -o "$CURL_OUTPUT" 2>> "$LOG_FILE" || curl_status=$?

curl_end_time=$(date +%s)
curl_duration=$((curl_end_time - curl_start_time))
log "Curl request completed in $curl_duration seconds with status: ${curl_status:-0}"

# Check if the request timed out
if [ "${curl_status:-0}" -eq 28 ]; then
  log "ERROR: Request timed out after $DEBUG_TIMEOUT seconds"
  log "This suggests the server is hanging or very slow to respond"
elif [ "${curl_status:-0}" -ne 0 ]; then
  log "ERROR: Curl failed with status code $curl_status"
else
  log "Curl request completed successfully"
fi

# Display response headers if available
if [ -f "$CURL_HEADERS" ]; then
  log "Response headers:"
  cat "$CURL_HEADERS" | tee -a "$LOG_FILE"
else
  log "No response headers captured"
fi

# Check the response
if [ -f "$CURL_OUTPUT" ]; then
  log "Response output file exists ($(du -h "$CURL_OUTPUT" | cut -f1))"
  
  # Check if response is empty
  if [ ! -s "$CURL_OUTPUT" ]; then
    log "ERROR: Response file is empty (0 bytes)"
  else
    log "Response content:"
    cat "$CURL_OUTPUT" | tee -a "$LOG_FILE"
    
    # Check if response is valid JSON
    if ! grep -q '^{.*}$' "$CURL_OUTPUT"; then
      log "WARNING: Response is not valid JSON"
    else
      # Extract the text from the JSON
      transcription=$(grep -o '"text":"[^"]*"' "$CURL_OUTPUT" | cut -d'"' -f4)
      
      if [ -z "$transcription" ] && grep -q '"text":""' "$CURL_OUTPUT"; then
        log "Empty transcription received from API (valid but empty)"
      elif [ -n "$transcription" ]; then
        log "Successfully extracted transcription: $transcription"
      else
        log "Failed to extract transcription from response"
      fi
    fi
  fi
else
  log "ERROR: No response output file created"
fi

log "Debug completed. Check $LOG_FILE for full details."
echo "Debug log saved to $LOG_FILE" 