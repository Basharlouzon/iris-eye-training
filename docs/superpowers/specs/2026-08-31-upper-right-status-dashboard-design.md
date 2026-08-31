# Iris Upper-Right Status Dashboard Design

Date: 2026-08-31

## Summary

Replace the current small, click-only SwiftUI `MenuBarExtra` window with a custom
macOS status item and a large borderless dashboard panel. The panel opens beneath
the Iris eye icon on the upper-right side of the active display and reuses the
existing Today, Train, Progress, and Settings experience.

The center notch pill remains the glanceable reminder surface. The upper-right
dashboard becomes the primary menu-bar interaction surface.

## Goals

- Open a polished 440 × 620 pt Iris dashboard when the pointer rests over the
  menu-bar eye icon.
- Anchor the dashboard beneath the icon and align it to the upper-right without
  allowing it to leave the visible screen.
- Preserve the dashboard while the pointer moves between the status icon and the
  panel.
- Support click-to-pin, outside-click dismissal, and a short hover-exit grace
  period.
- Reuse the existing Today, Train, Progress, and Settings views and shared app
  data rather than introducing a duplicate menu experience.
- Keep the center notch pill compact and operational.

## Non-goals

- Reproducing CleanMyMac’s colors, branding, system-health content, or exact
  visual styling.
- Adding system-cleaning, CPU, disk, memory, or network features.
- Changing Iris monetization or adding a paywall.
- Replacing the center notch pill with the status dashboard.
- Supporting multiple full Iris dashboards at the same time.

## User Experience

### Hover opening

Hovering the Iris menu-bar icon for 150 ms opens the dashboard beneath the icon.
The delay prevents accidental openings while the pointer crosses the menu bar.

The dashboard remains visible while the pointer is over either the status item or
the dashboard. Leaving both starts a 350 ms close delay, allowing the pointer to
cross the small gap between them without flicker.

### Pinning and dismissal

Clicking the status icon toggles a pinned state:

- Clicking while closed opens and pins the dashboard.
- Clicking while open and unpinned pins it.
- Clicking while open and pinned closes it.

An unpinned dashboard closes after the hover-exit delay. A pinned dashboard closes
when the user clicks outside it, presses Escape, clicks the status icon again, or
opens the center full dashboard.

Right-clicking the status icon opens a compact native utility menu containing Take
a Break Now, Settings, and Quit Iris. This preserves the essential commands from
the removed `MenuBarExtra` without competing with the dashboard interaction.

### Relationship to the notch pill

The center notch pill stays visible and continues to communicate the next break,
an active reset, and completion. Opening a full dashboard from either surface
closes the other full dashboard first, preventing duplicate panels.

## Visual Design

### Panel

- Size: 440 × 620 pt.
- Position: 8 pt below the status-item button, right-aligned to the button’s right
  edge, then clamped to the active screen’s visible frame with a 12 pt margin.
- Shape: 24 pt continuous corner radius.
- Background: `Theme.panel`.
- Edge treatment: low-opacity white ring plus a deep, soft black shadow.
- Content inset: 24 pt.
- No arrow, title-bar chrome, traffic lights, or resize controls.

### Content

The panel reuses the Iris header, Today / Train / Progress navigation, scrollable
content, free-core footer, and Settings overlay. Unlike the center notch panel, it
has no hardware-notch spacer. The additional height gives Train and Progress a
more comfortable viewport while keeping Today visible without unnecessary
scrolling.

The menu-bar dashboard maintains the current dark neutral palette with orange,
restorative green, and progress violet accents. It does not copy the reference
image’s purple gradient or unrelated health cards.

### Status icon

The status item uses the existing `eye.fill` SF Symbol as a template image so it
adapts to light and dark menu bars. Its button retains a standard macOS status-item
hit area and exposes an accessibility label of “Iris”.

## Architecture

### `StatusDashboardController`

A new `@MainActor` controller owns:

- One `NSStatusItem`.
- One borderless, non-activating `NSPanel`.
- A dedicated `PanelModel` for tab selection, settings presentation, and panel
  state.
- Hover-open and hover-close work items.
- Local and global event monitors for Escape and outside clicks.

The controller is created by `AppDelegate` at launch and retained for the lifetime
of the application.

