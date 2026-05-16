// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import ApplicationServices

/// Polls `AXIsProcessTrusted()` and fires `onChange` whenever the trust
/// state flips. macOS doesn't publish a notification for Accessibility
/// permission changes — polling is the canonical approach (every
/// clipboard manager, snippet expander, and window-manager does this).
///
/// Two cadences:
///
///  - **Steady state** (`start()`): 1-second poll. Cheap (one syscall
///    per second), responsive enough that the menu-bar icon brightens
///    almost immediately after the user flips the toggle.
///
///  - **Burst** (`burstPoll(...)`): 250 ms poll for up to 60 s, used
///    right after the user clicks "Grant Accessibility…" while they're
///    inside System Settings. Catches the toggle the moment it lands.
///    Falls back to `onBurstTimeout` if no change was detected — this
///    is the hook for surfacing "click Quit & Relaunch" UI when macOS's
///    per-process TCC cache holds the old value.
///
/// **Runloop mode matters.** `Timer.scheduledTimer(…)` adds to
/// `.defaultMode` by default, which pauses while a menu is tracked or
/// an `NSAlert` is modal. We schedule on `RunLoop.main` in `.common`
/// modes so the poller keeps firing even with a menu down or an alert
/// up. Without this, the previous v1.4.0 implementation could miss a
/// grant for as long as the menu/modal stayed open.
final class PermissionMonitor {

    private var timer: Timer?
    private var burstEndDate: Date?
    private(set) var lastState: Bool

    var onChange: ((Bool) -> Void)?
    /// Fires once when a burst-poll period elapses without observing a
    /// flip. Used by the menu controller to surface "Quit & Relaunch"
    /// when macOS isn't propagating the new trust state in-process.
    var onBurstTimeout: (() -> Void)?

    init() {
        self.lastState = AXIsProcessTrusted()
    }

    var isTrusted: Bool { lastState }

    /// Force an immediate state read. Useful right after returning from
    /// System Settings — gives the user instant feedback in addition to
    /// the next scheduled poll.
    @discardableResult
    func refresh() -> Bool {
        let now = AXIsProcessTrusted()
        if now != lastState {
            lastState = now
            onChange?(now)
        }
        return now
    }

    func start() {
        installTimer(interval: 1.0)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        burstEndDate = nil
    }

    /// Run a fast 250 ms poll for up to `duration` seconds. When the
    /// burst window elapses without a state change, `onBurstTimeout` is
    /// called and the monitor returns to steady-state cadence.
    func burstPoll(duration: TimeInterval = 60.0, interval: TimeInterval = 0.25) {
        burstEndDate = Date().addingTimeInterval(duration)
        installTimer(interval: interval)
    }

    private func installTimer(interval: TimeInterval) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = AXIsProcessTrusted()
            if now != self.lastState {
                self.lastState = now
                self.onChange?(now)
                // If we were bursting and the change landed, return to
                // steady cadence — no need to keep hammering.
                if self.burstEndDate != nil {
                    self.burstEndDate = nil
                    self.installTimer(interval: 1.0)
                }
                return
            }
            // Burst timeout check (only when we're in burst mode).
            if let end = self.burstEndDate, Date() >= end {
                self.burstEndDate = nil
                self.installTimer(interval: 1.0)
                self.onBurstTimeout?()
            }
        }
        // CRITICAL: schedule on `.common` modes so the poller keeps
        // firing while menus are tracked and modals are up. Without
        // this, the timer pauses while the user is reading the very
        // alert that told them what to do.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
