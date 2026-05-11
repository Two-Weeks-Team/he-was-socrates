# Session Handoff — First-Launch UX Improvements

**Created**: 2026-05-06
**Project**: He Was Socrates — Korean Socratic on-device macOS app
**Hackathon**: The Gemma 4 Good Hackathon (Kaggle/Google DeepMind), submission deadline **2026-05-19 08:59 KST** (D-13 from this handoff)
**Last commit on main**: `3f02a34` (Merge PR #32 PR-Λ disk-mediated KV cache reuse)

---

## 1. Where the previous session left off

The user tested PR-Λ (latest main, ~800 ms per-turn decode + ~2 s user-facing) and reported:

> "충분히 빠른데?"
> "맞아 부트스트랩이 7초정도 걸려. 그리고 한국어 다운로드나 그외 조건이 일반 사용자용으로 너무 불편해."

Translated: "Fast enough — but bootstrap takes ~7s and Korean voice/STT downloads + other setup conditions are too inconvenient for general users."

The user then asked for a handoff document so a new session can pick up the **first-launch UX work**.

---

## 2. Current state of `main`

### Git
- HEAD: `3f02a34` — Merge PR #32 PR-Λ
- Recent commits:
  ```
  3f02a34 Merge pull request #32 from Two-Weeks-Team/perf/disk-mediated-kv-reuse-pr-lambda
  aab5100 fix(gemma): apply PR #32 review feedback (gemini + codex P1)
  0ccac49 Merge pull request #31 from Two-Weeks-Team/fix/xcodegen-folder-resources-app-build
  0326bf4 perf(gemma): disk-mediated KV cache reuse — TTFT 4.6s→192ms (24×) [PR-Λ]
  ```
- Working tree clean. No PR-μ (our prior in-memory variant) — superseded by PR-Λ.

### Performance (PR-Λ measured on M1 Max MBP 64 GB / Gemma 4 E4B 4-bit MLX)
- **load**: ~1.9 s (cached weights)
- **warmup**: ~4.8 s — runs `streamResponse(to: "ready")` to EOS, saves KV cache to disk **every launch** (no skip-if-exists, by intent)
- **per-turn median wall**: ~800 ms (decode only)
- **per-turn user-facing**: ~2 s (decode + STT endpoint + TTS prep + Korean audio playback)
- **bootstrap total**: ~7 s every launch (1.9 + 4.8 + first-turn 0.8)

### Tests
- **65 swift-testing scenarios** all green local + CI
- CI matrix: macos-15 + Xcode latest-stable
- `make ci-local` passes

### Build verified end-to-end
- `make assets && make xcodeproj && make app` → BUILD SUCCEEDED
- App at `~/Library/Developer/Xcode/DerivedData/HeWasSocrates-*/Build/Products/Debug/HeWasSocrates.app`
- 16 viseme PNGs + face_halftone.png correctly bundled (PR #31 xcodegen fix in effect)

---

## 3. The work to pick up: first-launch friction

User-validated friction matrix for general users on a fresh Mac:

| Item | Current handling | User impact | Severity |
|---|---|---|---|
| **Korean TTS Voice (Yuna) missing** | "음성을 찾을 수 없다" — **no recovery hint** | macOS doesn't bundle ko-KR voice by default. User sees fail with no install instructions. | 🔴 HIGH |
| **Korean STT model missing** | recovery hint exists ("Siri & Spotlight → 한국어 켜라") | Only shown after fail-after-the-fact; no preflight | 🔴 HIGH |
| **Gemma 4 weights ~3.97 GB download** | `loadProgress` shown as Double (0..1) | 5-30 min wait first launch, no human-readable progress text | 🔴 HIGH |
| **TCC microphone permission** | recovery hint exists | First-launch popup. If denied, fail → see hint | 🟡 MID |
| **TCC speech recognition permission** | recovery hint exists | Same as above | 🟡 MID |
| **Preflight check** | **None** ❌ — all checks fail-after-the-fact | User sees errors only after attempting | 🔴 HIGH |
| **Bootstrap 7 s splash** | spinner + numeric progress | 7 s every launch, no human-readable phase text | 🟡 MID |

### Code locations of relevant pieces
- `apps/macos/HeWasSocrates/HeWasSocrates/ContentView.swift` — `FailedMessage` namespace (Korean recovery hints), `SocraticAppViewModel`, bootstrap UI
- `packages/SocraticEngine/Sources/SocraticEngine/Errors/PhaseFailureKey.swift` — failure key constants (incl. `ttsVoiceMissing`, `sttOnDeviceUnsupported`)
- `packages/SocraticEngine/Sources/SocraticEngine/Audio/TTSManager.swift` — Korean voice resolution chain (premium → enhanced → default)
- `packages/SocraticEngine/Sources/SocraticEngine/Audio/AudioInputManager.swift` — `supportsOnDeviceRecognition` precheck (PR-θ)
- `packages/SocraticEngine/Sources/SocraticEngine/Gemma/GemmaService.swift` — `loadModel()` + `warmup()` (PR-Λ disk-mediated)
- `packages/SocraticEngine/Sources/SocraticEngine/EngineCoordinator.swift` — `bootstrap()` orchestration

---

## 4. Proposed improvements (with effort estimates)

### Tier 1 — Small code, big UX (~1 day total)

**T1.1** 🔴 **Yuna voice recovery hint** (5 min)
- File: `apps/macos/HeWasSocrates/HeWasSocrates/ContentView.swift`
- Add to `FailedMessage.recovery(for:)` switch:
  ```swift
  case PhaseFailureKey.ttsVoiceMissing:
      return "시스템 설정 → 손쉬운 사용 → 음성 콘텐츠 → 시스템 음성 → 한국어 → Yuna 다운로드"
  ```
- No regression risk. Single new switch case.

**T1.2** 🔴 **Bootstrap pre-flight check + setup screen** (4-6 h)
- New phase `Phase.preflightChecking` or modify `.bootstrapping` to multi-stage
- Checks at startup, before model load:
  1. Mic permission — TCC `AVAudioApplication.requestRecordPermission`
  2. Speech recognition permission — `SFSpeechRecognizer.requestAuthorization`
  3. ko-KR voice installed — `AVSpeechSynthesisVoice.speechVoices().contains { $0.language == "ko-KR" }`
  4. ko-KR STT supportsOnDeviceRecognition — `SFSpeechRecognizer(locale: ko-KR)?.supportsOnDeviceRecognition == true`
- If any missing, show **single setup screen** with:
  - Checklist (✅/❌ per item)
  - Per-item Korean instruction + system-preferences-deeplink button (`x-apple.systempreferences:` URL)
  - "다시 점검" button
- Once all green, auto-proceed to bootstrap

**T1.3** 🟡 **Bootstrap progress text** (2 h)
- File: `ContentView.swift` SocraticAppViewModel
- Replace numeric progress with phase-aware Korean text:
  - "Gemma 4 다운로드 중 (1.2 / 3.97 GB)" — when `loadProgress < 1.0`
  - "모델 준비 중..." — during warmup
  - "흉상 깨우기..." — final transition

### Tier 2 — Larger work, biggest impact (1-3 days)

**T2.1** 🔴 **Gemma weights sidecar in DMG** (1-2 d)
- Eliminate first-launch 4 GB download
- Two shapes:
  - **(a) Bundled-in-DMG**: include weights in `HeWasSocrates.app/Contents/Resources/Models/` — DMG ~4.5 GB, exceeds GitHub Releases 2 GiB cap → host on Cloudflare R2 / Backblaze B2
  - **(b) Sidecar installer**: small DMG (~50 MB) + separate `WeightsDownloader.app` or `install-weights.sh` that judges run before main app — staged into sandbox container
- (b) is recommended (smaller distribution, preserves GitHub Releases hosting)
- See `claudedocs/2026-05-06-stack-comparison-research.html` slide 21 (DMG distribution research) for full pipeline

**T2.2** 🟡 **First-launch onboarding wizard** (1-2 d)
- Extends T1.2 into multi-screen Welcome flow
- Welcome → Permission requests with explanation → Setup checklist → "Ready" confirmation

### Tier 3 — Optional polish

**T3.1** 🟢 Bootstrap warm-restart skip — saves 4.8 s warmup on subsequent launches by checking if cache file exists at the start of `warmup()`. Was discussed and **deferred** by user ("충분히 빠른데?"). Code patch ready in this handoff (Section 7).

---

## 5. Rule / SpecDD compliance check (all proposed items)

| Rule | T1.1 | T1.2 | T1.3 | T2.1 | T2.2 |
|---|---|---|---|---|---|
| Hackathon §2.6.b external models/tools acceptable | ✅ | ✅ | ✅ | ✅ | ✅ |
| §3.6.c OSI-approved code | ✅ | ✅ | ✅ | ✅ | ✅ |
| §2.5.a CC-BY 4.0 winner grant compatible | ✅ | ✅ | ✅ | ✅ | ✅ |
| NO-CLOUD invariant (CLAUDE.md #2) | ✅ | ✅ | ✅ | ✅ enhances offline | ✅ |
| `runs/2026-05-05-spec/` lock (CLAUDE.md #5) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Korean prompt verbatim (CLAUDE.md #3) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Stable surface (CONTRIBUTING.md L27-31) | ✅ | needs new `Phase` case if added — emit failure key instead, see note | ✅ | ✅ | ✅ |

**Note for T1.2**: adding a new `EngineCoordinator.Phase` case (e.g., `.preflightChecking`) would be a stable-surface change requiring SpecDD delta. Avoid — instead reuse `.bootstrapping` and surface preflight state via a new `BootstrapStage` published property on the ViewModel (UI-only, not engine surface).

---

## 6. Recommended next-session plan

User chose between:
- **A** (minimal): T1.1 + T1.2 + T1.3 → ~1 day, transforms first-launch UX
- **B** (ideal): A + T2.1 sidecar → ~2 days, eliminates 4 GB download
- **C** (full wizard): A + T2.1 + T2.2 → ~3-4 days
- **D** (custom): user picks specific items

User has not yet selected. Default recommendation in the prior session: **A or B**.

### Concrete first action when next session starts

1. Confirm user's choice (A/B/C/D)
2. Create branch from main: `git checkout -b feat/firstlaunch-ux main`
3. Start with **T1.1** (5 min, safe, immediate value) regardless of larger choice — fixes the biggest single hint gap (Yuna)
4. Then **T1.2** (preflight check) — design first, validate the `Phase` strategy before coding
5. Build + launch test on user's machine before any commit

### What NOT to do
- Don't add new `EngineCoordinator.Phase` cases (stable-surface)
- Don't modify `runs/2026-05-05-spec/`
- Don't change Korean system prompt
- Don't change Gemma model variant (E4B 4-bit MLX, frozen invariant)
- Don't restart the audit / 17-agent comparison work — already complete and documented at `claudedocs/2026-05-06-final-audit-merged-state-report.html` and `claudedocs/2026-05-06-stack-comparison-research.html`
- Don't commit/PR the deferred Tier 3 (warm-restart skip) unless user revisits

---

## 7. Tier 3 deferred patch — ready to apply if revisited

If user later reverses on the 5 s warmup-skip optimization, the patch is small:

**File**: `packages/SocraticEngine/Sources/SocraticEngine/Gemma/GemmaService.swift`
**Location**: `public func warmup() async`, inside `case .real`, after `guard let container = modelContainer`

**Change**: hoist the `cacheURL` resolution out of the second `do { ... }` block to the top, then add a fast-path branch:

```swift
case .real:
    #if canImport(MLXLLM)
    guard let container = modelContainer else { return }

    // Resolve cache path up-front
    let cacheURL: URL
    do {
        let cachesDir = try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        cacheURL = cachesDir.appendingPathComponent(
            "hewassocrates-system-prompt-cache.safetensors")
    } catch { return }

    // Fast path: cache file from previous launch already valid
    if FileManager.default.fileExists(atPath: cacheURL.path) {
        do {
            let (loaded, _) = try loadPromptCache(url: cacheURL)
            if loaded.isEmpty { throw GemmaServiceError.warmCacheEmpty }
            systemCacheURL = cacheURL
            return  // SKIP fresh build — saves ~4.8s
        } catch {
            try? FileManager.default.removeItem(at: cacheURL)
            // fall through
        }
    }

    // Existing PR-Λ cold-build code follows unchanged
    let warmSession = ChatSession(container, instructions: ..., ...)
    ...
    try await warmSession.saveCache(to: cacheURL)
    systemCacheURL = cacheURL
    ...
```

**Threat model defense** (in case PR-Λ author objects via review):
> Cache contents are deterministic in (model weights, system prompt, generateParameters) — all three are frozen invariants in this project (CLAUDE.md #2/#3/#5). A cached file from a previous launch is bit-equivalent to what fresh warmup would produce. mlx-swift-lm wire-format change → loadPromptCache throws → caught → file removed → fresh rebuild (the existing PR-Λ path).

---

## 8. Reference artifacts

### Reports (in `claudedocs/`)
- `2026-05-06-final-audit-merged-state-report.html` — final audit close-out, 24 slides, 10 PRs merged α→κ + bench reproducibility
- `2026-05-06-stack-comparison-research.html` — 17-agent stack comparison (Groq / Apple Foundation Models / etc.), 24 slides
- `bench/2026-05-06-latency-bench.json` + `.log` — current PR-Λ baseline measurements

### Memory files (auto-loaded next session)
At `/Users/kimsejun/.claude/projects/-Users-kimsejun-Documents-GitHub-he-was-socrates/memory/`:
- `MEMORY.md` (index)
- `project_audit_state.md` — 11 PRs merged, ship-ready
- `project_invariants.md` — frozen invariants list
- `project_latency_floor.md` — measured 6.0 s/turn pre-PR-Λ (now ~0.8 s post-PR-Λ — needs update)
- `project_stack_choices.md` — MLX/Gemma 4/GPU verification
- `project_stack_comparison_reference.md` — 17-agent comparison index
- `feedback_no_squash.md` — merge policy
- `feedback_official_sources_only.md` — research-citation policy
- `user_role.md` — user collaboration mode

### Spec / contracts
- `runs/2026-05-05-spec/spec/SPEC.md` — frozen spec (lock SHA preserved)
- `runs/2026-05-05-spec/spec/SPEC.md.iter5-phoneme-pipeline-correction.md` — current delta
- `runs/2026-05-05-spec/idea.spec.json` — model variant + load-bearing features
- `CLAUDE.md` — project root invariants (read first)
- `HANDOFF.md` — gallery → repo handoff (original)
- `CONTRIBUTING.md` L27-31 — stable surface contract

### Hackathon submission artifacts (handled by another teammate, not this thread)
- Apple Developer Program $99 — already enrolled (per user)
- Kaggle writeup ≤1500 words — pending
- YouTube ≤3 min demo video — pending
- DMG notarized — pending
- See `claudedocs/2026-05-06-stack-comparison-research.html` slide 7 + 21 for distribution checklist

---

## 9. Quick session resume command (for new session)

After loading this handoff, the next assistant can verify state and ask the user which tier:

```
1. git status                                # working tree clean?
2. git log --oneline -3                       # main HEAD = 3f02a34?
3. swift test --package-path packages/SocraticEngine | tail -3   # 65 tests green?
4. ls claudedocs/                             # final-audit + stack-comparison + this handoff
5. cat claudedocs/2026-05-06-session-handoff-firstlaunch-ux.md   # this file
6. Ask user: "A / B / C / D ?" per Section 6
```

---

## 10. Open questions for next session

1. **Tier choice**: A (minimal, ~1d) / B (+sidecar, ~2d) / C (+wizard, ~3-4d) / D (custom)?
2. **Sidecar shape** if T2.1 chosen: bundled-in-DMG (4.5GB) or separate WeightsDownloader.app (~50 MB DMG)?
3. **System Settings deeplink strategy**: `x-apple.systempreferences:` URLs are not in App Sandbox public docs and may be fragile across macOS versions — verify or use plain text instructions?
4. **Tier 3 (warmup skip)**: keep deferred or revisit?
5. **Submission timeline**: any update from teammate handling writeup/video/DMG that affects our Tier choice?

End of handoff.
