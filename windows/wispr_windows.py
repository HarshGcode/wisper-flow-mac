"""
================================================================================
  WISPR CLONE  —  WINDOWS VERSION   (Python)
  Windows equivalent of the macOS Swift app (../Sources/WisprClone/).
================================================================================

Features (all visible in the window UI + the system tray):
  • Voice typing: HOLD Right Ctrl, speak, release — typed into the focused field.
  • Meeting transcription: continuously transcribe your mic to a saved file.

Speech engine: Google Web Speech (free, needs internet).
Setup + run:  see README.md.
"""

import os
import sys
import threading
import time
import datetime
import traceback


def _log_dir():
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


try:
    import tkinter as tk
    from tkinter import simpledialog, messagebox
    import keyboard
    import pyperclip
    import speech_recognition as sr
    import pystray
    from PIL import Image, ImageDraw
except Exception:
    log("FATAL: a required library failed to import:\n" + traceback.format_exc())
    raise

# ---- Settings ---------------------------------------------------------------
HOTKEY = "right ctrl"

LANG_OPTIONS = [
    ("Hinglish (Roman) — Hindi + English", "hinglish"),
    ("English (US)", "en-US"),
    ("Hindi — हिन्दी", "hi-IN"),
    ("English (India)", "en-IN"),
    ("Spanish", "es-ES"),
    ("French", "fr-FR"),
    ("German", "de-DE"),
    ("Arabic", "ar-SA"),
    ("Mandarin", "zh-CN"),
]
import json
import requests

CONFIG_PATH = os.path.join(_log_dir(), "wispr_config.json")
_config = {}


def load_config():
    global _config
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            _config = json.load(f)
    except Exception:
        _config = {}


def save_config():
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(_config, f)
    except Exception:
        pass


load_config()
current_language = _config.get("language", "en-US")
groq_key = _config.get("groq_key", "") or _config.get("whisper_key", "") or os.environ.get("GROQ_API_KEY", "")


def is_hinglish():
    return current_language == "hinglish"


def save_language(code):
    global current_language
    current_language = code
    _config["language"] = code
    save_config()


def groq_chat(text, system):
    """Post-process text with a Groq-hosted LLM (e.g. romanize Hinglish)."""
    if not groq_key or not text:
        return text
    try:
        resp = requests.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": f"Bearer {groq_key}", "Content-Type": "application/json"},
            json={
                "model": "llama-3.3-70b-versatile",
                "temperature": 0.2,
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": text},
                ],
            },
            timeout=20,
        )
        if resp.status_code == 200:
            return resp.json()["choices"][0]["message"]["content"].strip()
        log(f"Groq chat error {resp.status_code}: {resp.text[:200]}")
    except Exception:
        log("Groq chat error:\n" + traceback.format_exc())
    return text


ROMANIZE_PROMPT = (
    "You clean up a raw voice-dictation transcript. Rules EXACTLY:\n"
    "1. NEVER translate. Keep the SAME language the speaker used — English stays English, "
    "Hindi stays Hindi. Do not convert English to Hindi or Hindi to English.\n"
    "2. If any words are in Devanagari (Hindi script), convert ONLY the script to Roman/Latin "
    "letters without changing the words (e.g. 'क्या कर रहे हो' -> 'kya kar rahe ho').\n"
    "3. Only fix spelling, grammar, spacing and punctuation, and remove fillers (um, uh). Do "
    "NOT add, remove, reword or rephrase the actual content.\n"
    "4. Return ONLY the corrected text, nothing else."
)


def whisper_transcribe(wav_bytes):
    """Hinglish: send recorded audio to Whisper (Groq) — handles Hindi+English."""
    if not groq_key:
        log("Hinglish mode on but no Groq key set")
        return ""
    try:
        resp = requests.post(
            "https://api.groq.com/openai/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {groq_key}"},
            files={"file": ("audio.wav", wav_bytes, "audio/wav")},
            data={"model": "whisper-large-v3", "response_format": "text", "temperature": "0"},
            timeout=30,
        )
        if resp.status_code == 200:
            return resp.text.strip()
        log(f"Whisper error {resp.status_code}: {resp.text[:200]}")
    except Exception:
        log("Whisper request error:\n" + traceback.format_exc())
    return ""
