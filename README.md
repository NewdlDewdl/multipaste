<p align="center">
  <img src="Resources/icon-256.png" width="192" height="192" alt="Multipaste clipboard icon">
</p>

<h1 align="center">Multipaste</h1>

<p align="center">
  <strong>Win+V for macOS.</strong> Clipboard history <em>and</em> snippet expansion in one tiny native app.
</p>

<p align="center">
  <a href="https://github.com/NewdlDewdl/multipaste/releases/latest"><strong>↓ Download v2.3.0 (universal, Intel + Apple Silicon)</strong></a><br>
  <a href="#install">Install</a> ·
  <a href="#keys">Keys</a> ·
  <a href="#paste-many-things-at-once">Multi-paste</a> ·
  <a href="#snippet-expansion">Snippets</a> ·
  <a href="#how-does-it-compare">Compare</a> ·
  <a href="#privacy">Privacy</a> ·
  <a href="#license">License</a> ·
  <a href="#contributing">Contribute</a>
</p>

<p align="center"><code>Press ⌘⇧V anywhere → ↑↓ pick → ↩ paste&nbsp;&nbsp;·&nbsp;&nbsp;⌥↩ mark several → ↩ pastes them all</code></p>

---

A native clipboard history *and* snippet expander with a global hotkey,
a picker window, multi-paste (mark several items, paste them in one
go), pinning, search, full keyboard navigation, and an automatic
update check. Built for macOS 13+ (tested on macOS 26 Tahoe).

No subscriptions, no Electron, no telemetry, no account. ~1.9 MB
universal Swift binary in an ~840 KB DMG (one binary for Intel + Apple
Silicon), runs at ~0% CPU and ~50 MB RAM when idle, starts at login.

