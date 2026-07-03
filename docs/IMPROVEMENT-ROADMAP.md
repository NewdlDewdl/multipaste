<!-- SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal -->
<!-- SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0 -->

# Multipaste improvement roadmap

Generated 2026-07-03 by an 8-lens reverse-prompting agent swarm that read the
actual v2.3.0 codebase (power-user UX, reliability/correctness, competitor
parity, architecture/maintainability, privacy/security, performance/resource,
accessibility/i18n, testing gaps), then synthesized + adversarially
verified the top ship-now pick. 43 raw ideas deduped to the 33 ranked below,
best-first by (impact x reach) / effort. Every entry is grounded in real
file/line evidence from the sources.

**Rank 1 (paste as plain text) and rank 2 (preserve snippet trigger on
re-copy) shipped in v2.4.0.** The rest is the standing backlog.

`ship-now` = self-contained, has a pure-logic testable Core, needs no
interactive-GUI verification, fits the ethos (no telemetry/deps/redesign,
macOS 13-safe). `core` = has a pure AppKit-free policy at its heart.

| # | Title | Impact | Effort | ship-now | core | Category |
|--:|-------|:------:|:------:|:--------:|:----:|----------|
| 1 | Paste as plain text (⇧↩ in picker + optional default), strips RTF formatting | high | small | ✓ | ✓ | power-user-ux |
| 2 | Preserve snippet trigger on re-copy (dedup drops trigger, silently killing the snippet) | high | small | ✓ | ✓ | reliability-correctness |
| 3 | Corrupt/truncated history.json wipes everything incl. pinned snippets; add quarantine + backup fallback | high | medium | ✓ | ✓ | reliability-correctness |
| 4 | Search matches snippet trigger + prefix/word-boundary ranking | high | medium | ✓ | ✓ | power-user-ux |
| 5 | maxHistory setting is frozen at launch; add HistoryStore.reconfigure(maxItems:) | high | small | ✓ | ✓ | reliability-correctness |
| 6 | Undo last destructive action (delete / Clear All / Clear History) | high | medium | ✓ | ✓ | power-user-ux |
| 7 | Stop rewriting the whole 9.4MB history.json on every copy; debounce saves + use the dead queue | high | medium | ✓ | ✓ | performance-resource |
| 8 | Cap/downscale captured images so a Retina screenshot doesn't bloat history to megabytes | high | medium | ✓ | ✓ | performance-resource |
| 9 | Extract pasteboard-kind classification into a pure PasteboardClassifier and test the priority table | high | medium | ✓ | ✓ | testing-quality-gaps |
| 10 | Extract the snippet keystroke-buffer state machine into a pure SnippetBuffer and test it | high | medium | ✓ | ✓ | architecture-maintainability |
| 11 | Sensitive-content classifier: skip/never-persist unmarked secrets (API keys, PEM, JWTs, cards) | high | medium | ✓ | ✓ | privacy-security |
| 12 | VoiceOver-accessible picker rows via a pure PickerRowAccessibility.label formatter | high | medium | ✓ | ✓ | accessibility-i18n |
| 13 | Time-based retention / TTL (auto-expire clips older than N) | medium | small | ✓ | ✓ | privacy-security |
| 14 | Copy-to-clipboard-without-pasting as a per-pick action (⌘↩ / ⌘C) | medium | small | ✓ | ✓ | power-user-ux |
| 15 | Per-source-app capture exclusion (block-list by bundle identifier) | medium | medium | ✓ | ✓ | privacy-security |
| 16 | Filter search by content kind (kind:image / type chips) | medium | medium | ✓ | ✓ | competitor-parity |
| 17 | Edit an item's content in place (not just its trigger) | medium | medium |  | ✓ | power-user-ux |
| 18 | Full-content preview / peek for items truncated at 240 chars | high | medium |  | ✓ | power-user-ux |
| 19 | Auto-clear / auto-pause on screen lock or sleep | medium | medium | ✓ | ✓ | privacy-security |
| 20 | Split image blobs into content-addressed sidecar files | high | large |  | ✓ | performance-resource |
| 21 | Extract PickerWindow.handleKey into a pure PickerKeyRouting enum + shared KeyCode table | medium | medium | ✓ | ✓ | architecture-maintainability |
| 22 | Clipboard content transforms (trim / case / collapse newlines) on paste | medium | medium | ✓ | ✓ | competitor-parity |
| 23 | Restrict history.json to owner-only perms (0600/0700) | medium | small | ✓ | ✓ | privacy-security |
| 24 | Adaptive poll interval to cut idle wakeups | medium | small | ✓ | ✓ | performance-resource |
| 25 | Fix/verify makePreview grapheme truncation + reconcile the newline-collapse doc/behavior mismatch | medium | small | ✓ | ✓ | testing-quality-gaps |
| 26 | MarkList↔MultiPasteComposer integration test (paste order == badge order after prune/toggleAll) | medium | small | ✓ | ✓ | testing-quality-gaps |
| 27 | Serialization/thread-safety honesty: remove or actually use the dead queue + lock the single-thread contract | medium | small | ✓ | ✓ | testing-quality-gaps |
| 28 | Cross-process file lock (flock) around load/save during single-instance handoff | low | medium |  | ✓ | reliability-correctness |
| 29 | Centralize dynamic picker/menu strings into a Core HintText seam (pluralization now, localization later) | low | medium | ✓ | ✓ | accessibility-i18n |
| 30 | Non-color signal for marks/pin (increase-contrast aware ContrastPolicy) | medium | medium |  | ✓ | accessibility-i18n |
| 31 | Extract ordinal(_:) into a tested Core Ordinal utility | low | small | ✓ | ✓ | accessibility-i18n |
| 32 | HistoryStore round-trip smoke script (real on-disk load/evict/legacy/corruption) | medium | small | ✓ |  | testing-quality-gaps |
| 33 | Reduce reloadData churn: row-scoped reloads for mark toggles + cache sortedForDisplay | medium | medium |  | ✓ | performance-resource |

