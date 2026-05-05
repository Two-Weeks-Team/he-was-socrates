import Foundation

/// Loads and applies the phoneme→viseme map.
/// Source of truth: `runs/2026-05-05-spec/spec/phoneme-viseme-map.json` (locked)
/// + `runs/2026-05-05-spec/spec/phoneme-viseme-map.delta.json` (Korean delta, iter-4).
///
/// At runtime, the locked map is loaded first, then the delta overlays.
public struct PhonemeMap: Sendable {
    public let baseRevision: String
    public let deltaRevision: String?

    /// IPA symbol → primary viseme (e.g. "ɑ" → AA).
    public let ipaToViseme: [String: VisemeID]

    /// Apple internal label → IPA. Built at scaffold time by
    /// `tools/capture-apple-phonemes.swift` — this struct provides a stub
    /// table for Phase 3 development.
    public let appleLabelToIPA: [String: String]

    /// Hangul jamo → viseme bucket fallback when no IPA path is available.
    public let hangulJamoToViseme: [String: VisemeID]

    public func viseme(forIPA ipa: String) -> VisemeID {
        ipaToViseme[ipa] ?? .REST
    }

    public func viseme(forJamo jamo: String) -> VisemeID {
        hangulJamoToViseme[jamo] ?? .REST
    }

    public func viseme(forAppleLabel label: String) -> VisemeID {
        guard let ipa = appleLabelToIPA[label] else { return .REST }
        return viseme(forIPA: ipa)
    }

    /// Bundled minimal default — full map loaded from JSON resource at runtime.
    /// Reflects iter-4 amendments: ㅓ→UH (was AA), ɾ→S (was R).
    public static let `default`: PhonemeMap = PhonemeMap(
        baseRevision: "frozen-2026-05-05",
        deltaRevision: "iter-4-2026-05-05",
        ipaToViseme: [
            // Vowels (en-US)
            "ɑ":  .AA, "æ": .AA, "a": .AA,
            "i":  .EE, "iː": .EE, "ɪ": .IH,
            "oʊ": .OH, "o": .OH, "ɔ": .OH,
            "aʊ": .OW, "u": .OW, "uː": .OW,
            "ʌ":  .UH, "ə": .UH, "ɛ": .IH,
            // Consonants
            "m": .M, "p": .P, "b": .B,
            "f": .F, "v": .V,
            "θ": .TH, "ð": .TH,
            "s": .S, "z": .S, "t": .S, "d": .S, "n": .S, "l": .S,
            "ʃ": .SH, "ʒ": .SH, "tʃ": .SH, "dʒ": .SH,
            "ɹ": .R, "w": .R,
            // Korean delta
            "ɾ": .S, // ㄹ initial flap (was .R per iter-4)
            "k": .S, "ɡ": .S, "h": .S, "j": .EE,
        ],
        // Stub for Phase 3 — real table built by capture-apple-phonemes.swift.
        // Keep empty so VisemeDriver falls through to jamo fallback when invoked.
        appleLabelToIPA: [:],
        hangulJamoToViseme: [
            // Vowels (iter-4 deltas applied)
            "ㅏ": .AA, "ㅑ": .AA,
            "ㅓ": .UH, "ㅕ": .UH,  // iter-4: was AA
            "ㅗ": .OH, "ㅛ": .OH,
            "ㅜ": .OW, "ㅠ": .OW, "ㅝ": .UH,  // iter-4: was AA
            "ㅡ": .UH, "ㅣ": .EE,
            "ㅐ": .IH, "ㅔ": .IH,
            "ㅘ": .OW,
            // Consonants
            "ㅁ": .M, "ㅂ": .B, "ㅃ": .B, "ㅍ": .P,
            "ㄴ": .S, "ㄷ": .S, "ㄸ": .S, "ㅌ": .S,
            "ㄹ": .S,
            "ㄱ": .S, "ㄲ": .S, "ㅋ": .S,
            "ㅅ": .S, "ㅆ": .S,
            "ㅈ": .S, "ㅉ": .S, "ㅊ": .S,
            "ㅎ": .S,
            "ㅇ": .REST,
        ]
    )
}
