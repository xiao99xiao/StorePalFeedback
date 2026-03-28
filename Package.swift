// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StorePalFeedback",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "StorePalFeedback", targets: ["StorePalFeedback"]),
        .library(name: "StorePalSwiftUI", targets: ["StorePalSwiftUI"]),
        .library(name: "StorePalWhatsNew", targets: ["StorePalWhatsNew"]),
    ],
    targets: [
        .target(
            name: "StorePalFeedback",
            resources: [.process("Resources")]
        ),
        .target(name: "StorePalSwiftUI", dependencies: ["StorePalFeedback"]),
        .target(name: "StorePalWhatsNew", dependencies: ["StorePalFeedback"]),
    ]
)
