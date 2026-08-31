import AppKit

enum StatusDashboardGeometry {
    static let preferredSize = NSSize(width: 440, height: 620)

    static func frame(
        anchor: NSRect?,
        visibleFrame: NSRect,
        preferredSize: NSSize = preferredSize,
        gap: CGFloat = 8,
        margin: CGFloat = 12
    ) -> NSRect {
        let width = min(preferredSize.width, max(1, visibleFrame.width - margin * 2))
        let height = min(preferredSize.height, max(1, visibleFrame.height - margin * 2))

        let fallbackX = visibleFrame.maxX - margin - width
        let desiredX = anchor.map { $0.maxX - width } ?? fallbackX
        let minimumX = visibleFrame.minX + margin
        let maximumX = visibleFrame.maxX - margin - width
        let x = min(max(desiredX, minimumX), maximumX)

        let desiredTop = anchor?.minY ?? (visibleFrame.maxY + gap - margin)
        let desiredY = desiredTop - gap - height
        let minimumY = visibleFrame.minY + margin
        let maximumY = visibleFrame.maxY - margin - height
        let y = min(max(desiredY, minimumY), maximumY)

        return NSRect(x: x, y: y, width: width, height: height)
    }
}
