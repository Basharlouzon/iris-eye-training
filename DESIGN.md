# Iris — approved implementation spec

Source of truth: [Figma showcase, node 20:2](https://www.figma.com/design/ShS6XWT1oh7JVfR3wqpGAL/IRIS-app?node-id=20-2).

The app is a native SwiftUI interpretation of the approved showcase. System text,
controls, shapes, accessibility, and the working exercise canvas remain native.

## Frame system

| State | Size | Notes |
|---|---:|---|
| Floating compact | 211 × 58 pt | Top-center pill on displays without a notch |
| Notch compact | notch width + 26 pt | Hardware notch plus a glanceable lower lip |
| Center expanded | 404 × 540 pt | Today / Train / Progress shell beneath the notch |
| Upper-right dashboard | 440 × 620 pt | Right-aligned beneath the Iris status icon |

Expanded panels use a 28 pt lower radius, a dark hairline, and a deep soft shadow.
Content begins after the measured hardware-notch inset.

## Semantic tokens

| Token | Value | Use |
|---|---|---|
| Canvas | `#050605` | surrounding desktop treatment |
| Panel | `#080A08` | main shell |
| Surface | `#101310` | cards and inactive tabs |
| Surface elevated | `#151915` | coach and emphasized cards |
| Surface strong | `#1C211C` | selected and active surfaces |
| Iris orange | `#FF9238` | actions, daily state, active training |
| Restorative green | `#B7F77A` | breaks, privacy, positive health state |
| Progress violet | `#A98BFF` | progress metrics and insight |
| Text primary | `#E9ECE6` | primary content |
| Text secondary | `#9CA39A` | supporting content |
| Text tertiary | `#70786E` | labels and metadata |

Typography uses the macOS system face: rounded design for product titles and
numbers, monospaced design for timers. Labels are 8–9 pt with modest tracking;
body text is 10–11 pt; section titles are 15 pt; the brand and settings title are
20 pt.

## Approved experience map

### Compact

Compact Iris resolves one state at a time in this priority order: active distance
reset, completion, due break, focus countdown, resting. Each state has a distinct
signal color, title, and short supporting line.

### Onboarding

1. **Promise** — explains the calm, proactive benefit.
2. **Routine** — Balanced 45m/60s, Gentle 60m/45s, or Classic 20m/20s.
3. **Privacy** — confirms local-first behavior and optional context.

### Today

The header shows greeting and comfort score. The coach card owns the primary action.
Two metrics show focus blocks and distance breaks. Weather and Music are secondary,
optional context cards.

### Train

The daily routine contains Figure 8, Infinity, Zigzag, and Diagonals. Each step is
60 seconds. Rows communicate Ready, Now, and Done. The current step includes a live
native canvas preview and one clear Start/Stop action.

### Progress

Two top metrics show comfort score and reset rate. A weekly insight explains the
pattern in plain language. A seven-day chart uses violet only for the current day.

### Settings

Settings are grouped into rhythm, comfort intelligence, optional context, and Mac
preferences. Calendar and Focus context are off by default; Music support and
adaptive timing are on. All core features are labeled free in this build.

## Motion and behavior

- The upper-right dashboard opens after a 150 ms icon hover, sits 8 pt below its
  anchor, and stays inside the active screen with a 12 pt visible-frame margin.
- Crossing between the icon and dashboard keeps it open; leaving both starts a
  350 ms dismissal delay.
- Clicking the status icon pins or closes the dashboard. Outside click and Escape
  dismiss it; right-click exposes Take a Break, Settings, and Quit.
- Center-notch hover expansion waits 120 ms; unpinned dismissal waits 350 ms.
- Shell content uses a 0.35 s spring; panel geometry uses a 0.38 s eased animation.
- Upper-right panel motion uses a short 180 ms opacity/vertical transition, or a
  100 ms opacity-only transition when Reduce Motion is enabled.
- Exercise motion is driven by `TimelineView` and `Canvas` at display cadence.
- Progress is framed as supportive feedback, not a streak punishment system.
