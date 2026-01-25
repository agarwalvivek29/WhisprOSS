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
- **Transcription History** — Browse, search, and revisit past transcriptions with SwiftData persistence
- **Guided Onboarding** — 4-step setup wizard for permissions and configuration

## How It Works

1. **Press and hold `Fn` key** to start recording (or Right `⌘` as alternative)
2. **Speak naturally** — don't worry about "um"s or pauses
3. **Release the key** — text is transcribed, cleaned up, and pasted

That's it. No clicking, no copy-paste, no switching windows.

### First Launch

On first launch, you'll be guided through a 4-step onboarding:
1. **Welcome** — Introduction to WhisprOSS
2. **Permissions** — Grant Accessibility, Microphone, and Speech Recognition
3. **Configuration** — Set up your LLM endpoint (optional)
4. **Completion** — Ready to start dictating

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

### Transcription History

All transcriptions are automatically saved and can be accessed from the History tab:
- **Search** across raw and processed transcripts
- **Toggle** between raw speech recognition output and LLM-processed text
- **Copy** any transcription to clipboard
- **View metadata** — model used, writing style, formality, word count
- **Delete** individual entries

## Architecture

```
WhisprOSS/
├── App/
│   ├── WhisprOSSApp.swift              # App entry point with dependency injection
│   └── RootView.swift                  # Navigation coordinator (onboarding vs main)
│
├── Models/
│   ├── AppSettings.swift               # User preferences (UserDefaults-backed)
│   ├── TranscriptionEntry.swift        # SwiftData model for history persistence
│   └── NavigationItem.swift            # Sidebar navigation enum
│
├── Services/
│   ├── ConversationController.swift    # Main orchestrator (hotkey, workflow, paste)
│   ├── SpeechManager.swift             # AVAudioEngine + SFSpeechRecognizer
│   ├── LiteLLMClient.swift             # OpenAI-compatible streaming API client
│   └── PermissionsHelper.swift         # Permission checking & requesting
│
├── Views/
│   ├── Main/
│   │   ├── MainView.swift              # Navigation split view with sidebar
│   │   ├── HomeView.swift              # Dashboard with status & instructions
│   │   ├── HistoryView.swift           # Master-detail transcription list
│   │   └── SidebarView.swift           # Navigation sidebar
│   │
│   ├── Settings/
│   │   └── SettingsView.swift          # LLM config, writing preferences
│   │
│   ├── HUD/
│   │   ├── HUDWaveView.swift           # Notch UI with idle/recording states
│   │   └── HUDInstructionsView.swift   # First-launch instructions overlay
│   │
│   ├── Components/
│   │   ├── BrandHeaderView.swift       # Logo and branding
│   │   ├── StatCard.swift              # Status indicator cards
│   │   ├── HistoryEntryRow.swift       # List row component
│   │   └── HistoryDetailView.swift     # Detail panel for transcriptions
│   │
│   └── Onboarding/
│       ├── OnboardingContainerView.swift
│       ├── WelcomeStepView.swift
│       ├── PermissionsStepView.swift
│       ├── ConfigurationStepView.swift
│       └── CompletionStepView.swift
│
└── Assets/
    └── Assets.xcassets/                # App icon and colors
```

### Key Components

| Component | Responsibility |
|-----------|----------------|
| **ConversationController** | Detects Fn key via `NSEvent.flagsChanged`, coordinates recording/transcription/paste, saves to history |
| **SpeechManager** | Manages AVAudioEngine + SFSpeechRecognizer, publishes real-time audio levels for waveform |
| **LiteLLMClient** | Streams chat completions from any OpenAI-compatible API (SSE parsing) |
| **AppSettings** | User preferences with dynamic LLM system prompt generation |
| **HUDWindowController** | Floating NSPanel with Dynamic Island-style notch, multi-monitor aware |

### Data Persistence

| What | Where |
|------|-------|
| **App Settings** | UserDefaults (LLM URL, API key, writing style, formality, etc.) |
| **Transcription History** | SwiftData (`TranscriptionEntry` with raw/processed text, timestamps, metadata) |

## Roadmap

- [x] Transcription history with persistence
- [x] Guided onboarding flow
- [ ] Custom hotkey configuration
- [ ] App-specific tone presets
- [ ] Offline LLM support (llama.cpp, MLX)
- [ ] Command mode ("open Safari", "new email")
- [ ] Undo last transcription
- [ ] Custom vocabulary/corrections
- [ ] iOS companion app

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 — see the [LICENSE](LICENSE) file for details.

## Technologies

- **SwiftUI** — Declarative UI framework
- **Combine** — Reactive state management (ObservableObject, @Published)
- **SwiftData** — On-device persistence for transcription history
- **AVFoundation** — Audio input via AVAudioEngine
- **Speech** — On-device transcription via SFSpeechRecognizer
- **AppKit** — NSPanel for HUD, NSEvent for hotkey detection
- **CoreAudio** — Audio device selection
- **Accelerate** — DSP for RMS waveform calculation

## Acknowledgments

Inspired by [Wispr Flow](https://wisprflow.ai/). Built with SwiftUI, Apple Speech Recognition, and love for open source.

---

**Note:** This is an independent open-source project and is not affiliated with Wispr Inc.