---

## Detail (the grounded rationale for each)

### 1. Paste as plain text (⇧↩ in picker + optional default), strips RTF formatting  **[SHIPPED v2.4.0]**

*impact: high · effort: small · category: power-user-ux · ship-now: True · pure-core: True*

Merges ideas 1 and 13 (identical). Single highest impact-x-reach everyday action still missing: Paster.put writes .rtf+.string for rtf items (Paster.swift:28-31) so styled web/Word/Notion clippings drag fonts into plain fields. MultiPasteComposer.textRepresentation (MultiPasteComposer.swift:61-72) ALREADY extracts plain from every kind, so the pure core is nearly free. isShift is already computed in handleKey (PickerWindow.swift:344) but only used for Tab. Pure decision (which flavor, what string) is fully unit-testable; AppKit part is ~6 lines.

### 2. Preserve snippet trigger on re-copy (dedup drops trigger, silently killing the snippet)  **[SHIPPED v2.4.0]**

*impact: high · effort: small · category: reliability-correctness · ship-now: True · pure-core: True*

Idea 8, verified against HistoryStore.insert:35-38 which copies existing.pinned but NOT existing.trigger; the fresh factory item defaults trigger=nil (ClipboardItem.swift:43). Re-copying a snippet's exact text leaves a pinned-but-dead item: SnippetMatcher.match requires pinned AND non-empty trigger, so the snippet stops firing with zero notice. Trivial one-line fix, purely unit-testable in the exact HistoryStoreTests style.

### 3. Corrupt/truncated history.json wipes everything incl. pinned snippets; add quarantine + backup fallback

*impact: high · effort: medium · category: reliability-correctness · ship-now: True · pure-core: True*

