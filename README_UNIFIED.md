# WhisperHelper - Cross-Platform Speech-to-Text

WhisperHelper is a unified, cross-platform utility for system-wide speech-to-text transcription. It works on both **Linux** and **macOS** using a single set of scripts that automatically detect your operating system and use the appropriate tools.

## Features

- **Cross-platform compatibility**: Works on both Linux and macOS with automatic OS detection
- **Press-and-hold recording**: Hold a hotkey to record, release to transcribe
- **5-second quick recording**: One keypress for a 5-second recording that automatically transcribes
- **Smart text insertion**: Automatically types text or copies to clipboard based on platform capabilities
- **Background processing**: Non-blocking operation with visual feedback via notifications

## Requirements

### Common Requirements (Both Platforms)
- **SoX** for audio recording
- **curl** for API communication
- A running Whisper API server (default: `http://10.0.0.60:8080/inference`)

### Linux-Specific Requirements
- **xbindkeys** for hotkey management
- **xdotool** for text insertion
- **xclip** for clipboard access
- **libnotify** (notify-send) for notifications

Install on Ubuntu/Debian:
```bash
sudo apt-get install sox curl xbindkeys xdotool xclip libnotify-bin
```

### macOS-Specific Requirements
- **Hammerspoon** for hotkey management
- **pbcopy** (built-in) for clipboard access

Install on macOS:
```bash
# Install SoX via Homebrew
brew install sox

# Install Hammerspoon
brew install --cask hammerspoon
```

## Installation

1. Clone or download the WhisperHelper repository
2. Make the scripts executable:
   ```bash
   chmod +x whisper_helper.sh
   chmod +x start_whisper_helper.sh
   chmod +x stop_whisper_helper.sh
   ```
3. Install platform-specific dependencies (see requirements above)

## Usage

### Starting WhisperHelper

```bash
./start_whisper_helper.sh
```

This will:
- Detect your operating system automatically
- Configure the appropriate hotkey manager (xbindkeys on Linux, Hammerspoon on macOS)
- Set up the hotkeys and start listening

### Hotkeys

#### Linux
- **Alt + r**: 5-second recording (automatically transcribes)
- **Alt + Shift + r**: Press and hold to record, release to transcribe

#### macOS
- **Cmd + Option + r**: 5-second recording (automatically transcribes)
- **Cmd + Option + Shift + r**: Press and hold to record, release to transcribe

### Stopping WhisperHelper

```bash
./stop_whisper_helper.sh
```

### Manual Commands

You can also use the main script directly:

```bash
# Start a press-and-hold recording
./whisper_helper.sh start

# Stop the current recording and transcribe
./whisper_helper.sh stop

# Record for 5 seconds and auto-transcribe
./whisper_helper.sh record_5_seconds
```

## Configuration

The main configuration is in `whisper_helper.sh`:

```bash
# API Configuration
WHISPER_API_URL="http://10.0.0.60:8080/inference"
WHISPER_API_TIMEOUT=10

# Debug logging
DEBUG_MODE=true
```

### Text Insertion Behavior

- **Linux**: Attempts to type text directly into the active window using xdotool. Falls back to clipboard if typing fails.
- **macOS**: Copies text to clipboard by default. Set `TYPE_TEXT=true` environment variable to enable direct typing via AppleScript.

## Platform Detection

The scripts automatically detect your operating system:
- **Darwin** → macOS mode
- **Linux** → Linux mode
- **Unknown** → Falls back to basic functionality

## File Structure

After consolidation, you only need these main files:
- `whisper_helper.sh` - Main cross-platform script
- `start_whisper_helper.sh` - Cross-platform startup script
- `stop_whisper_helper.sh` - Cross-platform stop script
- `.xbindkeysrc` - Linux hotkey configuration (used automatically)

The `mac/` directory is now optional - all functionality is consolidated into the main scripts.

## Troubleshooting

### Check Dependencies
The scripts will automatically check for missing dependencies and provide installation instructions for your platform.

### Debug Logging
Debug logs are written to `/tmp/whisper_helper.log`. Enable with:
```bash
DEBUG_MODE=true
```

### Common Issues

1. **Recording not starting**: Check that SoX can access your microphone
2. **Text not inserting**: 
   - Linux: Ensure xdotool is installed and the target window is focused
   - macOS: Text goes to clipboard by default - paste with Cmd+V
3. **API connection issues**: Verify the Whisper server is running at the configured URL

## Notifications

- **Linux**: Uses `notify-send` for system notifications
- **macOS**: Uses AppleScript for native notifications
- All platforms show recording status, transcription progress, and completion/error messages

## Migration from Platform-Specific Versions

If you were using the separate Linux and macOS versions:

1. Replace your existing scripts with the unified versions
2. Run `./start_whisper_helper.sh` - it will automatically detect your platform
3. The hotkeys remain the same on each platform
4. All existing functionality is preserved but now works cross-platform

The unified version maintains full compatibility with existing workflows while adding cross-platform support. 