import Foundation

/// One wondering-log entry. Mirrors the Core Data `Wonder` entity per
/// `runs/2026-05-05-spec/spec/coredata-model.md`. The Codable struct here is
/// the in-memory + JSON-export shape; persistence is in Storage/WonderingLog.swift.
public struct Wonder: Codable, Sendable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let userUtterance: String
    public let socraticReply: String
    public let mode: Mode
    public let modeConfidence: Double
    public let language: Language
    public let audioFilePathLocal: URL?
    public let thinkingTraceCompressed: String
    public let tags: [SemanticTag]
    public let surfaceLater: Bool
    public let schemaVersion: Int

    /// Stable derivation key — content fingerprint for SC5 dedup. NOT the
    /// primary id (which is a fresh UUID), but used by WonderingLog to detect
    /// "user said the same thing in the same session."
    public var contentFingerprint: String {
        // SHA-256(utterance + day-bucketed-timestamp + sessionPlaceholder).
        // Real implementation in Storage/WonderingLog.swift uses CryptoKit.
        return "\(userUtterance.lowercased())|\(language.rawValue)"
    }

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        userUtterance: String,
        socraticReply: String,
        mode: Mode,
        modeConfidence: Double,
        language: Language,
        audioFilePathLocal: URL? = nil,
        thinkingTraceCompressed: String = "",
        tags: [SemanticTag] = [],
        surfaceLater: Bool = true,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.createdAt = createdAt
        self.userUtterance = userUtterance
        self.socraticReply = socraticReply
        self.mode = mode
        self.modeConfidence = modeConfidence
        self.language = language
        self.audioFilePathLocal = audioFilePathLocal
        self.thinkingTraceCompressed = thinkingTraceCompressed
        self.tags = tags
        self.surfaceLater = surfaceLater
        self.schemaVersion = schemaVersion
    }
}

// `Language` moved to its own file (Models/Language.swift) so Swift 6.1
// (Xcode 16.3 / GitHub-hosted macos-15 runner) module-emit doesn't treat
// the trailing types in this file as nested.

public struct SemanticTag: Codable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    /// Truncated SHA-256(embedding) — one-way digest, not the embedding itself.
    public let embeddingHash: String

    public init(id: UUID = UUID(), name: String, embeddingHash: String) {
        self.id = id
        self.name = name
        self.embeddingHash = embeddingHash
    }
}

/// Session boundary (per coredata-model.md §3).
public struct SessionRecord: Codable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public var endedAt: Date?
    public var mode: Mode?
    public var wonderCount: Int

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        mode: Mode? = nil,
        wonderCount: Int = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.mode = mode
        self.wonderCount = wonderCount
    }
}
