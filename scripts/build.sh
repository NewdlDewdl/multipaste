#!/usr/bin/env bash
# Build Multipaste in release mode, then assemble Multipaste.app.
# Output: dist/Multipaste.app
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
    SWIFT_ARCH="arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
    SWIFT_ARCH="x86_64"
else
    echo "unsupported arch: $ARCH" >&2
    exit 1
fi

echo "==> swift build -c release"
swift build -c release --arch "$SWIFT_ARCH" --product Multipaste

BIN_PATH="$(swift build -c release --arch "$SWIFT_ARCH" --product Multipaste --show-bin-path)/Multipaste"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "error: built binary not found at $BIN_PATH" >&2
    exit 1
fi

APP="dist/Multipaste.app"
echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN_PATH"        "$APP/Contents/MacOS/Multipaste"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/PkgInfo  "$APP/Contents/PkgInfo"

chmod +x "$APP/Contents/MacOS/Multipaste"

# Ad-hoc codesign so the system gives the app a stable identity (needed
# for TCC permissions like Accessibility to persist across rebuilds).
echo "==> ad-hoc codesign"
codesign --force --deep --sign - --options runtime --timestamp=none "$APP"

# Sanity: ensure the bundle is well-formed.
codesign --verify --deep --strict "$APP"

echo ""
echo "✓ Built $APP"
ls -la "$APP/Contents/MacOS/"
