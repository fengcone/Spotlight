// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Spotlight",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Spotlight",
            dependencies: []
        )
    ]
)
