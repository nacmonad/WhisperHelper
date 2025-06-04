#!/bin/bash

# WhisperHelper - A cross-platform utility for system-wide speech-to-text
# Uses SoX for recording and connects to a remote Whisper API server
# Compatible with Linux and macOS

# Detect operating system
detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*)  echo "linux" ;;
    *)       echo "unknown" ;;
  esac
}

OS_TYPE=$(detect_os)

# Configuration variables (can be moved to a separate config file later)
WHISPER_API_URL="http://0.0.0.0:8080/inference"
WHISPER_API_TIMEOUT=10 
WHISPER_HEALTH_URL="http://0.0.0.0:8080/health"
TEMP_AUDIO_FILE="/tmp/whisper_helper_recording.wav"
TEMP_TRANSCRIPT_FILE="/tmp/whisper_helper_transcript.txt"
STOP_RECORDING_FLAG="/tmp/whisper_helper_stop_recording"
LOCK_FILE="/tmp/whisper_helper.lock"
LOG_FILE="/tmp/whisper_helper.log"
RECORDING_PID_FILE="/tmp/whisper_helper_recording_pid"
CONTINUOUS_AUDIO_FILE="/tmp/whisper_helper_continuous.wav"
SOX_DAEMON_PID_FILE="/tmp/whisper_helper_daemon_pid"
RECORDING_START_MARKER="/tmp/whisper_helper_start_marker"

# Enable debug logging
DEBUG_MODE=true
# Debug logging function
log_debug() {
  if [ "$DEBUG_MODE" = true ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
  fi
}

# Platform-specific notification function
show_notification() {
  local title="$1"
  local message="$2"
  local duration="${3:-1000}"
  
  log_debug "Attempting to show notification: [$title] $message"
  
  case "$OS_TYPE" in
    "macos")
      # Add auto-close text and use Dismiss button, auto-close after 1 second
      local enhanced_message="$message (will close automatically in 1 second)"
      if osascript -e "display alert \"$title\" message \"$enhanced_message\" buttons {\"Dismiss\"} default button \"Dismiss\" giving up after 1" 2>> "$LOG_FILE"; then
        log_debug "macOS alert dialog sent successfully"
      else
        log_debug "macOS alert dialog failed, trying notification"
        # Fallback to notification if alert fails
        osascript -e "display notification \"$enhanced_message\" with title \"$title\"" 2>> "$LOG_FILE" || log_debug "Notification also failed"
      fi
      ;;
    "linux")
      # For Linux, add the auto-close text and use shorter duration (1 second = 1000ms)
      local enhanced_message="$message (will close automatically in 1 second)"
      if notify-send "$title" "$enhanced_message" -t 1000 2>> "$LOG_FILE"; then
        log_debug "Linux notification sent successfully"
      else
        log_debug "Linux notification failed"
      fi
      ;;
    *)
      echo "[$title] $message"
      log_debug "Generic notification: [$title] $message"
      ;;
  esac
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
  
  # Platform-specific dependencies
  case "$OS_TYPE" in
    "linux")
      if ! command -v xdotool &> /dev/null; then
        missing_deps+=("xdotool")
      fi
      
      if ! command -v xclip &> /dev/null; then
        missing_deps+=("xclip")
      fi
      ;;
    "macos")
      if ! command -v pbcopy &> /dev/null; then
        missing_deps+=("pbcopy")
      fi
      ;;
  esac
  
  if [ ${#missing_deps[@]} -ne 0 ]; then
    log_debug "Error: Missing dependencies: ${missing_deps[*]}"
    echo "Error: Missing dependencies: ${missing_deps[*]}"
    case "$OS_TYPE" in
      "linux")
        echo "Please install them with: sudo apt-get install ${missing_deps[*]}"
        ;;
      "macos")
        echo "Please install them with: brew install ${missing_deps[*]}"
        ;;
    esac
    exit 1
  fi
}

