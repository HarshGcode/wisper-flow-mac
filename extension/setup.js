// Show the user's actual configured shortcut, if available.
chrome.commands?.getAll?.((cmds) => {
  const c = (cmds || []).find((x) => x.name === "toggle-dictation");
  if (c && c.shortcut) document.getElementById("shortcut").textContent = c.shortcut;
});
