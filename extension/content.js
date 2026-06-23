// Runs in the page. Owns the whole dictation loop: speech recognition (via the
// page's webkitSpeechRecognition — reliable here, unlike an offscreen doc), text
// insertion into the focused field, and the floating "listening" pill.

(() => {
  if (window.__wisprCloneInjected) return;
  window.__wisprCloneInjected = true;

  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  let recognition = null;
  let recording = false;
  let lastEditable = null;

  document.addEventListener("focusin", (e) => {
    if (isEditable(e.target)) lastEditable = e.target;
  }, true);

  // --- editable detection + insertion --------------------------------------

  function isEditable(el) {
    if (!el) return false;
    const tag = el.tagName;
    if (tag === "TEXTAREA") return true;
    if (tag === "INPUT") {
      const t = (el.type || "text").toLowerCase();
      return ["text", "search", "url", "email", "tel", "password", "number", ""].includes(t);
    }
    return el.isContentEditable === true;
  }

  function targetEl() {
    const a = document.activeElement;
    if (isEditable(a)) return a;
    if (lastEditable && document.contains(lastEditable)) return lastEditable;
    return null;
  }

  function insertText(text) {
    const el = targetEl();
    if (!el) { flashPill("Click into a text field first"); return; }
    el.focus();
    if (el.tagName === "INPUT" || el.tagName === "TEXTAREA") {
      const start = el.selectionStart ?? el.value.length;
      const end = el.selectionEnd ?? el.value.length;
      el.setRangeText(text, start, end, "end");
      el.dispatchEvent(new Event("input", { bubbles: true }));
    } else {
      const ok = document.execCommand("insertText", false, text);
      if (!ok) {
        const sel = window.getSelection();
        if (sel && sel.rangeCount) {
          const range = sel.getRangeAt(0);
          range.deleteContents();
          range.insertNode(document.createTextNode(text));
          range.collapse(false);
        }
      }
      el.dispatchEvent(new Event("input", { bubbles: true }));
    }
  }

  // --- recognition ----------------------------------------------------------

  function startRec() {
    if (!SR) { flashPill("This browser has no speech recognition"); return; }
    try {
      recognition = new SR();
    } catch (_) { flashPill("Couldn't start speech recognition"); return; }

    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = navigator.language || "en-US";

    recognition.onresult = (event) => {
      let interim = "";
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const r = event.results[i];
        if (r.isFinal) insertText(r[0].transcript.trim() + " ");
        else interim += r[0].transcript;
      }
      setInterim(interim);
    };

    recognition.onerror = (e) => {
      if (e.error === "no-speech" || e.error === "aborted") return;
      if (e.error === "not-allowed" || e.error === "service-not-allowed") {
        flashPill("Allow the microphone for this site, then try again");
      } else if (e.error === "network") {
        flashPill("Network error — speech needs an internet connection");
      } else {
        flashPill("Mic error: " + e.error);
      }
      stopRec();
    };

    recognition.onend = () => {
      // Chrome stops after a pause; restart while the user keeps the session open.
      if (recording) { try { recognition.start(); } catch (_) {} }
    };

    try {
      recognition.start();
      recording = true;
      showPill(true);
      report(true);
    } catch (_) { /* start() throws if already running */ }
  }

  function stopRec() {
    recording = false;
    showPill(false);
    report(false);
    if (recognition) { try { recognition.stop(); } catch (_) {} }
    recognition = null;
  }

  function toggle() { recording ? stopRec() : startRec(); }

  function report(on, error) {
    chrome.runtime.sendMessage({ type: "recording-state", on, error }).catch(() => {});
  }

  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (msg.type === "toggle") { toggle(); sendResponse?.({ recording }); }
    else if (msg.type === "getLocalState") { sendResponse?.({ recording }); }
    return true;
  });

  // --- floating pill UI -----------------------------------------------------

  let pill = null, interimSpan = null, flashTimer = null;

  function ensurePill() {
    if (pill) return;
    pill = document.createElement("div");
    pill.setAttribute("data-wispr-clone", "");
    Object.assign(pill.style, {
      position: "fixed", bottom: "24px", left: "50%", transform: "translateX(-50%)",
      zIndex: "2147483647", display: "none", alignItems: "center", gap: "10px",
      maxWidth: "70vw", padding: "10px 16px", borderRadius: "999px",
      background: "rgba(20,22,38,0.96)", color: "#fff",
      font: "14px -apple-system,system-ui,sans-serif",
      boxShadow: "0 8px 30px rgba(0,0,0,0.35)", pointerEvents: "none"
    });
    const dot = document.createElement("span");
    Object.assign(dot.style, {
      width: "10px", height: "10px", borderRadius: "50%", background: "#e0245e",
      animation: "wisprPulse 1.2s infinite"
    });
    const label = document.createElement("span");
    label.textContent = "Listening…"; label.style.fontWeight = "600";
    interimSpan = document.createElement("span");
    Object.assign(interimSpan.style, { opacity: "0.75", whiteSpace: "nowrap",
      overflow: "hidden", textOverflow: "ellipsis", maxWidth: "50vw" });
    const style = document.createElement("style");
    style.textContent = "@keyframes wisprPulse{0%{box-shadow:0 0 0 0 rgba(224,36,94,.7)}70%{box-shadow:0 0 0 10px rgba(224,36,94,0)}100%{box-shadow:0 0 0 0 rgba(224,36,94,0)}}";
    pill.append(dot, label, interimSpan);
    (document.body || document.documentElement).append(style, pill);
  }

  function showPill(on) {
    ensurePill();
    pill.style.display = on ? "flex" : "none";
    if (!on) interimSpan.textContent = "";
  }
  function setInterim(text) { ensurePill(); interimSpan.textContent = text || ""; }
  function flashPill(text) {
    ensurePill();
    pill.style.display = "flex";
    interimSpan.textContent = text;
    clearTimeout(flashTimer);
    flashTimer = setTimeout(() => { if (!recording) { interimSpan.textContent = ""; pill.style.display = "none"; } }, 2800);
  }
})();
