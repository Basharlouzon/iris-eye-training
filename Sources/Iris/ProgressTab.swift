import SwiftUI

struct ProgressTab: View {
    @ObservedObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let snapshot = ProgressSnapshot(
            breaks: state.breaksToday,
            exercises: state.exercisesToday
        )
        let week = state.lastSevenDays()
        let weekActions = week.reduce(0) { $0 + $1.breaks + $1.exercises }
        let activeDays = week.filter { $0.breaks + $0.exercises > 0 }.count

        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today’s progress")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("Completed activity only")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
                IrisStatusChip(label: "Today", tone: .progress)
            }

            HStack(spacing: 12) {
                IrisMetricTile(
                    label: "This week",
                    value: "\(weekActions)",
                    trend: "\(activeDays) of 7 days active",
                    tone: .progress
                )
                IrisMetricTile(
                    label: "Completed today",
                    value: "\(snapshot.completedActions)",
                    trend: snapshot.activitySummary,
                    tone: .restorative
                )
            }

            IrisSurfaceCard(
                eyebrow: "Today’s insight",
                title: snapshot.completedActions == 0 ? "Your first signal starts here" : "Today’s rhythm is taking shape",
                detail: progressDetail(snapshot),
                tone: .progress
            )

            weeklyRhythm(week)
        }
    }

    /// Real bars from the persisted daily log. Falls back to a placeholder
    /// until the first week of activity exists.
    @ViewBuilder
    private func weeklyRhythm(_ week: [(label: String, breaks: Int, exercises: Int, isToday: Bool)]) -> some View {
        let hasHistory = week.contains { $0.breaks + $0.exercises > 0 }
        let maxActivity = max(1, week.map { $0.breaks + $0.exercises }.max() ?? 1)

        VStack(alignment: .leading, spacing: 10) {
            Text("SEVEN-DAY RHYTHM")
                .font(.system(size: 9, weight: .medium))
                .tracking(0.2)
                .foregroundStyle(Theme.tertiary)

            if hasHistory {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                        let activity = day.breaks + day.exercises
                        let height: CGFloat = activity == 0 ? 6 : 18 + CGFloat(activity) / CGFloat(maxActivity) * 52
                        VStack(spacing: 6) {
                            Text("\(activity)")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(activity > 0 ? Theme.text : Theme.tertiary)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(day.isToday ? Theme.progress : Theme.surfaceStrong)
                                .frame(width: 26, height: height)
                            Text(day.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(day.isToday ? Theme.progress : Theme.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8),
                           value: week.map { $0.breaks + $0.exercises })
            } else {
                Text("Iris will show a real weekly pattern after seven days of completed activity.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func progressDetail(_ snapshot: ProgressSnapshot) -> String {
        if snapshot.completedActions == 0 {
            return "Complete a distance break or guided exercise. Iris records only actions you actually finish."
        }
        return "\(snapshot.activitySummary) completed today. Keep the rhythm comfortable rather than perfect."
    }
}
