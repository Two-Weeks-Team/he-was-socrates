// He Was Socrates — Stage-5 day-1 Apple phoneme availability probe.
//
// Implements the §S3 / §S4 verification gate from
// `runs/2026-05-05-spec/spec/SPEC.md.iter4-api-correction.md`.
//
// For each (voice × utterance) pair, the probe synthesizes the utterance via
// AVSpeechSynthesizer and captures every AVSpeechSynthesisMarker whose
// `.mark == .phoneme`. Aggregated results are written to:
//   runs/2026-05-05-spec/spec/apple-phoneme-availability.json
//
// The probe is informational only — it always exits 0. The verdict it
// computes drives downstream decisions (real phoneme stream vs jamo-uniform
// fallback) but is reviewed and ratified by the user, not by CI.

import AVFoundation
import Foundation

// MARK: - Fixtures (per SPEC.md §4.4 + iter4 §S4)

private let koreanFixtures: [String] = [
    "안녕",
    "왜 어떤 노래는 들으면 우는지?",
    "얼음이 미끄러워요",
    "변호사가 필요해",
]

private let englishFixtures: [String] = [
    "hello",
    "why does some music make me cry?",
    "ice is slippery",
]

/// Voices we care about for the gate. Order matters — Yuna/Heami first
/// because §S4's branch logic keys off ko-KR behavior.
private let probedVoices: [(displayName: String, expectedLanguage: String)] = [
    ("Yuna",     "ko-KR"),
    ("Heami",    "ko-KR"),
    ("Samantha", "en-US"),
    ("Alex",     "en-US"),
]

// MARK: - JSON model

struct VoiceReport: Encodable {
    var installed: Bool
    var identifier: String?
    var quality: String?
    var phonemeMarkerCount: Int
    var sampleLabels: [String]

    enum CodingKeys: String, CodingKey {
        case installed
        case identifier
        case quality
        case phonemeMarkerCount = "phoneme_markers_emitted"
        case sampleLabels = "sample_labels"
    }
}

struct FixtureReport: Encodable {
    var voice: String
    var language: String
    var markerCount: Int
    var labels: [String]

    enum CodingKeys: String, CodingKey {
        case voice
        case language
        case markerCount = "marker_count"
        case labels
    }
}

struct ProbeReport: Encodable {
    var probedAtKST: String
    var macosVersion: String
    var verdict: String
    var voices: [String: VoiceReport]
    var fixtures: [String: FixtureReport]

    enum CodingKeys: String, CodingKey {
        case probedAtKST = "probed_at_kst"
        case macosVersion = "macos_version"
        case verdict
        case voices
        case fixtures
    }
}

// MARK: - Marker capture delegate

/// Captures `.phoneme` markers synchronously while AVSpeechSynthesizer plays
/// an utterance. We use the delegate `willSpeak marker:` channel on macOS 14+
/// which fires for every AVSpeechSynthesisMarker (regardless of `.mark` kind).
///
/// The class is unchecked-Sendable because callbacks are serialized by
/// AVSpeechSynthesizer onto a single delegate queue and the consumer waits on
/// the semaphore before reading state.
final class MarkerCapturingDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var phonemeLabels: [String] = []
    var allMarkerCount: Int = 0
    var didFinish: Bool = false
    var didCancel: Bool = false

    private let semaphore = DispatchSemaphore(value: 0)

    func reset() {
        phonemeLabels.removeAll(keepingCapacity: true)
        allMarkerCount = 0
        didFinish = false
        didCancel = false
    }

    /// Wait up to `timeout` seconds for `didFinish` or `didCancel`.
    func waitForCompletion(timeout: TimeInterval) -> Bool {
        return semaphore.wait(timeout: .now() + timeout) == .success
    }

    // The marker delegate is available on macOS 14+; signature is:
    //   speechSynthesizer(_:willSpeak marker:utterance:)
    // AVSpeechSynthesisMarker exposes `bookmarkName: String` (non-optional,
    // empty string when absent). For `.mark == .phoneme` it carries the
    // voice-engine-specific phoneme label.
    @available(macOS 14.0, *)
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeak marker: AVSpeechSynthesisMarker,
                           utterance: AVSpeechUtterance) {
        allMarkerCount += 1
        if marker.mark == .phoneme {
            phonemeLabels.append(marker.bookmarkName)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        didFinish = true
        semaphore.signal()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        didCancel = true
        semaphore.signal()
    }
}

// MARK: - Voice resolution

func resolveVoice(named target: String) -> AVSpeechSynthesisVoice? {
    let all = AVSpeechSynthesisVoice.speechVoices()
    // Match by case-insensitive name suffix; system voice names sometimes
    // include parenthetical quality tags ("Yuna (Enhanced)" etc).
    let lowered = target.lowercased()
    let matches = all.filter { $0.name.lowercased().contains(lowered) }
    let qualityOrder: [AVSpeechSynthesisVoiceQuality] = [.premium, .enhanced, .default]
    for q in qualityOrder {
        if let v = matches.first(where: { $0.quality == q }) {
            return v
        }
    }
    return matches.first
}

// MARK: - Probe logic

