// swift-tools-version: 6.1
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
        // mlx-swift-lm — Apple's official LLM/VLM Swift package (MIT). Provides
        // MLXLLM library with built-in Gemma 4 E4B IT 4-bit support via
        // LLMRegistry.gemma4_e4b_it_4bit pointing to mlx-community/gemma-4-e4b-it-4bit.
        // Brings mlx-swift transitively, so we don't need to declare it separately.
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", from: "3.31.3"),
        // HuggingFace clients — required at call site by the #hubDownloader and
        // #huggingFaceTokenizerLoader macros, which expand to code that
        // references HuggingFace.HubClient and Tokenizers types.
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "SocraticEngine",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
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
        // Latency benchmark — out-of-process executable that loads the real
        // Gemma 4 E4B 4-bit MLX weights via the same call paths as the app
        // (LLMRegistry.gemma4_e4b_it_4bit + #hubDownloader macro), runs warmup
        // and N timed turns through FunctionCallOrchestrator, and prints
        // wall-clock samples + median/p10/p90 to stdout. Invocation:
        //
        //   HF_HUB_CACHE=/path/to/hub swift run -c release LatencyBench
        //
        // The HF_HUB_CACHE env var is honored by swift-huggingface (see
        // CacheLocationProvider.swift) so the bench can reuse weights staged
        // by the sandboxed app at ~/Library/Containers/<bundle>/.../huggingface/hub.
        .executableTarget(
            name: "LatencyBench",
            dependencies: ["SocraticEngine"],
            path: "Sources/LatencyBench"
        ),
    ]
)
