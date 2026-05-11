#!/usr/bin/env bash
# Install Multipaste.app to ~/Applications, install the LaunchAgent, and load
# it so the app runs immediately and at every login from now on.
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
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENT_DIR/com.rohin.multipaste.plist"
LOG_DIR="$HOME/Library/Logs/Multipaste"

echo "==> installing $APP_DEST"
mkdir -p "$APPS_DIR"
rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"

# Register with Launch Services so System Settings → Accessibility,
# Spotlight, and `open -a Multipaste` all know where to find the bundle.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -f "$APP_DEST" >/dev/null 2>&1 || true
fi

mkdir -p "$LOG_DIR"
mkdir -p "$LAUNCH_AGENT_DIR"

APP_BINARY="$APP_DEST/Contents/MacOS/Multipaste"

# If the agent is already loaded, unload it first so we can swap binaries
# cleanly. Ignore errors (won't exist on first install).
if launchctl list | grep -q "com.rohin.multipaste"; then
    echo "==> unloading existing LaunchAgent"
    launchctl bootout "gui/$UID/com.rohin.multipaste" 2>/dev/null || \
        launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
fi

echo "==> installing LaunchAgent at $LAUNCH_AGENT_PLIST"
sed -e "s|__APP_BINARY__|$APP_BINARY|g" \
    -e "s|__LOG_DIR__|$LOG_DIR|g" \
    LaunchAgent/com.rohin.multipaste.plist \
    > "$LAUNCH_AGENT_PLIST"

# Validate the plist before loading
plutil -lint "$LAUNCH_AGENT_PLIST" >/dev/null

echo "==> loading LaunchAgent"
launchctl bootstrap "gui/$UID" "$LAUNCH_AGENT_PLIST" 2>/dev/null || \
    launchctl load "$LAUNCH_AGENT_PLIST"

# Make sure it's enabled (a disabled agent silently refuses to start)
launchctl enable "gui/$UID/com.rohin.multipaste" 2>/dev/null || true

sleep 1

if launchctl list | grep -q "com.rohin.multipaste"; then
    PID="$(launchctl list | awk '/com\.rohin\.multipaste/ {print $1}')"
    echo ""
    echo "✓ Multipaste is running (PID $PID)"
else
    echo ""
    echo "✗ LaunchAgent didn't start — check $LOG_DIR/multipaste.err.log"
    exit 1
fi

cat <<'EOF'

Next steps:
  1. Press ⌘⇧V anywhere to open the picker.
  2. The first time you select an item, macOS will ask you to grant
     Accessibility permission to Multipaste:
        System Settings → Privacy & Security → Accessibility
     Toggle "Multipaste" on. After that, picks auto-paste into the
     focused app — exactly like Win+V on Windows.
  3. The status-bar icon (📋) gives you Pause / Clear / Quit.

Logs:   ~/Library/Logs/Multipaste/
Data:   ~/Library/Application Support/Multipaste/
Uninstall:  bash scripts/uninstall.sh
EOF
