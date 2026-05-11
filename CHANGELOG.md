# Changelog

## 1.7.2 — 2026-05-11

Hotfix: clicking Diagnostics… hung the app. This is the **third**
occurrence of the same `Process()` pipe-drain bug, finally rooted out
across the codebase.

### What was wrong

`Diagnostics.siblingMultipasteProcesses()` ran `/bin/ps -Ao pid,command`
with the naive `task.waitUntilExit()` + `readDataToEndOfFile()` pattern.
On a busy Mac that produces well over 64 KB of output (the kernel pipe
buffer size) — measured 176,664 bytes on the test machine. `ps` blocks
writing into the full pipe, we block waiting for `ps` to exit, main
thread freezes, the UI looks crashed.

The fix from 1.6.1 (async `readabilityHandler` before `waitUntilExit`)
was already applied to `SingleInstance.enforce()` and
`Diagnostics.readCodesign()`. The `siblingMultipasteProcesses()` helper
was missed.

### Also fixed: synchronous subprocess call from main thread

Even after the deadlock fix, `MenuBarController.showDiagnostics()` was
spawning `codesign` + `ps` from the main thread before presenting the
alert. On a slow system that meant a few hundred milliseconds of
beachball before the dialog appeared. Now `Diagnostics.snapshot()` runs
on a background `userInitiated` queue and the alert presents on main
once the snapshot is ready. UI stays responsive the entire time.

### Verification

A probe with the new async-drain pattern processed 176 KB of `ps`
output in **66 ms**. The previous code would have deadlocked at byte
~65,536 — every time, on any reasonably loaded macOS system.

### Permanent guard

Three independent occurrences of the same bug in one codebase is a
signal. Any future `Process()` invocation that pipes stdout/stderr
should either:
  - Use `readabilityHandler` + `DispatchGroup` to drain async, OR
  - Have a comment explaining why the output is bounded < 64 KB.

Audit grep: `git grep -n 'waitUntilExit\|readDataToEndOfFile' Sources/`
should return zero hits not paired with an async-drain pattern.

## 1.7.1 — 2026-05-11

Fixes the "picked an item, hit Enter, nothing pasted, had to ⌘V manually"
bug — present since the picker shipped in 1.0.0.

### What was wrong

The picker calls `NSApp.activate(ignoringOtherApps: true)` so its search
field receives keystrokes. But on dismiss we never returned focus to the
app the user was previously in. By the time we synthesized ⌘V (after a
fixed 80 ms delay), Multipaste was *still* the frontmost app — so the
keystroke landed in Multipaste's own event queue and disappeared.

### The fix

Standard pattern from every working menu-bar app:

1. **Capture the previously-frontmost app** in `PickerWindow.show()` —
   crucially, *before* the `NSApp.activate` call that makes Multipaste
   itself frontmost.
2. **On pick** (Enter or ⌘1-9), `commitItem(_:)` snapshots that target
   and passes it back through the `onPick` callback alongside the item.
3. **In `AppDelegate.pickAndPaste`**, call
   `previousApp.activate(options: [])` to return focus to the original
   app.
4. **Poll `NSWorkspace.frontmostApplication` every 20 ms** (up to
   500 ms) until it matches `previousApp`, instead of waiting a fixed
   delay. Focus-switching is asynchronous — the actual time varies from
   ~30 ms on idle systems to ~250 ms under load. A fixed 80 ms delay
   was simultaneously too short on busy systems and unnecessarily long
   on idle ones. The new approach paces itself.
5. **Once focus has actually returned**, synthesize ⌘V via
   `CGEvent.post`.

Every transition is logged to `~/Library/Logs/Multipaste/multipaste.log`
(`pickAndPaste: reactivating com.apple.TextEdit pid=…`, then
`pickAndPaste: focus restored, synthesizing ⌘V`) so you can verify the
fix worked on your machine.

If focus polling times out (target app dead, screensaver, etc.), we
synthesize ⌘V anyway and log `focus restore TIMED OUT` — the user still
gets *some* paste rather than silent failure.

## 1.7.0 — 2026-05-11

Copying a file now does the right thing in *both* text and file-accepting
paste targets — simultaneously. The Claude desktop app was the
motivating case: pasting a copied file in the **code tab** now yields
the full file path; pasting the same copied file in the **chat tab**
attaches the file itself. No app detection, no mode switching, no
clipboard rewriting at paste time — both representations live on the
pasteboard together and the receiving control picks whichever type it
wants.

