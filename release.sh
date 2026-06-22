#!/bin/bash
# Full public-release pipeline for Wispr Clone:
#   build → sign with Developer ID → create .dmg → notarize → staple → verify
#
# Produces a notarized "Wispr Clone.dmg" that anyone can download and open
# without Gatekeeper warnings.
#
# Prereqs: enroll in Apple Developer Program, then fill in release.config
# (see release.config.example).
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f release.config ]; then
    echo "❌ release.config not found."
    echo "   Copy release.config.example to release.config and fill in your Apple credentials."
    exit 1
fi
# shellcheck disable=SC1091
source release.config

: "${SIGN_IDENTITY:?Set SIGN_IDENTITY in release.config}"
: "${TEAM_ID:?Set TEAM_ID in release.config}"
: "${APPLE_ID:?Set APPLE_ID in release.config}"
: "${APP_PASSWORD:?Set APP_PASSWORD in release.config}"

APP_NAME="Wispr Clone"
APP="build/${APP_NAME}.app"
DMG="build/${APP_NAME}.dmg"
DMG_STAGE="build/dmg-stage"

# --- 1. Build + sign with Developer ID ---------------------------------------
echo "==> [1/5] Building and signing with Developer ID…"
SIGN_IDENTITY="${SIGN_IDENTITY}" ./build_app.sh >/dev/null
echo "    signed: ${APP}"

echo "==> Verifying signature…"
codesign --verify --strict --verbose=2 "${APP}"

# --- 2. Build a drag-to-Applications .dmg ------------------------------------
echo "==> [2/5] Creating ${DMG}…"
rm -rf "${DMG_STAGE}" "${DMG}"
mkdir -p "${DMG_STAGE}"
cp -R "${APP}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGE}" \
    -ov -format UDZO \
    "${DMG}" >/dev/null
rm -rf "${DMG_STAGE}"
echo "    created: ${DMG}"

# --- 3. Sign the .dmg --------------------------------------------------------
echo "==> [3/5] Signing the .dmg…"
codesign --force --sign "${SIGN_IDENTITY}" --timestamp "${DMG}"

# --- 4. Notarize -------------------------------------------------------------
echo "==> [4/5] Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "${DMG}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${TEAM_ID}" \
    --password "${APP_PASSWORD}" \
    --wait

# --- 5. Staple the ticket so it works offline --------------------------------
echo "==> [5/5] Stapling notarization ticket…"
xcrun stapler staple "${DMG}"
xcrun stapler validate "${DMG}"

echo ""
echo "✅ Done. Distributable, notarized installer:"
echo "   ${DMG}"
echo ""
echo "Upload this .dmg to your GitHub Release; the website's Download button links to it."
