// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ai-limit-bar",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "AILimitBarKit",
            path: "Sources/AILimitBarKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "AILimitBar",
            dependencies: ["AILimitBarKit"],
            path: "Sources/AILimitBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AILimitBarKitTests",
            dependencies: ["AILimitBarKit"],
            path: "Tests/AILimitBarKitTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
