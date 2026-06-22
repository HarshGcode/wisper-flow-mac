// Service worker: orchestrates dictation.
// - Listens for the keyboard command and popup messages to toggle dictation.
// - Runs speech recognition in an offscreen document (stable extension origin so
//   the microphone permission is granted once, not per-website).
// - Relays recognized text to the content script in the tab that was active when
//   dictation started, which inserts it into the focused field.

let recording = false;
let targetTabId = null;

const OFFSCREEN_PATH = "offscreen.html";

async function ensureOffscreen() {
  const has = await chrome.offscreen.hasDocument?.();
  if (has) return;
  await chrome.offscreen.createDocument({
    url: OFFSCREEN_PATH,
    reasons: ["USER_MEDIA"],
    justification: "Run on-page speech recognition for voice dictation."
  });
}

function setBadge(on) {
  chrome.action.setBadgeText({ text: on ? "●" : "" });
  chrome.action.setBadgeBackgroundColor({ color: "#e0245e" });
}

async function startDictation() {
  if (recording) return;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !tab.id || (tab.url && tab.url.startsWith("chrome"))) {
    // Can't inject into chrome:// pages or the Web Store.
    notifyState(false, "Open a normal web page first (dictation can't run on chrome:// pages).");
    return;
  }
  targetTabId = tab.id;
  await ensureOffscreen();
  recording = true;
  setBadge(true);
  chrome.runtime.sendMessage({ target: "offscreen", type: "start" });
  sendToTab(targetTabId, { type: "status", recording: true });
}

function stopDictation() {
  if (!recording) return;
  recording = false;
  setBadge(false);
  chrome.runtime.sendMessage({ target: "offscreen", type: "stop" });
  if (targetTabId != null) sendToTab(targetTabId, { type: "status", recording: false });
}

function toggleDictation() {
  recording ? stopDictation() : startDictation();
}

function sendToTab(tabId, msg) {
  chrome.tabs.sendMessage(tabId, msg).catch(() => {});
}

function notifyState(isRecording, error) {
  chrome.runtime.sendMessage({ type: "state", recording: isRecording, error }).catch(() => {});
}

// Keyboard shortcut.
chrome.commands.onCommand.addListener((command) => {
  if (command === "toggle-dictation") toggleDictation();
});

// Messages from popup and offscreen.
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === "toggle") { toggleDictation(); return; }
  if (msg.type === "getState") { sendResponse({ recording }); return true; }

  // From offscreen recognizer:
  if (msg.from === "offscreen") {
    if (msg.type === "result" && targetTabId != null) {
      sendToTab(targetTabId, { type: "insert", text: msg.text, isFinal: msg.isFinal });
    } else if (msg.type === "error") {
      recording = false;
      setBadge(false);
      if (targetTabId != null) sendToTab(targetTabId, { type: "status", recording: false });
      notifyState(false, msg.error);
    } else if (msg.type === "ended") {
      // Recognition stopped on its own; restart if user still wants to record.
      if (recording) chrome.runtime.sendMessage({ target: "offscreen", type: "start" });
    }
  }
});
