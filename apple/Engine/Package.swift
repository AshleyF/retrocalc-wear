// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RetroRPNEngine",
    platforms: [
        .macOS(.v13),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "RetroRPNEngine", targets: ["RetroRPNEngine"]),
    ],
    targets: [
        .target(name: "RetroRPNEngine"),
        .testTarget(
            name: "RetroRPNEngineTests",
            dependencies: ["RetroRPNEngine"]
        ),
    ]
)
