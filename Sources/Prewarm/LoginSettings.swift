import AppKit
import CoreServices
import ServiceManagement

final class LoginSettings: NSObject {
    private let defaults: UserDefaults
    private let service = SMAppService.mainApp
    init(defaults: UserDefaults = .standard) { self.defaults = defaults; super.init() }
    var enableAtLogin: Bool { defaults.bool(forKey: "enableAtLogin") }

    // Read synchronously in applicationDidFinishLaunching, while the launch event is current.
    static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        event?.eventClass == kCoreEventClass && event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
    func addItems(to menu: NSMenu) {
        let status = service.status
        let open = NSMenuItem(title: "Open at Login", action: #selector(toggleOpen), keyEquivalent: "")
        open.target = self
        open.state = status == .enabled ? .on : status == .requiresApproval ? .mixed : .off
        open.toolTip = "Launch Prewarm when you log in."
        menu.addItem(open)
        let enable = NSMenuItem(title: "Enable at Login", action: #selector(toggleEnable), keyEquivalent: "")
        enable.target = self
        enable.state = enableAtLogin ? .on : .off
        enable.isEnabled = status == .enabled
        enable.toolTip = enable.isEnabled ? "Keep the selected microphone warm at login. Current warming is unchanged." : "Turn on Open at Login first."
        menu.addItem(enable)
        if status == .requiresApproval || status == .notFound {
            let settings = NSMenuItem(title: "Login Items Settings…", action: #selector(openSettings), keyEquivalent: "")
            settings.target = self
            settings.toolTip = status == .requiresApproval ? "Approve Prewarm in macOS Login Items." : "Check the installed app's login item in System Settings."
            menu.addItem(settings)
        }
    }
    @objc private func toggleOpen() {
        do {
            if service.status == .enabled || service.status == .requiresApproval { try service.unregister() }
            else { try service.register() }
            if service.status == .requiresApproval {
                showNotice(title: "Open at Login needs approval", message: "Enable Prewarm in macOS Login Items to finish turning this on.")
            }
        } catch {
            showNotice(title: "Couldn't change Open at Login", message: "\(error.localizedDescription)\n\nUse the installed Prewarm app and check Login Items in System Settings.")
        }
    }
    @objc private func toggleEnable() {
        guard service.status == .enabled else { return }
        defaults.set(!enableAtLogin, forKey: "enableAtLogin")
    }
    @objc private func openSettings() { SMAppService.openSystemSettingsLoginItems() }
    private func showNotice(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Open Login Items…")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn { openSettings() }
    }
}
