# Releasing Multipaste (permanent runbook)

The complete path from "green branch" to "Rohin's Mac runs the new
version via Homebrew and GitHub is fully updated." Written during the
v2.4.0 ship; keep it current: when a release trips over something new,
add the gotcha here in the same change that works around it.

## 0. Pre-flight gates (all must pass on the EXACT commit you ship)

```sh
cd ~/code/multipaste
make test                  # read the count AND the exit code
make plaintext-smoke-test  # mirror script + shipped executor (--paste-smoke)
make smoke-test            # screenshot pipeline
make verify-app            # universal + codesign + version consistency
```

Version consistency is test-enforced (`VersionConsistency` suite):
`Version.swift`, `Info.plist` (`CFBundleShortVersionString` AND a bumped
`CFBundleVersion`), README hero `Download vX.Y.Z` + `Multipaste-X.Y.Z.dmg`,
CHANGELOG's newest `## X.Y.Z` entry, and SECURITY.md's supported table
must all agree. If `make test` is green, they agree.

## 1. Build + hash the artifact

```sh
bash scripts/dmg.sh                          # writes dist/Multipaste-X.Y.Z.dmg
shasum -a 256 dist/Multipaste-X.Y.Z.dmg      # RECORD this hash
```

**Never rebuild the DMG after recording the hash.** The file you hash is
the file you upload is the hash you put in the cask. Three uses, one file.

## 2. Merge + push (GitHub source of truth)

```sh
git checkout main
git merge --no-ff <release-branch> -m "vX.Y.Z: <slug>"
make test && make verify-app                 # re-gate ON MAIN after merge
git push origin main
git push origin <release-branch>             # keep branch history on GitHub
```

## 3. GitHub release

Conventions (verified against v2.2.0/v2.3.0): tag `vX.Y.Z`, title
`vX.Y.Z: <short slug>`, body = the CHANGELOG entry for this version
(without the `## X.Y.Z` heading line), the DMG attached as the asset.

```sh
# extract the newest CHANGELOG entry body into a notes file first
gh release create vX.Y.Z dist/Multipaste-X.Y.Z.dmg \
  --title "vX.Y.Z: <slug>" --notes-file /path/to/notes.md
gh release view vX.Y.Z --json tagName,assets   # CoVe: tag + asset exist
```

The in-app `UpdateChecker` reads the GitHub *latest release* tag, so the
moment this lands, running older installs will offer the update.

## 4. Homebrew cask bump

The tap source lives at `~/code/homebrew-multipaste` (pushes to
`NewdlDewdl/homebrew-multipaste`). Edit `Casks/multipaste.rb`: `version`
and `sha256` (the recorded hash). Commit message convention:
`multipaste X.Y.Z`.

```sh
cd ~/code/homebrew-multipaste
$EDITOR Casks/multipaste.rb
git commit -am "multipaste X.Y.Z" && git push
```

Gotchas already learned:
- The tap is TRUSTED since 2026-06-10 (`brew trust newdldewdl/multipaste`);
  a fresh machine needs that once or upgrade refuses to load the cask.
- `brew upgrade` reads the tap's CLONE under
  `$(brew --prefix)/Library/Taps/newdldewdl/homebrew-multipaste`; run
  `brew update` first so the clone pulls your push.
- `depends_on macos:` must use the SYMBOL form (`:ventura` = Ventura or
  newer; Homebrew's MacOSRequirement defaults to the `>=` comparator).
  The string form `">= :ventura"` is deprecated and warns on every brew
  command (fixed in the tap 2026-07-04). `brew audit --cask
  newdldewdl/multipaste/multipaste` catches this class of problem; run it
  after any cask edit.

## 5. Update the local install

```sh
brew update
brew upgrade --cask multipaste
```

Post-upgrade verification (all four, not a sample):

```sh
defaults read /Applications/Multipaste.app/Contents/Info.plist CFBundleShortVersionString
    # must print the new version
pgrep -x Multipaste                        # running (relaunch if the upgrade quit it)
tail -5 ~/Library/Logs/Multipaste/multipaste.log   # fresh boot line
# paste still works WITHOUT re-granting Accessibility: the stable codesign
# designated requirement (identifier-only DR) carries the TCC grant across
# rebuilds. If paste is dead, check System Settings > Accessibility first.
```

**`pgrep` alone LIES after an upgrade.** Homebrew removes the old bundle,
but the pre-upgrade process keeps running from the deleted inode, so
"process running" does not mean "new version running". Proof channel: the
log's boot line self-reports the version and pid
(`[multipaste X.Y.Z pid=N]`), and `ps -o lstart= -p <pid>` shows a start
time older than the upgrade for a stale image. Always quit and relaunch as
part of the upgrade (`osascript -e 'tell application id
"com.rohin.multipaste" to quit'` then `open -a Multipaste`), then confirm
the new pid's boot line and `trust=ON` (Accessibility survived).

Then the live checklist for the release's headline feature (for v2.4.0
it's the 5-step list at the end of `docs/reviews/v2.4.0-FINDINGS.md`; all
5 steps were verified synthetically at ship time 2026-07-04, no finger
needed). The whole checklist is drivable headlessly; recipe:

- A synthetic ⌘⇧V (osascript System Events `key code 9 using {command
  down, shift down}`) DOES trigger the Carbon hotkey on macOS 26.
- **The pasteboard is the oracle.** `Paster.put` writes the general
  pasteboard before synthesizing ⌘V, so after any picker action, read
  the pasteboard TYPES: `public.rtf` present = rich paste, string-only =
  plain paste, file URLs = rich file paste. Pair each check with the log
  line (`pickAndPaste[single|combined(N items)]`) to prove a paste really
  executed. The tool for both halves is in-repo: `scripts/pbtool.swift`
  (compile with `swiftc -O scripts/pbtool.swift -o /tmp/pbtool`), modes
  `rich <text>` / `file <path...>` / `info`.
- **Pinned items sort first**, so ↩ right after open pastes a pin, not
  your sentinel. Always type a unique filter (e.g. `PASTECHECK`) before
  ↩ / ⇧↩.
- **`screencapture` closes the picker**: taking a screenshot makes the
  panel resign key and it hides (`picker.resignKey → hide` in the log),
  and every later keystroke lands in the front app instead. Screenshot
  the hint bar in a SEPARATE picker session from the paste checks.
- **Synthetic ⌥↩ does not register** (the mark never happens; the paste
  stays `[single]`). Use ⌥⌘A (mark all visible under the filter) for
  multi-paste checks. ⌘⌫ (delete) and esc work synthetically, which is
  also how to purge sentinel items from history afterward: filter, then
  ⌘⌫ once per match, and verify with a grep of
  `~/Library/Application Support/Multipaste/history.json`.
- Prefs can be flipped live from the shell (`defaults write
  com.rohin.multipaste plainTextPasteDefault -bool true`); the app reads
  UserDefaults on every access, so no relaunch is needed. `defaults
  delete` restores the registered default afterward.

## 6. Rollback (if something is wrong after ship)

```sh
gh release delete vX.Y.Z --yes && git push origin :refs/tags/vX.Y.Z
cd ~/code/homebrew-multipaste && git revert HEAD && git push
brew update && brew reinstall --cask multipaste   # back to previous cask version
```

Nothing in the ship is irreversible except users who already downloaded;
prefer a fast-follow patch release over rewriting a published tag.
