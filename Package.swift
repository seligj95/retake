// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Retake",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "Retake",
            targets: ["Retake"]
        )
    ],
    dependencies: [
        // KeyboardShortcuts temporarily removed due to Swift 6.2 macro compatibility issues
        // TODO: Add back when dependency is updated or when building with Xcode
        // .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Retake",
            dependencies: [],
            path: "Retake",
            exclude: ["Info.plist", "Retake.entitlements"]
        )
    ]
)
