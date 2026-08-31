import AppKit
import SwiftUI
import Combine

@MainActor
final class PanelModel: ObservableObject {
    @Published var isExpanded = false
    @Published var isPinned = false
    @Published var isHovering = false
    @Published var showSettings = false
    @Published var selectedTab: IrisTab = .today
    @Published var hasNotch = true
    @Published var notchHeight: CGFloat = 32
}

final class IrisPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// NSView that owns the hover tracking area; SwiftUI content fills it.
final class HoverView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self,
                                       userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
}

@MainActor
final class NotchPanelController {
    static let shared = NotchPanelController(state: AppState.shared)

    let model = PanelModel()
    private let state: AppState
    private var panel: IrisPanel!
    private var hoverWork: DispatchWorkItem?
    private var exitWork: DispatchWorkItem?
    private var monitors: [Any] = []

    static let panelWidth: CGFloat = 404
    static let expandedHeight: CGFloat = 540
    static let lipHeight: CGFloat = 26
    static let floatingPillHeight: CGFloat = 58

    private init(state: AppState) {
        self.state = state
        configurePanel()
        positionCurrentState(animate: false)
        panel.orderFrontRegardless()
        installMonitors()
        // Keep timers honest even when nothing else is happening.
        _ = ProcessInfo.processInfo.beginActivity(options: [.userInitiated],
                                                  reason: "Iris break reminders")
    }

    // MARK: Panel setup

    private func configurePanel() {
        let p = IrisPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 50),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered,
                          defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        p.ignoresMouseEvents = false

        let hover = HoverView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        let hosting = NSHostingView(rootView: RootView(state: state, model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = true
        let mask: NSView.AutoresizingMask = [.width, .height]
        hosting.autoresizingMask = mask
        hosting.frame = hover.bounds
        hover.addSubview(hosting)
        hover.onEnter = { [weak self] in self?.handleHoverEntered() }
        hover.onExit = { [weak self] in self?.handleHoverExited() }
        p.contentView = hover
        panel = p
    }

    private func installMonitors() {
        let clickHandler: (NSEvent) -> Void = { [weak self] _ in
            Task { @MainActor in
                guard let self, let panel = self.panel, self.model.isExpanded else { return }
                if !panel.frame.contains(NSEvent.mouseLocation) {
                    self.setExpanded(false)
                }
            }
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown],
                                                           handler: clickHandler) {
            monitors.append(monitor)
        }
        // Escape collapses the panel.
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    self?.collapseIfExpanded()
                }
            }
            return event
        }) {
            monitors.append(monitor)
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            Task { @MainActor in self?.positionCurrentState(animate: false) }
        }
        // Sleep/wake can leave the panel mispositioned; snap back on wake.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                                          object: nil,
                                                          queue: .main) { [weak self] _ in
            Task { @MainActor in self?.positionCurrentState(animate: false) }
        }
    }

    @objc private func collapseIfExpanded() {
        if model.isExpanded {
            setExpanded(false)
        }
    }

    // MARK: Geometry

    private struct Geo {
        let frame: NSRect
        let hasNotch: Bool
        let notchHeight: CGFloat
    }

    /// The built-in (notched) display when present; otherwise the main screen.
    private static func irisScreen() -> NSScreen? {
        if let builtin = NSScreen.screens.first(where: { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
        }) {
            return builtin
        }
        return NSScreen.main
    }

    private static func geometry(expanded: Bool) -> Geo? {
        // The pill belongs on the physical notch — target the built-in display
        // even when an external monitor has keyboard focus.
        guard let screen = irisScreen() else { return nil }
        let f = screen.frame

        var notchWidth: CGFloat = 168
        var notchHeight: CGFloat = 32
        var hasNotch = false
        var centerX = f.midX
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let w = right.minX - left.maxX
            if w > 24 {
                notchWidth = w
                notchHeight = f.maxY - left.minY
                hasNotch = true
                centerX = (left.maxX + right.minX) / 2
            }
        }

        if expanded {
            let extraGap: CGFloat = hasNotch ? 0 : 6
            let height = Self.expandedHeight + extraGap
            let frame = NSRect(x: centerX - Self.panelWidth / 2,
                               y: f.maxY - height,
                               width: Self.panelWidth,
                               height: height)
            return Geo(frame: frame, hasNotch: hasNotch, notchHeight: notchHeight)
        } else if hasNotch {
            let width = notchWidth + 26
            let height = notchHeight + Self.lipHeight
            let frame = NSRect(x: centerX - width / 2,
                               y: f.maxY - height,
                               width: width,
                               height: height)
            return Geo(frame: frame, hasNotch: true, notchHeight: notchHeight)
        } else {
            let width: CGFloat = 211
            let height = Self.floatingPillHeight
            let frame = NSRect(x: centerX - width / 2,
                               y: f.maxY - height - 6,
                               width: width,
                               height: height)
            return Geo(frame: frame, hasNotch: false, notchHeight: 0)
        }
    }

    func positionCurrentState(animate: Bool) {
        guard let panel, let g = Self.geometry(expanded: model.isExpanded) else { return }
        model.hasNotch = g.hasNotch
        model.notchHeight = g.notchHeight
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.38
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.94, 0.26, 1)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(g.frame, display: true)
            }
        } else {
            panel.setFrame(g.frame, display: false)
        }
    }

    // MARK: State

    func setExpanded(_ flag: Bool, pin: Bool = false) {
        guard flag != model.isExpanded else { return }
        if flag {
            StatusDashboardController.shared.closeForAnotherDashboard()
        }
        model.isPinned = pin
        model.isExpanded = flag
        if flag {
            exitWork?.cancel()
            state.music.startPolling()
        } else {
            model.showSettings = false
        }
        positionCurrentState(animate: true)
    }

    func expandPinned() {
        setExpanded(true, pin: true)
    }

    func toggle() {
        if model.isExpanded { setExpanded(false) } else { setExpanded(true, pin: true) }
    }

    func openSettings() {
        expandPinned()
        model.showSettings = true
    }

    func open(tab: IrisTab) {
        model.selectedTab = tab
        expandPinned()
    }

    private func handleHoverEntered() {
        model.isHovering = true
        exitWork?.cancel()
        guard !model.isExpanded else { return }
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.setExpanded(true)
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func handleHoverExited() {
        model.isHovering = false
        hoverWork?.cancel()
        guard model.isExpanded, !model.isPinned else { return }
        exitWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.model.isPinned else { return }
            self.setExpanded(false)
        }
        exitWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func cancelPendingHover() {
        hoverWork?.cancel()
        exitWork?.cancel()
    }

    func collapseForAnotherDashboard() {
        guard model.isExpanded else { return }
        setExpanded(false)
    }
}