# Function to check if Whisper API server is healthy and ready
check_whisper_health() {
  log_debug "Checking Whisper API health at $WHISPER_HEALTH_URL"
  
  # Test basic connectivity first
  local api_host=$(echo "$WHISPER_HEALTH_URL" | sed -E 's#^https?://##' | sed -E 's#/.*$##' | sed -E 's#:[0-9]+$##')
  local test_host="$api_host"
  if [ "$api_host" = "0.0.0.0" ]; then
    test_host="localhost"
  fi
  
  local api_port=$(echo "$WHISPER_HEALTH_URL" | grep -oE ':[0-9]+' | cut -d':' -f2)
  if [ -z "$api_port" ]; then
    api_port="8080"
  fi
  
  # Quick connectivity test
  if ! curl -s --connect-timeout 3 --max-time 5 "http://$test_host:$api_port/" -o /dev/null 2>/dev/null; then
    log_debug "Error: Cannot connect to Whisper API server at $test_host:$api_port"
    return 1
  fi
  
  # Check health endpoint
  local health_response
  local health_status=0
  
  health_response=$(curl -s --connect-timeout 3 --max-time 10 "$WHISPER_HEALTH_URL" 2>/dev/null) || health_status=$?
  
  if [ $health_status -ne 0 ]; then
    log_debug "Health check failed with curl status: $health_status"
    return 1
  fi
  
  log_debug "Health check response: $health_response"
  
  # Check if response indicates healthy status
  if echo "$health_response" | grep -qi "healthy\|ok\|ready"; then
    log_debug "Whisper API server is healthy and ready"
    return 0
  else
    log_debug "Whisper API server health check returned unexpected response"
    return 1
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
    show_notification "WhisperHelper" "Recording already in progress."
    return 1
  fi
  
  # Check if SoX daemon is running
  if [ ! -f "$SOX_DAEMON_PID_FILE" ]; then
    log_debug "ERROR: SoX daemon not running. Please restart WhisperHelper."
    show_notification "WhisperHelper" "Audio daemon not running. Please restart WhisperHelper."
    return 1
  fi
  
  local daemon_pid=$(cat "$SOX_DAEMON_PID_FILE" 2>/dev/null)
  if [ -z "$daemon_pid" ] || ! kill -0 "$daemon_pid" 2>/dev/null; then
    log_debug "ERROR: SoX daemon process not found. Please restart WhisperHelper."
    show_notification "WhisperHelper" "Audio daemon stopped. Please restart WhisperHelper."
    return 1
  fi
  
  # Remove any existing stop flag and temp files
  rm -f "$STOP_RECORDING_FLAG"
  rm -f "$TEMP_AUDIO_FILE"
  log_debug "Removed stop flag and temp files"
  
  # Create lock file with current process ID
  echo $$ > "$LOCK_FILE"
  log_debug "Created lock file with PID: $$"
  
  # Record the start time (in seconds since epoch with high precision)
  local start_time=$(date +%s.%N)
  echo "$start_time" > "$RECORDING_START_MARKER"
  log_debug "Recording start time marker: $start_time"
  
  # Visual indicator that recording has started (instant feedback!)
  show_notification "WhisperHelper" "Recording started..."
  log_debug "Notification sent: Recording started"
  
  # Store the process ID for the recording session
  echo $$ > "$RECORDING_PID_FILE"
  log_debug "Recording session started with instant audio capture"
  
  log_debug "Recording started successfully - ZERO delay!"
  
  # Don't exit the function immediately, let it complete
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
  
  # Check if we have a start marker
  if [ ! -f "$RECORDING_START_MARKER" ]; then
    log_debug "ERROR: No recording start marker found"
    show_notification "WhisperHelper" "Recording start time not found"
    return 1
  fi
  
  # Get the start time and calculate duration
  local start_time=$(cat "$RECORDING_START_MARKER" 2>/dev/null)
  local end_time=$(date +%s.%N)
  
  # Calculate duration in seconds (with decimal precision)
  local duration=$(echo "$end_time - $start_time" | bc -l)
  log_debug "Recording duration: $duration seconds (from $start_time to $end_time)"
  
  # Enforce minimum recording time (0.5 seconds)
  local min_duration=0.5
  if (( $(echo "$duration < $min_duration" | bc -l) )); then
    local sleep_time=$(echo "$min_duration - $duration" | bc -l)
    log_debug "Recording too short ($duration s), waiting additional $sleep_time seconds"
    show_notification "WhisperHelper" "Recording... (minimum 0.5 seconds)"
    sleep "$sleep_time"
    # Recalculate end time and duration
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    log_debug "Final recording duration: $duration seconds"
  fi
  
  # Check if SoX daemon is still running
  if [ ! -f "$SOX_DAEMON_PID_FILE" ]; then
    log_debug "ERROR: SoX daemon PID file not found"
    show_notification "WhisperHelper" "Audio daemon stopped"
    cleanup_recording_session
    return 1
  fi
  
  local daemon_pid=$(cat "$SOX_DAEMON_PID_FILE" 2>/dev/null)
  if [ -z "$daemon_pid" ] || ! kill -0 "$daemon_pid" 2>/dev/null; then
    log_debug "ERROR: SoX daemon process not running"
    show_notification "WhisperHelper" "Audio daemon stopped"
    cleanup_recording_session
    return 1
  fi
  
  show_notification "WhisperHelper" "Processing audio..."
  log_debug "Extracting audio segment from continuous recording"
  
  # Simpler approach: calculate bytes to extract based on audio format
  # 16kHz, 16-bit, mono = 32,000 bytes per second
  local bytes_per_second=32000
  local bytes_to_extract=$(echo "$duration * $bytes_per_second" | bc -l | cut -d. -f1)
  log_debug "Need to extract $bytes_to_extract bytes for $duration seconds"
  
  # Get current file size
  local file_size=$(stat -f%z "$CONTINUOUS_AUDIO_FILE" 2>/dev/null || echo "0")
  log_debug "Current continuous file size: $file_size bytes"
  
  if [ "$file_size" -gt 44 ]; then  # WAV header is 44 bytes
    # Calculate skip amount (file size - header - bytes we want)
    local wav_header_size=44
    local data_size=$((file_size - wav_header_size))
    local skip_bytes=$((data_size - bytes_to_extract))
    
    if [ $skip_bytes -lt 0 ]; then
      skip_bytes=0
      bytes_to_extract=$data_size
      log_debug "Extracting entire audio data: $bytes_to_extract bytes"
    else
      log_debug "Skipping $skip_bytes bytes, extracting last $bytes_to_extract bytes"
    fi
    
    # Create a new WAV file with the extracted audio
    if {
      # Copy WAV header
      dd if="$CONTINUOUS_AUDIO_FILE" of="$TEMP_AUDIO_FILE" bs=44 count=1 2>/dev/null
      # Append the audio data we want
      dd if="$CONTINUOUS_AUDIO_FILE" of="$TEMP_AUDIO_FILE" bs=1 skip=$((wav_header_size + skip_bytes)) count=$bytes_to_extract conv=notrunc seek=44 2>/dev/null
    }; then
      log_debug "Successfully extracted audio segment using byte-level extraction"
      
      # Verify the extracted audio file
      if [ -f "$TEMP_AUDIO_FILE" ] && [ -s "$TEMP_AUDIO_FILE" ]; then
        log_debug "Audio extraction successful, proceeding with transcription"
        
        # Process the recording
        local start_time=$(date +%s)
        get_transcription >/dev/null
        local transcription_status=$?
        local end_time=$(date +%s)
        local transcription_duration=$((end_time - start_time))
        log_debug "Transcription request took $transcription_duration seconds with status: $transcription_status"
        
        # Check transcription result
        if [ $transcription_status -eq 0 ] && [ -f "$TEMP_TRANSCRIPT_FILE" ]; then
          if [ ! -s "$TEMP_TRANSCRIPT_FILE" ]; then
            log_debug "Transcription file exists but is empty (no speech detected)"
            show_notification "WhisperHelper" "No speech detected"
          else
            log_debug "Transcription successful, inserting text"
            insert_text
          fi
        else
          if [ $transcription_duration -ge $WHISPER_API_TIMEOUT ]; then
            log_debug "Transcription request timed out after $transcription_duration seconds"
            show_notification "WhisperHelper" "Transcription timed out - server may be overloaded"
          else
            log_debug "Transcription failed or returned empty"
            show_notification "WhisperHelper" "Transcription failed - check logs"
          fi
        fi
      else
        log_debug "ERROR: Audio extraction failed - no audio file created"
        show_notification "WhisperHelper" "Audio extraction failed"
      fi
    else
      log_debug "ERROR: Failed to create temporary audio file"
      show_notification "WhisperHelper" "Audio processing failed"
    fi
  else
    log_debug "ERROR: Continuous audio file is too small to extract audio"
    show_notification "WhisperHelper" "Audio processing failed"
  fi
  
  # Clean up recording session
  cleanup_recording_session
  log_debug "Stop recording process completed"
  return 0
}

