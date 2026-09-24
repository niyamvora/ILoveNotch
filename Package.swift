// swift-tools-version: 6.0
// SPDX-License-Identifier: MIT
import PackageDescription

// Tools 6.0 builds every target in the Swift 6 language mode: complete strict-concurrency checking.
let package = Package(
    name: "OpenNotchKit",
    platforms: [.macOS("14.6")],
    products: [
        .library(name: "NotchSurface", targets: ["NotchSurface"])
    ],
    targets: [
        .target(name: "NotchSurface"),
        .testTarget(name: "NotchSurfaceTests", dependencies: ["NotchSurface"]),
    ]
)
