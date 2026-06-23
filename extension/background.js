// Service worker: forwards the toggle (keyboard command or popup) to the active
// tab's content script, which owns speech recognition + text insertion.
//
// Key robustness fix: we PROGRAMMATICALLY INJECT content.js before toggling, so
// dictation works even on tabs that were already open before the extension was
// loaded (the classic "nothing happens" cause).

let recording = false;

function setBadge(on) {
  chrome.action.setBadgeText({ text: on ? "●" : "" });
  chrome.action.setBadgeBackgroundColor({ color: "#e0245e" });
}

function isRestricted(url) {
  if (!url) return true;
  return /^(chrome|edge|brave|about|view-source|chrome-extension):/i.test(url) ||
         url.startsWith("https://chrome.google.com/webstore") ||
         url.startsWith("https://chromewebstore.google.com");
}

async function toggle() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !tab.id || isRestricted(tab.url)) {
    notify(false, "Open a normal web page first — dictation can't run on chrome:// or the Web Store.");
    return;
  }
  // Make sure the content script is present (no-op if already injected).
  try {
    await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ["content.js"] });
  } catch (_) { /* some pages block injection; sendMessage below will just fail quietly */ }

  chrome.tabs.sendMessage(tab.id, { type: "toggle" }).catch(() => {
    notify(false, "Couldn't start on this page. Try reloading the tab.");
  });
}

function notify(isRecording, error) {
  chrome.runtime.sendMessage({ type: "state", recording: isRecording, error }).catch(() => {});
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === "toggle-from-popup") { toggle(); return; }
  if (msg.type === "getState") { sendResponse({ recording }); return true; }
  if (msg.type === "recording-state") {
    recording = msg.on;
    setBadge(msg.on);
    notify(msg.on, msg.error);
  }
});