# Helper function to clean up recording session files
cleanup_recording_session() {
  log_debug "Cleaning up recording session files"
  rm -f "$TEMP_AUDIO_FILE"
  rm -f "$TEMP_TRANSCRIPT_FILE"
  rm -f "$STOP_RECORDING_FLAG"
  rm -f "$LOCK_FILE"
  rm -f "$RECORDING_PID_FILE"
  rm -f "$RECORDING_START_MARKER"
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
  
  # Check if Whisper API server is healthy first
  echo "Checking server health..." >&2
  if ! check_whisper_health; then
    log_debug "Error: Whisper API server is not healthy or ready"
    echo "Error: Whisper API server is not healthy or ready. Please check if the server is running and accessible." >&2
    return 1
  fi
  echo "Server is healthy and ready." >&2
  
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
    -H "Connection: close" \
    -F "file=@$TEMP_AUDIO_FILE" \
    -F "temperature=0.0" \
    -F "response_format=json" \
    --connect-timeout 5 \
    --max-time $WHISPER_API_TIMEOUT \
    --retry 0 \
    --no-keepalive \
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
        echo "Error: Inference request timed out after $WHISPER_API_TIMEOUT seconds." >&2
        echo "This usually means the Whisper server is hanging on inference requests." >&2
        echo "Try restarting the Whisper server or check server logs for errors." >&2
        log_debug "Timeout after $WHISPER_API_TIMEOUT seconds. Inference request is hanging - server issue."
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
  
  # Convert literal "\n" to actual newlines
  text=$(echo "$text" | sed 's/\\n/\n/g')
  log_debug "Text after newline conversion: $text"
  
  # Platform-specific text insertion
  case "$OS_TYPE" in
    "linux")
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
      ;;
    "macos")
      log_debug "Attempting to type text directly into active window"
      # On macOS, use AppleScript to type the text directly
      # First, escape any quotes and backslashes in the text
      local escaped_text=$(echo "$text" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
      
      # Use AppleScript to type the text
      if osascript -e "tell application \"System Events\" to keystroke \"$escaped_text\"" 2>> "$LOG_FILE"; then
        log_debug "Text successfully typed into the active window"
        echo "Text typed into the active window" >&2
      else
        log_debug "AppleScript typing failed, falling back to clipboard"
        # If typing fails, copy to clipboard as fallback
        echo "$text" | pbcopy
        log_debug "Text copied to clipboard"
        echo "Text copied to clipboard" >&2
        show_notification "WhisperHelper" "Text copied to clipboard. Paste with Cmd+V."
      fi
      ;;
    *)
      log_debug "Unknown OS, falling back to stdout"
      echo "Transcription: $text"
      ;;
  esac
}

