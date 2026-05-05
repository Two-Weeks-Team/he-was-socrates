# Performance Test Suite — He Was Socrates

**Authored:** 2026-05-05T16:25+09:00 (KST)
**Addresses:** SC6-01, SC6-02, SC6-04, SC6-05, SC6-07, SC6-08, SC6-10, SC6-11, SC6-12, SC6-13, SC6-14, SC6-15, SC6-16, SC6-17, L3, L4, L7

This artifact makes demo-day metrics falsifiable and reproducible. Companion to `spec/demo-day-reliability.md` (the operator's checklist).

---

## 1. TTFT phase diagram (SC6-01)

TTFT = "Time To First Viseme." Defined as: from the moment the user releases the push-to-talk Space key (or the VAD declares end-of-utterance) to the moment the first non-REST viseme PNG paints on screen.

```
[user releases Space]
  ↓ Δ1: STT finalize (SFSpeechRecognizer commits final transcription)
[final user_utterance string]
  ↓ Δ2: orchestrator dispatches defer_to_human + mode_classify in parallel
[both return]
  ↓ Δ3: orchestrator dispatches ask_back + surface_past_wonder in parallel
[ask_back streams first sentence boundary]
  ↓ Δ4: AVSpeechSynthesizer prepare + first willSpeakRangeOfSpeechString delegate fires
[first word boundary anchor]
  ↓ Δ5: g2p produces phoneme list for first word; first non-REST viseme picked
[first non-REST viseme paints]
```

Per-stage budget on the REQUIRED hardware tier (L4):

| Stage | M2 Pro/Max budget | M1 (degraded) budget |
|---|---|---|
| Δ1 STT finalize | ≤ 800 ms | ≤ 1000 ms |
| Δ2 defer + mode_classify (parallel) | ≤ 600 ms | ≤ 1200 ms |
| Δ3 ask_back to first sentence + surface_past_wonder | ≤ 1800 ms | ≤ 3000 ms |
| Δ4 AVSpeech prepare + first delegate fire | ≤ 350 ms | ≤ 500 ms |
| Δ5 g2p + viseme paint | ≤ 100 ms | ≤ 150 ms |
| **Sum (warm TTFT)** | **≤ 3650 ms (≈ 4 s)** | **≤ 5850 ms (≈ 6 s)** |

This makes the original `idea.spec.json` "TTFT ≤ 8s on M2/M3, ≤ 12s on M1" easily achievable on warm path. Warm vs cold distinction:

| Phase | M2 Pro/Max budget |
|---|---|
| App cold-launch to ready-prompt UI | ≤ 6 s |
| Warm TTFT | ≤ 4 s |

Demo-day metric is the WARM TTFT only (per L4 launch state machine; preload happens behind splash).

---

## 2. Drift measurement (SC6-04 L7)

Definition: instantaneous drift = (time when viseme PNG paints) − (time AVSpeechSynthesizer reports word boundary via willSpeakRangeOfSpeechString delegate). Sample at every word boundary.

Targets (revised from `idea.spec.json`'s ≤ 50 ms RMS):

| Metric | Target | Source |
|---|---|---|
| Within-segment RMS | ≤ 30 ms | L7 |
| Within-segment peak | ≤ 80 ms | L7 |
| Inter-segment gap (code-switched) | ≤ 150 ms tolerated, labeled deliberate pause | SC4-005 |
| Reduce Motion Tier 2 (12 fps) tolerance | ≤ 83 ms RMS (1 frame) | SC1-008 |

Measurement methodology:
1. Record 5 utterances per locale × 5 utterances per code-switched style = 30 samples.
2. Capture `(audio_engine_render_time, viseme_paint_time)` pairs via signposts.
3. Compute RMS and peak per utterance and per dataset.
4. Pass criteria: 95% of utterances satisfy targets; failing utterances logged for SC6-10 timing-master analysis.

Drift recovery state machine (SC3-010):
- < 33 ms: no action.
- 33–100 ms: micro-adjust frame duration (skip or repeat one frame).
- 100–250 ms: snap to next word boundary (NOT mid-word).
- ≥ 250 ms: freeze on REST viseme; log `Viseme.StallRecovery`.

---

## 3. Frame-pacing methodology (SC6-07)

- Render via `CADisplayLink` synced to display refresh.
- Forbid initiating MLX inference while AVSpeechSynthesizer is mid-utterance (one inference + one TTS + viseme paint can co-exist; two inferences cannot).
- Target: ≤ 1 dropped frame per 5-second utterance.
- Tooling: Instruments → Animation Hitches template; signpost emit per frame.

---

## 4. End-of-turn detection (SC6-08)

Demo-day default = **push-to-talk via Space**. Most reliable; eliminates ~1.8 s SFSpeechRecognizer trailing-silence debounce.

Shipped-product future: VAD with 600–800 ms silence threshold, layered on top of partial transcripts.

---

## 5. Dictation language pack probe (SC6-12)

At app launch:
```swift
let supportsKO = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))?.supportsOnDeviceRecognition ?? false
let supportsEN = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.supportsOnDeviceRecognition ?? false
```

If either is false, surface `STT.OnDeviceModelMissing.{ko_KR|en_US}` and BLOCK STT until installed (no cloud fallback). SC4-015.

---

## 6. AVSpeechSynthesizer voice probe (SC6-13)

At app launch:
```swift
let voices = AVSpeechSynthesisVoice.speechVoices()
let yunaEnhanced = voices.first(where: { $0.identifier.contains("ko-KR.Yuna") && $0.quality == .enhanced })
let samanthaEnhanced = voices.first(where: { $0.identifier.contains("en-US.Samantha") && $0.quality == .enhanced })
```

Fallback chain per `error-catalog.md#TTS.VoiceUnavailable`:
- ko-KR: Yuna (enhanced) → Heami (enhanced) → Yuna (compact) → Heami (compact) → any ko-KR → text-only with REST + caption (degraded)
- en-US: Samantha (enhanced) → Alex → Samantha (compact) → any en-US → text-only

---

## 7. Audio output latency compensation (SC6-15)

```swift
let outputLatency = AVAudioSession.sharedInstance().outputLatency  // seconds
if outputLatency > 0.050 {  // > 50 ms
    visemeScheduler.shiftBy(outputLatency)  // shift viseme schedule ahead by that much
    // OR: degrade to static face if output latency catastrophic and shift is unstable
}
```

Demo-day mandate: built-in speakers or wired output only; no AirPods.

---

## 8. Wondering log retrieval (SC6-16)

- Embedding model: Apple `NLEmbedding` (Apache-2.0 system framework) for MVP; Gemma embedding head reserved post-MVP.
- Top-K = 3 cosine over `Wonder.embeddingHash` (one-way SHA — see SC7-014 caveat: SHA cannot semantic-search; therefore for surface_past_wonder we maintain a parallel ENCRYPTED-AT-REST embedding cache `~/Library/Application Support/com.twoweeks.hewassocrates/embedding-cache/`, NOT exported).
- Latency budget: retrieval ≤ 100 ms, embedding generation ≤ 50 ms.

> **Reconciliation note:** SC7-014 wants embeddingHash to be one-way (SHA). SC6-16 wants semantic search. Resolution: `Wonder.embeddingHash` field stays one-way (SHA — for tag dedup and exported safety). A SEPARATE local-only embedding cache (encrypted at rest by FileVault, never exported) holds the real vectors for surface_past_wonder. Best of both.

---

## 9. Crash recovery RTO (SC6-17)

- Target ≤ 10 s on M2 Pro from process restart to ready-listening state.
- Achieved by: (a) MLX model file mmap-resident if process re-launches within 60 s (macOS file cache likely warm), (b) `Session.endedAt = nil` sentinel for in-progress session, resume to last Wonder.

---

## 10. Memory pressure handling (SC3-015)

```swift
DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main).setEventHandler {
    switch source.mask {
    case .warning:
        VisemeCache.evictNonEssential()
    case .critical:
        SessionManager.saveAndQuit(reason: .oomGracefulExit)
    default:
        break
    }
}
```

---

## 11. Pass/fail summary table

| Metric | M2 Pro/Max target | M1 target | Measurement |
|---|---|---|---|
| Cold launch → ready prompt | ≤ 6 s | ≤ 10 s | from `applicationDidFinishLaunching` to listening state |
| Warm TTFT | ≤ 4 s | ≤ 6 s | end-of-utterance to first non-REST viseme |
| Drift RMS within segment | ≤ 30 ms | ≤ 50 ms | per §2 |
| Drift peak | ≤ 80 ms | ≤ 120 ms | per §2 |
| Dropped frames per utterance | ≤ 1 in 5 s | ≤ 2 in 5 s | Instruments |
| RAM peak | ≤ 7 GB | ≤ 9 GB | Activity Monitor |
| Thermal state during 5 min | ≤ `.fair` | ≤ `.serious` | NSProcessInfo |

---

## 12. Cross-references

- L3, L4, L7, M01 (256K reframe), M04 (OfflineProofBadge ⇄ network-test-plan.md)
- SC6 cluster, SC1-008 (Reduce Motion Tier 2 tolerance), SC3-010 (drift state machine)
- `spec/demo-day-reliability.md` for the operator-facing checklist
