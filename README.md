# Wispr Clone

A minimal voice-dictation app for macOS (Apple Silicon), inspired by Wispr Flow.
Hold a hotkey, speak, and the transcribed text is pasted into whatever app you're using.

- **On-device transcription** via Apple's `SFSpeechRecognizer` — no API key, fully offline.
- **Optional AI cleanup** with Claude (removes filler words, fixes grammar/punctuation). Off by default.
- **Menu-bar app** — no Dock icon, no window.

## Build

```bash
./build_app.sh
open "build/Wispr Clone.app"
```

Requires the Swift toolchain (Command Line Tools). No full Xcode needed.

## First launch — grant permissions

On first run macOS will ask for, or you'll need to enable in
**System Settings ▸ Privacy & Security**:

1. **Microphone** — to record your voice.
2. **Speech Recognition** — to transcribe on-device.
3. **Accessibility** — to detect the hotkey globally and paste text.

After granting Accessibility, **relaunch the app** (`open "build/Wispr Clone.app"`).

## Usage

- **Hold the Right Option (⌥) key** and speak. Release to stop.
- The text is transcribed and pasted into the focused app (or copied to the
  clipboard if auto-paste is off).
- Click the menu-bar mic icon for options:
  - **AI Cleanup (Claude)** — toggle LLM cleanup of the transcript.
  - **Auto-paste into focused app** — toggle paste vs. clipboard-only.
  - **Set Anthropic API Key…** — required only for AI Cleanup. Stored locally.

## AI cleanup

Cleanup is optional and off by default. To enable:
1. Menu ▸ **Set Anthropic API Key…** (or set the `ANTHROPIC_API_KEY` env var).
2. Menu ▸ **AI Cleanup (Claude)**.

Cleanup never changes meaning — it only removes filler words and fixes
grammar/punctuation/formatting. On any network error it falls back to the raw text.

## Project layout

| File | Purpose |
|------|---------|
| `Sources/WisprClone/main.swift` | App entry point (accessory/menu-bar mode) |
| `AppDelegate.swift` | Status item, menu, wiring, permission flow |
| `SpeechService.swift` | Mic capture + on-device speech recognition |
| `HotkeyManager.swift` | Push-to-talk global hotkey (Right ⌥) |
| `TextInserter.swift` | Pasteboard + synthesized ⌘V insertion |
| `Cleanup.swift` | Optional Claude API cleanup |
| `Settings.swift` | Persisted settings (UserDefaults) |

## Customizing the hotkey

The push-to-talk key is Right Option (virtual keycode `61`) in
`HotkeyManager.swift`. Change `rightOptionKeyCode` to use a different modifier.
