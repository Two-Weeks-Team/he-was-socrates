# Triage — Iteration 1 (SpecDD pre-author cluster)

**Run:** `2026-05-05-spec`
**Authored by:** SPEC_LEAD
**Authored at KST:** 2026-05-05T15:55+09:00
**Profile:** standard (max 3 author⇄critic iterations, +1 if blockings strictly decreasing, cap 4)
**Input universe:** 128 findings (36 blocking · 49 high · 30 medium · 13 low) across 7 critic JSON files

---

## 1. Author-mind contract decisions (locked here, ratified in SPEC.md §1)

These are decisions SPEC_LEAD makes BEFORE author drafts so author has unambiguous targets. Each is a resolution of a cross-critic conflict or an open choice from the locked design.

| ID | Decision | Drives |
|----|----------|--------|
| **L1** | Canonical function-call contract format = **JSON Schema 2020-12** at `spec/function_call_contract.yaml`. OpenAPI 3.1 not used (no HTTP). SPEC.md §3 hyperlinks. | SC2-001, SC2-003, SC2-014 |
| **L2** | g2p primary engine = **AVSpeechSynthesizer phoneme delegate (PRIMARY)**, espeak-ng REMOVED entirely (GPLv3 ↮ Apache-2.0 + Mac App Store). This **reverses** `design-approved.json#design_tokens.viseme_set.g2p_engine_primary`. **USER ESCALATION (a)** — see §4. Author writes `spec/proposed-design-delta.json` documenting the swap. | SC7-002, SC4-006, SC6-18 |
| **L3** | M01 wording revised: 256K context = **architectural ceiling for compressed-recall**, NOT literal 256K live KV cache. Live context budget per turn = **32K tokens**. KV dtype = **INT8 minimum**. RAM ceiling = **≤ 7 GB peak on 16 GB Mac**. **USER ESCALATION (b)** — load-bearing demo claim, user must approve revised wording. Author writes wording delta to `spec/proposed-design-delta.json`. | SC6-03, SC2-008, SC5-01 |
| **L4** | Demo-day hardware tier = **REQUIRED MacBook Pro M2 Pro/Max OR Mac mini M2/M2 Pro OR Mac Studio (active cooling, ≥16 GB RAM)**. M2 Air = DEGRADED. M1 8 GB = UNSUPPORTED. **USER ESCALATION (c)** — user must commit to demo machine class. | SC6-02, SC6-06, SC6-14 |
| **L5** | Portrait provenance — Author writes `assets/socrates-portrait.PROVENANCE.md` STUB with three resolution paths (AI-gen / hand-drawn / public-domain). **USER ESCALATION (d)** — user must declare before freeze. Spec freezes WITH stub; substantive content blocks Mac App Store but not hackathon DMG (legal note in SPEC.md). | SC7-008 |
| **L6** | Sustainability partner (M12) — **USER ESCALATION (e)** — user must pick 1 of 4 named candidates. Spec accepts deferred-to-Writeup if user prefers; SPEC.md flags as TBD. | M12 mitigation, BP D3 |
| **L7** | Drift target = **≤ 30 ms RMS, peak ≤ 80 ms** (tightened from `idea.spec.json`'s 50 ms RMS, per SOURCE.md beard-occlusion + SC6-04). Per-segment for code-switched output (SC4-005); inter-segment gap ≤150 ms tolerated and labeled as deliberate pause. | SC6-04, SOURCE.md, SC5-10 |
| **L8** | Function-call streaming = `ask_back` returns `AsyncStream<TokenDelta>` with `{ delta: String, isFinal: Bool, sentenceBoundary: Bool, turn_id: UUID }`. TTS dispatched at first-sentence-boundary. SC5-10 mandates **caching the (text, voiceID, rate) → viseme timeline tuple** on Wonder for replay determinism. | SC2-002, SC5-10, SC6-07 |
| **L9** | `defer_to_human.trigger_category` enum = `legal\|medical\|financial\|welfare\|insurance\|emergency\|other` (UNION of `idea.spec.json#no_go` + `design-approved.json#function_call_schema`). Single source of truth = `function_call_contract.yaml`; SPEC.md normative. **Bypass-the-bust mode for `emergency`** (SC3-024) — full-screen hotline overlay (KO 1393, US-EN 988), NOT a Socratic question. | SC2-006, SC3-024, M07 |
| **L10** | Mode enum = `curious_adult\|learning_student\|skeptical\|unspecified` (renamed from `other`). `mode_classify.returns` adds `mode_raw: String` (Gemma's pre-normalization emission, for local replay diagnostics) and `mode_chip_pattern: String` (`disc\|diamond\|triangle\|circle`) for SC1-001 color-only differentiation fix. | SC2-007, SC1-001 |
| **L11** | Locale tags canonical = **BCP-47 everywhere** (`ko-KR`, `en-US`, `mixed`, `und`). Function-call `language` enum stays `ko\|en\|auto` for Gemma simplicity but Swift adapter resolves to BCP-47 BEFORE any Speech / AVSpeech call. Wonder.language persists ONLY BCP-47 (`auto` never reaches Core Data). Wonder gains `bcp47Locale: String` + `bcp47SecondaryLocale: String?`. | SC2-005, SC4-001, SC4-002 |
| **L12** | STT mixed-language strategy = **Strategy A — primary-locale recognition with code-switched-token tolerance**. KPI revised: `idea.spec.json`'s "STT accuracy on Korean+English mixed: ≥ 90% word accuracy" → **"primary-language word accuracy ≥ 90%, code-switched foreign tokens MAY be transliterated; Hangul-primary default unless user explicitly toggles"**. Push-to-talk (Space) is the demo-day default end-of-turn trigger (SC6-08). | SC4-003, SC6-08, SC3-011 |
| **L13** | Storage = **Core Data (locked, NOT SwiftData)**. Migration policy = lightweight only for v1.x; heavyweight gated by export-to-JSON-and-recreate flow. `AppMeta` singleton entity holds `schemaVersion: Int` + `appVersionAtLastMigration: String`. Backup-before-migrate to `.sqlite.pre-v{N}` mandatory. | SC5-04, SC3-013 |
| **L14** | Wonder.id = **UUIDv4 random** (uniqueness guaranteed). Dedup uses separate `contentFingerprint: String` (SHA-256 over normalized utterance + mode + bcp47Locale). Dedup policy = **`accumulate`** (always insert) for hackathon MVP simplicity; cross-link via `Wonder.relatedWonderIds: [UUID]` populated on `surface_past_wonder` recall. | SC5-01, SC5-08 |
| **L15** | Inference determinism: `mode_classify` and `defer_to_human` use **temp=0, seed=0**. `ask_back` and `surface_past_wonder` use **temp=0.7, top_p=0.9, seed=deterministic-hash(turn_id)**. Each Wonder persists `inferenceFingerprint: {modelSHA256, mlxSwiftVersion, temp, topP, seed}` for 14-month replay. | SC5-02 |
| **L16** | Error surface modality = **single centered overlay above bust, z-index above thought silhouette**, painterly frame, KO+EN copy, child-mode large-text variant. Bust NEVER speaks errors (stays in Socratic character). New tokens: `error_overlay_*`. | SC3-006 |
| **L17** | Reduce-Motion = **3-tier fallback**: Tier1 30fps full, Tier2 12fps + pulse off (existing), Tier3 static bust + caption-only (NEW; user toggle "Disable lip-sync"). Reconciliation note: user's mouth-sync requirement = default; a11y is fallback path. | SC1-008 |
| **L18** | Caption Policy = **default-on**, system-Live-Captions inheritance, Child-Mode forced-on (override impossible). Word-boundary highlight independent of caption toggle. | SC1-003, SC1-011 |
| **L19** | COPPA flow = **first-launch consent gate BEFORE microphone activation** (SC7-004). Auto-detection (`mode_classify` returning learning_student) acts as **safety override only** — if first-launch was Adult and auto-detect fires, app pauses, shows consent gate, PURGES just-collected utterance. Per-user consent flag stored in `AppMeta.consentSource: enum {self_adult, parent_direct_basic, parent_direct_strong, school_authorized, unset}`. MVP supports `self_adult` and `parent_direct_basic` (in-app form: name + date + consent text); MAS post-MVP reserves `parent_direct_strong`. | SC7-004, SC7-018, M08 |
| **L20** | Network egress = entitlement `com.apple.security.network.client = false` AND `com.apple.security.network.server = false` AND **NSURLProtocol shim** at launch trapping any URL request. CI gate: `codesign -d --entitlements :- ./HeWasSocrates.app \| grep -q network.client && exit 1`. | SC3-014, SC7-001 |

## 2. Cross-critic conflicts resolved

| Conflict | Resolution | Authority |
|---|---|---|
| SC1-008 wants Tier 3 (static, no lip-sync); SC6-04+SOURCE.md want tighter drift; user requirement = "lip-sync 필수" | All three honored: default = lip-sync (user req), drift target tightened to 30 ms RMS (SOURCE+SC6), Tier 3 a11y opt-out (SC1) | L7 + L17 |
| SC6-07 wants 16 ms crossfade (mask discontinuity on painterly portrait); design-approved locks `viseme_crossfade_ms: 0` | Author writes `spec/proposed-design-delta.json` proposing crossfade 16 ms. NOT a user escalation; design tokens were locked by SPEC_LEAD review and authority for delta is here. | SC6-07 |
| SC6-04 wants drift ≤ 30 ms (was ≤ 50 ms in `idea.spec.json#success_criteria`) | Author proposes delta to demo_day_metrics in `spec/proposed-design-delta.json` (idea.spec.json is locked input — delta-not-mutate per spec-lead constraints) | L7 |
| SC2-006 enum-drift (no_go vs trigger_category) | L9: union enum, single source = function_call_contract.yaml | L9 |
| SC4-001/SC4-002 BCP-47 vs ISO-639-1 + auto semantics | L11: layered (function-call simple + persistence canonical) | L11 |
| SC3-013 says "File Protection complete" is iOS-only and macOS doesn't have it; idea.spec.json claims it | Author replaces wording: macOS uses FileVault (user-level) + `NSURLIsExcludedFromBackupKey = true` for Application Support. Document in SPEC.md §11 with explicit Time Machine caveat (SC7-010). | SC7-010, SC3-013 |
| SC4-003 mixed-language KPI ≥90% unachievable with single SFSpeechRecognizer | L12: KPI revised; delta to demo_day_metrics in `proposed-design-delta.json` | L12 |
| SC5-02 wants temp=0 for replay; SC6-XX implicit "thoughtful" feel needs temp>0 | L15: split — classification temp=0, generation temp=0.7 (with seed determinism for replay) | L15 |
| SC1-001 wants mode_chip pattern differentiation; SC2-007 wants mode_raw field | L10: both — pattern token + mode_raw field | L10 |
| SC2-011 naming consistency wants `classify_mode` (verb-first); design-approved locks `mode_classify` | Author proposes rename in `proposed-design-delta.json`. NOT a blocking conflict; can be deferred or applied if delta approved. | medium — defer if user prefers stability |

## 3. Findings → action grouping

### 3.1 ACCEPT (resolved in iter-1 author draft)

**All blockings (36) accepted.** Each blocking maps to one or more of L1–L20 + author-side artifact creation:

- SC1 blockers (7): L10 (chip pattern), L18 (caption policy), L17 (Reduce Motion Tier 3), keyboard map, fullscreen exit invariant, VoiceOver routing, contrast variants — author writes SPEC.md §7 + design-tokens delta
- SC2 blockers (4): L1 (JSON Schema), L8 (streaming), error envelope, orchestration sequence — author writes `function_call_contract.yaml` + SPEC.md §3
- SC3 blockers (6): error catalog, TCC permissions, STT bootstrap, model integrity, install-time guards, error surface modality — author writes `error-catalog.md` + SPEC.md §8, §9
- SC4 blockers (4): L11 (BCP-47), L12 (mixed STT), TTS voice fallback, auto semantics split — author writes SPEC.md §10
- SC5 blockers (4): L14 (Wonder.id), L15 (determinism), L8 (correlation_id), L13 (migration) — author writes SPEC.md §6, `coredata-model.md`
- SC6 blockers (5): L3 (256K reframe), L4 (hardware tier), L7 (drift), launch state machine, TTFT phase diagram — author writes `performance-test-suite.md` + `demo-day-reliability.md` + SPEC.md §5
- SC7 blockers (6): L20 (entitlements), L2 (drop espeak-ng), Gemma TOU, L19 (COPPA VPC), TCC strings, L20 model integrity — author writes SPEC.md §11, `entitlements.plist.md`

**Highs (49): all addressed in iter-1 author draft** — no defer.
**Mediums (30): 22 addressed in iter-1, 8 deferred to TestDD or post-MVP** (see §3.2).
**Lows (13): 7 addressed in iter-1, 6 deferred** (see §3.2).

### 3.2 DEFER to TestDD or post-MVP

| Finding | Severity | Reason | Defer to |
|---|---|---|---|
| SC1-014 wondering log review UI a11y | medium | UI is post-MVP per `out_of_scope_v1`; SPEC.md §6 reserves Core Data fields (accessibilityNarrative, readingLevelGrade) so it isn't retrofit | post-MVP |
| SC1-016 focus_ring_color | low | Cosmetic; design tokens delta noted but not required for MVP demo | TestDD polish |
| SC2-011 function naming consistency (mode_classify → classify_mode) | medium | Stylistic; mass-rename costs > consistency benefit at v1.0 | post-MVP v1.1 (semver minor with alias) |
| SC2-015 AppleScript .sdef declaration | low | Vacuously absent in MVP; reaffirmed in SPEC.md §11 External Surfaces | covered by §11 negative declaration |
| SC3-018 MAS 4 GB binary size | medium | Not MVP-blocking (DMG primary); ODR plan for MAS post-MVP | post-MVP |
| SC4-013 video bilingual closer | medium | Video script artifact; SPEC.md §13 codifies bilingual policy; actual subtitle bake is video-production task | video shoot week 2 |
| SC4-014 App Store Connect metadata | medium | Post-MVP per `idea.spec.json#distribution.secondary_planned` | MAS submission |
| SC4-018 canonical translations | low | SPEC.md §10 establishes the table with seed entries; expansion ongoing | continuous |
| SC6-19 demo-day reliability checklist | low (note: critic mis-rated; impact is high) | Author produces `demo-day-reliability.md` in iter-1 — actually NOT deferred | iter-1 |
| SC7-019 auto-update / Sparkle | low | Affirmatively absent in MVP; SPEC.md §11 declares no-Sparkle | covered |
| SC7-020 egress proof methodology | low | Author produces `network-test-plan.md` in iter-1 — NOT deferred | iter-1 |
| SC7-021 logging hygiene | low | SPEC.md §11 lint rule + redaction policy — NOT deferred | iter-1 |

### 3.3 ESCALATE to user (5 items, pre-flighted as a single batch per Claude main-thread instruction)

| # | Question | Default if no answer | Blocks freeze? |
|---|----------|---------------------|----------------|
| **(a)** | Confirm reversal of `design-approved.json#design_tokens.viseme_set.g2p_engine_primary` from `espeak-ng` → `AVSpeechSynthesizer phoneme delegate (primary)`. Rationale: GPLv3 ↮ Apache-2.0 + Mac App Store (SC7-002). | Apply reversal; ship hackathon DMG with phoneme delegate; fall back to compiled-in IPA dictionary for ko-KR if delegate emits engine-specific phonemes. | YES if user objects to reversal — non-reversal forces a different distribution model (DMG-only, no MAS) which contradicts `idea.spec.json#distribution.secondary_planned`. |
| **(b)** | Confirm M01 wording change: "256K context — multi-year wondering log compression and selective injection" → "256K context CAPABILITY enables long-summary recall via `surface_past_wonder`; live context window cap = 32K tokens; older entries compressed to ≤200-char summaries via SemanticTag clusters." Rationale: SC6-03 RAM math shows literal 256K KV cache is infeasible on consumer M-series. | Apply wording change; M01 ablation evidence reframed accordingly in SPEC.md. | YES — load-bearing demo claim, user must approve. |
| **(c)** | Commit demo-day machine: REQUIRED tier (M2 Pro/Max MBP, Mac mini M2/M2 Pro, Mac Studio) vs DEGRADED (M2 Air). | REQUIRED tier; SPEC.md §5 Hardware Matrix codifies; M2 Air relegated to DEGRADED with TTFT margin warning. | NO — spec freezes either way; demo-day prep instruction differs. Recommend user commit before video shoot (W2). |
| **(d)** | Portrait provenance for `assets/socrates-portrait.png`. Three valid resolutions: AI-generated (log generator + prompt + license), hand-drawn (artist + license), public-domain (museum URL + access terms). | Spec freezes with `PROVENANCE.md` stub flagging UNKNOWN; SPEC.md §11 includes a hackathon-DMG-only carve-out + Mac App Store submission BLOCK until resolved. | NO for hackathon demo (user can declare verbally on demo day or in Writeup); YES for Mac App Store submission. |
| **(e)** | Sustainability partner (M12). Pick 1: Khan Academy 한국지부 / OER 공동체 / 한국교총 / KAIST AI 교육연구센터. | SPEC.md notes "TBD before submission deadline 2026-05-19"; Writeup author selects. | NO — Writeup deliverable, not spec deliverable. |

**Escalation decision rule:** SPEC_LEAD proceeds with iter-1 author draft applying defaults (a)–(e). SPEC.md and `proposed-design-delta.json` annotate every default. User can override at iter-2 or freeze; spec lock-hash recomputes if user changes any default before freeze.

## 4. Iteration-1 deliverables manifest (what author writes)

```
runs/2026-05-05-spec/spec/
├── SPEC.md                              # ≥10 sections, master narrative
├── function_call_contract.yaml          # JSON Schema 2020-12, 4 functions
├── error-catalog.md                     # NSError domain × code × KO/EN copy × adult/child variant
├── coredata-model.md                    # Wonder, SemanticTag, Session, AppMeta + migration policy
├── data-flow-diagram.md                 # Microphone → STT → Gemma → TTS → Core Data, M08 COPPA explicit
├── performance-test-suite.md            # TTFT phases, drift RMS measurement, frame-pacing methodology
├── demo-day-reliability.md              # 14-item pre-flight checklist
├── phoneme-viseme-map.json              # KO + EN IPA → 16-viseme, fallback chain
├── entitlements.plist.md                # required-true / prohibited entitlements + Hardened Runtime
├── network-test-plan.md                 # OfflineProofBadge engineering proof
├── model-integrity.md                   # SHA-256 weights + bundle layout
├── proposed-design-delta.json           # design-approved.json deltas (M01 wording, g2p swap, drift, crossfade, mode enum)
├── lock.sha256                          # produced at freeze
└── freeze-summary.md                    # produced at freeze
```

## 5. Author iteration-1 boundaries

- Apply ALL L1–L20 decisions verbatim.
- Cite each finding ID in inline comments where addressed.
- Where finding requires `design-approved.json` mutation, write to `proposed-design-delta.json` instead (per SPEC_LEAD constraint: do not mutate locked artifacts).
- All ISO 8601 timestamps include `+09:00`.
- Use BCP-47 everywhere user-facing locale appears.
- All KO+EN strings authored as TODO-free seed copy (no "TBD localized later"); SC4 critic round-2 will refine wording.

End of triage.
