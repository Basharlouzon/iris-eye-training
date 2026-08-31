import SwiftUI
import Combine

struct AlertItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var title: String
    var message: String
    var isRead = false
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var alerts: [AlertItem] = []
    @Published var nextBreak: Date?
    @Published var restSecondsLeft: Int?
    @Published var breaksToday = 0
    @Published var exercisesToday = 0
    @Published var flashMessage: String?

    let scheduler = BreakScheduler()
    let weather = WeatherService()
    let music = MusicService()
    let exercises = ExerciseSession()

    var unreadAlerts: [AlertItem] { alerts.filter { !$0.isRead } }

    var restDuration: Int {
        let id = defaults.string(forKey: SettingsKeys.routinePreset)
        return RoutinePreset.resolve(id: id).restSeconds
    }

    private var restTimer: Timer?
    private var flashTimer: Timer?
    private let defaults = UserDefaults.standard

    private init() {
        loadAlerts()
        loadStats()
        scheduler.attach(self)
        let minutes = defaults.object(forKey: SettingsKeys.breakInterval) == nil
            ? Double(RoutinePreset.balanced.focusMinutes)
            : defaults.double(forKey: SettingsKeys.breakInterval)
        scheduler.rescheduleFromNow(minutes: minutes)
        weather.refreshIfNeeded()
    }

    // MARK: - Alerts

    func addAlert(title: String, message: String) {
        let alert = AlertItem(date: Date(), title: title, message: message)
        alerts.insert(alert, at: 0)
        pruneAlerts()
        saveAlerts()
        let soundsOn = defaults.object(forKey: SettingsKeys.sounds) == nil || defaults.bool(forKey: SettingsKeys.sounds)
        if soundsOn { NSSound(named: "Pop")?.play() }
    }

    func addBreakAlert() {
        addAlert(title: "Time for an eye break",
                 message: "Look farther away for \(restDuration) seconds.")
        if focusBreaksEnabled {
            // The full-screen break IS the notification.
            startRest()
        } else {
            let auto = defaults.object(forKey: SettingsKeys.autoExpand) == nil || defaults.bool(forKey: SettingsKeys.autoExpand)
            if auto { NotchPanelController.shared.expandPinned() }
        }
    }

    func markAlertDone(_ id: UUID) {
        if let i = alerts.firstIndex(where: { $0.id == id }) {
            alerts[i].isRead = true
            saveAlerts()
        }
    }

    func snoozeAlert(_ id: UUID, minutes: Double = 10) {
        markAlertDone(id)
        scheduler.rescheduleFromNow(minutes: minutes)
    }

    func markAllBreakAlertsDone() {
        var changed = false
        for i in alerts.indices where !alerts[i].isRead {
            alerts[i].isRead = true
            changed = true
        }
        if changed { saveAlerts() }
    }

    private func pruneAlerts() {
        alerts = Array(alerts.prefix(30))
    }

    private func saveAlerts() {
        if let data = try? JSONEncoder().encode(alerts) {
            defaults.set(data, forKey: "alerts.data")
        }
    }

    private func loadAlerts() {
        if let data = defaults.data(forKey: "alerts.data"),
           let stored = try? JSONDecoder().decode([AlertItem].self, from: data) {
            alerts = stored
        }
    }

    // MARK: - Rest (20-20-20)

    var focusBreaksEnabled: Bool {
        defaults.object(forKey: SettingsKeys.focusBreaks) == nil || defaults.bool(forKey: SettingsKeys.focusBreaks)
    }

    func startRest() {
        guard restTimer == nil else { return }
        restSecondsLeft = restDuration
        if focusBreaksEnabled {
            TheaterController.shared.presentRest()
        }
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                guard let left = self.restSecondsLeft else { timer.invalidate(); return }
                if left <= 1 {
                    timer.invalidate()
                    self.restTimer = nil
                    self.restSecondsLeft = nil
                    self.breaksToday += 1
                    self.saveStats()
                    self.markAllBreakAlertsDone()
                    self.showFlash("Break complete ✓")
                    let minutes = self.defaults.object(forKey: SettingsKeys.breakInterval) == nil
                        ? Double(RoutinePreset.balanced.focusMinutes)
                        : self.defaults.double(forKey: SettingsKeys.breakInterval)
                    self.scheduler.rescheduleFromNow(minutes: minutes)
                } else {
                    self.restSecondsLeft = left - 1
                }
            }
        }
        t.tolerance = 0.2
        restTimer = t
    }

    func startRestNow() {
        startRest()
    }

    /// Abandons the running rest without counting it.
    func cancelRest() {
        restTimer?.invalidate()
        restTimer = nil
        restSecondsLeft = nil
    }

    var isResting: Bool { restSecondsLeft != nil }

    // MARK: - Stats

    func incrementExercises() {
        exercisesToday += 1
        saveStats()
        showFlash("Exercise complete ✓")
    }

    private func loadStats() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let key = f.string(from: Date())
        if defaults.string(forKey: "stats.day") == key {
            breaksToday = defaults.integer(forKey: "stats.breaks")
            exercisesToday = defaults.integer(forKey: "stats.exercises")
        } else {
            breaksToday = 0
            exercisesToday = 0
            defaults.set(key, forKey: "stats.day")
        }
    }

    private func saveStats() {
        defaults.set(breaksToday, forKey: "stats.breaks")
        defaults.set(exercisesToday, forKey: "stats.exercises")
    }

    // MARK: - Flash

    func showFlash(_ message: String) {
        flashMessage = message
        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.flashMessage = nil }
        }
    }

    func breakIntervalChanged(to minutes: Double) {
        scheduler.rescheduleFromNow(minutes: minutes)
    }
}