# -----------------------------------------------------------------------------

recognizer = sr.Recognizer()
is_recording = False
meeting_active = False
_meeting_file = None
_status = "Idle"

tray_icon = None
_root = None
_show_requested = False
_quit_requested = False


def set_status(s):
    global _status
    _status = s


def set_tray_active(active):
    if tray_icon is not None:
        try:
            tray_icon.icon = make_icon(active)
        except Exception:
            pass


# ---- Icon -------------------------------------------------------------------
def make_icon(active=False):
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bg = (224, 36, 94) if active else (107, 81, 242)
    d.rounded_rectangle((4, 4, 60, 60), radius=14, fill=bg)
    d.rounded_rectangle((26, 16, 38, 40), radius=6, fill="white")
    d.arc((20, 24, 44, 46), start=0, end=180, fill="white", width=3)
    d.line((32, 46, 32, 52), fill="white", width=3)
    d.line((24, 52, 40, 52), fill="white", width=3)
    return img


# ---- Text insertion ---------------------------------------------------------
def insert_text(text):
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
        pyperclip.copy(previous)
    except Exception:
        pass


# ---- Meeting Mode -----------------------------------------------------------
def transcript_dir():
    d = os.path.join(os.path.expanduser("~"), "Documents", "WisprClone-Transcripts")
    os.makedirs(d, exist_ok=True)
    return d


def append_transcript(text):
    if not _meeting_file:
        return
    try:
        with open(_meeting_file, "a", encoding="utf-8") as f:
            f.write(f"[{datetime.datetime.now():%H:%M}] {text}\n")
    except Exception:
        log("Transcript write error:\n" + traceback.format_exc())


def meeting_loop():
    try:
        with sr.Microphone() as source:
            recognizer.adjust_for_ambient_noise(source, duration=0.5)
            # Allow longer phrases so fast/continuous talkers aren't cut off.
            recognizer.pause_threshold = 1.0
            while meeting_active:
                try:
                    audio = recognizer.listen(source, timeout=5, phrase_time_limit=20)
                except sr.WaitTimeoutError:
                    continue
                except Exception:
                    continue
                if not meeting_active:
                    break
                try:
                    if is_hinglish() and groq_key:
                        text = whisper_transcribe(audio.get_wav_data())
                        if text:
                            text = groq_chat(text, ROMANIZE_PROMPT)
                    else:
                        text = recognizer.recognize_google(audio, language=current_language)
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
        set_tray_active(False)


def start_meeting():
    global meeting_active, _meeting_file
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
    set_status("Meeting: transcribing…")
    set_tray_active(True)
    log(f"Meeting transcription started -> {path}")
    threading.Thread(target=meeting_loop, daemon=True).start()


def stop_meeting():
    global meeting_active
    if not meeting_active:
        return
    meeting_active = False
    set_status("Idle")
    set_tray_active(False)
    log(f"Meeting transcription stopped. Saved: {_meeting_file}")


def open_transcripts():
    try:
        os.startfile(transcript_dir())
    except Exception:
        log("Open folder error:\n" + traceback.format_exc())


# ---- Push-to-talk dictation -------------------------------------------------
def record_and_transcribe():
    global _status
    frames = []
    try:
        log("Opening microphone…")
        with sr.Microphone() as source:
            set_status("Listening…")
            set_tray_active(True)
            while is_recording:
                try:
                    frames.append(source.stream.read(source.CHUNK))
                except Exception:
                    log("Audio read error:\n" + traceback.format_exc())
                    break
            audio = sr.AudioData(b"".join(frames), source.SAMPLE_RATE, source.SAMPLE_WIDTH)
        log(f"Captured {len(frames)} audio chunks")
    except Exception:
        log("Mic error:\n" + traceback.format_exc())
        set_status("Mic error")
        set_tray_active(False)
        return

    set_tray_active(False)
    set_status("Transcribing…")

    if is_hinglish() and groq_key:
        text = whisper_transcribe(audio.get_wav_data())
        log(f"Whisper: {text!r}")
        if text:
            text = groq_chat(text, ROMANIZE_PROMPT)  # -> Roman Hinglish
            log(f"Romanized: {text!r}")
            insert_text(text + " ")
            set_status("Idle")
        else:
            set_status("Didn't catch that")
        return

    try:
        text = recognizer.recognize_google(audio, language=current_language)
        log(f"Recognized: {text!r}")
        insert_text(text + " ")
        set_status("Idle")
    except sr.UnknownValueError:
        set_status("Didn't catch that")
    except Exception:
        log("Transcribe error:\n" + traceback.format_exc())
        set_status("Error")


