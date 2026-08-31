import SwiftUI

struct ProgressTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        let snapshot = ProgressSnapshot(
            breaks: state.breaksToday,
            exercises: state.exercisesToday
        )

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
                    label: "Comfort momentum",
                    value: "\(snapshot.comfortScore)",
                    trend: "From completed activity",
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

            VStack(alignment: .leading, spacing: 10) {
                Text("SEVEN-DAY RHYTHM")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(Theme.tertiary)

                Text("Iris will show a real weekly pattern after seven days of completed activity.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(index == 6 ? Theme.progress : Theme.surfaceStrong)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if index == 6 {
                                        Text("\(snapshot.completedActions)")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .foregroundStyle(Theme.panel)
                                            .monospacedDigit()
                                    }
                                }
                            Text(["M", "T", "W", "T", "F", "S", "NOW"][index])
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(index == 6 ? Theme.progress : Theme.tertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func progressDetail(_ snapshot: ProgressSnapshot) -> String {
        if snapshot.completedActions == 0 {
            return "Complete a distance break or guided exercise. Iris records only actions you actually finish."
        }
        return "\(snapshot.activitySummary) completed today. Keep the rhythm comfortable rather than perfect."
    }
}
