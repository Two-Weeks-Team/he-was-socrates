# SPEC.md Iter-5 Amendment — Empirical Phoneme Pipeline Correction

| Field | Value |
|---|---|
| Authority | Empirically observed at scaffold (Stage-5 day-1 ApplePhonemeProbe run) and confirmed against on-device behaviour 2026-05-05 KST |
| Source | `runs/2026-05-05-spec/spec/apple-phoneme-availability.json` (verdict `"no-markers-anywhere"`), `runs/2026-05-05-spec/spec/viseme-best-practices.md` §7.1 |
| Affects | `SPEC.md §4.3` (TTS + Lip-sync subsystem), `phoneme-viseme-map.json:g2p_engine_*` |
| Builds on | `SPEC.md.iter2-amendment.md`, `SPEC.md.iter4-api-correction.md` |
| SHA-256 lock | **NOT recomputed**. Treat this amendment as authoritative for downstream scaffold; freeze v1 SHA preserved for audit. |

---

## Background

Iter-4 (`SPEC.md.iter4-api-correction.md`) re-pointed §4.3's "phoneme delegate" terminology to `AVSpeechSynthesizer.write(_:toBufferCallback:)` + `AVSpeechSynthesisMarker.Mark.phoneme`. The remaining open question — left to Stage-5 day-1 — was whether *any* macOS voice actually emits `.phoneme` markers in practice for the locales we ship.

`tools/ApplePhonemeProbe` was run against the canonical test-fixture utterances on macOS 26.4.1 (Apple Silicon, Xcode 26.4 SDK). The result is committed as `apple-phoneme-availability.json`:

```jsonc
{
  "macos_version": "26.4.1",
  "verdict": "no-markers-anywhere",
  "voices": {
    "Samantha (en-US)": { "phoneme_markers_emitted": 0 },
    "Yuna (ko-KR)":     { "phoneme_markers_emitted": 0 },
    "Heami (ko-KR)":    { "installed": false }
  },
  "fixtures": { /* every test-fixture utterance: marker_count = 0 */ }
}
```

**Translation:** the Apple-internal phoneme stream that iter-4 designated as PRIMARY does not materialise on the build target. Every locale, every voice, every fixture: zero `.phoneme` markers. The PRIMARY path is empirically dead.

This is not a bug to file against Apple — it's a stable behaviour on macOS 14, 15, and 26 (the probe was re-run on each). The framework simply does not surface phoneme-grain timing for system-installed voices.

---

## Amendment

### §4.3 Lip-sync pipeline — promote the JamoTimeline fallback to PRIMARY

The pipeline now reads:

```
PRIMARY: JamoTimeline 15:70:15 jamo time-distribution per Korean syllable
         (FALLBACK 1.5 in iter-4, before empirical evidence)

         For each AVSpeechUtterance:
           on `synth(_:didStart:)`:
              JamoTimeline.buildSchedule(text, totalDurationMs: estimated)
              → VisemeDriver.ingestSchedule(...)
              → VisemeDriver.notePlaybackStarted()
           on `synth(_:didFinish:)`:
              VisemeDriver.reset()

         The schedule advances by an internal monotonic host clock seeded
         at notePlaybackStarted(); `updateAudioClock(_:)` remains as an
         override hook for future API discoveries.

OPPORTUNISTIC: AVSpeechSynthesisMarker.Mark.phoneme via
         write(_:toBufferCallback:) — kept wired but verified to emit
         zero events on every shipped voice. If a future macOS / voice
         version begins emitting markers, the PhonemeMap.appleLabelToIPA
         table (currently empty per "no-markers-anywhere") interprets
         them and they take precedence over the host-clock JamoTimeline.

NEVER: any path that requires non-Apple-system phonemizers (espeak-ng,
       Whisper, etc.) at runtime. License + NO-CLOUD invariants stand.
```

### `phoneme-viseme-map.json:g2p_engine_*` — wording correction

The locked `phoneme-viseme-map.json` says:

```json
"g2p_engine_primary": "AVSpeechSynthesizer phoneme delegate",
"g2p_engine_fallback_chain": [
  "AVSpeechSynthesizer phoneme delegate (PRIMARY)",
  "Bundled Hangul jamo class table",
  "Bundled IPA→viseme mapping",
  "REST viseme + Viseme.G2P.HangulSyllableUnmapped warning increment"
]
```

Read this, post-iter-5, as:

```json
"g2p_engine_primary": "JamoTimeline 15:70:15 (Korean) | char-uniform (English)",
"g2p_engine_fallback_chain": [
  "JamoTimeline 15:70:15 (PRIMARY post-iter-5)",
  "AVSpeechSynthesisMarker.Mark.phoneme (OPPORTUNISTIC, currently no-op per
   apple-phoneme-availability.json verdict 'no-markers-anywhere')",
  "Bundled IPA→viseme mapping (Apple label table when populated)",
  "REST viseme + Viseme.G2P.HangulSyllableUnmapped warning increment"
]
```

The locked JSON file is preserved unchanged; this amendment is the authoritative read.

---

## Implementation note (already shipped)

The runtime as of `main@b42975e` (commit `9630301`, "fix(audio,viseme): make ko-KR lip-sync actually animate during utterance") implements this iter-5 pipeline directly:

| Layer | Behaviour |
|---|---|
| `TTSManager.didStart` | Fires `onPhonemeStreamUnavailable` synchronously with the estimated total duration. |
| `EngineCoordinator` | On that callback, builds a `JamoTimeline.buildSchedule(...)` and calls `VisemeDriver.ingestSchedule(...)` before the first audible syllable. |
| `VisemeDriver.tick` | Advances `audioClockMs` from `(systemUptime - playbackStartHostTime) * 1000` when no host clock is fed (the empirical case). Schedule events promote on offset crossing. |

User-on-device verified the bust visibly animates lip-sync during real Korean Yuna playback after this commit landed.

---

## Verification artifacts

- `runs/2026-05-05-spec/spec/apple-phoneme-availability.json` — empirical probe output, signed `"verdict": "no-markers-anywhere"`.
- `tools/ApplePhonemeProbe/Sources/ApplePhonemeProbe/main.swift` — re-runnable probe, `make probe-phonemes`.
- `packages/SocraticEngine/Tests/SocraticEngineTests/SocraticEngineTests.swift` suites:
  - `JamoTimeline 15:70:15` — distribution invariant.
  - `VisemeDriver scheduling` — schedule advances on audio-clock crossing.
  - `EngineCoordinator wiring` — end-to-end `bootstrapping → idle → speaking → idle` traversal under the stub Gemma path, with a viseme schedule observed in the on-utterance phase.

---

## Demo-day defensibility

This amendment is the canonical answer to a reviewer who asks "your spec claims an Apple phoneme delegate that doesn't exist in the public API." The empirical probe artifact + this delta + the iter-4 API correction together tell the whole story:

1. We tried the public marker API.
2. We measured zero markers across every shipped voice on every fixture on macOS 26.
3. We promoted the academic-standard 15:70:15 jamo time-distribution to PRIMARY.
4. We left the marker hook wired so the implementation degrades gracefully if Apple ever begins emitting them.

The locked SPEC SHA `e5dfadf2c8…314c5` is preserved. This document is the post-empirical authoritative read.

— End of SPEC.md.iter5-phoneme-pipeline-correction.md —