def on_press(_event):
    global is_recording
    if meeting_active:
        return
    if not is_recording:
        is_recording = True
        threading.Thread(target=record_and_transcribe, daemon=True).start()


def on_release(_event):
    global is_recording
    is_recording = False


# ---- System tray ------------------------------------------------------------
def build_tray():
    return pystray.Icon(
        "wispr_clone",
        make_icon(),
        "Wispr Clone (Windows)",
        menu=pystray.Menu(
            pystray.MenuItem("Show Window", lambda i, item: _request_show()),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem(
                lambda i: "Stop Meeting Transcription" if meeting_active else "Start Meeting Transcription",
                lambda i, item: stop_meeting() if meeting_active else start_meeting(),
            ),
            pystray.MenuItem("Open Transcripts Folder", lambda i, item: open_transcripts()),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit", lambda i, item: _request_quit()),
        ),
    )


def _request_show():
    global _show_requested
    _show_requested = True


def _request_quit():
    global _quit_requested
    _quit_requested = True


# ---- Window UI (tkinter) ----------------------------------------------------
def build_window():
    root = tk.Tk()
    root.title("Wispr Clone")
    root.geometry("440x680")
    root.configure(bg="#0c0f1a")
    root.resizable(False, False)

    PURPLE, BLUE, FG, MUTED, CARD = "#6b51f2", "#458cfb", "#eef1fa", "#9aa3bf", "#141a2e"

    tk.Label(root, text="🎙  Wispr Clone", bg="#0c0f1a", fg=FG,
             font=("Segoe UI", 20, "bold")).pack(anchor="w", padx=24, pady=(22, 2))

    status_var = tk.StringVar(value="● Idle")
    tk.Label(root, textvariable=status_var, bg="#0c0f1a", fg=MUTED,
             font=("Segoe UI", 10)).pack(anchor="w", padx=24)

    def section(title):
        tk.Frame(root, bg="#222a44", height=1).pack(fill="x", padx=24, pady=(16, 10))
        tk.Label(root, text=title, bg="#0c0f1a", fg=FG,
                 font=("Segoe UI", 12, "bold")).pack(anchor="w", padx=24)

    def hint(text):
        tk.Label(root, text=text, bg="#0c0f1a", fg=MUTED, font=("Segoe UI", 9),
                 wraplength=390, justify="left").pack(anchor="w", padx=24, pady=(4, 0))

    section("🎙  Voice Typing")
    hint("Hold the Right Ctrl key in any app, speak, then release — your words are typed where the cursor is.")

    section("📝  Meeting Transcription")
    hint("Transcribe your voice during any meeting (Zoom, Meet, Teams) and save it to a timestamped file.")

    meet_text = tk.StringVar(value="● Start Meeting Transcription")

    def on_meet():
        if meeting_active:
            stop_meeting()
        else:
            start_meeting()

    meet_btn = tk.Button(root, textvariable=meet_text, command=on_meet,
                         bg=PURPLE, fg="white", activebackground=BLUE, activeforeground="white",
                         relief="flat", font=("Segoe UI", 11, "bold"), cursor="hand2",
                         padx=14, pady=8, bd=0)
    meet_btn.pack(fill="x", padx=24, pady=(10, 6))

    tk.Button(root, text="Open Transcripts Folder", command=open_transcripts,
              bg=CARD, fg=FG, activebackground="#1f2740", activeforeground=FG,
              relief="flat", font=("Segoe UI", 10), cursor="hand2", padx=10, pady=6, bd=0
              ).pack(fill="x", padx=24)

    section("⚙  Settings")
    hint("Speech language — pick the language you'll speak in.")

    def on_lang(selected_name):
        for n, c in LANG_OPTIONS:
            if n == selected_name:
                save_language(c)
                log(f"Language set to {c}")
                break

    cur_name = next((n for n, c in LANG_OPTIONS if c == current_language), "English (US)")
    lang_var = tk.StringVar(value=cur_name)
    lang_menu = tk.OptionMenu(root, lang_var, *[n for n, _ in LANG_OPTIONS], command=on_lang)
    lang_menu.configure(bg=CARD, fg=FG, activebackground="#1f2740", activeforeground=FG,
                        relief="flat", highlightthickness=0, font=("Segoe UI", 10), cursor="hand2")
    lang_menu["menu"].configure(bg=CARD, fg=FG)
    lang_menu.pack(fill="x", padx=24, pady=(8, 0))

    tk.Label(root, text="Pick \"Hinglish (Roman)\" above for Hindi+English in Roman letters "
                        "(kya kar rahe ho). Needs the free Groq key below.",
             bg="#0c0f1a", fg=MUTED, font=("Segoe UI", 8), wraplength=390, justify="left"
             ).pack(anchor="w", padx=24, pady=(6, 0))

    def set_key():
        global groq_key
        k = simpledialog.askstring("Groq API Key",
                                   "Paste your free Groq key (console.groq.com/keys):", show="*")
        if k:
            groq_key = k.strip()
            _config["groq_key"] = groq_key
            save_config()
            messagebox.showinfo("Saved", "Groq key saved. Pick 'Hinglish (Roman)' as the language to use it.")

    tk.Button(root, text="Set Groq API Key  (free — console.groq.com/keys)", command=set_key,
              bg=CARD, fg=FG, activebackground="#1f2740", activeforeground=FG,
              relief="flat", font=("Segoe UI", 10), cursor="hand2", padx=10, pady=6, bd=0
              ).pack(fill="x", padx=24, pady=(6, 0))

    tk.Label(root, text="Closing this window keeps Wispr Clone running in the tray.",
             bg="#0c0f1a", fg=MUTED, font=("Segoe UI", 8)).pack(anchor="w", padx=24, pady=(18, 0))

    # Keep UI in sync + handle tray-triggered show/quit (must run on this thread).
    def tick():
        status_var.set(("🔴 " if (meeting_active or is_recording) else "● ") + _status)
        meet_text.set("■ Stop Meeting Transcription" if meeting_active else "● Start Meeting Transcription")
        meet_btn.configure(bg=("#e0245e" if meeting_active else PURPLE))
        global _show_requested
        if _show_requested:
            _show_requested = False
            root.deiconify(); root.lift()
        if _quit_requested:
            _do_quit(root)
            return
        root.after(300, tick)

    root.protocol("WM_DELETE_WINDOW", root.withdraw)  # hide to tray instead of quitting
    root.after(300, tick)
    return root


def _do_quit(root):
    try:
        keyboard.unhook_all()
    except Exception:
        pass
    try:
        if tray_icon is not None:
            tray_icon.stop()
    except Exception:
        pass
    try:
        root.destroy()
    except Exception:
        pass
    os._exit(0)


# ---- Main -------------------------------------------------------------------
def main():
    global tray_icon, _root

    tray_icon = build_tray()
    try:
        tray_icon.run_detached()  # tray in the background; window owns the main thread
    except Exception:
        threading.Thread(target=tray_icon.run, daemon=True).start()

    log("Registering hotkey…")
    keyboard.on_press_key(HOTKEY, on_press, suppress=False)
    keyboard.on_release_key(HOTKEY, on_release, suppress=False)

    log("Window starting — app is ready.")
    _root = build_window()
    _root.mainloop()


if __name__ == "__main__":
    try:
        log("=== Wispr Clone (Windows) starting ===")
        log(f"Hotkey: {HOTKEY}")
        main()
    except Exception:
        log("FATAL on startup:\n" + traceback.format_exc())
        try:
            input("\nAn error occurred (see above and wispr_clone_log.txt). Press Enter to exit…")
        except Exception:
            pass
