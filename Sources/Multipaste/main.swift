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

// Hidden IPC: `Multipaste --pin-current` tells the ALREADY-RUNNING
// Multipaste to pin whatever is currently on the clipboard, then exits
// WITHOUT starting a second instance. Must run before Diagnostics /
// SingleInstance (exactly like --paste-smoke) so it has no side effects on
// the live daemon. The running app owns history.json in memory and rewrites
// it on every copy, so routing through a DistributedNotification lets the
// owner do the pin through its real store (dedup + persist + notify).
if CommandLine.arguments.contains("--pin-current") {
    DistributedNotificationCenter.default().postNotificationName(
        MultipasteIPC.pinCurrent, object: nil, userInfo: nil, deliverImmediately: true)
    exit(0)
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
