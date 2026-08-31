import Foundation

enum IrisTab: String, CaseIterable, Identifiable {
    case today
    case train
    case progress

    var id: Self { self }

    var title: String {
        rawValue.capitalized
    }
}

enum CompactPresentation: Equatable {
    case resting
    case breakDue
    case active(secondsLeft: Int)
    case complete
    case focus(secondsLeft: Int)

    static func resolve(
        restSecondsLeft: Int?,
        unreadBreaks: Int,
        nextBreakInterval: TimeInterval?,
        completedMessage: String?
    ) -> Self {
        if let restSecondsLeft {
            return .active(secondsLeft: restSecondsLeft)
        }
        if completedMessage != nil {
            return .complete
        }
        if unreadBreaks > 0 || (nextBreakInterval ?? 1) <= 0 {
            return .breakDue
        }
        if let nextBreakInterval {
            return .focus(secondsLeft: max(0, Int(nextBreakInterval.rounded())))
        }
        return .resting
    }
}

struct RoutinePreset: Identifiable, Equatable {
    let id: String
    let title: String
    let focusMinutes: Int
    let restSeconds: Int

    static let balanced = Self(
        id: "balanced",
        title: "Balanced",
        focusMinutes: 45,
        restSeconds: 60
    )
    static let gentle = Self(
        id: "gentle",
        title: "Gentle",
        focusMinutes: 60,
        restSeconds: 45
    )
    static let classic = Self(
        id: "classic",
        title: "Classic 20–20–20",
        focusMinutes: 20,
        restSeconds: 20
    )
    static let all = [balanced, gentle, classic]

    static func resolve(id: String?) -> Self {
        all.first { $0.id == id } ?? .balanced
    }
}

enum OnboardingStep: Int, CaseIterable {
    case promise
    case language
    case routine
    case privacy

    var next: Self? {
        Self(rawValue: rawValue + 1)
    }
}

struct OnboardingDraft: Equatable {
    var selectedRoutineID: String

    init(defaults: UserDefaults = .standard) {
        selectedRoutineID = defaults.string(forKey: SettingsKeys.routinePreset)
            ?? RoutinePreset.balanced.id
    }

    func commit(to defaults: UserDefaults = .standard) {
        let routine = RoutinePreset.resolve(id: selectedRoutineID)
        defaults.set(routine.id, forKey: SettingsKeys.routinePreset)
        defaults.set(Double(routine.focusMinutes), forKey: SettingsKeys.breakInterval)
        defaults.set(true, forKey: SettingsKeys.hasOnboarded)
    }
}

struct ProgressSnapshot: Equatable {
    let breaks: Int
    let exercises: Int

    var comfortScore: Int {
        min(100, 64 + breaks * 4 + exercises * 3)
    }

    var completedActions: Int { max(0, breaks) + max(0, exercises) }
    var activitySummary: String {
        "\(max(0, breaks)) break\(breaks == 1 ? "" : "s") • \(max(0, exercises)) exercise\(exercises == 1 ? "" : "s")"
    }
}

struct TrainingRoutine: Equatable {
    let stepIDs: [String]
    let stepDurationSeconds: Int

    static let approved = Self(
        stepIDs: ["fig8", "infinity", "zigzag", "diagonals"],
        stepDurationSeconds: 60
    )

    var totalMinutes: Int {
        stepIDs.count * stepDurationSeconds / 60
    }
}

enum IrisFeatureDefaults {
    static let adaptiveTiming = true
    static let calendarContext = false
    static let focusContext = false
    static let musicSupport = true
}

struct CompactLayoutStyle: Equatable {
    let showsDetailLine: Bool
    let signalDiameter: Double
    let titleFontSize: Double
    let detailFontSize: Double
    let requiredHeight: Double

    static func resolve(hasNotch: Bool) -> Self {
        if hasNotch {
            return Self(
                showsDetailLine: false,
                signalDiameter: 18,
                titleFontSize: 11,
                detailFontSize: 10,
                requiredHeight: 22
            )
        }
        return Self(
            showsDetailLine: true,
            signalDiameter: 38,
            titleFontSize: 15,
            detailFontSize: 9,
            requiredHeight: 38
        )
    }
}

struct TodaySnapshot: Equatable {
    let breaks: Int
    let exercises: Int
    let focusMinutesPerBlock: Int

    var completedFocusBlocks: Int { max(0, breaks) }
    var focusMinutes: Int { completedFocusBlocks * max(0, focusMinutesPerBlock) }
    var distanceBreakSummary: String {
        breaks == 0 ? "No resets yet" : "\(breaks) reset\(breaks == 1 ? "" : "s") completed"
    }
}

struct TodayLayoutMetrics: Equatable {
    let summaryHeight: Double
    let coachHeight: Double
    let metricsHeight: Double
    let contextHeight: Double
    let footerHeight: Double
    let spacing: Double

    static let approved = Self(
        summaryHeight: 32,
        coachHeight: 148,
        metricsHeight: 92,
        contextHeight: 64,
        footerHeight: 21,
        spacing: 10
    )

    var totalHeight: Double {
        summaryHeight + coachHeight + metricsHeight + contextHeight + footerHeight + spacing * 4
    }
}

struct IrisLaunchConfiguration: Equatable {
    let previewTab: IrisTab?
    let previewsStatusDashboard: Bool
    let previewsSettings: Bool
    let previewsOnboarding: Bool

    init(arguments: [String]) {
        let prefix = "--iris-preview="
        let value = arguments
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
        previewTab = value.flatMap(IrisTab.init(rawValue:))
        previewsStatusDashboard = arguments.contains("--iris-preview-status-dashboard")
        previewsSettings = arguments.contains("--iris-preview-settings")
        previewsOnboarding = arguments.contains("--iris-preview-onboarding")
    }
}
