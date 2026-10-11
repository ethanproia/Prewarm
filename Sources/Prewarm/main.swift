import AppKit
import AVFoundation
import PrewarmCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let engine = CaptureEngine()
    private var state: CaptureState?
    private let defaults = UserDefaults.standard
    private var enabled: Bool { defaults.bool(forKey: "enabled") }
    private var selection: String { defaults.string(forKey: "microphoneUID") ?? "" }
    private var observers: [NSObjectProtocol] = []
    private var menuOpen = false
    private var settingsWindow: NSWindow?
    private var warmingCheckbox: NSButton?
    private var microphonePopup: NSPopUpButton?
    private var statusLabel: NSTextField?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.ethan.Prewarm"
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) else {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = IconArtwork.menuImage(active: false)
        statusItem.button?.toolTip = "Prewarm — Off"
        engine.onState = { [weak self] state in
            guard let self else { return }
            self.state = state
            self.statusItem.button?.image = IconArtwork.menuImage(active: state.running)
            self.statusItem.button?.toolTip = "Prewarm — \(state.message)"
            self.buildMenu()
            self.refreshSettings()
            self.writeDiagnostics(state)
        }
        buildMenu()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.engine.setSleeping(true) })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.engine.setSleeping(false) })
        apply()
        if !defaults.bool(forKey: "hasShownSettings") {
            defaults.set(true, forKey: "hasShownSettings")
            showSettings()
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        writeDiagnostics(CaptureState(processID: ProcessInfo.processInfo.processIdentifier, updatedAt: Date(), message: "Not running", enabled: enabled, selection: selection, targetUID: nil, targetName: nil, running: false, sampleAge: nil, available: state?.available ?? []))
    }
    private func item(_ title: String, action: Selector? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }
    private func buildMenu() {
        // An open menu must remain stable while the user makes a selection.
        if menuOpen { return }
        let menu = NSMenu()
        menu.delegate = self
        let title = item("Prewarm")
        title.isEnabled = false
        menu.addItem(title)
        let status = item(state?.message ?? "Off")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        let toggle = item("Keep microphone warm", action: #selector(toggleEnabled))
        toggle.state = enabled ? .on : .off
        menu.addItem(toggle)
        let microphone = item("Microphone")
        let submenu = NSMenu()
        let system = item("System default", action: #selector(selectMicrophone(_:)))
        system.representedObject = ""
        system.image = IconArtwork.deviceImage(transport: "system")
        system.state = selection.isEmpty ? .on : .off
        submenu.addItem(system)
        submenu.addItem(.separator())
        for device in (state?.available ?? []).sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let choice = item(device.name, action: #selector(selectMicrophone(_:)))
            choice.representedObject = device.uid
            choice.image = IconArtwork.deviceImage(transport: device.transport.rawValue)
            choice.state = selection == device.uid ? .on : .off
            submenu.addItem(choice)
        }
        if !selection.isEmpty && !(state?.available ?? []).contains(where: { $0.uid == selection }) {
            let missing = item("\(defaults.string(forKey: "microphoneName") ?? "Selected microphone") (disconnected)")
            missing.image = IconArtwork.deviceImage(transport: defaults.string(forKey: "microphoneTransport") ?? "other")
            missing.state = .on
            missing.isEnabled = false
            submenu.addItem(missing)
        }
        microphone.submenu = submenu
        menu.addItem(microphone)
        menu.addItem(.separator())
        let privacy = item("Audio is discarded. Nothing is recorded.")
        privacy.isEnabled = false
        menu.addItem(privacy)
        menu.addItem(item("Settings…", action: #selector(showSettings)))
        menu.addItem(item("Microphone privacy settings…", action: #selector(openPrivacy)))
        menu.addItem(item("About Prewarm…", action: #selector(about)))
        menu.addItem(item("Quit Prewarm", action: #selector(quit)))
        statusItem.menu = menu
    }
    func menuWillOpen(_ menu: NSMenu) { menuOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuOpen = false; DispatchQueue.main.async { self.buildMenu(); self.refreshSettings() } }
    @objc private func toggleEnabled() {
        defaults.set(!enabled, forKey: "enabled")
        apply()
        buildMenu()
        refreshSettings()
    }
    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        defaults.set(uid, forKey: "microphoneUID")
        defaults.set(sender.title, forKey: "microphoneName")
        defaults.set(uid.isEmpty ? "system" : (state?.available.first(where: { $0.uid == uid })?.transport.rawValue ?? "other"), forKey: "microphoneTransport")
        apply()
        buildMenu()
        refreshSettings()
    }
    private func apply() {
        if enabled && AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async { self?.apply() }
            }
        }
        engine.configure(enabled: enabled, selection: selection)
    }
    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 230), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Prewarm Settings"
            window.isReleasedWhenClosed = false
            let title = NSTextField(labelWithString: "Keep your microphone ready")
            title.font = .systemFont(ofSize: 17, weight: .semibold)
            let checkbox = NSButton(checkboxWithTitle: "Keep microphone warm", target: self, action: #selector(toggleEnabled))
            warmingCheckbox = checkbox
            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            popup.menu?.delegate = self
            popup.target = self
            popup.action = #selector(selectPopupMicrophone(_:))
            microphonePopup = popup
            let micRow = NSStackView(views: [NSTextField(labelWithString: "Microphone"), popup])
            micRow.orientation = .horizontal
            micRow.spacing = 12
            let status = NSTextField(wrappingLabelWithString: "Off")
            status.textColor = .secondaryLabelColor
            statusLabel = status
            let privacy = NSTextField(wrappingLabelWithString: "Audio is immediately discarded. Nothing is recorded or sent.")
            privacy.font = .systemFont(ofSize: 11)
            privacy.textColor = .secondaryLabelColor
            let stack = NSStackView(views: [title, checkbox, micRow, status, privacy])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 16
            stack.translatesAutoresizingMaskIntoConstraints = false
            window.contentView!.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
                stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
                stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
                popup.widthAnchor.constraint(equalToConstant: 260),
                privacy.widthAnchor.constraint(equalTo: stack.widthAnchor),
                status.widthAnchor.constraint(equalTo: stack.widthAnchor)
            ])
            window.center()
            settingsWindow = window
        }
        refreshSettings()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func refreshSettings() {
        warmingCheckbox?.state = enabled ? .on : .off
        statusLabel?.stringValue = state?.message ?? "Off"
        guard let popup = microphonePopup else { return }
        // Leave a popup's visible menu stable while tracking a click.
        if menuOpen { return }
        popup.removeAllItems()
        popup.addItem(withTitle: "System default")
        popup.lastItem?.representedObject = ""
        popup.lastItem?.image = IconArtwork.deviceImage(transport: "system")
        for device in (state?.available ?? []).sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            popup.addItem(withTitle: device.name)
            popup.lastItem?.representedObject = device.uid
            popup.lastItem?.image = IconArtwork.deviceImage(transport: device.transport.rawValue)
        }
        if !selection.isEmpty && !(state?.available ?? []).contains(where: { $0.uid == selection }) {
            popup.addItem(withTitle: "\(defaults.string(forKey: "microphoneName") ?? "Selected microphone") (disconnected)")
            popup.lastItem?.representedObject = selection
            popup.lastItem?.image = IconArtwork.deviceImage(transport: defaults.string(forKey: "microphoneTransport") ?? "other")
        }
        if let selected = popup.itemArray.first(where: { ($0.representedObject as? String) == selection }) { popup.select(selected) }
    }
    @objc private func selectPopupMicrophone(_ sender: NSPopUpButton) {
        if let selected = sender.selectedItem { selectMicrophone(selected) }
    }
    @objc private func openPrivacy() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
    }
    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Prewarm"
        alert.informativeText = "Keeps your chosen microphone ready for dictation. Audio is immediately discarded and never saved or sent.\n\nVersion 0.1.0\nBased on macos-mic-keepwarm by Drew Burchfield (MIT)."
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
    private func writeDiagnostics(_ state: CaptureState) {
        // Metadata only, useful for verifying capture and reconnect without audio logging.
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("com.ethan.Prewarm")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(state) { try? data.write(to: directory.appendingPathComponent("status.json"), options: .atomic) }
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
