# Iris Approved Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved Figma showcase as the native macOS SwiftUI notch app while preserving the existing break scheduler, exercises, weather, Music integration, and menu-bar behavior.

**Architecture:** Add a small pure experience model for compact state, onboarding, routines, and derived progress so behavior can be tested without rendering SwiftUI. Build token-driven reusable SwiftUI components, then compose the 211×58 compact pill and 404×540 expanded Today/Train/Progress panels around the existing services.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Combine, Swift Package Manager, XCTest, macOS 13+

**Spec:** Figma file `ShS6XWT1oh7JVfR3wqpGAL`, showcase node `20:2`; product decisions captured on Figma nodes `25:211` and `26:2`.

## Global Constraints

- Preserve the existing macOS 13 deployment floor and menu-bar-only `LSUIElement` application behavior.
- Expanded panel is exactly 404×540 pt; compact non-notch pill targets 211×58 pt.
- Core product remains free; no paywall or entitlement code.
- Activity adaptation remains on-device; Calendar and Focus settings are optional and off by default.
- Reuse `BreakScheduler`, `WeatherService`, `MusicService`, `ExerciseSession`, and `Exercise.catalog`.
- Keep all network requests behind the existing `NetworkGuard`.

---

### Task 1: Testable Experience State

**Files:**
- Modify: `Package.swift`
- Create: `Tests/IrisTests/IrisExperienceTests.swift`
- Create: `Sources/Iris/IrisExperience.swift`

**Interfaces:**
- Produces: `IrisTab`, `CompactPresentation`, `RoutinePreset`, `OnboardingStep`, and `ProgressSnapshot`.
- Consumed by: compact pill, onboarding flow, root tab shell, Today and Progress views.

- [ ] **Step 1: Add the XCTest target and write failing behavioral tests**

```swift
@testable import Iris
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
        XCTAssertEqual(
            CompactPresentation.resolve(
                restSecondsLeft: nil,
                unreadBreaks: 1,
                nextBreakInterval: 300,
                completedMessage: nil
            ),
            .breakDue
        )
    }

    func testBalancedRoutineUsesApprovedTiming() {
        XCTAssertEqual(RoutinePreset.balanced.focusMinutes, 45)
        XCTAssertEqual(RoutinePreset.balanced.restSeconds, 60)
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
}
```

- [ ] **Step 2: Run the tests and verify RED**

Run: `swift test --filter IrisExperienceTests`

Expected: compilation fails because `CompactPresentation`, `RoutinePreset`, `OnboardingStep`, and `ProgressSnapshot` do not exist.

- [ ] **Step 3: Implement the minimum pure state**

```swift
import Foundation

enum IrisTab: String, CaseIterable, Identifiable {
    case today, train, progress
    var id: Self { self }
}

enum CompactPresentation: Equatable {
    case resting
    case breakDue
    case active(secondsLeft: Int)
    case complete
    case focus(secondsLeft: Int)

    static func resolve(
        restSecondsLeft: Int?,
        unreadBreaks: Int,
        nextBreakInterval: TimeInterval?,
        completedMessage: String?
    ) -> Self {
        if let restSecondsLeft { return .active(secondsLeft: restSecondsLeft) }
        if completedMessage != nil { return .complete }
        if unreadBreaks > 0 || (nextBreakInterval ?? 1) <= 0 { return .breakDue }
        if let nextBreakInterval {
            return .focus(secondsLeft: max(0, Int(nextBreakInterval.rounded())))
        }
        return .resting
    }
}

struct RoutinePreset: Identifiable, Equatable {
    let id: String
    let title: String
    let focusMinutes: Int
    let restSeconds: Int

    static let balanced = Self(id: "balanced", title: "Balanced", focusMinutes: 45, restSeconds: 60)
    static let gentle = Self(id: "gentle", title: "Gentle", focusMinutes: 60, restSeconds: 45)
    static let classic = Self(id: "classic", title: "Classic 20–20–20", focusMinutes: 20, restSeconds: 20)
    static let all = [balanced, gentle, classic]
}

enum OnboardingStep: Int, CaseIterable {
    case promise, routine, privacy
    var next: Self? { Self(rawValue: rawValue + 1) }
}

struct ProgressSnapshot: Equatable {
    let breaks: Int
    let exercises: Int
    var comfortScore: Int { min(100, 64 + breaks * 4 + exercises * 3) }
    var resetRate: Int { min(100, breaks * 12) }
}
```

- [ ] **Step 4: Run tests and verify GREEN**

Run: `swift test --filter IrisExperienceTests`

Expected: 5 tests pass, 0 failures.

---

### Task 2: Figma Token System and Reusable Components

**Files:**
- Modify: `Sources/Iris/Theme.swift`
- Create: `Sources/Iris/IrisComponents.swift`

**Interfaces:**
- Consumes: exact Figma semantic colors and 8/12/16/24 spacing rhythm.
- Produces: `IrisActionButtonStyle`, `IrisStatusChip`, `IrisSurfaceCard`, `IrisMetricTile`, `IrisExerciseRow`, and `IrisPanelHeader`.

