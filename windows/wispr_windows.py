"""
================================================================================
  WISPR CLONE  —  WINDOWS VERSION   (Python)
  This file runs ONLY on Windows. It is the Windows equivalent of the macOS
  Swift app in ../Sources/WisprClone/.  (Do NOT use this on a Mac.)
================================================================================

What it does (same idea as the Mac app):
  • Lives in the system tray (bottom-right, near the clock).
  • Push-to-talk: HOLD the Right Ctrl key, speak, then release.
  • Your speech is transcribed and typed into whatever text field is focused.

Speech engine: Google Web Speech (free, needs internet) — same as the browser
extension. (The Mac app uses Apple's on-device engine.)

Setup + run:  see README.md in this folder.
"""

import threading
import time

import keyboard          # global hotkey
import pyperclip         # clipboard (for pasting text)
import speech_recognition as sr
import pystray
from PIL import Image, ImageDraw

# ---- Settings ---------------------------------------------------------------
# Push-to-talk key. Hold it to dictate. Change this if you prefer another key
# (e.g. "right alt", "right shift", "scroll lock").
HOTKEY = "right ctrl"
LANGUAGE = "en-US"
# -----------------------------------------------------------------------------

recognizer = sr.Recognizer()
is_recording = False
_status = "Idle"


def make_icon(active=False):
    """Draw a simple microphone tray icon (purple, red when recording)."""
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bg = (224, 36, 94) if active else (107, 81, 242)
    d.rounded_rectangle((4, 4, 60, 60), radius=14, fill=bg)
    # mic body
    d.rounded_rectangle((26, 16, 38, 40), radius=6, fill="white")
    # stand
    d.arc((20, 24, 44, 46), start=0, end=180, fill="white", width=3)
    d.line((32, 46, 32, 52), fill="white", width=3)
    d.line((24, 52, 40, 52), fill="white", width=3)
    return img


def insert_text(text):
    """Paste `text` into the currently focused field via the clipboard."""
    if not text:
        return
    try:
        previous = pyperclip.paste()
    except Exception:
        previous = ""
    pyperclip.copy(text)
    time.sleep(0.05)
    keyboard.send("ctrl+v")
    time.sleep(0.15)
    try:
        pyperclip.copy(previous)  # restore the user's old clipboard
    except Exception:
        pass


def record_and_transcribe(icon):
    """Record from the mic while the hotkey is held, then transcribe + type."""
    global _status
    frames = []
    try:
        with sr.Microphone() as source:
            _status = "Listening…"
            icon.icon = make_icon(active=True)
            while is_recording:
                try:
                    frames.append(source.stream.read(source.CHUNK, exception_on_overflow=False))
                except Exception:
                    break
            audio = sr.AudioData(b"".join(frames), source.SAMPLE_RATE, source.SAMPLE_WIDTH)
    except Exception as e:
        _status = f"Mic error: {e}"
        icon.icon = make_icon(active=False)
        return

    icon.icon = make_icon(active=False)
    _status = "Transcribing…"
    try:
        text = recognizer.recognize_google(audio, language=LANGUAGE)
        insert_text(text + " ")
        _status = "Idle"
    except sr.UnknownValueError:
        _status = "Didn't catch that"
    except sr.RequestError as e:
        _status = f"Network/API error: {e}"
    except Exception as e:
        _status = f"Error: {e}"


def on_press(icon):
    def handler(_event):
        global is_recording
        if not is_recording:
            is_recording = True
            threading.Thread(target=record_and_transcribe, args=(icon,), daemon=True).start()
    return handler


def on_release(_event):
    global is_recording
    is_recording = False


def main():
    icon = pystray.Icon(
        "wispr_clone",
        make_icon(),
        "Wispr Clone (Windows) — hold Right Ctrl to dictate",
        menu=pystray.Menu(
            pystray.MenuItem(lambda i: f"Status: {_status}", None, enabled=False),
            pystray.MenuItem(f"Hold {HOTKEY.title()} to dictate", None, enabled=False),
            pystray.MenuItem("Quit", lambda i, item: (keyboard.unhook_all(), i.stop())),
        ),
    )

    # Register the push-to-talk hotkey.
    keyboard.on_press_key(HOTKEY, on_press(icon), suppress=False)
    keyboard.on_release_key(HOTKEY, on_release, suppress=False)

    icon.run()


if __name__ == "__main__":
    main()
