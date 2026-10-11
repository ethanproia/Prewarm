import AppKit
import SwiftUI
import PrewarmCore

private enum WarmAccent {
    static let color = NSColor(name: "PrewarmWarmAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.87, green: 0.43, blue: 0.13, alpha: 1)
            : NSColor(srgbRed: 0.82, green: 0.39, blue: 0.10, alpha: 1)
    }
}
private final class WarmingState: ObservableObject {
    @Published var isOn = false
    var onChange: ((Bool) -> Void)?
}
private struct WarmingSwitch: SwiftUI.View {
    @ObservedObject var model: WarmingState
    var body: some SwiftUI.View {
        Toggle("Keep microphone ready", isOn: Binding(get: { model.isOn }, set: { model.onChange?($0) }))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Color(nsColor: WarmAccent.color))
    }
}

private final class DeviceBadge: NSView {
    private let imageView = NSImageView()
    var selected = false { didSet { imageView.contentTintColor = selected ? .white : .labelColor; needsDisplay = true } }
    var icon: NSImage? { didSet { imageView.image = icon } }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentTintColor = .labelColor
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor), imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16), imageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        (selected ? WarmAccent.color : NSColor.quaternaryLabelColor).setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}

private final class DeviceRow: NSButton {
    let uid: String
    init(name: String, uid: String, kind: String, selected: Bool, action: Selector, target: AnyObject) {
        self.uid = uid
        super.init(frame: .zero)
        title = ""
        isBordered = true
        bezelStyle = .accessoryBarAction
        showsBorderOnlyWhileMouseInside = true
        focusRingType = .default
        self.target = target
        self.action = action
        setAccessibilityLabel(name)
        setAccessibilityValue(selected ? "Selected" : "Not selected")
        let badge = DeviceBadge(frame: .zero)
        badge.icon = IconArtwork.deviceImage(kind: kind)
        badge.selected = selected
        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        let check = NSImageView(image: NSImage(systemSymbolName: "checkmark", accessibilityDescription: selected ? "Selected" : nil)!)
        check.isHidden = !selected
        for view in [badge, label, check] { view.translatesAutoresizingMaskIntoConstraints = false; addSubview(view) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 36),
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6), badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 28), badge.heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 9), label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: check.leadingAnchor, constant: -8),
            check.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7), check.centerYAnchor.constraint(equalTo: centerYAnchor),
            check.widthAnchor.constraint(equalToConstant: 13), check.heightAnchor.constraint(equalToConstant: 13)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class PrewarmPanel: NSViewController {
    var onClose: (() -> Void)?
    var onToggle: (() -> Void)?
    var onSelect: ((String, String, String) -> Void)?
    var onAbout: (() -> Void)?
    var onQuit: (() -> Void)?
    var onSoundSettings: (() -> Void)?
    var onPrivacy: (() -> Void)?
    private let warmingState = WarmingState()
    private lazy var warmingSwitch = NSHostingView(rootView: WarmingSwitch(model: warmingState))
    private let toggleState = NSTextField(labelWithString: "Off")
    private let deviceStack = NSStackView()
    private let status = NSTextField(labelWithString: "Off")
    private var lastRows: [String] = []
    private var enabled = false
    private var selection = ""

    override func loadView() {
        let content = NSView()
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 16
            glass.contentView = content
            // The container is a backdrop; interactive glass scales the whole panel on press.
            view = glass
        } else {
            let material = NSVisualEffectView()
            material.material = .popover
            material.blendingMode = .behindWindow
            material.state = .active
            material.addSubview(content)
            view = material
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor), content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: view.topAnchor), content.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let header = NSTextField(labelWithString: "Prewarm")
        header.font = .systemFont(ofSize: 13, weight: .semibold)
        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")!, target: self, action: #selector(closePanel))
        close.isBordered = false
        close.contentTintColor = .secondaryLabelColor
        let headerRow = NSStackView(views: [header, NSView(), close])
        headerRow.orientation = .horizontal
        close.widthAnchor.constraint(equalToConstant: 18).isActive = true
        close.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let label = NSTextField(labelWithString: "Keep microphone ready")
        label.font = .systemFont(ofSize: 13)
        warmingState.onChange = { [weak self] _ in self?.onToggle?() }
        warmingSwitch.setAccessibilityLabel("Keep microphone ready")
        toggleState.font = .systemFont(ofSize: 11)
        toggleState.textColor = .secondaryLabelColor
        let row = NSView()
        for child in [label, toggleState, warmingSwitch] { child.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(child) }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor), label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggleState.trailingAnchor.constraint(equalTo: warmingSwitch.leadingAnchor, constant: -7), toggleState.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            warmingSwitch.widthAnchor.constraint(equalToConstant: 38), warmingSwitch.heightAnchor.constraint(equalToConstant: 24),
            warmingSwitch.trailingAnchor.constraint(equalTo: row.trailingAnchor), warmingSwitch.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        let micHeader = NSTextField(labelWithString: "Microphone")
        micHeader.font = .systemFont(ofSize: 13, weight: .semibold)
        deviceStack.orientation = .vertical
        deviceStack.alignment = .leading
        deviceStack.spacing = 2
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        let more = NSButton(image: NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "More")!, target: self, action: #selector(showMore(_:)))
        more.isBordered = false
        more.contentTintColor = .secondaryLabelColor
        more.setAccessibilityLabel("More")
        more.toolTip = "About, microphone privacy, and Quit. Audio is never saved or sent."
        let sound = NSButton(title: "Sound Settings…", target: self, action: #selector(soundSettings))
        sound.isBordered = true
        sound.bezelStyle = .accessoryBarAction
        sound.showsBorderOnlyWhileMouseInside = true
        sound.focusRingType = .default
        sound.font = .systemFont(ofSize: 13)
        sound.alignment = .left
        let actions = NSStackView(views: [sound, NSView(), more])
        actions.orientation = .horizontal
        actions.spacing = 8
        let footer = NSStackView(views: [status, actions])
        footer.orientation = .vertical
        footer.alignment = .leading
        footer.spacing = 6
        actions.widthAnchor.constraint(equalTo: footer.widthAnchor).isActive = true
        more.widthAnchor.constraint(equalToConstant: 22).isActive = true
        more.heightAnchor.constraint(equalToConstant: 22).isActive = true
        let stack = NSStackView(views: [headerRow, row, separator(), micHeader, deviceStack, separator(), footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(12, after: headerRow)
        stack.setCustomSpacing(4, after: micHeader)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        for wide in [headerRow, row, deviceStack, footer] {
            wide.translatesAutoresizingMaskIntoConstraints = false
            wide.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        for divider in stack.arrangedSubviews.compactMap({ $0 as? NSBox }) { divider.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 300),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)
        ])
    }
    private func separator() -> NSBox { let box = NSBox(); box.boxType = .separator; return box }
    @objc private func showMore(_ sender: NSButton) {
        let menu = NSMenu()
        let privacy = NSMenuItem(title: "Audio is never saved or sent.", action: nil, keyEquivalent: "")
        privacy.isEnabled = false
        menu.addItem(privacy)
        menu.addItem(.separator())
        for (title, selector) in [("About Prewarm…", #selector(about)), ("Microphone Privacy…", #selector(privacySettings)), ("Quit Prewarm", #selector(quitApp))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
    }
    func update(state: CaptureState?, enabled: Bool, selection: String, missingName: String, missingKind: String) {
        loadViewIfNeeded()
        self.enabled = enabled
        self.selection = selection
        defer { view.layoutSubtreeIfNeeded(); preferredContentSize = NSSize(width: 300, height: view.fittingSize.height) }
        warmingState.isOn = enabled
        toggleState.stringValue = enabled ? "On" : "Off"
        status.toolTip = state?.message
        status.setAccessibilityHelp(state?.message)
        if !enabled { status.stringValue = "Off" }
        else if state?.running == true, state?.sampleAge != nil { status.stringValue = "Ready" }
        else if state?.message.contains("access") == true { status.stringValue = "Microphone access required" }
        else if state?.message.hasPrefix("Cannot") == true || state?.message.hasPrefix("Microphone unavailable") == true { status.stringValue = "Microphone unavailable" }
        else if state?.message.contains("sleep") == true { status.stringValue = "Paused" }
        else if state?.targetUID != nil { status.stringValue = "Starting…" }
        else { status.stringValue = "Waiting for microphone" }
        status.isHidden = status.stringValue == "Ready" || status.stringValue == "Off"
        var choices = [("System default", "", "system")]
        choices += (state?.available ?? []).sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }).map { ($0.name, $0.uid, $0.iconKind) }
        if !selection.isEmpty && !choices.contains(where: { $0.1 == selection }) { choices.append(("\(missingName) (disconnected)", selection, missingKind)) }
        let fingerprint = choices.map { "\($0.0)|\($0.1)|\($0.2)|\($0.1 == selection)" }
        guard fingerprint != lastRows else { return }
        lastRows = fingerprint
        for row in deviceStack.arrangedSubviews { deviceStack.removeArrangedSubview(row); row.removeFromSuperview() }
        for choice in choices {
            let row = DeviceRow(name: choice.0, uid: choice.1, kind: choice.2, selected: choice.1 == selection, action: #selector(selectDevice(_:)), target: self)
            row.identifier = NSUserInterfaceItemIdentifier(choice.2)
            deviceStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: deviceStack.widthAnchor).isActive = true
        }
        view.layoutSubtreeIfNeeded()
        preferredContentSize = NSSize(width: 300, height: view.fittingSize.height)
    }
    @objc private func closePanel() { onClose?() }
    @objc private func selectDevice(_ sender: DeviceRow) { onSelect?(sender.uid, sender.accessibilityLabel() ?? "Microphone", sender.identifier?.rawValue ?? "other") }
    @objc private func about() { onAbout?() }
    @objc private func soundSettings() { onSoundSettings?() }
    @objc private func privacySettings() { onPrivacy?() }
    @objc private func quitApp() { onQuit?() }
}
