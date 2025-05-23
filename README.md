# WhisperHelper

A Linux utility that provides system-wide speech-to-text functionality by connecting to a remote Whisper API server.

## Overview

WhisperHelper allows you to convert speech to text anywhere in your Linux system with a simple hotkey. It records your voice using SoX, sends the audio to a configured Whisper API endpoint, and types the transcribed text into your currently focused application or copies it to the clipboard.

## Features

- System-wide hotkey activation
- Audio recording from system microphone using SoX
- Integration with remote Whisper API (compatible with OpenAI's Whisper model)
- Automatic text insertion into the active application
- Clipboard fallback when no text field is focused

## Implementation Steps

1. **Input Detection**
   - Implement global hotkey detection using a library like `xlib` or `keyboard`
   - Configure start/stop recording triggers

2. **Audio Recording**
   - Capture audio from the default microphone using SoX (`rec` command)
   - Handle recording start/stop and audio format conversion via SoX

3. **API Integration**
   - Send recorded audio to the remote Whisper API (http://10.0.0.60:8080/inference)
   - Process the API response to extract transcribed text

4. **Text Insertion**
   - Determine the currently focused application/text field using X11 or Wayland protocols
   - Simulate keyboard typing to insert the text using libraries like `xdotool` or `ydotool`
   - Implement clipboard fallback using a library like `xclip` or `wl-clipboard`

5. **Configuration**
   - Create config file for API endpoint, hotkeys, and other preferences
   - Implement settings UI (optional)

6. **System Integration**
   - Create startup service or autostart entry for persistent availability
   - Ensure proper permissions for audio and input device access

## Requirements

- Linux system with X11 or Wayland
- SoX (Sound eXchange) for audio recording
- Bash or Python for script orchestration
- Access to a running Whisper API server 