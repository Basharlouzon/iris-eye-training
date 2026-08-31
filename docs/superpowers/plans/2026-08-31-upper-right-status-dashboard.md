# Iris Upper-Right Status Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 200 pt click-only menu-bar window with a polished 440 × 620 pt Iris dashboard that opens beneath the upper-right status icon on hover and supports pinning, dismissal, and the existing utility commands.

**Architecture:** A custom `NSStatusItem` and borderless `NSPanel` are owned by a new main-actor controller. Pure geometry and interaction-state types make screen placement and hover/pin behavior independently testable, while a reusable SwiftUI dashboard wrapper renders the existing Today, Train, Progress, onboarding, and Settings flows with shared `AppState`.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (`NSStatusItem`, `NSPanel`, `NSEvent`, `NSTrackingArea`), XCTest, Swift Package Manager.

**Spec:** `docs/superpowers/specs/2026-08-31-upper-right-status-dashboard-design.md`

## Global Constraints

- macOS deployment target remains 13.0.
- Preferred dashboard size is exactly 440 × 620 pt.
- Dashboard gap below the status item is 8 pt; visible-screen margin is 12 pt.
- Hover-open delay is 150 ms; hover-close delay is 350 ms.
- The upper-right panel has no arrow, title bar, traffic lights, or resize controls.
- The center notch pill remains available and compact.
- `AppState.shared` remains the only source for reminders, exercises, statistics, weather, and Music state.
- Calendar and Focus context remain optional; no paywall is introduced.
- The workspace is not a Git repository. Do not run commit, branch, merge, push, or worktree commands; use green test/build checkpoints instead.

## File Structure

- Create `Sources/Iris/StatusDashboardGeometry.swift`: pure panel-size and screen-placement logic.
- Create `Sources/Iris/StatusDashboardPresentation.swift`: pure hover, pin, and dismissal reducer.
- Create `Sources/Iris/StatusDashboardView.swift`: upper-right panel surface around the reusable dashboard content.
- Create `Sources/Iris/StatusDashboardController.swift`: status item, tracking, AppKit panel, timers, monitors, and utility menu.
- Modify `Sources/Iris/RootView.swift`: rename the reusable expanded content to `IrisDashboardView` and keep the notch wrapper thin.
- Modify `Sources/Iris/Main.swift`: remove `MenuBarExtra`, retain the controller, and expose only a non-window Settings scene.
- Modify `Sources/Iris/NotchPanelController.swift`: coordinate full-dashboard exclusivity.
- Modify `Tests/IrisTests/IrisExperienceTests.swift`: geometry and presentation regression coverage.
- Modify `README.md` and `DESIGN.md`: document the upper-right hover dashboard and right-click utility menu.

---

### Task 1: Testable Upper-Right Geometry

**Files:**
- Create: `Sources/Iris/StatusDashboardGeometry.swift`
- Test: `Tests/IrisTests/IrisExperienceTests.swift`

**Interfaces:**
- Consumes: AppKit `NSRect`, `NSSize`.
- Produces: `StatusDashboardGeometry.preferredSize`, `StatusDashboardGeometry.frame(anchor:visibleFrame:preferredSize:gap:margin:)`.

- [ ] **Step 1: Write failing geometry tests**

Add these tests to `IrisExperienceTests`:

```swift
func testStatusDashboardRightAlignsBeneathStatusItem() {
    let visible = NSRect(x: 0, y: 53, width: 1728, height: 1030)
    let anchor = NSRect(x: 1668, y: 1085, width: 24, height: 22)

    let frame = StatusDashboardGeometry.frame(
        anchor: anchor,
        visibleFrame: visible
    )

    XCTAssertEqual(frame, NSRect(x: 1252, y: 451, width: 440, height: 620))
}

func testStatusDashboardClampsToVisibleScreenMargins() {
    let visible = NSRect(x: 0, y: 0, width: 1280, height: 800)
    let anchor = NSRect(x: 1300, y: 790, width: 30, height: 22)

    let frame = StatusDashboardGeometry.frame(
        anchor: anchor,
        visibleFrame: visible
    )

    XCTAssertEqual(frame.maxX, 1268)
    XCTAssertGreaterThanOrEqual(frame.minX, 12)
    XCTAssertGreaterThanOrEqual(frame.minY, 12)
    XCTAssertLessThanOrEqual(frame.maxY, 788)
}

func testStatusDashboardShrinksOnAConstrainedScreen() {
    let visible = NSRect(x: 0, y: 0, width: 400, height: 600)

    let frame = StatusDashboardGeometry.frame(
        anchor: nil,
        visibleFrame: visible
    )

    XCTAssertEqual(frame.size, NSSize(width: 376, height: 576))
    XCTAssertEqual(frame.origin, NSPoint(x: 12, y: 12))
}
```

