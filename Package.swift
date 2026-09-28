// swift-tools-version: 5.9
import PackageDescription

var nativeTargets: [Target] = []
#if os(macOS)
nativeTargets = [
    .target(name: "AgrypnosMac", dependencies: ["AgrypnosCore"],
            path: "Apps/Agrypnos/Sources",
            exclude: ["AppMain.swift", "AppDelegate.swift", "MenuBar", "Hotkey", "Launch"]),
    .testTarget(name: "AgrypnosMacTests", dependencies: ["AgrypnosMac", "AgrypnosCore"],
                path: "Tests/AgrypnosMacTests"),
]
#endif

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
    ] + nativeTargets
)
