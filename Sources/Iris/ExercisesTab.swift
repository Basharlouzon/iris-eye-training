import SwiftUI

// MARK: - Exercise catalog
// Parity with the web app's Exercise library: 11 path types + Infinity
// (the second step of the approved 4-step routine).

struct Exercise: Identifiable, Hashable {
    enum Kind {
        case lemniscateV      // standing figure 8
        case lemniscateH      // lying infinity
        case zigzag
        case diagonals
        case sweepH           // horizontal sweep
        case sweepV           // vertical sweep
        case circle
        case rect             // rectangle
        case nearfar          // near & far focus rings
        case jump             // random jump between positions
        case pulse            // static pulse
        case breathe          // breathing rings
    }

    let id: String
    let name: String
    let hint: String
    let kind: Kind

    /// First four entries are the approved routine steps (see TrainingRoutine.approved).
    static let catalog: [Exercise] = [
        Exercise(id: "fig8", name: "Figure Eight", hint: "Trace the standing loop with your eyes, then reverse.", kind: .lemniscateV),
        Exercise(id: "infinity", name: "Infinity", hint: "Sweep side to side in a lying figure 8.", kind: .lemniscateH),
        Exercise(id: "zigzag", name: "Zig-Zag", hint: "Follow the dot as it cuts down the rows.", kind: .zigzag),
        Exercise(id: "diagonals", name: "Diagonal", hint: "Corner to corner. Keep your head still.", kind: .diagonals),
        Exercise(id: "sweepH", name: "Horizontal Sweep", hint: "Track edge to edge, smooth and level.", kind: .sweepH),
        Exercise(id: "sweepV", name: "Vertical Sweep", hint: "Track floor to ceiling without moving your head.", kind: .sweepV),
        Exercise(id: "circle", name: "Circle", hint: "Ride the ellipse around without losing the dot.", kind: .circle),
        Exercise(id: "rect", name: "Rectangle", hint: "Trace the rectangle, crisp corners.", kind: .rect),
        Exercise(id: "nearfar", name: "Near & Far", hint: "Shift focus between the near and far rings.", kind: .nearfar),
        Exercise(id: "jump", name: "Random Jump", hint: "Snap your focus from marker to marker.", kind: .jump),
        Exercise(id: "pulse", name: "Static Pulse", hint: "Hold center and follow the pulse in place.", kind: .pulse),
        Exercise(id: "breathe", name: "Breathing", hint: "Blink soft and match the breathing rings.", kind: .breathe),
    ]
}

