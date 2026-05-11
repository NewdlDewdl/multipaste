import AppKit
import ApplicationServices

/// Polls `AXIsProcessTrusted()` every couple of seconds and fires
/// `onChange` whenever the trust state flips. macOS doesn't publish a
/// notification for Accessibility permission changes — polling is the
/// canonical approach (every clipboard manager, snippet expander, and
/// window-manager does this).
///
/// 2-second cadence: snappy enough that users see auto-paste light up
/// within a beat of flipping the toggle, slow enough that the cost is
/// effectively zero (~one syscall every 2s).
final class PermissionMonitor {

    private var timer: Timer?
    private var lastState: Bool

    var onChange: ((Bool) -> Void)?

    init() {
        self.lastState = AXIsProcessTrusted()
    }

    var isTrusted: Bool { lastState }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = AXIsProcessTrusted()
            if now != self.lastState {
                self.lastState = now
                self.onChange?(now)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
