// Runs in the offscreen document. Owns the SpeechRecognition engine and streams
// recognized text back to the service worker.

const SR = self.SpeechRecognition || self.webkitSpeechRecognition;
let recognition = null;
let wantRunning = false;

function post(msg) {
  chrome.runtime.sendMessage({ from: "offscreen", ...msg }).catch(() => {});
}

function buildRecognition() {
  const r = new SR();
  r.continuous = true;
  r.interimResults = true;
  r.lang = navigator.language || "en-US";

  r.onresult = (event) => {
    let interim = "";
    for (let i = event.resultIndex; i < event.results.length; i++) {
      const result = event.results[i];
      const text = result[0].transcript;
      if (result.isFinal) {
        post({ type: "result", text: text.trim() + " ", isFinal: true });
      } else {
        interim += text;
      }
    }
    if (interim) post({ type: "result", text: interim, isFinal: false });
  };

  r.onerror = (e) => {
    if (e.error === "no-speech" || e.error === "aborted") return; // benign
    post({ type: "error", error: e.error || "speech error" });
  };

  r.onend = () => {
    // Chrome ends recognition after a pause; tell the worker so it can restart
    // while the user is still holding the session open.
    post({ type: "ended" });
  };

  return r;
}

function start() {
  if (!SR) { post({ type: "error", error: "SpeechRecognition not supported in this browser" }); return; }
  wantRunning = true;
  try {
    if (!recognition) recognition = buildRecognition();
    recognition.start();
  } catch (_) {
    // start() throws if already started — ignore.
  }
}

function stop() {
  wantRunning = false;
  if (recognition) {
    try { recognition.stop(); } catch (_) {}
  }
}

chrome.runtime.onMessage.addListener((msg) => {
  if (msg.target !== "offscreen") return;
  if (msg.type === "start") start();
  else if (msg.type === "stop") stop();
});
