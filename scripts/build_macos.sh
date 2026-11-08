#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter_bin="${FLUTTER_BIN:-flutter}"
"$flutter_bin" pub get
"$flutter_bin" analyze
"$flutter_bin" test
"$flutter_bin" build macos --release
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent "build/macos/Build/Products/Release/Weekly Routine.app" "dist/Weekly-Routine-macOS.zip"
printf 'Built: %s/dist/Weekly-Routine-macOS.zip\n' "$PWD"
