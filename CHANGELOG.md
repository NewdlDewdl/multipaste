# Changelog

## 2.2.0 (2026-06-07)

**Press ⌘⇧V, pick an item, hit Return, and it pastes the first time. The
picker no longer "opens but won't paste until you reopen it two or three
times."**

The clipboard picker used to activate Multipaste so its search field could
take keystrokes, then, on pick, re-activate whatever app you came from and
synthesize ⌘V into it. On macOS 14+ (Sonoma) and later, app activation became
*cooperative*: `activate()` is only a request, and handing focus back to
another app no longer completes synchronously. So the synthesized ⌘V frequently
fired a beat before the target app had actually regained input focus, and the
paste vanished. The picker *looked* like it did nothing; you reopened it and
retried until the timing happened to line up. Chromium/Electron targets (Claude
desktop, Codex, Slack, VS Code) made it worse for a second, independent reason
(below).

### Two root causes, two fixes

**1. The focus race, fixed by never stealing focus.** The picker is now a true
*non-activating* panel. It already used `.nonactivatingPanel` (which is
*allowed* to take keyboard focus without activating its app) but then defeated
that by calling `NSApp.activate(ignoringOtherApps:)` on show. Removing that one
call, plus declaring `canBecomeKey` on an `NSPanel` subclass so the search field
still accepts typing, means the app you were in **stays frontmost the whole time
the picker is open**. On pick there's nothing to re-activate, so there's no
activation round-trip to lose a race against. (This is exactly how Maccy's
`FloatingPanel` works.) Dismiss-on-click-away, previously a side effect of the
app deactivating, is now handled explicitly via `windowDidResignKey`.

