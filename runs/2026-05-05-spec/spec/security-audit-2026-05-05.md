# Security Audit — He Was Socrates (Phase 6 review)

**Date:** 2026-05-05
**Auditor:** `security-engineer` agent (Claude Opus 4.7, 1M ctx)
**Branch:** `repo-setup-ci-and-docs`
**Commit at audit start:** `da22782 chore: add spec/ placeholder for SpecDD outputs`
**Mandate:** read-only audit ahead of public release. No application code modified.

---

## 1. Scope reviewed

Files inspected (all paths absolute from repo root):

- `apps/macos/HeWasSocrates/HeWasSocrates/Resources/HeWasSocrates.entitlements`
- `apps/macos/HeWasSocrates/HeWasSocrates/Resources/Info.plist`
- `packages/SocraticEngine/Package.swift`
- `packages/SocraticEngine/Package.resolved`
- `packages/SocraticEngine/Sources/SocraticEngine/Gemma/SystemPrompt.swift`
- `packages/SocraticEngine/Sources/SocraticEngine/Gemma/ModelIntegrity.swift`
- `packages/SocraticEngine/Sources/SocraticEngine/Gemma/GemmaService.swift`
- `packages/SocraticEngine/Sources/SocraticEngine/Gemma/FunctionCallParser.swift`
- `packages/SocraticEngine/Sources/SocraticEngine/Gemma/FunctionCallOrchestrator.swift`
- `packages/SocraticEngine/Sources/SocraticEngine/Audio/AudioInputManager.swift`
- `packages/SocraticEngine/Sources/SocraticEngine/EngineCoordinator.swift`
- `packages/SocraticEngine/Sources/SocraticEngine/Storage/WonderingLog.swift`
- `scripts/preview-server.py`
- `scripts/build-visemes.sh`
- `.gitignore`
- `.github/workflows/ci.yml`
- `NOTICE`, `README.md`, `SETUP.md`, `HANDOFF.md`
- `runs/2026-05-05-spec/spec/entitlements.plist.md`
- `runs/2026-05-05-spec/spec/network-test-plan.md`
- `runs/2026-05-05-spec/spec/model-integrity.md`
- `runs/2026-05-05-spec/spec/SPEC.md` (selected sections)
- `packages/SocraticEngine/.build/checkouts/*/LICENSE*` (transitive license sweep)

Files I did NOT inspect (out of mandate or out of audit scope): the rest of
`apps/`, `tools/`, `docs/`, the SpecDD frozen artifacts beyond the four
above, `.venv-build/`, `assets/`.

---

## 2. Tooling output summary

### 2.1 gitleaks

```
$ gitleaks detect --no-banner --source .
INF 3 commits scanned.
INF scanned ~801831 bytes (801.83 KB) in 189ms
INF no leaks found
```

Note: gitleaks ran with the **default ruleset**. `runs/2026-05-05-spec/spec/entitlements.plist.md` §8 specifies a custom `.gitleaks.toml` (Apple-App-Specific-Password regex + PEM block regex) committed at repo root. **It is not present.** See finding `M-04`.

### 2.2 Manual credential grep

```
$ grep -rEni 'password|secret|token|api[_-]?key' \
    --include='*.swift' --include='*.py' --include='*.sh' .
```

All matches were benign:

- `Tokenizer` / `Tokenizers` — HuggingFace library symbol references
- `maxTokens` — LLM context-window parameter
- (no `password`, `secret`, `apiKey`, etc.)

### 2.3 Manual network-call grep

```
$ grep -rEni 'URLSession|URLRequest|http\.client|requests\.get|fetch\(|urllib|httpx|aiohttp' \
    --include='*.swift' --include='*.py' .

scripts/preview-server.py:15:from urllib.parse import urlparse
```

The single match is **URL parsing only**, no network call. No `URLSession` / `URLRequest` anywhere in shipped Swift sources.

### 2.4 Localhost-only verification of preview-server

```
scripts/preview-server.py:145:    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
```

Bound to `127.0.0.1` only. Not reachable off-box.

