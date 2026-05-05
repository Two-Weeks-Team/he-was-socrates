# Changelog

All notable changes to **He Was Socrates** are documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

> ⚠️ **Pre-1.0 status:** breaking changes may occur on any commit until the
> Kaggle hackathon submission (2026-05-19). After submission, normal SemVer
> compatibility guarantees apply.

---

## [Unreleased]

### Added
- _(reserved for in-flight work)_

### Changed
- _(reserved for in-flight work)_

---

## [0.1.0-pre1] — 2026-05-05

The initial scaffold for The Gemma 4 Good Hackathon submission. Six phases of
work landed in two PRs.

### Added

- **Phase 0** (pre-flight) — `LICENSE` (Apache-2.0 + CC-BY-4.0 dual), `NOTICE`
  with full third-party attributions, hardened `.gitignore`,
  `runs/2026-05-05-spec/spec/scaffold-plan-proposal.md`.
- **Phase 1** (skeleton) — `packages/SocraticEngine` Swift Package buildable
  with CommandLineTools alone (no Xcode required for engine work);
  `apps/macos/HeWasSocrates` macOS app target with xcodegen-driven
  `project.yml`, sandbox-locked entitlements (no network), Korean+English
  Info.plist usage description strings.
- **Phase 2** (asset pipeline) — `scripts/halftone.py`,
  `scripts/viseme_compose.py`, `scripts/build-visemes.sh`,
  `scripts/build_manifest.py`, `scripts/preview-server.py`. Generates 17
  1-bit halftone PNGs (1 face + 16 visemes) from the source portrait;
  byte-deterministic, validated by `make assets-verify`. Live editor at
  `http://localhost:8765/preview/index.html` with sliders for mouth_xy,
  scale, dot_size, gamma, mode, feather.
- **Phase 3** (engine real implementations) —
  `AudioInputManager` (`SFSpeechRecognizer` + `AVAudioEngine` push-to-talk),
  `TTSManager` (`AVSpeechSynthesizer` voice resolution chain),
  `VisemeDriver` (Timer-driven 30 fps tick, ≥2 frame hold, audio-clock-synced
  schedule, drift alert > 50 ms),
  `JamoTimeline` (15:70:15 ko-KR initial:medial:final fallback per iter-4 §S1),
  `FunctionCallOrchestrator` end-to-end pipeline.
- **Phase 4** (MLX-Swift + Gemma 4 architecture) —
  Verified mlx-swift 0.31.3 (latest 2026-04-01) and
  mlx-swift-lm 3.31.3 (Apple official, MIT). `LLMRegistry.gemma4_e4b_it_4bit`
  → `mlx-community/gemma-4-e4b-it-4bit`. `GemmaService` runs in `.stub` mode
  (canned Korean Socratic JSON) and `.real` mode (`LLMModelFactory.shared.loadContainer`
  with `#hubDownloader()` + `#huggingFaceTokenizerLoader()`).
- **Phase 5** (demo materials, partial) — `docs/video-script.md`
  (28-beat 3:00 shooting script with M01–M11 mitigation evidence),
  `docs/writeup-draft.md` (1294 words, positioning per (e) M12 user override
  as research/educational artifact).
- **EngineCoordinator** — composes the six subsystems into a hands-free turn
  loop with explicit `Phase` enum (.bootstrapping / .idle / .listening /
  .thinking / .surfacing / .speaking / .failed).
- **System prompt** — verbatim user-authored Korean Socratic prompt
  (산파술 + 엘렝코스 + 9 question types + 단정한 평어체) embedded at compile
  time via `SystemPrompt.composed`. Immutable from runtime input
  (resolves SC7-007).
- **41 swift-testing scenarios** — viseme set integrity, phoneme map
  iter-4 deltas, wondering log SC5 dedup + deterministic JSON export,
  Hangul jamo decomposition, JamoTimeline schedule weighting, VisemeDriver
  scheduling + drift alerting, system prompt Korean invariants,
  `FunctionCallParser` robustness (markdown fence stripping, smart quote
  normalization, trailing-prose tolerance), `GemmaService` stub integration,
  `FunctionCallOrchestrator` end-to-end Korean Socratic + regulated defer,
  `EngineCoordinator` wiring.

### Spec amendments

The frozen SpecDD lock (`SHA-256: e5dfadf2c8…314c5`) is preserved unchanged.
The following amendments live as delta documents alongside the locked
manifest, NOT inside it:

- **iter-2** — 7 spot-fix amendments to `SPEC.md` (resolved during the SpecDD
  evaluator-optimizer loop).
