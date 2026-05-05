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

**Prerequisite:** Apple Silicon Mac with macOS 14+, full Xcode 16+ (Xcode 26 ships Swift 6.1+ and the Metal Toolchain auto-installs on first build), and Homebrew.

The project ships two parallel quick-start tracks: a manual one for humans and a strictly-scripted one for LLMs / CI. Both end at the same green build, the same `.app` bundle, and the same first-launch flow.

### For Human (interactive)

```bash
# 1) Clone
git clone https://github.com/Two-Weeks-Team/he-was-socrates.git
cd he-was-socrates

# 2) Install brew-managed CLI deps (xcodegen, swift-format, gitleaks)
brew bundle

# 3) Sanity-check the toolchain — green checks for swift / xcodebuild /
#    xcodegen / python3, optional gitleaks + swift-format.
make doctor

# 4) (Optional) Pin your Apple Developer Team ID so signing isn't ad-hoc.
#    Without this, the build still succeeds with ad-hoc signing for Debug.
cp apps/macos/HeWasSocrates/Local.xcconfig.example \
   apps/macos/HeWasSocrates/Local.xcconfig
$EDITOR apps/macos/HeWasSocrates/Local.xcconfig    # set DEVELOPMENT_TEAM = …

# 5) Single-command bootstrap. This is `assets → xcodeproj → app →
#    install-gemma-weights`. The last step pre-fetches the ~3.97 GB
#    Gemma 4 E4B 4-bit model into the sandboxed app's HuggingFace cache
#    via Python's huggingface_hub. The app itself ships with NO network
#    entitlements (NO-CLOUD invariant), so the model MUST be staged from
#    outside the sandbox here — the runtime only ever READS the cache.
#    Auto-downloads the Metal Toolchain (~688 MB) on first call too.
make bootstrap

# 6) Launch the app.
make run
```

What you do at first launch (the parts only a human can do):

1. Approve **Microphone** + **Speech Recognition** TCC dialogs.
2. **Hold Spacebar** to talk; release to let the bust think and ask back. **Esc** quits.

Note: if the bust shows `⚠ gemma load: Failed to load Gemma 4 model.`, the offline cache wasn't staged — re-run `make install-gemma-weights` and relaunch.

Try: "왜 어떤 노래는 들으면 우는지?" → 산파술 질문이 돌아옵니다. "변호사 좀 추천해줘" → `defer_to_human` 거절 (이 거절이 곧 제품 메커닉입니다).

### For LLM / CI (non-interactive)

The same flow, but every step exits with a non-zero status on failure and emits machine-readable progress. Use this on CI runners, in `claude-code` agentic loops, or for unattended verification on a fresh worker.

```bash
# 1) Clone + enter (no auth needed for the public repo)
git clone --depth=1 https://github.com/Two-Weeks-Team/he-was-socrates.git
cd he-was-socrates

# 2) Install brew deps non-interactively. Brewfile pins xcodegen, swift-format, gitleaks.
brew bundle --no-lock

# 3) Toolchain audit — exits 1 if Swift / xcodebuild / xcodegen / python3 missing.
make doctor

# 4) Engine-only verification path (no Xcode required, ~1.5 s on M2 Pro).
make engine-test          # 41 swift-testing scenarios

# 5) CI parity gate — same checks GitHub Actions runs (assets-verify + tests + lint).
make ci-local

# 6) Full app build + offline model stage. `make bootstrap` runs:
#      assets → xcodeproj → app → install-gemma-weights.
#    Metal Toolchain auto-downloads via `xcodebuild -downloadComponent` on
#    first call (no Apple ID required). install-gemma-weights provisions a
#    Python venv and uses huggingface_hub to stage ~3.97 GB into the
#    sandbox container so the NO-CLOUD app can read it offline.
#    Skip the model fetch in CI by overriding the bootstrap chain:
make assets xcodeproj app           # build-only path, no model fetch

# 7) Headless launch with stub Gemma (no MLX fetch, no model load).
#    The .app still exercises every wiring path: SFSpeechRecognizer →
#    FunctionCallOrchestrator(.stub) → AVSpeechSynthesizer → VisemeDriver.
HEWASSOCRATES_GEMMA_MODE=stub make run

# 8) Verify the artefact you just built.
APP="$(xcodebuild -project apps/macos/HeWasSocrates/HeWasSocrates.xcodeproj \
                  -scheme HeWasSocrates -configuration Debug \
                  -showBuildSettings 2>/dev/null \
      | awk -F' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR =/ {print $2; exit}')/HeWasSocrates.app"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements :- "$APP" \
  | grep -E '(network\.client|network\.server|disable-library-validation|allow-unsigned-executable-memory|device\.camera)' \
  && { echo "FAIL: prohibited entitlement leaked" >&2; exit 1; } \
  || echo "PASS: NO-CLOUD entitlement gate"
test -f "$APP/Contents/Resources/face_halftone.png"
test "$(ls "$APP/Contents/Resources/visemes" | wc -l | xargs)" = "16"
```

Things an LLM **cannot** automate — the bust requires a human at first launch:

- TCC permission dialogs (Microphone, Speech Recognition) — system-modal, no programmatic grant on production macOS.
- The 3.97 GB Gemma weight stage (`make install-gemma-weights`) finishes unattended, but in CI you'll usually want to skip it. Run the build path `make assets xcodeproj app` instead of the full `make bootstrap`, and launch with `HEWASSOCRATES_GEMMA_MODE=stub`.
- Voice input via Spacebar push-to-talk — there's no headless voice fixture; if you need a deterministic conversation trace, drive the engine layer directly via `swift test` (the `FunctionCallOrchestrator end-to-end (stub Gemma)` suite covers it).

Detailed setup including Stage-5 day-1 tasks: see **[SETUP.md](SETUP.md)**. Architecture and invariants for AI assistants: **[CLAUDE.md](CLAUDE.md)**.

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
