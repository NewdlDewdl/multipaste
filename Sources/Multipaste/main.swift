// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit

// Hidden self-check: `Multipaste --paste-smoke` runs the REAL Paster.put
// against a private NSPasteboard and exits (wired into `make
// plaintext-smoke-test`, so the shipped executor, not a hand-mirrored
// copy, is what gets verified). Must run before Diagnostics/SingleInstance
// so the check has no side effects and a running Multipaste is untouched.
if CommandLine.arguments.contains("--paste-smoke") {
    exit(PasteSmokeCheck.run())
}

// Log a one-line boot summary BEFORE anything else, so the err log gives
// us visibility into the daemon's view of trust + cdhash + siblings.
Diagnostics.logBoot()

// Kill stale sibling Multipaste processes (LaunchAgent + LoginItem
// duplicates) before installing UI hooks.
SingleInstance.enforce()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