Merges ideas 7 and 12. load() catch sets items=[] then save() overwrites (HistoryStore.swift:208-218); a single corrupt byte destroys the entire pinned-snippet library permanently. Existing test corruptStoreFileIsRecovered encodes the loss as intended. Add quarantine-corrupt-file + rotate history.bak + fallback on load; testable by feeding corrupt primary + valid backup. Durable fsync write (idea 12) folds in.

### 4. Search matches snippet trigger + prefix/word-boundary ranking

*impact: high · effort: medium · category: power-user-ux · ship-now: True · pure-core: True*

Merges ideas 4 (SearchRanker) and 22 (trigger-in-search); 4 is the superset. search() (HistoryStore.swift:152) filters preview substring only, never trigger, so typing 'addr' can't find the ;addr snippet. Extract a pure ItemSearch/SearchRanker: prefix>word-boundary>substring, match trigger too, empty-query unchanged. Fully unit-testable, mirrors TabNavigation/PasteRouting precedent.

### 5. maxHistory setting is frozen at launch; add HistoryStore.reconfigure(maxItems:)

*impact: high · effort: small · category: reliability-correctness · ship-now: True · pure-core: True*

Merges ideas 9 and 19 (identical). maxItems is let, set once (HistoryStore.swift:20,27); Settings writes only prefs.maxHistory (SettingsWindowController.swift:257). Changing history size does nothing until relaunch: silent gap in a shipped feature. Make it var + reconfigure(evict+save+notify), wire an onMaxHistoryChanged closure. Pure-logic down-evict test.

### 6. Undo last destructive action (delete / Clear All / Clear History)

*impact: high · effort: medium · category: power-user-ux · ship-now: True · pure-core: True*

Idea 3. Every destructive action is instant and irreversible; handleClearAll (MenuBarController.swift:259) nukes ALL incl. pinned snippets with no confirm/undo, yet Reset Accessibility gets a full NSAlert. Add a one-deep snapshot UndoBuffer in Core, wire ⌘Z. Pure snapshot-mutate-undo restores exact array/order.

### 7. Stop rewriting the whole 9.4MB history.json on every copy; debounce saves + use the dead queue

*impact: high · effort: medium · category: performance-resource · ship-now: True · pure-core: True*

Merges ideas 10 (partial) and 27. insert()->save() encodes the entire items array on every copy on the main-queue timer thread (HistoryStore.swift:42,214-223; ClipboardMonitor timer on .main). With inline PNGs the live file is 9.4MB, 96% images, so a 5-char copy rewrites ~9MB synchronously on main. Add a pure SavePolicy (coalesce bursts) + move encode/write onto the already-declared-but-unused queue (line 21).

### 8. Cap/downscale captured images so a Retina screenshot doesn't bloat history to megabytes

*impact: high · effort: medium · category: performance-resource · ship-now: True · pure-core: True*

Idea 28. snapshot() stores full-res PNG with no cap (ClipboardMonitor.swift:132-141); live file holds 5314x2924 screenshots, threatening the ~50MB idle bar. Pure ImageBudget policy: given (w,h,bytes)+caps return keepAsIs/downscale/reject. Only the HISTORY copy shrinks; live paste fidelity unaffected. Fully unit-testable with synthetic dims.

### 9. Extract pasteboard-kind classification into a pure PasteboardClassifier and test the priority table

*impact: high · effort: medium · category: testing-quality-gaps · ship-now: True · pure-core: True*

Merges ideas 37 and (partially) the marker logic. snapshot() (ClipboardMonitor.swift:114-159) encodes the highest-consequence pure decision (marker suppression + files>image>rtf>text) yet lives in AppKit code with ZERO tests; a reordered branch or a dropped nspasteboard marker ships green. Move the ladder to Core over an AppKit-free descriptor; unit-test each rule. High-value safety net that unblocks the per-app exclusion + sensitive-content ideas.

