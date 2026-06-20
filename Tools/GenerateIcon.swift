// Generates the Ember app icon (1024x1024 PNG) using Core Graphics.
// Run: swift Tools/GenerateIcon.swift
// Output: Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }

let S = CGFloat(size)

// MARK: Background gradient (warm ember orange, top-light -> bottom-deep)
let bgColors = [
    CGColor(colorSpace: cs, components: [1.00, 0.58, 0.23, 1.0])!, // #FF9540
    CGColor(colorSpace: cs, components: [1.00, 0.40, 0.00, 1.0])!, // #FF6600
    CGColor(colorSpace: cs, components: [0.90, 0.27, 0.02, 1.0])!, // #E64405
]
let bgGradient = CGGradient(colorsSpace: cs, colors: bgColors as CFArray,
                            locations: [0.0, 0.55, 1.0])!
ctx.drawLinearGradient(bgGradient,
                       start: CGPoint(x: 0, y: S),
                       end: CGPoint(x: 0, y: 0),
                       options: [])

// Subtle radial glow behind the mark for depth
let glow = CGGradient(colorsSpace: cs, colors: [
    CGColor(colorSpace: cs, components: [1, 1, 1, 0.22])!,
    CGColor(colorSpace: cs, components: [1, 1, 1, 0.0])!,
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow,
                       startCenter: CGPoint(x: S * 0.5, y: S * 0.44), startRadius: 0,
                       endCenter: CGPoint(x: S * 0.5, y: S * 0.44), endRadius: S * 0.5,
                       options: [])

// MARK: Ember mark — an upward teardrop with an inner highlight.
func teardrop(cx: CGFloat, baseY: CGFloat, radius r: CGFloat, tipY: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let tip = CGPoint(x: cx, y: tipY)
    let right = CGPoint(x: cx + r, y: baseY)
    p.move(to: tip)
    p.addCurve(to: right,
               control1: CGPoint(x: cx + r * 0.95, y: tipY + (baseY - tipY) * 0.62),
               control2: CGPoint(x: cx + r, y: baseY - r * 0.65))
    // Sweep under the base (through the bottom) to the left point.
    p.addArc(center: CGPoint(x: cx, y: baseY), radius: r,
             startAngle: 0, endAngle: .pi, clockwise: true)
    p.addCurve(to: tip,
               control1: CGPoint(x: cx - r, y: baseY - r * 0.65),
               control2: CGPoint(x: cx - r * 0.95, y: tipY + (baseY - tipY) * 0.62))
    p.closeSubpath()
    return p
}

// Note: CG origin is bottom-left, so "up" is +y. Place tip high (large y).
let cx = S * 0.5
let outer = teardrop(cx: cx, baseY: S * 0.40, radius: S * 0.215, tipY: S * 0.80)
ctx.addPath(outer)
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 46,
              color: CGColor(colorSpace: cs, components: [0.5, 0.16, 0.0, 0.45])!)
ctx.setFillColor(CGColor(colorSpace: cs, components: [1, 1, 1, 1])!)
ctx.fillPath()

// Inner highlight teardrop (warm cream) for a glowing-core feel
ctx.setShadow(offset: .zero, blur: 0, color: nil)
let inner = teardrop(cx: cx, baseY: S * 0.41, radius: S * 0.118, tipY: S * 0.66)
ctx.addPath(inner)
let innerGrad = CGGradient(colorsSpace: cs, colors: [
    CGColor(colorSpace: cs, components: [1.00, 0.62, 0.25, 1.0])!,
    CGColor(colorSpace: cs, components: [1.00, 0.84, 0.45, 1.0])!,
] as CFArray, locations: [0, 1])!
ctx.saveGState()
ctx.clip()
ctx.drawLinearGradient(innerGrad,
                       start: CGPoint(x: cx, y: S * 0.29),
                       end: CGPoint(x: cx, y: S * 0.66),
                       options: [])
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("image") }
let outURL = URL(fileURLWithPath: "Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
try? FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("dest")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("Wrote \(outURL.path)")
