# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Read these first

- **[memory/CLAUDE.md](memory/CLAUDE.md)** — project-scoped operating rules with a higher priority than the user-global `~/.claude/CLAUDE.md`. Lists the **absolute invariants** below and the SpecDD lock items that must not be re-litigated.
- **[runs/2026-05-05-spec/spec/SPEC.md](runs/2026-05-05-spec/spec/SPEC.md)** plus its delta documents (`SPEC.md.iter2-amendment.md`, `SPEC.md.iter4-api-correction.md`) — the frozen contract. Lock SHA `e5dfadf2c8…314c5` is preserved by **never editing files inside `runs/2026-05-05-spec/spec/`**. Spec changes go through new `iter<N>-<topic>.md` delta documents at the same path.
- **[HANDOFF.md](HANDOFF.md)** §1.3 — Mitigation 12 rules adopted in full from the gallery decision.

## Absolute invariants (DO NOT violate without explicit user approval)

1. **Zero bytes leave the device.** No `network.client` or `network.server` entitlement. No `URLSession`/`Network.framework` calls to external hosts. STT runs with `requiresOnDeviceRecognition = true`. The HuggingFace weight download is the **only** sanctioned network egress and happens via the system MLX cache on first launch.
2. **The abstention mechanic is the product.** `defer_to_human` for legal/medical/financial/welfare/insurance/emergency advice is load-bearing. Do not "improve" the bust into an answering machine.
3. **Korean tone is locked to 단정한 평어체** — neither 존댓말 nor friendly. The Korean Socratic system prompt in `Sources/SocraticEngine/Gemma/SystemPrompt.swift` is verbatim user-authored and embedded at compile time.
4. **No photoreal lip-sync.** The 1-bit halftone PNG swap is the aesthetic — SadTalker / Audio2Face / etc. are out of scope.
5. **`runs/2026-05-05-spec/` is read-only** except for new delta documents. The lock SHA must never be recomputed casually.
6. **`.env` is not modified without explicit user instruction.**

## Common commands

All build, test, and lint flows go through the Makefile. `make help` lists targets. The CI workflow at `.github/workflows/ci.yml` runs the same gates — `make ci-local` reproduces it.

```bash
# Toolchain audit (Swift / Xcode / xcodegen / python3 / swift-format / gitleaks)
make doctor

# Asset pipeline (Python, deterministic — regenerates 17 PNGs from source-portrait.png)
make assets           # ~10s, creates .venv-build, runs halftone + viseme-compose
make assets-verify    # rebuild and fail if the manifest drifts (CI determinism gate)
make preview-server   # http://localhost:8765/preview/index.html — sliders for halftone params

# Engine layer (Swift Package, builds with CommandLineTools alone — no Xcode required)
make engine           # swift build packages/SocraticEngine
make engine-test      # swift test — 41 swift-testing scenarios, ~1.5s on M2 Pro

# Run a single engine test (swift-testing predicate filter)
cd packages/SocraticEngine && swift test --filter <TestName-or-Suite>

# macOS app (full Xcode 15.2+ + xcodegen required)
make xcodeproj        # regenerate apps/macos/HeWasSocrates/HeWasSocrates.xcodeproj from project.yml
make app              # xcodebuild -scheme HeWasSocrates build (Debug)

# Local CI parity (runs assets-verify + engine-test + swift-format lint, in CI order)
make ci-local

# Stage-5 day-1 phoneme probe (informational, exits 0)
make probe-phonemes   # runs tools/ApplePhonemeProbe, writes apple-phoneme-availability.json

# Secret scan (gitleaks, uses .gitleaks.toml at repo root)
make secret-scan
```

After editing `apps/macos/HeWasSocrates/project.yml`, **always re-run `make xcodeproj`** — the `.xcodeproj` is generated, not committed in detail.

## High-level architecture

Three layers, pinned by language and tooling:

```
apps/macos/HeWasSocrates/   ← SwiftUI app target (xcodegen-driven .xcodeproj)
packages/SocraticEngine/    ← Swift Package: the entire turn loop
tools/ApplePhonemeProbe/    ← standalone executable Swift Package, day-1 verification
scripts/                    ← build-time Python (Pillow/numpy via .venv-build) — NOT shipped
assets/                     ← source-portrait.png + 17 generated PNGs + .build-manifest.json
runs/2026-05-05-spec/       ← frozen SpecDD artifacts (lock SHA preserved)
```

### The turn loop (engine layer)

