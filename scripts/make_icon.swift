// Renders the Iris app icon: dark squircle, almond eye with orange iris, notch cutout.
// Usage: swift scripts/make_icon.swift <output-iconset-dir>
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

// Background squircle
let corner: CGFloat = 224
let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: corner, cornerHeight: corner, transform: nil)
ctx.addPath(bgPath)
ctx.clip()

let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [CGColor(srgbRed: 0.13, green: 0.13, blue: 0.15, alpha: 1),
                                   CGColor(srgbRed: 0.02, green: 0.02, blue: 0.03, alpha: 1)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s * 0.4, y: 0), options: [])

let cx: CGFloat = s / 2
let cy: CGFloat = s / 2 - 40

// Almond eye outline
let eyeW: CGFloat = 620
let eyeH: CGFloat = 300
let left = CGPoint(x: cx - eyeW / 2, y: cy)
let right = CGPoint(x: cx + eyeW / 2, y: cy)
let eye = CGMutablePath()
eye.move(to: left)
eye.addCurve(to: right,
             control1: CGPoint(x: cx - eyeW * 0.18, y: cy + eyeH * 0.92),
             control2: CGPoint(x: cx + eyeW * 0.18, y: cy + eyeH * 0.92))
eye.addCurve(to: left,
             control1: CGPoint(x: cx + eyeW * 0.18, y: cy - eyeH * 0.92),
             control2: CGPoint(x: cx - eyeW * 0.18, y: cy - eyeH * 0.92))
eye.closeSubpath()

ctx.addPath(eye)
ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.92))
ctx.setLineWidth(34)
ctx.setLineJoin(.round)
ctx.strokePath()

// Iris
let irisR: CGFloat = 158
ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.56, blue: 0.16, alpha: 1))
ctx.fillEllipse(in: CGRect(x: cx - irisR, y: cy - irisR, width: irisR * 2, height: irisR * 2))

// Pupil
ctx.setFillColor(CGColor(srgbRed: 0.05, green: 0.04, blue: 0.06, alpha: 1))
ctx.fillEllipse(in: CGRect(x: cx - 62, y: cy - 62, width: 124, height: 124))

// Highlight
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95))
ctx.fillEllipse(in: CGRect(x: cx + 34, y: cy + 40, width: 52, height: 52))

// Notch cutout at top center
let notchW: CGFloat = 340
let notchH: CGFloat = 92
let notch = CGPath(roundedRect: CGRect(x: cx - notchW / 2, y: s - notchH, width: notchW, height: notchH),
                   cornerWidth: 0, cornerHeight: 0, transform: nil)
ctx.addPath(notch)
ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
ctx.fillPath()
// round only the bottom corners of the notch by drawing a rounded rect slightly overlapping
let notchRound = CGPath(roundedRect: CGRect(x: cx - notchW / 2, y: s - notchH, width: notchW, height: notchH),
                        cornerWidth: 30, cornerHeight: 30, transform: nil)
ctx.addPath(notchRound)
ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
ctx.fillPath()
// cover the rounded top corners with a plain rect (notch top edge is flush with icon top)
ctx.fill(CGRect(x: cx - notchW / 2, y: s - 40, width: notchW, height: 40))

let image = ctx.makeImage()!

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "resources/AppIcon.iconset"
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
    print("wrote \(name)")
}
