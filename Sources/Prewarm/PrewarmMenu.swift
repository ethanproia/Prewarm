import AppKit

/// Ordinary menu items let macOS own layout, selection, hover and keyboard behavior.
final class PrewarmMenu: NSObject {
    let menu = NSMenu()
    var onToggle: (() -> Void)?
    var onSelect: ((String, String, String) -> Void)?
    var onSoundSettings: (() -> Void)?
    var onAbout: (() -> Void)?
    var onPrivacy: (() -> Void)?
    var onQuit: (() -> Void)?
    private struct Choice { let name: String; let uid: String; let kind: String; var disconnected = false }

    override init() { super.init(); menu.autoenablesItems = false }
    func update(state: CaptureState?, enabled: Bool, selection: String, missingName: String, missingKind: String) {
        menu.removeAllItems()
        let warming = item("Keep Microphone Warm", action: #selector(toggle))
        warming.state = enabled ? .on : .off
        warming.toolTip = enabled ? "On — click to release the microphone" : "Off — click to keep the microphone active"
        if enabled && !(state?.running == true && state?.sampleAge != nil) {
            let status = item(state?.enabled == true ? state?.message ?? "Starting…" : "Starting…", action: nil)
            status.isEnabled = false
        }
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Microphone"))
        var choices = [Choice(name: "System default", uid: "", kind: "system")]
        choices += (state?.available ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { Choice(name: $0.name, uid: $0.uid, kind: $0.iconKind) }
        if !selection.isEmpty && !choices.contains(where: { $0.uid == selection }) {
            choices.append(Choice(name: missingName, uid: selection, kind: missingKind, disconnected: true))
        }
        for choice in choices {
            let row = item(choice.name + (choice.disconnected ? " (disconnected)" : ""), action: #selector(select(_:)))
            row.representedObject = choice
            row.state = choice.uid == selection ? .on : .off
            row.image = IconArtwork.deviceImage(kind: choice.kind)
        }
        menu.addItem(.separator())
        item("Sound Settings…", action: #selector(soundSettings))
        item("About Prewarm…", action: #selector(about))
        let privacy = item("Microphone Privacy…", action: #selector(privacySettings))
        privacy.toolTip = "Audio is never saved or sent. Opens macOS microphone permissions."
        menu.addItem(.separator())
        item("Quit Prewarm", action: #selector(quit), key: "q")
    }
    @discardableResult private func item(_ title: String, action: Selector?, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }
    @objc private func toggle() { onToggle?() }
    @objc private func select(_ item: NSMenuItem) {
        guard let choice = item.representedObject as? Choice else { return }
        onSelect?(choice.uid, choice.name, choice.kind)
    }
    @objc private func soundSettings() { onSoundSettings?() }
    @objc private func about() { onAbout?() }
    @objc private func privacySettings() { onPrivacy?() }
    @objc private func quit() { onQuit?() }
}
