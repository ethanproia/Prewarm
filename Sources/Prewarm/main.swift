import AppKit
import AVFoundation
import PrewarmCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let engine = CaptureEngine()
    private var state: CaptureState?
    private let defaults = UserDefaults.standard
    private var enabled = false
    private let loginSettings = LoginSettings()
    private var selection: String { defaults.string(forKey: "microphoneUID") ?? "" }
    private var observers: [NSObjectProtocol] = []
    private var aboutWindow: NSWindow?
    private lazy var controls = makePanel()
    private lazy var panelHost = makePanelHost()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.ethan.Prewarm"
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) else { NSApp.terminate(nil); return }
        let loginLaunch = LoginSettings.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        enabled = StartupPolicy.initialEnabled(isLoginLaunch: loginLaunch, enableAtLogin: loginSettings.enableAtLogin, savedEnabled: defaults.bool(forKey: "enabled"))
        NSApp.setActivationPolicy(.accessory)
        if let iconURL = Bundle.main.url(forResource: "Prewarm", withExtension: "icns"), let icon = NSImage(contentsOf: iconURL) { NSApp.applicationIconImage = icon }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if #available(macOS 27.0, *) {
            statusItem.expandedInterfaceDelegate = self
        } else {
            statusItem.button?.setButtonType(.toggle)
            (statusItem.button?.cell as? NSButtonCell)?.showsStateBy = .changeBackgroundCellMask
            statusItem.button?.target = self
            statusItem.button?.action = #selector(togglePanel)
        }
        statusItem.button?.image = IconArtwork.menuImage(active: false)
        statusItem.button?.toolTip = "Prewarm — Off"
        engine.onState = { [weak self] state in
            guard let self else { return }
            self.state = state
            self.statusItem.button?.image = IconArtwork.menuImage(active: state.running)
            self.statusItem.button?.toolTip = "Prewarm — \(state.message)"
            self.refreshPanel()
            self.writeDiagnostics(state)
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.engine.setSleeping(true) })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.engine.setSleeping(false) })
        apply()
        refreshPanel()
        if !loginLaunch && !defaults.bool(forKey: "hasShownSettings") {
            defaults.set(true, forKey: "hasShownSettings")
            DispatchQueue.main.async { [weak self] in self?.showPanel() }
        }
    }
    private func makePanelHost() -> PrewarmPanelHost {
        let host = PrewarmPanelHost(content: controls)
        host.onDismiss = { [weak self] in
            guard let self else { return }
            if #available(macOS 27.0, *), let session = self.statusItem.expandedInterfaceSession { session.cancel() }
            else { self.panelHost.hide() }
        }
        host.onDidHide = { [weak self] in
            if #available(macOS 27.0, *) { self?.statusItem.expandedInterfaceSession?.cancel() }
        }
        return host
    }
    private func makePanel() -> PrewarmPanel {
        let controls = PrewarmPanel()
        controls.onToggle = { [weak self] in self?.toggleEnabled() }
        controls.onSelect = { [weak self] uid, name, kind in self?.selectMicrophone(uid: uid, name: name, kind: kind) }
        controls.onAbout = { [weak self] in self?.about() }
        controls.onSoundSettings = { [weak self] in
            self?.panelHost.dismiss()
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension?input")!)
        }
        controls.onPrivacy = { [weak self] in self?.panelHost.dismiss(); self?.openPrivacy() }
        controls.onQuit = { NSApp.terminate(nil) }
        controls.addLoginItems = { [weak self] menu in self?.loginSettings.addItems(to: menu) }
        return controls
    }
    private func refreshPanel() {
        let name = defaults.string(forKey: "microphoneName") ?? "Selected microphone"
        let kind = defaults.string(forKey: "microphoneIconKind") ?? defaults.string(forKey: "microphoneTransport") ?? "other"
        controls.update(state: state, enabled: enabled, selection: selection, missingName: name, missingKind: kind)
        panelHost.refreshSize()
    }
    @objc private func togglePanel() { if panelHost.isShown { panelHost.dismiss() } else { showPanel() } }
    private func showPanel() {
        if #available(macOS 27.0, *) {
            if statusItem.expandedInterfaceSession == nil { statusItem.button?.performClick(nil) }
        } else { presentPanel() }
    }
    private func presentPanel() { guard let button = statusItem.button else { return }; refreshPanel(); panelHost.show(below: button) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return true }
    private func toggleEnabled() { enabled.toggle(); defaults.set(enabled, forKey: "enabled"); apply(); refreshPanel() }
    private func selectMicrophone(uid: String, name: String, kind: String) {
        defaults.set(uid, forKey: "microphoneUID")
        defaults.set(name, forKey: "microphoneName")
        defaults.set(kind, forKey: "microphoneIconKind")
        apply()
        refreshPanel()
    }
    private func apply() {
        if enabled && AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in DispatchQueue.main.async { self?.apply() } }
        }
        engine.configure(enabled: enabled, selection: selection)
    }
    private func openPrivacy() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }
    private func about() {
        panelHost.dismiss()
        if aboutWindow == nil {
            let controller = AboutController()
            let window = PrewarmWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 1), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "About Prewarm"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentViewController = controller
            controller.view.layoutSubtreeIfNeeded()
            window.setContentSize(controller.view.fittingSize)
            window.center()
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
@available(macOS 27.0, *)
extension AppDelegate: NSStatusItemExpandedInterfaceDelegate {
    func statusItem(_ statusItem: NSStatusItem, didBegin expandedInterfaceSession: NSStatusItemExpandedInterfaceSession) { presentPanel() }
    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) { panelHost.hide() }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
