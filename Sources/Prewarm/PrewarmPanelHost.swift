import AppKit

private final class FloatingPanel: NSPanel {
    var onDismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onDismiss?() }
}

/// One native panel/window frame and one supported material, without popover chrome.
final class PrewarmPanelHost {
    let content: PrewarmPanel
    private let panel: FloatingPanel
    private weak var anchor: NSStatusBarButton?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var isShown: Bool { panel.isVisible }

    init(content: PrewarmPanel) {
        self.content = content
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 1), styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "Prewarm"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] { panel.standardWindowButton(kind)?.isHidden = true }
        let material: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 0 // The native window frame owns the only rounded boundary.
            glass.contentView = content.view
            material = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .popover
            effect.blendingMode = .behindWindow
            effect.state = .followsWindowActiveState
            effect.addSubview(content.view)
            material = effect
        }
        content.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.view.leadingAnchor.constraint(equalTo: material.leadingAnchor), content.view.trailingAnchor.constraint(equalTo: material.trailingAnchor),
            content.view.topAnchor.constraint(equalTo: material.topAnchor), content.view.bottomAnchor.constraint(equalTo: material.bottomAnchor)
        ])
        panel.contentView = material
        panel.onDismiss = { [weak self] in self?.dismiss() }
    }
    func refreshSize() {
        // Full-size content occupies the native frame; do not add title-bar height.
        panel.setFrame(NSRect(origin: panel.frame.origin, size: content.preferredContentSize), display: false)
        panel.contentView?.layoutSubtreeIfNeeded()
        if isShown, let anchor { position(below: anchor) }
    }
    func show(below button: NSStatusBarButton) {
        anchor = button
        refreshSize()
        position(below: button)
        panel.makeKeyAndOrderFront(nil)
        installMonitors()
    }
    private func position(below button: NSStatusBarButton) {
        guard let window = button.window, let screen = window.screen ?? NSScreen.main else { return }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = min(max(rect.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        let y = max(visible.minY + 8, min(rect.minY - 6, visible.maxY - 6) - size.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    func dismiss() {
        panel.orderOut(nil)
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        globalMonitor = nil
        localMonitor = nil
    }
    private func installMonitors() {
        guard globalMonitor == nil && localMonitor == nil else { return }
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in self?.dismiss() }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            guard let self, event.window !== self.panel else { return event }
            if let anchor = self.anchor, event.window === anchor.window,
               anchor.bounds.contains(anchor.convert(event.locationInWindow, from: nil)) { return event }
            self.dismiss()
            return event
        }
    }
    deinit {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
    }
}
