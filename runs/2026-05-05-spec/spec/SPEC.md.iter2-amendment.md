# SPEC.md — Iteration-2 Amendment

**Authored:** 2026-05-05T17:15+09:00 (KST)
**Purpose:** Apply 7 round-2 critic minor findings as a single coherent patch on top of iter-1 SPEC.md. Each amendment is additive and points to its target SPEC.md section. The freeze hash includes both SPEC.md and this amendment.

---

## A1. SPEC.md §7.4 — Typed-utterance discoverability hint (resolves SC1-NEW-001)

ADD at end of §7.4:

> **Discoverability:** when VoiceOver is detected (`NSWorkspace.shared.isVoiceOverEnabled`) OR on first-launch fullscreen entry, render a discoverable on-screen hint near the caption area:
> - KO: "스페이스 키로 말하기, Cmd+Enter로 입력하기"
> - EN: "Press Space to speak, Cmd+Enter to type a question"
>
> Hint persists for 8 seconds OR until first user action (whichever comes first). Settings > Accessibility lists all keyboard shortcuts as a permanent reference.

## A2. SPEC.md §8 — Emergency overlay a11y (resolves SC3-NEW-001)

ADD at end of §8 modality matrix discussion:

> **Emergency overlay (`overlay_emergency_full_screen`) a11y semantics:**
> - SwiftUI role: `role(.alert)` (analog of NSAccessibilityRole.alert).
> - On appear: `NSAccessibility.post(notification: .announcement, value: "Emergency. Call 1393 in Korea or 988 in the US for support.", priority: .high)`.
> - The hotline number is rendered as **selectable text** (Cmd+C copyable) for non-vocal users to paste into Phone app.
> - The overlay does NOT auto-dismiss; user must explicitly choose "OK" / "확인" or "Call" / "전화" or "Cancel" / "취소".
> - "Call" launches `tel:1393` or `tel:988` URL via `NSWorkspace.shared.open(URL)` — exempt from network egress restriction since `tel:` is a system-handled URL scheme that does not initiate HTTP. Document in network-test-plan.md as an explicit allowance.

## A3. SPEC.md §10.4 — AttributedString locale runs (resolves SC1-NEW-002 + SC4-NEW-001)

ADD at end of §10.4:

> **Per-run locale attribution:** `AttributedString` runs MUST carry `.languageIdentifier` per-run (BCP-47 string). SwiftUI `Text` rendering uses this attribute for both:
> 1. **VoiceOver pronunciation:** mid-string voice swap (e.g. quoted Korean inside English caption).
> 2. **Font fallback selection:** ensures the Korean serif fallback (AppleMyungjo / Noto Serif CJK KR) is selected for Hangul ranges and the Times New Roman family for Latin ranges within the same caption.
>
> `Wonder.socraticReplyDisplayText` and `surface_past_wonder.connector_phrasing` MUST be rendered via this AttributedString builder, never as a flat String.

## A4. SPEC.md §3.4 — Streaming envelope-vs-stream-item relationship (resolves SC2-NEW-001)

ADD at end of §3.4:

> **Streaming and terminal envelope relationship:** `ask_back` emits `TokenDelta` items WITHOUT envelope wrapping during streaming. On `isFinal: true`, the orchestrator additionally emits ONE final `Envelope` wrapping the concatenated `response_terminal` data shape (text, language_resolved, sentence_count, word_count). Consumers awaiting the final envelope can `await` the orchestrator's `terminalEnvelope` future; consumers feeding TTS subscribe to the stream and act on `sentenceBoundary: true` boundaries.

## A5. SPEC.md §11.7 + data-flow-diagram.md — Diagnostics redaction on auto-detect-purge (resolves SC3-NEW-002)

ADD to SPEC.md §11.7 (and mirror in data-flow-diagram.md §2):

> **Auto-detect-purge atomicity scope:** when the safety-net override fires (Adult-flag user but `mode_classify` returns `learning_student` with confidence ≥ 0.6 + child-utterance heuristic), the orchestrator:
> 1. Discards Core Data context (no Wonder row written) — atomic.
> 2. Rotates the diagnostics file (`~/Library/Application Support/.../diagnostics/attempts-{date}.log`) and **redacts in-place all entries within the last 60 seconds with a matching `turn_id`**: utterance text replaced with `<redacted-coppa-purge>`, retain only timestamp + turn_id + function name for engineering audit. Same redaction rule applies to in-memory function-call attempt buffers.
> 3. Purges any partial audio file in `audio/{turn_id}.m4a.partial`.
> 4. Resets `mode_classify` cache for that turn_id.
>
> The redaction is auditable: `attempts-{date}.log` shows the entries existed but with content redacted, satisfying COPPA "no retention of child PII without consent" while preserving engineering-debug capability.

## A6. coredata-model.md §1 — Embedding cache regenerability (resolves SC5-NEW-001)

ADD to coredata-model.md §1 storage layout:

> **embedding-cache/ regenerability:** the `embedding-cache/` folder is REGENERATABLE from Wonder rows. On cache miss, corruption, or absence after migration, the orchestrator regenerates by re-embedding all extant `Wonder.userUtterance + " || " + Wonder.socraticReply` content via NLEmbedding (Apple system, Apache-2.0). Regeneration is:
> - **Idempotent:** re-running on already-cached entries is a no-op (cache key = `Wonder.id`).
> - **Bounded:** time complexity O(N) where N = Wonder count; budgeted at ≤ 5 ms per entry on M2 → 1000-row log regenerates in ≤ 5 s, hidden behind a one-time progress overlay.
> - **Sandbox-safe:** all in-process, no model file outside bundle, no network.

## A7. SPEC.md §3.3 — ask_back stall fallback to surface_past_wonder (resolves SC6-NEW-001)

ADD to SPEC.md §3.3 step 7:

> **Stall fallback:** if `ask_back` exceeds the soft-timeout (15 s on M2/M3, 25 s on M1) BEFORE emitting first sentence boundary AND `surface_past_wonder` has returned a non-empty `connector_phrasing`, the orchestrator emits `connector_phrasing` as a STANDALONE utterance to maintain conversational presence. `ask_back` continues with an additional 30 s grace before hard-timeout (45 s total). On hard-timeout, abort and surface `Model.InferenceTimeout.Hard` per error-catalog.md.

---

## A8. Verification

This iteration-2 amendment closes the 7 minor (1 high, 4 medium, 0 low + 2 cross-overlapping) findings raised at iter-1 round-2 critics. All targeted findings are now `resolved` rather than `documented-deferred`. The combined SPEC.md + this amendment is the freeze input.

| Finding | Status after A1-A7 |
|---|---|
| SC1-NEW-001 typed-utterance discoverability | A1 resolves |
| SC3-NEW-001 emergency overlay a11y | A2 resolves |
| SC1-NEW-002 / SC4-NEW-001 / SC4-009 AttributedString locale | A3 resolves |
| SC2-NEW-001 streaming envelope clarification | A4 resolves |
| SC3-NEW-002 diagnostics redaction on COPPA purge | A5 resolves |
| SC5-NEW-001 embedding cache regenerability | A6 resolves |
| SC6-NEW-001 ask_back stall fallback to surface_past_wonder | A7 resolves |
