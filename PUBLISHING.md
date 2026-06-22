# Publishing Wispr Clone to the public

This gets your app to the point where **anyone can download it from a website
and open it with no scary warnings** — like downloading WhatsApp.

There are 5 steps. Steps 1–2 are one-time setup; 3–5 you repeat for each release.

---

## Step 1 — Enroll in the Apple Developer Program (one-time, $99/year)

This is the part only you can do, and it's required: without it, macOS blocks
your app for everyone who downloads it.

1. Go to <https://developer.apple.com/programs/> and enroll ($99/yr).
2. After approval, create a **Developer ID Application** certificate:
   - Easiest: open Xcode ▸ Settings ▸ Accounts ▸ (your Apple ID) ▸ Manage Certificates ▸ **+** ▸ *Developer ID Application*.
   - Or at <https://developer.apple.com/account/resources/certificates>.
3. Create an **app-specific password** for notarization at
   <https://account.apple.com> ▸ Sign-In and Security ▸ App-Specific Passwords.

## Step 2 — Fill in your credentials (one-time)

```bash
cp release.config.example release.config
```

Open `release.config` and fill in the 4 values (signing identity, Team ID,
Apple ID, app-specific password). Find your signing identity with:

```bash
security find-identity -v -p codesigning
```

`release.config` is gitignored — your secrets never get committed.

## Step 3 — Build the notarized installer

```bash
./release.sh
```

This builds the app, signs it with your Developer ID, packages it into
`build/Wispr Clone.dmg`, uploads it to Apple for notarization, waits for
approval, and staples the ticket. The result is a `.dmg` anyone can open cleanly.

## Step 4 — Host the .dmg (free, via GitHub Releases)

1. Create a GitHub repo and push this project (`git init`, commit, push).
2. On GitHub: **Releases ▸ Draft a new release**, tag it `v1.0`.
3. Drag `build/Wispr Clone.dmg` into the release assets, publish.
4. Your permanent download URL will be:
   ```
   https://github.com/USER/REPO/releases/latest/download/Wispr.Clone.dmg
   ```
   (GitHub replaces spaces in the filename with dots.)

## Step 5 — Point the website at the download & deploy it

1. In `site/index.html`, near the bottom, set:
   ```js
   var DOWNLOAD_URL = "https://github.com/USER/REPO/releases/latest/download/Wispr.Clone.dmg";
   ```
2. Deploy the `site/` folder — any static host works. Free options:
   - **Vercel** / **Netlify**: drag-and-drop the `site/` folder, or connect the repo.
   - **GitHub Pages**: serve the `site/` folder from the repo.

That's it — share the website link and people can download and run your app.

---

### Future updates

When you change the app, bump `CFBundleShortVersionString` in `Info.plist`,
re-run `./release.sh`, and upload the new `.dmg` to a new GitHub Release.
The website's `latest/download` link automatically points to the newest one.
