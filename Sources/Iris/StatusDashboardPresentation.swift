struct StatusDashboardPresentation: Equatable {
    enum Event: Equatable {
        case statusPointerChanged(Bool)
        case panelPointerChanged(Bool)
        case openDelayElapsed
        case closeDelayElapsed
        case statusClicked
        case outsideClicked
        case escapePressed
        case anotherDashboardOpened
    }

    private(set) var isOpen = false
    private(set) var isPinned = false
    private(set) var pointerOverStatus = false
    private(set) var pointerOverPanel = false

    mutating func apply(_ event: Event) {
        switch event {
        case let .statusPointerChanged(value):
            pointerOverStatus = value
        case let .panelPointerChanged(value):
            pointerOverPanel = value
        case .openDelayElapsed:
            if pointerOverStatus && !isOpen {
                isOpen = true
                isPinned = false
            }
        case .closeDelayElapsed:
            if !isPinned && !pointerOverStatus && !pointerOverPanel {
                isOpen = false
            }
        case .statusClicked:
            if isOpen && isPinned {
                close()
            } else {
                isOpen = true
                isPinned = true
            }
        case .outsideClicked, .escapePressed, .anotherDashboardOpened:
            close()
        }
    }

    private mutating func close() {
        isOpen = false
        isPinned = false
    }
}