### 10. Extract the snippet keystroke-buffer state machine into a pure SnippetBuffer and test it

*impact: high · effort: medium · category: architecture-maintainability · ship-now: True · pure-core: True*

Merges ideas 20 and 39 (identical). The stateful buffer feeding SnippetMatcher lives in the CGEvent tap (SnippetEngine.swift:90-148): reset-on-Cmd/Ctrl/Esc, backspace pop, 64-char suffix window, clear-after-match. All untestable; a suffix->prefix mutation or dropped reset misfires expansions system-wide and ships green. Extract SnippetBuffer.feed(KeyEventKind); adapter shrinks. Also lock the pinned-invariant between .snippets and SnippetMatcher.

### 11. Sensitive-content classifier: skip/never-persist unmarked secrets (API keys, PEM, JWTs, cards)

*impact: high · effort: medium · category: privacy-security · ship-now: True · pure-core: True*

Idea 23. snapshot() only rejects the 3 nspasteboard markers; unmarked secrets (AWS AKIA, ghp_, sk_live_, PEM, JWT, Luhn cards) are captured and persisted plaintext forever. Pure classify(text)->SensitiveKind? with low-false-positive patterns; policy skip/captureButNeverPersist. Fully unit-testable. Guard against false positives before shipping.

### 12. VoiceOver-accessible picker rows via a pure PickerRowAccessibility.label formatter

*impact: high · effort: medium · category: accessibility-i18n · ship-now: True · pure-core: True*

Merges ideas 33 and 36 (shared formatter). ItemCellView is a bare NSView with no accessibility (PickerWindow.swift:580); multi-paste order is conveyed only by a colored badge + toolTip VoiceOver ignores, pin only by emoji. Pure label(for:index:markIndex:)->String composer is the meaty testable core; AppKit sets the label. Reused by the menu-bar a11y fix.

### 13. Time-based retention / TTL (auto-expire clips older than N)

*impact: medium · effort: small · category: privacy-security · ship-now: True · pure-core: True*

Merges ideas 16 and 24 (identical). Eviction is count-only (HistoryStore.evict:182-197); a token copied on a quiet day lingers plaintext for weeks. timestamp exists (ClipboardItem.swift:22) but is never read for pruning. Pure HistoryRetention.expired(items:now:maxAge:) dropping unpinned-older-than-TTL; inject 'now' for tests.

### 14. Copy-to-clipboard-without-pasting as a per-pick action (⌘↩ / ⌘C)

*impact: medium · effort: small · category: power-user-ux · ship-now: True · pure-core: True*

Idea 5. Only way to stage a clip without auto-typing is toggling the global pasteOnSelect. Add a per-pick copy-only commit path (onPick pasteAfter:false). Small; policy enum is a thin pure addition. Verifying no-⌘V-synthesized ideally wants a GUI eyeball, hence not the top ship-now.

### 15. Per-source-app capture exclusion (block-list by bundle identifier)

*impact: medium · effort: medium · category: privacy-security · ship-now: True · pure-core: True*

Merges ideas 14 and 26 (identical). README markets 'password managers excluded' but it rests solely on source apps voluntarily setting markers; unmarked apps (browser private windows, banking, terminals) are fully captured with no opt-out. Pure SourceAppFilter.shouldCapture(bundleID:excluded:) with wildcard rules; monitor reads frontmostApplication. Editable list UI is real AppKit work.

### 16. Filter search by content kind (kind:image / type chips)

*impact: medium · effort: medium · category: competitor-parity · ship-now: True · pure-core: True*

Idea 15. Every item carries kindLabel that search never uses. Pure SearchQuery parser splits a leading kind: operator from free text; testable parse+filter matrix. Composes cleanly with the SearchRanker (rank 4); best shipped together with it.

### 17. Edit an item's content in place (not just its trigger)

*impact: medium · effort: medium · category: power-user-ux · ship-now: False · pure-core: True*

