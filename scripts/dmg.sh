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
cat > "$STAGE/READ ME FIRST.txt" <<EOF
Multipaste — Win+V for macOS

To install:
  1. Drag Multipaste to the Applications folder shortcut on the right.
  2. Open your Applications folder and double-click Multipaste.
  3. macOS will ask "Are you sure?" — click Open. (This is normal for
     apps not from the App Store.)
  4. Multipaste shows a Welcome window. Click "Get Started".

To use:
  - Press ⌘⇧V anywhere to open the clipboard picker.
  - The status-bar icon (📋) has Preferences, snippets, and Quit.

Source code and docs: https://github.com/NewdlDewdl/multipaste
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