### How

macOS Finder's "copy a file" produces a pasteboard with
`public.file-url` and a handful of legacy URL/filename types, but
**no `public.utf8-plain-text`**. Pasting in a code editor therefore
gets nothing useful, or just the filename via OS fallback.

`ClipboardMonitor.augmentFileURLsIfNeeded()` now intercepts these
file-only pasteboards. When a fresh file copy lands and there's no
usable string representation, Multipaste snapshots every existing
type's data, clears the pasteboard, re-declares all types plus
`.string`, writes the saved data back, and adds the full path
(newline-joined for multi-file copies) as the string.

Result:

- Text-only consumers (code editors, terminals, search fields) → path
- File-URL consumers (chat composers, image editors, Finder) → file

Both at the same time, from a single ⌘C.

### What's added

- **`MultipasteCore/PasteboardAugmenter`** — pure `pathText(forFiles:)`
  and `shouldAugment(existing:)` helpers. 7 new unit tests covering
  single/multi/empty file lists, nil/empty/whitespace-only existing
  strings, and the "don't clobber real text" guarantee.
- **`Preferences.augmentFileCopiesWithPath`** (default ON, persisted in
  `~/Library/Preferences/com.rohin.multipaste.plist`).
- **Settings → General**: new "Add file path as text on file copies"
  checkbox with explanatory hint.
- Test count: **69** (was 62).

### Trade-off documented

The augmentation bumps `changeCount` by one (because we have to
`clearContents()` + re-declare types to inject a new representation on
an Apple-owned pasteboard). Multipaste's own next poll dedupes via
`contentHash`, so the history list doesn't double-up. Other clipboard
managers running concurrently might briefly see a "new" copy event;
this is the only way to add a representation to a pasteboard you don't
own.

## 1.6.1 — 2026-05-11

Hotfix: 1.6.0 froze before its main loop ever started.

`SingleInstance.enforce()` ran `/bin/ps -Ao pid,lstart,command` with the
naive `task.waitUntilExit()` + `readDataToEndOfFile()` pattern. On a busy
macOS system the ps output exceeded the 64 KB pipe buffer, ps blocked
writing, the Swift side blocked waiting — classic UNIX pipe deadlock.
Multipaste's main thread was stuck at `main.swift:9` for the entire
lifetime of v1.6.0, never reaching `NSApp.run()`. No menu-bar icon, no
Welcome window, no anything — even though the process was technically
"alive."

This is the same deadlock that was already fixed inside
`Diagnostics.readCodesign` in 1.6.0 — but `SingleInstance` had a copy of
the pattern that was missed.

**Fix**: install an async `readabilityHandler` on the pipe that drains
into a `Data` accumulator before `waitUntilExit`. Same fix that worked
for codesign now applied to ps. Detection: the `sample` tool's call
graph showed the stack pinned at `Multipaste_main + 20`, which is line 9
of `main.swift` — `SingleInstance.enforce()`.

## 1.6.0 — 2026-05-11

Fixes "I granted Accessibility access but Multipaste still says OFF" — the
real, root-cause version. Three independent bugs found and fixed.

### Bug 1: LaunchAgent-supervised processes don't inherit TCC grants

The biggest issue. v1.0–1.5 used a LaunchAgent plist in
`~/Library/LaunchAgents/` as the auto-start mechanism. macOS Tahoe's TCC
framework refuses to apply Accessibility grants to processes spawned by
launchd as user-level LaunchAgents — even with a stable designated
requirement, even when the same .app bundle gets `trust=ON` when
launched directly.

**Fix**: switched to `SMAppService.mainApp.register()` (the modern
Apple-recommended path, what Maccy / Rectangle / AltTab use). DMG users
flip "Enable" in the Welcome window; the bundle registers itself as a
Login Item and surfaces in System Settings → General → Login Items.

**Migration**: on first launch, v1.6.0 detects leftover LaunchAgent
plists from earlier installs and removes them automatically.

### Bug 2: TCC indexes permissions by cdhash; rebuilds drift

Every `make install` produced a fresh ad-hoc-signed binary with a new
cdhash, and TCC kept the permission grant pinned to the old cdhash.

