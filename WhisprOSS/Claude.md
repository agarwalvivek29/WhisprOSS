# WhisprOSS Voice-First Assistant for macOS

## Overview

WhisprOSS is a voice-first dictation assistant for macOS inspired by Wispr Flow. The workflow is: press-and-hold Fn key → record speech → release to stop → transcribe with Apple's on-device speech recognition → clean up with LLM → paste cleaned text into active application.

**Current Status: v0 - Working MVP**

---

## Product Goals

- **Press-and-hold Fn key** to start/stop recording (Right Command as testing fallback)
- **Minimal HUD overlay** showing microphone icon and live audio waveform
- **On-device transcription** using `SFSpeechRecognizer` (fast, private)
- **LLM cleanup** via LiteLLM proxy to remove filler words and improve formatting
- **Auto-paste** cleaned text into active application
- Multi-monitor support with HUD appearing on the active screen

---

## Architecture

### Core Components

1. **SpeechManager.swift**
   - Manages `AVAudioEngine` for microphone input
   - Uses `SFSpeechRecognizer` for on-device transcription
   - Publishes real-time audio level for waveform animation
   - Explicitly sets system default audio input device to avoid aggregate device issues

2. **LiteLLMClient.swift**
   - Streams chat completions from LiteLLM proxy (`/v1/chat/completions`)
   - Configurable base URL and API key
   - Async sequence-based streaming for low latency

3. **ConversationController.swift**
   - Orchestrates the complete workflow
   - Monitors Fn key press/release via `flagsChanged` events
   - Tracks modifier flag state to detect Fn key transitions
   - Coordinates speech → transcription → LLM → paste

4. **HUDWaveView.swift & HUDWindowController.swift**
   - Borderless, transparent overlay window
   - Shows mic icon + animated waveform based on audio level
   - Intelligent screen detection: appears on screen with active window or mouse cursor

5. **AppSettings.swift**
   - User-configurable settings: LiteLLM URL, API key, model, writing style, formality
   - Builds dynamic system prompts based on user preferences
   - Persisted to UserDefaults

6. **PermissionsHelper.swift**
   - Manages macOS permissions: Accessibility, Microphone, Speech Recognition
   - Provides UI helpers to request and check permissions

---

## Implementation Details

### Hotkey Detection (Fn Key)

The Fn key doesn't generate `keyDown`/`keyUp` events on macOS. Instead:

```swift
// Track modifier flag changes to detect Fn press/release
private var previousModifierFlags: NSEvent.ModifierFlags = []

NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
    let fnWasPressed = previousModifierFlags.contains(.function)
    let fnIsPressed = event.modifierFlags.contains(.function)

    if fnIsPressed && !fnWasPressed {
        // Fn key pressed - start recording
    } else if !fnIsPressed && fnWasPressed {
        // Fn key released - stop recording
    }

    previousModifierFlags = event.modifierFlags
}
```

### Audio Device Selection

AVAudioEngine sometimes defaults to aggregate devices instead of the actual microphone. Fix:

```swift
// Get system default input device ID
var deviceID: AudioDeviceID = 0
var propertyAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultInputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), ...)

// Explicitly set it on the audio engine
let inputNode = audioEngine.inputNode
AudioUnitSetProperty(
    inputNode.audioUnit!,
    kAudioOutputUnitProperty_CurrentDevice,
    kAudioUnitScope_Global,
    0,
    &deviceID,
    UInt32(MemoryLayout<AudioDeviceID>.size)
)
audioEngine.reset()
```

### Multi-Monitor HUD Positioning

The HUD detects the active screen in priority order:

1. **Screen containing the frontmost app's main window** (using `CGWindowListCopyWindowInfo`)
2. **Screen containing the mouse cursor** (fallback when windows minimized)
3. **Main screen** (final fallback)

```swift
let mouseLocation = NSEvent.mouseLocation
let activeScreen = NSScreen.screens.first { screen in
    NSMouseInRect(mouseLocation, screen.frame, false)
} ?? NSScreen.main

// Position HUD at bottom center of active screen
let x = screen.visibleFrame.minX + (screen.visibleFrame.width - size.width) / 2
let y = screen.visibleFrame.minY + margin
```

### Sandbox & Entitlements

The app is sandboxed and requires specific entitlements:

