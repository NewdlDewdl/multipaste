# Contributing to Multipaste

Thanks for your interest in contributing. Multipaste is a sole-maintainer
project (Rohin Agrawal); this document explains how to contribute code,
report bugs, and — most importantly — the **Contributor License
Agreement (CLA)** that makes contributions legally possible under
Multipaste's source-available license.

If you only want to *use* Multipaste, you don't need to read this. The
[README](README.md) and [LICENSE.md](LICENSE.md) cover that.

---

## The license situation in one paragraph

Multipaste 2.0.0+ is licensed under [PolyForm Strict
1.0.0](LICENSE.md) — a **source-available, noncommercial** license,
not OSI open source. Under PolyForm Strict, **you, as a user of the
software, do NOT have the right to modify or distribute it**. That
restriction is intentional: it preserves the licensor's path to a
future commercial product. But it creates a problem for contributors:
opening a pull request technically requires both modifying the
software (creating a derivative work) AND distributing the modified
version (pushing to a fork, asking it be merged). The CLA below is
how we make contributions legal anyway.

---

## Contributor License Agreement (CLA)

**By submitting any contribution to this project — including (but not
limited to) a pull request, patch file, code suggestion, bug fix,
documentation edit, test, build-script change, design proposal, or
issue comment that includes proposed code — you agree to all of the
following.**

You retain the copyright in your contribution. You are NOT assigning
copyright to anyone. What you ARE granting is a broad license to use
your contribution.

### 1. License grant

You grant **Rohin Agrawal** (the "licensor"), and any successor in
interest to the Multipaste project, a perpetual, worldwide, non-
exclusive, no-charge, royalty-free, irrevocable copyright license to:

1. Reproduce, prepare derivative works of, publicly display, publicly
   perform, and distribute your contribution.
2. Sublicense the foregoing rights through multiple tiers of
   sublicensees.
3. Combine your contribution with the existing Multipaste codebase or
   any future version of it.
4. **Relicense your contribution under any license terms — including
   future versions of PolyForm Strict, fully proprietary closed-source
   terms, dual licensing, or any other open-source or source-available
   license — at the licensor's sole discretion, without further notice
   to or consent from you.**

### 2. Patent grant

You grant the licensor a perpetual, worldwide, non-exclusive, no-
charge, royalty-free, irrevocable patent license to make, have made,
use, offer to sell, sell, import, and otherwise transfer your
contribution, where such license applies only to those patent claims
licensable by you that are necessarily infringed by your contribution
alone or by combination of your contribution with the Multipaste
project.

### 3. Reciprocal permission to contribute

In exchange for the rights you grant above, the licensor grants you a
one-time, contribution-scoped license to make the specific changes
contained in your contribution and to convey them to the licensor for
the purpose of evaluation and possible merging into Multipaste. This
license is limited to that contribution; it does not extend PolyForm
Strict's restrictions on your general use of Multipaste.

### 4. Representations

You represent that:

1. You are legally entitled to grant the above licenses — either
   because you own the copyright in your contribution, OR because
   your employer or institution has authorized you to do so.
2. To your knowledge, your contribution does not knowingly infringe
   on any third party's copyright, patent, trademark, or other
   intellectual property right.
3. If your employer has rights to intellectual property that you
   create which includes your contribution, either (a) your employer
   has waived such rights for your contribution, OR (b) your employer
   has executed a separate agreement with the licensor permitting your
   contribution.
4. Your contribution is your original work, OR you have clearly
   identified any third-party material in your contribution and noted
   its source and license.

### 5. No warranty

Your contribution is provided "AS IS", without warranty of any kind.
You are not obligated to provide support, updates, or maintenance for
your contribution.

### 6. Why this matters

The two clauses that may be unexpected are **§1.4 (relicensing
right)** and **§3 (one-time scoped permission)**.

- **§1.4** means that if Multipaste is ever relicensed — including a
  flip to fully proprietary closed-source — your contribution comes
  along under the new license, without anyone asking you. This is
  intentional. The licensor needs the freedom to evolve the licensing
  model without coordinating with every past contributor (a problem
  that has historically blocked many open-source projects from
  relicensing). If you are not comfortable with this, please do not
  contribute.

- **§3** is what makes your PR legal in the first place. Without it,
  the act of forking + modifying + opening a PR would technically
  violate PolyForm Strict's prohibition on derivative works. §3 is a
  narrow exception granted to you, for this contribution only, in
  exchange for the broad grant in §1.