### 2.5 Transitive license sweep

All 16 transitive Swift packages reviewed under
`packages/SocraticEngine/.build/checkouts/*/LICENSE*`:

| Package | Pinned version | License |
|---|---|---|
| EventSource (mattt) | 1.4.1 | MIT |
| mlx-swift | 0.31.3 | MIT |
| mlx-swift-lm | 3.31.3 | MIT |
| swift-asn1 | 1.7.0 | Apache-2.0 |
| swift-atomics | 1.3.0 | Apache-2.0 |
| swift-collections | 1.4.1 | Apache-2.0 |
| swift-crypto | 4.5.0 | Apache-2.0 |
| swift-huggingface | 0.9.0 | Apache-2.0 |
| swift-jinja | 2.3.5 | Apache-2.0 |
| swift-nio | 2.99.0 | Apache-2.0 |
| swift-numerics | 1.1.1 | Apache-2.0 |
| swift-syntax | 600.0.1 | Apache-2.0 |
| swift-system | 1.6.4 | Apache-2.0 |
| swift-testing | 0.99.0 | Apache-2.0 |
| swift-transformers | 1.3.1 | Apache-2.0 |
| yyjson | 0.12.0 | MIT |

**No GPL-tainted dependency.** SC7-002 license-compatibility — pass.

---

## 3. Findings

Severity legend: BLOCKING (must fix before public release) · HIGH · MEDIUM · LOW · INFO.

### H-01 — Runtime model-load path attempts HuggingFace download (HIGH)

**Where:** `packages/SocraticEngine/Sources/SocraticEngine/Gemma/GemmaService.swift` lines 71–88; reinforced by `SETUP.md` lines 65–67 and 110–125.

**What:** In `.real` mode, `GemmaService.loadModel()` calls
`LLMModelFactory.shared.loadContainer(from: #hubDownloader(), ...)`. This is
a network call to HuggingFace Hub. The accompanying source comment
acknowledges that "first launch (~3.97 GB) [downloads] into
`~/Library/Caches/com.apple.MLX/...`". `SETUP.md` instructs users to set
`HF_ENDPOINT=https://huggingface.co` if the download stalls.

This is in direct tension with the **NO cloud egress** invariant.

**Evidence:**

```swift
// GemmaService.swift:75–83
let container = try await LLMModelFactory.shared.loadContainer(
    from: #hubDownloader(),
    using: #huggingFaceTokenizerLoader(),
    configuration: LLMRegistry.gemma4_e4b_it_4bit
) { progress in
    Task { [weak self] in
        await self?.updateProgress(progress.fractionCompleted)
    }
}
```

```swift
// GemmaService.swift:25–27 (source comment)
///   3. Optionally bundle weights into app `Resources/` for offline-first
///      install (per `idea.spec.json` no-runtime-download policy). When
///      bundled, set `useBundledWeights = true` so we skip HuggingFace fetch.
```

The `useBundledWeights = true` flag is **referenced in the comment but not
implemented anywhere** in `GemmaService` or its callers (verified by grep).

**Severity rationale:** the App Sandbox **does** block this download in
practice (no `network.client` entitlement → kernel denies the socket). So
the user-visible behavior on a notarized release build is "load fails".
However:

1. The codepath itself violates the invariant in intent.
2. Anyone running this in a non-sandboxed context (CLI `swift run`, dev
   build, tests) will hit HuggingFace.
3. `SETUP.md` lines 65–67 promise the download as part of first launch,
   which is wrong and will mislead future contributors.
4. If the sandbox were ever weakened or the entitlement reintroduced (a
   one-line PR), egress immediately follows.

**Remediation (recommended):**

- Implement `useBundledWeights` properly. If bundled, point
  `LLMModelFactory` at a local `URL` derived from
  `Bundle.module.url(forResource: "models/gemma-4-e4b-it-4bit", ...)`
  rather than `#hubDownloader()`.
- Update `SETUP.md` to remove the HF-Hub download instructions and replace
  with a one-shot Stage-5 day-1 bundling step (matches
  `runs/2026-05-05-spec/spec/model-integrity.md` §1).
