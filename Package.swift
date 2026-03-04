// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeSessionTaskbar",
    platforms: [.macOS(.v13)],
    swiftLanguageModes: [.v5],
    targets: [
        .executableTarget(
            name: "ClaudeSessionTaskbar",
            path: "Sources"
        )
    ]
)
