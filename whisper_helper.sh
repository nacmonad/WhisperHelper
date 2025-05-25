#!/bin/bash

# WhisperHelper - A Linux utility for system-wide speech-to-text
# Uses SoX for recording and connects to a remote Whisper API server

# Configuration variables (can be moved to a separate config file later)
WHISPER_API_URL="http://10.0.0.60:8080/inference"
WHISPER_API_TIMEOUT=10  # Reduced timeout from 30 to 10 seconds
TEMP_AUDIO_FILE="/tmp/whisper_helper_recording.wav"
TEMP_TRANSCRIPT_FILE="/tmp/whisper_helper_transcript.txt"
STOP_RECORDING_FLAG="/tmp/whisper_helper_stop_recording"
LOCK_FILE="/tmp/whisper_helper.lock"
LOG_FILE="/tmp/whisper_helper.log"
RECORDING_PID_FILE="/tmp/whisper_helper_recording_pid"

# Enable debug logging
DEBUG_MODE=true
# Debug logging function
log_debug() {
  if [ "$DEBUG_MODE" = true ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
  fi
}

# Check if required tools are installed
check_dependencies() {
  local missing_deps=()
  
  if ! command -v sox &> /dev/null; then
    missing_deps+=("sox")
  fi
  
  if ! command -v curl &> /dev/null; then
    missing_deps+=("curl")
  fi
  
  if ! command -v xdotool &> /dev/null; then
    missing_deps+=("xdotool")
  fi
  
  if ! command -v xclip &> /dev/null; then
    missing_deps+=("xclip")
  fi
  
  if [ ${#missing_deps[@]} -ne 0 ]; then
    log_debug "Error: Missing dependencies: ${missing_deps[*]}"
    echo "Error: Missing dependencies: ${missing_deps[*]}"
    echo "Please install them with: sudo apt-get install ${missing_deps[*]}"
    exit 1
  fi
}

# Function to check if a recording is in progress
is_recording_active() {
  if [ -f "$LOCK_FILE" ]; then
    local pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
      return 0  # Recording is active
    fi
  fi
  return 1  # No active recording
}

# Function to handle start recording (key press)
start_recording() {
  log_debug "Starting recording process"
  
  # Check if recording is already in progress
  if is_recording_active; then
    local pid=$(cat "$LOCK_FILE" 2>/dev/null)
    log_debug "Recording already in progress. PID: $pid"
    echo "Recording already in progress."
    notify-send "WhisperHelper" "Recording already in progress." -t 1000
    return 1
  fi
  
  # Remove any existing stop flag
  rm -f "$STOP_RECORDING_FLAG"
  log_debug "Removed stop flag if it existed"
  
  # Remove any existing temporary audio file
  if [ -f "$TEMP_AUDIO_FILE" ]; then
    log_debug "Removing existing audio file: $TEMP_AUDIO_FILE"
    rm -f "$TEMP_AUDIO_FILE"
  fi
  
  # Create lock file with current process ID FIRST
  echo $$ > "$LOCK_FILE"
  log_debug "Created lock file with PID: $$"
  
  # Visual indicator that recording has started
  notify-send "WhisperHelper" "Recording started..." -t 1000
  log_debug "Notification sent: Recording started"
  
  # Start recording in background
  log_debug "Launching record_audio function in background"
  record_audio &
  
  # Store the background process ID
  RECORDING_PID=$!
  echo "$RECORDING_PID" > "$RECORDING_PID_FILE"  # Store recording PID separately
  log_debug "Recording process launched with PID: $RECORDING_PID"
  
  # Wait a moment to ensure recording starts
  sleep 0.5
  
  # Verify recording started properly
  if ! kill -0 "$RECORDING_PID" 2>/dev/null; then
    log_debug "ERROR: Recording process failed to start or exited immediately"
    notify-send "WhisperHelper" "Recording failed to start" -t 2000
    rm -f "$LOCK_FILE"
    rm -f "$RECORDING_PID_FILE"
    return 1
  fi
  
  log_debug "Recording started successfully"
  
  # Don't exit the function, as that would trigger cleanup
  # Instead, detach and let the background process continue
  log_debug "Exiting start_recording function without triggering cleanup"
  exit 0
}

# Function to handle stop recording (key release)
stop_recording() {
  log_debug "Stop recording requested"
  
  # Check if recording is in progress
  if [ ! -f "$LOCK_FILE" ] && [ ! -f "$RECORDING_PID_FILE" ]; then
    log_debug "No recording in progress (no lock file or PID file found)"
    echo "No recording in progress." >&2
    return 1
  fi
  
  # Create stop flag file to signal recording process to stop
  touch "$STOP_RECORDING_FLAG"
  log_debug "Created stop flag file: $STOP_RECORDING_FLAG"
  
  # Get recording PID
  local recording_pid=""
  if [ -f "$RECORDING_PID_FILE" ]; then
    recording_pid=$(cat "$RECORDING_PID_FILE" 2>/dev/null)
    log_debug "Found recording PID: $recording_pid in PID file"
  else
    if [ -f "$LOCK_FILE" ]; then
      recording_pid=$(tail -n 1 "$LOCK_FILE" 2>/dev/null || echo "")
      log_debug "Using PID from lock file: $recording_pid"
    else
      log_debug "Neither PID file nor lock file found"
    fi
  fi
  
  # Wait a moment for recording to complete
  log_debug "Waiting for recording to complete..."
  sleep 1
  
  # Check if recording process is still running
  if [ -n "$recording_pid" ] && kill -0 "$recording_pid" 2>/dev/null; then
    log_debug "Recording process (PID: $recording_pid) still running, attempting to kill"
    kill "$recording_pid" 2>/dev/null || true
    log_debug "Waiting for recording process to exit..."
    wait "$recording_pid" 2>/dev/null || true
  fi
  
  # Check if recording was made
  if [ -f "$TEMP_AUDIO_FILE" ]; then
    if [ -s "$TEMP_AUDIO_FILE" ]; then
      log_debug "Audio file exists and has size: $(du -h "$TEMP_AUDIO_FILE" | cut -f1)"
      notify-send "WhisperHelper" "Transcribing audio..." -t 1500
      
      # Process the recording - this will save transcription to the transcript file
      log_debug "Getting transcription..."
      local start_time=$(date +%s)
      get_transcription >/dev/null
      local transcription_status=$?
      local end_time=$(date +%s)
      local duration=$((end_time - start_time))
      log_debug "Transcription request took $duration seconds with status: $transcription_status"
      
      # Check if transcription was successful by looking for transcript file
      if [ $transcription_status -eq 0 ] && [ -f "$TEMP_TRANSCRIPT_FILE" ]; then
        # Check if transcription is empty
        if [ ! -s "$TEMP_TRANSCRIPT_FILE" ]; then
          log_debug "Transcription file exists but is empty (no speech detected)"
          notify-send "WhisperHelper" "No speech detected" -t 1500
        else
          log_debug "Transcription saved to file, inserting text"
          # No need to pass the transcription - insert_text will read from file
          insert_text
          notify-send "WhisperHelper" "Transcription inserted" -t 1500
        fi
      else
        # If transcription failed, check specific errors
        if [ $duration -ge $WHISPER_API_TIMEOUT ]; then
          log_debug "Transcription request timed out after $duration seconds"
          notify-send "WhisperHelper" "Transcription timed out - server may be overloaded" -t 2500
        else
          log_debug "Transcription failed or returned empty"
          notify-send "WhisperHelper" "Transcription failed - check logs" -t 1500
        fi
      fi
    else
      log_debug "Audio file exists but is empty"
      echo "Recording file exists but is empty." >&2
      notify-send "WhisperHelper" "No audio recorded (empty file)" -t 1500
    fi
  else
    log_debug "No audio file found at: $TEMP_AUDIO_FILE"
    echo "No recording found to process or file is empty." >&2
    notify-send "WhisperHelper" "No audio recorded (missing file)" -t 1500
  fi
  
  # Clean up
  log_debug "Cleaning up temporary files"
  rm -f "$TEMP_AUDIO_FILE"
  rm -f "$TEMP_TRANSCRIPT_FILE"
  rm -f "$STOP_RECORDING_FLAG"
  rm -f "$LOCK_FILE"
  rm -f "$RECORDING_PID_FILE"
  log_debug "Stop recording process completed"
  return 0
}

# Record audio using SoX until stop flag is detected
record_audio() {
  log_debug "Starting audio recording with SoX"
  echo "Recording audio..." >&2
  
  # Use SoX to record audio
  # -d: Use default audio device
  # -r 16000: Sample rate 16kHz (good for speech recognition)
  # -c 1: Mono channel
  # -b 16: 16-bit depth
  log_debug "Launching sox command to record"
  # Create an empty file first to ensure it exists
  touch "$TEMP_AUDIO_FILE"
  sox -d -r 16000 -c 1 -b 16 "$TEMP_AUDIO_FILE" 2>> "$LOG_FILE" &
  local SOX_PID=$!
  log_debug "SoX recording process started with PID: $SOX_PID"
  
  # Check periodically if stop flag exists
  while true; do
    if [ -f "$STOP_RECORDING_FLAG" ]; then
      log_debug "Stop flag detected, stopping recording"
      # Kill the sox process
      kill $SOX_PID 2>/dev/null || true
      wait $SOX_PID 2>/dev/null || true
      log_debug "SoX process terminated"
      break
    fi
    
    # Check if sox is still running
    if ! kill -0 $SOX_PID 2>/dev/null; then
      log_debug "SoX process exited on its own"
      echo "Recording completed automatically." >&2
      break
    fi
    
    sleep 0.1
  done
  
  # Verify recording file
  if [ -f "$TEMP_AUDIO_FILE" ]; then
    log_debug "Recording saved to $TEMP_AUDIO_FILE (size: $(du -h "$TEMP_AUDIO_FILE" | cut -f1))"
    echo "Recording saved to $TEMP_AUDIO_FILE" >&2
  else
    log_debug "ERROR: Recording file not created!"
  fi
}

# Send audio to Whisper API and get transcription
get_transcription() {
  log_debug "Sending audio to Whisper API at $WHISPER_API_URL"
  echo "Sending audio to Whisper API..." >&2
  
  if [ ! -f "$TEMP_AUDIO_FILE" ]; then
    log_debug "Error: Audio file not found."
    echo "Error: Audio file not found." >&2
    return 1
  fi
  
  # Check audio file size
  local file_size=$(du -k "$TEMP_AUDIO_FILE" | cut -f1)
  log_debug "Audio file size: ${file_size}KB"
  echo "Audio file size: ${file_size}KB" >&2
  
  if [ "$file_size" -eq 0 ]; then
    log_debug "Error: Audio file is empty."
    echo "Error: Audio file is empty." >&2
    return 1
  fi
  
  # Clear any existing transcript file
  rm -f "$TEMP_TRANSCRIPT_FILE"
  
  # Test connectivity to API server first
  echo "Testing connection to API server..." >&2
  local api_host=$(echo "$WHISPER_API_URL" | sed -E 's#^https?://##' | sed -E 's#/.*$##' | sed -E 's#:[0-9]+$##')
  log_debug "API host: $api_host"
  
  if ! ping -c 1 -W 2 "$api_host" > /dev/null 2>&1; then
    log_debug "Error: Cannot reach API server. Network connectivity issue."
    echo "Error: Cannot reach API server. Network connectivity issue." >&2
    return 1
  fi
  
  # Try a simple HTTP connection test before sending the file
  local api_port=$(echo "$WHISPER_API_URL" | grep -oE ':[0-9]+' | cut -d':' -f2)
  if [ -z "$api_port" ]; then
    api_port="80"
  fi
  
  log_debug "Testing HTTP connection to $api_host:$api_port"
  if ! timeout 3 bash -c "</dev/tcp/$api_host/$api_port" 2>/dev/null; then
    log_debug "Error: Cannot connect to API server port. Server may be down."
    echo "Error: Cannot connect to API server port. Server may be down." >&2
    return 1
  fi
  
  # Send the file to the Whisper API using curl with better error handling
  log_debug "Sending curl request to API"
  echo "Sending request with curl, this may take a moment..." >&2
  
  # Temporary file for curl output
  local curl_output="/tmp/whisper_helper_curl_output.txt"
  local curl_headers="/tmp/whisper_helper_curl_headers.txt"
  local curl_status=0
  
  # Record start time
  local start_time=$(date +%s)
  log_debug "Starting curl request at $(date)"
  
  # Use curl with timeout and verbose output
  curl -s -X POST \
    "$WHISPER_API_URL" \
    -H "Content-Type: multipart/form-data" \
    -F "file=@$TEMP_AUDIO_FILE" \
    -F "model=whisper-1" \
    --connect-timeout 5 \
    --max-time $WHISPER_API_TIMEOUT \
    -D "$curl_headers" \
    -o "$curl_output" 2>> "$LOG_FILE" || curl_status=$?
  
  # Record end time and calculate duration
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_debug "Curl request completed in $duration seconds with status: $curl_status"
  
  if [ $curl_status -ne 0 ]; then
    log_debug "Curl failed with status: $curl_status"
    echo "API request failed. Curl error code: $curl_status" >&2
    
    # Map curl error codes to human-readable messages
    case $curl_status in
      6) echo "Error: Could not resolve host. Check your network connection or API URL." >&2 ;;
      7) echo "Error: Failed to connect to host. Server may be down or wrong port." >&2 ;;
      28) 
        echo "Error: Connection timed out after $WHISPER_API_TIMEOUT seconds. Server may be overloaded or unreachable." >&2
        log_debug "Timeout after $WHISPER_API_TIMEOUT seconds. Server might be hanging."
        ;;
      *) echo "Error: Curl failed with code $curl_status. Check log for details." >&2 ;;
    esac
    
    return 1
  fi
  
  # Get the response from the output file
  local response=""
  if [ -f "$curl_output" ]; then
    if [ ! -s "$curl_output" ]; then
      log_debug "Curl output file exists but is empty"
      echo "Error: Received empty response from API" >&2
      return 1
    fi
    response=$(cat "$curl_output")
    log_debug "API response: $response"
  else
    log_debug "Curl output file not created"
    echo "Error: No response received from API" >&2
    return 1
  fi
  
  # Check if response is valid JSON
  if ! echo "$response" | grep -q '^{.*}$'; then
    log_debug "Response is not valid JSON: $response"
    echo "Error: Received invalid JSON response from API" >&2
    return 1
  fi
  
  # Extract the text from the JSON response
  # This assumes the response is in the format: {"text": "transcription"}
  local transcription=$(echo "$response" | grep -o '"text":"[^"]*"' | cut -d'"' -f4)
  
  # Handle empty transcription properly
  if [ -z "$transcription" ] && echo "$response" | grep -q '"text":""'; then
    log_debug "Empty transcription received from API"
    echo "Warning: Server returned empty transcription - no speech detected" >&2
    echo "" > "$TEMP_TRANSCRIPT_FILE"
    echo "Empty transcription saved to file" >&2
    return 0  # Return success since this is a valid but empty response
  elif [ -n "$transcription" ]; then
    # Trim trailing newlines from the transcription
    transcription=$(echo "$transcription" | sed 's/\\n$//g' | tr -d '\n')
    log_debug "Transcription after trimming: $transcription"
    
    # Write only the transcription to the transcript file
    echo "$transcription" > "$TEMP_TRANSCRIPT_FILE"
    echo "Successfully received transcription" >&2
    return 0
  else
    log_debug "Failed to extract transcription from response"
    echo "Error: Could not extract transcription from API response" >&2
    echo "Raw response: $response" >&2
    return 1
  fi
  
  # Clean up curl output file
  rm -f "$curl_output"
  rm -f "$curl_headers"
  
  # Only log the transcription, don't echo it with debug info
  log_debug "Final transcription saved to $TEMP_TRANSCRIPT_FILE"
  
  # Return just the clean transcription without debug info
  cat "$TEMP_TRANSCRIPT_FILE"
}

