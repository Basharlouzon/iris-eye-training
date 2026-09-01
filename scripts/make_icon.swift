// Renders the Iris app icon — black squircle, faint grid, glowing almond eye
// with a radial orange iris, an orbit ring + dot, and the signature notch cutout.
// Usage: swift scripts/make_icon.swift <output-iconset-dir> [website-png-path]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func makeContext(_ width: Int, _ height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height,
              bitsPerComponent: 8, bytesPerRow: 0,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

let ctx = makeContext(size, size)
let s = CGFloat(size)

// Background squircle with a soft top-lit gradient
let corner: CGFloat = 224
let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: corner, cornerHeight: corner, transform: nil)
ctx.addPath(bgPath)
ctx.clip()

let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [CGColor(srgbRed: 0.075, green: 0.08, blue: 0.07, alpha: 1),
                                   CGColor(srgbRed: 0.016, green: 0.02, blue: 0.016, alpha: 1)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: s),
                       end: CGPoint(x: s * 0.35, y: 0), options: [])

// Faint grid, clipped to the squircle
ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.030))
ctx.setLineWidth(2)
let gridStep: CGFloat = s / 16
var g: CGFloat = gridStep
while g < s {
    ctx.move(to: CGPoint(x: g, y: 0)); ctx.addLine(to: CGPoint(x: g, y: s))
    ctx.move(to: CGPoint(x: 0, y: g)); ctx.addLine(to: CGPoint(x: s, y: g))
    g += gridStep
}
ctx.strokePath()

let cx: CGFloat = s / 2
let cy: CGFloat = s * 0.46

// Warm glow behind the eye
let glow = CGGradient(colorsSpace: colorSpace,
                      colors: [CGColor(srgbRed: 1.0, green: 0.56, blue: 0.16, alpha: 0.22),
                               CGColor(srgbRed: 1.0, green: 0.56, blue: 0.16, alpha: 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow,
                       startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                       endCenter: CGPoint(x: cx, y: cy), endRadius: s * 0.42,
                       options: [])

// Orbit ring + dot (the Focus Mode signature)
let orbitR: CGFloat = s * 0.365
ctx.setStrokeColor(CGColor(srgbRed: 1, green: 0.56, blue: 0.16, alpha: 0.28))
ctx.setLineWidth(s * 0.008)
ctx.strokeEllipse(in: CGRect(x: cx - orbitR, y: cy - orbitR, width: orbitR * 2, height: orbitR * 2))
let orbitAngle: CGFloat = -0.9
let ox = cx + cos(orbitAngle) * orbitR
let oy = cy + sin(orbitAngle) * orbitR
let dotR: CGFloat = s * 0.022
ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.56, blue: 0.16, alpha: 1))
ctx.fillEllipse(in: CGRect(x: ox - dotR, y: oy - dotR, width: dotR * 2, height: dotR * 2))

// Almond eye
let eyeW: CGFloat = s * 0.60
let eyeH: CGFloat = s * 0.30
let left = CGPoint(x: cx - eyeW / 2, y: cy)
let right = CGPoint(x: cx + eyeW / 2, y: cy)
let eye = CGMutablePath()
eye.move(to: left)
eye.addCurve(to: right,
             control1: CGPoint(x: cx - eyeW * 0.18, y: cy + eyeH * 0.95),
             control2: CGPoint(x: cx + eyeW * 0.18, y: cy + eyeH * 0.95))
eye.addCurve(to: left,
             control1: CGPoint(x: cx + eyeW * 0.18, y: cy - eyeH * 0.95),
             control2: CGPoint(x: cx - eyeW * 0.18, y: cy - eyeH * 0.95))
eye.closeSubpath()

// Soft shadow under the eye shape
ctx.saveGState()
ctx.addPath(eye)
ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.035,
              color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55))
ctx.setStrokeColor(CGColor(srgbRed: 0.92, green: 0.94, blue: 0.90, alpha: 1))
ctx.setLineWidth(s * 0.030)
ctx.setLineJoin(.round)
ctx.strokePath()
ctx.restoreGState()

// Iris: radial orange with darker rim, clipped to the almond
ctx.saveGState()
ctx.addPath(eye)
ctx.clip()
let irisR: CGFloat = s * 0.135
let irisCenter = CGPoint(x: cx, y: cy)
let irisGrad = CGGradient(colorsSpace: colorSpace,
                          colors: [CGColor(srgbRed: 1.0, green: 0.72, blue: 0.38, alpha: 1),
                                   CGColor(srgbRed: 1.0, green: 0.52, blue: 0.10, alpha: 1),
                                   CGColor(srgbRed: 0.78, green: 0.30, blue: 0.04, alpha: 1)] as CFArray,
                          locations: [0, 0.55, 1])!
ctx.drawRadialGradient(irisGrad,
                       startCenter: CGPoint(x: irisCenter.x - irisR * 0.35, y: irisCenter.y + irisR * 0.35),
                       startRadius: irisR * 0.1,
                       endCenter: irisCenter, endRadius: irisR,
                       options: [])
ctx.restoreGState()

// Pupil + highlight
ctx.setFillColor(CGColor(srgbRed: 0.03, green: 0.025, blue: 0.03, alpha: 1))
ctx.fillEllipse(in: CGRect(x: cx - s * 0.052, y: cy - s * 0.052, width: s * 0.104, height: s * 0.104))
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95))
ctx.fillEllipse(in: CGRect(x: cx + s * 0.028, y: cy + s * 0.036, width: s * 0.048, height: s * 0.048))

// Notch cutout at top center (brand signature)
let notchW: CGFloat = s * 0.30
let notchH: CGFloat = s * 0.085
let notchRect = CGRect(x: cx - notchW / 2, y: s - notchH, width: notchW, height: notchH)
ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
ctx.fill(notchRect)
let notchRound = CGPath(roundedRect: notchRect, cornerWidth: s * 0.028, cornerHeight: s * 0.028, transform: nil)
ctx.addPath(notchRound)
ctx.fillPath()
ctx.fill(CGRect(x: cx - notchW / 2, y: s - s * 0.02, width: notchW, height: s * 0.02))

let image = ctx.makeImage()!

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "resources/AppIcon.iconset"
let webOut = args.count > 2 ? args[2] : "website/icon.png"

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for scale in [16, 32, 64, 128, 256, 512, 1024] {
    let small = makeContext(scale, scale)
    small.interpolationQuality = .high
    small.draw(image, in: CGRect(x: 0, y: 0, width: scale, height: scale))
    guard let scaled = small.makeImage() else { continue }
    let name: String
    switch scale {
    case 16: name = "icon_16x16.png"
    case 32: name = "icon_16x16@2x.png"
    case 64: name = "icon_32x32.png"
    case 128: name = "icon_32x32@2x.png"
    case 256: name = "icon_128x128@2x.png"
    case 512: name = "icon_256x256@2x.png"
    case 1024: name = "icon_512x512@2x.png"
    default: continue
    }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("cannot create \(url)")
    }
    CGImageDestinationAddImage(dest, scaled, nil)
    CGImageDestinationFinalize(dest)
}

// Website copy (single large PNG)
let webURL = URL(fileURLWithPath: webOut)
try? FileManager.default.createDirectory(atPath: (webOut as NSString).deletingLastPathComponent,
                                         withIntermediateDirectories: true)
if let dest = CGImageDestinationCreateWithURL(webURL as CFURL, UTType.png.identifier as CFString, 1, nil) {
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}
print("icon written: \(outDir) + \(webOut)")
