import AppKit
import SwiftUI

/// Owns the first-launch window independently from the menu-bar dashboard.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func presentIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: SettingsKeys.hasOnboarded) else { return }
        present()
    }

    func present() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.center()
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Iris"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = NSColor(Theme.panel)
        window.contentView = NSHostingView(rootView: WelcomeOnboardingView(controller: self))
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func cancel() {
        window?.close()
    }

    func finish() {
        window?.close()
        StatusDashboardController.shared.open(tab: .today)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else { return }
        window = nil
    }
}

// MARK: - View

struct WelcomeOnboardingView: View {
    let controller: OnboardingWindowController

    @State private var draft = OnboardingDraft()
    @State private var step: OnboardingStep = .promise

    private var selectedRoutine: RoutinePreset {
        RoutinePreset.resolve(id: draft.selectedRoutineID)
    }

    var body: some View {
        ZStack {
            Theme.panel.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ZStack {
                    stepContent
                        .id(step)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.985)),
                                removal: .opacity
                            )
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                footer
            }
        }
        .frame(width: 560, height: 560)
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.2), value: step)
    }

    private var header: some View {
        ZStack {
            Text("IRIS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(Theme.secondary)

            HStack {
                Button(action: goBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.secondary)
                    .frame(minWidth: 64, minHeight: 40, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(step == .promise)
                .opacity(step == .promise ? 0 : 1)

                Spacer()

                HStack(spacing: 12) {
                    Text("\(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.tertiary)
                        .monospacedDigit()

                    Button("Cancel", action: controller.cancel)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .frame(minWidth: 52, minHeight: 40, alignment: .trailing)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    ForEach(OnboardingStep.allCases, id: \.self) { item in
                        Capsule()
                            .fill(item == step ? Theme.accent : Theme.surfaceStrong)
                            .frame(width: item == step ? 20 : 6, height: 4)
                    }
                }

                Text(stepLabel.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.tertiary)
            }

            Spacer()

            IrisActionButton(title: actionTitle, style: .accent, action: advance)
        }
        .padding(.horizontal, 36)
        .padding(.top, 12)
        .padding(.bottom, 22)
    }

    private var stepLabel: String {
        switch step {
        case .promise: "Meet Iris"
        case .language: "How it talks"
        case .routine: "Your rhythm"
        case .privacy: "Ready"
        }
    }

    private var actionTitle: String {
        switch step {
        case .promise: "Meet the eye"
        case .language: "Got it"
        case .routine: "Use \(selectedRoutine.title.lowercased())"
        case .privacy: "Start Iris"
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .promise: meetStep
        case .language: languageStep
        case .routine: rhythmStep
        case .privacy: readyStep
        }
    }

    private var meetStep: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)
            AnimatedEyeHero()
                .frame(height: 128)
            VStack(spacing: 10) {
                Text("Your eyes deserve a better workday.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Iris lives quietly in your menu bar. The little eye follows your work rhythm and tells you when to rest—before your eyes complain.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 420)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 36)
    }

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The eye speaks in blinks.")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
            Text("A glance at the menu bar is enough to know what Iris needs from you.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)

            VStack(spacing: 8) {
                stateRow(
                    eye: StatusItemEye.frame(for: .idle(blinkEvery: 6), tick: 0),
                    title: "Calm blinks",
                    detail: "Everything is fine. Iris idles and blinks naturally."
                )
                stateRow(
                    eye: StatusItemEye.frame(for: .approaching, tick: 0),
                    title: "Quick blinks",
                    detail: "A break is coming up in under two minutes."
                )
                stateRow(
                    eye: StatusItemEye.frame(for: .due, tick: 0),
                    title: "Tired gaze",
                    detail: "A break is due. The eye half-closes and gently pulses."
                )
                stateRow(
                    eye: StatusItemEye.frame(for: .resting(secondsLeft: 20), tick: 0),
                    title: "Closed, counting",
                    detail: "Your reset is running right in the menu bar."
                )
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 18)
    }

    private func stateRow(eye: StatusItemEye.Frame, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(nsImage: StatusItemEye.image(eye))
                .interpolation(.high)
                .frame(width: 34, height: 34)
                .background(
                    Theme.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var rhythmStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a starting rhythm.")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
            Text("Choose what feels realistic today. You can change this anytime in Settings.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(RoutinePreset.all) { preset in
                routineOption(preset)
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 24)
    }

    private func routineOption(_ preset: RoutinePreset) -> some View {
        let selected = preset.id == draft.selectedRoutineID
        return Button {
            draft.selectedRoutineID = preset.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("\(preset.focusMinutes) min focus • \(preset.restSeconds) sec reset")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(selected ? Theme.surfaceStrong : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.8) : Theme.stroke, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var readyStep: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.accent)
            Text("One small favor first.")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                primerRow(
                    icon: "music.note",
                    title: "Allow Music control",
                    detail: "When macOS asks, choose OK to power the menu-bar music controls."
                )
                primerRow(
                    icon: "moon.stars.fill",
                    title: "Breaks dim the screen",
                    detail: "Iris can soften distractions for your \(selectedRoutine.restSeconds)-second reset. You can turn this off anytime."
                )
            }
            .frame(maxWidth: 430)
            Text("Everything stays on this Mac. No account, analytics, or cloud sync.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 36)
    }

    private func primerRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.surfaceElevated, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func goBack() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    private func advance() {
        guard let next = step.next else {
            finish()
            return
        }
        step = next
    }

    private func finish() {
        draft.commit()
        AppState.shared.breakIntervalChanged(to: Double(selectedRoutine.focusMinutes))
        controller.finish()
    }
}

// MARK: - Animated hero eye

struct AnimatedEyeHero: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { timeline in
            AnimatedEyeHeroFrame(date: timeline.date)
        }
    }
}

private struct AnimatedEyeHeroFrame: View {
    let date: Date

    private var frame: StatusItemEye.Frame {
        let tick = date.timeIntervalSinceReferenceDate
        let cycle = tick.truncatingRemainder(dividingBy: 9)
        if cycle < 2.5 {
            return StatusItemEye.frame(for: .idle(blinkEvery: 2.5), tick: tick)
        }
        if cycle < 4.5 {
            return StatusItemEye.frame(for: .due, tick: tick)
        }
        if cycle < 6.5 {
            return StatusItemEye.frame(
                for: .resting(secondsLeft: 7 - Int(cycle - 4.5)),
                tick: tick
            )
        }
        return StatusItemEye.frame(for: .approaching, tick: tick)
    }

    var body: some View {
        Image(nsImage: StatusItemEye.image(frame))
            .interpolation(.high)
            .resizable()
            .scaledToFit()
            .frame(width: 84, height: 84)
            .padding(18)
            .background(
                Circle()
                    .fill(Theme.surfaceElevated)
                    .overlay(
                        Circle().strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1.5)
                    )
            )
    }
}
