import AppKit
import SwiftUI

/// Status-only apps have no application menu to supply the usual Close shortcut.
final class PrewarmWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command,
           event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

private struct AboutView: SwiftUI.View {
    let icon: NSImage
    let version: String
    let build: String
    let openDocs: () -> Void

    var body: some SwiftUI.View {
        VStack(spacing: 10) {
            Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit).frame(width: 112, height: 112)
                .accessibilityLabel("Prewarm app icon")
            Text("Prewarm").font(.system(size: 24, weight: .semibold))
            Text("Keeps your microphone warm.").font(.system(size: 13))
            Text("Version \(version) (\(build))").font(.system(size: 11)).foregroundStyle(.secondary)
            Text("By Ethan Proia").font(.system(size: 12))
            actions.padding(.vertical, 6)
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    Text("Based on ").foregroundStyle(.secondary)
                    Link("macos-mic-keepwarm", destination: URL(string: "https://github.com/drewburchfield/macos-mic-keepwarm")!)
                        .buttonStyle(.link)
                        .help("Drew Burchfield's original macos-mic-keepwarm project")
                }
                Text("by Drew Burchfield · MIT license").foregroundStyle(.secondary)
            }
            .font(.system(size: 10))
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 320)
        .textSelection(.enabled)
    }
    @ViewBuilder private var actions: some SwiftUI.View {
        if #available(macOS 26.0, *) { buttons.buttonBorderShape(.capsule) }
        else { buttons }
    }
    private var buttons: some SwiftUI.View {
        HStack(spacing: 12) {
            Button("Docs", action: openDocs).help("Open bundled Prewarm documentation")
            Button("GitHub") { }.disabled(true)
                .help("The Prewarm repository has not been published yet.")
                .accessibilityHint("Unavailable until the Prewarm repository is published")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

final class AboutController: NSViewController {
    private let info: [String: Any]
    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) { self.info = info; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func loadView() {
        let material = NSVisualEffectView()
        material.material = .underWindowBackground
        material.blendingMode = .behindWindow
        material.state = .followsWindowActiveState
        view = material
        let hosting = NSHostingView(rootView: AboutView(
            icon: NSApp.applicationIconImage,
            version: info["CFBundleShortVersionString"] as? String ?? "Unknown",
            build: info["CFBundleVersion"] as? String ?? "Unknown",
            openDocs: { if let url = Bundle.main.url(forResource: "README", withExtension: "md") { NSWorkspace.shared.open(url) } }
        ))
        hosting.sizingOptions = .intrinsicContentSize
        hosting.safeAreaRegions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false
        material.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: material.leadingAnchor), hosting.trailingAnchor.constraint(equalTo: material.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: material.topAnchor), hosting.bottomAnchor.constraint(equalTo: material.bottomAnchor)
        ])
    }
}
