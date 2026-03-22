// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StorePalFeedback",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "StorePalFeedback", targets: ["StorePalFeedback"]),
        .library(name: "StorePalSwiftUI", targets: ["StorePalSwiftUI"]),
    ],
    targets: [
        .target(
            name: "StorePalFeedback",
            resources: [.process("Resources")]
        ),
        .target(name: "StorePalSwiftUI", dependencies: ["StorePalFeedback"]),
    ]
)
