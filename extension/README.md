# Wispr Clone — Chrome Extension

Voice typing inside the browser. Click into any text field, press the shortcut,
and speak — your words are typed in. Works in Gmail, X, ChatGPT, search bars, etc.

## Install (load the pre-built extension)

1. Open **`chrome://extensions`** in Chrome (or Edge/Brave).
2. Turn on **Developer mode** (top-right toggle).
3. Click **Load unpacked** and select this **`extension/`** folder.
4. The Wispr Clone icon appears in your toolbar.

## Use

1. **If you have tabs already open, reload them once** so the extension attaches.
2. Click into any text box on a web page.
3. Press **⌘⇧Y** (Mac) / **Ctrl+Shift+Y** (Win/Linux), or click the toolbar icon → **Start**.
4. **The first time on each website**, Chrome asks for the microphone — click **Allow**.
5. Speak. Press again to stop.

Change the shortcut at `chrome://extensions/shortcuts`.

## How it works

- A keyboard command (or the popup) toggles dictation.
- The background worker injects `content.js` into the active tab (so it works even
  on tabs opened before the extension was loaded), then sends a toggle.
- The content script runs the browser's `webkitSpeechRecognition` **in the page**
  and inserts recognized text into the focused `input` / `textarea` /
  `contenteditable` element. Chrome asks for the mic once per website.

## Note on privacy

In-browser dictation uses the browser's built-in Web Speech engine (Google), so
audio is processed in the cloud. For fully **on-device, private** dictation, use
the **Wispr Clone Mac app** in the parent folder.

## Publishing to the Chrome Web Store (optional)

To let anyone install it with one click (instead of "Load unpacked"):
1. Pay the one-time **$5** Chrome Web Store developer fee.
2. Zip this `extension/` folder and upload it at
   <https://chrome.google.com/webstore/devconsole>.
3. Submit for review.
