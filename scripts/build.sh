#!/usr/bin/env bash
# Build Multipaste in release mode as a UNIVERSAL binary (arm64 + x86_64),
# then assemble Multipaste.app.
# Output: dist/Multipaste.app
#
# Why universal: shipping an arm64-only binary breaks every Intel Mac user
# with the exact macOS error "You can't open the application 'Multipaste'
# because this application is not supported on this Mac." This was the bug
# in v2.0.0 — caught by a friend on Intel Ventura 13.7.8. Fixed in v2.0.1
# by building for both archs and lipo-ing them into a single fat binary.
#
# Override:
#   MULTIPASTE_BUILD_ARCHS="arm64"        # arm64-only
#   MULTIPASTE_BUILD_ARCHS="x86_64"       # x86_64-only
#   MULTIPASTE_BUILD_ARCHS="arm64 x86_64" # universal (default)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Default: universal (arm64 + x86_64). The Intel side adds ~2× build time
# but produces a binary that runs on every Mac that meets the macOS 13+
# minimum — both Apple Silicon and Intel.
ARCHS="${MULTIPASTE_BUILD_ARCHS:-arm64 x86_64}"

echo "==> building Multipaste for architectures: $ARCHS"

PER_ARCH_BINS=()
for ARCH in $ARCHS; do
    case "$ARCH" in
        arm64|x86_64) ;;
        *)
            echo "error: unsupported architecture '$ARCH' (expected arm64 or x86_64)" >&2
            exit 1
            ;;
    esac

    echo "==> swift build -c release --arch $ARCH"
    swift build -c release --arch "$ARCH" --product Multipaste

    BIN="$(swift build -c release --arch "$ARCH" --product Multipaste --show-bin-path)/Multipaste"
    if [[ ! -x "$BIN" ]]; then
        echo "error: built binary not found at $BIN" >&2
        exit 1
    fi
    PER_ARCH_BINS+=("$BIN")
done

APP="dist/Multipaste.app"
echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Combine all per-arch binaries into a single fat (universal) binary.
# `lipo -create` works for any N including N=1 (single-arch passthrough),
# so the same path handles single-arch overrides without special-casing.
echo "==> lipo: combining ${#PER_ARCH_BINS[@]} binary/binaries into a fat Mach-O"
lipo -create -output "$APP/Contents/MacOS/Multipaste" "${PER_ARCH_BINS[@]}"

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/PkgInfo  "$APP/Contents/PkgInfo"

# Ensure the icon is built and present in the bundle.
if [[ ! -f Resources/Multipaste.icns ]]; then
    echo "==> generating icon"
    bash scripts/make-iconset.sh
fi
cp Resources/Multipaste.icns "$APP/Contents/Resources/Multipaste.icns"

chmod +x "$APP/Contents/MacOS/Multipaste"

# Ad-hoc codesign with a designated requirement that matches by bundle
# identifier instead of by cdhash. Without this override, the default DR
# pins TCC permissions (Accessibility, Input Monitoring) to a specific
# cdhash — and every rebuild changes the cdhash, so the user re-grants
# Accessibility on every update. With `identifier "..."` as the DR, TCC
# can match new builds to old grants. macOS 14+ honors this for ad-hoc.
echo "==> ad-hoc codesign with stable designated requirement"
codesign --force --deep --sign - \
    --identifier com.rohin.multipaste \
    --requirements '=designated => identifier "com.rohin.multipaste"' \
    --options runtime \
    --timestamp=none \
    "$APP"

# Sanity: ensure the bundle is well-formed.
codesign --verify --deep --strict "$APP"

# Sanity: ensure the embedded binary actually contains every architecture
# we asked for. Fails the build loudly if the universal step silently
# dropped an arch — the regression-guard for the v2.0.0 Intel-can't-open
# bug.
echo "==> verifying universal binary contains: $ARCHS"
ACTUAL_ARCHS="$(lipo -archs "$APP/Contents/MacOS/Multipaste")"
for ARCH in $ARCHS; do
    if ! echo "$ACTUAL_ARCHS" | grep -qw "$ARCH"; then
        echo "error: built binary missing requested architecture '$ARCH'" >&2
        echo "  expected: $ARCHS" >&2
        echo "  actual:   $ACTUAL_ARCHS" >&2
        exit 1
    fi
done
echo "  ✓ binary contains: $ACTUAL_ARCHS"

echo ""
echo "✓ Built $APP"
ls -la "$APP/Contents/MacOS/"
