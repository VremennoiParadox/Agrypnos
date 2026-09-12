// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Agrypnos",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "AgrypnosCore", targets: ["AgrypnosCore"]),
    ],
    targets: [
        .target(
            name: "AgrypnosCore",
            path: "Sources/AgrypnosCore"
        ),
        .testTarget(
            name: "AgrypnosCoreTests",
            dependencies: ["AgrypnosCore"],
            path: "Tests/AgrypnosCoreTests"
        ),
    ]
)
