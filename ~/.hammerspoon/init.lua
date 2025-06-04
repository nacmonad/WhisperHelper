-- WhisperHelper Hammerspoon Configuration
-- This sets up hotkeys for speech-to-text functionality

print("=== WhisperHelper Configuration Loading ===")

local whisperPath = "/Users/pointcoexpedro/Dev/WhisperHelper/whisper_helper.sh"

-- Global variable to track recording state
local isRecording = false
local recordingStartTime = nil

-- Function to run WhisperHelper commands
function runWhisperHelper(command)
    print("DEBUG: runWhisperHelper called with command: " .. command)
    local task = hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
        print("DEBUG: Task completed with exit code: " .. exitCode)
        if stdOut then print("DEBUG: stdout: " .. stdOut) end
        if stdErr then print("DEBUG: stderr: " .. stdErr) end
        if exitCode ~= 0 then
            hs.alert.show("WhisperHelper error: " .. (stdErr or "Unknown error"))
        end
    end, {whisperPath, command})
    task:start()
end

-- Function to stop recording with timeout protection
function stopRecording()
    if isRecording then
        print("DEBUG: Stopping recording...")
        isRecording = false
        hs.alert.show("🛑 Stopped. Processing...", 2)
        runWhisperHelper("stop")
        recordingStartTime = nil
    end
end

-- Function to start recording
function startRecording()
    if not isRecording then
        print("DEBUG: Starting recording...")
        isRecording = true
        recordingStartTime = hs.timer.secondsSinceEpoch()
        hs.alert.show("🎤 Recording... (press Cmd+Shift+S to stop)", 1)
        runWhisperHelper("start")
        
        -- Auto-stop after 60 seconds as safety measure
        hs.timer.doAfter(60, function()
            if isRecording then
                print("DEBUG: Auto-stopping recording after 60 seconds")
                stopRecording()
            end
        end)
    end
end

-- Test function to verify hotkeys are working
function testHotkey()
    print("DEBUG: testHotkey function called!")
    hs.alert.show("Hotkey test - this means hotkeys are working!")
    print("Hotkey test successful")
end

-- Test hotkey first
print("DEBUG: Binding test hotkey Cmd+Shift+T")
hs.hotkey.bind({"cmd", "shift"}, "t", function()
    print("DEBUG: Test hotkey triggered!")
    testHotkey()
end)

-- Separate start and stop hotkeys for more reliability
print("DEBUG: Binding start recording hotkey Cmd+Shift+Space")
hs.hotkey.bind({"cmd", "shift"}, "space", function()
    print("DEBUG: Start recording triggered!")
    startRecording()
end)

print("DEBUG: Binding stop recording hotkey Cmd+Shift+S")
hs.hotkey.bind({"cmd", "shift"}, "s", function()
    print("DEBUG: Stop recording triggered!")
    stopRecording()
end)

-- Alternative push-to-talk using different approach
print("DEBUG: Binding alternative push-to-talk Cmd+Shift+H")
local pttModal = hs.hotkey.modal.new({"cmd", "shift"}, "h")

pttModal:bind({}, 'escape', function()
    print("DEBUG: Push-to-talk cancelled")
    pttModal:exit()
    stopRecording()
end)

function pttModal:entered()
    print("DEBUG: Push-to-talk modal entered - starting recording")
    hs.alert.show("🎤 Recording... (release Cmd+Shift+H to stop)", 0.5)
    startRecording()
end

function pttModal:exited()
    print("DEBUG: Push-to-talk modal exited - stopping recording")
    stopRecording()
end

-- Alternative: 5-second recording with a single key press
print("DEBUG: Binding 5-second recording hotkey Cmd+Shift+R")
hs.hotkey.bind({"cmd", "shift"}, "r", function()
    print("DEBUG: 5-second recording triggered!")
    -- Let the shell script handle all notifications
    runWhisperHelper("record_5_seconds")
end)

-- Emergency cleanup hotkey
print("DEBUG: Binding emergency cleanup hotkey Cmd+Shift+C")
hs.hotkey.bind({"cmd", "shift"}, "c", function()
    print("DEBUG: Emergency cleanup triggered!")
    isRecording = false
    recordingStartTime = nil
    hs.alert.show("🧹 Emergency cleanup performed", 1)
    -- Kill any stuck processes
    os.execute("pkill -f 'sox.*whisper_helper'")
    os.execute("rm -f /tmp/whisper_helper*")
end)

-- Show notification when Hammerspoon config is loaded
hs.alert.show("WhisperHelper hotkeys loaded!\nCmd+Shift+Space: Start recording\nCmd+Shift+S: Stop recording\nCmd+Shift+H: Hold for push-to-talk\nCmd+Shift+R: 5-second recording\nCmd+Shift+C: Emergency cleanup")

-- Auto-reload config when this file changes
function reloadConfig(files)
    local doReload = false
    for _,file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
end
local myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

print("WhisperHelper Hammerspoon setup complete!")
print("=== Configuration Loading Finished ===")