- **iter-4** — `AVSpeechSynthesizer` API correction (the original spec named
  a non-existent "phoneme delegate"; the actual API is
  `AVSpeechSynthesizer.write(_:toBufferCallback:)` + `AVSpeechSynthesisMarker.phoneme`
  on macOS 14+, with `JamoTimeline` 15:70:15 fallback when ko-KR voices emit
  no markers).
- **phoneme-viseme-map.delta.json** — Korean phoneme deltas: ㅓㅕㅝ → UH (was AA),
  ɾ → S (was R), +ㅘ diphthong added.

### User ratifications applied

Recorded in `runs/2026-05-05-spec/spec/user-ratifications.md`:

- **(a)** espeak-ng dropped → AVSpeechSynthesizer phoneme delegate primary
  (later refined to marker-stream API)
- **(b)** M01 256K context literal claim → reframed to "compressed multi-year recall"
- **(c)** Demo machine class = M2 Pro+, fan-cooled, plugged in
- **(d)** Source portrait = AI-generated, hygiene tracking out of scope
- **(e)** M12 sustainability partner = REJECTED ("이건 무시해도 됩니다.
  해커톤의 목적과 정합하지 않습니다."). Repositioned as research/educational
  artifact in writeup.
- **(f)** Image = visual direction only (Hybrid stack interpretation rolled back)
- **(g)** Scaffold plan structure approved (5 phases, 13 days)
- **(h)** Asset path B (halftone-derived) selected
- **(i)** Source portrait persisted at `assets/source-portrait.png`
- **(j)** `VISEME_DIMS` revised — IH 105×26, F/V 80×14, TH 76×26, REST 82×8
  per `viseme-best-practices.md` §7.2
- **(k)** Korean phoneme map delta applied
- **(l)** OSS tools adopted: Rhubarb Lip Sync (MIT) + g2pK (Apache-2.0),
  build-time only, never shipped in DMG
- **(m)** SPEC.md §4.3 API correction via delta document, no SHA recompute

### Repo infrastructure

- Public GitHub repository under the `Two-Weeks-Team` organization
- GitHub Actions CI on `macos-14` (engine build + tests + asset determinism +
  swift-format lint + gitleaks secret scan)
- Dependabot weekly updates for Swift Package + GitHub Actions
- Issue forms (bug report, feature request) in YAML
- Pull request template
- `CODEOWNERS`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`
- `Brewfile` for `xcodegen`, `swift-format`, `gitleaks`
- `tools/ApplePhonemeProbe` — Stage-5 day-1 probe per iter-4 §S3-S4
- `Makefile` targets: `doctor`, `assets`, `assets-clean`, `assets-verify`,
  `engine`, `engine-test`, `xcodeproj`, `app`, `preview-server`,
  `probe-phonemes`, `ci-local`, `secret-scan`

### Deferred to Stage-5 day-1 (post-merge work)

- Gemma 4 E4B 4-bit weights first-launch download (~3.97 GB) integration test
  on a clean Mac
- ko-KR phoneme marker emission probe via `tools/ApplePhonemeProbe`
- `apple_phoneme_to_ipa.json` empirical capture
- `ModelIntegrity.expectedSHA256` canonical hash commitment
- Demo video shoot (per `docs/video-script.md`)
- Kaggle Writeup polish (per `docs/writeup-draft.md`)

### Security

- App Sandbox enabled. `network.client` and `network.server` entitlements
  intentionally absent (NO-CLOUD invariant).
- `SFSpeechRecognitionAudioBufferRequest.requiresOnDeviceRecognition = true`
  enforced in `AudioInputManager`.
- System prompt assembled at compile time only.
- Model integrity verification scaffold present (canonical hash committed
  at Stage-5 day-1).
- ATS deny-all in `Info.plist`.
- See `SECURITY.md` for the full hardening invariants checklist.

### Known limitations

- The bust occasionally produces re-questions that read as too generic.
  Tuning is post-submission work.
- Lip-sync drift on M1 8 GB exceeds the 50 ms RMS spec target. M1 8 GB is
  marked unsupported in `runs/2026-05-05-spec/spec/demo-day-reliability.md`;
  the demo machine is M2 Pro 16 GB minimum.
- ko-KR phoneme marker availability from Apple is empirically unverified
  until Stage-5 day-1 — `JamoTimeline` fallback is exercised by tests but
  the path through real Apple markers is not.
- Auto-classification of child mode runs locally and shows a UI chip, but
  the verifiable-parental-consent flow before persistence is specified, not
  yet implemented.

[Unreleased]: https://github.com/Two-Weeks-Team/he-was-socrates/compare/v0.1.0-pre1...HEAD
[0.1.0-pre1]: https://github.com/Two-Weeks-Team/he-was-socrates/releases/tag/v0.1.0-pre1
