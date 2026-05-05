# He Was Socrates — Specification (SPEC.md)

| Field | Value |
|---|---|
| Run | `2026-05-05-spec` |
| Authored | 2026-05-05T16:45+09:00 (KST) |
| Schema version | 1.0.0 |
| Authority | This file is the master human-readable narrative. On any conflict between SPEC.md and a sub-spec (e.g. `function_call_contract.yaml`), the sub-spec wins for its scope. On any conflict between SPEC.md and the locked upstream artifacts, the deltas in `proposed-design-delta.json` take priority once user-approved. |
| Locked inputs | `idea.spec.json`, `chosen_preview.json`, `design-approved.json`, `assets/SOURCE.md` |
| Sub-specs | `function_call_contract.yaml`, `coredata-model.md`, `error-catalog.md`, `data-flow-diagram.md`, `performance-test-suite.md`, `demo-day-reliability.md`, `phoneme-viseme-map.json`, `entitlements.plist.md`, `network-test-plan.md`, `model-integrity.md` |

---

## Table of Contents

1. Overview & contract authority hierarchy
2. Architecture summary (M01 load-bearing claim)
3. Function-Call Contract (cross-ref `function_call_contract.yaml`)
4. STT, TTS, and Lip-sync pipeline
5. Performance & demo-day metrics
6. Wondering Log persistence (Core Data)
7. Accessibility (WCAG 2.2 AA)
8. Error model & recovery
9. Permissions, sandbox, entitlements
10. Internationalization & localization
11. Security, privacy, and distribution (incl. COPPA/M08)
12. External Surfaces — binding negative declaration
13. Video script policies & storytelling alignment
14. Deferrals, escalations, and limitations
15. Cross-reference index of audit findings → sections

---

## 1. Overview & contract authority hierarchy

He Was Socrates is a macOS-native fullscreen app that listens to user wonderings, thinks visibly via a thought silhouette, and replies ONLY with re-questions — driven by a 16-viseme lip-synced classical bust. Gemma 4 E4B (MLX-quantized Q4) runs on-device with **zero network egress**. 0 byte cloud is enforced at the entitlement, sandbox-shim, and runtime-test layers.

**Authority hierarchy (top wins on conflict):**
1. `spec/lock.sha256` — proves identity of frozen artifacts
2. `idea.spec.json` + `chosen_preview.json` + `design-approved.json` (locked upstream) AS MUTATED by the user-approved deltas in `proposed-design-delta.json`
3. `function_call_contract.yaml` (machine-readable; for function-call boundary)
4. `coredata-model.md` (for persistence)
5. `error-catalog.md` (for failure surface)
6. SPEC.md (this file; integrative narrative)
7. `entitlements.plist.md`, `model-integrity.md`, `network-test-plan.md` (operational specs)
8. `performance-test-suite.md` + `demo-day-reliability.md` (measurement and operator)
9. `phoneme-viseme-map.json`, `data-flow-diagram.md` (subsystem detail)

**Decision: function-call schema format = JSON Schema 2020-12 at `function_call_contract.yaml`.** OpenAPI 3.1 was rejected because the project has no HTTP surface; an OpenAPI document for a non-HTTP boundary would carry forward HTTP-specific concepts (paths, methods, statuses) that would have to be either ignored or systematically re-interpreted, hiding the contract intent. JSON Schema 2020-12 is a clean fit for Gemma function-calling. (L1 / SC2-001)

## 2. Architecture summary

```
                ┌────────────────────────────────────┐
                │ macOS native fullscreen application │
                │  Swift + SwiftUI, arm64-only        │
                └────────────────────────────────────┘
                                ║
                                ▼
       ┌─────────────────────────────────────────────────────┐
       │  Speech (input)        ←  AVAudioEngine + SFSpeech  │
       │  Gemma orchestration   ←  MLX-Swift, E4B Q4         │
       │  Lip-sync (viseme)     ←  16-PNG @ 30 fps + g2p     │
       │  Speech (output)       ←  AVSpeechSynthesizer       │
       │  Persistence           ←  Core Data + Application   │
       │                            Support, FileVault       │
       │  Error overlay         ←  SwiftUI z-stack           │
       └─────────────────────────────────────────────────────┘
                                ║
                                ╳   ← network severed
```

### 2.1 M01 reframed (USER ESCALATION (b) DELTA-03)

The locked design says "256K context — multi-year wondering log compression and selective injection." The literal interpretation (256K live KV cache tokens) is RAM-infeasible on consumer M-series (~12.5 GB working set; SC6-03). The reframe — APPROVED PENDING USER — is:

