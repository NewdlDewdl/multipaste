// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Names for the one-shot-CLI → running-app IPC channel.
///
/// A short-lived `Multipaste --<flag>` process cannot safely mutate the
/// running daemon's `history.json` (the daemon owns it in memory and
/// rewrites it on every clipboard change, so an outside edit is clobbered).
/// Instead the CLI posts a `DistributedNotification` and the running
/// instance performs the action through its real `HistoryStore`.
///
/// Defined in ONE place so the poster (`main.swift`) and the observer
/// (`AppDelegate`) can never drift on the string.
enum MultipasteIPC {
    /// Posted by `Multipaste --pin-current`; observed by the running
    /// AppDelegate, which pins whatever is on the clipboard right now.
    static let pinCurrent = Notification.Name("com.rohin.multipaste.pinCurrent")
}
