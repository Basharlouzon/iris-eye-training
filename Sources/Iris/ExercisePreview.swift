import SwiftUI

/// High-fidelity exercise canvas, ported from the web Exercise library design:
/// grid background, gradient guide strokes, endpoint/corner/jump markers,
/// direction arrows, FAR/NEAR and INHALE/EXHALE annotations, and the target
/// dot with glow halo, outer ring, highlight and a fading motion trail.
struct ExercisePreviewCanvas: View {
    let kind: Exercise.Kind
    // Session-driven playback (nil startedAt = ambient loop for library cards).
    var startedAt: Date? = nil
    var loopSeconds: Double = 6
    var reversed: Bool = false
    var paused: Bool = false
    /// True = draw the animation directly on the parent background (full-screen mode).
    var plain: Bool = false

    var body: some View {
        if plain {
            core
        } else {
            core
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.panel)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        }
    }

    private var core: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
            Canvas { context, size in
                let phase: Double
                if let startedAt {
                    var p = timeline.date.timeIntervalSince(startedAt) / max(0.5, loopSeconds)
                    p = p.truncatingRemainder(dividingBy: 1)
                    if p < 0 { p += 1 }
                    phase = reversed ? 1 - p : p
                } else {
                    // Ambient drift so library cards feel alive without a session.
                    let seconds = timeline.date.timeIntervalSinceReferenceDate / loopSeconds
                    phase = seconds.truncatingRemainder(dividingBy: 1)
                }
                render(context: context, size: size, kind: kind, phase: phase)
            }
        }
    }

    private func render(context: GraphicsContext, size: CGSize, kind: Exercise.Kind, phase: Double) {
        drawGrid(context, size)
        drawAnnotations(context, size, kind)
        drawGuide(context, size, kind)

        let scale = dotScale(kind, phase)
        drawTrail(context, size, kind: kind, phase: phase, reversed: reversed, scale: scale)
        drawDot(context, at: ExercisePath.point(kind, t: phase, size: size), scale: scale)
    }

    // MARK: Layers

    private func drawGrid(_ context: GraphicsContext, _ size: CGSize) {
        let step: CGFloat = 20
        var path = Path()
        var x: CGFloat = step
        while x < size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }
        var y: CGFloat = step
        while y < size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += step
        }
        context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 1)
    }

    private func drawGuide(_ context: GraphicsContext, _ size: CGSize, _ kind: Exercise.Kind) {
        let guide = ExercisePath.guidePath(kind, size: size)
        guard !guide.isEmpty else { return }
        let gradient = Gradient(colors: [.white.opacity(0.06), .white.opacity(0.34), .white.opacity(0.06)])
        context.stroke(guide,
                       with: .linearGradient(gradient,
                                             startPoint: .zero,
                                             endPoint: CGPoint(x: size.width, y: size.height)),
                       lineWidth: 2)
    }

    private func drawAnnotations(_ context: GraphicsContext, _ size: CGSize, _ kind: Exercise.Kind) {
        let margin = ExercisePath.marginFor(size)
        let w = size.width - margin * 2
        let h = size.height - margin * 2
        let cx = size.width / 2
        let cy = size.height / 2

        // Markers along fixed points
        let markers = ExercisePath.markerPoints(kind, size: size)
        for point in markers {
            context.stroke(Path(ellipseIn: CGRect(x: point.x - 5.5, y: point.y - 5.5, width: 11, height: 11)),
                           with: .color(.white.opacity(0.28)), lineWidth: 1)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 1.8, y: point.y - 1.8, width: 3.6, height: 3.6)),
                         with: .color(.white.opacity(0.55)))
        }

        // Direction arrows
        for (point, angle) in ExercisePath.arrows(kind, size: size) {
            drawArrow(context, at: point, angle: angle)
        }

        switch kind {
        case .nearfar:
            let rFar = min(w, h) * 0.42
            let rNear = min(w, h) * 0.15
            context.stroke(Path(ellipseIn: CGRect(x: cx - rFar, y: cy - rFar, width: rFar * 2, height: rFar * 2)),
                           with: .color(.white.opacity(0.26)), lineWidth: 1.5)
            context.stroke(Path(ellipseIn: CGRect(x: cx - rNear, y: cy - rNear, width: rNear * 2, height: rNear * 2)),
                           with: .color(Theme.accent.opacity(0.5)), lineWidth: 1.5)
            drawLabel(context, "FAR", at: CGPoint(x: size.width - 24, y: cy - rFar))
            drawLabel(context, "NEAR", at: CGPoint(x: size.width - 24, y: cy - rNear + 12))
        case .pulse:
            let base = min(w, h) / 2
            for (i, k) in [0.28, 0.52, 0.76, 1.0].enumerated() {
                let r = base * k
                context.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                               with: .color(.white.opacity(0.22 - Double(i) * 0.045)), lineWidth: 1.2)
            }
        case .breathe:
            let base = min(w, h) / 2
            for (i, k) in [0.22, 0.48, 0.74, 1.0].enumerated() {
                let r = base * k
                context.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                               with: .color(.white.opacity(0.18 - Double(i) * 0.02)),
                               style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
            }
            drawLabel(context, "INHALE", at: CGPoint(x: cx, y: 10))
            drawLabel(context, "EXHALE", at: CGPoint(x: cx, y: size.height - 10))
        default:
            break
        }
    }

    private func drawArrow(_ context: GraphicsContext, at point: CGPoint, angle: CGFloat) {
        let length: CGFloat = 9
        let width: CGFloat = 6
        let tip = CGPoint(x: point.x + cos(angle) * length / 2, y: point.y + sin(angle) * length / 2)
        let backLeft = CGPoint(x: point.x - cos(angle) * length / 2 + cos(angle + .pi / 2) * width / 2,
                               y: point.y - sin(angle) * length / 2 + sin(angle + .pi / 2) * width / 2)
        let backRight = CGPoint(x: point.x - cos(angle) * length / 2 - cos(angle + .pi / 2) * width / 2,
                                y: point.y - sin(angle) * length / 2 - sin(angle + .pi / 2) * width / 2)
        var path = Path()
        path.move(to: tip)
        path.addLine(to: backLeft)
        path.addLine(to: backRight)
        path.closeSubpath()
        context.fill(path, with: .color(Theme.accent.opacity(0.85)))
    }

    private func drawLabel(_ context: GraphicsContext, _ text: String, at point: CGPoint) {
        context.draw(
            Text(text)
                .font(.system(size: 7, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.5)),
            at: point
        )
    }

    // MARK: Target dot

    private func dotScale(_ kind: Exercise.Kind, _ phase: Double) -> CGFloat {
        switch kind {
        case .pulse:
            // Two pulses per loop.
            return 1 + 0.55 * (0.5 - 0.5 * cos(2 * .pi * phase * 2))
        case .breathe:
            // One slow breath per loop.
            return 0.75 + 0.65 * (0.5 - 0.5 * cos(2 * .pi * phase))
        default:
            return 1
        }
    }

    private func drawTrail(_ context: GraphicsContext, _ size: CGSize,
                           kind: Exercise.Kind, phase: Double, reversed: Bool, scale: CGFloat) {
        // Breathing/pulse dots stay in place; a trail there is visual noise.
        guard kind != .pulse, kind != .breathe else { return }
        for k in 1...8 {
            var tp = phase - Double(k) * 0.010 * (reversed ? -1 : 1)
            tp = ExercisePath.normalized(tp)
            let p = ExercisePath.point(kind, t: tp, size: size)
            let r = (4.2 - CGFloat(k) * 0.42) * scale
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Theme.accent.opacity(0.26 - Double(k) * 0.028)))
        }
    }

    private func drawDot(_ context: GraphicsContext, at point: CGPoint, scale: CGFloat) {
        let body = 4.5 * scale
        // Glow halo
        var glow = context
        glow.addFilter(.blur(radius: 5))
        let halo = body * 2.1
        glow.fill(Path(ellipseIn: CGRect(x: point.x - halo, y: point.y - halo, width: halo * 2, height: halo * 2)),
                  with: .color(Theme.accent.opacity(0.35)))
        // Outer ring
        let ring = body * 1.55
        context.stroke(Path(ellipseIn: CGRect(x: point.x - ring, y: point.y - ring, width: ring * 2, height: ring * 2)),
                       with: .color(.white.opacity(0.30)), lineWidth: 1)
        // Body with soft shadow
        let bodyRect = CGRect(x: point.x - body, y: point.y - body, width: body * 2, height: body * 2)
        var shadowed = context
        shadowed.addFilter(.shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1.5))
        shadowed.fill(Path(ellipseIn: bodyRect), with: .color(Theme.accent))
        // 3D highlight
        let hi = body * 0.38
        context.fill(Path(ellipseIn: CGRect(x: point.x - body * 0.35, y: point.y - body * 0.5, width: hi * 2, height: hi * 2)),
                     with: .color(.white.opacity(0.85)))
        // Center fixation dot
        context.fill(Path(ellipseIn: CGRect(x: point.x - 1.1, y: point.y - 1.1, width: 2.2, height: 2.2)),
                     with: .color(.white))
    }
}