- [ ] **Step 1: Replace legacy theme values with approved semantic tokens**

Use exact colors: panel `#080A08`, surface `#101310`, elevated `#151915`, strong `#1C211C`, accent `#FF9238`, restorative `#B7F77A`, progress `#A98BFF`, primary text `#E9ECE6`, secondary `#9CA39A`, tertiary `#70786E`.

- [ ] **Step 2: Implement component primitives as small SwiftUI views**

Each component accepts semantic state and content rather than reading `AppState` directly. Buttons use `.buttonStyle(.plain)`; settings switches remain native `Toggle` controls.

- [ ] **Step 3: Compile the component layer**

Run: `swift build -c debug`

Expected: build succeeds with no compiler errors.

---

### Task 3: Compact Pill, Panel Shell, and Onboarding

**Files:**
- Modify: `Sources/Iris/RootView.swift`
- Modify: `Sources/Iris/NotchPanelController.swift`
- Modify: `Sources/Iris/Theme.swift`
- Create: `Sources/Iris/OnboardingView.swift`

**Interfaces:**
- Consumes: `CompactPresentation.resolve`, `IrisTab`, `RoutinePreset`, `OnboardingStep`.
- Produces: approved compact states, 404×540 shared shell, three-step onboarding.

- [ ] **Step 1: Update geometry**

Set `expandedHeight = 540`, `floatingPillHeight = 58`, and floating width to 211 while retaining notch-aware placement.

- [ ] **Step 2: Implement the compact state presentation**

Map active rest to restorative countdown, unread alert to “Look away”, scheduled work to focus countdown, completion flash to “Nice work”, and no schedule to “Comfort is steady”.

- [ ] **Step 3: Implement the expanded header and text navigation**

Use Today, Train, and Progress labels with one selected state, the private/on-device label, settings access, and free/optional-context footer.

- [ ] **Step 4: Implement onboarding**

Promise → routine selection → privacy. Persist completion in `SettingsKeys.hasOnboarded`; selecting a routine writes `SettingsKeys.breakInterval` and reschedules the scheduler.

- [ ] **Step 5: Verify**

Run: `swift test && swift build -c debug`

Expected: tests pass and the application target builds.

---

### Task 4: Today, Train, and Progress Screens

**Files:**
- Replace: `Sources/Iris/HomeTab.swift`
- Replace the view layer in: `Sources/Iris/ExercisesTab.swift` while preserving `Exercise`, `ExercisePath`, and `ExerciseSession`
- Create: `Sources/Iris/ProgressTab.swift`
- Modify: `Sources/Iris/MusicTab.swift`
- Modify: `Sources/Iris/RootView.swift`

**Interfaces:**
- Today consumes `AppState`, `WeatherService`, and `MusicService`.
- Train consumes `Exercise.catalog` and `ExerciseSession`.
- Progress consumes `ProgressSnapshot`.

- [ ] **Step 1: Build Today**

Show the next restorative action, live break/exercise metrics, weather context, and current Music context. The primary button invokes `state.startRest()`.

- [ ] **Step 2: Build Train**

Show four routine rows with available/current/complete language. Selecting an available exercise calls `session.select`; the primary action starts or stops the existing session timer.

- [ ] **Step 3: Build Progress**

Show comfort score, reset rate, weekly insight copy, and the seven-bar rhythm visualization from the approved frame.

- [ ] **Step 4: Integrate navigation**

Switch the expanded shell between the three views without recreating service objects.

- [ ] **Step 5: Verify**

Run: `swift test && swift build -c debug`

Expected: all tests pass and all three tabs compile.

---

### Task 5: Settings, Optional Context, and Handoff

**Files:**
- Modify: `Sources/Iris/Theme.swift`
- Replace: `Sources/Iris/SettingsSheet.swift`
- Modify: `Sources/Iris/AppState.swift`
- Modify: `README.md`

**Interfaces:**
- Produces settings keys for adaptive timing, Calendar context, Focus mode, Music support, and onboarding completion.
- Calendar and Focus toggles persist locally but do not request permissions or alter scheduling in this milestone.

- [ ] **Step 1: Add settings keys and native toggles**

Use approved labels and defaults: adaptive timing on; Calendar off; Focus off; Music support on.

- [ ] **Step 2: Keep current operational settings**

Retain break interval, sounds, weather units/city, and launch-at-login controls beneath the product settings.

- [ ] **Step 3: Update documentation**

Document the approved free-first product structure, new tabs, 540 pt panel, and optional-context status.

- [ ] **Step 4: Build and bundle**

Run: `swift test`, `swift build -c release`, and `./scripts/bundle.sh`.

Expected: all tests pass, release build exits 0, and `build/Iris.app` is produced and codesigned.

- [ ] **Step 5: Visual smoke test**

Open the built application, capture the expanded panel, compare it with Figma node `20:2`, and correct any visible spacing, clipping, or contrast regressions before completion.

