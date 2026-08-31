import ServiceManagement
import SwiftUI

struct SettingsSheet: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: PanelModel
    let topInset: CGFloat

    @AppStorage(SettingsKeys.breakInterval) private var breakInterval: Double = 45
    @AppStorage(SettingsKeys.autoExpand) private var autoExpand = true
    @AppStorage(SettingsKeys.sounds) private var sounds = true
    @AppStorage(SettingsKeys.useFahrenheit) private var useFahrenheit = false
    @AppStorage(SettingsKeys.routinePreset) private var routinePreset = RoutinePreset.balanced.id
    @AppStorage(SettingsKeys.focusBreaks) private var focusBreaks = true
    @AppStorage(SettingsKeys.musicSupport) private var musicSupport = true

    @State private var cityText = UserDefaults.standard.string(forKey: SettingsKeys.city) ?? "New York"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset + 8)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("Shape Iris around your day")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
                IrisStatusChip(label: "Free", tone: .restorative)
                Button {
                    model.showSettings = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 28, height: 28)
                        .background(Theme.surfaceStrong, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    routineCard
                    intelligenceCard
                    contextCard
                    preferencesCard

                    if let launchError {
                        Text(launchError)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("Run onboarding again") {
                        UserDefaults.standard.set(false, forKey: SettingsKeys.hasOnboarded)
                        model.showSettings = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.tertiary)

                    Text("IRIS 1.0 • PRIVATE BY DEFAULT • ALL CORE FEATURES FREE")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(0.2)
                        .foregroundStyle(Theme.tertiary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
        .background(Theme.panel)
    }

    private var routineCard: some View {
        settingsCard(title: "Your rhythm", detail: "Choose a starting point. Adaptive timing can refine it locally.") {
            VStack(spacing: 6) {
                ForEach(RoutinePreset.all) { preset in
                    Button {
                        routinePreset = preset.id
                        breakInterval = Double(preset.focusMinutes)
                        state.breakIntervalChanged(to: breakInterval)
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(routinePreset == preset.id ? Theme.accent : Theme.surfaceStrong)
                                .frame(width: 8, height: 8)
                            Text(preset.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text("\(preset.focusMinutes)m / \(preset.restSeconds)s")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(routinePreset == preset.id ? Theme.accent : Theme.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(routinePreset == preset.id ? Theme.surfaceStrong : Theme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var intelligenceCard: some View {
        settingsCard(title: "Comfort intelligence", detail: "All observations and adjustments stay on this Mac.") {
            VStack(spacing: 10) {
                toggleRow("Full-screen breaks", detail: "Dim the screen when a break is due", isOn: $focusBreaks)
                toggleRow("Auto-open break", detail: "Show Iris when a reset is due", isOn: $autoExpand)
                toggleRow("Gentle sounds", detail: "Play a quiet reminder cue", isOn: $sounds)
            }
        }
    }

    private var contextCard: some View {
        settingsCard(title: "Media", detail: "Optional. Nothing here is required.") {
            VStack(spacing: 10) {
                toggleRow("Music transport", detail: "Show player controls in Today", isOn: $musicSupport)
            }
        }
    }

    private var preferencesCard: some View {
        settingsCard(title: "Mac preferences", detail: "Practical controls for weather and startup.") {
            VStack(spacing: 12) {
                HStack {
                    Text("Weather city")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    TextField("City", text: $cityText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 10)
                        .frame(width: 118, height: 28)
                        .background(Theme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .onSubmit { state.weather.setCity(cityText) }
                }

                HStack {
                    Text("Temperature")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    unitChip("°C", selected: !useFahrenheit) { useFahrenheit = false }
                    unitChip("°F", selected: useFahrenheit) { useFahrenheit = true }
                }

                toggleRow("Launch at login", detail: "Keep Iris ready after restart", isOn: $launchAtLogin) { enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        launchError = nil
                    } catch {
                        launchError = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            }
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(Theme.accent)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toggleRow(
        _ title: String,
        detail: String,
        isOn: Binding<Bool>,
        onChange: ((Bool) -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.tertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Theme.accent)
                .onChange(of: isOn.wrappedValue) { newValue in
                    onChange?(newValue)
                }
        }
    }

    private func unitChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(selected ? Theme.onAccent : Theme.secondary)
                .frame(width: 34, height: 26)
                .background(selected ? Theme.accent : Theme.panel, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
