import Foundation

/// 16-viseme set per `runs/2026-05-05-spec/spec/phoneme-viseme-map.json` +
/// the iter-2 + iter-4 amendments. Order matters: this enum's rawValue
/// matches the asset file name `viseme_<rawValue>.png`.
public enum VisemeID: String, Codable, Sendable, CaseIterable {
    case AA, EE, IH, OH, OW, UH
    case M, P, B, F, V, TH
    case S, SH, R, REST

    /// Pixel dimensions on the 1024×1024 canvas — kept in sync with
    /// `scripts/viseme_compose.py:VISEME_DIMS`. Used for layout sanity
    /// checks at runtime.
    public var nominalDims: (w: Int, h: Int) {
        switch self {
        case .AA:   return (100, 75)
        case .EE:   return (118, 18)
        case .IH:   return (105, 26)
        case .OH:   return (58, 58)
        case .OW:   return (44, 44)
        case .UH:   return (82, 32)
        case .M:    return (94, 8)
        case .P:    return (94, 8)
        case .B:    return (94, 8)
        case .F:    return (80, 14)
        case .V:    return (80, 14)
        case .TH:   return (76, 26)
        case .S:    return (74, 24)
        case .SH:   return (68, 32)
        case .R:    return (58, 38)
        case .REST: return (82, 8)
        }
    }

    /// Asset bundle resource name (without extension).
    public var resourceName: String { "viseme_\(rawValue)" }

    /// Approximate articulatory class for cross-cutting drift recovery.
    public var phoneticClass: PhoneticClass {
        switch self {
        case .AA, .EE, .IH, .OH, .OW, .UH: return .vowel
        case .M, .P, .B:                   return .labialClosure
        case .F, .V:                       return .labiodental
        case .TH:                          return .dentalFricative
        case .S, .SH, .R:                  return .alveolarPostalveolar
        case .REST:                        return .silence
        }
    }
}

public enum PhoneticClass: String, Sendable {
    case vowel
    case labialClosure
    case labiodental
    case dentalFricative
    case alveolarPostalveolar
    case silence
}
