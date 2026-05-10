// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacModeMenu",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacModeMenu", targets: ["MacModeMenu"])
    ],
    targets: [
        .executableTarget(
            name: "MacModeMenu",
            path: "Sources/MacModeMenu"
        )
    ]
)