# Function to record for 5 seconds and automatically transcribe
record_5_seconds() {
  log_debug "Starting 5-second recording"
  
  # Check if recording is already in progress
  if is_recording_active; then
    local pid=$(cat "$LOCK_FILE" 2>/dev/null)
    log_debug "Recording already in progress. PID: $pid"
    echo "Recording already in progress."
    show_notification "WhisperHelper" "Recording already in progress."
    return 1
  fi
  
  # Check if SoX daemon is running
  if [ ! -f "$SOX_DAEMON_PID_FILE" ]; then
    log_debug "ERROR: SoX daemon not running. Please restart WhisperHelper."
    show_notification "WhisperHelper" "Audio daemon not running. Please restart WhisperHelper."
    return 1
  fi
  
  local daemon_pid=$(cat "$SOX_DAEMON_PID_FILE" 2>/dev/null)
  if [ -z "$daemon_pid" ] || ! kill -0 "$daemon_pid" 2>/dev/null; then
    log_debug "ERROR: SoX daemon process not found. Please restart WhisperHelper."
    show_notification "WhisperHelper" "Audio daemon stopped. Please restart WhisperHelper."
    return 1
  fi
  
  # Remove any existing temp files
  rm -f "$STOP_RECORDING_FLAG"
  rm -f "$TEMP_AUDIO_FILE"
  log_debug "Removed temp files"
  
  # Create lock file with current process ID
  echo $$ > "$LOCK_FILE"
  log_debug "Created lock file with PID: $$"
  
  # Record the start time (in seconds since epoch with high precision)
  local start_time=$(date +%s.%N)
  echo "$start_time" > "$RECORDING_START_MARKER"
  log_debug "Recording start time marker: $start_time"
  
  # Visual indicator that recording has started
  show_notification "WhisperHelper" "Recording for 5 seconds..."
  log_debug "Notification sent: Recording for 5 seconds"
  
  # Store the process ID for the recording session
  echo $$ > "$RECORDING_PID_FILE"
  log_debug "5-second recording session started with instant audio capture"
  
  # Wait for exactly 5 seconds
  log_debug "Recording for 5 seconds..."
  echo "Recording for 5 seconds..."
  sleep 5
  
  # Stop recording and process
  log_debug "Stopping recording and processing audio..."
  echo "Stopping recording and processing audio..."
  stop_recording
  
  log_debug "5-second recording completed"
  echo "5-second recording completed"
}

