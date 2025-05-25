# WhisperHelper for macOS

A macOS utility for system-wide speech-to-text. Uses SoX for recording audio and connects to a remote Whisper API server for transcription.

## Requirements

- macOS 10.14 or higher
- [Homebrew](https://brew.sh/) for installing dependencies
- [Hammerspoon](https://www.hammerspoon.org/) for hotkey support

## Installation

1. Install required dependencies:

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install SoX for audio recording
brew install sox

# Install Hammerspoon for hotkey support
brew install --cask hammerspoon
```

2. Make the scripts executable:

```bash
chmod +x *.sh
```

3. Start WhisperHelper:

```bash
./start_whisper_helper_mac.sh
```

This will configure Hammerspoon with the appropriate hotkeys and start the service.

## Usage

WhisperHelper provides two recording modes:

1. **5-Second Recording**: Press `Alt+r` to start a recording that will automatically stop after 5 seconds and be transcribed.

2. **Press-and-Hold Recording**: Press and hold `Alt+Shift+r` to start recording, then release the key combination to stop recording and trigger transcription.

After transcription, the text is automatically copied to your clipboard, so you can paste it anywhere with `Cmd+v`.

## Stopping the Service

To stop WhisperHelper completely:

```bash
./stop_whisper_helper_mac.sh
```

## Configuration

The WhisperHelper scripts use the following configuration:

- Whisper API URL: `http://10.0.0.60:8080/inference`
  - You can edit `whisper_helper_mac.sh` to change this URL.

- Hotkeys: 
  - `Alt+r` for 5-second recording
  - `Alt+Shift+r` for press-and-hold recording
  - These can be modified in the Hammerspoon configuration file at `~/.hammerspoon/init.lua`

## Troubleshooting

- **SoX Recording Issues**: Ensure your microphone is properly connected and set as the default input device in System Preferences.

- **Transcription Fails**: Check the log file at `/tmp/whisper_helper.log` for detailed error messages.

- **Hammerspoon Not Working**: Open Hammerspoon, click on the menubar icon, and select "Reload Config". Check the Hammerspoon console for any errors.

## Files

- `whisper_helper_mac.sh`: Main script for recording and transcription
- `start_whisper_helper_mac.sh`: Script to start the service and configure Hammerspoon
- `stop_whisper_helper_mac.sh`: Script to stop the service and clean up
- `record_5_seconds_mac.sh`: Script for 5-second recording mode
- `record_press_hold_mac.sh`: Script for press-and-hold recording (start)
- `record_release_mac.sh`: Script for press-and-hold recording (stop)

## Notes

- The transcribed text is copied to the clipboard for easy pasting.
- You can set `TYPE_TEXT=true` in your environment to have WhisperHelper type the text using AppleScript instead of copying to clipboard.
- All temporary files are stored in `/tmp/` and are cleaned up after each recording. 