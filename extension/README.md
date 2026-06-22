# Wispr Clone — Chrome Extension

Voice typing inside the browser. Click into any text field, press the shortcut,
and speak — your words are typed in. Works in Gmail, X, ChatGPT, search bars, etc.

## Install (load the pre-built extension)

1. Open **`chrome://extensions`** in Chrome (or Edge/Brave).
2. Turn on **Developer mode** (top-right toggle).
3. Click **Load unpacked** and select this **`extension/`** folder.
4. The Wispr Clone icon appears in your toolbar.

## First-time setup

1. Click the toolbar icon → **Enable microphone →** (opens the setup page).
2. Click **Enable microphone** and choose **Allow**. (One time only.)

## Use

1. Click into any text box on a web page.
2. Press **⌘⇧Y** (Mac) / **Ctrl+Shift+Y** (Win/Linux), or click the toolbar icon → **Start**.
3. Speak. Press again to stop.

Change the shortcut at `chrome://extensions/shortcuts`.

## How it works

- A keyboard command (or the popup) toggles dictation.
- Speech recognition runs in an **offscreen document** (stable extension origin →
  microphone permission is granted once, not per-site).
- Recognized text is relayed to the active tab's content script, which inserts it
  into the focused `input` / `textarea` / `contenteditable` element.

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
