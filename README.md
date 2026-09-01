# Iris — calmer eyes for deep work

Iris is a private, free-first macOS eye-comfort companion that lives beneath the
MacBook notch, or in a floating top-center pill on other displays. It turns break
reminders, short eye-movement routines, and lightweight context into one calm daily
rhythm.

The current implementation follows the approved Figma showcase in
[`ShS6XWT1oh7JVfR3wqpGAL`](https://www.figma.com/design/ShS6XWT1oh7JVfR3wqpGAL/IRIS-app?node-id=20-2).

## Product experience

- **Compact Iris** — a 211 × 58 pt glanceable state for focus countdowns, due
  breaks, active resets, and completion feedback.
- **Upper-right dashboard** — hover the Iris menu-bar eye to open a 440 × 620 pt
  Today / Train / Progress dashboard. Click to pin; move away to dismiss;
  right-click for Take a Break, Settings, and Quit.
- **Today** — a single recommended action, comfort score, focus and distance-break
  metrics, plus optional weather and Music context.
- **Train** — an approved four-step, four-minute routine powered by the existing
  animated exercise engine. The complete 12-exercise catalog remains available to
  quick actions and the underlying app.
- **Progress** — comfort score, reset rate, weekly insight, and a low-pressure rhythm
  chart.
- **Onboarding** — promise, routine choice, and privacy confirmation. Balanced,
  Gentle, and Classic 20–20–20 routines are included.
- **Settings** — , break behavior, optional Calendar/Focus/Music
  context, weather, units, launch at login, and an onboarding reset.
- **Private by default** — the core routine and progress state stay on-device.

All core features are currently free. Calendar and Focus context are optional and
off by default; there is no paywall in this build.

## Build and run

Requires Xcode or a Swift toolchain capable of building the macOS 13 target.

```bash
swift test
./scripts/bundle.sh
open build/Iris.app
```

The app is menu-bar-only (`LSUIElement`). Music controls may trigger the standard
macOS Automation permission prompt. Weather uses Open-Meteo and requires network
access to its API and geocoding hosts.

## Project map

```text
Sources/Iris/
  Main.swift                  App entry and controller startup
  AppState.swift              reminders, stats, rest timer, shared services
  IrisExperience.swift        testable navigation, routine, compact, progress state
  Theme.swift                 approved semantic color tokens
  IrisComponents.swift        reusable buttons, chips, cards, metrics, rows, header
  NotchPanelController.swift  211 × 58 compact / 404 × 540 expanded NSPanel
  StatusDashboardController.swift  upper-right status item, hover panel, input
  StatusDashboardGeometry.swift    screen-aware status-panel placement
  StatusDashboardPresentation.swift hover, pin, and dismissal state
  StatusDashboardView.swift        440 × 620 upper-right dashboard surface
  RootView.swift              compact state, tab shell, settings presentation
  OnboardingView.swift        three-step first-run experience
  HomeTab.swift               Today dashboard
  TrainTab.swift              four-step guided reset
  ProgressTab.swift           comfort trends and insight
  ExercisesTab.swift          full catalog, path math, session model, canvas engine
  SettingsSheet.swift         free-first settings and optional context
  WeatherService.swift        guarded Open-Meteo client
  MusicService.swift          Music app integration
Tests/IrisTests/
  IrisExperienceTests.swift   compact, routine, onboarding, progress, default tests
scripts/
  bundle.sh                   release build, app assembly, ad-hoc signing
DESIGN.md                     approved implementation tokens and frame map
```

## Window behavior

Notch geometry uses `NSScreen.auxiliaryTopLeftArea` and
`auxiliaryTopRightArea`. The upper-right dashboard is right-aligned beneath the
status icon, clamped to the active display, and preserves a 350 ms bridge while
the pointer crosses from the icon into the panel. Both non-activating panels stay
at status-bar level and join all spaces; only one full dashboard opens at a time.
