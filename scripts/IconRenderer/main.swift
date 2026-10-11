import AppKit
import Foundation
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
func render(width: Int, height: Int, draw: (NSRect) -> Void) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    draw(NSRect(x: 0, y: 0, width: width, height: height))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for size in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = size * factor
        let suffix = factor == 2 ? "@2x" : ""
        try render(width: pixels, height: pixels) { IconArtwork.drawAppIcon(in: $0) }.write(to: URL(fileURLWithPath: "\(root)/assets/Prewarm.iconset/icon_\(size)x\(size)\(suffix).png"))
    }
}
try render(width: 720, height: 420) { canvas in
    NSColor(srgbRed: 0.95, green: 0.945, blue: 0.93, alpha: 1).setFill()
    canvas.fill()
    IconArtwork.drawAppIcon(in: NSRect(x: 30, y: 90, width: 270, height: 270))
    let font: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.black]
    ("Prewarm · flame microphone" as NSString).draw(at: NSPoint(x: 45, y: 55), withAttributes: font)
    for (index, dark) in [false, true].enumerated() {
        let y = CGFloat(240 - index * 135)
        let strip = NSRect(x: 345, y: y, width: 340, height: 95)
        (dark ? NSColor(srgbRed: 0.12, green: 0.12, blue: 0.12, alpha: 1) : .white).setFill()
        NSBezierPath(roundedRect: strip, xRadius: 12, yRadius: 12).fill()
        let ink: NSColor = dark ? .white : .black
        for (i, size) in [16, 18, 22].enumerated() {
            let x = CGFloat(375 + i * 100)
            IconArtwork.drawMark(in: NSRect(x: x, y: y + 45, width: CGFloat(size) * 24 / 28, height: CGFloat(size)), color: ink)
            IconArtwork.drawMark(in: NSRect(x: x + 28, y: y + 45, width: CGFloat(size) * 24 / 28, height: CGFloat(size)), color: ink, active: false)
            ("\(size) px on / off" as NSString).draw(at: NSPoint(x: x - 4, y: y + 15), withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: ink])
        }
    }
}.write(to: URL(fileURLWithPath: "\(root)/assets/icon-review.png"))

try render(width: 540, height: 180) { canvas in
    NSColor.white.setFill(); canvas.fill()
    for (i, kind) in ["system", "builtIn", "bluetooth", "usb", "other"].enumerated() {
        let x = CGFloat(26 + i * 105)
        let icon = IconArtwork.deviceImage(transport: kind)
        icon.draw(in: NSRect(x: x + 22, y: 102, width: 18, height: 18))
        icon.draw(in: NSRect(x: x + 8, y: 43, width: 42, height: 42))
        (kind as NSString).draw(at: NSPoint(x: x, y: 18), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.black])
    }
}.write(to: URL(fileURLWithPath: "\(root)/assets/device-icon-review.png"))