**2. Chromium/Electron dropped the Command modifier, fixed with the device
bit.** The synthesized ⌘V set only the generic Command mask (`NX_COMMANDMASK`).
Chromium-based apps inspect the *device-dependent* left/right Command bit and
ignore a Command that lacks it, so the keystroke degraded to a bare "v" or was
dropped. The synthesized event now also carries `NX_DEVICELCMDKEYMASK` (the
long-standing Flycut #18 / Maccy fix), posts to the session tap instead of the
HID tap, and suppresses live keyboard input during the post so a still-held
hotkey modifier can't contaminate it. Snippet expansion shares the same
hardened keystroke, so it benefits too.

### How it works

`PickerWindow` presents via `orderFrontRegardless()` + `makeKey()` (never
`NSApp.activate`); `PickerPanel` overrides `canBecomeKey`. `AppDelegate`'s
`pickAndPaste` routes through the pure `PasteRouting` policy: the common case is
`.immediate` (previous app still frontmost → settle one beat, then paste), with
a `.restoreFocus` fallback that uses cooperative `yieldActivation(to:)` for the
rare case focus did land on Multipaste, and `.clipboardOnly` when there's no
safe target. `Paster.simulateCommandV()` stamps `PasteSynthesis.commandVFlags`
(`maskCommand | NX_DEVICELCMDKEYMASK`). The ⌘V flag composition and the routing
decision are pure, AppKit-free, and unit-tested.

### What changed

- **`Sources/Multipaste/PickerWindow.swift`**: new `PickerPanel: NSPanel`
  (`canBecomeKey == true`); `show()` drops `NSApp.activate(ignoringOtherApps:)`
  and uses `orderFrontRegardless()` + `makeKey()`; `hidesOnDeactivate = false`
  plus `windowDidResignKey` dismissal; logs the panel-key / frontmost state on
  show.
- **`Sources/Multipaste/AppDelegate.swift`**: `pickAndPaste` rewritten around
  `PasteRouting`; the `.restoreFocus` fallback uses `NSApp.yieldActivation(to:)`
  plus `activate(from:options:)` on macOS 14+; a short settle after the focus
  condition is met; `waitForFocus` tightened to a non-optional target.
- **`Sources/Multipaste/Paster.swift`**: `simulateCommandV()` hardened with the
  left-Command device bit, `.cgSessionEventTap`, local-input suppression, and a
  `synthMarker` tag; now owns the shared `synthMarker`.
- **`Sources/Multipaste/SnippetEngine.swift`**: reuses
  `Paster.simulateCommandV()` (drops its duplicate sender); marker sourced from
  `Paster`.
- **`Sources/MultipasteCore/PasteSynthesis.swift`** (new): pure ⌘V flag /
  keycode policy carrying the device-bit rationale.
- **`Sources/MultipasteCore/PasteRouting.swift`** (new): pure paste-path
  decision (`.immediate` / `.restoreFocus` / `.clipboardOnly`).
- **`Tests/MultipasteCoreTests/PasteSynthesisTests.swift`** (new, 7 tests):
  lock the device bit into the flags so it can never silently regress.
- **`Tests/MultipasteCoreTests/PasteRoutingTests.swift`** (new, 4 tests): the
  routing truth table.
- **`Sources/MultipasteCore/Version.swift`**: 2.1.3 to 2.2.0.
- **`Resources/Info.plist`**: `CFBundleShortVersionString` 2.1.3 to 2.2.0,
  `CFBundleVersion` 21 to 22.
- **`README.md`** / **`SECURITY.md`**: test count 221 to 232; current release
  noted as 2.2.0.

## 2.1.3 — 2026-05-28

**Unpinning keeps the item where it is — it no longer teleports back to
the far-away spot where it was first copied.**

Since v2.1.1, pinned items always sit at the top of the picker. But
*unpinning* an item dropped it straight back to its original
chronological slot — and for an item you'd pinned precisely because it
was old, that slot is near the bottom of the list. So you'd unpin
something at the top and watch it vanish "super far away." Functionally
fine; viscerally wrong.

Now, unpinning leaves the item right where your eye already is: it
becomes the most-recent **unpinned** item, so it lands at the top of the
unpinned section — directly below any items that are still pinned,
above everything else. Pinned-always-first still holds (an unpinned
item can never sit above a pinned one), so "stays put" resolves to "top
of the unpinned section." No teleport.

The picker also keeps your selection **on that item** across the
pin/unpin reorder, so you literally watch it stay in place instead of
the highlight jumping to whatever else shuffled into that row.

### How it works

`HistoryStore.togglePin(id:)` now, on the **unpin** branch, lifts the
item to the front of the recency store (`items[0]`). Because
`sortedForDisplay()` renders `pinned (by recency) ++ unpinned (by
recency)`, a most-recent unpinned item sorts to the top of the unpinned
group. The pin branch is unchanged (it keeps its recency slot and gets
hoisted into the pinned block). Storage stays chronological apart from
this one deliberate move; eviction, persistence, and dedup are
unaffected.

`PickerWindow.reload()` gained a `pendingReselectID` that pin/unpin sets
so the highlighted row follows the toggled item by identity rather than
by stale row index.

### What changed

- **`Sources/MultipasteCore/HistoryStore.swift`** — `togglePin` moves
  the item to `items[0]` when unpinning; documented the rationale.
- **`Sources/Multipaste/PickerWindow.swift`** — `reload()` preserves the
  selected item by id (via `pendingReselectID`); `togglePinSelection`
  sets it and the unpin hint now reads "stays here, won't drop back
  down."
- **`Tests/MultipasteCoreTests/HistoryStoreTests.swift`** — rewrote the
  old `unpinningRestoresChronologicalPosition` (which asserted the now-
  unwanted teleport) into `unpinningKeepsItemAtTopOfUnpinned`, and added
  4 guards: `unpinningDoesNotTeleportToOrigin` (the 5-item "super far
  away" scenario), `unpinningLandsBelowRemainingPinned`,
  `unpinMovesItemToFrontOfStorage`, `unpinDoesNotReorderOtherItems`.
- **`Sources/MultipasteCore/Version.swift`** — 2.1.2 → 2.1.3.
- **`Resources/Info.plist`** — `CFBundleShortVersionString` 2.1.2 →
  2.1.3, `CFBundleVersion` 20 → 21.
- **`README.md`** / **`SECURITY.md`** — test count 217 → 221; current
  release noted as 2.1.3.

### Test count

217 → 221 (+5 new unpin tests, −1 rewritten teleport assertion). All
pass in ~0.1s.

### Compatibility

Pure behavioral change to unpinning. No data, preference, or API
changes; drop-in upgrade. Your existing pinned items and history are
untouched.

## 2.1.2 — 2026-05-28

**Hotfix: the single-instance guard no longer SIGTERMs innocent
bystander processes.** `SingleInstance.enforce()` runs at every launch
to kill rival Multipaste instances (so the old LaunchAgent and the
SMAppService Login Item can't both spawn a clipboard daemon). It
decided what counted as a "rival" with:

```swift
guard line.contains("Multipaste.app/Contents/MacOS/Multipaste") else { continue }
```

That matches the binary path **anywhere on a `ps` line — including the
arguments of unrelated processes.** Any shell one-liner, `grep`,
`tail -f`, or editor that referenced the binary path got SIGTERM'd the
instant Multipaste launched. (Found the hard way: it repeatedly killed
the diagnostic shell used while updating a local install across several
versions — every relaunch nuked the very terminal watching it.)

### The fix

Matching now keys on `argv0` — the process's actual **executable**, the
first whitespace-delimited token of the `ps` command column — not on a
substring of the whole command line. A genuine Multipaste process has
`argv0 == …/Multipaste.app/Contents/MacOS/Multipaste`; a bystander
shell has `argv0 == /bin/zsh` and merely mentions the path in later
tokens, so it is correctly left alone.

The parsing moved into a pure, unit-tested helper:
`MultipasteCore/ProcessTable.multipasteSiblingPIDs(psOutput:ownPID:)`.
`SingleInstance.enforce()` keeps its asynchronous pipe-drain (the
v1.6.1 deadlock fix) and now calls the helper instead of an inline
`line.contains` loop.

### What changed

- **`Sources/MultipasteCore/ProcessTable.swift`** (new) — pure
  `ps -Ao pid,command` parser that returns real Multipaste sibling PIDs
  by `argv0`, excluding our own PID, the header row, blank/malformed
  lines, and bystanders that only reference the path in arguments.
- **`Sources/Multipaste/SingleInstance.swift`** — `enforce()` now uses
  `ProcessTable.multipasteSiblingPIDs`; deleted the over-broad
  `line.contains` matching. Added `import MultipasteCore`.
- **`Tests/MultipasteCoreTests/ProcessTableTests.swift`** (new) — 14
  tests: real app matched, `~/Applications` variant matched, shell /
  grep / tail with the path in args all excluded, own-PID excluded,
  multiple real siblings, argv0-with-trailing-args matched, `ps` header
  row skipped, leading-whitespace PID parsed, blank/malformed skipped,
  empty input, unrelated app ignored, and an explicit
  real-world-bug-scenario regression guard.
- **`Tests/MultipasteCoreTests/main.swift`** — registers the new suite.
- **`Sources/MultipasteCore/Version.swift`** — 2.1.1 → 2.1.2.
- **`Resources/Info.plist`** — `CFBundleShortVersionString` 2.1.1 →
  2.1.2, `CFBundleVersion` 19 → 20.
- **`README.md`** / **`SECURITY.md`** — test count 203 → 217; current
  release noted as 2.1.2.

### Test count

203 → 217 (+14 ProcessTable). All pass in ~0.1s.

### Compatibility

Pure behavioral fix to startup process-matching. No data, preference,
or API changes. Upgrading is a drop-in replacement.

## 2.1.1 — 2026-05-28

**Hotfix: the pin button now actually does something.** Rohin reported
(with a screenshot of the picker showing pinned items #1 and #2
highlighted yellow but stuck at the top only because they were the
most-recent ⌘C, not because they were pinned) that pinning was a
visible no-op. The pin button protected against eviction past the
history cap, but that's invisible — every clipboard manager has a
history cap, and "your pinned item didn't get evicted" doesn't feel
like a feature when the item still slides down the list as you ⌘C
new things.

The fix: pinned items now ALWAYS rise to the top of the picker, the
"Recent" menu-bar list, and search results. Unconditionally. The
"Show pinned items at the top of the picker" preference toggle —
which defaulted OFF — is deprecated; the underlying property is
hard-wired to return `true` and ignore writes so any pre-existing
plist with the old false value silently does the right thing on
upgrade.

### How it works

`HistoryStore.sortedForDisplay(pinnedFirst:)` (previously took a
Bool, defaulted to false in callers) lost the parameter — it now
always hoists pinned. `HistoryStore.search(_:pinnedFirst:)` lost
the parameter too. The storage `items` array stays chronological
for eviction / persistence / dedup logic; only USER-facing surfaces
call `sortedForDisplay()`.

`MenuBarController` previously rendered `store.items.prefix(9)` for
its Recent dropdown — raw chronological order — which made the menu
disagree with the picker after pinning. Now uses
`store.sortedForDisplay().prefix(9)` so both surfaces match.

`SettingsWindowController` drops the "Show pinned items at the top
of the picker" checkbox. The Preferences property remains in the
API but is `@available(*, deprecated)` and hard-wired to true.

### What changed

- **`Sources/MultipasteCore/HistoryStore.swift`** — `sortedForDisplay`
  loses the `pinnedFirst` parameter; `search(_:pinnedFirst:)` collapses
  into a single `search(_:)` that always returns pinned-first results.
  Storage `items` invariant unchanged (chronological).
- **`Sources/MultipasteCore/Preferences.swift`** — `pinnedItemsFirst`
  marked `@available(*, deprecated)`. Getter returns `true`
  unconditionally; setter is a no-op. Old plists with the value
  silently do the right thing on next launch.
- **`Sources/Multipaste/PickerWindow.swift`** — picker reload calls
  `store.search(query)` without the (removed) `pinnedFirst` argument.
- **`Sources/Multipaste/MenuBarController.swift`** — Recent dropdown
  builds from `store.sortedForDisplay().prefix(9)` instead of
  `store.items.prefix(9)`.
- **`Sources/Multipaste/SettingsWindowController.swift`** — removes
  the pinned-first checkbox + its hint + the action selector. General
  tab is one row shorter.
- **`Tests/MultipasteCoreTests/HistoryStoreTests.swift`** — pinned-first
  test suite expanded from 3 → 7 tests: drops the parameter-respecting
  cases, adds `pinningOldItemHoistsItToTop` (the Rohin-reported regression
  guard), `unpinningRestoresChronologicalPosition`,
  `searchResultsAreAlwaysPinnedFirst`,
  `itemsStaysChronologicalEvenWhenSortedHoists`.
- **`Tests/MultipasteCoreTests/PreferencesTests.swift`** — two pinned-first
  tests reframed for the deprecation: getter always-true,
  setter no-op.
- **`Sources/MultipasteCore/Version.swift`** — 2.1.0 → 2.1.1.
- **`Resources/Info.plist`** — `CFBundleShortVersionString` 2.1.0 →
  2.1.1, `CFBundleVersion` 18 → 19.
- **`README.md`** — drops "Show pinned items at top" docs from the
  Settings section; the Keys section already mentions ⌘P pin/unpin
  — added a one-line explainer ("Pinned items always show first in
  the picker") next to it. Test count headline 199 → 203.

### Test count

199 → 203 (+4 net: +7 new HistoryStore pin-related tests, -3 old
parameter-respecting tests, +2 new deprecated-Preferences tests, -2
old toggle-persistence tests). All pass in ~0.28s.

### Compatibility

- **Users who never touched the toggle** (the default, off) get the
  new pinned-first behavior automatically — this is the fix.
- **Users who explicitly turned it ON** in 2.1.0: same behavior they
  had, the toggle just isn't visible anymore. Nothing lost.
- **Users who explicitly turned it OFF** (e.g. because they wanted
  pure-recency): the old preference is ignored. If this is you and
  you genuinely want pure recency, open an issue — but the design
  call here is that pin's "protect from eviction" survives without
  hoisting being optional, and hoisting is what users mean when they
  click the pin button.

## 2.1.0 — 2026-05-28

**Headline #1 — auto-copy screenshots to clipboard.** macOS's default
screenshot workflow (⌘⇧3, ⌘⇧4, ⌘⇧5) saves to disk and only copies to the
clipboard when you remember to hold ⌃ (⌃⌘⇧4 etc.). Most people don't —
they screenshot, then drag the file out of Finder into Slack/iMessage/
chat. Now Multipaste auto-copies every screenshot to the clipboard the
moment macOS writes it, so it lands in your history alongside every
other ⌘C and you can just press ⌘V — no extra keystrokes to remember.

**Headline #2 — the "Multipaste vX.Y.Z is available" dialog now
renders markdown properly.** Rohin reported (with a screenshot) that
the v2.0.2 update dialog showed the literal release-notes markdown as
plain text — `## 2.0.2 — 2026-05-16`, `**in-DMG `READ ME FIRST.txt`**`,
`### The bug`, `>` blockquote markers all visible as raw sigils. The
fix is two-pronged:
- `ReleaseNotesFormatter.summary(from:)` (in `MultipasteCore`)
  extracts the **user-facing** portion of the release-notes markdown
  — strips the `## VERSION` header, stops at the first `### `
  engineer-detail subsection. CHANGELOG-author convention going
  forward: put the user-facing summary first, use `### …`
  subsections for "How it works" / "What changed" / etc.
- `MarkdownAttributedString.render(_:)` (in the Multipaste exec
  target) converts inline markdown — `**bold**`, `*italic*`,
  ``` `code` ```, `[link](url)` — into a styled `NSAttributedString`.
  Bold → bold font, italic → italic font, inline code → monospaced
  font + subtle background tint, links → blue + underline + clickable.
- `UpdateService.surfaceUpdate(…)` now shows that styled string in
  a scrollable, non-editable `NSTextView` inside the alert's
  `accessoryView` (instead of the plain-text-only `informativeText`).

This was an embarrassing bug — the painstakingly-formatted CHANGELOG
entries that exist precisely to give users a clear "what's new" were
being displayed as markdown source code in the one place users would
actually read them.

### How it works

1. On launch, read `defaults read com.apple.screencapture` to find the
   user's configured screenshot location (default `~/Desktop`) and
   filename prefix (default `"Screenshot"`).
2. Open the directory with `open(O_EVTONLY)` and attach a
   `DispatchSource.makeFileSystemObjectSource` watcher. On each
   directory-mtime bump, diff the listing against a baseline of paths
   already-seen.
3. For each NEW file whose name matches the screenshot pattern (any of
   `Screenshot 2026-05-28 at 10.13.42 AM.png`,
   `Screenshot_2026-05-28_at_10.13.42.png`, or `Screenshot.png`),
   read the bytes and write to `NSPasteboard.general` as PNG (and TIFF
   as fallback). The existing `ClipboardMonitor` polls `changeCount` at
   300ms and inserts the image into history — no new history pipeline
   needed.

Why `DispatchSource` over `FSEvents`: for a single directory at low
event rate, the C-API ceremony of `FSEventStreamCreate` (retained
context pointers, global callbacks) isn't worth it. The
`makeFileSystemObjectSource` path is two screens of Swift instead of
six, and uses the same kqueue-backed kernel mechanism underneath.

Why we baseline at start: the user may already have hundreds of
existing screenshots on the Desktop when Multipaste launches. We do
NOT want to copy those — they're old. So we snapshot the directory at
`start()` and only react to additions from that point on.

### What changed

- **`Sources/MultipasteCore/ScreenshotDetector.swift`** (new) — pure
  helpers for filename-pattern matching (`isLikelyScreenshot`), macOS
  preference resolution (`resolveLocation`, `resolvePrefix`), and the
  diff-against-baseline core logic (`filterNewScreenshots`). 32 unit
  tests pin every branch.
- **`Sources/Multipaste/ScreenshotWatcher.swift`** (new) — AppKit-bound
  wrapper: opens the directory with `O_EVTONLY`, attaches a
  `DispatchSourceFileSystemObject`, calls into `ScreenshotDetector`
  on each event, and writes the matched files to
  `NSPasteboard.general`. Logs to `~/Library/Logs/Multipaste/multipaste.log`
  for debuggability.
- **`Sources/MultipasteCore/Preferences.swift`** — adds
  `autoCopyScreenshots` toggle, default ON. The whole point of the
  feature is to be on, so we ship it on; users who don't want it can
  flip the checkbox in Preferences → General.
- **`Sources/Multipaste/AppDelegate.swift`** — wires the watcher into
  the app lifecycle alongside `ClipboardMonitor`: `start()` on launch,
  `stop()` on terminate, `reloadSettings()` on toggle.
- **`Sources/Multipaste/SettingsWindowController.swift`** — new
  checkbox "Auto-copy screenshots to clipboard" + a hint line; the
  toggle bounces the watcher via a callback to AppDelegate.
- **`Tests/MultipasteCoreTests/ScreenshotDetectorTests.swift`** (new)
  — 32 tests covering: default English `.png` naming, every accepted
  extension (png/jpg/jpeg/tiff/tif/heic/pdf), uppercase-extension
  tolerance, the underscore-separator variant some third-party tools
  produce, the standalone-prefix corner case (`Screenshot.png`),
  rejection of dotfile temp files, custom-prefix matching, location
  resolution with tilde / absolute / empty / whitespace values,
  custom-name preference, and the diff-against-baseline filter.
- **`Tests/MultipasteCoreTests/PreferencesTests.swift`** — 3 new tests
  for the `autoCopyScreenshots` toggle: default-on, persistence,
  off→on round trip.
- **`Sources/MultipasteCore/ReleaseNotesFormatter.swift`** (new) —
  pure helpers for shaping CHANGELOG markdown into the user-facing
  summary (`summary(from:)`) + a clean-plain-text fallback
  (`cleanPlainText(from:)`). Drops the `## VERSION` header, stops at
  the first `### ` engineer-detail subsection.
- **`Sources/Multipaste/MarkdownAttributedString.swift`** (new) —
  AppKit-bound inline-markdown renderer using Foundation's
  `AttributedString(markdown:)` parser. Translates
  `inlinePresentationIntent` runs into bold / italic / monospaced
  (code) / link styling on an `NSAttributedString` ready for an
  `NSTextView`.
- **`Sources/Multipaste/UpdateService.swift`** — `surfaceUpdate(…)`
  now extracts the summary, renders the markdown, and shows it in
  a scrollable, non-editable `NSTextView` inside the alert's
  `accessoryView`. The plain-text `informativeText` is now just a
  single "You're running X.Y.Z. Here's what's new:" line.
- **`Tests/MultipasteCoreTests/ReleaseNotesFormatterTests.swift`**
  (new) — 20 tests covering every branch of both helpers, including
  a regression guard that exercises the literal v2.0.2 CHANGELOG
  markdown Rohin reported in the dialog screenshot.
- **`Tests/MultipasteCoreTests/PreferencesTests.swift`** — 3 new tests
  for the `autoCopyScreenshots` toggle: default-on, persistence,
  off→on round trip.
- **`Tests/MultipasteCoreTests/main.swift`** — registers the new
  `ScreenshotDetector` and `ReleaseNotesFormatter` suites.
- **`scripts/screenshot-smoke-test.swift`** (new) — end-to-end
  integration smoke test for the screenshot-to-clipboard pipeline.
- **`scripts/preview-update-dialog.swift`** (new) — visual preview
  of the update dialog that pops it up with the literal v2.0.2
  CHANGELOG markdown for inspection.
- **`Makefile`** — adds `smoke-test` and `preview-update-dialog`
  targets.
- **`Sources/MultipasteCore/Version.swift`** — 2.0.2 → 2.1.0.
- **`Resources/Info.plist`** — `CFBundleShortVersionString` 2.0.2 →
  2.1.0, `CFBundleVersion` 17 → 18.
- **`README.md`** — new "Screenshots → clipboard" section above
  "File copy → path text"; hero CTA + Easy-install link bumped to
  `Multipaste-2.1.0.dmg`; test-count headline bumped 144 → 199;
  test-coverage table grew with new `ScreenshotDetector` and
  `ReleaseNotesFormatter` rows.
- **`SECURITY.md`** — supported-versions table now lists `2.1.x` as
  the current release and `2.0.x` as best-effort.

### Test count

144 → 199 (+32 ScreenshotDetector, +3 Preferences extensions,
+20 ReleaseNotesFormatter). All tests pass in ~0.3s on Apple Silicon.

### Compatibility

- **Existing users**: prefs default to ON. Granted Accessibility
  carries across the version bump (the designated requirement is by
  bundle ID, not cdhash — see "TCC indexes by cdhash" in the
  "bugs we fixed" section of README). No re-grant needed.
- **First-run Desktop access prompt**: on first launch after 2.1.0,
  macOS prompts "Multipaste would like to access files in your Desktop
  folder" (or whatever your screenshot location is). This is a TCC
  prompt for the new directory-read; granting once is permanent.
  Denying it makes the watcher silently no-op (logged in
  `multipaste.log`), the rest of the app works normally.
- **Pause Monitoring** menu item: pauses history insertion but does
  NOT pause the screenshot watcher. The screenshot still lands on the
  clipboard for downstream ⌘V; it just doesn't enter history. This
  matches the existing pause semantics (the OS-level clipboard write
  still happens; we only suppress our own bookkeeping).

## 2.0.2 — 2026-05-16

Hotfix: the **in-DMG `READ ME FIRST.txt`** told users to double-click
Multipaste on first launch — which doesn't work for an ad-hoc-signed
app downloaded from the internet.

### The bug

Multipaste is ad-hoc signed (no Apple Developer ID — we'd need a $99/yr
Apple Developer Program membership for that). Apps without Developer ID
signing trigger Gatekeeper on first launch. When a user double-clicks
the app, macOS shows:

> "Multipaste cannot be opened because the developer cannot be verified."
>
> [Cancel] [Move to Bin]

**There is no Open button.** The user is stuck — they have to know the
control-click → Open workaround that produces a different dialog:

> "macOS cannot verify the developer of 'Multipaste'. Are you sure you
> want to open it?"
>
> [Cancel] [**Open**]

The in-DMG README's step 2 said "double-click", and step 3 then
described the Open button — but those two steps are mutually exclusive
flows. A user following the steps as written would get stuck at step 2.

The main `README.md` had the correct control-click instructions; only
the in-DMG README was wrong. (The main README's audience already has
GitHub open, so they typically didn't hit the bug.)

### The fix

`scripts/dmg.sh` rewrites the `READ ME FIRST.txt` heredoc with the
accurate Gatekeeper flow:

```
3. CONTROL-CLICK (or right-click) on Multipaste, then choose Open.
   macOS will ask "macOS cannot verify the developer of 'Multipaste'.
   Are you sure you want to open it?" — click Open.

   Why not just double-click on first launch? Double-clicking a
   downloaded app that isn't signed by an Apple-registered developer
   shows a dialog with NO Open button — just Cancel and Move to Bin.
   The control-click route is the standard Gatekeeper bypass for
   indie apps. You only do this once; every subsequent launch is an
   ordinary double-click.

   If control-click → Open doesn't show an Open button (this can
   happen on some macOS 15 Sequoia configurations): open System
   Settings → Privacy & Security → scroll to the bottom → click
   "Open Anyway" next to "Multipaste was blocked...".
```

Also expanded step 4 to walk through the Welcome window's Login Item +
Accessibility flow, and added a Homebrew-users note ("`brew install
--cask` removes the quarantine flag, so you can skip step 3 entirely").

### What changed

- **`scripts/dmg.sh`** — `READ ME FIRST.txt` heredoc rewritten with
  the accurate control-click instructions + macOS 15 Sequoia fallback
  + Homebrew-skip-step-3 note.
- **`Sources/MultipasteCore/Version.swift`** — 2.0.1 → 2.0.2.
- **`Resources/Info.plist`** — `CFBundleShortVersionString` 2.0.1 →
  2.0.2, `CFBundleVersion` 16 → 17.
- **`README.md`** — hero CTA: `↓ Download v2.0.2 (universal — Intel
  + Apple Silicon)`. Easy-install link points at `Multipaste-2.0.2.dmg`.
  Latest-release badge bumped to v2.0.2. The Easy-install section's
  control-click instructions were already correct in v2.0.1 — no
  change needed there.
- **`Tests/MultipasteCoreTests/BuildScriptTests.swift`** — suite
  grew 2 → 4 tests. New: `dmgReadmeUsesControlClickNotDoubleClick`
  locates the `READ ME FIRST.txt` heredoc in `scripts/dmg.sh` and
  asserts it mentions control-click / right-click, references the
  Open button, and does NOT instruct users to "double-click
  Multipaste" as the first-launch action. New:
  `dmgReadmeMentionsSystemSettingsFallback` asserts the heredoc
  mentions System Settings → Privacy & Security as the macOS 15
  Sequoia fallback.
- **`CHANGELOG.md`** — this entry.

### Compatibility

- **Anyone installing from the v2.0.2 DMG** — the in-DMG README is
  now accurate. Control-click → Open on first launch, double-click
  every time after.
- **Apple Silicon + Intel users** — unchanged from v2.0.1's universal
  binary. v2.0.2 is also a universal DMG.
- **Homebrew users** — unchanged. `brew install --cask
  NewdlDewdl/multipaste/multipaste` continues to remove the
  quarantine flag automatically, so Gatekeeper doesn't trigger and
  step 3 is skipped entirely. `brew upgrade --cask multipaste`
  pulls v2.0.2 after your next `brew update`.

Test count: **144** (was 142). All passing.

The 2.0.1 → 2.0.2 release is a docs-only fix; same universal binary,
same code paths, same License + Contribution + chooser infrastructure.

## 2.0.1 — 2026-05-16

Hotfix: ship a **universal binary** (arm64 + x86_64) so Intel Macs can
actually open Multipaste.

### The bug

v2.0.0's `scripts/build.sh` did:

```sh
ARCH="$(uname -m)"
swift build -c release --arch "$ARCH" --product Multipaste
```

— it built only for the *build host's* architecture. Built on an M1
Mac mini, the v2.0.0 DMG shipped an **arm64-only** binary. Friends on
Intel Macs downloaded it and got the exact macOS error:

> "You can't open the application 'Multipaste' because this application
> is not supported on this Mac."

That's macOS's wording for an architecture mismatch (NOT a macOS-version
mismatch — Multipaste's minimum is still macOS 13 Ventura, and the
friend who reported this is on 13.7.8). The Multipaste binary literally
had no x86_64 slice, so the loader refused to start it.

### The fix

`scripts/build.sh` now defaults to building both architectures and
combining them with `lipo -create`:

```sh
ARCHS="${MULTIPASTE_BUILD_ARCHS:-arm64 x86_64}"
for ARCH in $ARCHS; do
    swift build -c release --arch "$ARCH" --product Multipaste
    PER_ARCH_BINS+=("$(swift build … --show-bin-path)/Multipaste")
done
lipo -create -output "$APP/Contents/MacOS/Multipaste" "${PER_ARCH_BINS[@]}"
```

After assembly, the script runs `lipo -archs` on the embedded binary
and **fails the build** if any requested architecture is missing —
the load-bearing regression guard that makes this bug class impossible
to ship from a single-arch developer machine again.

Override knob: `MULTIPASTE_BUILD_ARCHS="arm64"` (or `"x86_64"`) for
single-arch builds during local development if you don't want to wait
for both. Default is universal.

### What changed

- **`scripts/build.sh`** — rewritten to iterate over `$ARCHS` and use
  `lipo -create` for the final binary; new verification step at the
  end fails the build if any requested arch is missing from the
  output binary.
- **`Sources/MultipasteCore/Version.swift`** — `2.0.0` → `2.0.1`.
- **`Resources/Info.plist`** — `CFBundleShortVersionString` `2.0.0`
  → `2.0.1`, `CFBundleVersion` `15` → `16`. `LSMinimumSystemVersion`
  unchanged at `13.0` — this is an Intel-compatibility fix, NOT a
  macOS-version raise.
- **`README.md`** — hero CTA now reads
  *"↓ Download v2.0.1 (universal — Intel + Apple Silicon)"*. Easy-install
  link points at `Multipaste-2.0.1.dmg`. Badge row gained
  *"Universal (Intel + Apple Silicon)"*. Test count badges 133 → 135
  (two new BuildScript tests added).
- **`Tests/MultipasteCoreTests/BuildScriptTests.swift`** — NEW
  suite, 2 tests:
    1. `buildShDefaultsToUniversal` — asserts `scripts/build.sh`
       defines `ARCHS` with the universal default
       `"${MULTIPASTE_BUILD_ARCHS:-arm64 x86_64}"`.
    2. `buildShVerifiesEmbeddedArchitectures` — asserts
       `scripts/build.sh` contains the `lipo -create` step AND the
       `lipo -archs` post-build verification AND the descriptive
       failure message. The fix-shape itself is now tested.

### Compatibility

- **Intel Mac users on macOS 13 Ventura or later** — v2.0.1 is the
  first release that actually opens. Apologies to anyone who tried
  v2.0.0 and saw the "not supported" error.
- **Apple Silicon users** — no change in behavior; the universal
  binary still has an arm64 slice. The DMG is roughly 2× larger
  (~900 KB instead of ~460 KB) because it now contains both arch
  slices, but everything else is identical.
- **Source builders** — single-arch builds still work via the
  `MULTIPASTE_BUILD_ARCHS` override. Default is universal.
- **Homebrew tap** — cask bumps to version 2.0.1 with the new
  sha256 in a follow-up commit to the
  [NewdlDewdl/homebrew-multipaste](https://github.com/NewdlDewdl/homebrew-multipaste)
  tap.

The 2.0.0 → 2.0.1 release is feature-identical otherwise — same
clipboard history, same snippet expansion, same License + Contribution
+ chooser infrastructure. Just runs on Intel now.

### Post-2.0.1 audit + lock-down (no version bump)

After shipping v2.0.1 to the Intel-Ventura friend, did a deep audit
to confirm he wouldn't hit ANY OTHER issues after the universal-
binary fix. Audit covered: API availability (anything macOS 14+
would crash on 13.7.8), force unwraps + crash points on the launch
path, threading + async correctness (timer modes, pipe drains,
RunLoop scheduling), Info.plist completeness, hardened-runtime
entitlements, regression of the four historical Accessibility/TCC
bugs (1.5.0 / 1.6.0 / 1.6.1), unresolved TODO/FIXME, and the
first-launch path.

Audit verdict: **clean.** No HIGH/MEDIUM/LOW findings. All four
historical bug fixes still in place. No macOS 14+ APIs used (only
`#available(macOS 13.0, *)` guards exist, which Ventura satisfies).
No risky force unwraps on the launch path. Timer scheduled in
`.common` mode. Pipe drained async. Bundle structure complete and
correctly signed.

Codified the verified properties so they stay verified:

- **`Tests/MultipasteCoreTests/InfoPlistTests.swift`** — NEW suite,
  7 tests:
    1. `bundleIdentifierMatchesSwift` — Info.plist
       `CFBundleIdentifier` matches Swift's
       `MultipasteVersion.bundleIdentifier`. Drift breaks every
       TCC grant, Login Item, preference, and launch agent
       (everything keyed by bundle ID).
    2. `packageTypeIsAPPL` — `CFBundlePackageType` is exactly
       `APPL` (without this macOS doesn't recognize the bundle
       as an app).
    3. `principalClassIsNSApplication` — required for AppKit apps.
    4. `isMenuBarOnlyApp` — `LSUIElement` is true. Without this
       Multipaste shows a Dock icon and ⌘W behaves wrong.
    5. `minimumSystemVersionIs13` — `LSMinimumSystemVersion` is
       `13.0`. Test failure indicates someone raised the floor —
       if intentional, update SECURITY.md's supported-versions
       table too.
    6. `hasAppleEventsUsageDescription` — present + non-empty +
       mentions Multipaste/paste. macOS displays it on first
       Apple Events use; a missing string can cause silent denial.
    7. `copyrightReferencesPolyFormStrictAndCommercialEmail` —
       `NSHumanReadableCopyright` mentions PolyForm Strict + the
       commercial-license email. Finder → Get Info surfaces this.

- **`Makefile`** — new `make verify-app` target. Runs after `make
  build` (or as release-prep) to confirm the BUILT bundle (not just
  the source) is correct: lipo asserts both archs are present in
  the embedded binary, `codesign --verify --deep --strict` passes,
  `CFBundleShortVersionString` matches `Version.swift`,
  `LSMinimumSystemVersion` is `13.0`. Fails non-zero on any check.
  Verified end-to-end against the actual v2.0.1 release bundle —
  all 4 checks green.

- README.md `Tests:` badge bumped 135 → 142. Test-coverage table
  gained an `InfoPlist` row. `make` reference list mentions the
  new `verify-app` target.

Audit-summary results (file:line evidence in the audit trail):

- All 4 historical bugs still fixed:
  - v1.5.0 timer-paused-in-modal: `PermissionMonitor.swift:80-109`
    (RunLoop.main + .common mode) ✓
  - v1.6.0 cdhash drift: `build.sh:82` (designated requirement
    by bundle ID) ✓
  - v1.6.0 LaunchAgent TCC loss: `AppDelegate.swift:139-161`
    (SMAppService migration) ✓
  - v1.6.1 pipe deadlock: `SingleInstance.swift:37-54`
    (async readabilityHandler before waitUntilExit) ✓

- No macOS 14+ APIs anywhere in Sources/.
- No `try!` anywhere in Sources/.
- Only `fatalError()` calls are in `init?(coder:)` initializers
  that are never invoked at runtime (NSView/NSWindow subclasses
  that don't support coder-based init).
- No TODO/FIXME/XXX/HACK comments in Sources/.

Test count: **142** (was 135). All passing in ~81 ms.

## 2.0.0 — 2026-05-16

Relicensed from MIT to **PolyForm Strict License 1.0.0** — the most
restrictive license in the
[PolyForm](https://polyformproject.org/) family of source-available
licenses. Source remains publicly visible; commercial use, distribution,
and derivative works now require a separate written license from the
author.

This is a **breaking change** for any commercial user of Multipaste
(which, to my knowledge, is currently nobody — but the major version
bump is honest signal that the legal posture has changed). Hence
1.9.0 → **2.0.0**, not 1.10.0.

### Why this license

The MIT license used through 1.9.0 was a giveaway — anyone could
embed Multipaste's combined clipboard-history + snippet-expansion
engine into a closed-source product and resell it without
attribution beyond the LICENSE.md notice. That's fine for a finished
hobby project; it's the wrong default while the option of turning
Multipaste into a commercial product is still on the table.

Three licenses were considered and rejected before landing on
PolyForm Strict:

- **MIT (status quo)** — too permissive; gives away every commercial
  right. Rejected: preserves no path to a paid future product.
- **GNU AGPL-3.0-or-later** — strongest standard copyleft, network-use
  clause closes the SaaS loophole. Rejected: still allows competing
  commercial forks (as long as they ship source under AGPL too), and
  would force *my own* future commercial product to be AGPL —
  defeating the point of the option I want to preserve.
- **PolyForm Noncommercial 1.0.0** — noncommercial use with
  derivatives permitted. Rejected: PolyForm Strict is strictly tighter
  (no derivative works at all) and there is no reason to give away the
  derivative right when the goal is maximum lockdown short of going
  fully proprietary.

**PolyForm Strict 1.0.0** is the answer because it:

1. Restricts use to noncommercial purposes only — personal, hobby,
   research, charity, education, government.
2. Forbids derivative works and redistribution entirely, even
   noncommercial ones, by anyone but the licensor.
3. Keeps source publicly visible — users, security researchers, and
   curious engineers can audit every line.
4. Preserves the path to going fully proprietary: as sole copyright
   holder I can release any future version under any license,
   including a closed-source commercial EULA, without permission from
   anyone.

It is the most restrictive recognized source-available license
short of "all rights reserved with public source," which is not a
standardized license at all and would surprise readers.

### What changed

- **`LICENSE.md`** — replaced the 22-line MIT `LICENSE` (bare, no
  extension) with a 75-line `LICENSE.md`: a 14-line project copyright
  header (sets out commercial-licensing contact and plain-English summary
  of the noncommercial restriction) followed by the verbatim 59-line
  canonical PolyForm Strict 1.0.0 markdown from
  <https://github.com/polyformproject/polyform-licenses/blob/1.0.0/PolyForm-Strict-1.0.0.md>.
  The license body is byte-for-byte identical to the PolyForm canonical
  text. The `.md` extension matters: PolyForm canonical text uses
  markdown (headings, autolinks, emphasis), and only with the `.md`
  extension will GitHub and other viewers render it as formatted text
  instead of showing raw `#`/`##`/`**` syntax. PolyForm's own guidance
  also recommends `LICENSE.md`.
- **`Resources/Info.plist`** — `CFBundleShortVersionString` bumped to
  `2.0.0`, `CFBundleVersion` to `15`. `NSHumanReadableCopyright` now
  reads `Copyright © 2026 Rohin Agrawal. Source-available under the
  PolyForm Strict License 1.0.0. Noncommercial use only; commercial
  licensing: rohin.agrawal@gmail.com`. Surfaces in Finder Get Info and
  in About dialogs.
- **`Sources/MultipasteCore/Version.swift`** — `1.9.0` → `2.0.0`.
- **`Sources/Multipaste/SettingsWindowController.swift`** — the About
  tab footer was `Made for Rohin. MIT licensed.`; now reads
  `Made for Rohin. Source-available under PolyForm Strict 1.0.0.
  Noncommercial use only — commercial licensing on request.` plus
  the source-repo URL.
- **`README.md`** —
  - Header badge: `v2.0.0` and `License: PolyForm Strict 1.0.0
    (source-available, noncommercial)`.
  - Comparison-table License row: Multipaste column flips from
    `MIT` to `**PolyForm Strict**²` with footnote.
  - Comparison-table "Open source" row: Multipaste column changes
    from `✓` to `src-avail²` — honest about not being OSI-approved
    open source.
  - Two footnotes added under the table: one explaining noncommercial
    pricing (and the commercial-licensing email), one explaining
    PolyForm Strict's source-available-but-not-open-source status.
  - "Why pick Multipaste" bullet: `Free + open source` → `Free for
    personal use + source-available`.
  - Full License section rewritten: enumerates the five things you
    *can* do (personal use, noncommercial-org use, source reading,
    issue filing, fair use) and the four things you *cannot* do
    (redistribute, distribute modifications, commercial use, fork as
    competitor); explains why this license was chosen over MIT,
    Apache, and AGPL; lists patent/warranty caveats and the 32-day
    violation cure period.
- **`CHANGELOG.md`** — this entry.
- **`Tests/MultipasteCoreTests/LicenseTests.swift`** — 13 tests that
  lock the LICENSE.md down so this can't silently regress to MIT,
  AGPL, or PolyForm Noncommercial. They read the file at the package
  root and assert: file exists and is named `LICENSE.md` (with `.md`
  extension — regression-tested), PolyForm Strict 1.0.0 title,
  canonical PolyForm URL, project copyright header with commercial-
  license contact, the "Copyright License" clause's verbatim "other
  than distributing the software or making changes" language (the
  Strict-defining no-distribution/no-derivatives clause), the
  "Noncommercial Purposes" / "Personal Uses" / "Noncommercial
  Organizations" sections, the Patent Defense clause, the 32-day cure
  period, the "No Liability" warranty disclaimer, absence of any
  leftover MIT permission grant, absence of any AGPL/GPL/Affero text,
  absence of PolyForm Noncommercial title (wrong PolyForm variant),
  absence of a stray bare-`LICENSE` file splitting the source of
  truth, line count in the 75–90 range, and the header's pointer at
  CONTRIBUTING.md / the Contributor License Agreement.
- Test count: **102** (was 83) — see also the new
  `ContributionTests` suite documented under "Contribution
  infrastructure" below.

### Compatibility

- **For personal users / hobbyists / researchers / charities /
  schools / governments**: no change — Multipaste is still free and
  the binary still works the same. Download the DMG, install via
  Homebrew, run it. The PolyForm Strict "Personal Uses" and
  "Noncommercial Organizations" clauses explicitly cover all these
  cases.
- **For anyone using Multipaste at a for-profit company**: this is a
  breaking change. You can still run the personal-use installation on
  your own machine for non-work activity, but using Multipaste as part
  of your job at a commercial entity is no longer permitted under the
  default license. Email <rohin.agrawal@gmail.com> for a commercial
  license; pricing TBD.
- **For redistributors / forkers / re-packagers**: this is a breaking
  change. PolyForm Strict forbids redistribution and derivative works
  entirely. The official distribution channels are GitHub Releases and
  the `NewdlDewdl/multipaste` Homebrew tap, both of which point at the
  original binary; no mirrors, no forks, no patched builds may be
  published.
- **Homebrew tap**: still works. The cask recipe points users at the
  official GitHub Releases URL — it's metadata, not redistribution.
- **GitHub source visibility**: still public. PolyForm Strict is
  source-available; reading the source on github.com is not
  redistribution, and forking the repo on GitHub for personal study is
  covered by the "Personal Uses" clause as long as you don't publish
  modifications.
- **Previous releases (≤1.9.0)**: remain under their original MIT
  license. PolyForm Strict applies to 2.0.0 and later. If you need
  a permissive license, the 1.9.0 source is still on GitHub at the
  `v1.9.0` tag, MIT-licensed in perpetuity.

### Contribution infrastructure (added post-relicense)

PolyForm Strict's "Copyright License" clause forbids derivative works
and distribution — which technically forbids the act of opening a PR
(fork = distribute, modify = derivative work). To make contributions
legally possible, the relicense ships with a complete contribution
infrastructure built around a **Contributor License Agreement (CLA)**.
This is the same pattern HashiCorp, Sentry, MongoDB, and other
source-available projects use.

- **`CONTRIBUTING.md`** — full CLA at the package root. Contributors
  retain copyright in their contributions but grant the licensor a
  perpetual, worldwide, royalty-free, irrevocable license to
  reproduce, modify, distribute, sublicense, and — most importantly —
  **relicense** the contribution under any future terms, including
  fully proprietary closed-source. Also includes a one-time, scoped
  reciprocal permission for the contributor to make the proposed
  changes despite PolyForm Strict's general prohibition (the
  mechanism that makes the PR legal at all). Plus patent grant,
  representations, what kinds of contributions are welcome, and the
  fork/branch/test/commit/PR workflow.
- **`.github/PULL_REQUEST_TEMPLATE.md`** — auto-loaded by GitHub on
  PR creation. Asks for summary / why / what-changed / testing, plus
  5 CLA checkboxes the contributor must check (CONTRIBUTING.md read,
  license grant, relicensing right specifically called out, entitled
  to grant, no infringement). The relicensing checkbox is flagged as
  "the unusual clause; please read it before checking the box."
- **`.github/ISSUE_TEMPLATE/bug_report.md`** — auto-loaded for new
  bug-report issues. Prompts for macOS version, Multipaste version,
  install method (DMG / Homebrew / source), Apple Silicon or Intel,
  steps to reproduce, log tail from
  `~/Library/Logs/Multipaste/multipaste.log`, and screenshots.
  Security issues are routed to email instead of public issues.
- **`LICENSE.md` header** — gained a 6-line note pointing contributors
  at CONTRIBUTING.md so they discover the CLA without hunting for it.
  License body unchanged; PolyForm canonical text remains byte-for-byte.
- **`README.md`** — new "Contributing" section after the License
  section. Spells out the unusual-by-default CLA terms (perpetual /
  irrevocable / relicensing right / one-time scoped permission to
  contribute) so contributors aren't ambushed by the agreement.
  Points at the bug-report template for issues.
- **`Tests/MultipasteCoreTests/ContributionTests.swift`** — NEW
  suite, 6 tests: `CONTRIBUTING.md` exists at package root; CLA
  contains "perpetual / worldwide / royalty-free / irrevocable"
  magic words; relicensing clause explicitly mentions "proprietary"
  and "closed-source"; PolyForm Strict context is explained; PR
  template exists, links to CONTRIBUTING.md, references CLA, has
  checkboxes, and explicitly calls out the relicensing clause;
  bug-report issue template exists with YAML front-matter, asks for
  macOS and Multipaste versions.
- **`Tests/MultipasteCoreTests/LicenseTests.swift`** — added
  `License/hasContributionPointer` test asserting the LICENSE.md
  header now references CONTRIBUTING.md and the Contributor License
  Agreement. Also bumped `lineCountInExpectedRange` from 70–80 to
  75–90 to accommodate the new 6-line contribution-pointer block.
- Test count: **102** (was 95).

### PolyForm standards compliance (added post-relicense)

Adopted every recommendation from
<https://github.com/polyformproject/polyformproject.org> so that
license-detection tools (licensee, FOSSology, scancode, GitHub's
license-detection, the REUSE tool) can correctly identify Multipaste's
license, and so that downstream auditors / package managers /
SBOM-generators see consistent metadata everywhere they look.

PolyForm Strict 1.0.0 is **not** on the SPDX standard license list
(only `PolyForm-Noncommercial-1.0.0` and `PolyForm-Small-Business-1.0.0`
are). The SPDX convention for non-standard licenses is the
`LicenseRef-` prefix, so Multipaste's machine-readable identifier
everywhere is **`LicenseRef-PolyForm-Strict-1.0.0`**.

Added:

- **`REUSE.toml`** — declares `SPDX-License-Identifier =
  "LicenseRef-PolyForm-Strict-1.0.0"` and
  `SPDX-FileCopyrightText = "Copyright (c) 2026 Rohin Agrawal"` for
  every path-glob in the repo (Sources/, Tests/, scripts/, Resources/,
  LaunchAgent/, root docs, .github/, LICENSE.md, LICENSES/).
  Follows the [REUSE Specification](https://reuse.software/spec/)
  format used by the Linux Foundation, KDE, Mozilla, and others.
- **`.licensee.json`** — tells the [licensee
  gem](https://github.com/licensee/licensee) (used by GitHub's
  license-detection) that the project is under
  `LicenseRef-PolyForm-Strict-1.0.0` instead of having it guess
  against the SPDX standard list and fail.
- **`LICENSES/LicenseRef-PolyForm-Strict-1.0.0.md`** — symlink to
  `../LICENSE.md` at the REUSE-canonical path. The REUSE tool walks
  this directory to discover licenses by SPDX ID; without it, REUSE
  emits "missing license file" warnings even when LICENSE.md is
  present.
- **`PolyForm Strict 1.0.0` badge in README.md** — clickable image at
  the canonical `https://polyformproject.org/strict.png` URL,
  linking to <https://polyformproject.org/licenses/strict/1.0.0/>.
  Same badge the PolyForm Project uses on its own licenses
  comparison page. Placed inside the **License section** (not in
  the intro header) with `width="80"` and `align="right"` so it's
  contextual polish — credit to the PolyForm Project + a working
  click-through to the canonical license page — without being a
  giant intimidating "STRICT" wall above the install instructions.
  An iteration-1 placement at the top of the README was caught as
  intimidating to non-developer users browsing the repo to download
  a clipboard manager, and moved. A regression test
  (`LicensingMetadata/readmeBadgeIsNotInIntroHeader`) asserts the
  badge URL doesn't appear in the first 30 lines of README.md, so
  it can't silently migrate back upward.

Modified:

- **All 41 `.swift` source files** (under `Sources/` and `Tests/`)
  gained a 2-line SPDX header at the very top:
  ```
  // SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
  // SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
  ```
  This is the per-file-header form prescribed by the SPDX spec and
  is what FOSSology / scancode look for when scanning source.
- **`Package.swift`** — gained the same SPDX header (after the
  required `// swift-tools-version:5.9` line, which SwiftPM mandates
  on line 1) plus a short pointer at LICENSE.md / REUSE.toml.

Tests:

- **`Tests/MultipasteCoreTests/LicensingMetadataTests.swift`** — NEW
  suite, 11 tests covering REUSE.toml existence + content,
  .licensee.json existence + JSON-validity + content, LICENSES/
  canonical file existence + symlink-integrity (content matches
  LICENSE.md exactly), every `.swift` file under Sources/ and Tests/
  has SPDX-License-Identifier + SPDX-FileCopyrightText in the top 5
  lines, Package.swift has SPDX header after the swift-tools-version
  directive, README contains the canonical PolyForm badge URL and
  the canonical license URL.

Upstream:

- Opened [polyformproject/polyformproject.org#3](https://github.com/polyformproject/polyformproject.org/pull/3)
  adding Multipaste to the auto-generated
  [adopters showcase](https://polyformproject.org/adopters):
  `adopters/multipaste.md` (description + license link) and
  `adopters/multipaste.png` (resized 256×256 app icon).

- Test count: **113** (was 102).

### Issue-template chooser + SECURITY.md (added post-relicense)

Replaced the single-template `bug_report.md` with a full GitHub issue
chooser per
<https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository>.
Users opening a new issue now see four contact-link off-ramps
(security email, commercial-licensing email, Discussions, CONTRIBUTING.md)
followed by two structured YAML forms (bug report, feature request)
with required fields, dropdowns, and CLA-acknowledgment checkboxes.
Blank issues are disabled.

Side effect: enabled GitHub Discussions on the repo so the chooser's
"General discussion / questions" off-ramp has a destination.

Added:

- **`.github/ISSUE_TEMPLATE/bug_report.yml`** — modern YAML issue
  form. Replaces the markdown template. Required fields: pre-flight
  checkboxes (searched issues, on latest release, not a security
  vuln), what happened, expected behavior, steps to reproduce,
  macOS version, Multipaste version, install-method dropdown,
  architecture dropdown. Optional fields: other clipboard managers,
  logs (rendered as shell block), screenshots, anything else. The
  required-fields validation means contributors can't accidentally
  submit a report missing the macOS version or repro steps.

- **`.github/ISSUE_TEMPLATE/feature_request.yml`** — modern YAML
  issue form. Required fields: pre-flight checkboxes (searched
  existing, read CONTRIBUTING), what problem are you solving (the
  underlying need, not the solution), ideal solution from user's
  perspective, importance dropdown (nice to have / improves my
  workflow / blocking my use). Optional fields: alternatives
  considered, additional context, **and three CLA-acknowledgment
  checkboxes** that fire only if the contributor offers to
  implement the feature themselves — including specific
  acknowledgment of CLA §1.4 (the relicensing right). This
  surfaces the unusual clause at feature-request time so it isn't
  a surprise when the PR lands.

- **`.github/ISSUE_TEMPLATE/config.yml`** — the chooser
  configuration. Sets `blank_issues_enabled: false` (forces users
  into a template) and adds four `contact_links`:
  - 🔐 Security vulnerability (private disclosure) — mailto link.
  - 💼 Commercial licensing inquiry — mailto link.
  - 💬 General discussion / questions — Discussions URL.
  - 📖 Read CONTRIBUTING.md before opening a feature request —
    repo URL.

- **`SECURITY.md`** at repo root — responsible-disclosure policy
  that the chooser routes security reports to. Documents which
  versions are supported (2.0.x ✅, 1.9.x ⚠️ best-effort, <1.9 ❌),
  the reporting channel (email + subject convention + explicit
  "don't open a public issue" wording), what to include in a
  report, what to expect from the maintainer (7-day acknowledgment,
  30-day investigation, patch release for confirmed criticals,
  public advisory after fix), and an explicit in-scope / out-of-
  scope section that acknowledges Multipaste's threat model (it
  reads the clipboard by design; that is the feature, not a
  vulnerability; `org.nspasteboard.org` privacy markers are how
  apps opt out).

Modified:

- **`CONTRIBUTING.md`** — "How to report a bug" section rewritten
  to describe the new YAML form's required fields and the chooser.
  New "How to propose a feature" section explaining the
  feature-request form and its CLA-acknowledgment checkboxes. New
  "Is this a bug?" pointer at GitHub Discussions.

- **`Tests/MultipasteCoreTests/ContributionTests.swift`** — removed
  the now-stale `issueTemplateExists` test (which expected the old
  `bug_report.md`). The replacement coverage lives in the new
  `IssueChooser` suite.

- **`Tests/MultipasteCoreTests/IssueChooserTests.swift`** — NEW
  suite, 8 tests:
  1. `bug_report.yml` exists, is a YAML form (has `name:`,
     `description:`, `body:`), required fields are present
     (macOS version, Multipaste version, install method,
     architecture, repro steps), `required: true` count ≥ 5,
     security reports are routed to email instead of the form.
  2. `feature_request.yml` exists, is a YAML form, references
     the Contributor License Agreement and specifically the
     relicensing clause, links to CONTRIBUTING.md, asks about
     importance.
  3. `config.yml` exists with `blank_issues_enabled: false`.
  4. `config.yml` has the four required contact links (Security,
     Commercial, Discussions, CONTRIBUTING) with correct email
     destinations and the Discussions URL.
  5. Old `bug_report.md` is gone (guards against accidental
     resurrection that would split the chooser).
  6. `SECURITY.md` exists at repo root (where GitHub looks).
  7. `SECURITY.md` documents the reporting channel
     (`rohin.agrawal@gmail.com` + subject convention + "don't
     open a public issue" wording).
  8. `SECURITY.md` documents supported versions (mentions 2.0.x).

- **`README.md`** — test count bumped 113 → 120 in the badge,
  architecture description, two `make test` blocks, and the
  Tests-coverage table totals. Added an `IssueChooser` row to the
  table summarizing the 8 new tests.

- **`Tests/MultipasteCoreTests/main.swift`** — registers
  `IssueChooserTests.registerAll()`.

- Test count: **120** (was 113). All passing in ~62 ms.

The 1.9.0 → 2.0.0 release is otherwise feature-identical.

### README beautification (added post-relicense)

The README intro was a wall of text under a `# Multipaste` h1. Friendly
to skimmers, but it didn't *look* like a polished macOS app — the
project icon never appeared, and the entire first screen was prose +
text badges. This change adds the standard polished-macOS-README
treatment: centered logo hero, large h1, single-sentence tagline,
prominent Download CTA, quick-nav row, and the ASCII demo all centered
above the divider.

Added:

- **`Resources/icon-256.png`** — 256×256 PNG resized from the existing
  `icon-1024.png` (2048×2048) via `sips`. 13 KB. Used as the hero
  image in the README; not bundled into the .app (the .app uses the
  `.icns`).

- **`Tests/MultipasteCoreTests/ReadmePolishTests.swift`** — NEW
  suite, 4 tests locking the README hero design in so it can't
  silently regress:
  1. `logoFileExistsAtExpectedPath` — the file is present and has
     valid PNG magic bytes (catches a corrupt or wrong-format file).
  2. `readmeHasCenteredLogoHero` — README intro has the
     `<p align="center">` hero wrapper, references the logo at
     `Resources/icon-256.png`, sets an explicit `width="192"`,
     has meaningful alt text mentioning Multipaste, and is followed
     by a centered `<h1>Multipaste</h1>`.
  3. `readmeHasQuickNavLinks` — intro has at least 4 of the 7
     expected section anchors (Install / Keys / Snippets / Compare
     / Privacy / License / Contribute), so users can jump without
     scrolling 700 lines.
  4. `readmeHasDownloadCallToAction` — intro has a bold "Download"
     link to `releases/latest`, sized to invite the click.

Modified:

- **`README.md`** — completely restructured top 30 lines. New
  hero block: centered logo (192×192) → `<h1>Multipaste</h1>` →
  centered tagline ("**Win+V for macOS.** Clipboard history *and*
  snippet expansion in one tiny native app.") → bold Download
  CTA ("↓ Download v2.0.0 (440 KB DMG)") → centered quick-nav row
  with 7 section links → centered ASCII demo. Below the divider,
  the existing long-form description and badge row continue as
  before — long-form unchanged, just demoted from "first thing
  users see" to "what they read after the hero hooks them."

- **`Tests/MultipasteCoreTests/main.swift`** — registers
  `ReadmePolishTests.registerAll()`.

- Test count: **125** (was 121).

### Version-consistency tests (added post-relicense)

Caught when Rohin spotted the README's Easy-install section saying
"Download Multipaste-1.9.0.dmg" while Version.swift / Info.plist /
release tag / GitHub release / Homebrew cask all said 2.0.0. The
download link was broken — clicking it 404'd because no v1.9.0
asset existed at the v2.0.0 release page.

The class of bug is *stale version strings scattered across docs
after a version bump*. The fix is twofold:

1. Updated the 5 stale strings:
   - README hero CTA: "440 KB DMG" → "460 KB DMG" (actual size).
   - README description: "440 KB DMG" → "460 KB DMG", and
     "~700 KB native Swift" → "~750 KB native Swift" (binary is
     768 480 bytes ≈ 750 KB; previous "~700 KB" understated).
   - README Easy-install link: `Multipaste-1.9.0.dmg` →
     `Multipaste-2.0.0.dmg` (the broken-link bug).
   - README Easy-install size: "(~420 KB)" → "(~460 KB)".
   - README "Why pick Multipaste" bullet: "~700 KB binary" →
     "~750 KB binary".

2. Added a `VersionConsistency` test suite that makes this entire
   class of bug impossible to ship again.

- **`Tests/MultipasteCoreTests/VersionConsistencyTests.swift`** —
  NEW suite, 6 tests. The suite reads
  `Sources/MultipasteCore/Version.swift` for the canonical version
  (parses `static let value = "X.Y.Z"` via regex) and then asserts:

  1. `swiftAndPlistAgreeOnVersion` — Info.plist's
     `CFBundleShortVersionString` matches Version.swift exactly.
  2. `readmeHeroDownloadCTAMatchesVersion` — README hero CTA
     reads `Download vX.Y.Z` matching the canonical version.
  3. `readmeInstallSectionReferencesCurrentDMG` — README contains
     `Multipaste-X.Y.Z.dmg` matching the canonical version.
  4. `readmeContainsNoStaleDMGReferences` — **the load-bearing
     test**: scans every `Multipaste-A.B.C.dmg` occurrence in
     README via regex; any that don't match the canonical version
     fail the build. Catches the exact bug Rohin spotted, plus
     every variant of it.
  5. `changelogLatestEntryMatchesVersion` — CHANGELOG's first
     `## X.Y.Z` heading matches the canonical version.
  6. `securityPolicySupportsCurrentMajorSeries` — SECURITY.md
     supported-versions table mentions the current major series
     (e.g., `2.0.x`).

  Explicitly out of scope: historical version references in
  CHANGELOG sub-sections (the v1.9.0 entry SHOULD say 1.9.0),
  "fixed in v1.6.0"-style historical bug references, PolyForm
  Strict 1.0.0 (that's the license version, not the app version),
  the Homebrew tap (separate repo), and approximate size strings
  (would couple tests to build output).

- Test count: **131** (was 125).

### README "Made for" honesty pass + snippet-example genericization

Two textual issues caught by Rohin:

1. The README's "Made for" footer said *"Built start-to-finish in
   one session: native Swift app, custom test harness, DMG
   installer, Homebrew tap, GitHub releases, update checker,
   four-bug forensic deep dive..."* This was true once (the
   original v1.0–v1.5-ish work landed in a single session on
   2026-05-11) but became false as the project iterated across
   many sessions, culminating in today's v2.0.0 relicense +
   standards-compliance + tests + chooser + SECURITY.md work.

2. The Snippet expansion tutorial used `rohin.agrawal@gmail.com`
   as the demo email — making the example feel about the
   maintainer rather than about the reader.

Fixed:

- README.md "Made for" section — dropped "in one session", added
  honest description: *"Personal-use macOS daily-driver: native
  Swift app, custom test harness, DMG installer, Homebrew tap,
  GitHub releases, update checker, four-bug forensic deep dive.
  v2.0.0 added source-available PolyForm Strict licensing with
  full SPDX/REUSE compliance, a Contributor License Agreement, an
  issue-template chooser, SECURITY.md, and 133 tests covering
  every artifact (including this README)."*

- README.md Snippet expansion — `rohin.agrawal@gmail.com` →
  `you@example.com` (both in the "copy" step and the expansion
  result). Generic placeholder invites the reader to imagine
  their own email. The personal address still appears in the
  License / SECURITY / Commercial sections where it's
  contextually appropriate (commercial-licensing contact,
  security-disclosure email, copyright notice).

Added regression tests in
**`Tests/MultipasteCoreTests/ReadmePolishTests.swift`** (suite
grew 4 → 6 tests):

- `readmeDoesNotClaimBuiltInOneSession` — case-insensitive scan
  for "in one session", "in a single session", "in one sitting",
  "in a single sitting". Catches the original wording plus
  near-variants so the false claim can't sneak back via rewording.
- `snippetExampleUsesGenericEmail` — scans the lines between
  `## Snippet expansion` and the next `##` heading; asserts they
  contain `example.com` and do NOT contain
  `rohin.agrawal@gmail.com`. The section-scoped check means the
  test doesn't false-positive on the email appearing legitimately
  in License / SECURITY / Commercial sections.

Audit of all "Rohin" references across the repo (89 occurrences
across 25 files) confirmed all other uses are legitimate:
copyright notices (LICENSE.md + REUSE.toml + 41 source-file SPDX
headers + Info.plist + CHANGELOG), commercial-licensing contact
email (LICENSE.md + README + CONTRIBUTING + SECURITY + issue
chooser + PR template), CLA references (CONTRIBUTING.md +
README), and the bundle identifier `com.rohin.multipaste` (which
is a stable API across every Multipaste installation in
existence — renaming it would break upgrades for every user, so
it stays).

- Test count: **133** (was 131).

The 1.9.0 → 2.0.0 release is otherwise feature-identical.

## 1.9.0 — 2026-05-11

Makes pinning visible. Same semantics — different feel.

### What pinning has always done

Three concrete behaviors, none of which 1.0–1.8 communicated well:

1. **Pinned items survive history eviction.** The 200-item cap drops
   unpinned entries only; pinned items stay forever.
2. **Pinned items survive "Clear History (Keep Pinned)."**
3. **Snippet expansion requires pinning** — a trigger only fires if
   the item is pinned. Setting a trigger auto-pins.

### Why it didn't *feel* like anything was happening

Pre-1.9.0 the only visual cue was a small 📌 emoji at the right edge
of the cell. The row's color didn't change, the order didn't change,
and nothing else moved. Users pressed ⌘P and saw essentially nothing,
leading to "what was pin supposed to do?"

### What 1.9.0 changes

- **Pinned rows now look pinned.** A 3 px yellow accent stripe down
  the left edge of the row, plus a 10%-opacity yellow background tint
  on the whole row. The previously-small 📌 emoji becomes a bold
  yellow `📌 PINNED` badge that you can read from across the room.
- **Inline action toast in the hint bar.** Press ⌘P and the bottom
  hint line briefly displays "📌 Pinned — survives history eviction
  and snippet expansion" for 1.6 seconds before restoring. Same for
  Unpin and Delete. Immediate "yes, that did something" feedback.
- **New Preferences toggle: "Show pinned items at the top of the
  picker."** Default off (recency order preserved). When on, pinned
  items are hoisted above unpinned ones, preserving relative recency
  within each group. Use it to make pinned items a "permanent shelf."
- New `MultipasteCore/HistoryStore.sortedForDisplay(pinnedFirst:)`
  pure helper. Stable sort, easily testable.
- 5 new unit tests: `sortedForDisplay` with pinned-first on/off,
  preserves relative order within groups, plus two for the new
  Preferences flag (default false + persistence).
- Test count: **83** (was 78).

## 1.8.0 — 2026-05-11

### Tab / Shift+Tab focus traversal in the picker

The picker now supports linear focus walking:

    search field  ↔  row 1  ↔  row 2  ↔  …  ↔  row N

- **`Tab`** from the search field moves focus to row 0 (the
  most-recent item). Subsequent Tabs advance through rows. At the
  last row Tab stops (no wrap — wrap would make Tab feel "lossy"
  since you'd have to count back to know where you are).
- **`Shift+Tab`** from a row moves to the previous row. From row 0
  it returns focus to the search field (caret positioned at the end
  of any existing query, so you can keep typing). From the search
  field Shift+Tab is a no-op.

Arrow keys still work as before for table-only selection — Tab adds
the extra "exit the textbox" behavior on top.

### What's added

- **`MultipasteCore/TabNavigation`** — pure state machine with a
  `FocusedRegion` enum (`searchField` / `row(Int)`) and `next` /
  `previous` transitions. Policy lives here (clamp vs wrap, no-op
  vs jump) so it's both trivially testable and trivially evolvable.
- **9 new unit tests** — search→row, row→row, clamp-at-end,
  Shift+Tab from row 0 to search, Shift+Tab from search no-op,
  empty-list edge case, single-row round-trip, and a full eight-
  step traversal across three rows.
- **`PickerWindow.handleTab(reverse:)`** wires the state machine
  to AppKit: snapshots current first-responder (search field's
  field editor or table view), runs the transition, applies the
  result by transferring first-responder and re-selecting rows.
- **Hint bar** in the picker now reads `↑↓/Tab select` (was just
  `↑↓ select`).
- README "Keys" table gains a `Tab / ⇧Tab` row.
- Test count: **78** (was 69).

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