/// Synthesize `text` with `voice` and return the captured phoneme labels.
/// Uses `synthesizer.write(_:toBufferCallback:)` (per SPEC iter4 §S1) so
/// audio is consumed silently to disk-less buffers — no speakers required
/// in CI/headless contexts. Phoneme markers arrive on the delegate.
func probe(voice: AVSpeechSynthesisVoice, text: String) -> [String] {
    let synthesizer = AVSpeechSynthesizer()
    let delegate = MarkerCapturingDelegate()
    synthesizer.delegate = delegate

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice
    // Slightly slowed (matches Phase 4 default) so markers have time to fire.
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95

    delegate.reset()

    // Drive synthesis via the buffer-callback API (SPEC iter4 §S1 PRIMARY).
    // We discard buffers — we only care about the marker stream.
    synthesizer.write(utterance) { (_: AVAudioBuffer) in
        // Buffers carry no markers per AVSpeechSynthesizer contract on
        // macOS 14+; markers arrive through the delegate channel.
    }

    // 8s ceiling per (voice × fixture). Worst-case Korean fixture is
    // ~3.5s of audio; the ceiling is generous to absorb cold-start.
    _ = delegate.waitForCompletion(timeout: 8.0)
    return delegate.phonemeLabels
}

// MARK: - Top-level run

func nowISO8601KST() -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
    f.timeZone = TimeZone(identifier: "Asia/Seoul")
    return f.string(from: Date())
}

func macOSVersionString() -> String {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
}

func computeVerdict(voiceReports: [String: VoiceReport]) -> String {
    func emits(_ name: String) -> Bool {
        guard let r = voiceReports[name], r.installed else { return false }
        return r.phonemeMarkerCount > 0
    }
    let koEmits = emits("Yuna") || emits("Heami")
    let enEmits = emits("Samantha") || emits("Alex")
    switch (koEmits, enEmits) {
    case (true, true):   return "all-voices-emit-markers"
    case (false, true):  return "ko-kr-silent-en-only"
    case (true, false):  return "ko-kr-emits-markers-en-silent"
    case (false, false): return "no-markers-anywhere"
    }
}

func main() -> Int32 {
    let runStartedAt = nowISO8601KST()
    print("Apple phoneme availability probe — \(runStartedAt)")
    print("macOS \(macOSVersionString())")
    print(String(repeating: "─", count: 64))

    var voiceReports: [String: VoiceReport] = [:]
    var fixtureReports: [String: FixtureReport] = [:]

    for (voiceName, expectedLanguage) in probedVoices {
        guard let voice = resolveVoice(named: voiceName) else {
            print("  \(voiceName) [\(expectedLanguage)]: NOT INSTALLED")
            print("    Install hint: System Settings > Accessibility > " +
                  "Spoken Content > System Voice > Manage Voices > " +
                  "\(expectedLanguage) > \(voiceName)")
            voiceReports[voiceName] = VoiceReport(
                installed: false,
                identifier: nil,
                quality: nil,
                phonemeMarkerCount: 0,
                sampleLabels: []
            )
            continue
        }

        let fixtures: [String] = (expectedLanguage == "ko-KR") ? koreanFixtures : englishFixtures
        var totalLabels: [String] = []

        print("  \(voiceName) [\(voice.identifier), q=\(voice.quality.rawValue)]")
        for fixture in fixtures {
            let labels = probe(voice: voice, text: fixture)
            totalLabels.append(contentsOf: labels)
            let key = "\(voiceName)::\(fixture)"
            fixtureReports[key] = FixtureReport(
                voice: voiceName,
                language: expectedLanguage,
                markerCount: labels.count,
                labels: labels
            )
            print("    fixture: \"\(fixture)\" → \(labels.count) marker(s)")
        }

        // Sample up to 16 unique labels for the per-voice summary.
        var seen = Set<String>()
        var samples: [String] = []
        for label in totalLabels where !label.isEmpty && seen.insert(label).inserted {
            samples.append(label)
            if samples.count >= 16 { break }
        }

        voiceReports[voiceName] = VoiceReport(
            installed: true,
            identifier: voice.identifier,
            quality: voice.quality.description,
            phonemeMarkerCount: totalLabels.count,
            sampleLabels: samples
        )
    }

    let verdict = computeVerdict(voiceReports: voiceReports)
    let report = ProbeReport(
        probedAtKST: runStartedAt,
        macosVersion: macOSVersionString(),
        verdict: verdict,
        voices: voiceReports,
        fixtures: fixtureReports
    )

    // Resolve the output path relative to the current working directory.
    // The probe is invoked from the repo root via `make probe-phonemes`, so
    // `runs/2026-05-05-spec/spec/` is reachable.
    let outputRelative = "runs/2026-05-05-spec/spec/apple-phoneme-availability.json"
    let cwd = FileManager.default.currentDirectoryPath
    let outputURL = URL(fileURLWithPath: cwd).appendingPathComponent(outputRelative)

    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: [.atomic])
        print(String(repeating: "─", count: 64))
        print("Verdict: \(verdict)")
        print("Wrote: \(outputURL.path)")
    } catch {
        // Still print the verdict; not being able to write the artifact is
        // recoverable (user can re-run from a writable cwd).
        print(String(repeating: "─", count: 64))
        print("Verdict: \(verdict)")
        print("WARN: could not write \(outputURL.path): \(error.localizedDescription)")
    }

    return 0
}

// MARK: - Helpers

private extension AVSpeechSynthesisVoiceQuality {
    var description: String {
        switch self {
        case .default:  return "default"
        case .enhanced: return "enhanced"
        case .premium:  return "premium"
        @unknown default: return "unknown(\(rawValue))"
        }
    }
}

exit(main())
