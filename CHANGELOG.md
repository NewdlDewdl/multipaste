# Changelog

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