- Add a release-build assertion: if `useBundledWeights == false` in a
  release build, refuse to load and emit `SocraticErrorCode.modelLoadFailed`
  with a "configuration error" rationale.

**Owner:** Stage-5 day-1 (engine + bundling). Should land before video shoot.

### H-02 — Defense-in-depth `URLProtocol` egress shim is not implemented (HIGH)

**Where:** documented in
`runs/2026-05-05-spec/spec/network-test-plan.md` §1 Layer 3 lines 33–54;
not present in `apps/macos/HeWasSocrates/HeWasSocrates/HeWasSocratesApp.swift`
or anywhere else in `apps/` or `packages/`.

**What:** The network-test-plan specifies an `EgressBlockingProtocol`
registered at `NSApplicationDidFinishLaunching` that intercepts and
**fails-closed** every `URLRequest`, while incrementing a counter the
OfflineProofBadge surfaces. This is the only runtime layer that catches
egress attempts originating from transitive dependencies (swift-nio,
EventSource/AsyncHTTPClient, swift-huggingface) before the kernel blocks
the socket. Without it:

1. A transitive dep's network attempt is logged only by the kernel, not
   by the app.
2. The OfflineProofBadge "Blocked: N" counter cannot be populated.
3. The audit Layer-3 control of network-test-plan.md is missing.

**Evidence:** `grep -rE "URLProtocol|EgressBlocking" apps packages` returns
zero hits in shipped sources. The only `URLProtocol` references are in
`.build/checkouts/EventSource/Tests/` (test fixtures of a transitive dep).

**Severity rationale:** the kernel-level sandbox already enforces the
no-egress invariant, so this is **defense-in-depth, not the only line of
defense**. However it is explicitly part of the spec contract (M04
OfflineProofBadge requires a counter to populate) and the demo-day
verification depends on it being shippable.

**Remediation:** implement `EgressBlockingProtocol` per the spec sketch and
register it in `HeWasSocratesApp.applicationDidFinishLaunching`. Wire the
counter into `OfflineProofBadge`.

**Owner:** `apps/macos/HeWasSocrates/` — depends on Phase 4 / Phase 5 app
wiring.

### M-01 — `build-visemes.sh` evaluates Python output via `eval` (MEDIUM)

**Where:** `scripts/build-visemes.sh` lines 47–69.

**What:** The shell script reads
`assets/.preview-config.json` and pipes it through a Python heredoc that
prints lines like `MOUTH_XY=514,540`. Those lines are then captured by
`eval "$(...)"` — bash will eval them as commands, not just variable
assignments.

```bash
# build-visemes.sh:47–69 (excerpted)
if [ -f "$CONFIG" ] && command -v python3 >/dev/null; then
    eval "$(python3 - <<PY
import json, pathlib
...
def out(name, val):
    if val is None: return
    print(f"{name}={val!s}")
...
PY
)"
fi
```

The values come from a JSON file that is **also writable through the
preview-server's `POST /api/config` endpoint**, which has no input
validation beyond "is it a dict".

**Attack model:** an attacker on the same machine, with write access to
`assets/.preview-config.json` (or able to send a POST to `127.0.0.1:8765`
while the developer has the preview server up), can craft a value such as

```json
{"dot_size": "1\nrm -rf /tmp/something\nDOT_SIZE=1"}
```

The Python `print(f"{name}={val!s}")` produces three lines, the second of
which is interpreted by `eval` as a shell command. The assignment uses
unquoted, unsanitized `val`.

**Severity rationale:** dev-machine only — `preview-server.py` is
`127.0.0.1`-bound and `build-visemes.sh` is build-time only. **The
released DMG is not affected.** But the attack is real on a developer
laptop with the preview server running, and a malicious browser tab on
the same machine can `fetch('http://127.0.0.1:8765/api/config', {method:'POST', ...})`
to plant a payload. CSRF protections on the preview server are absent
(no `Origin`/`Referer` check, no token).

