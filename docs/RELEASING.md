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

Then the live manual checklist for the release's headline feature (for
v2.4.0 it's the 5-step list at the end of
`docs/reviews/v2.4.0-FINDINGS.md`). A synthetic ⌘⇧V (osascript System
Events) DOES trigger the Carbon hotkey on macOS 26, so the picker can be
opened headlessly for verification.

## 6. Rollback (if something is wrong after ship)

```sh
gh release delete vX.Y.Z --yes && git push origin :refs/tags/vX.Y.Z
cd ~/code/homebrew-multipaste && git revert HEAD && git push
brew update && brew reinstall --cask multipaste   # back to previous cask version
```

Nothing in the ship is irreversible except users who already downloaded;
prefer a fast-follow patch release over rewriting a published tag.
