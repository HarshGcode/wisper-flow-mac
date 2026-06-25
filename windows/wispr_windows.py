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

import os
import sys
import threading
import time
import datetime
import traceback


# ---- Logging (so errors are visible even in the no-console .exe) -------------
def _log_dir():
    # Next to the .exe when frozen, else next to this script.
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))


LOG_PATH = os.path.join(_log_dir(), "wispr_clone_log.txt")


def log(msg):
    line = f"[{datetime.datetime.now():%H:%M:%S}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG_PATH, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


# Import third-party libs with clear errors if something is missing/broken.
try:
    import keyboard          # global hotkey
    import pyperclip         # clipboard (for pasting text)
    import speech_recognition as sr
    import pystray
    from PIL import Image, ImageDraw
except Exception:
    log("FATAL: a required library failed to import:\n" + traceback.format_exc())
    raise

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


# ---- Meeting Mode: continuously transcribe your mic to a saved file ----------
meeting_active = False
_meeting_file = None


def transcript_dir():
    d = os.path.join(os.path.expanduser("~"), "Documents", "WisprClone-Transcripts")
    os.makedirs(d, exist_ok=True)
    return d


def append_transcript(text):
    if not _meeting_file:
        return
    line = f"[{datetime.datetime.now():%H:%M}] {text}\n"
    try:
        with open(_meeting_file, "a", encoding="utf-8") as f:
            f.write(line)
    except Exception:
        log("Transcript write error:\n" + traceback.format_exc())


def meeting_loop(icon):
    """While a meeting is active, keep listening and append finalized phrases."""
    try:
        with sr.Microphone() as source:
            recognizer.adjust_for_ambient_noise(source, duration=0.5)
            while meeting_active:
                try:
                    audio = recognizer.listen(source, timeout=5, phrase_time_limit=15)
                except sr.WaitTimeoutError:
                    continue  # no speech in the last few seconds — re-check state
                except Exception:
                    continue
                if not meeting_active:
                    break
                try:
                    text = recognizer.recognize_google(audio, language=LANGUAGE)
                    if text:
                        append_transcript(text)
                        log(f"[meeting] {text!r}")
                except sr.UnknownValueError:
                    pass
                except Exception:
                    log("Meeting transcribe error:\n" + traceback.format_exc())
    except Exception:
        log("Meeting mic error:\n" + traceback.format_exc())
    finally:
        icon.icon = make_icon(active=False)


def start_meeting(icon):
    global meeting_active, _meeting_file, _status
    if meeting_active:
        return
    path = os.path.join(transcript_dir(), f"Meeting-{datetime.datetime.now():%Y-%m-%d-%H%M}.txt")
    _meeting_file = path
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(f"Meeting transcript — {datetime.datetime.now():%Y-%m-%d %H:%M}\n")
            f.write("=" * 50 + "\n\n")
    except Exception:
        log("Could not create transcript file:\n" + traceback.format_exc())
        return
    meeting_active = True
    _status = "Meeting: transcribing…"
    log(f"Meeting transcription started -> {path}")
    icon.icon = make_icon(active=True)
    icon.update_menu()
    threading.Thread(target=meeting_loop, args=(icon,), daemon=True).start()


def stop_meeting(icon):
    global meeting_active, _status
    if not meeting_active:
        return
    meeting_active = False
    _status = "Idle"
    log(f"Meeting transcription stopped. Saved: {_meeting_file}")
    icon.icon = make_icon(active=False)
    icon.update_menu()


def record_and_transcribe(icon):
    """Record from the mic while the hotkey is held, then transcribe + type."""
    global _status
    frames = []
    try:
        log("Opening microphone…")
        with sr.Microphone() as source:
            _status = "Listening…"
            icon.icon = make_icon(active=True)
            while is_recording:
                try:
                    # NOTE: SpeechRecognition's MicrophoneStream.read takes only the
                    # chunk size (it passes exception_on_overflow=False internally).
                    frames.append(source.stream.read(source.CHUNK))
                except Exception:
                    log("Audio read error:\n" + traceback.format_exc())
                    break
            audio = sr.AudioData(b"".join(frames), source.SAMPLE_RATE, source.SAMPLE_WIDTH)
        log(f"Captured {len(frames)} audio chunks")
    except Exception as e:
        log("Mic error:\n" + traceback.format_exc())
        _status = f"Mic error: {e}"
        icon.icon = make_icon(active=False)
        return

    icon.icon = make_icon(active=False)
    _status = "Transcribing…"
    try:
        text = recognizer.recognize_google(audio, language=LANGUAGE)
        log(f"Recognized: {text!r}")
        insert_text(text + " ")
        _status = "Idle"
    except sr.UnknownValueError:
        log("No speech recognized")
        _status = "Didn't catch that"
    except sr.RequestError as e:
        log("Network/API error:\n" + traceback.format_exc())
        _status = f"Network/API error: {e}"
    except Exception as e:
        log("Transcribe error:\n" + traceback.format_exc())
        _status = f"Error: {e}"


def on_press(icon):
    def handler(_event):
        global is_recording
        if meeting_active:
            return  # don't push-to-talk while a meeting is being transcribed
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
            pystray.Menu.SEPARATOR,
            pystray.MenuItem(
                lambda i: "■  Stop Meeting Transcription" if meeting_active else "●  Start Meeting Transcription",
                lambda i, item: stop_meeting(i) if meeting_active else start_meeting(i),
            ),
            pystray.MenuItem("Open Transcripts Folder", lambda i, item: os.startfile(transcript_dir())),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit", lambda i, item: (keyboard.unhook_all(), i.stop())),
        ),
    )

    # Register the push-to-talk hotkey.
    log("Registering hotkey…")
    keyboard.on_press_key(HOTKEY, on_press(icon), suppress=False)
    keyboard.on_release_key(HOTKEY, on_release, suppress=False)

    log("Tray icon starting — app is ready. Hold the hotkey to dictate.")
    icon.run()


if __name__ == "__main__":
    try:
        log("=== Wispr Clone (Windows) starting ===")
        log(f"Hotkey: {HOTKEY}")
        main()
    except Exception:
        log("FATAL on startup:\n" + traceback.format_exc())
        # Keep a console window open so the user can read the error.
        try:
            input("\nAn error occurred (see above and wispr_clone_log.txt). Press Enter to exit…")
        except Exception:
            pass
