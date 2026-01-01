// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LifeLogKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LifeLogKit",
            targets: ["LifeLogKit"]
        ),
    ],
    targets: [
        .target(
            name: "LifeLogKit",
            dependencies: []
        ),
        .testTarget(
            name: "LifeLogKitTests",
            dependencies: ["LifeLogKit"]
        ),
    ]
)
