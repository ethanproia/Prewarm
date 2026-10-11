import AppKit
import Foundation
import PrewarmCore
let root = CommandLine.arguments[1]
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
app.applicationIconImage = NSImage(contentsOfFile: "\(root)/assets/Prewarm.icns")!
let controller = AboutController(info: ["CFBundleShortVersionString": "0.1.2", "CFBundleVersion": "6"])
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
let controls = PrewarmMenu()
let devices = [Microphone(uid: "scarlett", name: "Scarlett Solo USB", transport: .usb, manufacturer: "Focusrite"), Microphone(uid: "airpods", name: "Ethan's AirPods Pro", transport: .bluetooth)]
let state = CaptureState(processID: 0, updatedAt: Date(), message: "Warming", enabled: true, selection: "scarlett", targetUID: "scarlett", targetName: "Scarlett Solo USB", running: true, sampleAge: 0, available: devices)
controls.update(state: state, enabled: true, selection: "scarlett", missingName: "Scarlett Solo USB", missingKind: "interface")
precondition(controls.menu.items.allSatisfy { $0.view == nil }, "Every menu item must use macOS's own drawing")
precondition(controls.menu.items.first?.state == .on)
precondition(controls.menu.items.filter(\.isSectionHeader).map(\.title) == ["Microphone"])
let scarlett = controls.menu.items.first { $0.title == "Scarlett Solo USB" }!
precondition(scarlett.state == .on && scarlett.image != nil)
let system = controls.menu.items.first { $0.title == "System default" }!
var selectedUID: String?
controls.onSelect = { uid, _, _ in selectedUID = uid }
precondition(app.sendAction(system.action!, to: system.target, from: system))
precondition(selectedUID == "", "System default must retain its opt-in empty UID")
var toggled = false
controls.onToggle = { toggled = true }
let warming = controls.menu.items[0]
precondition(app.sendAction(warming.action!, to: warming.target, from: warming) && toggled)
controls.update(state: nil, enabled: false, selection: "scarlett", missingName: "Scarlett Solo USB", missingKind: "interface")
precondition(controls.menu.items.first?.state == .off)
precondition(controls.menu.items.first { $0.title == "Scarlett Solo USB (disconnected)" }?.state == .on)
precondition(controls.menu.items.last?.keyEquivalent == "q")
print("Standard NSMenu fixture: no custom item views; native action routing, on/off, selected device, disconnected override and System default UID checked. No capture or visible menu opened.")
