import AppKit
import Foundation
let root = CommandLine.arguments[1]
func bitmap(_ width: Int, _ height: Int, _ draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill(using: .copy)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
let native = NSImage(systemSymbolName: "mic", accessibilityDescription: nil)!.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))!
let control = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)!.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))!
let candidates = [("Native mic", native), ("Native controls", control), ("Prewarm on", IconArtwork.menuImage(active: true)), ("Prewarm off", IconArtwork.menuImage(active: false))]
func drawImage(_ image: NSImage, at origin: NSPoint, scale: CGFloat = 1) {
    let size = image.size
    image.draw(in: NSRect(x: origin.x + (22 - size.width) / 2 * scale, y: origin.y + (22 - size.height) / 2 * scale, width: size.width * scale, height: size.height * scale))
}
var receipt: [String] = []
for factor in [1, 2] {
    for (name, icon) in candidates {
        let rep = bitmap(22 * factor, 22 * factor) { drawImage(icon, at: .zero, scale: CGFloat(factor)) }
        var xs: [Int] = [], ys: [Int] = []
        var mass = 0.0
        for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide {
            let a = rep.colorAt(x: x, y: y)!.alphaComponent
            mass += a
            if a > 0.1 { xs.append(x); ys.append(y) }
        }}
        receipt.append("\(name) \(factor)x canvas22pt image\(icon.size) alphaBounds=(\(xs.min() ?? 0),\(ys.min() ?? 0))–(\(xs.max() ?? 0),\(ys.max() ?? 0)) alphaMass=\(String(format: "%.1f", mass / Double(factor * factor)))")
    }
}
try receipt.joined(separator: "\n").write(toFile: "\(root)/assets/status-icon-bounds.txt", atomically: true, encoding: .utf8)
let sheet = bitmap(720, 250) {
    NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 720, height: 250).fill()
    for (i, entry) in candidates.enumerated() {
        let x = CGFloat(i * 170 + 30)
        for factor in [1, 2] {
            let y = CGFloat(factor == 1 ? 165 : 100)
            NSColor(srgbRed: 0.93, green: 0.93, blue: 0.93, alpha: 1).setFill()
            NSRect(x: x, y: y, width: CGFloat(22 * factor), height: CGFloat(22 * factor)).fill()
            drawImage(entry.1, at: NSPoint(x: x, y: y), scale: CGFloat(factor))
        }
        (entry.0 as NSString).draw(at: NSPoint(x: x, y: 62), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.black])
    }
    ("22 pt status canvas · top 1×, bottom 2× · native fixtures, not a live menubar capture" as NSString).draw(at: NSPoint(x: 30, y: 25), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
}
try sheet.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(root)/assets/status-icon-comparison.png"))
print(receipt.joined(separator: "\n"))
