# Multipaste

**Win+V for macOS.** A native, persistent clipboard history *and* snippet
expander with a global hotkey, a picker window, pinning, search, and full
keyboard navigation. Built for macOS 13+ (tested on macOS 26 Tahoe).

```
Press ⌘⇧V anywhere → picker appears → ↑↓ pick → ↩ paste
```

That's it. No subscriptions, no Electron, no telemetry, no account. ~60 KB
of native Swift, runs at ~0% CPU when idle, starts at login.

---

## Install

### 🟢 Easy — drag and drop (no Terminal)

1. Download **[Multipaste-1.2.0.dmg](https://github.com/NewdlDewdl/multipaste/releases/latest)**
   from the latest release.
2. Open the DMG. Drag **Multipaste** onto **Applications**.
3. Open your Applications folder, right-click **Multipaste**, choose **Open**,
   then **Open** again in the warning dialog. *(macOS asks this once for any
   app that isn't from the App Store — it won't ask again.)*
4. The Welcome window appears. Click **Enable** under "Start at login",
   then **Open System Settings** under "Accessibility" and toggle Multipaste
   on. Click **Get Started**.

You're done. Press ⌘⇧V anywhere.

### 🍺 Homebrew — one command

```sh
brew install --cask NewdlDewdl/multipaste/multipaste
```

Then open Multipaste from Spotlight or `/Applications` and follow the
Welcome window. The cask handles uninstall (`brew uninstall --cask multipaste`)
and clean-up of preferences when you `brew uninstall --zap`.

### 🛠 From source (devs)

```sh
git clone https://github.com/NewdlDewdl/multipaste
cd multipaste
make install            # build + install + LaunchAgent + load
```

The legacy `install.sh` path uses a LaunchAgent instead of the modern
Login Item. Both auto-start at login; pick whichever you prefer.

---

## How does it compare?

| | **Multipaste** | Maccy | Flycut | Paste | Pastebot | CopyClip&nbsp;2 | Alfred | Raycast | Espanso |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Price** | 🆓 | 🆓 | 🆓 | $29.99/yr | $12.99 | Paid | £34+ | 🆓 (Pro $8+) | 🆓 |
| **License** | MIT | MIT | MIT | Proprietary | Proprietary | Proprietary | Proprietary | Proprietary | GPL-3 |
| **Clipboard history** | ✓ | ✓ | text only | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| **Image capture** | ✓ | ✓ | ✗ | ✓ | ✓ | ✗ | ✓ | ✓ | n/a |
| **Rich text (RTF)** | ✓ | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | n/a |
| **File URLs** | ✓ | ✓ | ✗ | ✓ | ? | ✗ | ✓ | ✓ | n/a |
| **Pinned items** | ✓ | ✓ | ✗ | ✓ (pinboards) | ✓ | ✓ | ~ | ✓ | n/a |
| **Snippet expansion** | ✓ | ✗ | ✗ | ~ (no typed triggers) | ~ | ✗ | ✓ (separate) | ✓ (separate) | ✓ |
| **History + snippets, one tool** | **✓** | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Fuzzy search** | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Configurable hotkey** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Password managers excluded** (`nspasteboard.org`) | ✓ | ✓ | ✗ | ? | ? | ~ | ~ | ✓ | n/a |
| **Idle RAM** (approx) | **~50 MB** | ~80 MB | ~30 MB | ~150 MB | ~120 MB | ~60 MB | ~100 MB | ~250 MB | ~80 MB |
| **Sign-in / account** | none | none | none | required | none | none | none | optional | none |
| **Telemetry** | none | none | none | ? | ? | ? | none | yes | none |
| **Open source** | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |

**Why pick Multipaste over the closest free competitor (Maccy)?** Maccy
doesn't do snippet expansion. Multipaste does, in the same window, on the
same pinned items. Pin once, give it a trigger, type the trigger anywhere.

**Why pick it over Raycast?** Raycast is closed-source, ships its own
account flow, has telemetry, and is ~5× the RAM. Multipaste is one
program, MIT, no network calls.

**Why pick it over Espanso?** Espanso is snippet expansion only — no
clipboard history. Multipaste does both. Snippets are defined inline
(pin an item + give it a trigger), not in a YAML config file.

**Why pick it over Paste or Pastebot?** They're paid; Multipaste is free.
They don't do trigger-based snippet expansion either.

---

## Updates

Multipaste checks the GitHub Releases API on launch and once every 24
hours after that. When a newer version exists, you get a single alert
with three choices: Download, Skip This Version, or Remind Me Later.
**Silent when you're up-to-date.**

To check manually: menu-bar 📋 → **Check for Updates…**.

There's no auto-installer — the alert opens the release page in your
browser where you grab the new DMG (or run `brew upgrade --cask
multipaste`). Atomic-swap auto-installs require a code-signing identity
we don't have; this is the next-best, and you stay in control.

## After install — granting Accessibility access

Auto-paste and snippet expansion need macOS Accessibility permission.
Without it, **Multipaste still works** — picks land on your clipboard and
you press ⌘V manually — but you give up the magic. Granting access is
~30 seconds:

### From inside Multipaste (fastest)

When Multipaste needs Accessibility, the menu-bar icon dims and the menu
shows a yellow banner at the top:

```
⚠️  Grant Accessibility access…
    Needed for auto-paste and snippets
```

Click it. Multipaste does three things for you:

1. **Adds itself to the Accessibility list** automatically (via the
   `AXIsProcessTrustedWithOptions` system call — this is the step that
   pre-populates Multipaste in the toggle list so you don't have to
   hunt for it with the `+` button).
2. **Opens System Settings** straight to **Privacy & Security →
   Accessibility**.
3. **Shows a step-by-step alert** with the exact toggles to flip.

Toggle Multipaste **on** in System Settings. macOS asks for Touch ID or
your password. The moment access is granted, Multipaste pops up a
"Granted!" confirmation, restarts the snippet engine, and the menu-bar
icon brightens. No restart needed.

### Manually (if Multipaste isn't running yet, or you want to do it yourself)

1. **Apple menu → System Settings…**
2. In the sidebar, click **Privacy & Security**.
3. In the main pane, scroll down and click **Accessibility**.
4. **If Multipaste is in the list** → flip the toggle to **on**, confirm
   with Touch ID. Done.
5. **If Multipaste is NOT in the list**:
   - Click the **+** button below the list.
   - In the file picker: **Applications** → **Multipaste**, then **Open**.
   - Toggle the switch **on**.

If Multipaste was running before you toggled, quit it (menu-bar 📋 → Quit)
and relaunch from Applications so the new permission registers. (v1.4.0
detects this automatically — no restart needed — but older versions don't.)

### What's it actually for?

- **Auto-paste** — synthesizes ⌘V into the focused app after you pick an
  item from the picker. Without Accessibility, the system blocks any
  process from posting keyboard events.
- **Snippet expansion** — observes your typing system-wide, deletes the
  trigger text, types the expansion. Both halves need Accessibility.

That's it. Multipaste does not log keystrokes, does not exfiltrate, does
not make network calls outside the once-a-day update check
(`api.github.com/repos/NewdlDewdl/multipaste/releases/latest`). `grep -r
URLSession Sources` is the audit.

---

## Keys

In the picker:

| Key            | Action                                       |
| -------------- | -------------------------------------------- |
| `↑` / `↓`      | Move selection                               |
| `↩`            | Paste selected item                          |
| `⌘1` … `⌘9`    | Quick-paste the Nth visible item             |
| `⌘P`           | Pin / unpin selected item                    |
| `⌘E`           | Set / edit a snippet trigger for the item    |
| `⌘⌫`           | Delete selected item from history            |
| `esc`          | Close picker                                 |
| type anything  | Filter the history (case-insensitive)        |

Pinned items survive the eviction cap. Use them for frequently-pasted
snippets — your shipping address, an SSH key fingerprint, the boilerplate
import block.

### Settings

Open with the menu-bar icon → **Preferences…** (or `⌘,` when the menu is open).

- **General** — record a new hotkey by clicking the field and pressing the
  combo. Toggle auto-paste, launch-at-login, and history size (10–2000).
- **Snippets** — view and edit all triggers. Add new ones from the picker
  via `⌘E`.
- **About** — version info.

The hotkey recorder requires at least one modifier (otherwise plain letters
would be swallowed system-wide). Esc cancels recording.

### Snippet expansion

Pinned items can have a **trigger** — typing that string followed by space,
tab, or return anywhere on macOS expands it. For example:

1. Copy `rohin.agrawal@gmail.com` so it lands in your history.
2. Open the picker (`⌘⇧V`), select it, press `⌘E`, type `;e`, hit Save.
3. From now on, in any text field, typing `;e ` becomes
   `rohin.agrawal@gmail.com`. The trigger and the terminating space are
   deleted; the snippet is pasted.

Snippet expansion needs **Accessibility** permission (same prompt as the
auto-paste flow). Without it, the snippet engine silently no-ops.

Trigger picking rules:

- Triggers fire ONLY on **pinned** items with a non-empty trigger.
  Setting a trigger auto-pins the item.
- Terminators are space, tab, or return.
- Longest match wins (so `;email` doesn't get eaten by `;m`).
- Cmd/Ctrl-bearing keystrokes reset the buffer — no surprise expansion
  inside hotkey combos.

There is no Espanso-style YAML config: the snippet store IS the clipboard
history. Pin something, give it a trigger, you're done.

---

## What it captures

- Plain text
- Rich text (RTF — formatting preserved when you paste back)
- Images (PNG/TIFF — re-pasteable as image)
- File references (multi-select Finder copies, etc.)

What it ignores:

- Anything tagged with `org.nspasteboard.ConcealedType`
  (1Password, KeePassXC, Bitwarden, and other password managers set this)
- Anything tagged with `org.nspasteboard.TransientType`
- Anything tagged with `org.nspasteboard.AutoGeneratedType`

This follows the [nspasteboard.org] community convention so passwords never
land in history. There's no app-specific blocklist needed — well-behaved
password managers opt themselves out.

[nspasteboard.org]: https://nspasteboard.org

---

## Menu-bar controls

The 📋 icon in the menu bar gives you:

- **Show Clipboard History** — same as the hotkey
- **Recent** — `⌘1`-`⌘9` quick-paste from the menu without opening the picker
- **Pause Monitoring** — stop capturing new items (keeps existing history)
- **Clear History (Keep Pinned)** — wipe everything except pinned items
- **Clear All** — full wipe including pinned
- **Open Data Folder** — reveal `~/Library/Application Support/Multipaste`
- **Quit Multipaste** — stop the agent (`launchctl` will restart it next login;
  use `make uninstall` to disable permanently)

---

## Architecture

```
        ┌──────────────────────────┐    ┌──────────────────────────┐
        │  Carbon RegisterEventHK  │    │   CGEvent.tapCreate      │
        │  (⌘⇧V global hotkey)     │    │   (session keyboard tap) │
        └────────────┬─────────────┘    └────────────┬─────────────┘
                     │ press                         │ each keystroke
                     ▼                               ▼
   ┌──────────────────┐            ┌──────────────────┐
   │ ClipboardMonitor │            │  SnippetEngine   │
   │ polls NSPaste-   │            │  buffer ⇒        │
   │ board every 300ms│            │  SnippetMatcher  │
   └────────┬─────────┘            └────────┬─────────┘
            │ insert                         │ on match: backspace+paste
            ▼                                ▼
   ┌──────────────────┐                                   ┌────────────────┐
   │   HistoryStore   │◀──── observe ───── PickerWindow   │     Paster     │
   │  JSON-persisted  │◀──── observe ───── SettingsWindow │  pasteboard    │
   └──────────────────┘                                   │  + CGEvent ⌘V  │
                                                          └────────────────┘
```

- **MultipasteCore** (library, pure Swift) — `ClipboardItem`,
  `HistoryStore`, `Preferences`, `SnippetMatcher`. No AppKit. Fully
  unit-testable.
- **Multipaste** (executable, AppKit-bound) — `AppDelegate`,
  `ClipboardMonitor`, `HotKeyManager` (Carbon), `Paster` (CGEvent),
  `PickerWindow`, `ItemCellView`, `ThumbnailCache`, `MenuBarController`,
  `SettingsWindowController`, `HotkeyRecorderField`, `SnippetEngine`,
  `LoginAgent`, `Permissions`.

### Why polling, not a notification?

`NSPasteboard` has no KVO. There's no `pasteboardDidChange:` delegate.
Every clipboard manager on macOS — Maccy, Paste, Pastebot, Alfred — polls
`changeCount`. 300ms is the consensus sweet spot.

### Why Carbon for hotkeys?

`RegisterEventHotKey` lives in `Carbon.HIToolbox`. It still works in
2026 (Apple has shown no signs of removing it; it's how
`MASShortcut`, `KeyboardShortcuts`, and Sparkle do it). Crucially: it
does **not** require Accessibility permission, so the hotkey works the
moment the agent starts. Only the `simulateCommandV()` keystroke
synthesis does (gated behind `AXIsProcessTrusted`).

---

## Development

```sh
make test          # run the unit-test harness (25 tests, ~30ms)
make build         # produce dist/Multipaste.app
make run           # run the bundled binary in foreground (Ctrl-C to stop)
make install       # build + install to ~/Applications + load LaunchAgent
make uninstall     # remove app and unload agent (preserves history)
make purge         # uninstall + delete history and logs
make status        # is the agent running?
make logs          # tail stdout/stderr logs
make clean         # remove .build and dist
```

### Tests

Tests use a small custom harness (`Tests/MultipasteCoreTests/TestHarness.swift`)
that runs as `swift run MultipasteTests`. This avoids needing full Xcode —
the Command Line Tools-only toolchain ships neither XCTest's
testing import overlay nor `swift-testing`'s `_Testing_Foundation` module
in a SwiftPM-consumable form, so the harness is the most portable option.

Each test is a static `throws` function registered into `TestRegistry`;
the runner counts failures and exits non-zero on any. CI-friendly.

### Files

```
Package.swift
Makefile
README.md  LICENSE  CHANGELOG.md
Sources/
  MultipasteCore/      ← testable, pure Swift:
                          ClipboardItem  HistoryStore  Preferences
                          SnippetMatcher  Version
  Multipaste/          ← AppKit / system:
                          AppDelegate  AppPaths  ClipboardMonitor
                          HotKeyManager  HotkeyRecorderField
                          LoginAgent  MenuBarController  Paster
                          Permissions  PickerWindow
                          SettingsWindowController  SnippetEngine
                          ThumbnailCache  main.swift
Tests/MultipasteCoreTests/
  ClipboardItemTests.swift  HistoryStoreTests.swift
  PreferencesTests.swift    SnippetMatcherTests.swift
  TestHarness.swift         main.swift
Resources/
  Info.plist  PkgInfo
LaunchAgent/
  com.rohin.multipaste.plist  (template; install.sh substitutes paths)
scripts/
  build.sh  install.sh  uninstall.sh
```

---

## Data & privacy

- History lives at `~/Library/Application Support/Multipaste/history.json`
  in plain JSON. Inspect it, back it up, or delete it.
- Preferences live in `~/Library/Preferences/com.rohin.multipaste.plist`.
- Logs land in `~/Library/Logs/Multipaste/`.
- Nothing leaves your machine. There is no network code in this app.
- Password-manager copies are filtered out via the `nspasteboard.org`
  privacy markers — same convention every well-behaved manager supports.

To audit: `grep -r -i network Sources` (there are no matches) and
`grep -r URLSession Sources` (also no matches).

---

## Troubleshooting

**Hotkey does nothing.** Another app may have it registered. Try the
menu-bar icon → Show Clipboard History to confirm Multipaste itself is
running. If that works, choose a different hotkey (edit `prefs.hotkey`,
restart agent).

**Pick lands on clipboard but doesn't auto-paste.** You haven't granted
Accessibility. System Settings → Privacy & Security → Accessibility → add
`~/Applications/Multipaste.app` and toggle it on.

**Agent isn't running after reboot.** `make status` should print a line
with the PID. If it doesn't, `make logs` shows what crashed. The most
common cause is moving `Multipaste.app` after install — the LaunchAgent
plist hard-codes the absolute path. Run `make install` to refresh.

**History survives uninstall.** That's intentional. `make purge` wipes
everything.

---

## Made for

Rohin. Built in one sitting, in one repo, with tests and docs. No
shortcuts; the answer to "add multipaste to my Mac" is the finished
product.
