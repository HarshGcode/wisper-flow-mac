#!/bin/bash
# Builds WisprClone and packages it into a signed "Wispr Clone.app" bundle.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Wispr Clone"
BUNDLE="build/${APP_NAME}.app"
EXEC_NAME="WisprClone"

echo "==> Compiling (release)…"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${EXEC_NAME}"

echo "==> Assembling ${BUNDLE}…"
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${BUNDLE}/Contents/MacOS/${EXEC_NAME}"
cp Info.plist "${BUNDLE}/Contents/Info.plist"
if [ -f tools/AppIcon.icns ]; then
    cp tools/AppIcon.icns "${BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# SIGN_IDENTITY defaults to ad-hoc ("-"); release.sh overrides it with a
# "Developer ID Application: …" identity for notarizable, publicly distributable builds.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
echo "==> Code signing (identity: ${SIGN_IDENTITY})…"
codesign --force --deep \
    --sign "${SIGN_IDENTITY}" \
    --entitlements WisprClone.entitlements \
    --options runtime \
    --timestamp \
    "${BUNDLE}" 2>/dev/null || \
codesign --force --deep --sign "${SIGN_IDENTITY}" --entitlements WisprClone.entitlements --options runtime "${BUNDLE}"

echo ""
echo "✅ Built ${BUNDLE}"
echo ""
echo "Run it with:"
echo "   open \"${BUNDLE}\""
echo ""
echo "First launch: grant Microphone, Speech Recognition, and Accessibility"
echo "in System Settings ▸ Privacy & Security, then relaunch the app."
