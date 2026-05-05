# Scaffold Plan Proposal — He Was Socrates (Stage 5)

**Status:** PROPOSAL — pending user approval before any code is written.
**Author:** Claude main thread, 2026-05-05 KST
**Goal stated by user:** "기존 SPEC을 유지하는 것이 목적" — preserve frozen SpecDD as much as possible. The attached painterly Socrates is **visual-direction guidance**, not a stack pivot.

**Inputs locked (SHA `e5dfadf2…314c5`):** `idea.spec.json`, `chosen_preview.json`, `design-approved.json`, `spec/SPEC.md`, `spec/SPEC.md.iter2-amendment.md`, `spec/function_call_contract.yaml`, `spec/coredata-model.md`, `spec/error-catalog.md`, `spec/data-flow-diagram.md`, `spec/performance-test-suite.md`, `spec/demo-day-reliability.md`, `spec/phoneme-viseme-map.json`, `spec/entitlements.plist.md`, `spec/network-test-plan.md`, `spec/model-integrity.md`, `spec/proposed-design-delta.json`, `spec/triage-iter-1.md`. **No mutation of any of these.**

**Ratifications applied:** (a) espeak-ng dropped → AVSpeechSynthesizer phoneme delegate primary, (b) M01 256K → "compressed multi-year recall" reframe, (c) demo-day machine = M2 Pro+ fan-cooled plugged-in, (d) portrait = AI-generated, hygiene tracking out-of-scope, (e) M12 partner = withdrawn (out of hackathon scope).

**Timeline target:** Submission 2026-05-19T08:59+09:00. Days remaining at scaffold kickoff = ~13.

---

## Phase 0 — Pre-flight (½ day)

Goal: scaffold-ready state, zero code yet.

- [ ] User picks asset-authoring path A / B / C (see `spec/asset-pipeline.md`).
- [ ] User decides whether the source painterly portrait gets persisted at `assets/source-portrait.png` (relevant only for Options B and C).
- [ ] User confirms Xcode + Swift toolchain version (Xcode 15.2+, Swift 5.9+, target macOS 14.0).
- [ ] Add to `.gitignore`: `*.xcuserstate`, `DerivedData/`, `.DS_Store`, `*.p12`, `*.pem`, notarization tokens.
- [ ] Add `LICENSE` (Apache-2.0) at repo root, with NOTICE for Gemma weights TOU acknowledgement.

**Exit criterion:** Pre-flight checklist passed; we know what to build.

---

## Phase 1 — Xcode project init + skeleton (1 day)

Goal: app launches, fullscreen, displays a placeholder bust, exits on Esc.

### Directory structure (CORRECTED 2026-05-05 — aligns with existing monorepo)

The repo is already laid out as a monorepo per HANDOFF.md §2. The scaffold
fills in the placeholders that already exist:

```
he-was-socrates/                                          # repo root (already exists)
├── apps/                                                 # already exists
│   └── macos/                                            # already exists
│       └── HeWasSocrates/                                # already exists (empty placeholder)
│           ├── HeWasSocrates.xcodeproj/                  # NEW — Xcode project
│           ├── HeWasSocrates/                            # NEW — Swift app target
│           │   ├── HeWasSocratesApp.swift                # @main, NSApplicationDelegate
│           │   ├── ContentView.swift                     # root view, fullscreen
│           │   ├── Views/
│           │   │   ├── BustView.swift                    # 16-viseme PNG swap @ 30fps
│           │   │   ├── CaptionView.swift                 # word-boundary highlight
│           │   │   ├── ThoughtSilhouetteView.swift       # pulse animation
│           │   │   ├── ModeChipView.swift                # cyan/green + iconography
│           │   │   └── OfflineProofBadge.swift           # M04 — 0 KB sent counter
│           │   ├── Resources/
│           │   │   ├── Assets.xcassets                   # AppIcon, color tokens
│           │   │   ├── HeWasSocrates.entitlements        # per entitlements.plist.md
│           │   │   ├── Info.plist                        # usage descriptions KO+EN
│           │   │   ├── face_halftone.png                 # idle/REST (after Phase 2)
│           │   │   └── visemes/viseme_*.png              # 16 files (after Phase 2)
│           │   └── HeWasSocrates.xcdatamodeld/           # Core Data schema
│           └── HeWasSocratesTests/                       # NEW — UI / integration tests
├── packages/                                             # already exists
│   └── SocraticEngine/                                   # already exists (empty placeholder)
│       ├── Package.swift                                 # NEW — Swift Package manifest
│       ├── Sources/
│       │   └── SocraticEngine/                           # NEW — engine source
│       │       ├── Models/
│       │       │   ├── Wonder.swift                      # Core Data entity (coredata-model.md)
│       │       │   ├── SemanticTag.swift
│       │       │   ├── Session.swift
│       │       │   └── Mode.swift                        # enum
│       │       ├── Audio/
│       │       │   ├── AudioInputManager.swift           # SFSpeechRecognizer wrapper
│       │       │   └── TTSManager.swift                  # AVSpeechSynthesizer wrapper
│       │       ├── Viseme/
│       │       │   ├── VisemeDriver.swift                # phoneme → viseme @ 30fps
│       │       │   └── PhonemeMap.swift                  # loads phoneme-viseme-map.json
│       │       ├── Gemma/
│       │       │   ├── GemmaService.swift                # MLX-Swift bridge
│       │       │   └── FunctionCallOrchestrator.swift    # per function_call_contract.yaml
│       │       ├── Storage/
│       │       │   └── WonderingLog.swift                # Core Data + idempotency (SC5)
│       │       └── Errors/
│       │           └── ErrorCatalog.swift                # NSError domains (error-catalog.md)
│       └── Tests/
│           └── SocraticEngineTests/                      # NEW — unit + property tests
├── assets/                                               # NEW — Phase 0/2
│   ├── README.md                                         # explains pipeline + persistence
│   ├── source-portrait.png                               # NEXT TURN — user uploads
│   ├── face_halftone.png                                 # GENERATED Phase 2
│   ├── visemes/viseme_*.png                              # GENERATED Phase 2 (16 files)
│   └── .build-manifest.json                              # SHA-256 of generated PNGs
├── scripts/                                              # already exists (.gitkeep)
│   ├── halftone.py                                       # NEW Phase 2 — Python halftone
│   ├── viseme_compose.py                                 # NEW Phase 2 — 16-variant composer
│   ├── build-visemes.sh                                  # NEW Phase 2 — wrapper
│   └── img_to_ascii.py                                   # NEW Phase 5 — README/video decoration
├── docs/                                                 # already exists (.gitkeep)
│   ├── architecture.md                                   # NEW Phase 1 — system diagram
│   ├── video-script.md                                   # NEW Phase 5 — 3-min storyboard
│   └── writeup-draft.md                                  # NEW Phase 5 — Kaggle Writeup
├── spec/                                                 # already exists (.gitkeep)
│   └── (placeholder, real SpecDD is in runs/2026-05-05-spec/spec/)
├── runs/2026-05-05-spec/                                 # frozen SpecDD — DO NOT EDIT
│   ├── (17 locked artifacts, SHA e5dfadf2…314c5)
│   ├── assets/SOURCE.md                                  # visual brief
│   └── spec/                                             # 17 locked spec files
├── memory/                                               # PF memory — already exists
│   ├── CLAUDE.md
│   ├── LESSONS.md
│   └── PROGRESS.md
├── HANDOFF.md                                            # already exists
├── README.md                                             # already exists, will expand Phase 1
├── LICENSE                                               # already exists (Apache-2.0 + CC-BY-4.0)
├── NOTICE                                                # NEW Phase 0 — Gemma TOU acknowledgement
├── Makefile                                              # NEW Phase 1 — make assets, make build
└── .gitignore                                            # already exists
```

**Key adjustment vs my earlier draft:** the engine layer (Audio, Viseme,
Gemma, Storage, Errors) lives in **`packages/SocraticEngine`** as a Swift
Package — separable, testable in isolation, swappable for iPad later. The
app target (`apps/macos/HeWasSocrates`) only owns Views + AppDelegate +
Resources, and depends on the SocraticEngine package via Swift Package
Manager. This matches the existing repo layout intent per HANDOFF.md §2.

### Phase-1 deliverables

- Xcode project compiles, launches, takes fullscreen via `NSWindow.toggleFullScreen`.
- `presentationOptions = [.autoHideMenuBar, .autoHideDock]`.
- Black background (`background_ink_black` token from `design-approved.json`).
- Placeholder bust (single-color filled circle, awaiting real PNGs in Phase 2).
- Esc key exits fullscreen → quits app.
- VoiceOver: window has descriptive title, escape gesture works.

### Phase-1 acceptance test

```bash
xcodebuild -project HeWasSocrates.xcodeproj -scheme HeWasSocrates build
```

→ exit 0, app launches via `open ./build/Debug/HeWasSocrates.app`, fullscreen visible.

---

## Phase 2 — Asset authoring (1-2 days, depends on Option A/B/C)