- [ ] **Step 2: Run the tests and confirm RED**

Run:

```bash
swift test --filter IrisExperienceTests.testStatusDashboard
```

Expected: compilation fails because `StatusDashboardGeometry` does not exist.

- [ ] **Step 3: Implement the pure geometry type**

Create `StatusDashboardGeometry.swift`:

```swift
import AppKit

enum StatusDashboardGeometry {
    static let preferredSize = NSSize(width: 440, height: 620)

    static func frame(
        anchor: NSRect?,
        visibleFrame: NSRect,
        preferredSize: NSSize = preferredSize,
        gap: CGFloat = 8,
        margin: CGFloat = 12
    ) -> NSRect {
        let width = min(preferredSize.width, max(1, visibleFrame.width - margin * 2))
        let height = min(preferredSize.height, max(1, visibleFrame.height - margin * 2))
        let fallbackX = visibleFrame.maxX - margin - width
        let desiredX = anchor.map { $0.maxX - width } ?? fallbackX
        let minimumX = visibleFrame.minX + margin
        let maximumX = visibleFrame.maxX - margin - width
        let x = min(max(desiredX, minimumX), maximumX)

        let desiredTop = anchor?.minY ?? (visibleFrame.maxY + gap - margin)
        let desiredY = desiredTop - gap - height
        let minimumY = visibleFrame.minY + margin
        let maximumY = visibleFrame.maxY - margin - height
        let y = min(max(desiredY, minimumY), maximumY)

        return NSRect(x: x, y: y, width: width, height: height)
    }
}
```

- [ ] **Step 4: Run geometry tests and confirm GREEN**

Run:

```bash
swift test --filter IrisExperienceTests.testStatusDashboard
```

Expected: all three geometry tests pass with no warnings.

- [ ] **Step 5: Record checkpoint**

Run `swift build -c debug`. Record the passing output in the task log; no commit is possible in this non-Git workspace.

---

### Task 2: Hover, Pin, and Dismissal State

**Files:**
- Create: `Sources/Iris/StatusDashboardPresentation.swift`
- Test: `Tests/IrisTests/IrisExperienceTests.swift`

**Interfaces:**
- Consumes: `StatusDashboardPresentation.Event` values from the AppKit controller.
- Produces: `isOpen`, `isPinned`, `pointerOverStatus`, `pointerOverPanel`, and `apply(_:)`.

- [ ] **Step 1: Write failing interaction tests**

Add:

```swift
func testHoverKeepsDashboardOpenAcrossStatusItemAndPanel() {
    var state = StatusDashboardPresentation()
    state.apply(.statusPointerChanged(true))
    state.apply(.openDelayElapsed)
    XCTAssertTrue(state.isOpen)

    state.apply(.panelPointerChanged(true))
    state.apply(.statusPointerChanged(false))
    state.apply(.closeDelayElapsed)
    XCTAssertTrue(state.isOpen)

    state.apply(.panelPointerChanged(false))
    state.apply(.closeDelayElapsed)
    XCTAssertFalse(state.isOpen)
}

func testStatusClickPinsThenClosesDashboard() {
    var state = StatusDashboardPresentation()
    state.apply(.statusClicked)
    XCTAssertTrue(state.isOpen)
    XCTAssertTrue(state.isPinned)

    state.apply(.statusClicked)
    XCTAssertFalse(state.isOpen)
    XCTAssertFalse(state.isPinned)
}

func testPinnedDashboardIgnoresHoverExitButClosesForOutsideInput() {
    var state = StatusDashboardPresentation()
    state.apply(.statusClicked)
    state.apply(.closeDelayElapsed)
    XCTAssertTrue(state.isOpen)

    state.apply(.outsideClicked)
    XCTAssertFalse(state.isOpen)

    state.apply(.statusClicked)
    state.apply(.escapePressed)
    XCTAssertFalse(state.isOpen)
}

func testOpeningAnotherFullDashboardClosesStatusDashboard() {
    var state = StatusDashboardPresentation()
    state.apply(.statusClicked)
    state.apply(.anotherDashboardOpened)
    XCTAssertFalse(state.isOpen)
    XCTAssertFalse(state.isPinned)
}
```

- [ ] **Step 2: Run interaction tests and confirm RED**

