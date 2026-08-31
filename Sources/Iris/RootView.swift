import SwiftUI

struct RootView: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: PanelModel

    var body: some View {
        ZStack(alignment: .top) {
            panelShape
                .contentShape(Rectangle())
                .onTapGesture {
                    if model.isExpanded {
                        // A click inside the open panel keeps it open (pin),
                        // so a hover-opened panel isn't lost when the mouse leaves.
                        model.isPinned = true
                    } else {
                        NotchPanelController.shared.toggle()
                    }
                }

            if model.isExpanded {
                IrisDashboardView(
                    state: state,
                    model: model,
                    topInset: DashboardPlacement.notch(
                        topInset: model.hasNotch ? model.notchHeight : 0
                    ).topInset
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            } else {
                PillView(
                    state: state,
                    model: model,
                    notchHeight: model.hasNotch ? model.notchHeight : 0,
                    hasNotch: model.hasNotch
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: model.isExpanded)
        .ignoresSafeArea()
    }

    /// Closed pill: pure black to merge with the hardware notch, no border
    /// (a hairline over black reads as glass), tight radii and a whisper of
    /// shadow under the lip. Expanded keeps the softer panel treatment.
    @ViewBuilder
    private var panelShape: some View {
        if model.isExpanded {
            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                topTrailingRadius: 6,
                style: .continuous
            )
            .fill(Theme.panel)
            .overlay {
                UnevenRoundedRectangle(
                    topLeadingRadius: 6,
                    bottomLeadingRadius: 28,
                    bottomTrailingRadius: 28,
                    topTrailingRadius: 6,
                    style: .continuous
                )
                .strokeBorder(Theme.stroke, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.55), radius: 40, y: 18)
        } else {
            let radius: CGFloat = model.hasNotch ? 10 : 14
            UnevenRoundedRectangle(
                topLeadingRadius: model.hasNotch ? 2 : radius,
                bottomLeadingRadius: radius,
                bottomTrailingRadius: radius,
                topTrailingRadius: model.hasNotch ? 2 : radius,
                style: .continuous
            )
            .fill(Color.black)
            .shadow(color: .black.opacity(0.20), radius: 4, y: 2)
        }
    }
}

struct PillView: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: PanelModel
    let notchHeight: CGFloat
    let hasNotch: Bool

    @State private var pulsing = false

    private var hoverPeek: CGFloat {
        model.isHovering && !model.isExpanded ? 1.04 : 1.0
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let presentation = CompactPresentation.resolve(
                restSecondsLeft: state.restSecondsLeft,
                unreadBreaks: state.unreadAlerts.count,
                nextBreakInterval: state.nextBreak?.timeIntervalSince(context.date),
                completedMessage: state.flashMessage
            )
            let layout = CompactLayoutStyle.resolve(hasNotch: hasNotch)
            let isDue: Bool = {
                if case .breakDue = presentation { return true }
                return false
            }()

            VStack(spacing: 0) {
                Color.clear.frame(height: notchHeight)
                compactContent(presentation, layout: layout)
                    .frame(maxHeight: .infinity)
                    .onChange(of: isDue) { pulsing = $0 }
            }
            .onAppear { pulsing = isDue }
            .scaleEffect(hoverPeek, anchor: .bottom)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hoverPeek)
        }
    }

    @ViewBuilder
    private func compactContent(
        _ presentation: CompactPresentation,
        layout: CompactLayoutStyle
    ) -> some View {
        if layout.showsDetailLine {
            HStack(spacing: 10) {
                signal(for: presentation, layout: layout)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(for: presentation))
                        .font(.system(size: CGFloat(layout.titleFontSize), weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(detail(for: presentation))
                        .font(.system(size: CGFloat(layout.detailFontSize), weight: .medium))
                        .foregroundStyle(Theme.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                unreadBadge
            }
            .padding(.horizontal, 12)
        } else {
            HStack(spacing: 7) {
                signal(for: presentation, layout: layout)
                Text(title(for: presentation))
                    .font(.system(size: CGFloat(layout.titleFontSize), weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(compactDetail(for: presentation))
                    .font(.system(size: CGFloat(layout.detailFontSize), weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                unreadBadge
            }
            .padding(.horizontal, 9)
        }
    }

    /// Orange count badge for unread alerts (the "Alerts 3" cue from the reference).
    @ViewBuilder
    private var unreadBadge: some View {
        let count = state.unreadAlerts.count
        if count > 0 {
            HStack(spacing: 3) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 4, height: 4)
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .monospacedDigit()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.accent.opacity(0.16)))
        }
    }

    private func signal(
        for presentation: CompactPresentation,
        layout: CompactLayoutStyle
    ) -> some View {
        let config: (String, Color) = switch presentation {
        case .resting: ("I", Theme.surfaceElevated)
        case .breakDue: ("↗", Theme.restorative)
        case .active: ("●", Theme.accent)
        case .complete: ("✓", Theme.restorative)
        case .focus: ("●", Theme.accent)
        }

        let isDue: Bool = {
            if case .breakDue = presentation { return true }
            return false
        }()

        let circle = Text(config.0)
            .font(.system(size: hasNotch ? 8 : 11, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.panel)
            .frame(width: CGFloat(layout.signalDiameter), height: CGFloat(layout.signalDiameter))
            .background(config.1, in: Circle())
            .scaleEffect(pulsing && isDue ? 1.16 : 1.0)
            .animation(
                .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                value: pulsing && isDue
            )

        // Progress ring: fraction toward the next break, or remaining rest.
        let ring = ringSpec(for: presentation).map { spec in
            CountdownRing(fraction: spec.fraction, color: spec.color, diameter: CGFloat(layout.signalDiameter) + 3)
        }

        return ZStack {
            if let ring { ring }
            circle
        }
    }

    private func ringSpec(for presentation: CompactPresentation) -> (fraction: Double, color: Color)? {
        switch presentation {
        case .focus(let secondsLeft):
            let total = max(60, UserDefaults.standard.double(forKey: SettingsKeys.breakInterval) * 60)
            guard total > 0 else { return nil }
            return (min(1, max(0, 1 - Double(secondsLeft) / total)), Theme.accent)
        case .active(let secondsLeft):
            let total = max(1, state.restDuration)
            return (min(1, max(0, Double(secondsLeft) / Double(total))), Theme.restorative)
        case .resting, .breakDue, .complete:
            return nil
        }
    }

    private func title(for presentation: CompactPresentation) -> String {
        switch presentation {
        case .resting: "Iris"
        case .breakDue: "Look away"
        case .active: "Distance reset"
        case .complete: "Nice work"
        case .focus: "Focus block"
        }
    }

    private func detail(for presentation: CompactPresentation) -> String {
        switch presentation {
        case .resting: "Comfort is steady"
        case .breakDue: "60-second reset"
        case let .active(secondsLeft): "\(Self.format(TimeInterval(secondsLeft))) remaining"
        case .complete: "Eyes reset"
        case let .focus(secondsLeft): "\(Self.format(TimeInterval(secondsLeft))) remaining"
        }
    }

    private func compactDetail(for presentation: CompactPresentation) -> String {
        switch presentation {
        case .resting: "Steady"
        case .breakDue: "60 sec"
        case let .active(secondsLeft): Self.format(TimeInterval(secondsLeft))
        case .complete: "Complete"
        case let .focus(secondsLeft): Self.format(TimeInterval(secondsLeft))
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct RestRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceStrong, lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, fraction)))
                .stroke(Theme.restorative, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Slim ring wrapping the pill's signal circle: time toward the next break,
/// or remaining rest seconds.
struct CountdownRing: View {
    let fraction: Double
    let color: Color
    var diameter: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.16), lineWidth: 1.5)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }
}

struct IrisDashboardView: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: PanelModel
    let topInset: CGFloat

    @AppStorage(SettingsKeys.hasOnboarded) private var hasOnboarded = false
    var body: some View {
        Group {
            if hasOnboarded {
                mainPanel
            } else {
                OnboardingView(state: state, topInset: topInset)
            }
        }
        .overlay {
            if model.showSettings {
                SettingsSheet(state: state, model: model, topInset: topInset)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: model.showSettings)
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset + 4)

            IrisPanelHeader(
                selectedTab: $model.selectedTab,
                settingsAction: {
                    model.isPinned = true
                    model.showSettings = true
                }
            )
            .padding(.horizontal, 24)

            ScrollView(showsIndicators: true) {
                VStack(spacing: 10) {
                    Group {
                        switch model.selectedTab {
                        case .today:
                            HomeTab(state: state)
                        case .train:
                            TrainTab(state: state)
                        case .progress:
                            ProgressTab(state: state)
                        }
                    }

                    panelFooter
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
    }

    private var panelFooter: some View {
        Text("Iris 1.0 · rest your eyes, on schedule")
            .foregroundStyle(Theme.tertiary)
            .font(.system(size: 9, weight: .medium))
            .tracking(0.2)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: CGFloat(TodayLayoutMetrics.approved.footerHeight))
    }
}
