#!/bin/bash

# Script to run whisper.cpp server with debug options
# This helps diagnose server issues and view detailed logs

# Default configuration
SERVER_PORT=8080
SERVER_HOST="0.0.0.0"
SERVER_THREADS=4
MODEL_PATH="models/ggml-base.en.bin"
LOG_FILE="/tmp/whisper_server_debug.log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT       Server port (default: $SERVER_PORT)"
    echo "  -h, --host HOST       Server host (default: $SERVER_HOST)"
    echo "  -m, --model MODEL     Model path (default: $MODEL_PATH)"
    echo "  -t, --threads N       Number of threads (default: $SERVER_THREADS)"
    echo "  -l, --log FILE        Log file (default: $LOG_FILE)"
    echo "  --help                Show this help message"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            SERVER_PORT="$2"
            shift 2
            ;;
        -h|--host)
            SERVER_HOST="$2"
            shift 2
            ;;
        -m|--model)
            MODEL_PATH="$2"
            shift 2
            ;;
        -t|--threads)
            SERVER_THREADS="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Check if whisper.cpp directory exists
if [ ! -d "whisper.cpp" ]; then
    echo -e "${RED}[ERROR]${NC} whisper.cpp directory not found. Please run this script from the project root."
    exit 1
fi

# Check if the server executable exists
if [ ! -f "whisper.cpp/server" ] && [ ! -f "whisper.cpp/examples/server/server" ]; then
    echo -e "${YELLOW}[WARN]${NC} Server executable not found. Building server..."
    
    # Try to build the server
    cd whisper.cpp
    make server || {
        echo -e "${RED}[ERROR]${NC} Failed to build server."
        exit 1
    }
    cd ..
fi

SERVER_PATH=""
if [ -f "whisper.cpp/server" ]; then
    SERVER_PATH="whisper.cpp/server"
elif [ -f "whisper.cpp/examples/server/server" ]; then
    SERVER_PATH="whisper.cpp/examples/server/server"
else
    echo -e "${RED}[ERROR]${NC} Could not find server executable after build attempt."
    exit 1
fi

# Create log directory if it doesn't exist
LOG_DIR=$(dirname "$LOG_FILE")
mkdir -p "$LOG_DIR"

echo "==============================================="
echo "    WHISPER.CPP SERVER DEBUG MODE"
echo "==============================================="
echo "Server path: $SERVER_PATH"
echo "Host: $SERVER_HOST"
echo "Port: $SERVER_PORT"
echo "Model: $MODEL_PATH"
echo "Threads: $SERVER_THREADS"
echo "Log file: $LOG_FILE"
echo "==============================================="
echo "Starting server with verbose output..."
echo "Press Ctrl+C to stop the server"
echo "==============================================="

# Run the server with debug options and log output
WHISPER_DEBUG=1 WHISPER_VERBOSE=1 $SERVER_PATH \
    --host "$SERVER_HOST" \
    --port "$SERVER_PORT" \
    --model "$MODEL_PATH" \
    --threads "$SERVER_THREADS" \
    --print-progress \
    --convert \
    --language en \
    --log-file "$LOG_FILE" \
    --no-timestamps \
    2>&1 | tee -a "$LOG_FILE" 