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

private class HoverButton: NSButton {
    private var hovering = false
    private var hoverArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = hoverArea { removeTrackingArea(old) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if hovering || isHighlighted {
            let fill = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
                ? NSColor.controlBackgroundColor : NSColor.labelColor.withAlphaComponent(isHighlighted ? 0.13 : 0.07)
            fill.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9).fill()
        }
        super.draw(dirtyRect)
    }
    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9).fill() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}

private final class DeviceRow: HoverButton {
    let uid: String
    init(name: String, uid: String, kind: String, selected: Bool, action: Selector, target: AnyObject) {
        self.uid = uid
        super.init(frame: .zero)
        title = ""
        isBordered = false
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
            heightAnchor.constraint(equalToConstant: 32),
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9), badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 26), badge.heightAnchor.constraint(equalToConstant: 26),
            label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 8), label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: check.leadingAnchor, constant: -8),
            check.centerXAnchor.constraint(equalTo: trailingAnchor, constant: -23), check.centerYAnchor.constraint(equalTo: centerYAnchor),
            check.widthAnchor.constraint(equalToConstant: 13), check.heightAnchor.constraint(equalToConstant: 13)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class PrewarmPanel: NSViewController {
    var onToggle: (() -> Void)?
    var onSelect: ((String, String, String) -> Void)?
    var onAbout: (() -> Void)?
    var onQuit: (() -> Void)?
    var onSoundSettings: (() -> Void)?
    var onPrivacy: (() -> Void)?
    var addLoginItems: ((NSMenu) -> Void)?
    private let warmingState = WarmingState()
    private lazy var warmingSwitch = NSHostingView(rootView: WarmingSwitch(model: warmingState))
    private let deviceStack = NSStackView()
    private var contentStack: NSStackView!
    private let status = NSTextField(labelWithString: "Off")
    private var lastRows: [String] = []

    override func loadView() {
        let content = NSView()
        view = content
        let header = NSTextField(labelWithString: "Prewarm")
        header.font = .systemFont(ofSize: 13, weight: .semibold)
        header.textColor = .secondaryLabelColor
        warmingState.onChange = { [weak self] _ in self?.onToggle?() }
        warmingSwitch.setAccessibilityLabel("Keep microphone ready")
        let headerRow = NSView()
        for child in [header, warmingSwitch] { child.translatesAutoresizingMaskIntoConstraints = false; headerRow.addSubview(child) }
        NSLayoutConstraint.activate([
            headerRow.heightAnchor.constraint(equalToConstant: 28),
            header.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor), header.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            warmingSwitch.widthAnchor.constraint(equalToConstant: 38), warmingSwitch.heightAnchor.constraint(equalToConstant: 24),
            warmingSwitch.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor), warmingSwitch.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor)
        ])
        deviceStack.orientation = .vertical
        deviceStack.distribution = .fill
        deviceStack.setHuggingPriority(.required, for: .vertical)
        deviceStack.alignment = .leading
        deviceStack.spacing = 0
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        let more = NSButton(image: NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "More")!, target: self, action: #selector(showMore(_:)))
        more.isBordered = false
        more.contentTintColor = .secondaryLabelColor
        more.setAccessibilityLabel("More")
        more.toolTip = "Login settings, About, microphone privacy, and Quit."
        let sound = HoverButton(frame: .zero)
        sound.title = ""
        sound.target = self
        sound.action = #selector(soundSettings)
        sound.setAccessibilityLabel("Sound Settings…")
        sound.isBordered = false
        sound.focusRingType = .default
        let soundLabel = NSTextField(labelWithString: "Sound Settings…")
        soundLabel.font = .systemFont(ofSize: 13)
        soundLabel.translatesAutoresizingMaskIntoConstraints = false
        sound.addSubview(soundLabel)
        let actions = NSView()
        for button in [sound, more] { button.translatesAutoresizingMaskIntoConstraints = false; actions.addSubview(button) }
        NSLayoutConstraint.activate([
            actions.heightAnchor.constraint(equalToConstant: 28),
            sound.leadingAnchor.constraint(equalTo: actions.leadingAnchor), sound.trailingAnchor.constraint(equalTo: more.leadingAnchor, constant: -6),
            sound.centerYAnchor.constraint(equalTo: actions.centerYAnchor), sound.heightAnchor.constraint(equalToConstant: 22),
            soundLabel.leadingAnchor.constraint(equalTo: sound.leadingAnchor, constant: 9), soundLabel.centerYAnchor.constraint(equalTo: sound.centerYAnchor),
            more.trailingAnchor.constraint(equalTo: actions.trailingAnchor, constant: -9), more.centerYAnchor.constraint(equalTo: actions.centerYAnchor)
        ])
        let footer = NSStackView(views: [status, actions])
        footer.orientation = .vertical
        footer.distribution = .fill
        footer.detachesHiddenViews = true
        footer.alignment = .centerX
        footer.spacing = 6
        actions.widthAnchor.constraint(equalTo: footer.widthAnchor).isActive = true
        status.widthAnchor.constraint(equalTo: footer.widthAnchor, constant: -18).isActive = true
        more.widthAnchor.constraint(equalToConstant: 28).isActive = true
        more.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let headerDivider = separator()
        let stack = NSStackView(views: [headerRow, headerDivider, deviceStack, separator(), footer])
        contentStack = stack
        stack.orientation = .vertical
        stack.distribution = .fill
        stack.setHuggingPriority(.required, for: .vertical)
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(12, after: headerRow)
        stack.setCustomSpacing(12, after: headerDivider)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -18).isActive = true
        deviceStack.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        footer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        for divider in stack.arrangedSubviews.compactMap({ $0 as? NSBox }) { divider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -18).isActive = true }
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 300),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 7),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -7),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)
        ])
    }
    private func separator() -> NSBox { let box = NSBox(); box.boxType = .separator; return box }
    @objc private func showMore(_ sender: NSButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        if let addLoginItems { addLoginItems(menu); menu.addItem(.separator()) }
        for (title, selector) in [("About Prewarm…", #selector(about)), ("Microphone Privacy…", #selector(privacySettings)), ("Quit Prewarm", #selector(quitApp))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
    }
    func update(state: CaptureState?, enabled: Bool, selection: String, missingName: String, missingKind: String) {
        loadViewIfNeeded()
        defer { updatePreferredSize() }
        warmingState.isOn = enabled
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
        let defaultIcon = CapturePolicy.systemDefaultIcon(defaultUID: state?.systemDefaultUID, available: state?.available ?? [])
        var choices = [("System default", "", defaultIcon)]
        choices += (state?.available ?? []).sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }).map { ($0.name, $0.uid, $0.iconKind) }
        if !selection.isEmpty && !choices.contains(where: { $0.1 == selection }) { choices.append(("\(missingName) (disconnected)", selection, missingKind)) }
        let fingerprint = choices.map { "\($0.0)|\($0.1)|\($0.2)|\($0.1 == selection)" }
        guard fingerprint != lastRows else { return }
        lastRows = fingerprint
        var focusedUID: String?
        if let focused = view.window?.firstResponder as? DeviceRow,
           deviceStack.arrangedSubviews.contains(focused) { focusedUID = focused.uid }
        for row in deviceStack.arrangedSubviews { deviceStack.removeArrangedSubview(row); row.removeFromSuperview() }
        for choice in choices {
            let row = DeviceRow(name: choice.0, uid: choice.1, kind: choice.2, selected: choice.1 == selection, action: #selector(selectDevice(_:)), target: self)
            row.identifier = NSUserInterfaceItemIdentifier(choice.2)
            deviceStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: deviceStack.widthAnchor).isActive = true
        }
        if let uid = focusedUID,
           let row = deviceStack.arrangedSubviews.compactMap({ $0 as? DeviceRow }).first(where: { $0.uid == uid }) {
            view.window?.makeFirstResponder(row)
        }
    }
    private func updatePreferredSize() {
        contentStack.layoutSubtreeIfNeeded()
        preferredContentSize = NSSize(width: 300, height: ceil(contentStack.fittingSize.height) + 28)
        view.setFrameSize(preferredContentSize)
        view.layoutSubtreeIfNeeded()
    }
    @objc private func selectDevice(_ sender: DeviceRow) { onSelect?(sender.uid, sender.accessibilityLabel() ?? "Microphone", sender.identifier?.rawValue ?? "other") }
    @objc private func about() { onAbout?() }
    @objc private func soundSettings() { onSoundSettings?() }
    @objc private func privacySettings() { onPrivacy?() }
    @objc private func quitApp() { onQuit?() }
}
