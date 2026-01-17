# WhisprOSS

**Open-source voice-to-text for macOS** — Speak naturally, paste polished text anywhere.

WhisprOSS is a free, open-source alternative to [Wispr Flow](https://wisprflow.ai/). Press and hold a key, speak your thoughts, and get clean, formatted text pasted directly into any application.

## Features

- **Universal Dictation** — Works across any macOS application (Slack, VS Code, Notion, browsers, etc.)
- **On-Device Transcription** — Uses Apple's Speech Recognition for fast, private transcription
- **AI-Powered Cleanup** — Optional LLM processing removes filler words ("um", "uh", "like") and adds proper formatting
- **Direct Paste Mode** — Skip LLM for instant raw transcription when you need speed
- **Dynamic Island-Style HUD** — Minimal notch UI that expands during recording with live waveform
- **Full-Screen Support** — Overlay works even over full-screen applications
- **Multi-Monitor Support** — HUD follows your active screen
- **Customizable Writing Style** — Choose tone (casual, professional, creative, technical) and formality level

## How It Works

1. **Press and hold `Fn` key** to start recording
2. **Speak naturally** — don't worry about "um"s or pauses
3. **Release `Fn`** — text is transcribed, cleaned up, and pasted

That's it. No clicking, no copy-paste, no switching windows.

## Requirements

- macOS 14.0+
- Microphone access
- Accessibility permission (for global hotkey)
- Speech Recognition permission
- (Optional) LiteLLM proxy or OpenAI-compatible API for text cleanup

## Installation

### Build from Source

```bash
git clone https://github.com/agarwalvivek29/WhisprOSS.git
cd WhisprOSS
open WhisprOSS.xcodeproj
```

Build and run in Xcode (⌘R).

### Permissions

On first launch, grant these permissions in System Settings → Privacy & Security:
- **Accessibility** — Required for global Fn key detection
- **Microphone** — Required for voice recording
- **Speech Recognition** — Required for on-device transcription

## Configuration

### LLM Setup (Optional)

WhisprOSS can use any OpenAI-compatible API for text cleanup:

1. Open Settings in the app
2. Enter your LiteLLM/OpenAI base URL (default: `http://127.0.0.1:4000`)
3. Add API key if required
4. Choose your model (default: `gpt-4o-mini`)

**Or use Direct Paste Mode** — Toggle off "Use LLM Processing" for instant raw transcription without any API.

### Writing Preferences

- **Writing Style** — Casual, Professional, Creative, or Technical
- **Formality** — Informal, Neutral, or Formal
- **Remove Filler Words** — Strip "um", "uh", "like", "you know"
- **Auto-Format** — Add punctuation and capitalization

## Architecture

```
WhisprOSS/
├── WhisprOSSApp.swift          # App entry point
├── ConversationController.swift # Hotkey handling, workflow orchestration
├── SpeechManager.swift          # Audio recording & transcription
├── LiteLLMClient.swift          # LLM streaming client
├── HUDWaveView.swift            # Dynamic notch UI
├── AppSettings.swift            # User preferences
└── SettingsView.swift           # Settings UI
```

## Roadmap

- [ ] Custom hotkey configuration
- [ ] App-specific tone presets
- [ ] Offline LLM support (llama.cpp, MLX)
- [ ] Command mode ("open Safari", "new email")
- [ ] History and undo
- [ ] Custom vocabulary/corrections
- [ ] iOS companion app

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 — see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by [Wispr Flow](https://wisprflow.ai/). Built with SwiftUI, Apple Speech Recognition, and love for open source.

---

**Note:** This is an independent open-source project and is not affiliated with Wispr Inc.