/// Pure path math: maps a phase t (0..1 loop) to a point in the canvas.
enum ExercisePath {
    static func point(_ kind: Exercise.Kind, t: Double, size: CGSize) -> CGPoint {
        let margin = marginFor(size)
        let w = max(10, size.width - margin * 2)
        let h = max(10, size.height - margin * 2)
        let cx = size.width / 2
        let cy = size.height / 2
        let u = normalized(t)
        let angle = u * 2 * .pi
        let L = margin
        let R = margin + w
        let T = margin
        let B = margin + h

        switch kind {
        case .lemniscateV:
            // Standing figure 8: x swings at double frequency, y once.
            return CGPoint(x: cx + CGFloat(sin(2 * angle)) * w * 0.24,
                           y: cy - CGFloat(cos(angle)) * h * 0.42)
        case .lemniscateH:
            // Lying infinity: x swings once, y at double frequency.
            let ax = w / 2 * 0.92
            let ay = h / 2 * 0.55
            return CGPoint(x: cx + CGFloat(cos(angle)) * ax,
                           y: cy + CGFloat(sin(angle) * cos(angle)) * ay * 2)
        case .zigzag:
            var pts: [CGPoint] = []
            let rows = 5
            for r in 0...rows {
                let y = T + h * CGFloat(r) / CGFloat(rows)
                pts.append(CGPoint(x: r % 2 == 0 ? L : R, y: y))
            }
            return polyline(pts, u: u)
        case .diagonals:
            return polyline([CGPoint(x: L, y: T), CGPoint(x: R, y: B),
                             CGPoint(x: R, y: T), CGPoint(x: L, y: B),
                             CGPoint(x: L, y: T)], u: u)
        case .sweepH:
            // Smooth ping-pong left → right → left.
            let k = 0.5 - 0.5 * cos(2 * .pi * u)
            return CGPoint(x: L + w * CGFloat(k), y: cy)
        case .sweepV:
            let k = 0.5 - 0.5 * cos(2 * .pi * u)
            return CGPoint(x: cx, y: T + h * CGFloat(k))
        case .circle:
            let a = w / 2 * 0.78
            let b = h / 2 * 0.72
            return CGPoint(x: cx + CGFloat(cos(angle)) * a,
                           y: cy + CGFloat(sin(angle)) * b)
        case .rect:
            let inset: CGFloat = 8
            return polyline([CGPoint(x: L + inset, y: T), CGPoint(x: R - inset, y: T),
                             CGPoint(x: R - inset, y: B), CGPoint(x: L + inset, y: B),
                             CGPoint(x: L + inset, y: T)], u: u)
        case .nearfar:
            let s = 0.5 - 0.5 * cos(2 * .pi * u)
            let rFar = min(w, h) * 0.42
            let rNear = min(w, h) * 0.15
            let r = rNear + (rFar - rNear) * CGFloat(s)
            return CGPoint(x: cx, y: cy - r)
        case .jump:
            let pts = jumpPositions(w: w, h: h, l: L, t: T)
            let n = pts.count
            let scaled = u * Double(n)
            let i = min(n - 1, Int(scaled))
            let local = scaled - Double(i)
            let a = pts[i]
            let b = pts[(i + 1) % n]
            if local < 0.6 { return a }
            let f = (local - 0.6) / 0.4
            let e = f * f * (3 - 2 * f) // ease the jump between dwell points
            return CGPoint(x: a.x + (b.x - a.x) * CGFloat(e),
                           y: a.y + (b.y - a.y) * CGFloat(e))
        case .pulse, .breathe:
            return CGPoint(x: cx, y: cy)
        }
    }

