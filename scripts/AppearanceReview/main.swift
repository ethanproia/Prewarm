import AppKit
import Foundation
import PrewarmCore
let root = CommandLine.arguments[1]
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
app.applicationIconImage = NSImage(contentsOfFile: "\(root)/assets/Prewarm.icns")!
let controller = AboutController(info: ["CFBundleShortVersionString": "0.1.2", "CFBundleVersion": "11"])
let window = PrewarmWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 460), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
window.contentViewController = controller
for (name, appearanceName) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
    window.appearance = NSAppearance(named: appearanceName)
    controller.view.layoutSubtreeIfNeeded()
    let size = controller.view.fittingSize
    window.setContentSize(size)
    RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    controller.view.layoutSubtreeIfNeeded()
    let rep = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds)!
    controller.view.cacheDisplay(in: controller.view.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(root)/assets/about-\(name)-fixture.png"))
    print("About \(name): fit=\(size), inherited=\(controller.view.effectiveAppearance.name.rawValue); offscreen fixture, not live glass backdrop")
}
let devices = [Microphone(uid: "scarlett", name: "Scarlett Solo USB", transport: .usb, manufacturer: "Focusrite"), Microphone(uid: "airpods", name: "Ethan's AirPods Pro", transport: .bluetooth)]
let state = CaptureState(processID: 0, updatedAt: Date(), message: "Warming", enabled: true, selection: "scarlett", targetUID: "scarlett", targetName: "Scarlett Solo USB", running: true, sampleAge: 0, available: devices)
let panelContent = PrewarmPanel()
panelContent.update(state: state, enabled: true, selection: "scarlett", missingName: "Scarlett Solo USB", missingKind: "interface")
let host = PrewarmPanelHost(content: panelContent)
host.refreshSize()
let panelWindow = panelContent.view.window!
precondition(panelWindow is NSPanel)
precondition(panelWindow.styleMask.contains(.fullSizeContentView))
precondition(panelWindow.standardWindowButton(.closeButton)?.isHidden != false)
print("Initial panel sizing: frame=\(panelWindow.frame.size), content=\(panelWindow.contentView!.bounds.size), expected=\(panelContent.preferredContentSize)")
precondition(panelWindow.contentView!.bounds.size == panelContent.preferredContentSize)
RunLoop.current.run(until: Date().addingTimeInterval(0.05))
panelContent.view.layoutSubtreeIfNeeded()
func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
let children = descendants(panelContent.view)
let deviceRow = children.compactMap { $0 as? NSButton }.first { $0.accessibilityLabel() == "System default" }!
let soundButton = children.compactMap { $0 as? NSButton }.first { $0.accessibilityLabel() == "Sound Settings…" }!
let moreButton = children.compactMap { $0 as? NSButton }.first { $0.accessibilityLabel() == "More" }!
let section = children.compactMap { $0 as? NSTextField }.first { $0.stringValue == "Microphone" }!
let headerRect = section.convert(section.alignmentRect(forFrame: section.bounds), to: panelContent.view)
let rowRect = deviceRow.convert(deviceRow.bounds, to: panelContent.view)
let badge = deviceRow.subviews[0]
precondition(deviceRow.bounds.height == 32 && badge.frame.size == NSSize(width: 26, height: 26))
precondition(badge.frame.minX == 9 && badge.frame.minY == 3)
precondition(badge.convert(badge.bounds, to: panelContent.view).minX == headerRect.minX)
precondition(rowRect.minX == headerRect.minX - 9 && rowRect.maxX == headerRect.maxX + 9)
let hoverHit = panelContent.view.hitTest(deviceRow.convert(NSPoint(x: 1, y: 16), to: panelContent.view))
precondition(hoverHit === deviceRow, "Expanded padding must be part of the actual native button hit area")
let soundRect = soundButton.convert(soundButton.bounds, to: panelContent.view)
let moreRect = moreButton.convert(moreButton.bounds, to: panelContent.view)
precondition(soundRect.minX == rowRect.minX && soundRect.height == 22 && moreRect.minX - soundRect.maxX == 6)
let soundLabel = soundButton.subviews[0]
precondition(soundLabel.convert(soundLabel.alignmentRect(forFrame: soundLabel.bounds), to: panelContent.view).minX == headerRect.minX)
let hoverEvent = NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panelWindow.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
func savePanel(_ filename: String) throws {
    let rep = panelContent.view.bitmapImageRepForCachingDisplay(in: panelContent.view.bounds)!
    panelContent.view.effectiveAppearance.performAsCurrentDrawingAppearance {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.windowBackgroundColor.setFill()
        panelContent.view.bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        panelContent.view.cacheDisplay(in: panelContent.view.bounds, to: rep)
    }
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(root)/assets/\(filename).png"))
}
for (name, appearanceName) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
    panelWindow.appearance = NSAppearance(named: appearanceName)
    RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    panelContent.view.layoutSubtreeIfNeeded()
    deviceRow.mouseEntered(with: hoverEvent)
    try savePanel("floating-panel-\(name)-fixture")
    deviceRow.mouseExited(with: hoverEvent)
    soundButton.mouseEntered(with: hoverEvent)
    try savePanel("floating-panel-\(name)-settings-hover-fixture")
    soundButton.mouseExited(with: hoverEvent)
    print("NSPanel \(name): frame=\(panelWindow.frame.size), content=\(panelWindow.contentView!.bounds.size), inherited=\(panelContent.view.effectiveAppearance.name.rawValue); fixture only, no visible window")
}
if #available(macOS 26.0, *), let glass = panelWindow.contentView as? NSGlassEffectView {
    precondition(glass.cornerRadius == 0)
    print("NSPanel has one native glass host; inner radius=0, native window owns rounded boundary")
}
