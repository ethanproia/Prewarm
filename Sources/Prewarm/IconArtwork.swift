import AppKit

/// Original vector artwork: a flame-shaped microphone in a rounded cradle.
/// Coordinates use a 24 × 28 grid, with AppKit's upward Y axis.
enum IconArtwork {
    static func drawMark(in rect: NSRect, color: NSColor, active: Bool = true) {
        NSGraphicsContext.saveGraphicsState()
        let transform = AffineTransform(translationByX: rect.minX, byY: rect.minY)
        (transform as NSAffineTransform).concat()
        let scale = AffineTransform(scaleByX: rect.width / 24, byY: rect.height / 28)
        (scale as NSAffineTransform).concat()
        color.setFill()
        color.setStroke()
        let body = NSBezierPath()
        body.move(to: NSPoint(x: 12, y: 9))
        body.curve(to: NSPoint(x: 6, y: 15), controlPoint1: NSPoint(x: 8.2, y: 9), controlPoint2: NSPoint(x: 6, y: 11.5))
        body.curve(to: NSPoint(x: 12.5, y: 26), controlPoint1: NSPoint(x: 6, y: 20), controlPoint2: NSPoint(x: 11, y: 21))
        body.curve(to: NSPoint(x: 15, y: 19), controlPoint1: NSPoint(x: 12, y: 22), controlPoint2: NSPoint(x: 15.5, y: 22))
        body.curve(to: NSPoint(x: 17.8, y: 22), controlPoint1: NSPoint(x: 16.7, y: 19.2), controlPoint2: NSPoint(x: 17.4, y: 20.5))
        body.curve(to: NSPoint(x: 18, y: 15), controlPoint1: NSPoint(x: 17.3, y: 18.7), controlPoint2: NSPoint(x: 18, y: 18))
        body.curve(to: NSPoint(x: 12, y: 9), controlPoint1: NSPoint(x: 18, y: 11.5), controlPoint2: NSPoint(x: 15.8, y: 9))
        body.close()
        if active {
            body.windingRule = .evenOdd
            body.append(NSBezierPath(roundedRect: NSRect(x: 10.25, y: 12.5, width: 3.5, height: 6.5), xRadius: 1.75, yRadius: 1.75))
            body.fill()
        } else {
            body.lineWidth = 1.8
            body.lineJoinStyle = .round
            body.stroke()
        }
        let cradle = NSBezierPath()
        cradle.move(to: NSPoint(x: 3.2, y: 15))
        cradle.curve(to: NSPoint(x: 12, y: 5.4), controlPoint1: NSPoint(x: 3.2, y: 8.5), controlPoint2: NSPoint(x: 6.7, y: 5.4))
        cradle.curve(to: NSPoint(x: 20.8, y: 15), controlPoint1: NSPoint(x: 17.3, y: 5.4), controlPoint2: NSPoint(x: 20.8, y: 8.5))
        cradle.move(to: NSPoint(x: 12, y: 5.4))
        cradle.line(to: NSPoint(x: 12, y: 1.7))
        cradle.move(to: NSPoint(x: 7.5, y: 1.7))
        cradle.line(to: NSPoint(x: 16.5, y: 1.7))
        cradle.lineWidth = 1.9
        cradle.lineCapStyle = .round
        cradle.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
    static func menuImage(active: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 20), flipped: false) { rect in
            drawMark(in: rect.insetBy(dx: 1.2, dy: 0.7), color: .black, active: active)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = active ? "Prewarm — microphone warm" : "Prewarm — off"
        return image
    }
    static func deviceImage(kind: String) -> NSImage {
        let symbol: String
        let description: String
        switch kind {
        case "interface": symbol = "hifireceiver"; description = "Audio interface"
        case "usb": symbol = "cable.connector"; description = "USB audio input"
        case "microphone": symbol = "mic"; description = "Microphone"
        case "virtual": symbol = "waveform"; description = "Virtual audio input"
        case "aggregate": symbol = "square.stack"; description = "Aggregate audio input"
        case "builtIn": symbol = "mic"; description = "Built-in microphone"
        case "airpodspro": symbol = "airpodspro"; description = "AirPods Pro audio input"
        case "airpodsmax": symbol = "airpodsmax"; description = "AirPods Max audio input"
        case "airpods": symbol = "airpods"; description = "AirPods audio input"
        case "headphones": symbol = "headphones"; description = "Headphones audio input"
        case "bluetooth": symbol = "headphones"; description = "Bluetooth audio input"
        case "system": symbol = "arrow.triangle.branch"; description = "System default microphone"
        default: symbol = "waveform"; description = "Audio input"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .regular))!
        image.isTemplate = true
        return image
    }
    static func drawAppIcon(in rect: NSRect) {
        let tile = NSBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.065, dy: rect.height * 0.065), xRadius: rect.width * 0.195, yRadius: rect.height * 0.195)
        NSGradient(starting: NSColor(srgbRed: 1, green: 0.71, blue: 0.24, alpha: 1), ending: NSColor(srgbRed: 0.94, green: 0.28, blue: 0.075, alpha: 1))!.draw(in: tile, angle: -75)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(srgbRed: 0.63, green: 0.19, blue: 0.035, alpha: 0.3)
        shadow.shadowBlurRadius = rect.width * 0.032
        shadow.shadowOffset = NSSize(width: 0, height: -rect.height * 0.015)
        shadow.set()
        let mark = NSRect(x: rect.minX + rect.width * 0.265, y: rect.minY + rect.height * 0.215, width: rect.width * 0.47, height: rect.height * 0.57)
        drawMark(in: mark, color: NSColor(srgbRed: 1, green: 0.97, blue: 0.86, alpha: 1))
        NSGraphicsContext.restoreGraphicsState()
    }
}
