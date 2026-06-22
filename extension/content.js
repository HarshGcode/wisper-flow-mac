// Runs in every page. Inserts recognized text into the focused editable element
// and shows a small floating "listening" pill.

(() => {
  if (window.__wisprCloneInjected) return;
  window.__wisprCloneInjected = true;

  let lastEditable = null;

  // Remember the last editable element the user focused, so dictation still
  // targets it even if focus shifts slightly.
  document.addEventListener("focusin", (e) => {
    if (isEditable(e.target)) lastEditable = e.target;
  }, true);

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
      // contenteditable
      const ok = document.execCommand("insertText", false, text);
      if (!ok) {
        const sel = window.getSelection();
        if (sel && sel.rangeCount) {
          const range = sel.getRangeAt(0);
          range.deleteContents();
          range.insertNode(document.createTextNode(text));
          range.collapse(false);
        }
        el.dispatchEvent(new Event("input", { bubbles: true }));
      }
    }
  }

  // --- Floating pill UI -----------------------------------------------------

  let pill = null;
  let interimSpan = null;

  function ensurePill() {
    if (pill) return;
    pill = document.createElement("div");
    pill.setAttribute("data-wispr-clone", "");
    Object.assign(pill.style, {
      position: "fixed", bottom: "24px", left: "50%", transform: "translateX(-50%)",
      zIndex: "2147483647", display: "none", alignItems: "center", gap: "10px",
      maxWidth: "70vw", padding: "10px 16px", borderRadius: "999px",
      background: "rgba(20,22,38,0.96)", color: "#fff", font: "14px -apple-system,system-ui,sans-serif",
      boxShadow: "0 8px 30px rgba(0,0,0,0.35)", pointerEvents: "none",
      backdropFilter: "blur(8px)"
    });
    const dot = document.createElement("span");
    Object.assign(dot.style, {
      width: "10px", height: "10px", borderRadius: "50%", background: "#e0245e",
      boxShadow: "0 0 0 0 rgba(224,36,94,0.7)", animation: "wisprPulse 1.2s infinite"
    });
    const label = document.createElement("span");
    label.textContent = "Listening…";
    label.style.fontWeight = "600";
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
    if (!on && interimSpan) interimSpan.textContent = "";
  }

  let flashTimer = null;
  function flashPill(text) {
    ensurePill();
    pill.style.display = "flex";
    interimSpan.textContent = text;
    clearTimeout(flashTimer);
    flashTimer = setTimeout(() => { if (interimSpan) interimSpan.textContent = ""; pill.style.display = "none"; }, 2500);
  }

  chrome.runtime.onMessage.addListener((msg) => {
    if (msg.type === "status") {
      showPill(msg.recording);
    } else if (msg.type === "insert") {
      if (msg.isFinal) {
        if (interimSpan) interimSpan.textContent = "";
        insertText(msg.text);
      } else if (interimSpan) {
        interimSpan.textContent = msg.text;
      }
    }
  });
})();