# Cleanup function to ensure we don't leave lock files or temporary files
cleanup() {
  log_debug "Cleanup called"
  # Only clean up if we're not in the start command
  if [ "$1" != "start" ]; then
    cleanup_recording_session
    # Also clean up daemon files if this is a full shutdown
    if [ "$1" = "shutdown" ]; then
      # Stop the SoX daemon
      if [ -f "$SOX_DAEMON_PID_FILE" ]; then
        local daemon_pid=$(cat "$SOX_DAEMON_PID_FILE" 2>/dev/null)
        if [ -n "$daemon_pid" ] && kill -0 "$daemon_pid" 2>/dev/null; then
          log_debug "Stopping SoX daemon (PID: $daemon_pid)"
          kill "$daemon_pid" 2>/dev/null || true
        fi
      fi
      rm -f "$SOX_DAEMON_PID_FILE"
      rm -f "$CONTINUOUS_AUDIO_FILE"
    fi
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
elif [ "$1" = "record_5_seconds" ]; then
  log_debug "Command: record_5_seconds"
  # Set trap to clean up on exit
  trap cleanup EXIT INT TERM
  record_5_seconds
elif [ "$1" = "health" ]; then
  log_debug "Command: health"
  # Check Whisper API server health
  if check_whisper_health; then
    echo "✅ Whisper API server is healthy and ready"
    exit 0
  else
    echo "❌ Whisper API server is not healthy or unreachable"
    exit 1
  fi
elif [ "$1" = "test" ]; then
  log_debug "Command: test"
  echo "🔍 Testing Whisper server..."
  
  # Test health endpoint
  echo "1. Testing health endpoint..."
  if check_whisper_health; then
    echo "   ✅ Health check passed"
  else
    echo "   ❌ Health check failed"
    exit 1
  fi
  
  # Test inference with minimal audio
  echo "2. Testing inference endpoint with minimal audio..."
  
  # Create a very short test audio file (0.1 seconds of silence)
  test_file="/tmp/whisper_test_audio.wav"
  if sox -n -r 16000 -c 1 "$test_file" trim 0 0.1 2>/dev/null; then
    echo "   Created test audio file"
    
    # Test inference with short timeout to detect hanging
    test_start=$(date +%s)
    test_response=""
    test_status=0
    
    echo "   Sending test inference request (timeout: 10s)..."
    test_response=$(curl -s -X POST \
      "$WHISPER_API_URL" \
      -H "Content-Type: multipart/form-data" \
      -F "file=@$test_file" \
      -F "temperature=0.0" \
      -F "response_format=json" \
      --connect-timeout 3 \
      --max-time 10 \
      2>/dev/null) || test_status=$?
    
    test_end=$(date +%s)
    test_duration=$((test_end - test_start))
    
    rm -f "$test_file"
    
    if [ $test_status -eq 0 ]; then
      echo "   ✅ Inference test passed (${test_duration}s)"
      echo "   Response: $test_response"
    else
      echo "   ❌ Inference test failed (${test_duration}s)"
      if [ $test_status -eq 28 ]; then
        echo "   💡 Server is hanging on inference requests - restart the server"
      else
        echo "   💡 Curl error code: $test_status"
      fi
      exit 1
    fi
  else
    echo "   ❌ Failed to create test audio file"
    exit 1
  fi
  
  echo "🎉 All tests passed! Server is working correctly."
else
  # For backward compatibility or manual testing
  echo "Usage: $0 [start|stop|record_5_seconds|health|test]"
  case "$OS_TYPE" in
    "linux")
      echo "This script is designed to be called by xbindkeys for press/release events or timed recordings."
      ;;
    "macos")
      echo "This script is designed to be used with macOS hotkeys via Hammerspoon or other hotkey managers."
      ;;
    *)
      echo "This script is designed to be called by hotkey managers for press/release events or timed recordings."
      ;;
  esac
  check_dependencies
  exit 1
fi 