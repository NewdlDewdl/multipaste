#!/usr/bin/env bash
# Install Multipaste.app to ~/Applications and launch it.
#
# Multipaste handles its own auto-start via macOS's modern SMAppService
# Login Item API — the app registers itself the first time you click
# "Enable" in the Welcome window (or via Settings → Start at login).
# Earlier versions used a LaunchAgent plist in ~/Library/LaunchAgents,
# but TCC doesn't grant Accessibility to LaunchAgent-spawned processes
# on macOS Tahoe, so we moved off it. The app's first launch migrates
# any leftover plist automatically.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_SRC="dist/Multipaste.app"
# Always rebuild before installing — Swift's incremental compile makes this
# essentially free on no-change runs, but it eliminates the entire class of
# bug where a stale dist/ silently ships old binary.
echo "==> rebuilding before install"
bash scripts/build.sh

APPS_DIR="$HOME/Applications"
APP_DEST="$APPS_DIR/Multipaste.app"

echo "==> installing $APP_DEST"
mkdir -p "$APPS_DIR"
# Kill any running instance so we can swap the bundle. Multipaste's own
# SingleInstance.enforce() handles concurrent siblings, but the file copy
# below would fail if the binary is in use.
pkill -f "$APP_DEST/Contents/MacOS/Multipaste" 2>/dev/null || true
sleep 1
[[ -d "$APP_DEST" ]] && rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"

# Register with Launch Services so System Settings → Accessibility,
# Spotlight, and `open -a Multipaste` all know where to find the bundle.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -f "$APP_DEST" >/dev/null 2>&1 || true
fi

# Launch it. The app's first run will:
#  1. Migrate away from any leftover LaunchAgent plist.
#  2. Register itself as a Login Item via SMAppService (so it starts
#     automatically on the next macOS login).
#  3. Show the Welcome window if it's a fresh install.
echo "==> launching Multipaste"
open -a "$APP_DEST"

sleep 2

if pgrep -f "Multipaste.app/Contents/MacOS/Multipaste" >/dev/null; then
    echo ""
    echo "✓ Multipaste is running."
else
    echo ""
    echo "✗ Multipaste didn't start. Try opening it from Applications manually."
    exit 1
fi

cat <<'EOF'

Next steps:
  1. Press ⌘⇧V anywhere to open the picker.
  2. The first time you pick an item, macOS will prompt for Accessibility
     access. Multipaste's Welcome window has a one-click "Open System
     Settings" button — flip the toggle to grant access.
  3. The status-bar icon (📋) dims when access is missing. If it stays
     dim after granting, click 📋 → Reset Accessibility Permission,
     then Quit & Relaunch. Multipaste 1.6.0+ should not need this.

Data:        ~/Library/Application Support/Multipaste/
Preferences: ~/Library/Preferences/com.rohin.multipaste.plist
Uninstall:   bash scripts/uninstall.sh
EOF