### Option A path (hand-authored)

- Designer/dev opens source portrait in Procreate/PS.
- Authors 16 mouth-shape variants by hand, exports to `Resources/visemes/viseme_*.png`.
- Authors `face_halftone.png` (REST) at same canvas size.
- Each PNG: ≤ 200 KB, alpha bg, ink-black + alabaster palette per design tokens.

### Option B path (halftone-derived) — RECOMMENDED FOR TIMELINE

- `src/halftone.py` (Python 3.11+, ~50 LOC):
  - Reads `assets/source-portrait.png`.
  - Converts to 1-bit halftone via PIL + numpy (`dot_size`, `threshold` params).
  - Outputs `Resources/face_halftone.png` (REST viseme).
- `src/viseme_compose.py` (~80 LOC):
  - Reads REST PNG + 16 mouth-shape masks (PNG alpha layers, hand-authored or procedural).
  - Composes 16 viseme PNGs via PIL alpha-composite.
  - Outputs `Resources/visemes/viseme_*.png`.
- `scripts/build-visemes.sh`:
  - Runs halftone.py + viseme_compose.py.
  - Records SHA-256 of each output to `assets/.build-manifest.json`.
- `Makefile`: `make assets` regenerates; `make assets-verify` checks manifest unchanged.

### Option C path (Metal shader morph)

- Hand-authored single REST PNG.
- `Resources/Shaders/MouthMorph.metal`: vertex+fragment shaders applying parametric mouth deformation.
- `Services/VisemeShaderRenderer.swift`: Metal pipeline driving 16 viseme parameter sets.
- Trade-off: GPU contention with MLX inference (SC6 risk) — verify on M2 Pro before committing.

### Phase-2 deliverables (regardless of option)

- 17 PNG files in `Resources/` totaling < 5 MB (1-bit PNGs ≈ 50-200 KB each).
- `Resources/visemes/.viseme-manifest.json` — list of 16 viseme IDs + SHA-256 of each PNG, used by runtime for integrity verification.

### Phase-2 acceptance test

- All 17 PNGs present.
- Each PNG decodes to expected canvas dimensions.
- Per-PNG SHA-256 matches manifest.
- Visual smoke test: open `face_halftone.png` in Preview — looks like Socrates per attached portrait.

---

## Phase 3 — Skeletal app loop (2 days)

Goal: STT → fake Gemma response → TTS + viseme animation, running on canned input.

### Components implemented in this phase

- `AudioInputManager.swift`:
  - `SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))` (or "en-US" per user setting).
  - Push-to-talk via `Spacebar` press-and-hold (resolves SC6-08 STT debounce concern).
  - VAD fallback: 1.5s silence ends utterance.
  - On error: route through ErrorCatalog (per `error-catalog.md`).
- `TTSManager.swift`:
  - `AVSpeechSynthesizer` with delegate.
  - `AVSpeechSynthesizerDelegate.speechSynthesizer(_:willSpeakRangeOfSpeechString:utterance:)` for phoneme stream.
  - Voice selection: Yuna/Heami for ko-KR, Samantha for en-US, fallback chain (per `phoneme-viseme-map.json`).
- `VisemeDriver.swift`:
  - Subscribes to TTSManager phoneme stream.
  - Maps phoneme → viseme ID via `phoneme-viseme-map.json`.
  - Drives BustView at 30fps (12fps under Reduce Motion).
  - Re-anchor every word boundary to bound drift.
- `BustView.swift`:
  - SwiftUI `Image` with viseme ID binding.
  - Animation: `.animation(nil)` for hard swap (per `viseme_crossfade_ms: 0`).
- `GemmaService.swift` STUB:
  - Returns canned `ask_back` response: `"그건 왜 궁금한가?"` for any input.
  - Real MLX-Swift integration deferred to Phase 4.

### Phase-3 deliverables

