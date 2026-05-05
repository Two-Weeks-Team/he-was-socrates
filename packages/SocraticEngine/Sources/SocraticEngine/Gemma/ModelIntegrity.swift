import Foundation
import CryptoKit

/// SHA-256 integrity check for the bundled Gemma 4 E4B Q4 weights.
/// Per `runs/2026-05-05-spec/spec/model-integrity.md`, the runtime MUST verify
/// the bundle's weights file SHA matches an expected committed digest before
/// loading. Mismatch → refuse to launch (SocraticErrorCode.modelFileCorrupt).
///
/// The expected digest is committed to this Swift file at scaffold time,
/// keyed by model release tag, so a tampered DMG cannot silently substitute
/// weights without changing the binary.
public enum ModelIntegrity {

    /// Canonical model identifier — informational only.
    public static let modelTag = "gemma-4-e4b-it-4bit"
    public static let modelSourceURL = "https://huggingface.co/mlx-community/gemma-4-e4b-it-4bit"

    /// Expected SHA-256 of the primary weights file in the model directory.
    /// Stage-5 day-1 task: download once, compute SHA, commit here.
    /// Empty string until then — runtime treats empty-string as "skip check"
    /// in dev mode and errors out in release mode.
    public static let expectedSHA256: String = ""

    public static var isReleaseBuild: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

    /// Compute SHA-256 of the file at the given URL. Streams to handle
    /// large model files (Gemma E4B 4-bit ≈ 3.97 GB).
    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        let chunkSize = 64 * 1024
        while true {
            let chunk = handle.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public enum VerificationOutcome: Equatable, Sendable {
        case ok(actual: String)
        case mismatch(actual: String, expected: String)
        case skippedDevMode
        case fileMissing
    }

    public static func verify(weightsAt url: URL) throws -> VerificationOutcome {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .fileMissing
        }
        if expectedSHA256.isEmpty {
            return isReleaseBuild
                ? .mismatch(actual: try sha256(of: url), expected: "(unset)")
                : .skippedDevMode
        }
        let actual = try sha256(of: url)
        if actual.lowercased() == expectedSHA256.lowercased() {
            return .ok(actual: actual)
        }
        return .mismatch(actual: actual, expected: expectedSHA256)
    }
}
