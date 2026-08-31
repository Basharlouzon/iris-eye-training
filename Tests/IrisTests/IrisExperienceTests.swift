@testable import Iris
import AppKit
import XCTest

final class IrisExperienceTests: XCTestCase {
    func testCompactPresentationPrioritizesActiveBreakOverUnreadPrompt() {
        let result = CompactPresentation.resolve(
            restSecondsLeft: 42,
            unreadBreaks: 2,
            nextBreakInterval: 1_200,
            completedMessage: nil
        )

        XCTAssertEqual(result, .active(secondsLeft: 42))
    }

    func testCompactPresentationShowsDuePromptWhenUnreadBreakExists() {
        let result = CompactPresentation.resolve(
            restSecondsLeft: nil,
            unreadBreaks: 1,
            nextBreakInterval: 300,
            completedMessage: nil
        )

        XCTAssertEqual(result, .breakDue)
    }

    func testBalancedRoutineUsesApprovedTiming() {
        XCTAssertEqual(RoutinePreset.balanced.focusMinutes, 45)
        XCTAssertEqual(RoutinePreset.balanced.restSeconds, 60)
    }

    func testRoutineResolutionUsesStoredIDAndFallsBackToBalanced() {
        XCTAssertEqual(RoutinePreset.resolve(id: "gentle"), .gentle)
        XCTAssertEqual(RoutinePreset.resolve(id: "missing"), .balanced)
    }

    func testOnboardingAdvancesThroughAllThreeApprovedSteps() {
        XCTAssertEqual(OnboardingStep.promise.next, .routine)
        XCTAssertEqual(OnboardingStep.routine.next, .privacy)
        XCTAssertNil(OnboardingStep.privacy.next)
    }

    func testProgressSnapshotClampsComfortScore() {
        XCTAssertEqual(ProgressSnapshot(breaks: 40, exercises: 40).comfortScore, 100)
        XCTAssertEqual(ProgressSnapshot(breaks: 0, exercises: 0).comfortScore, 64)
    }

    func testProgressSnapshotReportsOnlyCompletedActions() {
        let snapshot = ProgressSnapshot(breaks: 2, exercises: 3)

        XCTAssertEqual(snapshot.completedActions, 5)
        XCTAssertEqual(snapshot.activitySummary, "2 breaks • 3 exercises")
    }

    func testTrainingRoutineUsesFourApprovedSteps() {
        XCTAssertEqual(TrainingRoutine.approved.stepIDs, ["fig8", "infinity", "zigzag", "diagonals"])
        XCTAssertEqual(TrainingRoutine.approved.totalMinutes, 4)
    }

    func testFreeFirstDefaultsKeepOptionalContextOff() {
        XCTAssertTrue(IrisFeatureDefaults.adaptiveTiming)
        XCTAssertTrue(IrisFeatureDefaults.musicSupport)
        XCTAssertFalse(IrisFeatureDefaults.calendarContext)
        XCTAssertFalse(IrisFeatureDefaults.focusContext)
    }

    func testNotchedCompactLayoutFitsTheAvailableLip() {
        let layout = CompactLayoutStyle.resolve(hasNotch: true)

        XCTAssertFalse(layout.showsDetailLine)
        XCTAssertLessThanOrEqual(layout.requiredHeight, 26)
    }

    func testFloatingCompactLayoutKeepsTheGlanceableDetail() {
        let layout = CompactLayoutStyle.resolve(hasNotch: false)

        XCTAssertTrue(layout.showsDetailLine)
        XCTAssertLessThanOrEqual(layout.requiredHeight, 58)
    }

    func testTodaySnapshotDoesNotInventFocusActivity() {
        let snapshot = TodaySnapshot(breaks: 0, exercises: 0, focusMinutesPerBlock: 45)

        XCTAssertEqual(snapshot.completedFocusBlocks, 0)
        XCTAssertEqual(snapshot.focusMinutes, 0)
        XCTAssertEqual(snapshot.distanceBreakSummary, "No resets yet")
    }

    func testTodaySnapshotUsesOnlyCompletedBreaksForFocusTotals() {
        let snapshot = TodaySnapshot(breaks: 2, exercises: 1, focusMinutesPerBlock: 45)

        XCTAssertEqual(snapshot.completedFocusBlocks, 2)
        XCTAssertEqual(snapshot.focusMinutes, 90)
        XCTAssertEqual(snapshot.distanceBreakSummary, "2 resets completed")
    }

    func testApprovedTodayLayoutFitsTheExpandedContentBudget() {
        XCTAssertLessThanOrEqual(TodayLayoutMetrics.approved.totalHeight, 421)
    }

    func testPreviewLaunchArgumentSelectsTheRequestedTab() {
        let configuration = IrisLaunchConfiguration(
            arguments: ["Iris", "--iris-preview=progress"]
        )

        XCTAssertEqual(configuration.previewTab, .progress)
        XCTAssertNil(IrisLaunchConfiguration(arguments: ["Iris"]).previewTab)
    }

    func testStatusDashboardPreviewLaunchArgumentSelectsTheUpperRightSurface() {
        let configuration = IrisLaunchConfiguration(
            arguments: [
                "Iris",
                "--iris-preview=today",
                "--iris-preview-status-dashboard",
                "--iris-preview-settings"
            ]
        )

        XCTAssertTrue(configuration.previewsStatusDashboard)
        XCTAssertTrue(configuration.previewsSettings)
        XCTAssertFalse(IrisLaunchConfiguration(arguments: ["Iris"]).previewsStatusDashboard)
        XCTAssertFalse(IrisLaunchConfiguration(arguments: ["Iris"]).previewsSettings)
    }

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

    func testDashboardPresentationInsetsMatchTheirSurface() {
        XCTAssertEqual(DashboardPlacement.notch(topInset: 32).topInset, 32)
        XCTAssertEqual(DashboardPlacement.statusItem.topInset, 0)
    }

    func testStatusDashboardUsesApprovedHoverTiming() {
        XCTAssertEqual(StatusDashboardController.openDelay, 0.15)
        XCTAssertEqual(StatusDashboardController.closeDelay, 0.35)
    }
}
