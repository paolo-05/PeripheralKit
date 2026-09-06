// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PeripheralKit",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PeripheralKit", targets: ["PeripheralKit"]),
    ],
    targets: [
        .executableTarget(name: "PeripheralKit"),
        .testTarget(name: "PeripheralKitTests", dependencies: ["PeripheralKit"]),
    ]
)
