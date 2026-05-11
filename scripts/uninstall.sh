#!/usr/bin/env bash
# Reverse of install.sh — unloads the agent, removes the plist, deletes the
# app from ~/Applications. Leaves history JSON in Application Support so the
# user can re-install without losing their pinned items. Pass `--purge` to
# also wipe history and logs.
set -euo pipefail

PURGE=0
if [[ "${1:-}" == "--purge" ]]; then PURGE=1; fi

LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/com.rohin.multipaste.plist"
APP_DEST="$HOME/Applications/Multipaste.app"
DATA_DIR="$HOME/Library/Application Support/Multipaste"
LOG_DIR="$HOME/Library/Logs/Multipaste"

if launchctl list | grep -q "com.rohin.multipaste"; then
    echo "==> stopping LaunchAgent"
    launchctl bootout "gui/$UID/com.rohin.multipaste" 2>/dev/null || \
        launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
fi

if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
    echo "==> removing $LAUNCH_AGENT_PLIST"
    rm -f "$LAUNCH_AGENT_PLIST"
fi

if [[ -d "$APP_DEST" ]]; then
    echo "==> removing $APP_DEST"
    rm -rf "$APP_DEST"
fi

if [[ $PURGE -eq 1 ]]; then
    echo "==> purging history and logs"
    rm -rf "$DATA_DIR" "$LOG_DIR"
fi

echo ""
echo "✓ Multipaste uninstalled."
if [[ $PURGE -eq 0 ]]; then
    echo "  History preserved at $DATA_DIR (use --purge to also remove it)."
fi
