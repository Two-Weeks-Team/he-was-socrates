# SPEC.md Iter-4 Amendment — AVSpeechSynthesizer Phoneme API Correction

| Field | Value |
|---|---|
| Authority | User ratification 2026-05-05 KST after research finding |
| Source | `runs/2026-05-05-spec/spec/viseme-best-practices.md` §7.1 (CRITICAL) |
| Affects | `SPEC.md §4.3` (TTS + Lip-sync subsystem) + `phoneme-viseme-map.json:g2p_engine_*` |
| SHA-256 lock | **NOT recomputed**. Treat this amendment as authoritative for downstream scaffold; freeze v1 SHA preserved for audit. |

---

## Background

The original SpecDD (frozen 2026-05-05 14:25 KST) §4.3 stated the lip-sync
pipeline derives phonemes from an *"AVSpeechSynthesizer phoneme delegate"*.
Research (`viseme-best-practices.md` §1.3 + §7.1) verified against
[Apple's official AVSpeechSynthesizerDelegate documentation][s8] and
[WWDC 2020 session 10022][s10] that **no such delegate method or
protocol exists** in the AVSpeechSynthesizer API. The closest equivalents are:

| API | What it provides | Phoneme info? |
|---|---|---|
| `AVSpeechSynthesizerDelegate` | utterance lifecycle, willSpeak range (word boundaries), cancellation | ❌ no phoneme stream |
| `AVSpeechSynthesisIPANotationAttribute` | input-side IPA hint | ❌ this is for *input*, not for receiving |
| `AVSpeechSynthesizer.write(_:toBufferCallback:)` | streamed PCM buffers + `[AVSpeechSynthesisMarker]` per buffer | ✅ **`.phoneme` markers added macOS 14+** |

The third API is the actual mechanism. It carries
`AVSpeechSynthesisMarker` objects whose `.mark` property can be `.phoneme`
(among others). The phoneme `value` is a **voice-engine-specific string label**,
not an IPA symbol.

## Scope of correction

### S1. SPEC.md §4.3 wording — replace verbatim

**OLD wording (frozen):**
> The phoneme stream is consumed via the `AVSpeechSynthesizer` phoneme delegate
> (PRIMARY; DELTA-01) and mapped to the 16-viseme set per
> `spec/phoneme-viseme-map.json`.

**NEW wording (this amendment):**
> The phoneme stream is consumed via `AVSpeechSynthesizer.write(_:toBufferCallback:)`
> (macOS 14+), filtering `AVSpeechSynthesisMarker` instances where
> `marker.mark == .phoneme`. The marker `.value` is an **Apple-internal,
> voice-engine-specific phoneme label** (NOT IPA), which the runtime maps to
> IPA via `apple_phoneme_to_ipa.json` (built empirically at scaffold start;
> see §S3 below) and then to the 16-viseme set per
> `spec/phoneme-viseme-map.json`.
>
> **ko-KR availability caveat:** Apple has not publicly documented whether
> `.phoneme` markers are emitted by ko-KR voices (Yuna, Heami) on macOS 14.
> If markers are absent or sparse, the runtime falls back to the
> **time-uniform jamo distribution model**: each Hangul syllable's audio
> duration is split (initial:medial:final) = 15%:70%:15% across the
> initial-consonant, vowel, and final-consonant viseme respectively
> (academic standard per the Korean Co-articulation paper, ASK 1999 / J Korea
> CGS 26(3)). The fallback is determined by Stage-5 day-1 empirical capture.

### S2. `phoneme-viseme-map.json:g2p_engine_*` — fallback chain delta

The frozen `phoneme-viseme-map.json` declares `g2p_engine_primary` and
`g2p_engine_fallback` directly. This amendment inserts an intermediate level:

```jsonc
// CONCEPTUAL — see runs/2026-05-05-spec/spec/phoneme-viseme-map.delta.json for the real patch
{
  "g2p_engine_primary": "AVSpeechSynthesizer.write(_:toBufferCallback:) → AVSpeechSynthesisMarker.phoneme (macOS 14+)",
  "g2p_engine_fallback_chain": [
    "1.0  Apple-label → IPA via apple_phoneme_to_ipa.json (built at scaffold start, deterministic, empirically captured)",
    "1.5  ko-KR jamo time-uniform distribution if Apple markers absent for ko-KR voice (15% / 70% / 15%)",
    "2.0  pre-computed dictionary lookup (top-N most-common ko+en words bundled in app)",
    "3.0  REST hold (silent fallback if all upstream layers fail)"
  ]
}
```

### S3. New scaffold task — `tools/capture-apple-phonemes.swift`

A Swift CLI tool, run **once per release** at scaffold time, on the
fixed list of `_test_fixture_utterances` declared in
`spec/SPEC.md` §4.4. For each utterance × each system voice, it:

1. Constructs an `AVSpeechUtterance(string:)` with the voice set.
2. Calls `synthesizer.write(utterance, toBufferCallback:)`.
3. Logs every `AVSpeechSynthesisMarker` received: `(mark, value, audioOffset, byteOffset)`.
4. Aggregates the unique `(voice, mark==.phoneme, value)` set into a JSON map.
5. For each unique Apple label, the human (or g2pK pipeline for ko-KR) supplies the IPA equivalent — committed to `apple_phoneme_to_ipa.json`.
6. CI guard: rebuild fails if any test-fixture utterance produces a marker with a label NOT in `apple_phoneme_to_ipa.json`.

This is now part of Phase 4 (real Gemma + audio integration) per
`scaffold-plan-proposal.md`.

### S4. Stage-5 day-1 verification gate

**Before any other Stage 5 work begins, the developer must:**

1. Run a probe: synthesize the seed phrases
   `["안녕", "hello", "왜 어떤 노래를 들으면 우는지?"]`
   through `Yuna`, `Heami`, `Samantha`, `Alex`, log all markers.
2. Decision tree based on output:
   - **All four voices emit `.phoneme` markers** → proceed with §S1's NEW wording, build `apple_phoneme_to_ipa.json` per §S3.
   - **Only en-US voices emit, ko-KR silent** → proceed with §S1 NEW wording for en-US + jamo-uniform fallback for ko-KR (§S1 caveat). Update demo-day-reliability.md to note the asymmetric sub-pipeline.
   - **None emit** → invoke jamo-uniform fallback for both languages. Update SPEC.md §4.3 again with a stronger "no Apple phoneme stream available, time-uniform model only" note. Demo video must avoid claiming "phoneme-accurate lip-sync" — claim "syllable-rate lip-sync" instead.

The decision artifact: `runs/2026-05-05-spec/spec/apple-phoneme-availability.json`
(written by the Day-1 probe, ratified by user).

## What is NOT changed by this amendment

- The 16-viseme set itself.
- The `mode_classify` / `ask_back` / `surface_past_wonder` / `defer_to_human`
  function-call schema (§5).
- The Core Data wondering log schema (§6).
- The COPPA / sandboxing / no-cloud invariants (§7, §8, §9).
- `spec/SPEC.md.iter2-amendment.md` (still authoritative for items A1–A7).
- Any of the 17 SHA-locked artifacts; the v1 freeze hash
  `e5dfadf2c85199173b54766a2322c8a9009f353e3ea1dcd064b8d8e9f07314c5` remains
  the reference. **This amendment lives outside the locked set.**

## Demo-day storytelling implication

A Kaggle reviewer who knows the Apple AVSpeechSynthesizer API would have
flagged the original "phoneme delegate" wording as technically incorrect.
The video script + Writeup must use the corrected terminology:

- ✅ `"using AVSpeechSynthesizer's phoneme marker stream (macOS 14+)"`
- ❌ ~~`"using the AVSpeechSynthesizer phoneme delegate"`~~

If the Day-1 probe shows ko-KR doesn't emit markers, the script also adds
a brief honest line:

> *"한국어 보이스의 경우 시스템 음운 마커가 부족하기 때문에 자모 시간 분배
> 방식으로 fallback합니다."*

This is honesty-as-storytelling — judges respond well to acknowledged
limitations + working fallbacks better than to glossed-over claims.

## References

- [s8] [Apple AVSpeechSynthesizerDelegate](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate)
- [s9] [AVSpeechSynthesisIPANotationAttribute](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisipanotationattribute)
- [s10] [WWDC 2020 — Create a seamless speech experience](https://developer.apple.com/videos/play/wwdc2020/10022/)
- Korean phoneme/viseme: [ASK 1999](https://koreascience.kr/article/CFKO199920828527868.page) + [J Korea CGS 26(3)](http://journal.cg-korea.org/archive/view_article?pid=jkcgs-26-3-49)

End of iter-4 amendment.