> **256K-context CAPABILITY enables long-summary recall via `surface_past_wonder`. Live context window cap = 32K tokens. KV cache dtype = INT8 minimum. Peak RAM ≤ 7 GB on 16 GB Mac. Older entries compressed to ≤ 200-char summaries (`Wonder.thinkingTraceCompressed` pattern) and clustered via `SemanticTag` embeddings for top-K retrieval.**

The architectural promise is preserved: Gemma 4's 256K window is what enables the multi-year recall demo (because compressed summaries can fit a year's wondering in a tiny fraction of the window without the lossy aggressive truncation a 4K-context model would force). The video script's "14-month time-jump" beat is `surface_past_wonder` cosine-top-1 over `Wonder.embeddingHash` cache, NOT live token injection.

### 2.2 Three load-bearing features (M01 ablation)

Per `function_call_contract.yaml#orchestration.ablation_harness`: build flag `SOCRATES_ABLATE` runs 50 sample utterances with one feature disabled. Pass criterion: ablating ANY of (configurable thinking mode, 256K-capability + compressed-recall, native function calling) drops `Gemma 'answers given' rate ≤ 5%` metric below threshold OR breaks the 14-month surfacing demo.

## 3. Function-Call Contract

**Single source of truth: `spec/function_call_contract.yaml`.** SPEC.md only summarizes here; detail lives there.

### 3.1 Four functions

| Function | Inference temp | Streaming | Always-required params |
|---|---|---|---|
| `defer_to_human` | 0.0, seed=0 | no | `user_utterance`, `turn_id` |
| `mode_classify` | 0.0, seed=0 | no | `user_utterance`, `recent_history_compressed`, `turn_id` |
| `ask_back` | 0.7, seed=hash(turn_id) | yes (`AsyncStream<TokenDelta>`) | `user_utterance`, `mode`, `language`, `turn_id` |
| `surface_past_wonder` | 0.0, seed=hash(turn_id) | optional | `user_utterance`, `log_compressed_summary`, `max_surfaced`, `turn_id` |

### 3.2 Common envelope

Every return is wrapped: `{ ok: bool, schema_version: "1.0.0", turn_id: UUID, data?: ..., error?: { code, message_en, message_ko, retryable, ... } }`. RFC-7807 analog. Error codes enumerated in `function_call_contract.yaml#$defs.Error.code`.

### 3.3 Orchestration sequence (per turn)

1. Generate `turn_id = UUIDv4()`.
2. `defer_to_human` first (safety guard; not a mode).
3. If `trigger_category == 'emergency'`: bypass bust, surface full-screen hotline overlay (KO 1393, US-EN 988); record Wonder with `Defer.Emergency.HotlineSurfaced`. STOP.
4. If `trigger_category != 'other'` (regulated advice): bust speaks `explanation_phrase`, recommends resource_class. STOP.
5. `mode_classify` (cached for the turn via `turn_id`; SC5-13 hysteresis applied: change Session.mode only on Δconfidence > 0.15 OR 3 consecutive same-mode).
6. `ask_back` and `surface_past_wonder` in parallel.
7. Stream `ask_back` to TTS at first sentence boundary; append `surface_past_wonder.connector_phrasing` at next sentence boundary if relevant.
8. Persist Wonder with `inferenceFingerprint`, `visemeTimelineCached`, `contentFingerprint`.

### 3.4 Streaming contract (L8 / SC2-002)

`ask_back` returns `AsyncStream<TokenDelta>` with `{ delta, isFinal, sentenceBoundary, turn_id, bcp47Hint? }`. TTS dispatched at first sentence boundary. Back-pressure: AVSpeechSynthesizer queue depth ≤ 2 utterances; further deltas buffer in orchestrator.

### 3.5 Retry (SC5-11)

Max 2 retries per function call. `seed_n = base_seed XOR n` to escape stuck states. Failed attempts NOT persisted to wondering log; written to `~/Library/Application Support/.../diagnostics/` (10 MB rolling). `defer_to_human` is fail-closed: final failure → canned safe phrase ("이건 사람 전문가에게 물어보는 게 좋겠어요." / "This is a question for a real person.").

### 3.6 Naming consistency

Current: `ask_back`, `surface_past_wonder`, `mode_classify`, `defer_to_human`. SC2-011 noted that `mode_classify` is noun-first vs others' verb-first. **Decision (medium-severity): defer rename to v1.1** to avoid late churn; convention documented as "all function names are imperative verb_object snake_case; `mode_classify` is the legacy exception, alias `classify_mode` reserved as a non-breaking minor v1.1 add."

## 4. STT, TTS, and Lip-sync pipeline

