import AppKit
import SwiftUI

/// Full-screen Focus Mode: dims the whole display to black and plays the
/// exercise animation large, with prev/next stepping through the routine,
/// auto-advance on step completion, auto-hiding controls and keyboard
/// shortcuts (← → step, space pause, Esc exit).
@MainActor
final class TheaterController: ObservableObject {
    static let shared = TheaterController()

    @Published var controlsVisible = true
    private(set) var isActive = false
    private(set) var mode: Mode = .exercise

    enum Mode { case exercise, breakRest }

    private var window: TheaterWindow?
    private var monitors: [Any] = []
    private var hideWork: DispatchWorkItem?
    private var advanceWork: DispatchWorkItem?
    private var activity: NSObjectProtocol?
    private var cursorHidden = false

    private var session: ExerciseSession { AppState.shared.exercises }

    func present(steps: [Exercise], index: Int = 0) {
        guard !isActive, !steps.isEmpty, let screen = NSScreen.main else { return }
        isActive = true
        mode = .exercise

        session.onStepComplete = { [weak self] in self?.handleStepComplete() }

        let w = TheaterWindow(contentRect: screen.frame,
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        w.setFrame(screen.frame, display: true)
        w.level = .screenSaver
        w.backgroundColor = .black
        w.isOpaque = true
        w.isMovable = false
        w.hasShadow = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.acceptsMouseMovedEvents = true
        w.contentView = NSHostingView(rootView: TheaterView(session: session,
                                                            controller: self,
                                                            music: AppState.shared.music))
        window = w
        w.orderFrontRegardless()
        w.makeKey()

        // Keep track info live for the in-theater music strip.
        AppState.shared.music.startPolling()

        // Keep the display awake for the length of the routine.
        activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated],
                                                         reason: "Iris focus mode")

        session.startQueue(steps, index: index)
        installMonitors()
        showControls()

        // The notch panel would float behind the theater; tuck it away.
        NotchPanelController.shared.setExpanded(false)
    }

    /// Full-screen rest overlay for scheduled breaks. Watches AppState: when
    /// the rest completes (restSecondsLeft → nil) it dismisses itself.
    func presentRest() {
        guard !isActive, let screen = NSScreen.main else { return }
        isActive = true
        mode = .breakRest

        let state = AppState.shared
        let w = TheaterWindow(contentRect: screen.frame,
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        w.setFrame(screen.frame, display: true)
        w.level = .screenSaver
        w.backgroundColor = .black
        w.isOpaque = true
        w.isMovable = false
        w.hasShadow = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.acceptsMouseMovedEvents = true
        w.contentView = NSHostingView(rootView: BreakTheaterView(state: state, controller: self))
        window = w
        w.orderFrontRegardless()
        w.makeKey()

        activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated],
                                                         reason: "Iris break")
        installMonitors()
        NotchPanelController.shared.setExpanded(false)
    }

    func dismiss() {
        guard isActive else { return }
        isActive = false
        mode = .exercise
        session.onStepComplete = nil
        session.stop()
        session.clearQueue()
        teardown()
    }

    func step(_ delta: Int) {
        guard isActive else { return }
        advanceWork?.cancel()
        session.gotoStep(delta)
        showControls()
    }

    func togglePause() {
        guard isActive else { return }
        session.togglePause()
        showControls()
    }

    // MARK: Flow

    private func handleStepComplete() {
        if session.queueIndex < session.queue.count - 1 {
            let idx = session.queueIndex
            schedule(1.6) { [weak self] in
                guard let self, self.isActive, self.session.queueIndex == idx else { return }
                self.session.gotoStep(1)
            }
        } else {
            schedule(5) { [weak self] in self?.dismiss() }
        }
    }

    private func schedule(_ seconds: Double, _ work: @escaping () -> Void) {
        advanceWork?.cancel()
        let item = DispatchWorkItem(block: work)
        advanceWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    // MARK: Chrome

    func showControls() {
        guard isActive, mode == .exercise else { return }
        controlsVisible = true
        setCursor(hidden: false)
        hideWork?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isActive else { return }
            self.controlsVisible = false
            self.setCursor(hidden: true)
        }
        hideWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: item)
    }

    private func setCursor(hidden: Bool) {
        guard hidden != cursorHidden else { return }
        cursorHidden = hidden
        if hidden { NSCursor.hide() } else { NSCursor.unhide() }
    }

    // MARK: Plumbing

    private func installMonitors() {
        var handlers: [Any] = []
        if let key = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            Task { @MainActor in self?.handleKey(event) }
            return event
        }) {
            handlers.append(key)
        }
        if let move = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown],
                                                       handler: { [weak self] event in
            Task { @MainActor in self?.showControls() }
            return event
        }) {
            handlers.append(move)
        }
        monitors = handlers
    }

    private func handleKey(_ event: NSEvent) {
        guard isActive else { return }
        switch event.keyCode {
        case 53: dismiss()      // Escape
        case 123: step(-1)      // ←
        case 124: step(1)       // →
        case 49: togglePause()  // space
        default: break
        }
    }

    private func teardown() {
        teardownMonitors()
        hideWork?.cancel()
        advanceWork?.cancel()
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        self.activity = nil
        setCursor(hidden: false)
        controlsVisible = true
        AppState.shared.music.stopPolling()
        window?.orderOut(nil)
        window = nil
    }

    private func teardownMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}

