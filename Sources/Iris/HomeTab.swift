import SwiftUI

struct HomeTab: View {
    @ObservedObject var state: AppState
    @ObservedObject private var weather: WeatherService
    @ObservedObject private var music: MusicService
    @AppStorage(SettingsKeys.musicSupport) private var musicSupport = true

    init(state: AppState) {
        self.state = state
        weather = state.weather
        music = state.music
    }

    var body: some View {
        let layout = TodayLayoutMetrics.approved

        VStack(spacing: CGFloat(layout.spacing)) {
            alertsSection

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("The next useful action is ready.")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
                IrisStatusChip(
                    label: progress.completedActions == 0 ? "Fresh start" : "\(progress.completedActions) actions",
                    tone: .restorative
                )
            }
            .frame(minHeight: CGFloat(layout.summaryHeight))

            coachCard
                .frame(minHeight: CGFloat(layout.coachHeight))

            HStack(spacing: 12) {
                IrisMetricTile(
                    label: "Focus blocks",
                    value: "\(today.completedFocusBlocks)",
                    trend: focusSummary,
                    tone: .daily
                )
                IrisMetricTile(
                    label: "Distance breaks",
                    value: "\(state.breaksToday)",
                    trend: today.distanceBreakSummary,
                    tone: .restorative
                )
            }
            .frame(minHeight: CGFloat(layout.metricsHeight))

            HStack(spacing: 12) {
                contextCard(
                    eyebrow: weatherLabel,
                    title: temperature,
                    detail: weatherDetail,
                    tone: Theme.restorative
                ) {
                    Task { await weather.refresh() }
                }

                contextCard(
                    eyebrow: "MOON",
                    title: MoonPhase.info().phaseName,
                    detail: "\(Int(MoonPhase.info().illumination * 100))% illuminated",
                    tone: Theme.progress
                ) {
                    // Phase is computed locally — nothing to refresh.
                }
            }
            .frame(minHeight: CGFloat(layout.contextHeight))

            musicBar
        }
    }

    /// Unread break alert — the gradient "Alerts" card from the notch concept.
    @ViewBuilder
    private var alertsSection: some View {
        if let alert = state.unreadAlerts.first {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("BREAK ALERT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.2)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(alert.date, style: .time)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Text(alert.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(alert.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 8) {
                    IrisActionButton(title: "Rest \(state.restDuration) sec", style: .quiet) {
                        state.markAllBreakAlertsDone()
                        state.startRest()
                    }
                    IrisActionButton(title: "Later", style: .restorative) {
                        state.snoozeAlert(alert.id, minutes: 10)
                    }
                    Spacer()
                    if state.unreadAlerts.count > 1 {
                        Text("+\(state.unreadAlerts.count - 1) older")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Theme.gradientTop, Theme.gradientBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    /// Music transport (reference 2) — shown only while a track is playing/app is connected.
    @ViewBuilder
    private var musicBar: some View {
        if musicSupport, music.trackName != nil {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.gradientTop, Theme.gradientBottom],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(music.trackName ?? "")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(music.artistName ?? "")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                transportButton("backward.fill", 28) { music.previousTrack() }
                transportButton(music.isPlaying ? "pause.fill" : "play.fill", 36,
                                iconColor: .black, background: .white) { music.togglePlayPause() }
                transportButton("forward.fill", 28) { music.nextTrack() }
            }
            .padding(10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func transportButton(_ icon: String,
                                 _ diameter: CGFloat,
                                 iconColor: Color = Theme.text,
                                 background: Color = Theme.surfaceStrong,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: diameter * 0.36, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: diameter, height: diameter)
                .background(background, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var progress: ProgressSnapshot {
        ProgressSnapshot(breaks: state.breaksToday, exercises: state.exercisesToday)
    }

    private var today: TodaySnapshot {
        TodaySnapshot(
            breaks: state.breaksToday,
            exercises: state.exercisesToday,
            focusMinutesPerBlock: focusInterval
        )
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var focusInterval: Int {
        UserDefaults.standard.object(forKey: SettingsKeys.breakInterval) == nil
            ? RoutinePreset.balanced.focusMinutes
            : Int(UserDefaults.standard.double(forKey: SettingsKeys.breakInterval))
    }

    private var focusSummary: String {
        today.completedFocusBlocks == 0
            ? "No completed blocks"
            : "\(today.focusMinutes) min completed"
    }

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.restorative)
                    .frame(width: 8, height: 8)
                Text(state.isResting ? "BREAK IN PROGRESS" : "BREAK COACH")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(Theme.restorative)
            }

            Text(state.isResting ? "Look farther, soften focus" : "A clean reset window is ready")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)

            Text(
                state.isResting
                    ? "Let the room come into focus. Keep your shoulders relaxed."
                    : "A short distance break now protects the next deep-work block."
            )
            .font(.system(size: 11))
            .foregroundStyle(Theme.tertiary)
            .fixedSize(horizontal: false, vertical: true)

            if let seconds = state.restSecondsLeft {
                HStack(spacing: 10) {
                    RestRing(fraction: Double(seconds) / Double(max(1, state.restDuration)))
                        .frame(width: 30, height: 30)
                    Text("\(PillView.format(TimeInterval(seconds))) remaining")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.restorative)
                }
            } else {
                IrisActionButton(
                    title: "Begin \(state.restDuration) sec",
                    style: .restorative,
                    action: state.startRest
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var temperature: String {
        guard let celsius = weather.tempC else { return "—" }
        let useFahrenheit = UserDefaults.standard.bool(forKey: SettingsKeys.useFahrenheit)
        let value = useFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }

    private var weatherLabel: String {
        WeatherService.describe(weather.weatherCode).label.uppercased()
    }

    private var weatherDetail: String {
        "\(weather.city) • tap to refresh"
    }

    private func contextCard(
        eyebrow: String,
        title: String,
        detail: String,
        tone: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(tone)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
