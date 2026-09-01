# Iris 👁

Eye care in your menu bar. A small animated eye blinks beside your clock, times
your breaks, and walks your eyes through real training drills — so long days at
the desk stop ending in strain.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![Sandboxed](https://img.shields.io/badge/App%20Sandbox-on-3E9B4F) ![Tests](https://img.shields.io/badge/tests-27%20passing-B7F77A)

**Landing page:** `website/index.html` — self-contained (no build step, no
dependencies), with live canvas ports of the menu-bar eye and the exercise
trainer.

## Features

- **The living eye** — the menu-bar icon is the app's voice: calm blinks while
  you work, quick blinks when a break is coming, a tired half-closed gaze when
  a break is due, and a closed lid counting down your rest seconds.
- **20-20-20 breaks, your rhythm** — Balanced, Gentle, Classic presets or any
  custom interval. Full-screen breaks dim everything with a draining countdown
  ring; skip is always one click away.
- **Full-screen Focus Mode** — one click dims the display and plays a guided
  drill large: twelve animated exercises (figure eights, zigzags, sweeps,
  spirals, near-and-far focusing, saccades…), auto-advancing steps, ←/→ to
  switch, space to pause, Esc to leave.
- **Breaks that notice you** — if you've stepped away for 90+ seconds, Iris
  reschedules quietly instead of interrupting; after a Mac wake it gives you
  five minutes before the first takeover.
- **Honest progress** — a seven-day activity chart built only from what you
  actually complete (persisted daily history), with truthful empty states.
- **Music transport** — the current Apple Music track with play/pause/skip in
  the dashboard and inside Focus Mode (standard Automation consent).
- **Sky, on schedule** — live weather for your city (Open-Meteo, host-allow
  listed, no key) and tonight's moon phase, computed on-device.
- **Notch pill (optional)** — on notched MacBooks, a compact status pill hangs
  from the notch: countdown, progress ring, unread-alert badge. Off by default;
  the menu-bar eye is the primary surface.
- **First-run welcome** — a four-step window that teaches the eye's language,
  picks your rhythm, and primes the one permission Iris can ask for.
- **Private by design** — App Sandbox, no account, no analytics, no tracking.
  The only outbound requests are to Open-Meteo's weather API.

## The eye's language

| State | What the eye does |
|---|---|
| Calm | Open, natural blinks — everything is fine |
| Quick blinks | A break is coming in under two minutes |
| Tired gaze | A break is due — half-closed and pulsing, with an unread badge |
| Closed + countdown | A rest is running, seconds left in the menu bar |

## Build & run

```bash
./scripts/bundle.sh        # swift build -c release → build/Iris.app
open build/Iris.app
```

Or open `Iris.xcodeproj` in Xcode (⌘R). Tests: `swift test`.

## Store

TestFlight: build 1.0.0(1) is uploaded and **Ready to Submit** — see
[`SHIP.md`](SHIP.md) for the upload pipeline and public-link steps.

## License

© 2026 Bashar Louzon. All rights reserved.
