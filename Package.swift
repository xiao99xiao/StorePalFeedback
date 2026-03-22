// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StorePalFeedback",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "StorePalFeedback", targets: ["StorePalFeedback"]),
        .library(name: "StorePalFeedbackUI", targets: ["StorePalFeedbackUI"]),
    ],
    targets: [
        .target(name: "StorePalFeedback"),
        .target(name: "StorePalFeedbackUI", dependencies: ["StorePalFeedback"]),
    ]
)