### 4.1 STT

- Engine: `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` HARD-CODED. Never falls back to Apple's network recognizer.
- Locale strategy: **Strategy A** (L12) — primary-locale recognition with code-switched-token tolerance; user can manually toggle locale before each utterance. Default = `ko-KR` for the demo target persona.
- End-of-turn detection: **push-to-talk via Space** for demo-day (most reliable; SC6-08).
- Locale model probe at app launch: if either ko-KR or en-US `supportsOnDeviceRecognition == false`, surface `STT.OnDeviceModelMissing.{ko_KR|en_US}` and BLOCK STT until user installs (no cloud fallback).
- Voice Control coexistence (SC1-015): on detection, force push-to-talk only.
- AVAudioSession interruption handling (SC3-012): subscribe to `.interruption` and `.audioEngineConfigurationChange`; on interrupt, freeze bust at REST, surface `STT.AudioInterruption.SystemEvent`.

### 4.2 TTS

- Engine: `AVSpeechSynthesizer`.
- Voice fallback chain (SC3-007 + SC4-004 + SC6-13):
  - ko-KR: Yuna(enhanced) → Heami(enhanced) → Yuna(compact) → Heami(compact) → any ko-KR → text-only with REST viseme + caption (degraded).
  - en-US: Samantha(enhanced) → Alex → Samantha(compact) → any en-US → text-only.
- Per-locale rate calibration (SC4-011): `AVSpeechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate × 0.92` for both ko and en.
- Output device latency compensation (SC6-15): `AVAudioSession.outputLatency` checked at session start; if > 50 ms (Bluetooth), shift viseme schedule by that latency. Demo-day mandate: built-in or wired audio only.
- Code-switched output policy (SC4-005): split into [{text, lang}] segments by Gemma post-processing; queue separately; viseme timeline tracks per-segment with explicit gap allowance ≤ 150 ms.

### 4.3 Lip-sync

- 16 visemes at 30 fps (Reduce Motion Tier 2: 12 fps; Tier 3: static, see §7.3).
- Crossfade: 16 ms (DELTA-06; was 0).
- g2p engine: AVSpeechSynthesizer phoneme delegate (PRIMARY; DELTA-01). espeak-ng dropped (license incompatibility).
- Phoneme→viseme mapping: `spec/phoneme-viseme-map.json` (KO + EN tables, Hangul jamo class fallback).
- Drift target: ≤ 30 ms RMS within segment, ≤ 80 ms peak (DELTA-04).
- Drift recovery state machine (SC3-010): see `error-catalog.md#viseme`.
- Viseme timeline cached in `Wonder.visemeTimelineCached` (CBOR) for replay determinism (SC5-10). Pause/resume continues from frame N; "repeat" plays cached buffer + visemes byte-identical.
- Timing master: AVSpeechSynthesizer's `willSpeakRangeOfSpeechString` delegate (word-grain). Within each word's time-slice, interpolate visemes by phoneme proportion. Per-word re-anchor (SC6-10).

## 5. Performance & demo-day metrics

See `spec/performance-test-suite.md` for full methodology. Summary:

| Metric | M2 Pro/Max (REQUIRED) | M1 (degraded) | Source |
|---|---|---|---|
| Cold launch → ready | ≤ 6 s | ≤ 10 s | SC6-05 |
| Warm TTFT | ≤ 4 s | ≤ 6 s | SC6-01 |
| Drift RMS within segment | ≤ 30 ms | ≤ 50 ms | DELTA-04 / L7 |
| Drift peak | ≤ 80 ms | ≤ 120 ms | DELTA-04 |
| Peak RAM | ≤ 7 GB | ≤ 9 GB | L3 |
| Dropped frames per 5s utterance | ≤ 1 | ≤ 2 | SC6-07 |

**Hardware tier (L4, USER ESCALATION (c)):**
- REQUIRED: MacBook Pro M2 Pro/Max OR Mac mini M2/M2 Pro OR Mac Studio (active cooling, ≥ 16 GB RAM)
- DEGRADED: M2 Air (warn-only, smaller TTFT margin)
- UNSUPPORTED: M1 8 GB, any Intel Mac

Install-time guards (SC3-005): `LSMinimumSystemVersion = 14.0`; arm64-only build; runtime guard at launch detects `hw.optional.arm64`; if 0, present overlay and exit gracefully.

Launch state machine (SC6-05): Splash → Preloading (model SHA check + load) → Ready → Listening → Thinking → Speaking → Idle.

