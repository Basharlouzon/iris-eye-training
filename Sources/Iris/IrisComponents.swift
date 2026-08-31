import SwiftUI

struct IrisActionButton: View {
    enum Style {
        case accent
        case restorative
        case quiet
    }

    let title: String
    var style: Style = .accent
    let action: () -> Void

    private var background: Color {
        switch style {
        case .accent: Theme.accent
        case .restorative: Theme.restorative
        case .quiet: Theme.surfaceStrong
        }
    }

    private var foreground: Color {
        style == .quiet ? Theme.text : Theme.onAccent
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .background(background, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 40)
        .contentShape(Rectangle())
    }
}

struct IrisStatusChip: View {
    enum Tone {
        case neutral
        case accent
        case restorative
        case progress
        case info
    }

    let label: String
    var tone: Tone = .neutral

    private var color: Color {
        switch tone {
        case .neutral: Theme.secondary
        case .accent: Theme.accent
        case .restorative: Theme.restorative
        case .progress: Theme.progress
        case .info: Color(red: 0.380, green: 0.710, blue: 1.000)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(0.2)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.surfaceElevated, in: Capsule())
    }
}

struct IrisSurfaceCard: View {
    enum Tone {
        case neutral
        case accent
        case restorative
        case progress
    }

    let eyebrow: String
    let title: String
    let detail: String
    var tone: Tone = .neutral

    private var color: Color {
        switch tone {
        case .neutral: Theme.tertiary
        case .accent: Theme.accent
        case .restorative: Theme.restorative
        case .progress: Theme.progress
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Capsule()
                .fill(color)
                .frame(width: 40, height: 4)
            Text(eyebrow.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(0.2)
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .background(tone == .neutral ? Theme.surface : Theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct IrisMetricTile: View {
    enum Tone {
        case daily
        case restorative
        case progress
    }

    let label: String
    let value: String
    let trend: String
    var tone: Tone = .daily

    private var color: Color {
        switch tone {
        case .daily: Theme.accent
        case .restorative: Theme.restorative
        case .progress: Theme.progress
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(0.2)
                .foregroundStyle(Theme.tertiary)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(trend)
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct IrisExerciseRow: View {
    enum State {
        case available
        case current
        case complete
    }

    let number: Int
    let title: String
    let detail: String
    let state: State
    let action: () -> Void

    private var tone: Color {
        switch state {
        case .available: Theme.tertiary
        case .current: Theme.accent
        case .complete: Theme.restorative
        }
    }

    private var status: String {
        switch state {
        case .available: "Ready"
        case .current: "Now"
        case .complete: "Done"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(String(format: "%02d", number))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.surface)
                    .frame(width: 36, height: 36)
                    .background(tone, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text(detail)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }

                Spacer(minLength: 8)
                IrisStatusChip(
                    label: status,
                    tone: state == .current ? .accent : state == .complete ? .restorative : .neutral
                )
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(state == .current ? Theme.surfaceStrong : state == .complete ? Theme.surfaceElevated : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct IrisPanelHeader: View {
    @Binding var selectedTab: IrisTab
    let settingsAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Iris")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("PRIVATE • ON DEVICE")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(Theme.restorative)
                Button(action: settingsAction) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 32, height: 32)
                        .background(Theme.surface, in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack {
                ForEach(IrisTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(selectedTab == tab ? Theme.accent : Theme.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Theme.surfaceStrong : Theme.surface, in: Capsule())
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
