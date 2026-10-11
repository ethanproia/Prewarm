import AppKit

final class AboutController: NSViewController {
    override func loadView() {
        let content = NSView()
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 20
            glass.contentView = content
            view = glass
        } else {
            let material = NSVisualEffectView()
            material.material = .hudWindow
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
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 100).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 100).isActive = true
        let title = label("Prewarm", size: 24, weight: .semibold)
        let description = label("Keeps your microphone ready for dictation.", size: 13)
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = info["CFBundleVersion"] as? String ?? "Unknown"
        let versionLabel = label("Version \(version) (\(build))", size: 11, color: .secondaryLabelColor)
        let author = label("By Ethan Proia", size: 12)
        let docs = NSButton(title: "Documentation", target: self, action: #selector(openDocs))
        let upstream = NSButton(title: "Upstream", target: self, action: #selector(openUpstream))
        for button in [docs, upstream] { button.bezelStyle = .rounded }
        docs.toolTip = "Open the bundled Prewarm documentation"
        upstream.toolTip = "Drew Burchfield's original macos-mic-keepwarm project"
        let buttons = NSStackView(views: [docs, upstream])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        let privacy = label("Audio is never saved or sent.", size: 11, color: .secondaryLabelColor)
        let credit = label("Based on macos-mic-keepwarm\nby Drew Burchfield · MIT license", size: 10, color: .secondaryLabelColor)
        let stack = NSStackView(views: [icon, title, description, versionLabel, author, buttons, privacy, credit])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(16, after: icon)
        stack.setCustomSpacing(16, after: author)
        stack.setCustomSpacing(16, after: buttons)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 38),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
        ])
    }
    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = .center
        return label
    }
    @objc private func openDocs() {
        if let url = Bundle.main.url(forResource: "README", withExtension: "md") { NSWorkspace.shared.open(url) }
    }
    @objc private func openUpstream() { NSWorkspace.shared.open(URL(string: "https://github.com/drewburchfield/macos-mic-keepwarm")!) }
}
