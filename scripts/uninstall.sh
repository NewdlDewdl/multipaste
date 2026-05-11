#!/usr/bin/env bash
# Reverse of install.sh — quits Multipaste, removes the app, and cleans
# up the LaunchAgent plist if a pre-1.6.0 install left one behind.
# Leaves history JSON and preferences alone unless invoked with --purge.
set -euo pipefail

PURGE=0
if [[ "${1:-}" == "--purge" ]]; then PURGE=1; fi

APP_DEST="$HOME/Applications/Multipaste.app"
LEGACY_AGENT_PLIST="$HOME/Library/LaunchAgents/com.rohin.multipaste.plist"
DATA_DIR="$HOME/Library/Application Support/Multipaste"
LOG_DIR="$HOME/Library/Logs/Multipaste"

# Stop the legacy LaunchAgent if it's loaded (pre-1.6.0 installs).
if launchctl list | grep -q "com.rohin.multipaste"; then
    echo "==> stopping legacy LaunchAgent"
    launchctl bootout "gui/$UID/com.rohin.multipaste" 2>/dev/null || \
        launchctl unload "$LEGACY_AGENT_PLIST" 2>/dev/null || true
fi
if [[ -f "$LEGACY_AGENT_PLIST" ]]; then
    echo "==> removing legacy LaunchAgent plist"
    rm -f "$LEGACY_AGENT_PLIST"
fi

# Stop any running instance. The user may have toggled Login Item on,
# in which case macOS will not auto-restart it once we close it.
echo "==> stopping running Multipaste"
osascript -e 'tell application "Multipaste" to quit' 2>/dev/null || \
    pkill -f "Multipaste.app/Contents/MacOS/Multipaste" 2>/dev/null || true
sleep 1

if [[ -d "$APP_DEST" ]]; then
    echo "==> removing $APP_DEST"
    rm -rf "$APP_DEST"
fi

if [[ $PURGE -eq 1 ]]; then
    echo "==> purging history, logs, preferences"
    rm -rf "$DATA_DIR" "$LOG_DIR"
    defaults delete com.rohin.multipaste 2>/dev/null || true
fi

echo ""
echo "✓ Multipaste uninstalled."
echo "  To also remove the SMAppService Login Item, open System Settings"
echo "  → General → Login Items and remove Multipaste from the list."
if [[ $PURGE -eq 0 ]]; then
    echo "  History preserved at $DATA_DIR (use --purge to also remove it)."
fi