Thermal awareness (SC3-008, SC6-06, SC6-14):
- `NSProcessInfo.thermalState == .serious`: viseme fps → 24, defer `surface_past_wonder`, prefer shorter `ask_back`.
- `.critical`: surface "잠깐 쉬어가요" overlay + freeze REST.

OOM handling (SC3-015): `DispatchSource.makeMemoryPressureSource` evicts non-essential caches on `.warning`; saves and quits gracefully on `.critical`.

## 6. Wondering Log persistence

See `spec/coredata-model.md`. Highlights:

- Storage = Core Data (locked, NOT SwiftData; L13).
- Wonder.id = UUIDv4 random; dedup via separate `contentFingerprint` (SHA-256 of normalized utterance + mode + locale).
- Dedup policy = `accumulate` (always insert); cross-link via `relatedWonderIds` populated by `surface_past_wonder` recall.
- Wonder fields **immutable** after first save (SC5-07): id, createdAt, userUtterance, socraticReply, mode, modeConfidence, bcp47Locale, thinkingTraceCompressed, audioFilePathLocal, inferenceFingerprint, contentFingerprint, visemeTimelineCached.
- Mutable + audited: surfaceLater, tags, _deletedAt.
- Schema versioning via `AppMeta.schemaVersion` (Int); lightweight migration for v1.x; heavyweight = export-to-JSON-and-recreate flow with backup-before-migrate.
- Audio file lifecycle (SC5-09 + SC7-015): `audio/{id}.m4a` (relative path, validated regex), AAC-only, never overwrite, soft-delete + 30 day grace OR immediate purge on COPPA 24 h timer.
- JSON export (SC5-12): byte-stable canonical form, sorted keys, ISO-8601 with KST `+09:00` preserved, top-level `wonderingLogContentHash` for verification.
- SemanticTag.embeddingHash = ONE-WAY SHA (SC7-014); separate local-only embedding cache (encrypted at rest by FileVault, never exported) holds vectors for `surface_past_wonder` semantic search.

## 7. Accessibility (WCAG 2.2 AA — M06 hard floor)

### 7.1 Conformance matrix

Computed contrast ratios per token (SC1):

| Token | Foreground vs `background_ink_black` (oklch 0.15 0.01 280) | CR | Allowed use |
|---|---|---|---|
| `alabaster_bust` (0.92 0.02 75) | | 18.21 | any |
| `warm_amber_accent` (0.78 0.15 75) | | 9.63 | any |
| `user_utterance_dim` (0.55 0.02 280) | | 4.04 | LARGE TEXT ONLY (≥ 32 px); auto-upgrades to `_high_contrast` (0.78 0.02 280) on Increase Contrast |
| `mode_chip_curious_adult` (0.65 0.10 200) | | 6.10 | with shape pattern (disc) |
| `mode_chip_learning_student` (0.65 0.10 145) | | 6.20 | with shape pattern (diamond) |
| `thought_silhouette_pulse_low` (0.25 0.02 280) | | 1.23 | DECORATIVE; replaced by static silhouette + "thinking…" label on Increase Contrast |
| `thought_silhouette_pulse_high` (0.32 0.04 285) | | 1.54 | DECORATIVE; same |

Mode chips MUST always render with both color AND shape pattern AND text label (1.4.1 fix).

### 7.2 VoiceOver routing (SC1-007 SC1-012)

| Element | Role | Label (KO / EN) | Live |
|---|---|---|---|
| Bust container | group | "소크라테스, 듣고 있음" / "Socrates, listening" | — |
| Caption region | static text + live region | (current caption) | polite for ask_back; assertive for defer |
| Thought silhouette | presentation | (decorative; ignored by VO) | — |
| Mode chip | button + state=selected | "Curious adult mode" etc. | — |
| Wondering log entry hint | status | (Wonder.accessibilityNarrative) | polite |

State-transition audio cues (SC1-012): `listening_start`, `thinking_start`, `speaking_start`, `defer_triggered` — short non-speech earcons (≤ 300 ms, ≤ -20 LUFS); also fired as `NSAccessibility.post(notification: .announcement, value: "Socrates is thinking")`.

### 7.3 Reduce Motion 3-tier fallback (L17 / SC1-008)

- **Tier 1** — full 30 fps + thought pulse (default).
- **Tier 2** — 12 fps + pulse off (current `respect_system_reduce_motion`).
- **Tier 3** — static bust + caption-only (NEW; user toggle "Disable lip-sync" in Settings).

Reconciliation: user's mouth-sync requirement = default; a11y is fallback path.

### 7.4 Keyboard contract (SC1-005, SC1-006, SC3-022)

