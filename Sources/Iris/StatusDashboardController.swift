import AppKit
import SwiftUI

final class StatusItemTrackingView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
}

@MainActor
final class StatusDashboardController: NSObject {
    static let shared = StatusDashboardController(state: .shared)
    nonisolated static let openDelay: TimeInterval = 0.15
    nonisolated static let closeDelay: TimeInterval = 0.35

    let model = PanelModel()

    private let state: AppState
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )
    private let panel = IrisPanel(
        contentRect: NSRect(origin: .zero, size: StatusDashboardGeometry.preferredSize),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private var presentation = StatusDashboardPresentation()
    private var openWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?
    private var eventMonitors: [Any] = []
    private var screenObserver: NSObjectProtocol?

    private init(state: AppState) {
        self.state = state
        super.init()
        configureStatusItem()
        configurePanel()
        installMonitors()
    }

    deinit {
        eventMonitors.forEach(NSEvent.removeMonitor)
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Iris")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = "Iris"
        button.setAccessibilityLabel("Iris")
        button.target = self
        button.action = #selector(handleStatusItemAction(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let trackingView = StatusItemTrackingView(frame: button.bounds)
        trackingView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.onEnter = { [weak self] in self?.handleStatusEntered() }
        trackingView.onExit = { [weak self] in self?.handleStatusExited() }
        button.addSubview(trackingView)
        NSLayoutConstraint.activate([
            trackingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            trackingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            trackingView.topAnchor.constraint(equalTo: button.topAnchor),
            trackingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false

        let hover = HoverView(
            frame: NSRect(origin: .zero, size: StatusDashboardGeometry.preferredSize)
        )
        hover.autoresizingMask = [.width, .height]
        hover.onEnter = { [weak self] in self?.handlePanelEntered() }
        hover.onExit = { [weak self] in self?.handlePanelExited() }

        let hosting = NSHostingView(rootView: StatusDashboardView(state: state, model: model))
        hosting.frame = hover.bounds
        hosting.autoresizingMask = [.width, .height]
        hover.addSubview(hosting)
        panel.contentView = hover
    }

    private func installMonitors() {
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]

        if let local = NSEvent.addLocalMonitorForEvents(matching: mouseEvents, handler: {
            [weak self] event in
            self?.closeIfClickIsOutside()
            return event
        }) {
            eventMonitors.append(local)
        }

        if let global = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents, handler: {
            [weak self] _ in
            Task { @MainActor in self?.closeIfClickIsOutside() }
        }) {
            eventMonitors.append(global)
        }

        if let keyboard = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: {
            [weak self] event in
            guard event.keyCode == 53, self?.presentation.isOpen == true else {
                return event
            }
            self?.cancelPendingWork()
            self?.presentation.apply(.escapePressed)
            self?.renderPresentation()
            return nil
        }) {
            eventMonitors.append(keyboard)
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.presentation.isOpen else { return }
                self.positionPanel()
            }
        }
    }

    @objc private func handleStatusItemAction(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            openWork?.cancel()
            showUtilityMenu()
            return
        }

        cancelPendingWork()
        presentation.apply(.statusClicked)
        renderPresentation()
    }

    private func handleStatusEntered() {
        closeWork?.cancel()
        presentation.apply(.statusPointerChanged(true))
        guard !presentation.isOpen else { return }

        openWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.presentation.apply(.openDelayElapsed)
            self.renderPresentation()
        }
        openWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.openDelay, execute: work)
    }

    private func handleStatusExited() {
        openWork?.cancel()
        presentation.apply(.statusPointerChanged(false))
        scheduleCloseIfNeeded()
    }

    private func handlePanelEntered() {
        closeWork?.cancel()
        presentation.apply(.panelPointerChanged(true))
    }

    private func handlePanelExited() {
        presentation.apply(.panelPointerChanged(false))
        scheduleCloseIfNeeded()
    }

    private func scheduleCloseIfNeeded() {
        guard presentation.isOpen, !presentation.isPinned else { return }
        closeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.presentation.apply(.closeDelayElapsed)
            self.renderPresentation()
        }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.closeDelay, execute: work)
    }

    private func cancelPendingWork() {
        openWork?.cancel()
        closeWork?.cancel()
    }

    private func renderPresentation() {
        model.isExpanded = presentation.isOpen
        model.isPinned = presentation.isPinned

        if presentation.isOpen {
            let isOpening = !panel.isVisible
            if isOpening {
                NotchPanelController.shared.collapseForAnotherDashboard()
            }
            positionPanel()
            showPanel(animate: isOpening)
            state.music.startPolling()
        } else {
            model.showSettings = false
            hidePanel()
        }
    }

    private func showPanel(animate: Bool) {
        guard animate else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            return
        }

        let finalFrame = panel.frame
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = 0
        if !reduceMotion {
            panel.setFrame(finalFrame.offsetBy(dx: 0, dy: 6), display: false)
        }
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.10 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            if !reduceMotion {
                panel.animator().setFrame(finalFrame, display: true)
            }
        }
    }

    private func hidePanel() {
        guard panel.isVisible else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let finalFrame = panel.frame

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.10 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            if !reduceMotion {
                panel.animator().setFrame(finalFrame.offsetBy(dx: 0, dy: 6), display: true)
            }
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.presentation.isOpen else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
                self.panel.setFrame(finalFrame, display: false)
            }
        }
    }

    private func positionPanel() {
        let anchor = statusButtonFrame()
        let screen = anchor.flatMap { rect in
            NSScreen.screens.first { $0.frame.intersects(rect) }
        } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        panel.setFrame(
            StatusDashboardGeometry.frame(anchor: anchor, visibleFrame: visibleFrame),
            display: false
        )
    }

    private func statusButtonFrame() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func closeIfClickIsOutside() {
        guard presentation.isOpen else { return }
        let pointer = NSEvent.mouseLocation
        guard !panel.frame.contains(pointer), statusButtonFrame()?.contains(pointer) != true else {
            return
        }

        cancelPendingWork()
        presentation.apply(.outsideClicked)
        renderPresentation()
    }

    private func showUtilityMenu() {
        let menu = NSMenu(title: "Iris")
        menu.addItem(menuItem(title: "Take a Break Now", action: #selector(startBreak)))
        menu.addItem(menuItem(title: "Settings…", action: #selector(openSettingsFromMenu), key: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit Iris", action: #selector(quit), key: "q"))

        guard let button = statusItem.button else { return }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: button.bounds.maxX, y: button.bounds.minY),
            in: button
        )
    }

    private func menuItem(title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func startBreak() {
        state.startRestNow()
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func closeForAnotherDashboard() {
        cancelPendingWork()
        presentation.apply(.anotherDashboardOpened)
        renderPresentation()
    }

    func open(tab: IrisTab) {
        cancelPendingWork()
        model.selectedTab = tab
        if !presentation.isOpen || !presentation.isPinned {
            presentation.apply(.statusClicked)
        }
        renderPresentation()
    }

    func openSettings() {
        open(tab: .today)
        model.showSettings = true
    }
}