**Remediation:**

1. Replace `eval` with a `source`-of-a-file pattern: have Python emit a
   key=value `.env`-style file with **shell-quoted** values, then
   `set -a; source <file>; set +a`. Or better, use `printf '%q'` from
   bash to quote each value.
2. In `preview-server.py`, validate each known config key against a
   strict regex / type whitelist before persisting.
3. Add an `Origin` header check on `POST /api/config` and `POST /api/rebuild`
   to reject CSRF.

**Owner:** scripts/ tooling.

### M-02 — `Package.resolved` is gitignored (MEDIUM)

**Where:** `.gitignore` line 21 — `Package.resolved`.

**What:** SwiftPM's `Package.resolved` is the lockfile that pins
transitive dependencies to exact commit SHAs. Excluding it from version
control means:

1. Every developer / CI run can independently re-resolve to a different
   transitive set if the upstream package's version range allows it.
2. Supply-chain reproducibility is lost — a malicious upstream that
   publishes a new patch version inside the existing range gets pulled in
   silently.
3. `.github/workflows/ci.yml` line 61 hashes against `Package.resolved`
   for caching, which means CI is hashing against the **un-checked-in**
   working-tree file (whatever resolution the runner produces). This
   defeats deterministic caching.

**Evidence:**

```
$ git check-ignore -v packages/SocraticEngine/Package.resolved
.gitignore:21:Package.resolved   packages/SocraticEngine/Package.resolved
```

