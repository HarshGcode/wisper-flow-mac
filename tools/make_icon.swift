import AppKit

// Renders a 1024x1024 app icon: a white microphone glyph on a purple→blue
// gradient rounded square (Wispr-flavored), then writes icon_1024.png.

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("no context")
}

// Rounded-rect background with a diagonal gradient.
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let corner = size * 0.2237 // macOS "squircle"-ish radius
let path = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
path.addClip()

let colors = [
    NSColor(calibratedRed: 0.42, green: 0.32, blue: 0.95, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.27, green: 0.55, blue: 0.98, alpha: 1).cgColor
] as CFArray
let space = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: size, y: 0),
                       options: [])

// Microphone glyph via SF Symbol, tinted white, centered.
let config = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .regular)
if let mic = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let tinted = NSImage(size: mic.size)
    tinted.lockFocus()
    NSColor.white.set()
    let r = NSRect(origin: .zero, size: mic.size)
    mic.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let glyphW = size * 0.46
    let glyphH = glyphW * (mic.size.height / mic.size.width)
    let glyphRect = NSRect(x: (size - glyphW) / 2,
                           y: (size - glyphH) / 2,
                           width: glyphW, height: glyphH)
    tinted.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else { fatalError("encode failed") }

let out = URL(fileURLWithPath: "tools/icon_1024.png")
try! png.write(to: out)
print("wrote \(out.path)")
