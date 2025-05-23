# WhisperHelper

A Linux utility that provides system-wide speech-to-text functionality by connecting to a remote Whisper API server.

## Overview

WhisperHelper allows you to convert speech to text anywhere in your Linux system with a simple hotkey. It records your voice using SoX, sends the audio to a configured Whisper API endpoint, and types the transcribed text into your currently focused application or copies it to the clipboard.

## Features

- System-wide hotkey activation (Alt+r for 5-second recording)
- Audio recording from system microphone using SoX
- Integration with remote Whisper API (compatible with OpenAI's Whisper model)
- Automatic text insertion into the active application
- Clipboard fallback when no text field is focused

## Usage

1. Start the WhisperHelper service by running `./start_whisper_helper.sh`
2. Press `Alt+r` to start recording for 5 seconds
3. After 5 seconds, the recording will stop automatically and be sent for transcription
4. The transcribed text will be inserted at your cursor position

To stop the service, run `./stop_whisper_helper.sh`

## Requirements

- Linux system with X11
- SoX (Sound eXchange) for audio recording
- curl for API communication
- xdotool for text insertion
- xclip for clipboard operations
- xbindkeys for hotkey binding

Install dependencies on Ubuntu/Debian:
```bash
sudo apt-get install sox curl xdotool xclip xbindkeys
```

## Configuration

You can modify the `.xbindkeysrc` file to customize hotkeys or add additional recording durations.

The main API endpoint and other settings can be changed in the `whisper_helper.sh` script.

## Implementation Details

1. **Input Detection**
   - Global hotkey detection using xbindkeys
   - Configured to use Alt+r for 5-second recording and transcription

2. **Audio Recording**
   - Captures audio from the default microphone using SoX
   - Handles recording start/stop via script commands

3. **API Integration**
   - Sends recorded audio to the remote Whisper API (http://10.0.0.60:8080/inference)
   - Processes the API response to extract transcribed text

4. **Text Insertion**
   - Uses xdotool to type the transcribed text into the active window
   - Falls back to clipboard (xclip) if text insertion fails

## System Integration

- Create a startup entry to run `start_whisper_helper.sh` on login for persistent availability
- The included desktop file can be used for autostart 