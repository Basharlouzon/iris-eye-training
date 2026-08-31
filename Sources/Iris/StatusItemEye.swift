import AppKit

/// The animated menu-bar eye. Drawn as a template image (alpha carries the
/// shape) so it adapts to any menu bar appearance.
///
/// States:
/// - idle: open eye, natural blink every ~6 s
/// - approaching (break < 2 min): blinks every ~1.8 s — a soft "soon" cue
/// - due (unread break alert): tired half-closed eye, opacity pulse
/// - resting: closed eye, plus a seconds countdown beside it
@MainActor
enum StatusItemEye {
    static let side: CGFloat = 18

    enum State: Equatable {
        case idle(blinkEvery: Double)
        case approaching
        case due
        case resting(secondsLeft: Int)
    }

    struct Frame {
        let openAmount: CGFloat // 0 = closed lid, 1 = fully open
        let alpha: CGFloat
        let title: String?
    }

    static func frame(for state: State, tick: TimeInterval) -> Frame {
        switch state {
        case .idle(let blinkEvery):
            return Frame(openAmount: 1 - blinkAmount(tick: tick, period: blinkEvery),
                         alpha: 1,
                         title: nil)
        case .approaching:
            return Frame(openAmount: 1 - blinkAmount(tick: tick, period: 1.8),
                         alpha: 1,
                         title: nil)
        case .due:
            let pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(tick * 2 * .pi / 1.3))
            return Frame(openAmount: 0.45, alpha: CGFloat(pulse), title: nil)
        case .resting(let secondsLeft):
            return Frame(openAmount: 0, alpha: 1, title: "\(secondsLeft)s")
        }
    }

    /// 0 → 1 → 0 lid closure over a ~0.22 s blink at the start of each period.
    private static func blinkAmount(tick: TimeInterval, period: Double) -> Double {
        let cycle = tick.truncatingRemainder(dividingBy: period)
        guard cycle < 0.24 else { return 0 }
        return sin(.pi * cycle / 0.24)
    }

    static func image(_ frame: Frame) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return true }
            context.setAllowsAntialiasing(true)
            context.setAlpha(frame.alpha)
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let midX = side / 2
            let midY = side / 2
            let halfWidth: CGFloat = side / 2 - 3
            let open = max(0.08, min(1, frame.openAmount))
            let halfHeight: CGFloat = 6.2 * open

            // Almond eye
            let eye = NSBezierPath()
            eye.move(to: NSPoint(x: midX - halfWidth, y: midY))
            eye.curve(to: NSPoint(x: midX + halfWidth, y: midY),
                      controlPoint1: NSPoint(x: midX - halfWidth * 0.45, y: midY + halfHeight),
                      controlPoint2: NSPoint(x: midX + halfWidth * 0.45, y: midY + halfHeight))
            eye.curve(to: NSPoint(x: midX - halfWidth, y: midY),
                      controlPoint1: NSPoint(x: midX + halfWidth * 0.45, y: midY - halfHeight),
                      controlPoint2: NSPoint(x: midX - halfWidth * 0.45, y: midY - halfHeight))
            eye.close()
            eye.lineWidth = 1.6
            eye.stroke()

            if open > 0.4 {
                // Iris, clipped to the almond
                context.saveGState()
                eye.setClip()
                let iris: CGFloat = 2.7
                context.fillEllipse(in: CGRect(x: midX - iris, y: midY - iris,
                                               width: iris * 2, height: iris * 2))
                context.restoreGState()
            } else {
                // Closed lid: a gentle downward arc
                let lid = NSBezierPath()
                lid.move(to: NSPoint(x: midX - halfWidth, y: midY))
                lid.curve(to: NSPoint(x: midX + halfWidth, y: midY),
                          controlPoint1: NSPoint(x: midX - halfWidth * 0.5, y: midY - 1.4),
                          controlPoint2: NSPoint(x: midX + halfWidth * 0.5, y: midY - 1.4))
                lid.lineWidth = 1.6
                lid.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
