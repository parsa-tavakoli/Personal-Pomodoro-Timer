// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Pomodoro", path: "Sources/Pomodoro")
    ]
)
