import AppKit
import Foundation
import PrewarmCore
let root = CommandLine.arguments[1]
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
app.applicationIconImage = NSImage(contentsOfFile: "\(root)/assets/Prewarm.icns")!
let controller = AboutController(info: ["CFBundleShortVersionString": "0.1.2", "CFBundleVersion": "5"])
let window = PrewarmWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 460), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
window.contentViewController = controller
let panel = PrewarmPanel()
let panelWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
panelWindow.backgroundColor = .windowBackgroundColor
panelWindow.contentViewController = panel
func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
func save(_ view: NSView, _ name: String) throws {
    view.layoutSubtreeIfNeeded()
    let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.effectiveAppearance.performAsCurrentDrawingAppearance {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.windowBackgroundColor.setFill()
        view.bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        view.cacheDisplay(in: view.bounds, to: rep)
    }
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(root)/assets/\(name)-fixture.png"))
}
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
    print("About \(name): fit=\(size), inherited=\(controller.view.effectiveAppearance.name.rawValue); offscreen control fixture, not live glass backdrop")

    panelWindow.appearance = NSAppearance(named: appearanceName)
    panelWindow.makeFirstResponder(nil)
    let devices = [Microphone(uid: "scarlett", name: "Scarlett Solo USB", transport: .usb, manufacturer: "Focusrite"), Microphone(uid: "airpods", name: "Ethan's AirPods Pro", transport: .bluetooth)]
    func update(message: String, running: Bool, enabled: Bool = true, selection: String = "scarlett") {
        let state = CaptureState(processID: 0, updatedAt: Date(), message: message, enabled: enabled, selection: selection, targetUID: "scarlett", targetName: "Scarlett Solo USB", running: running, sampleAge: running ? 0 : nil, available: devices)
        panel.update(state: state, enabled: enabled, selection: selection, missingName: "Scarlett Solo USB", missingKind: "interface")
        panelWindow.setContentSize(panel.preferredContentSize)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        panel.view.layoutSubtreeIfNeeded()
    }
    update(message: "Warming", running: true)
    try save(panel.view, "panel-\(name)")
    let readySize = panel.preferredContentSize
    let children = descendants(panel.view)
    let hovered = children.compactMap { $0 as? NSButton }.first { $0.accessibilityLabel() == "System default" }!
    precondition(hovered.subviews.first?.frame.minX == 0, "Device badge must align with the section leading edge")
    let selectedBefore = hovered.accessibilityValue() as? String
    hovered.mouseEntered(with: NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panelWindow.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!)
    try save(panel.view, "panel-\(name)-hover")
    precondition(hovered.accessibilityValue() as? String == selectedBefore)
    hovered.mouseExited(with: NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panelWindow.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!)
    precondition(panelWindow.makeFirstResponder(hovered), "Native microphone button must accept keyboard focus")
    precondition(hovered.focusRingMaskBounds == hovered.bounds)
    // Offscreen windows cannot show key-window focus automatically; draw AppKit's focus-ring mask explicitly.
    let focusRep = hovered.bitmapImageRepForCachingDisplay(in: hovered.bounds)!
    hovered.effectiveAppearance.performAsCurrentDrawingAppearance {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: focusRep)
        NSFocusRingPlacement.only.set()
        hovered.drawFocusRingMask()
        NSGraphicsContext.restoreGraphicsState()
    }
    try focusRep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(root)/assets/row-\(name)-focus-mask-fixture.png"))
    panel.onSelect = { uid, _, _ in update(message: "Warming", running: true, selection: uid) }
    hovered.performClick(nil)
    let focusedAfter = panelWindow.firstResponder as? NSButton
    precondition(focusedAfter?.accessibilityLabel() == "System default" && focusedAfter?.accessibilityValue() as? String == "Selected", "Device selection must preserve the focused UID across row rebuild")
    update(message: "Warming", running: true)
    panelWindow.makeFirstResponder(nil)
    let rowRects = descendants(panel.view).compactMap { $0 as? NSButton }.filter { $0.accessibilityValue() != nil }.map { $0.convert($0.bounds, to: panel.view) }
    let dividers = children.compactMap { $0 as? NSBox }.map { $0.convert($0.bounds, to: panel.view) }
    let rowBottom = rowRects.map(\.minY).min()!
    let bottomDivider = dividers.min(by: { $0.minY < $1.minY })!
    update(message: "Microphone access required", running: false)
    let errorSize = panel.preferredContentSize
    try save(panel.view, "panel-\(name)-error")
    update(message: "Off", running: false, enabled: false)
    precondition(panel.preferredContentSize == readySize, "Hidden normal status must reclaim its space")
    print("Panel \(name): ready/off=\(readySize), error=\(errorSize), last row-divider gap=\(rowBottom - bottomDivider.maxY), hover bounds=\(hovered.bounds); fixture only, no capture")
}
