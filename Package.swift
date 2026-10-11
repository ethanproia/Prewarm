// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "Prewarm", platforms: [.macOS(.v14)], products: [.executable(name: "Prewarm", targets: ["Prewarm"])], targets: [
    .target(name: "PrewarmCore"),
    .executableTarget(name: "Prewarm", dependencies: ["PrewarmCore"], linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("AVFoundation"), .linkedFramework("CoreAudio")]),
    .testTarget(name: "PrewarmCoreTests", dependencies: ["PrewarmCore"])
])
