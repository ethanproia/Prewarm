import AppKit
import AVFoundation
import PrewarmCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let engine = CaptureEngine()
    private var state: CaptureState?
    private let defaults = UserDefaults.standard
    private var enabled: Bool { defaults.bool(forKey: "enabled") }
    private var selection: String { defaults.string(forKey: "microphoneUID") ?? "" }
    private var observers: [NSObjectProtocol] = []
    private var settingsWindow: NSWindow?
    private let popover = NSPopover()
    private lazy var popoverPanel = makePanel()
    private lazy var windowPanel = makePanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.ethan.Prewarm"
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) else { NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = IconArtwork.menuImage(active: false)
        statusItem.button?.toolTip = "Prewarm — Off"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.contentViewController = popoverPanel
        popoverPanel.onClose = { [weak self] in self?.popover.performClose(nil) }
        windowPanel.onClose = { [weak self] in self?.settingsWindow?.orderOut(nil) }
        engine.onState = { [weak self] state in
            guard let self else { return }
            self.state = state
            self.statusItem.button?.image = IconArtwork.menuImage(active: state.running)
            self.statusItem.button?.toolTip = "Prewarm — \(state.message)"
            self.refreshPanels()
            self.writeDiagnostics(state)
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.engine.setSleeping(true) })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.engine.setSleeping(false) })
        apply()
        refreshPanels()
        if !defaults.bool(forKey: "hasShownSettings") { defaults.set(true, forKey: "hasShownSettings"); showSettings() }
    }
    private func makePanel() -> PrewarmPanel {
        let panel = PrewarmPanel()
        panel.onToggle = { [weak self] in self?.toggleEnabled() }
        panel.onSelect = { [weak self] uid, name, kind in self?.selectMicrophone(uid: uid, name: name, kind: kind) }
        panel.onAbout = { [weak self] in self?.about() }
        panel.onPrivacy = { [weak self] in self?.openPrivacy() }
        panel.onQuit = { NSApp.terminate(nil) }
        return panel
    }
    private func refreshPanels() {
        let name = defaults.string(forKey: "microphoneName") ?? "Selected microphone"
        let kind = defaults.string(forKey: "microphoneIconKind") ?? defaults.string(forKey: "microphoneTransport") ?? "other"
        for panel in [popoverPanel, windowPanel] { panel.update(state: state, enabled: enabled, selection: selection, missingName: name, missingKind: kind) }
        popover.contentSize = popoverPanel.preferredContentSize
        if let window = settingsWindow { window.setContentSize(windowPanel.preferredContentSize) }
    }
    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { refreshPanels(); popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Prewarm"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            // One visible header, shared with the popover. Leave room for native close.
            window.contentViewController = windowPanel
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            settingsWindow = window
            refreshPanels()
            window.center()
        }
        refreshPanels()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func toggleEnabled() { defaults.set(!enabled, forKey: "enabled"); apply(); refreshPanels() }
    private func selectMicrophone(uid: String, name: String, kind: String) {
        defaults.set(uid, forKey: "microphoneUID")
        defaults.set(name, forKey: "microphoneName")
        defaults.set(kind, forKey: "microphoneIconKind")
        apply()
        refreshPanels()
    }
    private func apply() {
        if enabled && AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in DispatchQueue.main.async { self?.apply() } }
        }
        engine.configure(enabled: enabled, selection: selection)
    }
    private func openPrivacy() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }
    private func about() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Prewarm"
        alert.informativeText = "Keeps your chosen microphone ready for dictation. Audio is never saved or sent.\n\nVersion 0.1.0\nBased on macos-mic-keepwarm by Drew Burchfield (MIT)."
        alert.runModal()
    }
    func applicationWillTerminate(_ notification: Notification) {
        writeDiagnostics(CaptureState(processID: ProcessInfo.processInfo.processIdentifier, updatedAt: Date(), message: "Not running", enabled: enabled, selection: selection, targetUID: nil, targetName: nil, running: false, sampleAge: nil, available: state?.available ?? []))
    }
    private func writeDiagnostics(_ state: CaptureState) {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("com.ethan.Prewarm")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(state) { try? data.write(to: directory.appendingPathComponent("status.json"), options: .atomic) }
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