If these terms are not acceptable to you, do not submit a contribution
to this project. There is no way to contribute "without the CLA"; the
CLA is what authorizes contribution at all.

---

## What kinds of contributions are welcome

**Welcome:**

- Bug fixes with reproduction steps and a test where feasible.
- Performance improvements with before/after measurements.
- Documentation improvements (README clarity, typo fixes, additional
  examples).
- Test coverage for existing untested code paths.
- macOS-version compatibility fixes (especially 13–15 Ventura/Sonoma/
  Sequoia, and 26 Tahoe).
- Accessibility improvements.
- Small feature proposals — open an issue first to discuss before
  writing code.

**Not welcome:**

- Wholesale UI redesigns without prior discussion.
- New dependencies (Multipaste is intentionally dependency-free; the
  Package.swift has zero `.package(url:)` entries).
- Telemetry, analytics, or any code that makes network calls beyond
  the existing once-a-day GitHub Releases update check.
- License changes (only the licensor relicenses; see §1.4 above).
- Code that requires Xcode-only build steps (Multipaste builds with
  `swift build` and Command Line Tools alone).
- Refactors that don't have a concrete bug or measurement motivating
  them.

---

## How to contribute code

### 1. Fork and clone

```sh
gh repo fork NewdlDewdl/multipaste --clone
cd multipaste
```

### 2. Set up the toolchain

You need only Xcode Command Line Tools:

```sh
xcode-select --install
```

No full Xcode required. Multipaste's test harness runs as a plain
`swift run` target.

### 3. Make your change

- Match the existing code style (see existing files for tab/space,
  brace placement, naming).
- Pure logic lives in `Sources/MultipasteCore/` (no AppKit imports).
- AppKit-bound code lives in `Sources/Multipaste/`.
- New tests go in `Tests/MultipasteCoreTests/` and follow the
  pattern in `SemanticVersionTests.swift` or similar:
  - One `enum` per test file.
  - `static func registerAll()` registers each test by name.
  - `static func testCase() throws { … }` for each case.
  - Use `try expect(cond, "message")` and `try expectEqual(a, b)`.

### 4. Run the test suite

```sh
make test
```

All tests must pass. The harness exits non-zero on any failure, so
this also gates CI (when CI is added).

### 5. Commit

Follow the existing commit style. Look at `git log --oneline -20`
for examples. Format:

```
<short imperative title under 70 chars>

<one or two paragraphs of body explaining what changed and why>

<file-by-file or bullet-by-bullet detail if the change is non-trivial>
```

Do NOT use Conventional Commits prefixes (`feat:`, `fix:`, etc.) —
the existing project uses descriptive imperative titles instead.

### 6. Open the PR

```sh
gh pr create --fill
```

Fill out the PR template (auto-loaded from
`.github/PULL_REQUEST_TEMPLATE.md`). It will ask you to confirm CLA
acceptance — checking the boxes constitutes agreement.

### 7. Review

The licensor (Rohin) reviews PRs as time permits. Expect:

- A clarifying question or two.
- Possibly a suggestion to restructure or simplify.
- Either a merge, a request for changes, or a polite decline (with
  reason).

There is no SLA. This is a solo project; reviews happen when they
happen. Be patient.

---

## How to report a bug

Use the bug-report issue template at
`.github/ISSUE_TEMPLATE/bug_report.md`. The key fields:

- macOS version (e.g., 14.5 Sonoma, 26.0 Tahoe).
- Multipaste version (menu bar → About).
- Install method (DMG, Homebrew, source).
- Apple Silicon or Intel.
- Steps to reproduce.
- Tail of `~/Library/Logs/Multipaste/multipaste.log`.

For **security vulnerabilities**, do NOT open a public issue. Email
<rohin.agrawal@gmail.com> with the details and "Multipaste security"
in the subject.

---

## Commercial licensing

If you want to use Multipaste commercially, embed it in a product,
distribute a modified version, or any other use not permitted by
PolyForm Strict, contact <rohin.agrawal@gmail.com> with "Multipaste
commercial license" in the subject. Terms negotiable.

---

## Code of conduct

Be civil. Disagree about the code, not the person. The licensor
reserves the right to close any issue or PR, or block any account, at
sole discretion. There is no formal CoC document and no enforcement
process beyond the licensor's judgment.
