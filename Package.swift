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
        // State machine, feature lifecycle, diagnostics. No AppKit, so it tests anywhere.
        .target(name: "NotchCore"),
        // Panel, SwiftUI surface, and notch geometry.
        .target(name: "NotchSurface", dependencies: ["NotchCore"]),
        .testTarget(name: "NotchCoreTests", dependencies: ["NotchCore"]),
        .testTarget(name: "NotchSurfaceTests", dependencies: ["NotchSurface"]),
        // XCTest metrics (clock, CPU, memory, signposts) for the core's hot paths.
        .testTarget(name: "PerformanceTests", dependencies: ["NotchCore"]),
    ]
)