### Status-item tracking

An `NSView` tracking overlay is installed in the status button. It reports
`mouseEntered` and `mouseExited` without replacing the button’s standard drawing
or accessibility behavior. The button action handles pin toggling.

### Dashboard view extraction

The reusable Today / Train / Progress shell moves from the center-panel-only
`ExpandedView` into an `IrisDashboardView`. It accepts:

- `AppState` for shared app data.
- `PanelModel` for navigation and settings state.
- A top inset, which is the hardware-notch height for the center panel and zero
  for the status dashboard.
- A presentation context identifying center-notch or upper-right usage.

The context controls only shell geometry and dismissal affordances. Feature views
continue to use the same models and services.

### Coordination

`NotchPanelController` and `StatusDashboardController` coordinate through narrow
public methods:

- Opening the upper-right dashboard collapses the center full panel.
- Expanding the center full panel closes the upper-right dashboard.
- Compact notch display remains visible when no full dashboard is open.

No controller owns or copies app content data. `AppState.shared` remains the single
source for reminders, exercises, statistics, weather, and Music state.

## Geometry

Panel placement is calculated by a pure `StatusDashboardGeometry` type:

1. Convert the status button bounds into screen coordinates.
2. Select the screen containing the status button.
3. Right-align the panel to the status button.
4. Place the panel 8 pt below the button.
5. Clamp horizontal placement to the visible screen with 12 pt margins.
6. Clamp vertical placement so the complete 620 pt panel remains visible.

Geometry is recalculated whenever the screen configuration changes or immediately
before the panel opens.

## Interaction State

A pure `StatusDashboardPresentation` reducer models whether the panel should remain
open from these inputs:

- Pointer over status item.
- Pointer over panel.
- Pinned state.
- Outside click.
- Escape key.

Timers delay the delivery of hover-enter and hover-exit events; they do not own
business state. Every new pointer event cancels obsolete work before scheduling a
replacement.

## Accessibility and Input

- Status icon accessibility label: “Iris”.
- Right-click provides native keyboard-accessible utility commands for Take a
  Break Now, Settings, and Quit Iris.
- Dashboard tabs, Settings, and actions retain their current SwiftUI labels.
- Escape closes the upper-right dashboard.
- Keyboard focus is accepted only after an explicit click; hover opening does not
  steal focus from the active application.
- Reduce Motion replaces panel slide/scale motion with a short opacity transition.
- All interactive targets remain at least the macOS standard control size.

## Failure Handling

- If status-button screen coordinates are unavailable, placement falls back to the
  upper-right corner of the main screen’s visible frame.
- If the target screen is smaller than 440 × 620 pt, the panel is clamped and its
  content remains scrollable.
- Event monitors are removed when the controller is deinitialized.
- Repeated hover events are idempotent and cannot create additional panels.

## Testing

### Unit tests

- Right-aligns the 440 × 620 panel beneath the status-item anchor.
- Clamps the panel within left, right, top, and bottom visible-screen margins.
- Hover over either surface keeps an unpinned panel open.
- Leaving both surfaces closes an unpinned panel.
- A pinned panel remains open after hover exit.
- Outside click and Escape close a pinned panel.
- Only one full dashboard is presented at a time.

### Integration verification

- Build and launch on the current 1728 × 1117 Retina display.
- Verify hover opening from the upper-right status icon.
- Move the pointer from the icon into the panel without flicker.
- Verify click-to-pin, outside-click close, and Escape close.
- Verify Today, Train, Progress, and Settings at 440 × 620 pt.
- Confirm the center compact pill still fits its 26 pt hardware-notch lip.

## Acceptance Criteria

- Hovering the upper-right Iris status icon opens a 440 × 620 dashboard within
  150–250 ms.
- The dashboard is right-aligned beneath the icon and fully visible on the active
  screen.
- The pointer can cross from the icon to the panel without dismissal.
- Click pinning, outside-click dismissal, and Escape behave consistently.
- Right-click exposes Take a Break Now, Settings, and Quit Iris.
- Today, Train, Progress, and Settings use the same live state as the notch surface.
- The old 200 pt `MenuContent` window is removed.
- All tests, release packaging, plist validation, and code-sign verification pass.
