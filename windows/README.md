# Wispr Clone — Windows version (Python)

The **Windows** equivalent of the macOS app. Lives in the system tray; hold a key
and speak, and your words are typed into any text field.

> This folder is **Windows only**. The macOS app is the Swift code in
> [`../Sources/WisprClone/`](../Sources/WisprClone). See [`../STRUCTURE.md`](../STRUCTURE.md)
> for which files belong to which platform.

## Requirements
- A **Windows PC** (10 or 11)
- **Python 3.9+** — install from <https://www.python.org/downloads/> (tick *"Add Python to PATH"*)
- An internet connection (speech uses Google's free web engine)

## Setup (one time)
Open **Command Prompt** in this folder and run:
```bat
pip install -r requirements.txt
```
> If `pyaudio` fails to install, run: `pip install pipwin` then `pipwin install pyaudio`.

## Run
Double-click **`run_wispr.bat`**, or from Command Prompt:
```bat
python wispr_windows.py
```
A 🎙️ icon appears in the system tray (bottom-right).

## Use
1. Click into any text field (Notepad, browser, Word, chat…).
2. **Hold the Right Ctrl key**, speak, then **release**.
3. Your words get typed in. The tray icon turns **red** while listening.

To quit: right-click the tray icon → **Quit**.

## Change the hotkey
Open `wispr_windows.py` and edit the `HOTKEY` line near the top
(e.g. `"right alt"`, `"right shift"`, `"scroll lock"`).

## Make a standalone .exe (optional)
So users don't need Python installed:
```bat
pip install pyinstaller
pyinstaller --onefile --noconsole --name "WisprClone" wispr_windows.py
```
The `.exe` appears in the `dist\` folder.

## Notes
- Speech is processed by **Google's web engine** (cloud), like the browser extension.
  The macOS app is the fully on-device, private one.
- If the hotkey doesn't work, try running the Command Prompt **as Administrator**.
