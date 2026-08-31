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
        var openAmount: CGFloat = 1 // 0 = closed lid, 1 = fully open
        var alpha: CGFloat = 1
        var title: String?
        /// While a Focus Mode exercise runs: a dot orbiting the eye.
        var orbitAngle: Double?
        /// Unread break alerts: app-style badge with the count.
        var badgeCount: Int?
    }

    static func frame(for state: State, tick: TimeInterval) -> Frame {
        switch state {
        case .idle(let blinkEvery):
            return Frame(openAmount: 1 - blinkAmount(tick: tick, period: blinkEvery))
        case .approaching:
            return Frame(openAmount: 1 - blinkAmount(tick: tick, period: 1.8))
        case .due:
            let pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(tick * 2 * .pi / 1.3))
            return Frame(openAmount: 0.45, alpha: CGFloat(pulse))
        case .resting(let secondsLeft):
            return Frame(openAmount: 0, title: "\(secondsLeft)s")
        }
    }

    /// 0 → 1 → 0 lid closure over a ~0.22 s blink at the start of each period.
    private static func blinkAmount(tick: TimeInterval, period: Double) -> Double {
        let cycle = tick.truncatingRemainder(dividingBy: period)
        guard cycle < 0.24 else { return 0 }
        return sin(.pi * cycle / 0.24)
    }

    static func image(_ frame: Frame) -> NSImage {
        // Extra width when the alert badge is present.
        let width = side + (frame.badgeCount == nil ? 0 : 4)
        let image = NSImage(size: NSSize(width: width, height: side), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return true }
            context.setAllowsAntialiasing(true)
            context.setAlpha(frame.alpha)
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let midX: CGFloat = 9
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

            // Orbiting dot while a Focus Mode exercise runs
            if let angle = frame.orbitAngle {
                let radius: CGFloat = 7.2
                let dot: CGFloat = 1.5
                let center = CGPoint(x: midX + CGFloat(cos(angle)) * radius,
                                     y: midY + CGFloat(sin(angle)) * radius)
                context.fillEllipse(in: CGRect(x: center.x - dot, y: center.y - dot,
                                               width: dot * 2, height: dot * 2))
            }

            // Unread-alert badge: punched-out number, app-icon style
            if let count = frame.badgeCount {
                let badgeCenter = CGPoint(x: width - 4.6, y: side - 4.6)
                let badgeRadius: CGFloat = count > 9 ? 5.0 : 4.4
                context.fillEllipse(in: CGRect(x: badgeCenter.x - badgeRadius,
                                               y: badgeCenter.y - badgeRadius,
                                               width: badgeRadius * 2, height: badgeRadius * 2))
                let label = count > 9 ? "9+" : "\(count)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 6.4, weight: .bold),
                    .foregroundColor: NSColor.black,
                ]
                let text = NSAttributedString(string: label, attributes: attributes)
                let textSize = text.size()
                context.setBlendMode(.clear)
                text.draw(at: NSPoint(x: badgeCenter.x - textSize.width / 2,
                                      y: badgeCenter.y - textSize.height / 2 + 0.4))
                context.setBlendMode(.normal)
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