Idea 6. ⌘E edits only the trigger; content is immutable (ClipboardItem.swift:9). Fix-a-typo/trim-URL/redact flows require recreating+re-pinning. Core updateText(id:newText:) recomputing hash+preview while preserving id/pin/trigger is pure and testable; the editor sheet is medium AppKit work needing GUI verification.

### 18. Full-content preview / peek for items truncated at 240 chars

*impact: high · effort: medium · category: power-user-ux · ship-now: False · pure-core: True*

Idea 2. Preview is hard-capped at 240 (ClipboardItem.swift:143) and the tooltip uses the same capped string (PickerWindow.swift:636), so long clips are never fully viewable anywhere. Core fullText accessor + PreviewFormatter is testable, but the peek surface (popover/footer) needs GUI design+verification.

### 19. Auto-clear / auto-pause on screen lock or sleep

*impact: medium · effort: medium · category: privacy-security · ship-now: True · pure-core: True*

Idea 25. No lock/sleep observers exist; history.json sits plaintext exactly during the walk-away threat window. Pure LockEventPolicy(event,config)->action is testable; AppKit observes com.apple.screenIsLocked + NSWorkspace sleep. Solid but lower daily-driver value than the top items.

### 20. Split image blobs into content-addressed sidecar files

*impact: high · effort: large · category: performance-resource · ship-now: False · pure-core: True*

Idea 29. Inline PNGs force load() to decode the whole 9.4MB file at launch and every save to serialize all bytes. contentHash is already sha256(png), an ideal blob key. Big win but LARGE (BlobStore + GC + migration); the image-cap (rank 8) and debounce (rank 7) capture most of the gain at a fraction of the effort.

### 21. Extract PickerWindow.handleKey into a pure PickerKeyRouting enum + shared KeyCode table

*impact: medium · effort: medium · category: architecture-maintainability · ship-now: True · pure-core: True*

Idea 20 (the routing variant). handleKey (PickerWindow.swift:342-410) is a 69-line god-method with magic keyCodes duplicated in 3 files and a provably-dead ⌘-backspace branch (verified: chars is 'backspace' can never equal the delete control char). Extract PickerAction routing to Core, delete the dead branch, unify KeyCode. Good hygiene but no direct user-facing value.

### 22. Clipboard content transforms (trim / case / collapse newlines) on paste

*impact: medium · effort: medium · category: competitor-parity · ship-now: True · pure-core: True*

Idea 17. Pure TextTransform enum with apply(_:to:) composes with plain-paste and multi-paste. Testable core, but it's a nice-to-have that layers best AFTER plain-text paste (rank 1) lands the paste-flavor seam.

### 23. Restrict history.json to owner-only perms (0600/0700)

*impact: medium · effort: small · category: privacy-security · ship-now: True · pure-core: True*

Idea 27(perms). The single most sensitive file isn't locked to owner-only on disk. Tiny high-certainty hardening: setAttributes posixPermissions after create/write; assert the mode constants in a Core DataFileProtection helper. Low reach on its own; fold into the reliability bundle.

### 24. Adaptive poll interval to cut idle wakeups

*impact: medium · effort: small · category: performance-resource · ship-now: True · pure-core: True*

Idea 31. Fixed 300ms timer fires ~3.3x/s forever (ClipboardMonitor.swift:34). Pure PollSchedule backoff curve keeps 300ms during active use, steps out when idle, snaps back on change. Testable, small, but marginal on a plugged-in Mac mini; battery benefit is the main draw.

### 25. Fix/verify makePreview grapheme truncation + reconcile the newline-collapse doc/behavior mismatch

*impact: medium · effort: small · category: testing-quality-gaps · ship-now: True · pure-core: True*

Idea 40, verified: the doc-comment (ClipboardItem.swift:136-138) promises internal-newline collapse but makePreview does NOT collapse; only test is ASCII-only. Reconcile doc vs code, add emoji/combining-mark + newline tests. Small correctness+honesty fix.