# Type the text into the currently focused window or copy to clipboard
insert_text() {
  local text="$1"
  
  if [ -z "$text" ] && [ ! -f "$TEMP_TRANSCRIPT_FILE" ]; then
    log_debug "No text to insert and no transcript file found"
    echo "No text to insert" >&2
    return 1
  fi
  
  # If no text was provided but transcript file exists, use that
  if [ -z "$text" ] && [ -f "$TEMP_TRANSCRIPT_FILE" ]; then
    text=$(cat "$TEMP_TRANSCRIPT_FILE")
    log_debug "Using text from transcript file: $text"
  fi
  
  log_debug "Attempting to insert text with xdotool"
  # Try to type the text using xdotool
  if xdotool type --clearmodifiers "$text" 2>> "$LOG_FILE"; then
    log_debug "Text successfully inserted into the active window"
    echo "Text inserted into the active window" >&2
  else
    log_debug "xdotool failed, falling back to clipboard"
    # If typing fails, copy to clipboard
    echo "$text" | xclip -selection clipboard
    log_debug "Text copied to clipboard"
    echo "Text copied to clipboard" >&2
  fi
}

# Cleanup function to ensure we don't leave lock files or temporary files
cleanup() {
  log_debug "Cleanup called"
  # Only clean up if we're not in the start command
  if [ "$1" != "start" ]; then
    rm -f "$TEMP_AUDIO_FILE"
    rm -f "$TEMP_TRANSCRIPT_FILE"
    rm -f "$STOP_RECORDING_FLAG"
    rm -f "$LOCK_FILE"
    rm -f "$RECORDING_PID_FILE"
    log_debug "Cleanup completed, exiting"
  else
    log_debug "Cleanup skipped for start command"
  fi
  exit 0
}

# Initialize log file
if [ "$DEBUG_MODE" = true ]; then
  echo "=== WhisperHelper started at $(date) ===" > "$LOG_FILE"
fi

# Handle command-line arguments
if [ "$1" = "start" ]; then
  log_debug "Command: start"
  # Set trap to clean up on exit, but pass the command to avoid cleanup for start
  trap 'cleanup "start"' EXIT INT TERM
  start_recording
elif [ "$1" = "stop" ]; then
  log_debug "Command: stop"
  # Set trap to clean up on exit
  trap cleanup EXIT INT TERM
  stop_recording
else
  # For backward compatibility or manual testing
  echo "Usage: $0 [start|stop]"
  echo "This script is designed to be called by xbindkeys for press/release events or timed recordings."
  check_dependencies
  exit 1
fi 