**Latest release:** [v2.3.0](https://github.com/NewdlDewdl/multipaste/releases/latest)
&nbsp;·&nbsp; **License:** [PolyForm Strict 1.0.0](LICENSE.md) (source-available, noncommercial)
&nbsp;·&nbsp; **Tests:** 271 unit tests &nbsp;·&nbsp; **Requires:** macOS 13 Ventura or later · **Universal** (Intel + Apple Silicon)

---

## Install

### 🟢 Easy — drag and drop (no Terminal)

1. Download **[Multipaste-2.3.0.dmg](https://github.com/NewdlDewdl/multipaste/releases/latest)**
   from the latest release (universal DMG: runs on both Intel and Apple Silicon).
2. Open the DMG. Drag **Multipaste** onto **Applications**.
3. Open your Applications folder, **right-click Multipaste**, choose
   **Open**, then **Open** again in the security warning. *(macOS asks
   this once for any app that isn't from the App Store — it won't ask
   again.)*
4. The Welcome window appears.
   - Click **Enable** under "Start at login".
   - Click **Open System Settings** under "Accessibility", flip the
     Multipaste toggle ON, confirm with Touch ID.
   - Click **Get Started**.

That's it. Press ⌘⇧V anywhere.

### 🍺 Homebrew — one command

```sh
brew install --cask NewdlDewdl/multipaste/multipaste
```

This pulls the same DMG, mounts it, copies the .app to `/Applications`,
and removes the quarantine flag (so no right-click-Open dance). Open
Multipaste from Spotlight or `/Applications` and follow the Welcome
window. Upgrade later with `brew upgrade --cask
NewdlDewdl/multipaste/multipaste`. Uninstall cleanly with `brew
uninstall --cask multipaste`, or wipe everything (history + prefs +
logs) with `brew uninstall --cask --zap multipaste`.

### 🛠 From source

```sh
git clone https://github.com/NewdlDewdl/multipaste
cd multipaste
make install            # build, install to ~/Applications, launch
```

Requires Xcode Command Line Tools (`xcode-select --install`). No Xcode
proper needed — Multipaste builds and tests with `swift build` and a
custom test harness.

---

## Keys

In the picker:

| Key                | Action                                                          |
| ------------------ | --------------------------------------------------------------- |
| `↑` / `↓`          | Move selection                                                  |
| `Tab` / `⇧Tab`     | Walk search ↔ row 1 ↔ row 2 ↔ … (linear focus traversal)        |
| `↩`                | Paste selected item (or ALL marked items, in badge order)       |
| `⌥↩` / `⌘-click`   | Mark / unmark item for multi-paste (badge shows paste order)    |
| `space` (in list)  | Mark / unmark item and step down (search field keeps its space) |
| `⌥⌘A`              | Mark all visible items (again: unmark them)                     |
| `⌘1` … `⌘9`        | Quick-paste the Nth visible item                                |
| `⌘P`               | Pin / unpin selected item (pinned items always show first)      |
| `⌘E`               | Set / edit a snippet trigger for the item                       |
| `⌘⌫`               | Delete selected item from history                               |
| `esc`              | Clear marks if any, else close picker                           |
| type anything      | Filter the history (case-insensitive)                           |

The default global hotkey is `⌘⇧V`. Change it in **Preferences → General → Hotkey**.

---

## Paste many things at once

The namesake feature: mark several history items and paste them ALL
with a single Return. Collect a name, an address, and a phone number
into one form-filling paste; drop three error messages into one bug
report; send a screenshot and its caption together.

1. Open the picker (`⌘⇧V`).
2. Mark items with `⌥↩` (works straight from the search field),
   `⌘-click`, or `space` when focus is in the list. Each marked row
   gets a numbered accent badge: that number is its position in the
   paste.
3. Change the search between marks if you like. Marks follow the
   *item*, not the row, so filtering never loses them. `⌥⌘A` marks
   everything currently visible.
4. Press `↩`. Everything pastes in badge order.

What the target app receives:

- **All text-ish items** (plain text, rich text, file copies) arrive
  as ONE paste, joined by the separator chosen in **Preferences →
  General → "Multi-paste separator"**: newline (default), blank line,
  space, tab, or nothing. The merged text also lands in history as a
  single item, ready to re-paste.
- **All file copies** arrive as one multi-file paste. Three marked
  files paste into Finder, a chat composer, or an email draft exactly
  as if all three had been ⌘C'd together.
- **Mixes that include images** (which can't be concatenated with
  anything) paste sequentially in badge order, about 0.2 s apart,
  into the still-focused target app.

`esc` clears the marks before it closes the picker, and marks reset
every time the picker opens, so a stale selection can never surprise
you. Power users can set any separator string, even ones the popup
doesn't list:

```sh
defaults write com.rohin.multipaste multiPasteSeparator " · "
```

---

## Screenshots → clipboard

Press ⌘⇧3 / ⌘⇧4 / ⌘⇧5 like you always have. macOS still saves the file
to your Desktop (or wherever you've configured `screencapture` to
save). Multipaste now ALSO copies it to the clipboard the moment it
appears — so the screenshot is one ⌘V away in Slack / iMessage /
chat composers, and it shows up in the picker (`⌘⇧V`) alongside
everything else.

No more remembering ⌃ — the modifier macOS makes you hold to get the
screenshot on the clipboard. (Quick: do you remember if it's ⌃⌘⇧3 or
⌘⌃⇧3 right now? Most people don't, which is the whole point.)

**How it works**: when you launch Multipaste, it reads
`defaults read com.apple.screencapture` to find your configured save
location (default `~/Desktop`) and filename prefix (default
`Screenshot`). It opens that directory with `O_EVTONLY` and attaches a
`DispatchSource.makeFileSystemObjectSource` watcher. On each
directory-mtime bump, it diffs against the baseline of paths it
already knew about and pulls out anything new whose name matches the
screenshot pattern — then reads the file and writes it to
`NSPasteboard.general` as PNG (and TIFF as fallback). The existing
clipboard monitor polls `changeCount` every 300 ms and inserts the
image into history just like any other ⌘C.

**Custom configurations are respected**:
- `defaults write com.apple.screencapture location ~/Pictures/Screenshots`
  → Multipaste watches your Pictures folder instead.
- `defaults write com.apple.screencapture name "MyShot"` → Multipaste
  matches `MyShot 2026-...` filenames.
- `defaults write com.apple.screencapture type jpg` (or `heic`, etc.)
  → Multipaste reads JPEG/HEIC/TIFF/PDF and publishes them on the
  clipboard.

After a `defaults write`, quit & relaunch Multipaste so the watcher
picks up the new location. (We don't auto-detect `defaults write`
because there's no notification path for it; the cost of a relaunch
is one menu click and it converges immediately.)

**Privacy + permissions**: on first launch after 2.1.3, macOS prompts
"Multipaste would like to access files in your Desktop folder" (or
wherever your screenshot location is). This is a one-time TCC prompt
— Allow once and the watcher works forever. If you Deny, the watcher
silently does nothing and logs the denial to
`~/Library/Logs/Multipaste/multipaste.log`; the rest of the app
continues to work. **Multipaste never reads files outside the
screenshot directory**, never uploads anything, never makes a network
call about your screenshots. Audit: `grep -rn ScreenshotWatcher
Sources/` — every read is local, every write goes only to
`NSPasteboard.general`.

**Pause Monitoring**: pausing the clipboard monitor (menu bar →
"Pause Monitoring") still lets screenshots land on the OS clipboard
for downstream ⌘V — it just doesn't add them to Multipaste's history.
That matches the existing pause semantics for regular ⌘C events:
the clipboard receives the write at the OS level, only our own
bookkeeping is suppressed.

Toggle off in **Preferences → General → "Auto-copy screenshots to
clipboard"** if you'd rather have the historical behavior. Default on
because the feature is the value prop — and because it's strictly
additive (the screenshot still saves to disk exactly as before; we
just *also* put it on the clipboard).

**Verifying it works on your machine** (60 seconds):

```sh
# 1. Tail the log — leave this running in a separate terminal.
tail -F ~/Library/Logs/Multipaste/multipaste.log

# 2. Take a screenshot the normal way:
#    ⌘⇧3 (full screen) — or ⌘⇧4 + region — or ⌘⇧5 + UI.

# 3. The log should print, within ~50 ms:
#    [multipaste 2.1.3 pid=N] ScreenshotWatcher: copied Screenshot 2026-...png (123456 bytes, 2 representations) to pasteboard

# 4. Open the picker (⌘⇧V). The screenshot should be the topmost item.

# 5. ⌘V into any text/chat composer — you should paste the image.
```

If you don't see the log line:
- Check Preferences → General — is "Auto-copy screenshots to clipboard"
  on? (It is by default; verify it wasn't turned off.)
- Check Diagnostics… in the menu — does it report the watcher attached
  successfully?
- Check the log for `ScreenshotWatcher: failed to attach watcher at
  …` — that's the macOS-denied-Desktop-access case. Open System
  Settings → Privacy & Security → Files and Folders → find Multipaste
  → enable Desktop.

---

## File copy → path text *and* file upload

Copy any file in Finder. Multipaste augments the pasteboard so:

- Pasting in **Claude's code tab** (or any text editor / terminal /
  search field) yields the **full file path**.
- Pasting in **Claude's chat tab** (or any drop target) uploads the
  **file itself**.

Both at the same time, from a single ⌘C. No app detection, no mode
switching. The receiving control picks whichever pasteboard type it
prefers — Multipaste just makes sure both are available.

**How it works**: Finder's file copy carries `public.file-url` and
legacy URL types but no `public.utf8-plain-text`. Multipaste detects
this case and adds the path as the string representation, preserving
every other type. Toggle off in **Preferences → General → "Add file
path as text on file copies"** if you'd rather have the historical
"empty string on file copy" behavior.

---

## Snippet expansion

Pinned items can have a **trigger** — typing it followed by space, tab,
or return anywhere on macOS expands it into the snippet content.

1. Copy something (`you@example.com`).
2. Open the picker (`⌘⇧V`), select it, press `⌘E`, type `;e`, hit
   **Save**.
3. From now on, in any text field, typing `;e ` becomes
   `you@example.com`. The trigger and the terminating space are
   deleted; the snippet content is pasted.

Trigger rules:

- Only **pinned** items with a non-empty trigger fire. Setting a
  trigger auto-pins the item.
- Terminators are space, tab, or return.
- Longest match wins (so `;email` doesn't get eaten by `;m`).
- Cmd-or-Ctrl-bearing keystrokes reset the buffer — no surprise
  expansion inside hotkey combos.

There is no YAML config. The snippet store *is* the clipboard history.
Pin something, give it a trigger, done.

---

## Settings

Open with the menu-bar 📋 → **Preferences…** (or `⌘,` while the menu is
open). Three tabs:

- **General**
  - Hotkey recorder (click, press your combo, release)
  - Auto-paste on select (checkbox)
  - Start at login (uses `SMAppService.mainApp.register()`)
  - Multi-paste separator (newline / blank line / space / tab / nothing)
  - History size (10 – 2000)
- **Snippets** — list of all triggers, with Edit Trigger / Remove
  Trigger buttons. Add new ones via the picker (`⌘E`).
- **About** — version, license, links.

The hotkey recorder rejects key combos with no modifier (otherwise
plain letters would be swallowed system-wide). Esc cancels recording.

---

## How does it compare?

| | **Multipaste** | Maccy | Flycut | Paste | Pastebot | CopyClip 2 | Alfred | Raycast | Espanso |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Price** | 🆓¹ | 🆓 | 🆓 | $30/yr | $13 | Paid | £34+ | 🆓 (Pro $8+) | 🆓 |
| **License** | **PolyForm Strict**² | MIT | MIT | Proprietary | Proprietary | Proprietary | Proprietary | Proprietary | GPL-3 |
| **Clipboard history** | ✓ | ✓ | text only | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| **Image capture** | ✓ | ✓ | ✗ | ✓ | ✓ | ✗ | ✓ | ✓ | n/a |
| **Rich text (RTF)** | ✓ | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | n/a |
| **File URLs** | ✓ | ✓ | ✗ | ✓ | ? | ✗ | ✓ | ✓ | n/a |
| **Pinned items** | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ~ | ✓ | n/a |
| **Snippet expansion (typed trigger)** | **✓** | ✗ | ✗ | ~ | ~ | ✗ | ~ separate | ~ separate | ✓ |
| **History + snippets, one tool** | **✓** unique | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Fuzzy search** | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Configurable hotkey** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Password managers excluded** (`nspasteboard.org`) | ✓ | ✓ | ✗ | ? | ? | ~ | ~ | ✓ | n/a |
| **Built-in update check** | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Idle RAM** (approx) | **~50 MB** | ~80 MB | ~30 MB | ~150 MB | ~120 MB | ~60 MB | ~100 MB | ~250 MB | ~80 MB |
| **Sign-in / account** | none | none | none | required | none | none | none | optional | none |
| **Telemetry** | none | none | none | ? | ? | ? | none | yes | none |
| **Open source** | src-avail² | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |

**Why pick Multipaste:**
- The only tool that combines clipboard history *and* trigger-based
  snippet expansion in one app. Maccy doesn't expand; Espanso doesn't
  remember.
- True multi-paste: mark several items in the picker and paste them
  all with one Return, merged text or a single multi-file paste.
- Free for personal use + source-available vs Paste / Pastebot / Alfred
  (paid) and Raycast (closed-source + telemetry). Source is on GitHub,
  read it, audit it, file issues against it.
- Lightweight: ~50 MB RAM idle, ~1.5 MB universal binary, no helper processes.

¹ Free for noncommercial use. Commercial use requires a separate license
from the author — email <rohin.agrawal@gmail.com>.

² PolyForm Strict 1.0.0 is a [source-available
license](https://polyformproject.org/licenses/strict/1.0.0/), not OSI
open source. Source is publicly visible and you may run Multipaste for
any noncommercial purpose (personal, hobby, research, charity,
education, government). Redistribution, modification, and commercial
use are not permitted. See the [License](#license) section below for
details.

---

## Updates

Multipaste checks the GitHub Releases API on launch (60 seconds after
start) and once every 24 hours after that.

- **Silent when you're up to date.** No nag dialogs.
- **When a newer release exists**, you get a single alert with three
  choices:
  - **Download** — opens the release page in your browser.
  - **Skip This Version** — remembered until a newer one ships.
  - **Remind Me Later** — re-prompts on the next 24-hour tick.
- **Manual check**: menu-bar 📋 → **Check for Updates…**. Unlike the
  silent check, this confirms "You're on the latest version" explicitly.

There's no atomic auto-installer — without an Apple Developer ID, we
can't safely replace a running .app. The alert opens the release page
where you grab the new DMG (or run `brew upgrade --cask
NewdlDewdl/multipaste/multipaste`).

---

## Granting Accessibility access

Auto-paste and snippet expansion need macOS Accessibility permission.
Without it Multipaste still works — picks land on your clipboard and
you press ⌘V manually — but you give up the magic.

### From inside Multipaste (fastest)

When access is missing, the menu-bar 📋 icon **dims** and the menu shows
a yellow banner at the top:

```
⚠️  Grant Accessibility access…
    Needed for auto-paste and snippets
    Already toggled? Quit & Relaunch
```

Click the banner. Multipaste does three things at once:

1. **Adds itself to the Accessibility list** (via
   `AXIsProcessTrustedWithOptions` — this is the call that pre-populates
   Multipaste so you don't have to hunt for it with the `+` button).
2. **Opens System Settings** straight to **Privacy & Security →
   Accessibility**.
3. **Shows a step-by-step alert** with three buttons: OK, Open Settings
   Again, Quit & Relaunch.

Toggle Multipaste **on** in System Settings. Authenticate with Touch ID
or your password.

Multipaste polls 4 times per second for 60 seconds after the banner
click, so the toggle is caught within a single tick — the icon
brightens, the status row says **Accessibility: ON**, and a "Granted!"
confirmation pops up. The snippet engine restarts automatically. No
relaunch needed.

### Manual path (if Multipaste isn't running yet)

1. Apple menu → System Settings…
2. **Privacy & Security** (left sidebar) → **Accessibility** (main pane)
3. If Multipaste is in the list → flip the toggle ON, confirm.
4. If not → click `+`, navigate to Applications → Multipaste → Open,
   toggle ON.

### Troubleshooting

Multipaste has **three escape hatches** built into the menu, each for a
different failure mode:

| Menu item                       | When to use it                                              |
| ------------------------------- | ----------------------------------------------------------- |
| **Diagnostics…**                | Show me the in-process truth (trust state, cdhash, supervisor, sibling PIDs). First thing to open when something seems off. Copy-to-Clipboard for support. |
| **Reset Accessibility Permission** | Toggled Multipaste on but the status row still says OFF? Wipes the TCC entry so you can grant fresh. The nuclear option for stale entries inherited from older builds. |
| **Quit & Relaunch**             | Bypasses macOS's per-process TCC cache. A fresh process gets a clean read of the trust bit. |

Multipaste also writes a structured log to
`~/Library/Logs/Multipaste/multipaste.log`. Boot lines look like:

```
[2026-05-11T19:20:05Z] [multipaste 1.6.1 pid=25953] trust=OFF bundle=/Users/.../Multipaste.app
[2026-05-11T19:20:55Z] [multipaste 1.6.1 pid=25953] Accessibility trust flipped to ON
```

`tail -f` it while you toggle the System Settings switch — you'll see
the flip the moment macOS applies it.

### What Accessibility is actually for

- **Auto-paste** — synthesizes ⌘V into the focused app via
  `CGEvent.post` after you pick an item. Without Accessibility, macOS
  drops synthesized keyboard events.
- **Snippet expansion** — installs a `CGEvent.tapCreate` keyboard tap
  to watch typing system-wide, delete the trigger characters, then
  paste the expansion.

Multipaste does not log keystrokes, does not exfiltrate anything, and
does not make network calls outside the once-a-day update check
(`api.github.com/repos/NewdlDewdl/multipaste/releases/latest`). Audit:
`grep -r URLSession Sources` — one match, in `UpdateService.swift`.

---

## Privacy

- **All data is local.** History lives at
  `~/Library/Application Support/Multipaste/history.json` in plain
  JSON. Inspect it, back it up, or delete it.
- **Preferences** live at
  `~/Library/Preferences/com.rohin.multipaste.plist`.
- **Logs** land in `~/Library/Logs/Multipaste/`.
- **Password managers are excluded.** Multipaste honors the
  community-standard [`org.nspasteboard.org`][nspasteboard] privacy
  markers — anything tagged `ConcealedType`, `TransientType`, or
  `AutoGeneratedType` is filtered out. 1Password, KeePassXC, Bitwarden,
  and most well-behaved managers set these markers automatically.
- **No telemetry.** Audit: `grep -r URLSession Sources` returns one
  match (the update check). `grep -r 'http' Sources` shows zero
  user-data POSTs.

[nspasteboard]: https://nspasteboard.org

---

## Architecture

```
              ┌──────────────────────────────┐         ┌──────────────────────────────┐
              │  Carbon RegisterEventHotKey  │         │   CGEvent.tapCreate          │
              │  (⌘⇧V global hotkey —        │         │   (session keyboard tap;     │
              │   no Accessibility needed)   │         │   needs Accessibility)       │
              └──────────────┬───────────────┘         └──────────────┬───────────────┘
                             │ keypress                                │ each keystroke
                             ▼                                         ▼
         ┌──────────────────────┐                ┌──────────────────────────┐
         │  ClipboardMonitor    │                │  SnippetEngine           │
         │  300ms NSPasteboard  │                │  ring buffer →           │
         │  changeCount poll    │                │  SnippetMatcher          │
         └──────────┬───────────┘                └────────────┬─────────────┘
                    │ insert                                    │ on match:
                    ▼                                           │ backspaces × N + ⌘V
       ┌──────────────────────────────────┐                     │
       │   HistoryStore                   │                     │
       │   JSON-persisted, deduped,       │                     │
       │   pinned-survives-eviction       │                     │
       └────────┬─────────────────────────┘                     │
                │ observers                                     │
                ▼                                               ▼
       ┌──────────────────┐   ┌──────────────────┐   ┌────────────────────┐
       │  PickerWindow    │   │ MenuBarController│   │     Paster         │
       │  NSPanel +       │   │ NSStatusItem +   │   │  pasteboard write  │
       │  NSTableView     │   │ live-state menu  │   │  + CGEvent ⌘V      │
       └─────────┬────────┘   └────────┬─────────┘   └────────────────────┘
                 │ pick                  │ menu picks
                 └──────────┬────────────┘
                            ▼
                    ┌──────────────┐         ┌─────────────────────┐
                    │ PermissionMon│         │  UpdateService      │
                    │ 1s poll +    │         │  GitHub Releases    │
                    │ 250ms burst  │         │  API, daily         │
                    └──────────────┘         └─────────────────────┘
```

**Two Swift targets:**

- **`MultipasteCore`** (library, pure Swift, no AppKit) —
  `ClipboardItem`, `HistoryStore`, `MarkList`, `MultiPasteComposer`,
  `MultiPasteSeparator`, `Preferences`, `SnippetMatcher`,
  `SemanticVersion`, `UpdateChecker`, `Version`.
  All testable. 271 unit tests live here (incl. MarkList + MultiPasteComposer for the v2.3.0 multi-paste feature; ScreenshotDetector for the screenshots-to-clipboard feature; PasteSynthesis + PasteRouting which lock the ⌘V device-bit and paste-path routing behind the v2.2.0 paste fix; License + Contribution + LicensingMetadata + IssueChooser + ReadmePolish + VersionConsistency suites that lock down LICENSE.md, CONTRIBUTING.md, SPDX/REUSE compliance, the GitHub issue-template chooser, SECURITY.md, the README hero design + stale-claim regression guards, and version-string agreement across every artifact).
- **`Multipaste`** (executable, AppKit-bound) —
  `AppDelegate`, `AppPaths`, `ClipboardMonitor`, `Diagnostics`,
  `HotKeyManager`, `HotkeyRecorderField`, `LoginAgent`, `LoginItem`,
  `MenuBarController`, `Paster`, `Permissions`, `PermissionMonitor`,
  `PickerWindow`, `SettingsWindowController`, `SingleInstance`,
  `SnippetEngine`, `ThumbnailCache`, `UpdateService`, `WelcomeWindow`,
  `main.swift`.

**Why polling, not a notification?** `NSPasteboard` has no KVO. There's
no `pasteboardDidChange:` delegate. Every clipboard manager on
macOS — Maccy, Paste, Pastebot, Alfred — polls `changeCount`. 300 ms is
the consensus sweet spot.

**Why Carbon for the global hotkey?** `RegisterEventHotKey` is in
`Carbon.HIToolbox`. It's older but unambiguously still supported in
2026, used by `MASShortcut`, `KeyboardShortcuts`, and Sparkle.
Crucially: it does **not** require Accessibility, so the hotkey works
from the moment the agent launches. Only the keystroke-synthesis side
of paste/expansion needs Accessibility.

**Why `SMAppService.mainApp` instead of a LaunchAgent?** Empirically
proven this session: LaunchAgent-spawned processes on macOS 26 Tahoe
do **not** inherit the user's Accessibility TCC grant.
`AXIsProcessTrusted()` returns `false` for them even when the toggle is
clearly on. SMAppService Login Items don't have this problem — they're
launched like the user would launch the app, with the same TCC context.
v1.6.0 made the switch.

---

## Tests

```sh
make test                    # runs all 271 unit tests in ~150 ms
make smoke-test              # end-to-end integration test of the screenshot pipeline
make preview-update-dialog   # visually preview the "vX.Y.Z is available" dialog
make verify-app              # verifies the built .app: universal binary + codesign + plist
```

`make smoke-test` runs `scripts/screenshot-smoke-test.swift` — a
self-contained Swift script that creates a temp directory, attaches a
`DispatchSourceFileSystemObject` watcher, drops a synthetic
`Screenshot YYYY-MM-DD at H.MM.SS AM.png` into it, verifies the
watcher fires, and confirms a private `NSPasteboard` round-trips the
image data. Real macOS APIs, no mocks; doesn't touch the user's real
screenshot location or system clipboard.

`make preview-update-dialog` runs `scripts/preview-update-dialog.swift`
— shows the actual "Multipaste vX.Y.Z is available" dialog populated
with the literal v2.0.2 CHANGELOG markdown that produced the bug Rohin
reported (raw `##`, `**`, ``` ` ```, `>`). Click "Looks good" if the
markdown rendered properly; click "Looks broken" otherwise. Use this
after editing `MarkdownAttributedString.render` or
`ReleaseNotesFormatter.summary` to make sure the visual output is
still correct.

Tests use a small custom harness
(`Tests/MultipasteCoreTests/TestHarness.swift`) that runs as
`swift run MultipasteTests`. This avoids needing full Xcode — the
Command Line Tools-only toolchain ships neither XCTest's testing import
overlay nor `swift-testing`'s `_Testing_Foundation` module in a SwiftPM-
consumable form, so the harness is the most portable option.

Each test is a static `throws` function registered into
`TestRegistry`; the runner counts failures and exits non-zero on any.
CI-friendly.

Coverage:

| Suite                  | Count | Covers                                                 |
| ---------------------- | ----- | ------------------------------------------------------ |
| `ClipboardItem`        | 11    | hashing, preview trim, kinds, Codable, ID, trigger     |
| `HistoryStore`         | 17    | insert order, dedup-resurface, eviction, pinning, search, persistence, corrupt-file recovery, observers, trigger autopin, snippets accessor |
| `Preferences`          | 6     | defaults, persistence, hotkey codec, history clamp, first-run flag |
| `SnippetMatcher`       | 11    | terminators, longest-match, unpinned skip, no-substring false-positive, char-count math |
| `SemanticVersion`      | 11    | v-prefix, garbage rejection, two-component rejection, ordering with double-digit components |
| `UpdateChecker`        | 6     | up-to-date, update-available, downgrade ignored, skipped-version, GitHub JSON parse, error on missing fields |
| `PasteboardAugmenter`  | 7     | path-text single/multi/empty, augment-when-nil/empty/whitespace, don't-clobber-real-text |
| `ScreenshotDetector`   | 32    | default macOS PNG name; jpg/jpeg/tiff/tif/heic/pdf accepted; uppercase ext; custom prefix matches/doesn't-match-default; underscore-joined names; standalone `Screenshot.png`; rejection of random files / dotfiles / .txt / non-prefix PNGs / movies; empty filename; empty prefix; extensionless; word-boundary check (`Screenshots` ≠ `Screenshot`); resolveLocation default/absolute/tilde/empty/whitespace/nil; resolvePrefix default/custom/empty/whitespace/trim; filterNewScreenshots basic/dedup/non-matches/custom-prefix/empty-dir |
| `ReleaseNotesFormatter` | 20  | `summary(from:)` strips `## VERSION` header, stops at first `### `, stops at second `## ` (multi-entry input), handles no-header / empty input, strips trailing blank lines, preserves inline markdown; `cleanPlainText(from:)` strips bold/italic/inline-code/headers/blockquote/links/converts bullets to •; conservative on unmatched delimiters; **v2.0.2-dialog-bug regression guard** (the literal markdown screenshot Rohin reported — no `##` / `**` / backtick sigils may survive a render pass) |
| `TabNavigation`        | 9     | search→row, between-rows, clamp at last row, Shift+Tab edges, empty list, single-row, three-row full traversal |
| `HistoryStore` (pin/unpin order) | 11 | (v2.1.1) unconditional hoist — chronological-when-nothing-pinned, hoist-when-pinned, within-group order preserved, **`pinningOldItemHoistsItToTop` regression guard** for the v2.1.0 "pin button is a no-op" bug, search results are pinned-first, storage `items` stays chronological when only pinning; (v2.1.3) **unpin keeps position** — `unpinningKeepsItemAtTopOfUnpinned`, `unpinningDoesNotTeleportToOrigin` (the 5-item "super far away" guard), `unpinningLandsBelowRemainingPinned`, `unpinMovesItemToFrontOfStorage`, `unpinDoesNotReorderOtherItems` |
| `Preferences` (pinned-first deprecation)  | 2 | (v2.1.1) deprecated getter hard-wired to true, writes are no-ops (old plists silently do the right thing) |
| `Preferences` (auto-copy screenshots) | 3 | default ON (the feature ships on), persistence, off↔on round trip |
| `ProcessTable`         | 14    | (v2.1.2) single-instance `ps` matching keys on `argv0` not a line substring — real app matched, `~/Applications` variant matched, shell/grep/tail with the path in **arguments** all excluded, own-PID excluded, multiple siblings, argv0-with-trailing-args matched, `ps` header skipped, leading-whitespace PID, blank/malformed skipped, empty input, unrelated app ignored, **real-world-bug regression guard** (the over-broad match that SIGTERM'd bystander shells) |
| `License`              | 13    | LICENSE.md path + `.md` extension regression-guard, PolyForm Strict 1.0.0 title + URL, project copyright header + commercial-license email, the Strict-defining no-distribution/no-derivatives clause, NC / Personal / NC-Org sections, Patent Defense, 32-day cure, warranty disclaimer, absence of MIT/AGPL/GPL/Affero, absence of PolyForm Noncommercial (wrong variant), absence of stray bare-LICENSE, line-count range, contribution pointer |
| `Contribution`         | 5     | CONTRIBUTING.md exists, CLA contains perpetual/worldwide/royalty-free/irrevocable grant, relicensing-right clause explicitly mentions proprietary closed-source, PolyForm Strict context explained, PR template links to CLA + has confirmation checkboxes + calls out relicensing |
| `LicensingMetadata`    | 12    | REUSE.toml exists + declares `LicenseRef-PolyForm-Strict-1.0.0` for Sources & Tests, `.licensee.json` exists + valid JSON + declares the SPDX ID, `LICENSES/LicenseRef-PolyForm-Strict-1.0.0.md` exists + content matches LICENSE.md (symlink intact), every `.swift` file under Sources & Tests has SPDX-License-Identifier + SPDX-FileCopyrightText in top 5 lines, Package.swift has SPDX header after `swift-tools-version`, README contains PolyForm badge URL (`polyformproject.org/strict.png`) + canonical license URL + **badge is NOT in the first 30 lines** (regression guard: stops the intimidating "STRICT" logo from migrating back into the intro header above the install instructions) |
| `IssueChooser`         | 8     | bug_report.yml is a YAML form with required fields (macOS version, Multipaste version, install method, arch, repro) + routes security to email; feature_request.yml has CLA acknowledgment including relicensing-clause callout; chooser config.yml disables blank issues + has security/commercial/Discussions/CONTRIBUTING contact links; old .md template removed; SECURITY.md exists at repo root + documents reporting channel + supported versions |
| `ReadmePolish`         | 6     | Hero logo file exists at `Resources/icon-256.png` + has valid PNG magic bytes; README intro has centered `<p align="center">` hero with logo (192px width) + meaningful alt text + centered `<h1>Multipaste</h1>`; intro has a quick-nav row with ≥4 section anchors; intro has a bold Download CTA linking to `releases/latest`; **README does NOT contain stale build-duration claims** (case-insensitive scan for one-session / single-sitting variants — regression guard); **snippet-expansion section uses a generic `you@example.com` example** rather than the maintainer's personal address (regression guard) |
| `VersionConsistency`   | 6     | Version.swift's `MultipasteVersion.value` parses cleanly; Info.plist `CFBundleShortVersionString` agrees with Version.swift; README hero `Download vX.Y.Z` CTA matches; README install section references `Multipaste-X.Y.Z.dmg` matching the canonical version; **no stale `Multipaste-A.B.C.dmg` patterns anywhere in README** (the regression-guard that catches the bug class where Version.swift bumps but the README install link still points at the old DMG); CHANGELOG's latest `## X.Y.Z` entry matches; SECURITY.md supported-versions table mentions the current major series (e.g. `2.0.x`) |
| `BuildScript`          | 4     | `scripts/build.sh` defaults to `ARCHS="${MULTIPASTE_BUILD_ARCHS:-arm64 x86_64}"` (so a fresh build is universal — **fixes the v2.0.0 Intel-can't-open bug**); script contains `lipo -create` step AND a `lipo -archs` post-build verification that fails the build if any requested arch is missing; the in-DMG `READ ME FIRST.txt` heredoc in `scripts/dmg.sh` uses **control-click / right-click → Open**, NOT just "double-click Multipaste" (fixes the v2.0.1 in-DMG-readme bug where users hit a Gatekeeper dialog with no Open button); the heredoc mentions System Settings → Privacy & Security as the macOS 15 Sequoia fallback |
| `InfoPlist`            | 7     | CFBundleIdentifier in Info.plist matches Swift's `MultipasteVersion.bundleIdentifier` (drift breaks every TCC grant + Login Item + preference + launch agent — anything keyed by bundle ID); CFBundlePackageType is `APPL`; NSPrincipalClass is `NSApplication`; LSUIElement is true (menubar-only, no Dock icon); LSMinimumSystemVersion is `13.0`; NSAppleEventsUsageDescription present + non-empty + mentions Multipaste/paste; NSHumanReadableCopyright references PolyForm Strict + commercial-license email (Finder Get Info shows the right contact) |
| `PasteSynthesis`       | 7     | ⌘V flag composition: the left-Command device bit (`NX_DEVICELCMDKEYMASK`, `0x8`) is OR'd into `commandVFlags` so Chromium/Electron honor the synthesized Command (Flycut #18); exact `0x10_0008` value; **regression guard that the flags never silently revert to bare `maskCommand`** (the v2.1.x paste-into-Electron bug) |
| `PasteRouting`         | 4     | paste-path decision: previous app still frontmost is `.immediate`, focus on Multipaste with a captured target is `.restoreFocus`, frontmost with no target is `.clipboardOnly` |
| `MarkList`             | 15    | (v2.3.0) multi-paste mark policy: paste order is MARK order not display order, toggle/unmark renumbering, 1-based badge positions, mark-all appends without reshuffling hand-placed marks, ⌥⌘A round-trips, unmark-all touches only visible elements, `prune(keeping:)` drops deleted items while preserving order, marks-survive-filtering design guard |
| `MultiPasteComposer`   | 15    | (v2.3.0) the single/combined/sequential decision table: empty pick plans nothing, one item stays `.single` (exact item, even an image), all-text combines with the separator in mark order (newline/blank-line/space/tab/empty all covered), RTF contributes plain text, all-file picks merge into ONE multi-file pasteboard (order-preserving, deduped keeping first slot), text+files combines via paths, any image forces `.sequential` in mark order, combined item is a fresh history-ready `.text` item, per-kind `textRepresentation`, **inter-item delay locked to the 0.1–0.3 s window** (below: pasteboard-swap race; above: feels broken) |
| `MultiPasteSeparator`  | 6     | (v2.3.0) popup ↔ literal mapping: exact literals, every choice round-trips, literals + labels unique, unknown literal has no popup row but is still honored, registered default is the newline choice |
| `Preferences` (multi-paste separator) | 3 | (v2.3.0) defaults to newline, persists across instances, accepts arbitrary hand-written separator strings |
| **Total**              | **271**| Pure logic; UI is integration-tested manually          |

---

## Files

```
Package.swift
Makefile
README.md  LICENSE.md  CHANGELOG.md

Sources/
  MultipasteCore/      ← testable, pure Swift:
                          ClipboardItem  HistoryStore  MarkList
                          MultiPasteComposer  MultiPasteSeparator
                          PasteboardAugmenter  Preferences
                          ProcessTable  ReleaseNotesFormatter
                          ScreenshotDetector  SemanticVersion
                          SnippetMatcher  TabNavigation
                          UpdateChecker  Version
  Multipaste/          ← AppKit / system:
                          AppDelegate  AppPaths  ClipboardMonitor
                          Diagnostics  HotKeyManager  HotkeyRecorderField
                          LoginAgent  LoginItem  MarkdownAttributedString
                          MenuBarController  Paster  Permissions
                          PermissionMonitor  PickerWindow
                          ScreenshotWatcher  SettingsWindowController
                          SingleInstance  SnippetEngine  ThumbnailCache
                          UpdateService  WelcomeWindow  main.swift

Tests/MultipasteCoreTests/
  ClipboardItemTests.swift  HistoryStoreTests.swift
  PreferencesTests.swift    SnippetMatcherTests.swift
  SemanticVersionTests.swift  UpdateCheckerTests.swift
  TestHarness.swift         main.swift

Resources/
  Info.plist  PkgInfo  Multipaste.icns  icon-1024.png

LaunchAgent/                    (legacy; install.sh no longer uses it)
  com.rohin.multipaste.plist

scripts/
  build.sh         # swift build -c release + bundle assembly + codesign
  dmg.sh           # builds dist/Multipaste-X.Y.Z.dmg
  install.sh       # build, copy to ~/Applications, open
  uninstall.sh     # remove app + cleanup
  make-icon.swift  # generates icon-1024.png via CoreGraphics
  make-iconset.sh  # sips + iconutil to produce .icns
```

---

## Development

```sh
make test          # run all 271 unit tests (~150 ms)
make build         # produce dist/Multipaste.app (also generates icon)
make run           # foreground-launch the bundled binary
make install       # build + copy to ~/Applications + open
make uninstall     # remove app and stop the supervisor
make purge         # uninstall + delete history, prefs, logs
make status        # is Multipaste running? show launchctl state
make logs          # tail multipaste.log
make clean         # remove .build/ and dist/
bash scripts/dmg.sh     # produce dist/Multipaste-X.Y.Z.dmg
```

To bump the version, edit
`Sources/MultipasteCore/Version.swift` and
`Resources/Info.plist`'s `CFBundleShortVersionString` /
`CFBundleVersion`. `scripts/dmg.sh` reads the plist to name the
output DMG.

---

## The bugs we fixed (and how)

This section documents the four root causes that made "I granted
Accessibility but it still says OFF" hard to fix. Each one masked the
next.

### 1. NSTimer was paused inside modal alerts and menus (fixed in 1.5.0)

`PermissionMonitor` polled `AXIsProcessTrusted()` via
`Timer.scheduledTimer(withTimeInterval:repeats:)`. That helper adds the
timer to the current run loop's `.defaultMode` — the same mode that's
suspended while a menu is being tracked or an `NSAlert` is modal. So
the poller was *silently frozen* during the exact moment the user was
reading "the icon will brighten when access is granted."

**Fix**: schedule on `RunLoop.main.add(timer, forMode: .common)` so it
keeps firing through menus and modals.

### 2. TCC indexes by cdhash; ad-hoc rebuilds drift (fixed in 1.6.0)

Each `make install` produced a fresh ad-hoc-signed binary with a new
cdhash, and TCC pinned the Accessibility grant to the old cdhash. Even
with a stable bundle identifier, a rebuild looked like a different app
to TCC.

**Fix A**: `scripts/build.sh` now signs with `--requirements
'=designated => identifier "com.rohin.multipaste"'`, making the
designated requirement match by bundle ID rather than cdhash. macOS
14+ honors this for ad-hoc apps so grants carry across rebuilds.

**Fix B**: a **Reset Accessibility Permission** menu item runs
`/usr/bin/tccutil reset Accessibility com.rohin.multipaste` for stale
entries inherited from earlier builds.

### 3. LaunchAgent-supervised processes don't get TCC grants (fixed in 1.6.0)

The biggest bug, and the most surprising. Empirically reproduced this
session:

```
$ ~/Applications/Multipaste.app/Contents/MacOS/Multipaste    # direct launch
[multipaste 1.6.0 pid=N] trust=ON

$ launchctl kickstart -k gui/$UID/com.rohin.multipaste        # via LaunchAgent
[multipaste 1.6.0 pid=M] trust=OFF
```

Same .app, same cdhash, same designated requirement, same user — only
the launch context differed. macOS 26 Tahoe's TCC refuses Accessibility
grants to processes spawned by launchd as user-level LaunchAgents. This
is undocumented but reproducible.

**Fix**: switched to `SMAppService.mainApp.register()`, the modern
Apple-recommended login-item API (used by Maccy, Rectangle, AltTab).
SMAppService-launched processes get full TCC permissions like any
user-launched app.

A one-shot migration on first launch deletes any leftover LaunchAgent
plist from earlier installs.

### 4. The famous pipe-drain deadlock (fixed in 1.6.1)

`SingleInstance.enforce()` ran `/bin/ps -Ao pid,lstart,command` to find
sibling Multipaste processes. The code did the naive

```swift
try task.run()
task.waitUntilExit()
let data = pipe.fileHandleForReading.readDataToEndOfFile()
```

— which is fine until ps output exceeds the kernel pipe buffer
(typically 64 KB). On a busy macOS system with hundreds of processes,
`ps -Ao` easily produces > 80 KB. ps blocks writing into the full
pipe, we block waiting for ps to exit. **Classic UNIX pipe deadlock.**

The Multipaste main thread sat at `main.swift:9` forever, never reaching
`NSApp.run()`. `ps`, `lsappinfo`, and `launchctl list` all reported the
process as "running" — and they were technically correct. But the app
had no menu-bar icon, no event loop, no anything.

**Diagnosis tool**: `/usr/bin/sample <pid> 1` dumped a 1-second
call-graph profile and showed the stack pinned at `Multipaste_main +
20`, which source-mapped to `main.swift:9` — `SingleInstance.enforce()`.

**Fix**: drain the pipe asynchronously via `readabilityHandler` into a
`Data` accumulator *before* calling `waitUntilExit`. Same fix that 1.6.0
had already applied to `Diagnostics.readCodesign` — but the duplicate
pattern in `SingleInstance` was missed until 1.6.1.

---

## License

<a href="https://polyformproject.org/licenses/strict/1.0.0/"><img src="https://polyformproject.org/strict.png" width="80" align="right" alt="PolyForm Strict 1.0.0 badge"></a>

[PolyForm Strict License 1.0.0](LICENSE.md) — source-available,
noncommercial only. **Multipaste is NOT open source** in the OSI sense.

The PolyForm family of licenses lives at
<https://polyformproject.org/>. Strict is the most restrictive
permitted-use license in the family: noncommercial use is permitted,
but redistribution and derivative works are not. Source is publicly
visible so you can audit it, learn from it, file bug reports, and
propose improvements — but the code itself remains under my sole
control while I evaluate the path to a commercial product.

**What you can do (no permission needed):**

- **Run it for personal use** — including hobby projects, private
  entertainment, study, religious observance, anything without
  "anticipated commercial application."
- **Run it inside a charity, school, public-research org, public-safety
  org, environmental nonprofit, or government institution** —
  PolyForm Strict explicitly lists these as permitted uses
  ("Noncommercial Organizations" clause).
- **Read the source** — it's on GitHub. Audit it. Learn from it.
- **File issues, suggest features, report security bugs** — the issue
  tracker is open.
- **Exercise your fair-use rights** — the license does not limit them.

**What you cannot do without a separate license:**

- **Redistribute Multipaste** — neither the source nor the compiled
  binary. The DMG download link must point at the official GitHub
  Releases page. (Homebrew's cask formula is fine — it points users at
  the official URL rather than redistributing the binary itself.)
- **Modify the source for personal use and share the result.** Personal
  modifications you keep to yourself aren't really exercised under the
  copyright license, but conveying modifications to anyone else is not
  permitted.
- **Use it commercially** — selling it, embedding it in a product you
  sell, deploying it on commercial infrastructure for revenue-
  generating activity, etc. The "Noncommercial Purposes" clause is
  exclusive: anything with "anticipated commercial application" is
  outside the grant.
- **Fork it as a competing product** — PolyForm Strict explicitly
  forbids derivative works.

**Why this license, and not MIT / Apache / AGPL?**

This project may eventually become a commercial product. PolyForm
Strict preserves that path: I retain all commercial rights, the source
stays visible (which is good for trust, transparency, and personal
users), and I can relicense future versions under any terms — including
fully proprietary, closed-source — because I am the sole copyright
holder. MIT or Apache would have given the code away; AGPL would have
required anyone embedding it (including me, in a future product) to
release downstream source. PolyForm Strict gives me the freedom to make
that call later.

**Commercial license inquiries:** <rohin.agrawal@gmail.com>.

**Patent grant + patent-defense + warranty disclaimer:** see the
"Patent License," "Patent Defense," and "No Liability" sections of the
LICENSE.md file. Notable: filing a patent claim against Multipaste
immediately terminates your patent license; ordinary violations have a
32-day cure period before all licenses terminate.

Full text in [LICENSE.md](LICENSE.md). Canonical reference:
<https://polyformproject.org/licenses/strict/1.0.0/>.

---

## Contributing

**Yes, pull requests are welcome** — even though PolyForm Strict on
its own forbids derivative works. The mechanism that makes this work
is a [Contributor License Agreement
(CLA)](CONTRIBUTING.md#contributor-license-agreement-cla) in
[CONTRIBUTING.md](CONTRIBUTING.md). Opening a PR constitutes
agreement with the CLA, which:

- Grants the licensor (Rohin) a perpetual, worldwide, irrevocable,
  royalty-free license to use, modify, distribute, and sublicense
  your contribution.
- Grants the licensor the right to **relicense** your contribution
  under any future terms — including fully proprietary closed-source
  — without coming back to you for permission. This is the unusual
  clause; please read it before contributing.
- Grants you (the contributor) a one-time, scoped permission to make
  the changes in your PR despite PolyForm Strict's general
  prohibition on derivative works.

Before opening a PR, read [CONTRIBUTING.md](CONTRIBUTING.md) in full
— it covers the CLA, what kinds of contributions are welcome (bug
fixes, perf improvements, doc fixes, test coverage, accessibility),
what is *not* welcome (telemetry, new dependencies, wholesale
redesigns), build/test commands, commit-message style, and the PR
workflow.

Bug reports: open an issue using the
[bug-report template](.github/ISSUE_TEMPLATE/bug_report.md). For
security issues, do NOT open a public issue — email
<rohin.agrawal@gmail.com> directly.

---

## Made for

Rohin Agrawal. Personal-use macOS daily-driver: native Swift app,
custom test harness, DMG installer, Homebrew tap, GitHub releases,
update checker, four-bug forensic deep dive. v2.0.0 added source-
available PolyForm Strict licensing with full SPDX/REUSE compliance,
a Contributor License Agreement, an issue-template chooser, SECURITY.md,
and 133 tests covering every artifact (including this README). v2.1.0
added auto-copy of screenshots (every ⌘⇧3 / ⌘⇧4 / ⌘⇧5 lands on the
clipboard automatically — no more ⌃ modifier to remember, no more
dragging files out of Finder) AND fixed the update-dialog bug where
the painstakingly-formatted CHANGELOG markdown was rendered as raw
`##` / `**` / ``` ` ``` sigils because `NSAlert.informativeText`
doesn't render markdown — now uses a styled `NSAttributedString` in
a scrollable accessory view, so users see bold + monospaced code +
links the way the changelog meant them. v2.1.1 fixed the pin button
being a visible no-op — pinned items now ALWAYS rise to the top of
the picker, search results, and the menu-bar Recent dropdown, not
just survive eviction past the history cap. v2.1.2 fixed the
single-instance guard SIGTERM-ing innocent bystander processes — it
matched the binary path anywhere on a `ps` line (killing any shell,
grep, or editor that merely referenced the path) instead of keying on
the process's actual executable. v2.1.3 made unpinning keep the item
where it is — top of the unpinned section — instead of teleporting it
back to the far-away slot where it was first copied. v2.2.0 fixed the
picker's "press Return and nothing pastes until you reopen it a few times"
race: the picker is now a non-activating panel that never steals focus from
the app you're pasting into, and the synthesized ⌘V carries the
device-dependent Command bit Chromium and Electron apps require. v2.3.0
delivered the namesake feature: mark several items in the picker (⌥↩,
⌘-click, Space, ⌥⌘A) and one Return pastes them all, as merged text with a
configurable separator, as a single multi-file paste, or sequentially when
images are in the mix. 271 tests now.
Search before building. Test before shipping. Boil the ocean.
