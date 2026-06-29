# Wispr Clone

Hold a key, speak, release — your words appear wherever your cursor is.
A free, open-source voice-dictation app inspired by [Wispr Flow](https://wisprflow.ai),
built for **macOS**, **Windows**, and the **browser**.

🌐 **Website & downloads:** https://wisper-flow-mac.vercel.app

## Features

- 🎙️ **Push-to-talk dictation** — hold a hotkey, speak, release, text is typed in.
- 🌍 **Multiple languages**, including a **Hinglish (Roman) mode** that transcribes
  mixed Hindi+English speech into natural Roman-script text (`kya kar rahe ho`),
  not Devanagari and not translated.
- 📝 **Meeting transcription** — continuously transcribe your mic during Zoom/Meet/Teams
  calls into a timestamped text file.
- 🔒 **On-device transcription available** — a bundled [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
  engine runs fully offline, no API key required.
- ⚡ **Best-quality cloud mode (optional)** — add a free [Groq](https://console.groq.com/keys)
  key to use cloud Whisper (`large-v3`) + an LLM cleanup pass for noticeably higher accuracy.
- ✂️ **Phrases** — define text macros ("trigger = expansion") that expand as you speak.
- 🧩 **Chrome extension** — dictate into any website, no install needed beyond the browser.
- 🛡️ **Self-integrity check (macOS)** — the app verifies its own code signature at
  launch and refuses to run if it's been tampered with.

## Platforms

| Platform | Where | Tech |
|---|---|---|
| macOS | [`Sources/WisprClone/`](Sources/WisprClone) | Swift, AppKit |
| Windows | [`windows/`](windows) | Python |
| Browser | [`extension/`](extension) | Manifest V3 JS |

See [STRUCTURE.md](STRUCTURE.md) for exactly which files belong to which platform.

## Quick start

### macOS
```bash
./build_app.sh
open "build/Wispr Clone.app"
```
Requires the Swift toolchain (Xcode Command Line Tools). Grant **Microphone**,
**Speech Recognition**, and **Accessibility** in System Settings → Privacy & Security
on first launch, then relaunch.

For on-device Whisper (no API key), first run:
```bash
./tools/setup_whisper.sh
```

### Windows
```bat
cd windows
pip install -r requirements.txt
python wispr_windows.py
```
See [windows/README.md](windows/README.md) for the standalone `.exe` build and full setup.

### Chrome extension
Load `extension/` as an unpacked extension via `chrome://extensions` (Developer Mode →
Load unpacked). See [extension/README.md](extension/README.md).

## Usage

1. Click into any text field.
2. **Hold the hotkey** (Right ⌥ Option on Mac, Right Ctrl on Windows), speak, release.
3. Your words appear at the cursor.

Open the app window or menu/tray icon to:
- Pick a **language**, including Hinglish (Roman).
- Start/stop **Meeting Transcription** and open the saved transcripts folder.
- Manage **Phrases** (text macros).
- Set a free **Groq API key** for cloud-quality transcription and AI cleanup.

## Transcription engines

| Mode | Engine | Needs a key? | Notes |
|---|---|---|---|
| Default (no key) | Bundled on-device whisper.cpp | No | Fully offline, private |
| With a Groq key | Cloud Whisper `large-v3` | Yes (free) | Best accuracy, especially for Hindi/Hinglish |
| Cleanup pass | Groq-hosted LLM | Yes (free) | Optional grammar fix / Hinglish romanization |

Get a free Groq key at [console.groq.com/keys](https://console.groq.com/keys) — no cost,
used only for transcription/cleanup, never sent anywhere else.

## Contributing

Issues and PRs are welcome. The codebase is intentionally small and readable —
see [STRUCTURE.md](STRUCTURE.md) to find the right file before changing something.

## Acknowledgements

Inspired by [Wispr Flow](https://wisprflow.ai). Not affiliated with it.
[soll](https://github.com/mithun-builds/soll) is a similar local-first macOS-only
dictation app worth checking out.

## License

[MIT](LICENSE)
