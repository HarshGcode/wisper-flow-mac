const statusEl = document.getElementById("status");

document.getElementById("enable").addEventListener("click", async () => {
  statusEl.textContent = "Requesting microphone…";
  statusEl.className = "status";
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    // We only needed the permission grant; release the mic immediately.
    stream.getTracks().forEach((t) => t.stop());
    statusEl.textContent = "✅ Microphone enabled. You're all set!";
    statusEl.className = "status ok";
  } catch (e) {
    statusEl.textContent = "❌ Microphone blocked. Click the camera/lock icon in the address bar to allow it, then retry.";
    statusEl.className = "status bad";
  }
});

chrome.commands?.getAll?.((cmds) => {
  const c = (cmds || []).find((x) => x.name === "toggle-dictation");
  if (c && c.shortcut) document.getElementById("shortcut").textContent = c.shortcut;
});
