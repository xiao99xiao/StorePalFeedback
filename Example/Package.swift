// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StorePalExample",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "StorePalExample",
            dependencies: [
                .product(name: "StorePalSwiftUI", package: "StorePalFeedback"),
            ],
            path: "StorePalExample"
        ),
    ]
)
