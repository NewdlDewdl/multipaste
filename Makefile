.PHONY: all build test smoke-test plaintext-smoke-test preview-update-dialog install uninstall purge run clean status logs verify-app

all: build

test:
	swift run -c debug MultipasteTests

# End-to-end integration smoke test of the screenshot-to-clipboard
# pipeline. Stand-alone Swift script that exercises the actual macOS
# APIs (DispatchSourceFileSystemObject + NSPasteboard) against a
# temp directory + a private pasteboard — so it doesn't touch the
# user's real screenshot folder or system clipboard. Complements
# the unit tests in `make test` (those cover the pure logic;
# this verifies the live integration on the machine).
smoke-test:
	@swift scripts/screenshot-smoke-test.swift

# End-to-end integration smoke test of the plain-text-paste feature
# (⇧↩). Mirrors PlainText.pasteWrite + Paster.put and runs the write
# against a PRIVATE NSPasteboard, proving a plain-text paste leaves
# .string and strips the .rtf type on a live pasteboard. The pure
# per-kind mapping is unit-tested in PlainTextTests; this proves the
# AppKit write those decisions drive.
plaintext-smoke-test:
	@swift scripts/plaintext-paste-smoke-test.swift

# Visual preview of the "vX.Y.Z is available" update dialog —
# uses the actual v2.0.2 CHANGELOG markdown that produced the bug
# Rohin reported (raw `##`, `**`, ```` ` ````, `>` in plain text).
# Click "Looks good" to confirm the fix works visually.
preview-update-dialog:
	@swift scripts/preview-update-dialog.swift

build:
	bash scripts/build.sh

# Post-build verification: confirms the built .app contains a universal
# binary (arm64 + x86_64), passes codesign --verify, and has all expected
# Info.plist keys. Run after `make build` (or as part of release prep)
# to catch any regression the v2.0.1 audit lock-down didn't already
# catch. Fails non-zero on any check.
verify-app:
	@if [ ! -d dist/Multipaste.app ]; then \
		echo "error: dist/Multipaste.app not found — run 'make build' first" >&2; \
		exit 1; \
	fi
	@echo "==> verifying dist/Multipaste.app is universal (arm64 + x86_64)"
	@ARCHS="$$(lipo -archs dist/Multipaste.app/Contents/MacOS/Multipaste)"; \
		echo "$$ARCHS" | grep -qw arm64 || { echo "  ✗ missing arm64 slice"; exit 1; }; \
		echo "$$ARCHS" | grep -qw x86_64 || { echo "  ✗ missing x86_64 slice"; exit 1; }; \
		echo "  ✓ binary contains: $$ARCHS"
	@echo "==> verifying codesign"
	@codesign --verify --deep --strict dist/Multipaste.app && echo "  ✓ codesign passes"
	@echo "==> verifying CFBundleShortVersionString matches Version.swift"
	@PLIST_V="$$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' dist/Multipaste.app/Contents/Info.plist)"; \
		SWIFT_V="$$(grep -E 'static let value = \"' Sources/MultipasteCore/Version.swift | sed -E 's/.*"(.*)".*/\1/')"; \
		[ "$$PLIST_V" = "$$SWIFT_V" ] || { echo "  ✗ version mismatch: Info.plist=$$PLIST_V vs Version.swift=$$SWIFT_V"; exit 1; }; \
		echo "  ✓ version: $$PLIST_V"
	@echo "==> verifying LSMinimumSystemVersion is 13.0"
	@MIN="$$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' dist/Multipaste.app/Contents/Info.plist)"; \
		[ "$$MIN" = "13.0" ] || { echo "  ✗ LSMinimumSystemVersion=$$MIN (expected 13.0)"; exit 1; }; \
		echo "  ✓ LSMinimumSystemVersion: $$MIN"
	@echo ""
	@echo "✓ dist/Multipaste.app verified — universal, signed, version-consistent"

install: build
	bash scripts/install.sh

uninstall:
	bash scripts/uninstall.sh

purge:
	bash scripts/uninstall.sh --purge

run: build
	./dist/Multipaste.app/Contents/MacOS/Multipaste

status:
	@launchctl list | grep com.rohin.multipaste || echo "not running"
	@echo
	@ls -la ~/Library/LaunchAgents/com.rohin.multipaste.plist 2>/dev/null || true

logs:
	@tail -n 80 -F ~/Library/Logs/Multipaste/multipaste.err.log ~/Library/Logs/Multipaste/multipaste.out.log

clean:
	rm -rf .build dist