`EngineCoordinator` (`packages/SocraticEngine/Sources/SocraticEngine/EngineCoordinator.swift`) is the only thing the app instantiates. It composes six subsystems and exposes a `Phase` enum (`bootstrapping → idle → listening → thinking → surfacing → speaking → failed`) for UI binding:

```
Spacebar press
  → AudioInputManager (SFSpeechRecognizer on-device + AVAudioEngine push-to-talk)
  → FunctionCallOrchestrator
       → mode_classify        (Gemma 4 E4B function-call)
       → surface_past_wonder  (optional, when WonderingLog non-empty)
       → ask_back  OR  defer_to_human
  → GemmaService (.stub for tests; .real wires LLMRegistry.gemma4_e4b_it_4bit via mlx-swift-lm)
  → TTSManager (AVSpeechSynthesizer; Yuna ko / Samantha en, premium → enhanced → default chain)
  → VisemeDriver (30 fps tick, ≥2-frame hold, audio-clock synced; >50ms drift → alert; Reduce Motion drops to 12fps)
       ├── primary: AVSpeechSynthesisMarker.phoneme stream (if Apple emits markers for the voice)
       └── fallback: JamoTimeline (Korean syllable decomposition, 15:70:15 initial:medial:final allocation)
  → WonderingLog (Core Data, SHA-256 content-fingerprint dedup, deterministic JSON export)
```

The **stub vs real** split for `GemmaService` matters: tests run in `.stub` mode (canned Korean Socratic JSON, no model download). The app uses `.real`. Never wire tests to `.real` — first launch downloads ~3.97 GB.

### Three Gemma 4 features are load-bearing (Mitigation M01)

Pulling any of these out collapses the product:
- **Configurable thinking mode** — visualized as a soft pulse on the bust during `Phase.thinking`.
- **Long context (256K)** — used as compressed multi-year recall over the wondering log via `surface_past_wonder`.
- **Native function calling** — the four-function dispatch (`mode_classify` · `surface_past_wonder` · `ask_back` · `defer_to_human`) is how the abstention mechanic and tone-locking are enforced. The contract lives at `runs/2026-05-05-spec/spec/function_call_contract.yaml`.

### Stable public API surface

These types are part of the published surface and must not change shape without a delta document under `runs/2026-05-05-spec/spec/`:

- `Mode` (`Sources/SocraticEngine/Models/Mode.swift`)
- `VisemeID` (`Sources/SocraticEngine/Viseme/VisemeID.swift`)
- `PhonemeMap.default` (`Sources/SocraticEngine/Viseme/PhonemeMap.swift`)
- `EngineCoordinator.Phase`
- `TurnOutput`

### Asset pipeline (deterministic — CI checks)

Python scripts in `scripts/` build a SHA-256-stable manifest into `assets/.build-manifest.json`. The CI `assets-determinism` job runs `make assets` twice and `diff`s the manifest. Any non-determinism (Pillow version drift, ordering, gamma rounding) fails the gate. The pipeline is build-time only and is **not** shipped in the `.app`.

### macOS app target

- `HeWasSocratesApp.swift` — SwiftUI `@main`, `NSWindow.toggleFullScreen`, auto-hide menu bar/Dock.
- `ContentView.swift` — fullscreen ink-black bust, key handler for Spacebar (push-to-talk) and Esc (exit).
- `Resources/Info.plist` + `Resources/HeWasSocrates.entitlements` — App Sandbox **without** `network.client`. Audio input only. Korean + English usage descriptions.
- Sandboxing has `ENABLE_HARDENED_RUNTIME = YES` and `SWIFT_STRICT_CONCURRENCY = complete` in `project.yml` — `EngineCoordinator` is `@MainActor`.

## Workflow conventions specific to this repo

- **Branches**: `main` is the last green build. Work on `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`, `perf/`, `test/` prefixed branches. Conventional Commits: `type(scope): description` with scopes from {`engine`, `viseme`, `audio`, `gemma`, `app`, `scripts`, `ci`, `docs`, `spec`}.
- **PR merging**: per the user-global rule, use `gh pr merge --merge` to preserve commit history. Squash is forbidden. `--rebase` is allowed only when resolving conflicts.
- **AI-assisted commits** include the `Co-Authored-By:` trailer — see recent `git log` for the exact format.
- **Run `make ci-local` before pushing.** It is the same gate as CI.
- The engine layer builds on **CommandLineTools alone**; the `.app` target requires **full Xcode 15.2+** with `xcode-select --switch /Applications/Xcode.app/Contents/Developer`. CI uses `macos-15` runners with `setup-xcode@latest-stable` for Swift 6.1+.