    static func guidePath(_ kind: Exercise.Kind, size: CGSize) -> Path {
        // Kinds with annotation-driven guides are drawn by the preview renderer.
        switch kind {
        case .nearfar, .jump, .pulse, .breathe:
            return Path()
        default:
            break
        }
        var path = Path()
        let steps = 160
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let p = point(kind, t: t, size: size)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    /// Dots marking fixed points (sweep endpoints, corners, jump positions).
    static func markerPoints(_ kind: Exercise.Kind, size: CGSize) -> [CGPoint] {
        let margin = marginFor(size)
        let w = max(10, size.width - margin * 2)
        let h = max(10, size.height - margin * 2)
        let cx = size.width / 2
        let cy = size.height / 2
        let L = margin, R = margin + w, T = margin, B = margin + h

        switch kind {
        case .sweepH:
            return [CGPoint(x: L, y: cy), CGPoint(x: R, y: cy)]
        case .sweepV:
            return [CGPoint(x: cx, y: T), CGPoint(x: cx, y: B)]
        case .rect:
            let inset: CGFloat = 8
            return [CGPoint(x: L + inset, y: T), CGPoint(x: R - inset, y: T),
                    CGPoint(x: R - inset, y: B), CGPoint(x: L + inset, y: B)]
        case .diagonals:
            return [CGPoint(x: L, y: T), CGPoint(x: R, y: B),
                    CGPoint(x: R, y: T), CGPoint(x: L, y: B)]
        case .jump:
            return jumpPositions(w: w, h: h, l: L, t: T)
        case .lemniscateV, .lemniscateH, .zigzag, .circle, .nearfar, .pulse, .breathe:
            return []
        }
    }

    /// Loop-direction arrows: (position, rotation).
    static func arrows(_ kind: Exercise.Kind, size: CGSize) -> [(CGPoint, CGFloat)] {
        let margin = marginFor(size)
        let w = max(10, size.width - margin * 2)
        let h = max(10, size.height - margin * 2)
        let cx = size.width / 2
        let cy = size.height / 2
        let L = margin, R = margin + w, T = margin, B = margin + h

        switch kind {
        case .sweepH:
            return [(CGPoint(x: R - 14, y: cy), tangentAngle(kind, u: 0.25, size: size)),
                    (CGPoint(x: L + 14, y: cy), tangentAngle(kind, u: 0.75, size: size))]
        case .sweepV:
            return [(CGPoint(x: cx, y: B - 14), tangentAngle(kind, u: 0.25, size: size)),
                    (CGPoint(x: cx, y: T + 14), tangentAngle(kind, u: 0.75, size: size))]
        case .circle:
            return [(point(kind, t: 0.75, size: size), tangentAngle(kind, u: 0.75, size: size))]
        case .lemniscateV:
            return [(point(kind, t: 0.125, size: size), tangentAngle(kind, u: 0.125, size: size))]
        case .lemniscateH:
            return [(point(kind, t: 0.125, size: size), tangentAngle(kind, u: 0.125, size: size))]
        case .rect:
            return [(point(kind, t: 0.1, size: size), tangentAngle(kind, u: 0.1, size: size))]
        case .zigzag:
            return [(point(kind, t: 0.03, size: size), tangentAngle(kind, u: 0.03, size: size))]
        case .diagonals:
            return [(point(kind, t: 0.03, size: size), tangentAngle(kind, u: 0.03, size: size))]
        case .nearfar, .jump, .pulse, .breathe:
            return []
        }
    }

    static func tangentAngle(_ kind: Exercise.Kind, u: Double, size: CGSize) -> CGFloat {
        let e = 0.002
        let a = point(kind, t: u - e, size: size)
        let b = point(kind, t: u + e, size: size)
        return atan2(b.y - a.y, b.x - a.x)
    }

    static func marginFor(_ size: CGSize) -> CGFloat {
        max(10, min(24, size.width * 0.09))
    }

    static func normalized(_ t: Double) -> Double {
        var u = t.truncatingRemainder(dividingBy: 1)
        if u < 0 { u += 1 }
        return u
    }

    private static func jumpPositions(w: CGFloat, h: CGFloat, l: CGFloat, t: CGFloat) -> [CGPoint] {
        let inset = min(w, h) * 0.10
        let cx = l + w / 2
        let cy = t + h / 2
        let B = t + h
        let R = l + w
        return [CGPoint(x: l + inset, y: t + inset),
                CGPoint(x: R - inset, y: t + inset),
                CGPoint(x: cx, y: cy),
                CGPoint(x: l + inset, y: B - inset),
                CGPoint(x: R - inset, y: B - inset),
                CGPoint(x: cx, y: t + inset)]
    }

    private static func polyline(_ pts: [CGPoint], u: Double) -> CGPoint {
        guard pts.count > 1 else { return pts.first ?? .zero }
        var lengths: [Double] = []
        var total: Double = 0
        for i in 1..<pts.count {
            let dx = Double(pts[i].x - pts[i - 1].x)
            let dy = Double(pts[i].y - pts[i - 1].y)
            let d = (dx * dx + dy * dy).squareRoot()
            lengths.append(d)
            total += d
        }
        var target = u * total
        for i in 0..<lengths.count {
            if target <= lengths[i] || i == lengths.count - 1 {
                let f: Double = lengths[i] == 0 ? 0 : target / lengths[i]
                return CGPoint(x: pts[i].x + (pts[i + 1].x - pts[i].x) * CGFloat(f),
                               y: pts[i].y + (pts[i + 1].y - pts[i].y) * CGFloat(f))
            }
            target -= lengths[i]
        }
        return pts.last ?? .zero
    }
}

// MARK: - Session model

@MainActor
final class ExerciseSession: ObservableObject {
    @Published var selectedID: String = UserDefaults.standard.string(forKey: SettingsKeys.selectedExercise) ?? "fig8"
    @Published var running = false
    @Published var reversed = false
    @Published var loopSeconds: Double = UserDefaults.standard.object(forKey: SettingsKeys.loopSeconds) == nil
        ? 5
        : UserDefaults.standard.double(forKey: SettingsKeys.loopSeconds)
    @Published var duration: Int = 30
    @Published var startedAt: Date?
    @Published var justCompleted = false
    @Published private(set) var queue: [Exercise] = []
    @Published var queueIndex: Int = 0
    @Published private(set) var isPaused = false

