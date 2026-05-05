import CryptoKit
import Foundation

/// Persistent wondering log. Phase 1: in-memory stub. Phase 3-4: Core Data
/// (or SwiftData) per `runs/2026-05-05-spec/spec/coredata-model.md`, with
/// FileProtection complete + dedup by content fingerprint per SC5-01.
///
/// SC5-04 invariants enforced here (Phase 4):
/// - schemaVersion field on every Wonder
/// - migration must back up DB before applying
/// - re-running migration on already-migrated DB = no-op
public actor WonderingLog {

    private var entries: [Wonder] = []
    private var sessions: [SessionRecord] = []
    public private(set) var currentSession: SessionRecord

    /// PR-γ: shared `ISO8601DateFormatter`. Apple's "Working with Dates"
    /// performance note observes that `ISO8601DateFormatter` initialization
    /// is O(locale tables) and was being paid on every `contentFingerprint`
    /// call (i.e. every `append` AND every dedup-check). Apple Foundation
    /// documents `ISO8601DateFormatter.string(from:)` as thread-safe after
    /// configuration (Foundation date-formatter contracts unchanged since
    /// ISO8601DateFormatter introduction in macOS 10.12). The
    /// `nonisolated(unsafe)` annotation makes this Sendable-clean under
    /// Swift 6 strict concurrency without spawning per-call formatters
    /// behind an actor hop.
    nonisolated(unsafe) private static let isoDayFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    public init() {
        self.currentSession = SessionRecord()
    }

    /// SC5-01 dedup: hash of (utterance + day-bucket + sessionId) — same
    /// utterance from same session + same day collapses to one entry.
    public static func contentFingerprint(
        utterance: String,
        sessionId: UUID,
        on day: Date = Date()
    ) -> String {
        let dayBucket = isoDayFormatter.string(from: Calendar.current.startOfDay(for: day))
        let raw =
            "\(utterance.trimmingCharacters(in: .whitespaces).lowercased())|\(sessionId.uuidString)|\(dayBucket)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(32).description
    }

    /// Append a wonder. Returns the assigned `Wonder` (with id stamped).
    /// Returns the EXISTING entry instead of duplicating if the content
    /// fingerprint already exists in this session-day.
    public func append(_ wonder: Wonder) -> Wonder {
        let fingerprint = Self.contentFingerprint(
            utterance: wonder.userUtterance,
            sessionId: currentSession.id
        )
        if let existing = entries.first(where: {
            Self.contentFingerprint(utterance: $0.userUtterance, sessionId: currentSession.id)
                == fingerprint
        }) {
            return existing
        }
        entries.append(wonder)
        currentSession.wonderCount += 1
        return wonder
    }

    /// Phase 4: surface_past_wonder embedding-similarity search. Phase 1
    /// returns recent matches by substring overlap (placeholder).
    public func surface(matching query: String, max: Int = 1) -> [Wonder] {
        let q = query.lowercased()
        let candidates =
            entries
            .filter { $0.surfaceLater }
            .filter { wonder in
                wonder.userUtterance.lowercased().contains(q.prefix(8))
            }
            .suffix(max)
        return Array(candidates)
    }

    /// Deterministic JSON export (SC5-08): sorted by `createdAt` ASC,
    /// timestamps ISO-8601 with timezone, stable key order.
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        return try encoder.encode(sorted)
    }

    /// Returns count of entries (read-only).
    public func count() -> Int { entries.count }

    /// End the current session and start a new one.
    public func endSession() {
        currentSession.endedAt = Date()
        sessions.append(currentSession)
        currentSession = SessionRecord()
    }
}
