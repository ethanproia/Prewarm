import AppKit
import Foundation
import PrewarmCore
let root = CommandLine.arguments[1]
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
app.applicationIconImage = NSImage(contentsOfFile: "\(root)/assets/Prewarm.icns")!
let controller = AboutController(info: ["CFBundleShortVersionString": "0.1.2", "CFBundleVersion": "8"])
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
for (name, appearanceName) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
    panelWindow.appearance = NSAppearance(named: appearanceName)
    RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    panelContent.view.layoutSubtreeIfNeeded()
    let rep = panelContent.view.bitmapImageRepForCachingDisplay(in: panelContent.view.bounds)!
    panelContent.view.effectiveAppearance.performAsCurrentDrawingAppearance {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.windowBackgroundColor.setFill()
        panelContent.view.bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        panelContent.view.cacheDisplay(in: panelContent.view.bounds, to: rep)
    }
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(root)/assets/floating-panel-\(name)-fixture.png"))
    print("NSPanel \(name): frame=\(panelWindow.frame.size), content=\(panelWindow.contentView!.bounds.size), inherited=\(panelContent.view.effectiveAppearance.name.rawValue); fixture only, no visible window")
}
if #available(macOS 26.0, *), let glass = panelWindow.contentView as? NSGlassEffectView {
    precondition(glass.cornerRadius == 0)
    print("NSPanel has one native glass host; inner radius=0, native window owns rounded boundary")
}