For an **application** (vs. a library), Swift convention is to commit
`Package.resolved`. Apple's own
[documentation](https://developer.apple.com/documentation/xcode/identifying-binary-dependencies)
explicitly recommends this for apps.

**Severity rationale:** this is a real supply-chain weakness and easy to
fix. Not a release-blocker because the current resolved versions are
pinned and reputable, but the moment any upstream publishes a malicious
patch, every fresh build picks it up.

**Remediation:**

1. Remove `Package.resolved` from `.gitignore` (or scope the ignore to
   library packages).
2. `git add packages/SocraticEngine/Package.resolved` and commit.
3. (Optional) Also commit `apps/macos/HeWasSocrates/.../Package.resolved`
   if the Xcode project resolves separately.

**Owner:** repo maintainer.

### M-03 — Custom `.gitleaks.toml` not committed; CI relies on default ruleset (MEDIUM)

**Where:** `runs/2026-05-05-spec/spec/entitlements.plist.md` §8 lines 144–158
specifies `.gitleaks.toml` rules (Apple App-Specific Password,
PEM private key); `.github/workflows/ci.yml` line 142 runs
`gitleaks detect --no-banner --source . --redact`.

**What:** the `.gitleaks.toml` file is not present at repo root. gitleaks
falls back to its default ruleset. The default catches AWS / GitHub /
Slack / Stripe etc. tokens but **does not have a regex for Apple
App-Specific Passwords** (4-quartet `xxxx-xxxx-xxxx-xxxx`). Per spec the
project's primary credential class IS the Apple App-Specific Password
used for notarization — exactly the regex that's missing.

**Evidence:** `ls /Users/kimsejun/Documents/GitHub/he-was-socrates/.gitleaks.toml` → no such file.

**Severity rationale:** medium because (a) the default ruleset still
provides general coverage, (b) `.env`/`*.p12` files are gitignored anyway,
but (c) the spec promises this control as part of SC7-011 and operating
without it is non-compliant.

**Remediation:** create `.gitleaks.toml` at repo root with the rules in
`entitlements.plist.md` §8 + a couple of generally-useful rules
(GitHub PAT, OpenAI API key, etc.). Re-run gitleaks locally to confirm
no incidental leaks.

**Owner:** repo maintainer.

### M-04 — Pre-commit gitleaks hook not configured (MEDIUM)

**Where:** Spec calls for a pre-commit hook at
`runs/2026-05-05-spec/spec/entitlements.plist.md` §8 line 158 ("Pre-commit
hook runs `gitleaks detect --staged --config .gitleaks.toml`"). No
`.husky/`, `.pre-commit-config.yaml`, or husky-equivalent found in repo.

**What:** secrets caught only at PR-time (CI), not at commit-time.

**Severity rationale:** CI is a sufficient gate for the public release
because PRs cannot land without it. But pre-commit catches mistakes
earlier and avoids leaked-then-rewritten history. Medium severity.

**Remediation:** add either a Husky config (`package.json` already not
present so a pre-commit framework like `pre-commit` works better) or a
shell script in `.git/hooks/pre-commit` that the SETUP.md install step
copies into `.git/hooks/`.

**Owner:** repo maintainer; tied to M-03.

### L-01 — `ModelIntegrity.expectedSHA256` is empty (LOW)

**Where:** `packages/SocraticEngine/Sources/SocraticEngine/Gemma/ModelIntegrity.swift` line 22.

**What:** the canonical hash is `""`. In DEBUG builds `verify(...)` returns
`.skippedDevMode`. In RELEASE builds it returns `.mismatch(actual: ..., expected: "(unset)")`,
which the caller is expected to treat as a launch refusal.

**Severity rationale:** this is **scaffolding**, not a defect — Stage-5
day-1 commits the canonical hash per `model-integrity.md` §2. The release
build would fail-closed today (it does the right thing for the wrong
reason). LOW because the gate works; INFO if you consider it
intentionally pending.

**Remediation:** Stage-5 day-1 — run the bundling pipeline, compute the
SHA-256 of the bundled `weights.safetensors`, commit the constant.

**Owner:** Stage-5 day-1 (engine).

### L-02 — NOTICE third-party SBOM is incomplete (LOW)

**Where:** `NOTICE` lines 109–113 — entry 8 is a placeholder for "Other
Swift Package Manager dependencies pinned in
apps/macos/HeWasSocrates/Package.resolved will be enumerated here at
scaffold completion".

**What:** the 16 transitive Swift packages identified in §2.5 above are
not enumerated in NOTICE. All are MIT or Apache-2.0 (license-compatible),
but Apache-2.0 §4(d) requires retaining attribution notices when
redistributing in derivative works. EventSource (MIT) requires copyright
notice retention. NOTICE is the right place; it's missing them.

**Evidence:** §2.5 transitive license sweep shows the dependency tree.
None are in NOTICE.

**Severity rationale:** strict-reading license compliance, but in
practice Apple SDK Agreement + the licenses' own reciprocity is satisfied
by the pinned source URLs in `Package.resolved`. Low because nobody is
likely to litigate, but it IS a license-compliance gap.

**Remediation:** at Stage-5 (or as a Phase 6 follow-up), generate NOTICE
entries 8–23 from `Package.resolved` automatically — there are tools
(`license-plist`) that do this.

**Owner:** repo maintainer.

### L-03 — `cookies.txt` / leaked-credentials risk (LOW, advisory)

**Where:** advisory only — `.gitignore` already excludes `.env`, `*.pem`,
`*.p12`. The audit grep found no committed credentials. This entry is a
safety reminder cross-referenced from the workspace-level CLAUDE.md
landmine: in the **sister `social-seeding-backend/` repo**, a `cookies.txt`
file with a real session id was committed. **No such file in
he-was-socrates.** Listed here so future contributors don't repeat the
mistake.

**Severity rationale:** N/A (no current finding); advisory-only.

**Remediation:** add `cookies.txt` and `*.session` to `.gitignore`
preemptively. Add gitleaks rule for session-cookie-like patterns.

### I-01 — Sandbox is the **only** runtime line of defense for no-egress (INFO)

**Where:** systemic.

**What:** the dependency tree contains `swift-nio`, `AsyncHTTPClient`
(transitive via EventSource), `swift-huggingface`, and `swift-transformers`.
All are network-capable. The binary therefore has the *capability* to
make network calls; only the App Sandbox prevents it.

This is unavoidable given the choice of `mlx-swift-lm` (which transitively
brings HuggingFace clients). The mitigation is the existing layered
defense:

1. App Sandbox (kernel-level) — present
2. ATS deny-all — present
3. No telemetry SDKs — present
4. URLProtocol shim — **missing** (see H-02)
5. Bundled weights bypass HF — **missing** (see H-01)

**Severity rationale:** informational. The combined controls when fully
implemented (i.e., once H-01 + H-02 are fixed) provide adequate
defense-in-depth. Today the design relies on a single kernel control,
which is acceptable for a sandboxed notarized macOS app but should be
documented.

**Remediation:** the SECURITY.md threat-model section documents this
explicitly. Continue to monitor `Package.resolved` for new network-capable
deps; add a CI strings-scan rule (already specified in
`network-test-plan.md` §1 Layer 2) — that scan rule is **not yet wired
into `ci.yml`** either. (Sub-finding: the strings-scan grep is not part
of CI; only entitlement-scan is mentioned. Wire it in.)

### I-02 — Info.plist usage strings deviate from spec format (INFO)

**Where:** `apps/macos/HeWasSocrates/HeWasSocrates/Resources/Info.plist`
lines 54–58 vs. `runs/2026-05-05-spec/spec/entitlements.plist.md` §4.

**What:** Spec says English in Info.plist + Korean in
`ko.lproj/InfoPlist.strings`. Implementation puts both languages inline
in the English Info.plist string. Result is identical to the user (TCC
shows the localized string), but the structure differs from spec.

**Severity rationale:** functionally correct; SC7-005 is satisfied
(both keys present, both languages covered). Documentation/spec drift
only.

**Remediation:** either update spec to match implementation, or split out
`ko.lproj/InfoPlist.strings`. Cosmetic.

---

## 4. Compliance posture (SC7 control mapping)

| Control | Status | Notes |
|---|---|---|
| **SC7-001 entitlement enumeration** | PASS | `HeWasSocrates.entitlements` declares only sandbox + audio-input + user-selected file r/w + downloads r/w. No `network.client`, no `network.server`, no `disable-library-validation`, no `allow-unsigned-executable-memory`, no `allow-dyld-environment-variables`. Matches `entitlements.plist.md` §1+§3. |
| **SC7-002 license compatibility** | PASS | No GPL anywhere. All transitive Swift deps are MIT or Apache-2.0. espeak-ng is dropped (per ratification (a)) and is not present in `Package.swift`, `Package.resolved`, or `NOTICE`. (Caveat: NOTICE SBOM incomplete — see L-02; not a license-compat issue.) |
| **SC7-003 Gemma TOU compliance** | PASS | `NOTICE` §1 acknowledges Gemma TOU, links the URL, asserts inference-only / byte-identical / SHA-recorded. `LICENSE` is dual Apache-2.0 + CC-BY-4.0 with Gemma weights flagged as governed by Gemma TOU. |
| **SC7-004 COPPA pre-consent collection** | PASS (design) | `SPEC.md` §11.7 specifies the flow: Verifiable Parental Consent BEFORE persistence; auto-detection acts as safety override (purges utterance if consent not yet passed). Implementation pending Phase 4 — see `WonderingLog.swift` Phase-1 in-memory stub. SECURITY.md hardening checklist enforces "no persist without `parentalConsentVerified`". |
| **SC7-005 TCC permissions enumerated** | PASS | `Info.plist` has both `NSMicrophoneUsageDescription` (line 54) and `NSSpeechRecognitionUsageDescription` (line 57). Both contain bilingual KO/EN strings. ATS deny-all is set. (See I-02 for spec-format deviation; not a compliance issue.) |
| **SC7-006 model integrity** | PASS (scaffold) | `ModelIntegrity.swift` implements streaming SHA-256 + verify outcome enum. Canonical hash is empty pending Stage-5 day-1 (see L-01). Release-build behavior is fail-closed on `(unset)`. |
| **SC7-007 prompt injection durability** | PASS | `SystemPrompt.composed = partA + partB + partC`, all three are compile-time `static let` strings. User input enters only via `SystemPrompt.userTurn(...)` which is the user-turn payload, not the system prompt. `recentHistoryCompressed` is compressed log content (not external input) and is also passed only as user-turn. |

Compliance summary: **all 7 controls PASS at the design / scaffold level.**
Findings H-01 and H-02 are not control failures per se — they are gaps
between spec and implementation that affect the **defense-in-depth**
posture; they should be closed before video shoot.

---

## 5. Day-1 verification gates (must run before video shoot)

The following must execute and pass at Stage-5 day-1, in this order:

1. **Compute and commit canonical Gemma SHA-256.**
   - Run `_scripts/compute-model-hashes.sh` (per `model-integrity.md` §2).
   - Update `ModelIntegrity.expectedSHA256` const.
   - Update `runs/2026-05-05-spec/spec/MODEL_HASHES.json` (currently
     missing — create it).
   - Closes L-01.

2. **Bundle weights into `Resources/models/`** and switch to
   `useBundledWeights = true` codepath in `GemmaService.loadModel()`.
   - Update `SETUP.md` to remove HF Hub download instructions.
   - Closes H-01.

3. **Implement `EgressBlockingProtocol` and register at app launch.**
   - Wire counter into `OfflineProofBadge` (M04 design-approved.json).
   - Closes H-02.

4. **Create `.gitleaks.toml` at repo root** with the spec-mandated rules
   (Apple App-Specific Password regex; PEM PRIVATE KEY regex; plus
   sensible defaults: GitHub PAT, OpenAI key).
   - Re-run `gitleaks detect --no-banner --source . --config .gitleaks.toml`
     locally; confirm no findings.
   - Add `.gitleaks.toml` to `.github/workflows/ci.yml` step 4 (the file is
     loaded by default if present at repo root, but explicit `--config`
     in the CI step makes the contract clear).
   - Closes M-03.

5. **Track `Package.resolved`.**
   - Remove the entry from `.gitignore`.
   - `git add packages/SocraticEngine/Package.resolved` and commit.
   - Closes M-02.

6. **Wire the strings-scan into CI** (`network-test-plan.md` §1 Layer 2):
   ```sh
   strings -a HeWasSocrates.app/Contents/MacOS/HeWasSocrates | \
     grep -E "(sentry\\.io|datadoghq|mixpanel|segment\\.io|amplitude\\.com|crashlytics|firebase|appcenter)" \
     && exit 1
   ```
   Closes the I-01 sub-finding.

7. **Live `nettop` recording during 5-minute session** (`network-test-plan.md`
   §1 Layer 4). Save the recording as evidence; expected: 0 bytes.

8. **Codesign + entitlement grep** (`network-test-plan.md` §1 Layer 1):
   ```sh
   codesign -d --entitlements :- ./HeWasSocrates.app | \
     grep -q "network\\.client\\|network\\.server" && exit 1
   ```

9. **Pre-commit hook installed** (M-04 remediation). Optional for
   pre-release but recommended.

---

## 6. Ship recommendation

**Ship-or-block: SHIP, conditional on H-01 and H-02 closing before
video shoot.** None of the findings are release-blockers in the strict
sense — the App Sandbox + ATS already enforce the no-egress invariant
even with H-01 / H-02 unresolved. But the demo-day on-camera proof and
the credibility of the "0-byte egress" claim depend on:

- (a) the bundle not attempting to download weights at runtime (H-01), and
- (b) the OfflineProofBadge "Blocked: 0" counter working (H-02).

If those two are not closed by video-shoot, the demo evidence is weaker
even though the security posture is fine.

The medium findings (M-01 build-script eval, M-02 lockfile, M-03
gitleaks config, M-04 pre-commit) are post-ship maintenance items and do
not affect the user-facing security model.

---

## 7. Sign-off

**Auditor:** security-engineer agent (Claude Opus 4.7, 1M context)
**Audit completion:** 2026-05-05 KST
**Files written:** this report only. No application code modified.
**Review status:** initial pass; recommend re-audit at Stage-5 day-1
exit gate to confirm H-01, H-02, L-01 closure.
