import AppKit
import PrewarmCore

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
        (selected ? NSColor.controlAccentColor : NSColor.quaternaryLabelColor).setFill()
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
        isBordered = false
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
            badge.leadingAnchor.constraint(equalTo: leadingAnchor), badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 28), badge.heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 9), label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: check.leadingAnchor, constant: -8),
            check.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1), check.centerYAnchor.constraint(equalTo: centerYAnchor),
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
    var onPrivacy: (() -> Void)?
    private let warmingSwitch = NSSwitch()
    private let toggleState = NSTextField(labelWithString: "Off")
    private let deviceStack = NSStackView()
    private let status = NSTextField(labelWithString: "Off")
    private var lastRows: [String] = []
    private var enabled = false
    private var selection = ""

    override func loadView() {
        let material = NSVisualEffectView()
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        view = material
        let header = NSTextField(labelWithString: "Prewarm")
        header.font = .systemFont(ofSize: 18, weight: .semibold)
        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")!, target: self, action: #selector(closePanel))
        close.isBordered = false
        close.contentTintColor = .secondaryLabelColor
        let headerRow = NSStackView(views: [header, NSView(), close])
        headerRow.orientation = .horizontal
        close.widthAnchor.constraint(equalToConstant: 18).isActive = true
        close.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let label = NSTextField(labelWithString: "Keep microphone ready")
        label.font = .systemFont(ofSize: 13)
        warmingSwitch.target = self
        warmingSwitch.action = #selector(toggle)
        warmingSwitch.setAccessibilityLabel("Keep microphone ready")
        toggleState.font = .systemFont(ofSize: 11)
        toggleState.textColor = .secondaryLabelColor
        let row = NSView()
        for child in [label, toggleState, warmingSwitch] { child.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(child) }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor), label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggleState.trailingAnchor.constraint(equalTo: warmingSwitch.leadingAnchor, constant: -7), toggleState.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            warmingSwitch.trailingAnchor.constraint(equalTo: row.trailingAnchor), warmingSwitch.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        let micHeader = NSTextField(labelWithString: "Microphone")
        micHeader.font = .systemFont(ofSize: 13, weight: .semibold)
        deviceStack.orientation = .vertical
        deviceStack.alignment = .leading
        deviceStack.spacing = 2
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        let privacy = NSTextField(labelWithString: "Audio is never saved or sent.")
        privacy.font = .systemFont(ofSize: 11)
        privacy.textColor = .secondaryLabelColor
        let footer = NSStackView(views: [status, privacy])
        footer.orientation = .vertical
        footer.alignment = .leading
        footer.spacing = 4
        let about = button("About", action: #selector(about))
        let privacyButton = button("Privacy…", action: #selector(privacySettings))
        let quit = button("Quit", action: #selector(quitApp))
        let spacer = NSView()
        let actions = NSStackView(views: [about, privacyButton, spacer, quit])
        actions.orientation = .horizontal
        actions.spacing = 12
        let stack = NSStackView(views: [headerRow, row, separator(), micHeader, deviceStack, separator(), footer, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(12, after: headerRow)
        stack.setCustomSpacing(4, after: micHeader)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        for wide in [headerRow, row, deviceStack, footer, actions] {
            wide.translatesAutoresizingMaskIntoConstraints = false
            wide.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        for divider in stack.arrangedSubviews.compactMap({ $0 as? NSBox }) { divider.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 300),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
    }
    private func separator() -> NSBox { let box = NSBox(); box.boxType = .separator; return box }
    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.font = .systemFont(ofSize: 11)
        button.contentTintColor = .secondaryLabelColor
        return button
    }
    func update(state: CaptureState?, enabled: Bool, selection: String, missingName: String, missingKind: String) {
        loadViewIfNeeded()
        self.enabled = enabled
        self.selection = selection
        warmingSwitch.state = enabled ? .on : .off
        toggleState.stringValue = enabled ? "On" : "Off"
        if !enabled { status.stringValue = "Off" }
        else if state?.running == true, state?.sampleAge != nil { status.stringValue = "Ready" }
        else if state?.message.contains("access") == true { status.stringValue = "Microphone access required" }
        else if state?.message.contains("sleep") == true { status.stringValue = "Paused" }
        else if state?.targetUID != nil { status.stringValue = "Starting…" }
        else { status.stringValue = "Waiting for microphone" }
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
    @objc private func toggle() { onToggle?() }
    @objc private func selectDevice(_ sender: DeviceRow) { onSelect?(sender.uid, sender.accessibilityLabel() ?? "Microphone", sender.identifier?.rawValue ?? "other") }
    @objc private func about() { onAbout?() }
    @objc private func privacySettings() { onPrivacy?() }
    @objc private func quitApp() { onQuit?() }
}