### 26. MarkList↔MultiPasteComposer integration test (paste order == badge order after prune/toggleAll)

*impact: medium · effort: small · category: testing-quality-gaps · ship-now: True · pure-core: True*

Idea 41. Both are unit-tested in isolation but the load-bearing end-to-end invariant (composer order == badge order, surviving eviction) is untested; the only join point is untested PickerWindow. Add a Core integration test + a shared orderedItems helper. Pure, small, high-leverage safety.

### 27. Serialization/thread-safety honesty: remove or actually use the dead queue + lock the single-thread contract

*impact: medium · effort: small · category: testing-quality-gaps · ship-now: True · pure-core: True*

Merges ideas 12(partial) and 38. HistoryStore.queue (line 21) is never used; all mutation is main-only-by-accident. Either delete+document+test the single-thread contract, or wrap reads/writes and add a concurrent-insert stress test. Correctness-and-honesty gap. Overlaps rank 7's queue use.

### 28. Cross-process file lock (flock) around load/save during single-instance handoff

*impact: low · effort: medium · category: reliability-correctness · ship-now: False · pure-core: True*

Idea 12(lock variant). SingleInstance SIGTERMs the sibling but both point at the same file with no advisory lock, a last-writer-wins clobber window. Real but narrow race; the flock helper is Core-testable for acquire/release though the handoff itself isn't unit-testable. Lower priority than the deterministic data-loss fixes above.

### 29. Centralize dynamic picker/menu strings into a Core HintText seam (pluralization now, localization later)

*impact: low · effort: medium · category: accessibility-i18n · ship-now: True · pure-core: True*

Idea 35. Hint/status strings are inline English with naive plural interpolation (PickerWindow.swift:317-319). Extract HintText.marks(count:) etc. to Core to make pluralization testable and leave one localization seam. Low user-visible value; do it opportunistically when touching the picker.

### 30. Non-color signal for marks/pin (increase-contrast aware ContrastPolicy)

*impact: medium · effort: medium · category: accessibility-i18n · ship-now: False · pure-core: True*

Idea 34. Mark order + pin confirmation are color-only; no accessibilityDisplayShouldIncreaseContrast check anywhere. Tiny pure ContrastPolicy.badgeStyle; the real value is the a11y-label work (rank 12). Needs GUI verification for the visual affordance.

### 31. Extract ordinal(_:) into a tested Core Ordinal utility

*impact: low · effort: small · category: accessibility-i18n · ship-now: True · pure-core: True*

Idea 34(ordinal). Hand-rolled ordinal buried in ItemCellView (PickerWindow.swift:739), untested, 11/12/13 off-by-one risk. Trivially moved to Core with a mutation-checkable test; folds into the accessibility-label formatter (rank 12) which needs the ordinal anyway.

### 32. HistoryStore round-trip smoke script (real on-disk load/evict/legacy/corruption)

*impact: medium · effort: small · category: testing-quality-gaps · ship-now: True · pure-core: False*

Idea 42. Persistence, the highest-stakes path, has only in-process tests; scripts/ already has a screenshot-smoke-test precedent. Add scripts/history-store-smoke-test.swift exercising the real file boundary (legacy no-trigger decode, garbage->empty). Good complement to the corrupt-wipe fix (rank 3) but not a code fix itself.

### 33. Reduce reloadData churn: row-scoped reloads for mark toggles + cache sortedForDisplay

*impact: medium · effort: medium · category: performance-resource · ship-now: False · pure-core: True*

Merges ideas 21 and 30. reload() does a full O(n) tableView.reloadData on every keystroke/mutation/mark toggle, rebuilding heavy cells. The sortedForDisplay caching half is pure+testable; the row-scoped reload is AppKit needing an eyeball. Perceived-responsiveness win, partly overlapping the search caching in idea 30.

