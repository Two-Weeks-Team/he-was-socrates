# SPEC.md Iter-6 Amendment — macOS 26 Tahoe Deployment Floor

| Field | Value |
|---|---|
| Authority | First-launch UX research (`claudedocs/2026-05-06-firstlaunch-ux-bestpractices.html`) + user decision 2026-05-06 KST |
| Source | Apple Developer documentation (SpeechAnalyzer / AssetInventory, WWDC25 session 277), useyourloaf reference on AVSpeechSynthesisVoice quality tiers, rmcdongit canonical deeplink reference |
| Affects | `LSMinimumSystemVersion` / SwiftPM `platforms` declarations / SocraticEngine module compile targets / app target deployment target |
| Builds on | `SPEC.md.iter2-amendment.md`, `SPEC.md.iter4-api-correction.md`, `SPEC.md.iter5-phoneme-pipeline-correction.md` |
| SHA-256 lock | **NOT recomputed**. Treat this amendment as authoritative for downstream first-launch UX work; freeze v1 SHA preserved for audit. |

---

## Background

The frozen `SPEC.md` (lock SHA `37538c5783ea51173a4eeccbea2b94d2cb1746a5bba9ce4a4562b6d98c1480f0`) inherited a `macOS 14.0+` deployment floor from the v1 design assumption that the engine layer should remain compatible with both Sonoma and Sequoia at ship time. Iter-5 already documented that empirical validation occurred on macOS 26.4.1; the `tools/ApplePhonemeProbe` run that produced the `no-markers-anywhere` verdict was performed against Tahoe SDK headers.

Two developments drive the floor revision:

1. **First-launch UX research** (2026-05-06): the `SpeechAnalyzer` + `AssetInventory.assetInstallationRequest(supporting:)` API introduced in macOS 26 lets the app **install ko_KR + en_US speech recognition assets in-app with a single user tap and a `Foundation.Progress`-driven UI**. Under the macOS 14/15 path the only available pattern is a System Settings deeplink with manual user navigation through Keyboard → Dictation → Languages → Edit → 한국어 — a non-trivial chain for a non-technical Korean user. The macOS 26 path is materially better.

2. **Bilingual scope expansion** (same date): the project now treats Korean **and** English as first-class languages requiring pre-flight asset installation. The `AssetInventory` API accepts a single request covering both locales (`supporting: [transcriberKo, transcriberEn]`), collapsing what would be two separate manual flows on the deeplink path into one in-app download.

Both developments are documented with Apple-official primary sources in the linked report. The floor revision is the precondition that unlocks the materially better UX without requiring a deeplink fallback path that complicates the pre-flight code by ~40%.

---

## Amendment

### Deployment floor — macOS 14.0 → macOS 26.0 Tahoe

The following declarations move from `14.0` / `.v14` to `26.0` / `"26.0"`:

| File | Locator | Before | After |
|---|---|---|---|
| `apps/macos/HeWasSocrates/HeWasSocrates/Resources/Info.plist` | `LSMinimumSystemVersion` | `14.0` | `26.0` |
| `apps/macos/HeWasSocrates/project.yml` | `options.deploymentTarget.macOS` | `"14.0"` | `"26.0"` |
| `apps/macos/HeWasSocrates/project.yml` | `targets.HeWasSocrates.deploymentTarget` | `"14.0"` | `"26.0"` |
| `apps/macos/HeWasSocrates/project.yml` | `targets.HeWasSocratesTests.deploymentTarget` | `"14.0"` | `"26.0"` |
| `packages/SocraticEngine/Package.swift` | `platforms` | `.macOS(.v14)` | `.macOS("26.0")` |
| `tools/ApplePhonemeProbe/Package.swift` | `platforms` | `.macOS(.v14)` | `.macOS("26.0")` |

The string form (`"26.0"`) is used in SwiftPM declarations rather than the named constant (`.v26`) for SwiftPM-version portability — the named constant requires a SwiftPM version that recognises macOS 26 as a known platform tier, which varies across the toolchains a future contributor may have installed.

### Newly accessible APIs (not yet adopted; iter-6 only opens the door)

The following macOS 26 APIs become call-site reachable; iter-6 itself does **not** mandate adoption, only authorises it:

- `SpeechTranscriber` — Speech.framework (https://developer.apple.com/documentation/speech/speechtranscriber)
- `SpeechAnalyzer` — Speech.framework (https://developer.apple.com/documentation/speech/speechanalyzer)
- `AssetInventory.assetInstallationRequest(supporting:)` — Speech.framework (https://developer.apple.com/documentation/speech/assetinventory)

The first concrete adoption — installing `ko_KR + en_US` speech recognition assets at pre-flight — is tracked under the first-launch UX work plan, not this amendment. The `SFSpeechRecognizer` STT body in `AudioInputManager.swift` remains the recognition path; only the asset-install path is delegated to `AssetInventory`. The two share OS-level on-device speech model assets, so the mixed configuration is supported.

### NOT changed by this amendment

- The NO-CLOUD invariant (`network.client` / `network.server` entitlements remain absent).
- The Korean Socratic system prompt verbatim text in `Sources/SocraticEngine/Gemma/SystemPrompt.swift`.
- The Gemma 4 E4B 4-bit MLX variant choice; nothing about the model load path moves.
- The `EngineCoordinator.Phase` enum surface; no new case is introduced.
- The `runs/2026-05-05-spec/` lock SHAs; this amendment is a delta document, not an edit to a locked file.

---

## Trade-off acknowledgement

The floor lift excludes users on macOS 14 (Sonoma) and macOS 15 (Sequoia). The trade-off was evaluated against:

- **General macOS update behaviour** — the user noted that macOS users tend to stay on the latest major version, and Apple's own release notes show >70% adoption of the current major within ~6 months of a release. Tahoe shipped 2025-09; 2026-05 adoption is mature.
- **Hackathon scope** — `The Gemma 4 Good Hackathon` (Kaggle/DeepMind) submission deadline 2026-05-19 has no published OS requirement that excludes macOS 26.
- **UX cost of supporting both floors** — maintaining a deeplink fallback for macOS 14/15 alongside the `AssetInventory` path approximately doubles the pre-flight asset-install code and adds a return-from-System-Settings polling loop. The simpler one-path implementation is preferred for the marathon's remaining 13-day window.

The decision is committed; reverting would require a follow-up delta amendment.

---

## Verification

The amendment is satisfied when **all of**:

1. `make xcodeproj` regenerates without warnings about unrecognised deployment-target strings.
2. `make engine-test` passes its 65 swift-testing scenarios (no test depends on `LSMinimumSystemVersion`; 65/65 expected).
3. `make ci-local` passes — same gates as `.github/workflows/ci.yml`.
4. The `.app` built by `make app` reports `LSMinimumSystemVersion = 26.0` under `Bundle.main.infoDictionary["LSMinimumSystemVersion"]`.

The CI runner image (`macos-15` per `.github/workflows/ci.yml`) builds the `.app` correctly with a higher `LSMinimumSystemVersion` because Xcode-on-macOS-15 ships an SDK targeting macOS 26 (forward SDK, lower host OS — supported configuration). Adding a `macos-26` runner for runtime verification is a separate optional follow-up not gated by this amendment.

---

## Cross-reference

- First-launch UX best-practices report — `claudedocs/2026-05-06-firstlaunch-ux-bestpractices.html`
- Session handoff — `claudedocs/2026-05-06-session-handoff-firstlaunch-ux.md`
- WWDC25 session 277 — https://developer.apple.com/videos/play/wwdc2025/277/
- AssetInventory documentation — https://developer.apple.com/documentation/speech/assetinventory
