// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StorePalFeedback",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "StorePalFeedback", targets: ["StorePalFeedback"]),
        .library(name: "StorePalSwiftUI", targets: ["StorePalSwiftUI"]),
    ],
    targets: [
        .target(name: "StorePalFeedback"),
        .target(name: "StorePalSwiftUI", dependencies: ["StorePalFeedback"]),
    ]
)
