// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MKSleepRGB",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "mksleep-rgb", targets: ["MKSleepRGB"]),
    ],
    targets: [
        .executableTarget(name: "MKSleepRGB"),
        .testTarget(name: "MKSleepRGBTests", dependencies: ["MKSleepRGB"]),
    ]
)