| Shortcut | Action |
|---|---|
| Space | push-to-talk start/stop listening |
| Cmd+Enter | submit typed utterance (text-input a11y mode; reconciles `out_of_scope_v1`'s "no text channel" with WCAG 2.1.1) |
| Esc | exit fullscreen (NEVER intercepted; 2.1.2 invariant) |
| Cmd+M | mode toggle |
| ↑/↓ | surface_past_wonder navigate (post-MVP) |
| Cmd+. | immediate stop & defer |
| Cmd+W | end session |
| Cmd+Q | quit gracefully |
| Cmd+, | open Settings (permissions, voice management, diagnostic export) |

Fullscreen `presentationOptions` allow-list: auto-hide menu bar + auto-hide Dock. **PROHIBITED**: `.disableProcessSwitching`, `.disableAppleMenu`, `.disableForceQuit`. Esc invariant: 1 keypress → exit fullscreen, no confirm.

### 7.5 Caption policy (L18 / SC1-003 + SC1-011)

- DEFAULT-ON for all `socraticReply` utterances.
- Inheritance: if macOS Live Captions / Subtitles is system-ON, app caption auto-ON regardless of user toggle.
- Child Mode: forced-on (override impossible).
- Word-boundary highlight (`weight_speech_highlighted_word: 600`) independent of caption toggle.

### 7.6 Larger Text / Dynamic Type (SC1-009)

- Use `NSFont.preferredFont(forTextStyle: ...)` family; respect `NSAccessibilityDisplayShouldDifferentiateWithoutColor` and Dynamic Type-equivalent.
- Caption max-width: `min(28em, 60vw)`.
- Child Mode default scale +20%.

### 7.7 High-Contrast & Reduce-Transparency (SC1-010)

- All color tokens have `_hi_contrast` variants (DELTA-07).
- `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast` toggles palette.
- Thought silhouette pulse → static silhouette + "thinking…" text label on Increase Contrast.
- `accessibilityDisplayShouldReduceTransparency` removes any blur/translucency.

### 7.8 Child Mode a11y defaults (SC1-011)

- Caption forced-on.
- Font scale +20% (multiplied with Larger Text).
- Viseme default Tier 2 (12 fps); user can configure.
- `ask_back.reading_level = 6` (Korean grade-equivalent: elementary).
- Automatic-utterance start FORBIDDEN (handshake required; SC1-004 strengthened).
- `defer_to_human` threshold lower.

### 7.9 Hover Text and Voice Control (SC1-013, SC1-015)

All textual UI gets `.help()` / `.accessibilityHint()`. Bust hint = "Socrates listens and asks back. Press Space to speak." Voice Control detection forces push-to-talk only.

### 7.10 Focus visible (SC1-016)

`focus_ring_color = warm_amber_accent` (CR 9.63), 3 px width, `NSFocusRingType.exterior`. (DELTA-07)

## 8. Error model & recovery

See `spec/error-catalog.md` for the full catalog. Modality matrix:

| Modality | Used for |
|---|---|
| `bust_caption_redirect` | recoverable in-character (bust says "say it again?"); STT.LowConfidence, retry-soft-paths |
| `overlay_modal` | mid-z modal above bust; permission denials, voice unavailable, integrity mismatch, storage corruption |
| `overlay_emergency_full_screen` | bypass bust character; suicide/emergency hotline (KO 1393 / US-EN 988) |
| `silent_state_change` | pulse amplitude change, viseme micro-adjust, OfflineProofBadge counter increment |
| `onboarding_block` | first-launch-only (Korean dictation not installed, voice not installed, M1 8GB warn) |
| `process_death` | crash → write to ~/Library/Logs/HeWasSocrates/crashdumps/, redact child-mode utterances |

**Bust never speaks errors** (stays in Socratic character). Error-overlay design tokens added in DELTA-07.

## 9. Permissions, sandbox, entitlements

See `spec/entitlements.plist.md`. Required entitlements: `app-sandbox`, `device.audio-input`, `files.user-selected.read-write`. Prohibited: `network.client`, `network.server`, `cs.disable-library-validation`, `cs.allow-unsigned-executable-memory`, `cs.allow-dyld-environment-variables`, `device.camera`, `personal-information.{location,calendars,contacts,photos-library}`. CI gate enforces.

Info.plist usage strings (KO + EN) verbatim in entitlements.plist.md §4. SFSpeechRecognizer hard-coded with `requiresOnDeviceRecognition = true`.

TCC revocation state machine (SC7-013): pre-flight on every audio session start; revocation → `AwaitingPermissionState` UI with deeplink to System Settings; auto-resume on `NSApplication.didBecomeActive`.

## 10. Internationalization & localization

### 10.1 Locale tag schema (L11)

- Function-call `language` enum: `ko | en | auto` (Gemma simplicity).
- Persistence (Wonder.bcp47Locale): BCP-47 only — `ko-KR | en-US | mixed | und`.
- Mapping: `ko → ko-KR`, `en → en-US (canonical)`, `auto → resolve-then-persist`.
- `auto` NEVER reaches Core Data.
- Wonder gains `bcp47SecondaryLocale` for code-switched utterances.

### 10.2 Mixed-language STT (L12 / DELTA-05)

Strategy A: primary-locale recognition; `idea.spec.json#success_criteria` revised to "primary-language word accuracy ≥ 90%; code-switched foreign tokens MAY be transliterated."

### 10.3 Code-switched TTS (SC4-005)

Gemma post-processes `ask_back` text into `[{text, lang}]` segments; each segment a separate AVSpeechUtterance. Inter-segment gap ≤ 150 ms, labeled deliberate pause. Drift target applies WITHIN segment.

### 10.4 Cross-locale wondering log (SC4-009)

Connector phrasing quotes past wondering verbatim in original language with quotation marks, frames in current-session language. Example en → ko: 'You once wondered, 「얼음이 미끄러운 건 얼음 때문일까」 — does that sit alongside what you ask now?'. `surface_past_wonder.returns` includes `past_locale` + `current_locale`.

### 10.5 Date formatting (SC4-012)

- UI: `DateFormatter` with current-UI locale, `dateStyle = .long`, `timeStyle = .short`.
- Relative: `RelativeDateTimeFormatter`.
- JSON export: ISO 8601 with KST `+09:00` preserved (DO NOT normalize to UTC; preserves wall-clock memory).

### 10.6 Font fallback (SC4-007)

`font_classical_serif` extended: `"Times New Roman, Source Serif Pro, Iowan Old Style, AppleMyungjo, Noto Serif CJK KR, serif"`. AppleMyungjo is bundled on macOS 14 and provides true Korean serif for mixed-locale captions. SwiftUI helper picks per-glyph-range font using AttributedString runs.

### 10.7 Localized enums and strings (SC4-008, SC4-010)

- `defer_to_human.suggested_resource_class`: stable enum (see `function_call_contract.yaml#$defs.ResourceClass`); Localizable.strings holds KO+EN labels.
- Mode chip labels: keys `mode.curious_adult.label`, etc.

### 10.8 Korean register policy (SC4-017)

Gemma system prompt: 해요체 (polite, warm, slightly elevated) for both adult and student modes. Mode does NOT change register. 3 KO + 3 EN exemplars in `spec/gemma-system-prompt.md` (deferred to iter-2 author).

### 10.9 Canonical translations table (SC4-018)

| Korean | English |
|---|---|
| 소크라테스는 답하지 않는다. 묻는다. | Socrates does not answer. He asks. |
| 왜 어떤 노래는 들으면 우는지? | Why do some songs make me cry when I hear them? |
| 법률·의료·금융 자문이 필요한 사람 | people who need legal, medical, or financial advice |

Locked across Writeup, README, video subtitle, App Store description.

### 10.10 RTL declaration (SC4-016)

v1 supports LTR only. Korean and English are both LTR. Arabic/Hebrew/Persian = `out_of_scope_v1` (additive). Root SwiftUI view forces `.environment(\.layoutDirection, .leftToRight)` until v2.

### 10.11 App Bundle Localization (SC4-014)

`Info.plist`: `CFBundleDevelopmentRegion = en`, `CFBundleLocalizations = ['en','ko']`. `en.lproj/` and `ko.lproj/` ship with Localizable.strings + InfoPlist.strings.

## 11. Security, privacy, distribution (incl. COPPA / M08)

### 11.1 Sandbox & 0-byte egress

See §9 + `network-test-plan.md`. Layered enforcement: build-time entitlement gate, telemetry-string scan, runtime NSURLProtocol shim, demo-day live `nettop` proof.

### 11.2 Model integrity

See `model-integrity.md`. SHA-256 of weights baked into binary at build time; runtime check refuses launch on mismatch. Never re-downloads.

### 11.3 Gemma TOU (SC7-003)

- Bundled weights governed by Gemma Terms of Use (NOT Apache-2.0 repo license).
- `/licenses/GEMMA_TOU.txt` shipped in repo.
- About > Acknowledgments view surfaces TOU + attribution.
- SHA-256 of weights in `spec/MODEL_HASHES.json`.
- `function_call_contract.yaml#$defs.RegulatedAdviceCategory` aligned with Gemma TOU prohibited-use categories.
- License header for `/Resources/models/*` explicitly states GEMMA_TOU governs (NOT Apache-2.0).

### 11.4 Portrait provenance (SC7-008 / USER ESCALATION (d))

Stub at `/assets/socrates-portrait.PROVENANCE.md`. Three resolution paths offered (AI-gen / hand-drawn / public-domain). **Status: UNKNOWN — pending user declaration.** Hackathon DMG ships with stub; **Mac App Store submission is BLOCKED** until declared. SPEC.md adds carve-out: hackathon-DMG-only operation acknowledged as IP-untested. Same provenance binding extends to 16 viseme PNGs derived from the portrait.

### 11.5 g2p license (SC7-002 / USER ESCALATION (a))

espeak-ng REMOVED. AVSpeechSynthesizer phoneme delegate (Apple system framework) is primary. DELTA-01 + DELTA-02 of `proposed-design-delta.json`.

### 11.6 Voice impersonation policy (SC7-009)

- MVP: ONLY Apple system AVSpeechSynthesizer voices.
- Voice Pack DLC reserved post-MVP: each voice = (1) Apple system OR (2) consented voice-actor recording with written release OR (3) public-domain historical (Socrates has none — explicitly NOT cloned).
- The bust speaks in a NEUTRAL synthesizer voice. NEVER claimed to be a "Socrates voice clone."
- Captions show "Voice: Apple System (Yuna)" during demo.

### 11.7 COPPA flow (M08 / L19 / SC7-004)

See `spec/data-flow-diagram.md`. Verifiable Parental Consent BEFORE microphone activation. `AppMeta.consentSource` enum. Auto-detection acts as safety override only — purges utterance if consent gate not yet passed. School-deployment reservation in schema (SC7-018) but out of MVP.

### 11.8 macOS-correct backup posture (SC7-010)

Replaces `idea.spec.json` "File Protection complete" wording. macOS uses FileVault (user-level) + `NSURLIsExcludedFromBackupKey = true` on Application Support. Time Machine caveat disclosed in COPPA consent screen. Audio = AAC in M4A (never raw PCM).

### 11.9 Path-traversal protection on import (SC7-015)

`Wonder.audioFilePathLocal` regex `^audio/[0-9a-f-]{36}\.m4a$`. JSON import rejects `..` or absolute paths.

### 11.10 Secrets & credentials hygiene (SC7-011)

`.gitignore` + pre-commit `gitleaks` scan + `xcrun notarytool store-credentials`. App contains ZERO secrets (vacuously, no network).

### 11.11 Codesign + Hardened Runtime (SC7-012)

See `entitlements.plist.md` §6. `--options runtime --timestamp`. Library Validation default-ENABLED. JIT entitlement OMITTED unless verified needed.

### 11.12 Auto-update (SC7-019)

NO Sparkle. NO auto-update for MVP. Manual download from project page; About > Check for Updates is a text-only URL. Mac App Store post-MVP handles updates natively.

### 11.13 Telemetry policy (SC7-017)

Affirmatively prohibits all third-party analytics SDKs. CI gate scans the binary for known telemetry domains. macOS CrashReporter is local-only by default. User-initiated diagnostic export only.

### 11.14 Logging hygiene (SC7-021)

`%{private}` format specifier for any user-content variable. Lint rule rejects `%{public}` on user-content variables. Crash logs redact `userUtterance` / `socraticReply` in child mode (SC3-017).

### 11.15 Distribution size (SC3-018)

Hackathon: DMG primary; ~4.2–4.5 GB. Notarization deadline = W2 Tuesday (May 12). Post-MVP MAS: explore On-Demand Resources (Apple-hosted, does not violate `no_go` "non-Apple source" rule).

### 11.16 Prompt injection (SC7-007)

System prompt is compiled into the binary as a const; never user-modifiable. Adversarial test set at `spec/prompt-injection-tests.md` (12+ utterances spanning override, role-play, regulated-advice probes, jailbreak templates). Acceptance: 100% of regulated-advice probes route to `defer_to_human`; 0% of overrides cause direct answer.

### 11.17 SBOM (SC7-016)

`/sbom/he-was-socrates.cdx.json` (CycloneDX 1.5) at every release tag. `/licenses/` directory per-component. Pre-flight verifies all SPM deps are SPDX-permissive-compatible. About > Acknowledgments displays.

### 11.18 Sustainability partner (M12 / USER ESCALATION (e))

TBD before submission deadline 2026-05-19. 4 candidates: Khan Academy 한국지부 / OER 공동체 / 한국교총 / KAIST AI 교육연구센터. Writeup deliverable, not spec deliverable.

## 12. External Surfaces — binding negative declaration

Per SC2-010 + SC7. The ONLY documented surfaces are:
1. 4 internal Gemma function calls (`function_call_contract.yaml`)
2. Speech framework input
3. AVSpeechSynthesizer output
4. Core Data storage (local)
5. Optional user-initiated JSON export (NSOpenPanel, user-chosen path)
6. Apple system Accessibility tree (caption + mode chip exposed for VoiceOver; wondering log NOT exposed)

ABSENT (binding declaration): HTTP server, AppleScript .sdef, NSXPC, URL scheme, Universal Links, share extension, Spotlight CoreSpotlight, Siri Shortcuts donation, debug WebSocket, file-watch outside container, MetricKit, Sentry/Crashlytics/Mixpanel/Segment/Amplitude/Datadog/Bugsnag/AppCenter, Bonjour advertise/browse, Sparkle.

## 13. Video script policies & storytelling alignment

### 13.1 M11 storytelling 30/30 alignment

Video script stays at high emotional resonance per M11. Closing caption is BILINGUAL (SC4-013):
- Line 1 (Korean primary): "소크라테스는 답하지 않는다. 묻는다."
- Line 2 (English subtitle, smaller weight): "Socrates does not answer. He asks."

Both languages baked into MP4 (not toggleable; preserves typography). Korean uses AppleMyungjo serif fallback chain.

### 13.2 Cold open beat (M04)

`design-approved.json#video_script_skeleton` 0:00-0:10 keeps "menu bar disappears + airplane-mode toggle + 0 KB sent counter" beat, BUT preceded by an off-camera or splash-covered preload (SC6-05). The visible beat is the warm-path transition, not cold launch.

### 13.3 Evidence beats

- 2:30-2:50: Activity Monitor showing 0 network requests + RAM under cap (per L3 reframed M01).
- Optional: live `nettop` inset.

## 14. Deferrals, escalations, and limitations

### 14.1 Deferred to TestDD or post-MVP

(See `spec/triage-iter-1.md` §3.2 for full table.)

| Item | Defer to |
|---|---|
| Wondering log review UI | post-MVP (schema reserves a11y fields) |
| Function rename `mode_classify → classify_mode` | post-MVP v1.1 (alias) |
| App Store Connect localized metadata | MAS submission post-MVP |
| Korean register exemplar set | iter-2 SC4 author refinement |
| Video bilingual subtitle bake | video shoot W2 |
| 1-year-of-data scaling test | TestDD |

### 14.2 USER ESCALATIONS (5 items, batched)

| # | Question | Default applied if silent | Blocks freeze? |
|---|---|---|---|
| (a) | Reverse `g2p_engine_primary`: espeak-ng → AVSpeechSynthesizer phoneme delegate | applied (DELTA-01) | for MAS path — see §11.4; NOT for hackathon |
| (b) | Reframe M01 256K → compressed-recall + 32K live | applied (DELTA-03) | no |
| (c) | Demo-day machine = REQUIRED tier (M2 Pro+) | applied | no, but recommend commit before video shoot |
| (d) | Portrait provenance (AI-gen / hand-drawn / public-domain) | stub flagged UNKNOWN | no for hackathon DMG; YES for MAS |
| (e) | Sustainability partner pick | TBD; Writeup | no |

### 14.3 Single-thread author limitation (transparency)

This SpecDD run was driven within one Claude Code thread without sub-agent dispatch (no Task tool in this environment). SPEC_LEAD performed the SPEC_AUTHOR role and the SC1–SC7 round-2 critic re-review inline. This is honest about the limitation: the author and round-2 critics are the same model in different personas, not genuinely independent minds. Cross-critic conflict resolution is therefore SPEC_LEAD's call rather than emergent panel consensus. Cited explicitly in `spec/freeze-summary.md`.

## 15. Cross-reference index

| Finding | Section / file |
|---|---|
| SC1-001..016 | §7 + DELTA-07 |
| SC2-001..016 | §3 + `function_call_contract.yaml` |
| SC3-001..024 | §8 + `error-catalog.md` |
| SC4-001..018 | §10 |
| SC5-01..14 | §6 + `coredata-model.md` |
| SC6-01..19 | §5 + `performance-test-suite.md` + `demo-day-reliability.md` |
| SC7-001..021 | §11 + `entitlements.plist.md` + `network-test-plan.md` + `model-integrity.md` |
| L1..L20 | §1 + `triage-iter-1.md` |
| M01..M12 | §2.1, §11.7, §11.18, §13 |
| DELTA-01..11 | `proposed-design-delta.json` |

— End of SPEC.md —
