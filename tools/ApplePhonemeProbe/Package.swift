// swift-tools-version: 6.1
// He Was Socrates — Stage-5 day-1 Apple phoneme availability probe.
// See: runs/2026-05-05-spec/spec/SPEC.md.iter4-api-correction.md §S3, §S4.
//
// This is intentionally a separate Swift package (not a target inside
// `packages/SocraticEngine`) so that:
//   1. The engine library stays a leaf with no executable products.
//   2. AVFoundation is only linked into the probe binary, not the library
//      (the library guards usage with `#if canImport(AVFAudio)`).
//   3. `swift run ApplePhonemeProbe` works from `tools/ApplePhonemeProbe/`
//      with no transitive MLX / HuggingFace fetch cost.

import PackageDescription

let package = Package(
    name: "ApplePhonemeProbe",
    platforms: [
        // SPEC.md.iter6-macos26-floor.md: floor 14 → 26.
        .macOS("26.0"),
    ],
    products: [
        .executable(
            name: "ApplePhonemeProbe",
            targets: ["ApplePhonemeProbe"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ApplePhonemeProbe",
            path: "Sources/ApplePhonemeProbe"
        )
    ]
)
