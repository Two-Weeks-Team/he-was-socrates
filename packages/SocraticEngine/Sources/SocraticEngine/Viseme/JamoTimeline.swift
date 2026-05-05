import Foundation

/// Korean jamo time-uniform fallback per
/// `runs/2026-05-05-spec/spec/SPEC.md.iter4-api-correction.md` §S1.
///
/// When ko-KR voices (Yuna, Heami) do NOT emit `.phoneme` markers from
/// `AVSpeechSynthesizer.write(_:toBufferCallback:)`, this struct produces a
/// schedule by:
/// 1. Decomposing Hangul syllables to jamo (initial / medial / final).
/// 2. Allocating each syllable's audio span as 15:70:15 across the three jamo.
/// 3. Mapping each jamo to its viseme via `PhonemeMap.viseme(forJamo:)`.
public struct JamoTimeline {

    public struct Entry: Equatable, Sendable {
        public let jamo: String
        public let viseme: VisemeID
        public let startMs: Double
        public let endMs: Double
    }

    public static let initialFraction: Double = 0.15
    public static let medialFraction: Double = 0.70
    public static let finalFraction: Double = 0.15

    /// Hangul syllable block range: U+AC00 – U+D7A3.
    public static func isHangulSyllable(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0xAC00 && scalar.value <= 0xD7A3
    }

    /// Decompose a single Hangul syllable into (initial, medial, final?) jamo.
    /// Returns `nil` if the input is not a valid Hangul syllable.
    public static func decomposeSyllable(_ scalar: Unicode.Scalar) -> (initial: String, medial: String, final: String?)? {
        guard isHangulSyllable(scalar) else { return nil }
        let base = Int(scalar.value) - 0xAC00
        let initialIdx = base / (21 * 28)
        let medialIdx = (base % (21 * 28)) / 28
        let finalIdx = base % 28

        let initials = ["ㄱ","ㄲ","ㄴ","ㄷ","ㄸ","ㄹ","ㅁ","ㅂ","ㅃ","ㅅ","ㅆ","ㅇ","ㅈ","ㅉ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"]
        let medials = ["ㅏ","ㅐ","ㅑ","ㅒ","ㅓ","ㅔ","ㅕ","ㅖ","ㅗ","ㅘ","ㅙ","ㅚ","ㅛ","ㅜ","ㅝ","ㅞ","ㅟ","ㅠ","ㅡ","ㅢ","ㅣ"]
        let finals = ["","ㄱ","ㄲ","ㄳ","ㄴ","ㄵ","ㄶ","ㄷ","ㄹ","ㄺ","ㄻ","ㄼ","ㄽ","ㄾ","ㄿ","ㅀ","ㅁ","ㅂ","ㅄ","ㅅ","ㅆ","ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"]

        let initial = initials[initialIdx]
        let medial = medials[medialIdx]
        let finalRaw = finals[finalIdx]
        let finalOpt: String? = finalRaw.isEmpty ? nil : finalRaw

        return (initial: initial, medial: medial, final: finalOpt)
    }

    /// Build a viseme schedule for a Korean utterance + total audio duration.
    /// Non-Hangul characters (whitespace, punctuation, embedded English) are
    /// allocated proportional time but mapped to REST or by space-budget heuristic.
    public static func buildSchedule(
        text: String,
        totalDurationMs: Double,
        phonemeMap: PhonemeMap = .default
    ) -> [Entry] {
        let scalars = Array(text.unicodeScalars)
        guard !scalars.isEmpty, totalDurationMs > 0 else { return [] }

        // Each "unit" is either a Hangul syllable (3 jamo slots) or a single
        // non-Hangul scalar (1 slot). Treat a Hangul syllable as ~weight 3,
        // non-Hangul as weight 1.
        let units: [(scalar: Unicode.Scalar, weight: Double)] = scalars.map { scalar in
            (scalar, isHangulSyllable(scalar) ? 3.0 : 1.0)
        }
        let totalWeight = units.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else { return [] }

        let msPerWeight = totalDurationMs / totalWeight

        var entries: [Entry] = []
        var cursorMs: Double = 0

        for unit in units {
            let unitMs = unit.weight * msPerWeight

            if let parts = decomposeSyllable(unit.scalar) {
                let initialMs = unitMs * Self.initialFraction
                let medialMs = unitMs * Self.medialFraction
                let finalMs = unitMs * Self.finalFraction

                entries.append(Entry(
                    jamo: parts.initial,
                    viseme: phonemeMap.viseme(forJamo: parts.initial),
                    startMs: cursorMs,
                    endMs: cursorMs + initialMs
                ))
                cursorMs += initialMs

                entries.append(Entry(
                    jamo: parts.medial,
                    viseme: phonemeMap.viseme(forJamo: parts.medial),
                    startMs: cursorMs,
                    endMs: cursorMs + medialMs
                ))
                cursorMs += medialMs

                if let f = parts.final {
                    entries.append(Entry(
                        jamo: f,
                        viseme: phonemeMap.viseme(forJamo: f),
                        startMs: cursorMs,
                        endMs: cursorMs + finalMs
                    ))
                } else {
                    // No final consonant — extend medial to cover the slot.
                    if !entries.isEmpty {
                        let last = entries.removeLast()
                        entries.append(Entry(
                            jamo: last.jamo,
                            viseme: last.viseme,
                            startMs: last.startMs,
                            endMs: last.endMs + finalMs
                        ))
                    }
                }
                cursorMs += finalMs
            } else {
                // Non-Hangul: REST (whitespace, punctuation) or single-scalar handling.
                let viseme: VisemeID = unit.scalar.properties.isWhitespace ? .REST : .REST
                entries.append(Entry(
                    jamo: String(unit.scalar),
                    viseme: viseme,
                    startMs: cursorMs,
                    endMs: cursorMs + unitMs
                ))
                cursorMs += unitMs
            }
        }

        // Tail REST so the bust closes after speech.
        if let last = entries.last {
            entries.append(Entry(
                jamo: "REST",
                viseme: .REST,
                startMs: last.endMs,
                endMs: totalDurationMs
            ))
        }

        return entries
    }

    /// Convert to (viseme, audioOffsetMs) pairs for VisemeDriver.ingestSchedule.
    public static func toDriverSchedule(_ entries: [Entry]) -> [(viseme: VisemeID, audioOffsetMs: Double)] {
        return entries.map { (viseme: $0.viseme, audioOffsetMs: $0.startMs) }
    }
}