**Fix**: `scripts/build.sh` now signs with `--requirements
'=designated => identifier "com.rohin.multipaste"'`, making the
designated requirement match by bundle identifier rather than cdhash.
On macOS 14+ this lets TCC carry grants across rebuilds.

**Escape hatch**: **Reset Accessibility Permission** menu item runs
`/usr/bin/tccutil reset Accessibility com.rohin.multipaste` to wipe
stuck entries from pre-1.6.0 cdhash drift.

### Bug 3: Duplicate supervisors fighting

LaunchAgent + SMAppService Login Item could be active simultaneously,
spawning two Multipaste processes that wrote over each other's history
JSON.

**Fix**: `SingleInstance.enforce()` at startup kills sibling Multipaste
processes; combined with the migration above, only one supervisor
remains.

### Visibility improvements

- **`~/Library/Logs/Multipaste/multipaste.log`** — boot line on every
  start (`trust=ON|OFF`, pid, bundle path) plus a line every time the
  trust state flips. Works for both terminal-launched and Login-Item-
  launched processes (writes to file + stderr).
- **Diagnostics…** menu item: scrollable view of version, bundle path,
  signing identifier, designated requirement, cdhash, login-item
  status, sibling PIDs, with a Copy-to-Clipboard button.
- **install.sh** rewritten — copies the .app, registers with Launch
  Services, and `open`s it. No more LaunchAgent plist creation.
- **uninstall.sh** cleans up the legacy LaunchAgent plist if a
  pre-1.6.0 install left one behind.

## 1.5.0 — 2026-05-11

Fixes "I granted access but the icon didn't brighten."

- **Timer scheduled in `.common` runloop modes** so the poller keeps
  firing while menus are tracked and `NSAlert`s are modal. The v1.4.0
  poller silently paused while the user was reading the very alert that
  told them what to do. This is the primary cause behind v1.4.0's
  reported "didn't auto-detect" symptom.
- **Burst-poll mode**: after the user clicks "Grant Accessibility
  access…", `PermissionMonitor` checks `AXIsProcessTrusted()` at 250 ms
  cadence for 60 seconds — the toggle is caught within a single tick of
  flipping.
- **`PermissionMonitor.refresh()`** triggered on every `NSWorkspace
  .didActivateApplication` event so the trust state is re-read the
  moment the user comes back to Multipaste from System Settings.
- **Quit & Relaunch** (`AppDelegate.relaunch()`) spawns a fresh app
  process and terminates the current one, bypassing macOS's per-process
  TCC cache. Available three ways:
    - Permanent **Quit & Relaunch** menu item.
    - **"Already toggled? Quit & Relaunch"** row under the warning banner.
    - **Quit & Relaunch** button on the post-grant fallback alert that
      fires when the burst-poll window elapses without a change.
- **Live "Accessibility: ON/OFF" status row** in the menu so the user
  always knows what Multipaste's actual in-process trust state is. No
  guessing.
- README: new "If the icon doesn't brighten after you grant access"
  section explaining the macOS TCC cache and the relaunch fix.

## 1.4.0 — 2026-05-11

Granting Accessibility is no longer a side quest.

- **In-menu "Grant Accessibility access…" banner** appears at the top
  of the menu whenever the OS reports the trust bit as `false`. Click
  it and Multipaste auto-adds itself to the Accessibility list, opens
  System Settings to the right pane, and shows step-by-step instructions
  in an alert.
- **Status-bar icon dims** when Accessibility is missing. Subtle "needs
  attention" cue that works in both light and dark mode.
- **PermissionMonitor** polls `AXIsProcessTrusted()` every 2 seconds.
  When access is granted (or revoked), the menu rebuilds, the icon
  un-dims, and a "Granted!" confirmation pops up. The SnippetEngine
  restarts automatically — no quit/relaunch needed.
- **Permissions.walkUserThroughAccessibilityGrant()** consolidates the
  prompt + deep-link + alert flow into one call. The Welcome window now
  uses it too, so every Grant Access entry point behaves identically.
- README adds a full "Granting Accessibility access" section with both
  in-app and manual walkthroughs, plus a clear explanation of what each
  permission is actually used for.

## 1.3.0 — 2026-05-11

You never have to wonder "am I on the latest?" again.