Run:

```bash
swift test --filter IrisExperienceTests.testHoverKeepsDashboardOpenAcrossStatusItemAndPanel
```

Expected: compilation fails because `StatusDashboardPresentation` does not exist.

- [ ] **Step 3: Implement the reducer**

Create `StatusDashboardPresentation.swift`:

```swift
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
            if pointerOverStatus {
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
```

- [ ] **Step 4: Run interaction tests and confirm GREEN**

Run:

```bash
swift test --filter IrisExperienceTests.testHoverKeepsDashboardOpenAcrossStatusItemAndPanel
swift test --filter IrisExperienceTests.testStatusClickPinsThenClosesDashboard
swift test --filter IrisExperienceTests.testPinnedDashboardIgnoresHoverExitButClosesForOutsideInput
swift test --filter IrisExperienceTests.testOpeningAnotherFullDashboardClosesStatusDashboard
```

Expected: all four tests pass.

- [ ] **Step 5: Record checkpoint**

Run `swift test`. Preserve the green output; no Git commit is attempted.

---

### Task 3: Reusable Dashboard Surface

**Files:**
- Create: `Sources/Iris/StatusDashboardView.swift`
- Modify: `Sources/Iris/RootView.swift`
- Test: `Tests/IrisTests/IrisExperienceTests.swift`

**Interfaces:**
- Consumes: `ExpandedView(state:model:topInset:)` content behavior already present in `RootView.swift`.
- Produces: `IrisDashboardView(state:model:topInset:)` and `StatusDashboardView(state:model:)`.

- [ ] **Step 1: Add a reusable presentation-context test**

Add:

```swift
func testDashboardPresentationInsetsMatchTheirSurface() {
    XCTAssertEqual(DashboardPlacement.notch(topInset: 32).topInset, 32)
    XCTAssertEqual(DashboardPlacement.statusItem.topInset, 0)
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```bash
swift test --filter IrisExperienceTests.testDashboardPresentationInsetsMatchTheirSurface
```

Expected: compilation fails because `DashboardPlacement` does not exist.

- [ ] **Step 3: Add the placement model**

At the top of `StatusDashboardView.swift`, add:

```swift
import SwiftUI

enum DashboardPlacement: Equatable {
    case notch(topInset: CGFloat)
    case statusItem

