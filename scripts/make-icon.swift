#!/usr/bin/env swift
// Generate Multipaste's app icon as a 1024×1024 PNG.
//
// Designed once. Re-run with `swift scripts/make-icon.swift` if you ever
// want to tweak the colors. Output: Resources/icon-1024.png.

import AppKit

let size: CGFloat = 1024
let canvas = NSSize(width: size, height: size)

let image = NSImage(size: canvas)
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext

// Squircle background (macOS app icon shape — approximated with rounded rect)
let pad: CGFloat = 96
let bgRect = NSRect(x: pad, y: pad, width: size - 2 * pad, height: size - 2 * pad)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 200, yRadius: 200)

// Gradient background: a punchy macOS blue → indigo
let gradient = NSGradient(colors: [
    NSColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 1.0),
    NSColor(red: 0.42, green: 0.32, blue: 0.96, alpha: 1.0),
])!
gradient.draw(in: bgPath, angle: -90)

// Clipboard body
let bodyRect = NSRect(x: 280, y: 200, width: 460, height: 580)
let body = NSBezierPath(roundedRect: bodyRect, xRadius: 50, yRadius: 50)
NSColor.white.setFill()
body.fill()

// Clip at the top of the clipboard
let clipRect = NSRect(x: 420, y: 740, width: 180, height: 100)
let clip = NSBezierPath(roundedRect: clipRect, xRadius: 26, yRadius: 26)
NSColor(white: 0.22, alpha: 1.0).setFill()
clip.fill()
// Inner highlight on the clip
let clipHi = NSBezierPath(roundedRect: clipRect.insetBy(dx: 22, dy: 18), xRadius: 16, yRadius: 16)
NSColor(white: 0.40, alpha: 1.0).setFill()
clipHi.fill()

// Stacked "clipboard history" lines — varying widths to suggest list rows
let lineColor = NSColor(white: 0.85, alpha: 1.0)
let highlightColor = NSColor(red: 0.42, green: 0.32, blue: 0.96, alpha: 0.55)
let lineHeight: CGFloat = 60
let lineGap: CGFloat = 30
let lineLeft: CGFloat = 340
let widths: [CGFloat] = [340, 280, 360, 240]
for (i, w) in widths.enumerated() {
    let y = 640 - CGFloat(i) * (lineHeight + lineGap)
    let r = NSRect(x: lineLeft, y: y - lineHeight, width: w, height: lineHeight)
    let p = NSBezierPath(roundedRect: r, xRadius: 18, yRadius: 18)
    if i == 1 {
        // Selected row — paint the highlight to convey "history with picker"
        let bg = NSRect(x: lineLeft - 16, y: y - lineHeight - 8, width: 380, height: lineHeight + 16)
        let bgp = NSBezierPath(roundedRect: bg, xRadius: 22, yRadius: 22)
        highlightColor.setFill()
        bgp.fill()
    }
    lineColor.setFill()
    p.fill()
}

// Subtle bottom shadow for depth (drawn inside the body)
ctx.saveGState()
ctx.addPath(NSBezierPath(roundedRect: bodyRect, xRadius: 50, yRadius: 50).cgPath)
ctx.clip()
let shadowGrad = NSGradient(colors: [
    NSColor(white: 0.0, alpha: 0.0),
    NSColor(white: 0.0, alpha: 0.08),
])!
shadowGrad.draw(in: bodyRect, angle: -90)
ctx.restoreGState()

image.unlockFocus()

// Save PNG
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to encode PNG\n".utf8))
    exit(1)
}

let dir = FileManager.default.currentDirectoryPath
let out = "\(dir)/Resources/icon-1024.png"
try? FileManager.default.createDirectory(
    atPath: (out as NSString).deletingLastPathComponent,
    withIntermediateDirectories: true
)
try png.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")

// Helper extension to get a CGPath out of NSBezierPath. NSBezierPath does
// not have a built-in `.cgPath` getter prior to macOS 14 (it does on 14+),
// but doing this manually keeps us portable across releases.
extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            switch element(at: i, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo, .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }
}