    /// Seconds completed before a pause; resume continues from here.
    private(set) var accumulated: TimeInterval = 0

    var currentElapsed: TimeInterval {
        accumulated + (startedAt.map { Date().timeIntervalSince($0) } ?? 0)
    }

    /// Focus mode hooks this to auto-advance to the next step.
    var onStepComplete: (() -> Void)?

    private var finishTimer: Timer?

    var selected: Exercise {
        Exercise.catalog.first { $0.id == selectedID } ?? Exercise.catalog[0]
    }

    func select(_ exercise: Exercise) {
        guard !running else { return }
        selectedID = exercise.id
        UserDefaults.standard.set(exercise.id, forKey: SettingsKeys.selectedExercise)
    }

    func setLoop(_ seconds: Double) {
        loopSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: SettingsKeys.loopSeconds)
    }

    func start() {
        guard !running, !isPaused else { return }
        justCompleted = false
        accumulated = 0
        isPaused = false
        running = true
        startedAt = Date()
        scheduleFinish(after: TimeInterval(duration))
    }

    func pause() {
        guard running, let started = startedAt else { return }
        accumulated += Date().timeIntervalSince(started)
        startedAt = nil
        finishTimer?.invalidate()
        finishTimer = nil
        running = false
        isPaused = true
    }

    /// Continues a paused step with its remaining time intact.
    func resume() {
        guard isPaused, !running else { return }
        isPaused = false
        running = true
        startedAt = Date()
        let remaining = TimeInterval(duration) - accumulated
        if remaining <= 0.05 {
            complete()
        } else {
            scheduleFinish(after: remaining)
        }
    }

    func togglePause() {
        if running {
            pause()
        } else if isPaused {
            resume()
        } else {
            start()
        }
    }

    private func scheduleFinish(after interval: TimeInterval) {
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.complete() }
        }
        t.tolerance = 0.3
        finishTimer = t
    }

    func stop() {
        running = false
        isPaused = false
        accumulated = 0
        startedAt = nil
        finishTimer?.invalidate()
        finishTimer = nil
    }

    /// Arms a playlist of steps and starts the one at `index`.
    func startQueue(_ steps: [Exercise], index: Int = 0) {
        guard !steps.isEmpty else { return }
        stop()
        queue = steps
        queueIndex = min(max(0, index), steps.count - 1)
        select(queue[queueIndex])
        start()
    }

    /// Moves through the queue (negative = previous) and starts the new step.
    func gotoStep(_ delta: Int) {
        guard !queue.isEmpty else { return }
        let next = min(max(0, queueIndex + delta), queue.count - 1)
        guard next != queueIndex else { return }
        stop()
        queueIndex = next
        select(queue[next])
        start()
    }

    func clearQueue() {
        queue = []
        queueIndex = 0
    }

    private func complete() {
        running = false
        startedAt = nil
        finishTimer?.invalidate()
        finishTimer = nil
        justCompleted = true
        AppState.shared.incrementExercises()
        onStepComplete?()
    }
}

extension AppState {
    func quickStart(_ exercise: Exercise) {
        TheaterController.shared.present(steps: [exercise])
    }
}
