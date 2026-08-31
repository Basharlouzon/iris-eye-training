import Foundation

@MainActor
final class BreakScheduler {
    private var timer: Timer?
    private weak var state: AppState?

    func attach(_ state: AppState) {
        self.state = state
    }

    var nextDate: Date? {
        timer?.fireDate
    }

    /// Schedules the next break alert `minutes` from now.
    func rescheduleFromNow(minutes: Double) {
        timer?.invalidate()
        let interval = max(60, minutes * 60)
        state?.nextBreak = Date().addingTimeInterval(interval)
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.fire() }
        }
        t.tolerance = 2
        timer = t
    }

    private func fire() {
        state?.addBreakAlert()
    }
}
