// Wraps a raw simulator screenshot in a clean iPhone-style device frame on a
// transparent background with a soft drop shadow.
// Usage: swift Tools/FrameScreenshot.swift <input.png> <output.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: FrameScreenshot <in.png> <out.png>\n".utf8))
    exit(2)
}
let inPath = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: inPath) as CFURL, nil),
      let shot = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write(Data("could not read \(inPath)\n".utf8))
    exit(1)
}

let w = CGFloat(shot.width)
let h = CGFloat(shot.height)

// Frame metrics derived from the screen width.
let bezel = (w * 0.020).rounded()          // uniform black border
let rimInset = (w * 0.006).rounded()        // titanium rim thickness
let screenRadius = w * 0.125                 // rounded screen corners
let bodyRadius = screenRadius + bezel + rimInset
let margin = (w * 0.075).rounded()           // padding for the shadow

let bodyW = w + 2 * (bezel + rimInset)
let bodyH = h + 2 * (bezel + rimInset)
let canvasW = Int(bodyW + 2 * margin)
let canvasH = Int(bodyH + 2 * margin)

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: canvasW, height: canvasH, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    exit(1)
}

let bodyRect = CGRect(x: margin, y: margin, width: bodyW, height: bodyH)
let rimRect = bodyRect.insetBy(dx: rimInset, dy: rimInset)
let screenRect = CGRect(x: margin + bezel + rimInset, y: margin + bezel + rimInset, width: w, height: h)

func roundedPath(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// Soft drop shadow cast by the device body.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -margin * 0.18), blur: margin * 0.7,
              color: CGColor(colorSpace: cs, components: [0, 0, 0, 0.42])!)
ctx.addPath(roundedPath(bodyRect, bodyRadius))
ctx.setFillColor(CGColor(colorSpace: cs, components: [0.06, 0.06, 0.07, 1])!)
ctx.fillPath()
ctx.restoreGState()

// Titanium rim: a subtle vertical gradient ring.
ctx.saveGState()
ctx.addPath(roundedPath(bodyRect, bodyRadius))
ctx.clip()
let rim = CGGradient(colorsSpace: cs, colors: [
    CGColor(colorSpace: cs, components: [0.42, 0.42, 0.45, 1])!,
    CGColor(colorSpace: cs, components: [0.20, 0.20, 0.22, 1])!,
    CGColor(colorSpace: cs, components: [0.34, 0.34, 0.37, 1])!,
] as CFArray, locations: [0, 0.5, 1])!
ctx.drawLinearGradient(rim, start: CGPoint(x: 0, y: canvasH), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

// Black inner body inside the rim.
ctx.addPath(roundedPath(rimRect, bodyRadius - rimInset))
ctx.setFillColor(CGColor(colorSpace: cs, components: [0.04, 0.04, 0.05, 1])!)
ctx.fillPath()

// The screenshot, clipped to rounded screen corners.
ctx.saveGState()
ctx.addPath(roundedPath(screenRect, screenRadius))
ctx.clip()
ctx.draw(shot, in: screenRect)
ctx.restoreGState()

guard let outImage = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else {
    exit(1)
}
CGImageDestinationAddImage(dest, outImage, nil)
CGImageDestinationFinalize(dest)
print("framed -> \(outPath)")