    var topInset: CGFloat {
        switch self {
        case let .notch(topInset): topInset
        case .statusItem: 0
        }
    }
}
```

- [ ] **Step 4: Extract the existing expanded content**

In `RootView.swift`, rename `ExpandedView` to `IrisDashboardView` without changing
its state gate, tab shell, Settings overlay, or feature views. Update the center
panel call site to:

```swift
IrisDashboardView(
    state: state,
    model: model,
    topInset: DashboardPlacement.notch(
        topInset: model.hasNotch ? model.notchHeight : 0
    ).topInset
)
```

Create the upper-right wrapper in `StatusDashboardView.swift`:

```swift
struct StatusDashboardView: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: PanelModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }

            IrisDashboardView(
                state: state,
                model: model,
                topInset: DashboardPlacement.statusItem.topInset
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .shadow(color: .black.opacity(0.50), radius: 32, y: 14)
    }
}
```

- [ ] **Step 5: Run the placement test and build**

Run:

```bash
swift test --filter IrisExperienceTests.testDashboardPresentationInsetsMatchTheirSurface
swift build -c debug
```

Expected: the test and build pass; the center notch dashboard remains behaviorally unchanged.

- [ ] **Step 6: Record checkpoint**

Run `swift test`. Preserve the results as the Task 3 checkpoint.

---

### Task 4: Custom Status Item and Hover Panel

**Files:**
- Create: `Sources/Iris/StatusDashboardController.swift`
- Modify: `Sources/Iris/Main.swift`
- Test: `Tests/IrisTests/IrisExperienceTests.swift`

**Interfaces:**
- Consumes: `StatusDashboardGeometry`, `StatusDashboardPresentation`, `StatusDashboardView`, `PanelModel`, `AppState.shared`.
- Produces: `StatusDashboardController.shared`, `closeForAnotherDashboard()`, `openSettings()`, and the live `NSStatusItem`.

- [ ] **Step 1: Add timing-contract tests**

Add:

```swift
func testStatusDashboardUsesApprovedHoverTiming() {
    XCTAssertEqual(StatusDashboardController.openDelay, 0.15)
    XCTAssertEqual(StatusDashboardController.closeDelay, 0.35)
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```bash
swift test --filter IrisExperienceTests.testStatusDashboardUsesApprovedHoverTiming
```

Expected: compilation fails because `StatusDashboardController` does not exist.

- [ ] **Step 3: Implement the non-intercepting tracking overlay**

Create `StatusDashboardController.swift` and add:

```swift
import AppKit
import SwiftUI

final class StatusItemTrackingView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
}
```

- [ ] **Step 4: Implement controller ownership and panel setup**

Add the controller with these stored properties and constants:

```swift
@MainActor
final class StatusDashboardController: NSObject {
    static let shared = StatusDashboardController(state: .shared)
    static let openDelay: TimeInterval = 0.15
    static let closeDelay: TimeInterval = 0.35

    let model = PanelModel()
    private let state: AppState
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = IrisPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private var presentation = StatusDashboardPresentation()
    private var openWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?
    private var monitors: [Any] = []

    private init(state: AppState) {
        self.state = state
        super.init()
        configureStatusItem()
        configurePanel()
        installMonitors()
    }
}
```

Configure the button with `eye.fill`, `image?.isTemplate = true`, accessibility
label “Iris”, target/action, and a `StatusItemTrackingView` constrained to its
bounds. Configure the panel with clear background, status-bar level, shadow,
all-spaces/fullscreen behavior, and an `NSHostingView` containing
`StatusDashboardView(state:model:)`.

- [ ] **Step 5: Implement hover scheduling and presentation synchronization**

Use one method as the only bridge from reducer state to AppKit state:

```swift
private func renderPresentation() {
    model.isExpanded = presentation.isOpen
    model.isPinned = presentation.isPinned
    if presentation.isOpen {
        positionPanel()
        panel.orderFrontRegardless()
        state.music.startPolling()
    } else {
        model.showSettings = false
        panel.orderOut(nil)
    }
}
```

On status enter, cancel close work, apply `.statusPointerChanged(true)`, and
schedule `.openDelayElapsed` after `openDelay`. On either exit, update the pointer
flag and schedule `.closeDelayElapsed` after `closeDelay`. Panel enter cancels the
close work. The button action applies `.statusClicked` and immediately renders.

Position the panel from the button’s screen rect:

```swift
private func positionPanel() {
    let anchor = statusItem.button.flatMap { button -> NSRect? in
        guard let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }
    let screen = anchor.flatMap { rect in
        NSScreen.screens.first { $0.frame.intersects(rect) }
    } ?? NSScreen.main
    guard let visibleFrame = screen?.visibleFrame else { return }
    panel.setFrame(
        StatusDashboardGeometry.frame(anchor: anchor, visibleFrame: visibleFrame),
        display: false
    )
}
```

- [ ] **Step 6: Preserve right-click utility actions**

Configure the status button to receive left and right mouse-up events. For a right
click, show an `NSMenu` containing:

```swift
NSMenuItem(title: "Take a Break Now", action: #selector(startBreak), keyEquivalent: "")
NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
NSMenuItem.separator()
NSMenuItem(title: "Quit Iris", action: #selector(quit), keyEquivalent: "q")
```

`startBreak` calls `state.startRestNow()`. `openSettingsFromMenu` opens and pins
the status dashboard, then sets `model.showSettings = true`. `quit` calls
`NSApp.terminate(nil)`.

- [ ] **Step 7: Add outside-click, Escape, and screen-change handling**

Use global and local mouse-down monitors to apply `.outsideClicked` when the click
is outside the panel and status button. Use a local key-down monitor to apply
`.escapePressed` for key code 53. Observe
`NSApplication.didChangeScreenParametersNotification` and reposition an open
panel. Store every monitor token and remove it in `deinit`.

- [ ] **Step 8: Replace `MenuBarExtra` with the controller-backed app scene**

In `Main.swift`, replace `IrisApp.body` with:

```swift
var body: some Scene {
    Settings {
        EmptyView()
    }
}
```

In `applicationDidFinishLaunching`, retain both controllers:

```swift
_ = NotchPanelController.shared
_ = StatusDashboardController.shared
```

Keep the existing preview-launch handling after controller initialization. Delete
`MenuContent` because its utility actions now live in the right-click menu.

- [ ] **Step 9: Run timing test, full tests, and debug build**

Run:

```bash
swift test --filter IrisExperienceTests.testStatusDashboardUsesApprovedHoverTiming
swift test
swift build -c debug
```

Expected: all commands succeed with no warnings.

---

### Task 5: Full-Dashboard Exclusivity and Motion

**Files:**
- Modify: `Sources/Iris/NotchPanelController.swift`
- Modify: `Sources/Iris/StatusDashboardController.swift`
- Test: `Tests/IrisTests/IrisExperienceTests.swift`

**Interfaces:**
- Consumes: `StatusDashboardPresentation.Event.anotherDashboardOpened`.
- Produces: `StatusDashboardController.closeForAnotherDashboard()` and coordinated opening in `NotchPanelController.setExpanded`.

- [ ] **Step 1: Extend the existing reducer regression test**

The Task 2 test `testOpeningAnotherFullDashboardClosesStatusDashboard` already
proves the state transition. Run it before controller wiring:

```bash
swift test --filter IrisExperienceTests.testOpeningAnotherFullDashboardClosesStatusDashboard
```

Expected: PASS, establishing the controller contract.

- [ ] **Step 2: Add the public close method to the status controller**

```swift
func closeForAnotherDashboard() {
    openWork?.cancel()
    closeWork?.cancel()
    presentation.apply(.anotherDashboardOpened)
    renderPresentation()
}
```

At the beginning of the status controller’s transition from closed to open, call:

```swift
NotchPanelController.shared.collapseForAnotherDashboard()
```

- [ ] **Step 3: Add the complementary notch method**

In `NotchPanelController`:

```swift
func collapseForAnotherDashboard() {
    guard model.isExpanded else { return }
    setExpanded(false)
}
```

Before `setExpanded(true, ...)` positions the center panel, call:

```swift
StatusDashboardController.shared.closeForAnotherDashboard()
```

Guard the calls so closing one surface cannot recursively close the other.

- [ ] **Step 4: Respect Reduce Motion**

Read `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` when opening or
closing the status panel. With Reduce Motion off, animate opacity and a 6 pt
vertical frame shift over 180 ms. With it on, use a 100 ms opacity-only transition.
Do not animate width or height.

- [ ] **Step 5: Run tests and build**

Run:

```bash
swift test
swift build -c debug
```

Expected: the complete suite passes and both controllers compile without actor or retain-cycle warnings.

---

### Task 6: Documentation, Packaging, and Live Verification

**Files:**
- Modify: `README.md`
- Modify: `DESIGN.md`
- Verify: `build/Iris.app`

**Interfaces:**
- Consumes: completed status dashboard behavior.
- Produces: documented, signed, runnable application bundle.

- [ ] **Step 1: Update product documentation**

In `README.md`, replace the old menu-bar quick-actions description with:

```markdown
- **Upper-right dashboard** — hover the Iris menu-bar eye to open a 440 × 620 pt
  Today / Train / Progress dashboard. Click to pin; move away to dismiss; right-click
  for Take a Break, Settings, and Quit.
```

In `DESIGN.md`, add the 440 × 620 upper-right panel, 8 pt anchor gap, 12 pt screen
margin, 150 ms open delay, 350 ms close delay, and pin/outside-click behavior.

- [ ] **Step 2: Run the full automated verification gate**

Run:

```bash
swift test
swift build -c debug
./scripts/bundle.sh
plutil -lint build/Iris.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 build/Iris.app
```

Expected: all tests pass, both builds succeed, plist is `OK`, and code signing is valid.

- [ ] **Step 3: Relaunch the packaged app**

Run:

```bash
pkill -x Iris 2>/dev/null || true
open build/Iris.app
```

Expected: one Iris process runs from `build/Iris.app/Contents/MacOS/Iris`.

- [ ] **Step 4: Verify the live upper-right interaction**

On the current 1728 × 1117 Retina display:

1. Hover the Iris status icon and confirm opening occurs after approximately 150 ms.
2. Confirm the panel is 440 × 620 pt and right-aligned beneath the icon.
3. Move between the icon and panel and confirm it stays open.
4. Leave both and confirm it closes after approximately 350 ms.
5. Click to pin, click outside to dismiss, then repeat and press Escape.
6. Open Today, Train, Progress, and Settings and confirm content uses the larger viewport.
7. Right-click the icon and run no destructive command; verify Take a Break Now, Settings, and Quit Iris are present.
8. Confirm the center compact notch pill remains correctly fitted.

- [ ] **Step 5: Scan for stale menu implementation**

Run:

```bash
rg -n 'MenuBarExtra|MenuContent|frame\(width: 200\)' Sources README.md DESIGN.md
```

Expected: no matches.

- [ ] **Step 6: Preserve final workspace state**

Because the project is not a Git repository, leave the verified source and bundle
in place and report the exact test count, release result, signing result, and
artifact path.
