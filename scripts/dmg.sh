#!/usr/bin/env bash
# Build a drag-to-install .dmg for end users. Output: dist/Multipaste.dmg
#
# Resulting DMG has:
#   - Multipaste.app
#   - Applications symlink (so the user drags from one to the other)
#   - A custom volume name "Multipaste"
#
# The DMG is ad-hoc signed via the bundled binary; no extra steps needed.
# We compress with UDZO (the standard "ZIP-ish" DMG format every Mac can mount).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)"
VOLNAME="Multipaste"
DMG_OUT="dist/Multipaste-${VERSION}.dmg"

echo "==> building app"
bash scripts/build.sh

STAGE="dist/dmg-stage"
rm -rf "$STAGE" "$DMG_OUT"
mkdir -p "$STAGE"

cp -R dist/Multipaste.app "$STAGE/Multipaste.app"
ln -s /Applications "$STAGE/Applications"

# Add a top-level README inside the DMG that the user sees when mounted.
#
# IMPORTANT: this README MUST describe the control-click Gatekeeper
# bypass, NOT just "double-click". Multipaste is ad-hoc signed (no
# Apple Developer ID), so on first launch Gatekeeper rejects a double-
# click with "Multipaste cannot be opened" (no Open button — just
# Cancel + Move to Bin). The control-click route is the standard
# bypass and produces a dialog that DOES have an Open button. Tests
# in BuildScriptTests lock this content in so a future edit can't
# silently reintroduce the broken "just double-click" instructions.
cat > "$STAGE/READ ME FIRST.txt" <<EOF
Multipaste — Win+V for macOS

To install:

  1. Drag Multipaste onto the Applications folder shortcut on the
     right.

  2. Open your Applications folder (Finder → Go → Applications).

  3. CONTROL-CLICK (or right-click) on Multipaste, then choose Open.
     macOS will ask "macOS cannot verify the developer of
     'Multipaste'. Are you sure you want to open it?" — click Open.

     Why not just double-click on first launch? Double-clicking a
     downloaded app that isn't signed by an Apple-registered
     developer shows a dialog with NO Open button — just Cancel
     and Move to Bin. The control-click route is the standard
     Gatekeeper bypass for indie apps. You only do this once;
     every subsequent launch is an ordinary double-click.

     If control-click → Open doesn't show an Open button (this can
     happen on some macOS 15 Sequoia configurations): open
     System Settings → Privacy & Security → scroll to the bottom
     → click "Open Anyway" next to "Multipaste was blocked...".

  4. Multipaste shows a Welcome window. Click "Enable" under
     "Start at login", click "Open System Settings" under
     "Accessibility" and flip the Multipaste toggle ON (authenticate
     with Touch ID), then click "Get Started".

To use:
  - Press ⌘⇧V anywhere to open the clipboard picker.
  - The status-bar icon (📋) has Preferences, snippets, and Quit.

Installed via Homebrew? (\`brew install --cask NewdlDewdl/multipaste/multipaste\`)
The cask removes the quarantine flag automatically, so you can skip
step 3 — just launch Multipaste from Spotlight or Applications.

Multipaste is source-available under PolyForm Strict 1.0.0
(noncommercial use only; commercial licensing on request).
Source code, full docs, and bug reports:
https://github.com/NewdlDewdl/multipaste
EOF

echo "==> creating $DMG_OUT"
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_OUT" >/dev/null

rm -rf "$STAGE"

# Verify the resulting DMG mounts and that the embedded app codesign is intact.
hdiutil verify "$DMG_OUT" >/dev/null

SIZE="$(du -h "$DMG_OUT" | awk '{print $1}')"
SHA="$(shasum -a 256 "$DMG_OUT" | awk '{print $1}')"
echo ""
echo "✓ $DMG_OUT ($SIZE)"
echo "  sha256: $SHA"
echo ""
echo "  → Update Homebrew cask formula with this sha256."