- Press space, say something in Korean → bust speaks back canned question with synced lip movement.
- VoiceOver compatibility verified (TTS doesn't fight VoiceOver — ducking implemented).
- Reduce Motion verified: 12fps fallback runs.

### Phase-3 acceptance test

- Manual: speak "안녕" → bust says "그건 왜 궁금한가?" with viseme animation.
- Drift measurement: record audio + screen, measure peak-to-peak < 50ms RMS drift.

---

## Phase 4 — Real Gemma integration (3-4 days)

Goal: replace canned response with real Gemma E4B Q4 inference, function-calling enabled, wondering log persists.

### Components implemented

- `GemmaService.swift`:
  - Bundle Gemma E4B Q4 weights at `Resources/gemma-4-e4b-it-4bit.mlx` (~3.97 GB).
  - SHA-256 verification on first launch (per `model-integrity.md`).
  - MLX-Swift loader with model preload at app launch (5s splash).
  - System prompt locked at compile time (resolves SC7-007 prompt-injection durability — system prompt immutable from runtime input).
- `FunctionCallOrchestrator.swift`:
  - Implements 4 function calls per `function_call_contract.yaml`.
  - Order: `mode_classify` → (optional) `surface_past_wonder` → `ask_back` OR `defer_to_human`.
  - Correlation-id per turn for idempotency (resolves SC5-03).
  - Streaming TTS+viseme start mid-generation when first 3 tokens arrive (resolves SC2-002 streaming contract).
- `WonderingLog.swift`:
  - Core Data `NSPersistentContainer` with FileProtection complete.
  - Wonder ID = SHA-256 of (utterance + timestamp-day + sessionID), 32-char prefix (resolves SC5-01 dedup).
  - Background context for writes, main context for reads.
  - Schema version field on `Wonder` and `Session` (resolves SC5-04).
  - JSON export with deterministic ordering (resolves SC5-08).

### Phase-4 deliverables

- Real Gemma response replaces canned stub.
- Wondering log persists across app launches.
- 14-month replay scene works: load fixture log from 14 months ago → ice wonder surfaces correctly.

### Phase-4 acceptance test

- 50-sample test set: KO+EN mixed utterances, mode_classify accuracy ≥ 80%.
- TTFT measurement on M2 Pro: ≤ 8s P95 (per `performance-test-suite.md`).
- 12-utterance prompt-injection test: 100% routed to `defer_to_human` for legal/medical/financial.

---

## Phase 5 — Polish + demo-day (3-4 days)

Goal: ship-ready DMG, video shot, Writeup written.

- `OfflineProofBadge.swift`: real-time `nettop`-equivalent counter showing 0 bytes egress.
- VoiceOver / Reduce Motion / Increase Contrast / Larger Text: verify all 4 paths.
- COPPA child-mode flow: verifiable parental consent screen with localized copy (KO+EN).
- DMG notarization: `notarytool submit` with App-Specific-Password.
- Demo video: shot on M2 Pro per `demo-day-reliability.md`, 3 minutes, includes 2 personas + 14-month replay.
- README: hero block (optional ASCII art if Option B's `img_to_ascii.py` is built), build instructions, license.
- Writeup: ≤1500 words, framed per (e) M12 override (research/educational artifact, OSS).
- Kaggle submission: DMG link + Writeup + YouTube unlisted/public.

### Phase-5 acceptance test

- Demo-day reliability checklist 100% pass on M2 Pro.
- DMG notarized + Gatekeeper passes.
- Video < 3:00, includes airplane-mode toggle (M04).
- Writeup acknowledges no-named-partner positioning explicitly.

---

## Risk register (top 5 across all phases)

| ID | Risk | Phase | Mitigation |
|---|---|---|---|
| R1 | Korean STT model not pre-installed on demo Mac | 0/5 | Pre-install + test 1 week before demo, add detection at first launch |
| R2 | Gemma E4B Q4 TTFT misses 8s budget on M2 Pro | 4 | Profile early in Phase 4; if missed, reduce context window from 32K to 16K |
| R3 | Asset authoring (Option A) takes longer than 2 days | 2 | Pre-commit to Option B if A artist not lined up by Phase 0 |
| R4 | Notarization fails on first attempt | 5 | Test notarization workflow on Day 7, not Day 13 |
| R5 | Wondering log replay produces non-deterministic output | 4 | Lock Gemma temperature=0, log seed + model SHA per Wonder |

---

## Out of scope for this plan (deferred to v1.1 or post-hackathon)

- iPad / iOS builds.
- Image/video input.
- Voice cloning of any kind.
- Cloud sync of wondering log.
- Multi-user support.
- Wondering log review UI (read/search/edit existing entries).
- App Store submission (post-hackathon, Phase 5+).
- Sustainability partner outreach (overridden by user).

---

## Approval requested

Before I start Phase 0, please confirm:

1. **Approve overall plan structure** (5 phases, 13-day timeline)?
2. **Pick asset-authoring option** A (hand) / B (halftone) / C (shader)?
3. **Persist source portrait file** at `assets/source-portrait.png` (Y/N — needed for B and C)?
4. **Any phase swap, scope cut, or addition** before kickoff?

I'll wait for your answers via AskUserQuestion before writing any Swift / Python / config code.
