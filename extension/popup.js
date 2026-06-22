const btn = document.getElementById("toggle");
const err = document.getElementById("err");

function render(recording) {
  btn.textContent = recording ? "⏹ Stop dictation" : "🎙️ Start dictation";
  btn.classList.toggle("rec", recording);
}

chrome.runtime.sendMessage({ type: "getState" }, (res) => {
  if (res) render(res.recording);
});

btn.addEventListener("click", () => {
  chrome.runtime.sendMessage({ type: "toggle" });
  // Optimistically flip, then close so dictation targets the page, not the popup.
  setTimeout(() => window.close(), 120);
});

document.getElementById("setup").addEventListener("click", (e) => {
  e.preventDefault();
  chrome.runtime.openOptionsPage();
});

// Show the user's actual configured shortcut, if available.
chrome.commands?.getAll?.((cmds) => {
  const c = (cmds || []).find((x) => x.name === "toggle-dictation");
  if (c && c.shortcut) document.getElementById("shortcut").textContent = c.shortcut;
});

// Surface recognition errors pushed from the background.
chrome.runtime.onMessage.addListener((msg) => {
  if (msg.type === "state") {
    render(msg.recording);
    if (msg.error) { err.style.display = "block"; err.textContent = "⚠️ " + msg.error; }
  }
});
