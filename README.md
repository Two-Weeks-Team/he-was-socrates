# He Was Socrates

[![CI](https://github.com/Two-Weeks-Team/he-was-socrates/actions/workflows/ci.yml/badge.svg)](https://github.com/Two-Weeks-Team/he-was-socrates/actions/workflows/ci.yml)
[![Tests](https://img.shields.io/badge/tests-41%20passing-brightgreen)](https://github.com/Two-Weeks-Team/he-was-socrates/actions)
[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1%2B-orange?logo=swift&logoColor=white)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue?logo=apple&logoColor=white)](https://www.apple.com/macos)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-required-lightgrey?logo=apple&logoColor=white)](https://www.apple.com/mac)
[![License: Apache 2.0](https://img.shields.io/badge/License%20(code)-Apache_2.0-green.svg)](LICENSE)
[![License: CC BY 4.0](https://img.shields.io/badge/License%20(content)-CC_BY_4.0-lightgrey.svg)](LICENSE)
[![MLX-Swift 0.31.3](https://img.shields.io/badge/MLX--Swift-0.31.3-purple)](https://github.com/ml-explore/mlx-swift)
[![mlx-swift-lm 3.31.3](https://img.shields.io/badge/mlx--swift--lm-3.31.3-purple)](https://github.com/ml-explore/mlx-swift-lm)
[![Gemma 4](https://img.shields.io/badge/Gemma-4_E4B_4bit-red)](https://huggingface.co/mlx-community/gemma-4-e4b-it-4bit)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Code of Conduct](https://img.shields.io/badge/Code%20of%20Conduct-2.1-blue.svg)](CODE_OF_CONDUCT.md)

> *macOS 풀스크린 위에 살아 돌아온 산파술. 듣고, 생각하고, 답하지 않는다 — 단 묻는다.*
>
> A macOS native fullscreen Socratic bust. Listens. Thinks. Refuses to answer.
> Asks back. **That refusal is the entire product.**

Submission for **The Gemma 4 Good Hackathon** (Kaggle / Google DeepMind, deadline 2026-05-19 08:59 KST). Track: **Main + Impact: Future of Education** (no Special Tech bonus).

---

## At a glance

| 발화 (User says) | 응답 (Bust asks back) |
|---|---|
| "왜 어떤 노래는 들으면 우는지?" | "그 노래를 처음 들은 건 누구와 함께였나?" |
| "얼음이 왜 미끄럽지?" | "미끄러운 건 얼음 때문일까, 네 손가락이 밀어낸 무엇 때문일까?" |
| "지구는 왜 둥글까?" | "네가 만져본 가장 큰 둥근 것은? 그것이 둥근 이유가 같을까?" |
| "변호사 좀 추천해줘" | _(refuses)_ "이 질문은 전문가의 도움이 필요하다. 자네에게 더 적합한 사람을 찾아보라." |

The bust speaks in **단정한 평어체** — neither polite-form nor friendly. He runs the **산파술 + 엘렝코스** dialectic. When you ask for legal/medical/financial/welfare/insurance/emergency advice, he refuses with a one-line acknowledgment and points you to a real expert. **That refusal IS the product mechanic.**

---

## What this is

A macOS app that:

1. **Listens** via `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` — *zero bytes leave the device, ever.*
2. **Thinks** via on-device **Gemma 4 E4B 4-bit** (~3.97 GB) running on Apple Silicon Metal through `MLX-Swift 0.31.3` and `mlx-swift-lm 3.31.3`.
3. **Asks back** via `AVSpeechSynthesizer` (Yuna for Korean, Samantha for English) with a **16-viseme halftone bust** swapped at 30 fps.
4. **Remembers** user wonderings in a Core Data wondering log — on-device, dedup-by-fingerprint, deterministic JSON export, no iCloud sync.

Three Gemma 4 features are **load-bearing** — pull any one out and the product collapses:

- 🧠 **Configurable thinking mode** — visible to the user as a soft pulse on the bust
- 📚 **Long context (256K)** — used as compressed multi-year recall over the wondering log
- 🔧 **Native function calling** — `mode_classify` · `surface_past_wonder` · `ask_back` · `defer_to_human` (the abstention mechanic)

---

## Quick start

**Prerequisite:** Apple Silicon Mac with macOS 14+ and **full Xcode 15.2+** installed.

```bash
# Clone
git clone https://github.com/Two-Weeks-Team/he-was-socrates.git
cd he-was-socrates

# Install build tooling (xcodegen)
brew bundle

# Sanity check the environment
make doctor

# Build assets (regenerates 17 PNGs from source-portrait.png)
make assets

# Build engine + run all tests (~1.5 s on M2 Pro)
make engine-test          # 41 swift-testing scenarios

# Generate Xcode project + build the .app
make xcodeproj
make app

# Launch
open apps/macos/HeWasSocrates/build/Debug/HeWasSocrates.app
```

First launch downloads Gemma 4 E4B 4-bit weights (~3.97 GB) into `~/Library/Caches/com.apple.MLX/`. Subsequent launches are warm.

Detailed setup including Stage-5 day-1 tasks: see **[SETUP.md](SETUP.md)**.

---

## Architecture

```
[macOS 14+ user]
   │  push-to-talk (Space)
   ▼
SFSpeechRecognizer (ko-KR | en-US)         ◀── requiresOnDeviceRecognition = true
   │
   ▼
FunctionCallOrchestrator
   │  → mode_classify (Gemma 4 E4B function-call)
   │  → surface_past_wonder (optional, when log non-empty)
   │  → ask_back   OR   defer_to_human
   ▼
GemmaService (MLX-Swift 0.31.3, gemma-4-e4b-it-4bit)
   │  thinking-mode tokens streamed
   ▼
AVSpeechSynthesizer (Yuna ko / Samantha en)
   │  → AVSpeechSynthesisMarker.phoneme stream OR JamoTimeline 15:70:15 fallback
   ▼
VisemeDriver (30 fps frame swap, 16 visemes, 1-bit halftone)
   │
   ▼
SwiftUI fullscreen bust (alabaster on ink-black)
```

### Engine layer (`packages/SocraticEngine`)

A Swift Package buildable with **CommandLineTools alone** (no Xcode required for engine-only work):

| Component | Role |
|---|---|
| `AudioInputManager` | `SFSpeechRecognizer` + `AVAudioEngine` push-to-talk |
| `TTSManager` | `AVSpeechSynthesizer` voice resolution chain (premium → enhanced → default), `onPhonemeStreamUnavailable` fallback hook |
| `VisemeDriver` | Timer-driven 30 fps tick, ≥2 frame hold, audio-clock-synced schedule, drift alert > 50 ms, Reduce Motion 30→12 fps |
| `JamoTimeline` | Korean syllable decomposition + 15:70:15 initial:medial:final allocation (per [iter-4 §S1](runs/2026-05-05-spec/spec/SPEC.md.iter4-api-correction.md)) |
| `GemmaService` | `.stub` mode (canned Korean Socratic JSON) and `.real` mode (`LLMRegistry.gemma4_e4b_it_4bit` via `LLMModelFactory`) |
| `FunctionCallOrchestrator` | system prompt → Gemma → parser → `TurnOutput` |
| `WonderingLog` | SC5 dedup (SHA-256 content fingerprint), deterministic JSON export |
| `SystemPrompt` | verbatim user-authored Korean Socratic prompt + JSON dispatch protocol |
| `EngineCoordinator` | composes the six subsystems into a hands-free turn loop with explicit `Phase` enum |

### macOS app layer (`apps/macos/HeWasSocrates`)

- `HeWasSocratesApp.swift` — SwiftUI `@main` + `NSWindow.toggleFullScreen` + auto-hide menu bar/Dock
- `ContentView.swift` — fullscreen ink-black bust, key handler for Spacebar (push-to-talk) + Esc (exit)
- `Resources/Info.plist` — Korean + English usage descriptions, ATS deny-all
- `Resources/HeWasSocrates.entitlements` — App Sandbox, **NO `network.client`** (NO-CLOUD invariant), audio-input only
- `project.yml` — xcodegen config (run `make xcodeproj` to materialize `.xcodeproj`)

### Asset pipeline (`scripts/`)

Build-time Python toolchain (NOT shipped in DMG):

| Script | Purpose |
|---|---|
| `halftone.py` | RGBA portrait → 1-bit halftone PNG with alabaster dots on transparent |
| `viseme_compose.py` | 16 viseme variants via alpha-erase mode + Gaussian feather |
| `build_manifest.py` | SHA-256 manifest for CI determinism check |
| `preview-server.py` | Local editor at [`localhost:8765`](http://localhost:8765/preview/index.html) with sliders for `mouth_xy`, `scale`, `dot_size`, `gamma`, `mode`, `feather` |

---

## Status

| Phase | Status | Highlights |
|---|---|---|
| **0** Pre-flight | ✅ | LICENSE, NOTICE, .gitignore, scaffold-plan |
| **1** Skeleton | ✅ | Swift Package + Xcode app structure (xcodegen-driven) |
| **2** Asset pipeline | ✅ | 17 1-bit halftone PNGs, deterministic build, live editor |
| **3** Engine real impls | ✅ | Audio/TTS/VisemeDriver/JamoTimeline/Orchestrator |
| **4** MLX-Swift + Gemma 4 | ✅ architecture | `LLMRegistry.gemma4_e4b_it_4bit` wired; first-launch HF download |
| **5** Demo materials | 🟡 partial | video script + writeup draft written; video shoot pending |
| **Day-1** AVSpeech ko-KR phoneme probe | ⏳ ready | `tools/ApplePhonemeProbe` ready to run |

Frozen SpecDD lock: `e5dfadf2c8…314c5` (preserved unchanged). Iter-2 amendment + iter-4 API correction live as delta documents alongside the lock.

---

## Project layout

```
he-was-socrates/
├── apps/macos/HeWasSocrates/         # macOS app target (xcodegen → .xcodeproj)
├── packages/SocraticEngine/          # Swift Package (engine layer)
├── tools/ApplePhonemeProbe/          # Stage-5 day-1 probe
├── assets/                           # source portrait + 17 generated PNGs + manifest
├── scripts/                          # build-time Python toolchain (NOT shipped)
├── docs/                             # video script, writeup draft, etc.
├── runs/2026-05-05-spec/             # locked SpecDD artifacts (DO NOT EDIT)
├── memory/                           # PreviewForge cross-cycle memory
├── .github/                          # CI workflows + issue/PR templates
├── README.md  SETUP.md  CONTRIBUTING.md  CODE_OF_CONDUCT.md  SECURITY.md
├── CHANGELOG.md  LICENSE  NOTICE  Brewfile
├── HANDOFF.md                        # gallery → repo handoff record
├── Makefile                          # `make doctor / assets / engine-test / app`
└── .gitignore
```

---

## Hackathon facts

| | |
|---|---|
| Sponsor | Google LLC (Google DeepMind) via Kaggle |
| Prize | $200K (Main 100K · Impact 5×10K · Special Tech 5×10K) |
| Submission | Writeup ≤1500 w + YouTube ≤3 min + public repo + live demo + media |
| Rubric | Impact 40 / Story 30 / Tech 30 |
| Deadline | 2026-05-19 08:59 KST |
| Winner license | CC-BY 4.0 |

Track selection: **Main + Impact: Future of Education** (Special Tech bonus declined).

---

## License

Dual-licensed:

- **Code** (`apps/`, `packages/`, `scripts/`, `tools/`, root `*.swift`/`*.py`/`*.sh`) — [Apache License 2.0](LICENSE)
- **Documentation, specifications, media** (`docs/`, `runs/`, `memory/`, `*.md`, `assets/source-portrait.png` and derivatives) — [Creative Commons CC-BY-4.0](LICENSE)

Bundled Gemma 4 weights are subject to [Google's Gemma Terms of Use](https://ai.google.dev/gemma/terms). See [NOTICE](NOTICE) for full third-party attributions including [MLX-Swift](https://github.com/ml-explore/mlx-swift) (MIT), [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) (MIT), [Rhubarb Lip Sync](https://github.com/DanielSWolf/rhubarb-lip-sync) (MIT, build-time only), [g2pK](https://github.com/Kyubyong/g2pK) (Apache-2.0, build-time only).

---

## Contributing

This is a hackathon submission, but contributions toward post-submission iteration are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Security disclosures: see [SECURITY.md](SECURITY.md).

---

## Acknowledgments

- The Korean Socratic system prompt is verbatim authored by the maker (Two-Weeks-Team), 2026-05-05 KST. Embedded at compile time, immutable from runtime input.
- The painterly Socrates portrait is AI-generated by the maker.
- Built on Gemma 4 (Apache-2.0 weights via [`mlx-community/gemma-4-e4b-it-4bit`](https://huggingface.co/mlx-community/gemma-4-e4b-it-4bit)), MLX-Swift, Apple Speech framework, AVSpeechSynthesizer.
- Halftone aesthetic inspired by Lucas Pope's *Return of the Obra Dinn* and *World of Horror* talking-head precedents.
- Ideation traceable to the `Two-Weeks-Team` 26-advocate Preview Forge gallery (2026-05-04) with 4-Panel evaluation (Tech / UX / Risk / Business — 40 simulated experts) + 12 Mitigation rules adopted in full. Audit trail preserved in `runs/2026-05-05-spec/`.

---

*소크라테스는 답하지 않는다. 묻는다.*