final class TheaterWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - Full-screen view

struct TheaterView: View {
    @ObservedObject var session: ExerciseSession
    @ObservedObject var controller: TheaterController
    let music: MusicService

    @AppStorage(SettingsKeys.musicSupport) private var musicSupport = true

    private var stepCount: Int { max(1, session.queue.count) }
    private var isLast: Bool { session.queueIndex >= stepCount - 1 }
    private var isFinished: Bool { session.justCompleted && isLast }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // The exercise itself stays fully visible even when controls hide.
                VStack(spacing: 0) {
                    Spacer(minLength: geo.size.height * 0.08)
                    ExercisePreviewCanvas(kind: session.selected.kind,
                                          startedAt: session.startedAt,
                                          elapsedBase: session.accumulated,
                                          loopSeconds: session.loopSeconds,
                                          reversed: session.reversed,
                                          paused: !session.running,
                                          plain: true)
                        .frame(width: geo.size.width * 0.58,
                               height: geo.size.height * 0.52)
                    Spacer()
                }

                header
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, max(24, geo.size.height * 0.05))
                    .padding(.leading, max(28, geo.size.width * 0.04))
                    .opacity(chromeOpacity)

                VStack {
                    Spacer()
                    controls(width: geo.size.width)
                        .padding(.bottom, max(30, geo.size.height * 0.05))
                }                .opacity(chromeOpacity)

                if session.justCompleted && !isFinished {
                    stepCompleteBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .offset(y: -geo.size.height * 0.30)
                }

                if isFinished {
                    finishedOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: controller.controlsVisible)
        .background(Color.black.ignoresSafeArea())
    }

    private var chromeOpacity: Double {
        controller.controlsVisible || isFinished ? 1 : 0
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // Live run indicator: a dot orbiting the step badge.
                    if session.running {
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                            let angle = timeline.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: 2.5) / 2.5 * 2 * .pi
                            ZStack {
                                Circle()
                                    .stroke(Theme.accent.opacity(0.35), lineWidth: 1.5)
                                Circle()
                                    .fill(Theme.accent)
                                    .frame(width: 4.5, height: 4.5)
                                    .offset(x: 7 * CGFloat(cos(angle)), y: 7 * CGFloat(sin(angle)))
                            }
                            .frame(width: 17, height: 17)
                        }
                    }
                    Text("STEP \(session.queueIndex + 1) OF \(stepCount)")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Theme.accent)
                }
                Text(session.selected.name)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text(session.selected.hint)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: 380, alignment: .leading)
                if session.isPaused {
                    Text("PAUSED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.restorative)
                        .padding(.top, 4)
                }
            }
            Spacer()
            musicStrip
            Button {
                controller.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 38, height: 38)
                    .background(Theme.surfaceStrong, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
    }

    private func controls(width: CGFloat) -> some View {
        VStack(spacing: 16) {
            segments(width: width)
            HStack(spacing: 30) {
                theaterButton("backward.end.fill", diameter: 46, enabled: session.queueIndex > 0) {
                    controller.step(-1)
                }
                theaterButton(session.running ? "pause.fill" : "play.fill",
                              diameter: 62,
                              iconColor: .black,
                              background: Color.white) {
                    controller.togglePause()
                }
                theaterButton("forward.end.fill", diameter: 46, enabled: !isLast) {
                    controller.step(1)
                }
            }
            Text("← → switch steps · space pause · esc exit")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func segments(width: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { i in
                    let fraction: Double = {
                        if i < session.queueIndex { return 1 }
                        if i > session.queueIndex { return 0 }
                        let elapsed = session.currentElapsed
                        return min(1, max(0, elapsed / Double(max(1, session.duration))))
                    }()
                    Capsule()
                        .fill(fraction >= 0.999 ? Theme.accent : Theme.accent.opacity(0.25))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in
                                Capsule()
                                    .fill(Theme.accent)
                                    .frame(width: g.size.width * fraction)
                            }
                        }
                }
            }
            .frame(width: min(420, width * 0.4))
        }
    }

    /// Slim music strip (reference 2) so tracks can be steered mid-routine
    /// without leaving Focus Mode. Fades with the rest of the chrome.
    @ViewBuilder
    private var musicStrip: some View {
        if musicSupport, let track = music.trackName {
            HStack(spacing: 14) {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30, height: 30)
                    .background(Theme.surfaceStrong, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(track)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(music.artistName ?? "")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                }
                .frame(width: 230, alignment: .leading)
                smallTransport("backward.fill") { music.previousTrack() }
                smallTransport(music.isPlaying ? "pause.fill" : "play.fill", prominent: true) {
                    music.togglePlayPause()
                }
                smallTransport("forward.fill") { music.nextTrack() }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Theme.surface, in: Capsule())
        }
    }

    private func smallTransport(_ icon: String,
                                prominent: Bool = false,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: prominent ? 15 : 12, weight: .semibold))
                .foregroundStyle(prominent ? Theme.onAccent : Theme.text)
                .frame(width: prominent ? 36 : 30, height: prominent ? 36 : 30)
                .background(prominent ? Theme.accent : Theme.surfaceStrong, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var stepCompleteBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.restorative)
            Text(stepCount > 0 && session.queueIndex < stepCount - 1
                 ? "Step complete — next: \(session.queue[session.queueIndex + 1].name)"
                 : "Step complete")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.surfaceStrong, in: Capsule())
    }

    private var finishedOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.restorative)
            Text("Routine complete")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
            Text("\(stepCount) steps · your eyes thank you")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
            IrisActionButton(title: "Done", style: .accent) {
                controller.dismiss()
            }
            .padding(.top, 8)
        }
        .padding(40)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func theaterButton(_ icon: String,
                               diameter: CGFloat,
                               iconColor: Color = Theme.text,
                               background: Color = Theme.surfaceStrong,
                               enabled: Bool = true,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: diameter * 0.34, weight: .semibold))
                .foregroundStyle(enabled ? iconColor : iconColor.opacity(0.3))
                .frame(width: diameter, height: diameter)
                .background(background.opacity(enabled ? 1 : 0.5), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(icon.contains("backward") ? "Previous step"
                            : icon.contains("forward") ? "Next step"
                            : icon.contains("pause") ? "Pause" : "Start")
    }
}

// MARK: - Full-screen break (rest) view

struct BreakTheaterView: View {
    @ObservedObject var state: AppState
    @ObservedObject var controller: TheaterController

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(Theme.restorative.opacity(0.14), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Theme.restorative, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: geo.size.height * 0.30, height: geo.size.height * 0.30)
                    .overlay(
                        Text("\(state.restSecondsLeft ?? 0)")
                            .font(.system(size: 76, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.text)
                            .monospacedDigit()
                            .contentShape(Rectangle())
                    )

                    VStack(spacing: 10) {
                        Text("Look 20 feet away")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.text)
                        Text("Blink slowly and soften your gaze.\nYour screen comes back on its own.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    Spacer()

                    Button("Skip break") {
                        state.cancelRest()
                        controller.dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.bottom, max(28, geo.size.height * 0.05))
                }
            }
        }
        .onChange(of: state.restSecondsLeft) { value in
            if value == nil, controller.mode == .breakRest {
                controller.dismiss()
            }
        }
    }

    private var progress: CGFloat {
        guard let left = state.restSecondsLeft else { return 1 }
        return CGFloat(left) / CGFloat(max(1, state.restDuration))
    }
}
