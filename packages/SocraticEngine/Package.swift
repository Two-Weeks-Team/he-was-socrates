// swift-tools-version: 5.9
// He Was Socrates — Engine layer.
// Audio (STT + TTS) + Viseme driver + Gemma orchestration + Wondering log.
// See runs/2026-05-05-spec/spec/SPEC.md §4–6 for the locked contract.

import PackageDescription

let package = Package(
    name: "SocraticEngine",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SocraticEngine",
            targets: ["SocraticEngine"]
        ),
    ],
    dependencies: [
        // swift-testing — bundled with Xcode 16+, fetched as package for CommandLineTools-only envs.
        .package(url: "https://github.com/apple/swift-testing", from: "0.10.0"),
        // MLX-Swift — Apple Metal-accelerated inference runtime.
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.18.0"),
    ],
    targets: [
        .target(
            name: "SocraticEngine",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
            ],
            path: "Sources/SocraticEngine"
        ),
        .testTarget(
            name: "SocraticEngineTests",
            dependencies: [
                "SocraticEngine",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/SocraticEngineTests"
        ),
    ]
)
