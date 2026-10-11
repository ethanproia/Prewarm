import AppKit
import Foundation
let root = CommandLine.arguments[1]
let specs = [("Receiver", "hifireceiver"), ("Gain dial", "dial.low"), ("Mixer", "slider.horizontal.3"), ("Cable", "cable.connector"), ("Mic", "mic")]
var images: [(String, NSImage)] = []
for (label, symbol) in specs {
    guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: label),
          let image = base.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)) else {
        fatalError("Missing native symbol: \(symbol)")
    }
    images.append((label, image))
    print("Available: \(symbol)")
}
let custom = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
    NSColor.black.setStroke()
    let panel = NSBezierPath(roundedRect: NSRect(x: 1, y: 3.5, width: 16, height: 11), xRadius: 2, yRadius: 2)
    panel.lineWidth = 1.2
    panel.stroke()
    let jack = NSBezierPath(ovalIn: NSRect(x: 3.1, y: 7.25, width: 3.5, height: 3.5))
    jack.lineWidth = 1.1
    jack.stroke()
    let gain = NSBezierPath(ovalIn: NSRect(x: 9.2, y: 5.9, width: 6.2, height: 6.2))
    gain.lineWidth = 1.1
    gain.stroke()
    let notch = NSBezierPath()
    notch.move(to: NSPoint(x: 12.3, y: 9))
    notch.line(to: NSPoint(x: 12.3, y: 11.2))
    notch.lineWidth = 1.1
    notch.lineCapStyle = .round
    notch.stroke()
    return true
}
images.append(("Scarlett front panel", custom))
let width = 840, height = 170
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
for (i, pair) in images.enumerated() {
    let x = CGFloat(i * 140 + 70)
    pair.1.draw(in: NSRect(x: x - 9, y: 117, width: 18, height: 18))
    pair.1.draw(in: NSRect(x: x - 18, y: 61, width: 36, height: 36))
    let style: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.black]
    let size = (pair.0 as NSString).size(withAttributes: style)
    (pair.0 as NSString).draw(at: NSPoint(x: x - size.width / 2, y: 28), withAttributes: style)
}
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(root)/assets/interface-icon-options.png"))
