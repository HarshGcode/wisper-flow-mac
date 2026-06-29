#!/bin/bash
# Builds the on-device Whisper engine (whisper.cpp binary + model) into ./whisper/
# so build_app.sh can bundle it. These files are gitignored (too large), so run
# this once on a fresh checkout. Requires: git, cmake (brew install cmake).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f whisper/whisper-cli ] && [ -f whisper/ggml-base.bin ]; then
    echo "✅ whisper/ already set up."
    exit 0
fi

command -v cmake >/dev/null || { echo "Installing cmake…"; brew install cmake; }

mkdir -p whisper-build && cd whisper-build
[ -d whisper.cpp ] || git clone --depth 1 https://github.com/ggml-org/whisper.cpp.git
cd whisper.cpp

echo "==> Building whisper-cli (static)…"
cmake -B build -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release \
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=ON >/dev/null
cmake --build build --config Release -j --target whisper-cli >/dev/null

echo "==> Downloading multilingual base model…"
bash ./models/download-ggml-model.sh base >/dev/null

cd ../..
mkdir -p whisper
cp whisper-build/whisper.cpp/build/bin/whisper-cli whisper/
cp whisper-build/whisper.cpp/models/ggml-base.bin whisper/
chmod +x whisper/whisper-cli
echo "✅ whisper/ ready (whisper-cli + ggml-base.bin)."
