// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Pomodoro",
    // Liquid Glass APIs need macOS 26 (Tahoe) or later.
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "Pomodoro", path: "Sources/Pomodoro")
    ],
    swiftLanguageModes: [.v5]
)
