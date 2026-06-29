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
# Bundle the on-device Whisper engine (binary + model) so transcription needs
# no API key and works offline. See tools/setup_whisper.sh to (re)create them.
if [ -f whisper/whisper-cli ] && [ -f whisper/ggml-small.bin ]; then
    cp whisper/whisper-cli "${BUNDLE}/Contents/Resources/whisper-cli"
    cp whisper/ggml-small.bin "${BUNDLE}/Contents/Resources/ggml-small.bin"
    chmod +x "${BUNDLE}/Contents/Resources/whisper-cli"
    echo "    bundled local Whisper engine"
else
    echo "    ⚠️  whisper/ engine missing — run tools/setup_whisper.sh (local Whisper disabled)"
fi

# Pick a signing identity:
#   1. Whatever the caller passed (release.sh uses a Developer ID).
#   2. Else the stable "Wispr Clone Self-Signed" cert if present — this keeps the
#      code signature identical across rebuilds, so the Accessibility permission
#      survives and doesn't need re-granting every time.
#   3. Else fall back to ad-hoc ("-").
if [ -z "${SIGN_IDENTITY:-}" ]; then
    if security find-identity -p codesigning 2>/dev/null | grep -q "Wispr Clone Self-Signed"; then
        SIGN_IDENTITY="Wispr Clone Self-Signed"
    else
        SIGN_IDENTITY="-"
    fi
fi
# Sign the nested Whisper binary first so the whole bundle is consistently signed.
if [ -f "${BUNDLE}/Contents/Resources/whisper-cli" ]; then
    codesign --force --sign "${SIGN_IDENTITY}" --options runtime \
        "${BUNDLE}/Contents/Resources/whisper-cli" 2>/dev/null || true
fi
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
