# Project structure — which file is for which platform

This project has **two separate apps** (macOS + Windows) plus a shared browser
extension and website. Use this table to know exactly what each file/folder is
for, so you can safely modify or delete the right ones.

## 🍎 macOS app (Swift) — runs only on Mac
| Path | What it is |
|------|------------|
| `Sources/WisprClone/` | All the Mac app source code (Swift) |
| `Sources/WisprClone/main.swift` | App entry point |
| `Sources/WisprClone/AppDelegate.swift` | Main controller, menu bar, recording flow |
| `Sources/WisprClone/HotkeyManager.swift` | Right ⌥ Option hotkey detection |
| `Sources/WisprClone/SpeechService.swift` | On-device speech → text (Apple) |
| `Sources/WisprClone/Cleanup.swift` | Optional Claude AI cleanup |
| `Sources/WisprClone/TextInserter.swift` | Pastes text into the focused app |
| `Sources/WisprClone/Settings.swift` | Saved settings |
| `Sources/WisprClone/IntegrityGuard.swift` | Self-tamper detection |
| `Package.swift` | Swift build config |
| `Info.plist` | Mac app metadata |
| `WisprClone.entitlements` | Mac permissions (mic, etc.) |
| `build_app.sh` | Builds the Mac `.app` |
| `release.sh`, `release.config.example` | Sign + notarize + `.dmg` (Mac distribution) |
| `tools/` | Mac app icon generation |
| `build/` | Built Mac app output (not committed) |

## 🪟 Windows app (Python) — runs only on Windows
| Path | What it is |
|------|------------|
| `windows/` | **Everything for Windows lives here** |
| `windows/wispr_windows.py` | The whole Windows app (tray, hotkey, speech, paste) |
| `windows/requirements.txt` | Python dependencies |
| `windows/run_wispr.bat` | Double-click launcher |
| `windows/README.md` | Windows setup + usage |

## 🌐 Shared (both platforms)
| Path | What it is |
|------|------------|
| `extension/` | Chrome extension — works on **Mac AND Windows** browsers |
| `site/` | The download website (`index.html`) |
| `vercel.json` | Website hosting config |
| `README.md`, `PUBLISHING.md` | Docs |

---

## ✅ Quick rules for the future
- Want to change the **Mac app**? → edit files in **`Sources/WisprClone/`**
- Want to change the **Windows app**? → edit **`windows/wispr_windows.py`**
- Want to change the **browser extension**? → edit **`extension/`**
- Deleting the Windows app entirely? → just delete the **`windows/`** folder (Mac app is untouched)
- Deleting the Mac app entirely? → delete `Sources/`, `Package.swift`, `Info.plist`, `WisprClone.entitlements`, `build_app.sh`, `release*.{sh,config.example}`, `tools/`, `build/` (Windows app is untouched)

Every Windows file also has a comment header saying it's the **Windows version**,
so it's clear even without this table.