**WhisprOSS.entitlements:**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.automation.apple-events</key>
<true/>
```

### Required Permissions

**Info.plist entries:**
- `NSMicrophoneUsageDescription` - For audio recording
- `NSSpeechRecognitionUsageDescription` - For on-device transcription

**System Settings:**
- Accessibility permission required for global hotkey monitoring
- Microphone permission required (automatically prompted)
- Speech Recognition permission required (automatically prompted)

---

## macOS Platform Issues & Solutions

### Issue 1: Microphone Reading 0.0 Despite Permission
**Symptom:** All permissions granted, but audio samples are all zeros.
**Cause:** App is sandboxed without `com.apple.security.device.audio-input` entitlement.
**Solution:** Create entitlements file and add `CODE_SIGN_ENTITLEMENTS` to project settings.

### Issue 2: Audio Engine Using Wrong Device
**Symptom:** Logs show "CADefaultDeviceAggregate" instead of actual microphone.
**Cause:** AVAudioEngine defaults to aggregate device in some configurations.
**Solution:** Explicitly set device using CoreAudio APIs before starting engine.

### Issue 3: LLM Network Requests Failing
**Symptom:** DNS errors when connecting to LiteLLM proxy.
**Cause:** Sandboxed app without network client entitlement.
**Solution:** Add `com.apple.security.network.client` entitlement.

### Issue 4: Fn Key Not Detected
**Symptom:** No logs when pressing Fn key.
**Cause:** Fn key only generates `flagsChanged` events, not `keyDown`/`keyUp`.
**Solution:** Monitor `flagsChanged` and track modifier flag state changes.

### Issue 5: HUD Appears on Wrong Screen
**Symptom:** HUD always appears on main screen, not active window's screen.
**Cause:** Using `NSScreen.main` instead of detecting active screen.
**Solution:** Use `CGWindowListCopyWindowInfo` to find frontmost window's screen.

---

## File Structure

```
WhisprOSS/
├── WhisprOSSApp.swift          # App entry point, dependency injection
├── ContentView.swift            # Main UI with permission banners
├── ConversationController.swift # Hotkey handling, workflow orchestration
├── SpeechManager.swift          # Audio recording & transcription
├── LiteLLMClient.swift          # LLM streaming client
├── HUDWaveView.swift            # HUD overlay UI + window controller
├── AppSettings.swift            # User settings & system prompt builder
├── SettingsView.swift           # Settings UI
├── PermissionsHelper.swift      # Permission checking & requesting
├── WhisprOSS.entitlements       # Sandbox entitlements
└── Claude.md                    # This file
```

---

## Workflow

1. User presses **Fn key**
2. `ConversationController` detects via `flagsChanged` event
3. Starts recording: `SpeechManager.startRecording()`
4. Shows HUD on active screen with live waveform
5. `AVAudioEngine` captures audio, `SFSpeechRecognizer` transcribes in real-time
6. User releases **Fn key**
7. Stops recording, retrieves final transcript
8. Sends transcript to LLM with system prompt based on user settings
9. LLM streams back cleaned text (removes "um", "uh", fixes grammar)
10. Simulates Cmd+V to paste into active app

---

## Key Learnings

1. **Fn key is special** - Only accessible via `flagsChanged` events with `.function` modifier
2. **Sandbox requires explicit entitlements** - Audio and network access must be declared
3. **AVAudioEngine device selection** - Must explicitly set device to avoid aggregates
4. **Multi-monitor HUD** - Requires detecting frontmost window's screen, not just main screen
5. **Global event monitors** - Need both global (other apps) and local (own app) monitors
6. **Real-time transcription** - `SFSpeechRecognizer` provides partial results during recording

---

## Future Improvements

- [ ] User-configurable hotkey (not just Fn)
- [ ] App-specific tone/style presets (e.g., formal for email, casual for Slack)
- [ ] Offline LLM support (llama.cpp, MLX)
- [ ] Command mode (e.g., "open Safari", "new email to John")
- [ ] History/undo for pasted text
- [ ] Custom vocabulary/corrections
- [ ] Whisper API fallback for better transcription quality

---

## Development Notes

**Minimum Requirements:**
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

**Debug Build Path (for Accessibility permission):**
```
/Users/agarwalvivek29/Library/Developer/Xcode/DerivedData/WhisprOSS-arhuvkuxazwkcchknllrnxbrlbrj/Build/Products/Debug/WhisprOSS.app
```

**Testing:**
- Use Right Command (⌘) as fallback hotkey for testing
- Test on multiple monitors if available
- Verify microphone selection in System Settings → Sound → Input

---

## Git Commit Guidelines

- **Do NOT add co-author lines** to commits (no `Co-Authored-By:` trailers)
- Use conventional commit format: `type: description`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`