- **Built-in update checker.** Multipaste pings the GitHub Releases API
  60 seconds after launch and every 24 hours after that. If a newer
  release exists, you see a one-shot alert with Download / Skip This
  Version / Remind Me Later buttons. Silent when up-to-date.
- **"Check for Updates…"** menu item — manual check that *does* show
  "you're on the latest" so the user gets explicit confirmation.
- **Skip-version persistence.** Once you click Skip, that specific
  version never re-prompts (but a newer one will).
- New core types: `SemanticVersion` (parse / Comparable, handles leading
  `v`, double-digit components, equality) and `UpdateChecker` (pure
  comparison + GitHub-release JSON parsing). 17 new tests, 62 total.
- App-target `UpdateService` wraps the URLSession fetch + scheduling +
  alert UI. Pure logic stays in `MultipasteCore` and remains network-free.
- README: add "Updates" section explaining the auto-check cadence and
  the manual menu item.

## 1.2.0 — 2026-05-11

End-user installable. No Terminal required.

- **DMG installer** (`scripts/dmg.sh` → `dist/Multipaste-1.2.0.dmg`).
  Drag-to-Applications + Read-Me-First.txt + bundled icon. ~400 KB.
- **Homebrew cask**: `brew install --cask NewdlDewdl/multipaste/multipaste`.
- **App icon** — gradient squircle with stacked-rows clipboard glyph,
  generated by `scripts/make-icon.swift` (rebuildable, in-tree source).
- **First-run Welcome window** — explains the hotkey, offers one-click
  Accessibility access (deep-links into System Settings), one-click
  "Start at login" via `SMAppService.mainApp.register()`.
- **Login Item registration** via the modern `SMAppService` API (macOS 13+).
  Surfaces in System Settings → General → Login Items where users
  actually look. Still works alongside the legacy LaunchAgent path for
  installs that came via `make install` / `install.sh`.
- README rewrite: compares Multipaste against Maccy, Flycut, Paste,
  Pastebot, CopyClip 2, Alfred, Raycast, and Espanso on price, license,
  features, RAM, account requirements, and telemetry.
- 45 unit tests (was 43); two new tests for `Preferences.hasCompletedFirstRun`.

## 1.1.0 — 2026-05-11

- **Settings window** (menu-bar → Preferences…, or `⌘,`) with three tabs:
  General (hotkey recorder, paste-on-select, launch-at-login, history
  size), Snippets (list/edit/remove triggers), About.
- **Hotkey recorder**: click the field, press a combo — any key with
  ≥1 modifier — and it's bound globally. Esc cancels.
- **Snippet expansion**: pinned items can carry a trigger string. Type
  `<trigger><space|tab|return>` anywhere on macOS and the trigger is
  replaced with the snippet content. Requires Accessibility consent (the
  same prompt as auto-paste).
- **Image thumbnails** in the picker for clipboard items containing PNG/
  TIFF data, with a 64-entry LRU-ish cache to keep re-renders cheap.
- **Snippet badge** in picker cells — items with a trigger show
  `⌨ ;trigger` in blue next to the kind label.
- New file layout:
  - Core: `SnippetMatcher` (pure trigger-matching logic; 11 tests).
  - App: `SnippetEngine` (CGEventTap), `SettingsWindowController`,
    `HotkeyRecorderField`, `ThumbnailCache`, `LoginAgent`.
- Backwards-compatible JSON: v1.0.0 history files load unchanged.
- 43 unit tests (was 25); ~30ms full suite.
- Fixed `scripts/install.sh` so it always rebuilds before copying — the
  previous skip-when-dist-exists behaviour silently shipped stale binaries.

## 1.0.0 — 2026-05-11

Initial release.

- Global hotkey (default ⌘⇧V) opens a floating picker.
- Persistent history (200 entries default; pinned items survive eviction).
- Captures plain text, RTF, images (PNG/TIFF), and file URLs.
- Honors `org.nspasteboard.ConcealedType` / `TransientType` / `AutoGeneratedType`
  so password managers never leak into history.
- Menu-bar status item with quick-pick of the 9 most recent items, pause/resume,
  and clear/clear-all.
- Auto-paste into the focused app via synthesized ⌘V (requires
  Accessibility permission once; falls back gracefully without it).
- LaunchAgent for auto-start at login.
- 25 unit tests covering dedup, eviction, pinning, search, persistence,
  corrupt-file recovery, observer subscription, and preference clamping.
