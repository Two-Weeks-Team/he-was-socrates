# User Ratifications — Post-Freeze (2026-05-05 KST)

Spec-lead applied 5 defaults at freeze time and queued them for user judgment.
This file records the user's actual decisions so TestDD / scaffold inherit a
single source of truth (not the speculative defaults inside
`spec/proposed-design-delta.json`).

| ID | Subject | Default applied | User decision (2026-05-05) | Status |
|---|---|---|---|---|
| (a) | SC7-002 license — espeak-ng GPLv3 vs Apache-2.0+MAS | drop espeak-ng → AVSpeechSynthesizer phoneme delegate primary | **Approved (drop)** | ✅ ratified |
| (b) | M01 "native 256K context" wording | reframe to "compressed multi-year recall" | **Approved (reframe)** | ✅ ratified |
| (c) | Demo-day hardware tier | M2 Pro+, fan-cooled, plugged in | **Approved (M2 Pro+)** | ✅ ratified |
| (d) | Socrates portrait provenance | UNKNOWN stub (MAS-blocker) | **AI 생성 (generator+prompt+date pending)** | ⏳ partial |
| (e) | M12 sustainability partner | TBD stub | **REJECTED by user** — "이건 무시해도 됩니다. 해커톤의 목적과 정합하지 않습니다." | ✅ user override |
| (g) | Scaffold plan structure (Phase 0–5, 13 days) | proposed | **Approved (Recommended)** | ✅ ratified |
| (h) | Asset-authoring path (A hand / B halftone / C shader) | recommended B | **Approved (B halftone-derived)** | ✅ ratified |
| (i) | Persist source portrait at `assets/source-portrait.png` | needed for B | **Yes** (uploaded 2026-05-05 16:20) | ✅ ratified |
| (j) | VISEME_DIMS revision (IH/F/V/TH/REST per research §7.2) | research recommendation | **Approved (apply all)** | ✅ ratified |
| (k) | Korean phoneme map delta (ㅓㅕㅝ → UH, ɾ → S, +ㅘ diphthong) | research §7.3 | **Approved (apply all)** | ✅ ratified |
| (l) | OSS build-time tools (Rhubarb MIT + g2pK Apache-2.0) | research §7.7 | **Approved (both)** | ✅ ratified |
| (m) | SPEC.md §4.3 API correction (phoneme delegate → marker stream) | research §7.1 CRITICAL | **Approved (delta document, no SHA recompute)** | ✅ ratified |

## (f) Image = visual-direction only (corrected 2026-05-05 KST)

**Earlier in this session I (Claude) over-interpreted the user's pasted
Python+halftone+ASCII technical context as a stack pivot, and proposed
"Hybrid Swift-runtime + Python build-time-toolchain" with an
`asset-pipeline.md` and `SOURCE.md` rewrite. That was wrong-direction.**

The user clarified 2026-05-05: the attached painterly Socrates portrait is
*visual style direction* (one REST-viseme rendered in the desired aesthetic),
not a runtime asset, not a stack pivot. The 15 other visemes still need to
be authored, and the runtime still swaps PNGs at 30fps per locked spec.

**Canonical position (post-correction):**
- **Runtime stack = Swift + SwiftUI + MLX-Swift, unchanged from frozen SpecDD.**
- **Image = visual-direction reference for scaffold (Stage 5) art authoring.**
- **Asset-authoring path = decision deferred to scaffold-plan (3 options below).**
- **SHA lock `e5dfadf2…314c5` = unchanged. No iter-3 amendment.**

### Asset-authoring options (to be picked at scaffold time)

| Option | Path | Time cost | Fidelity | Reproducibility |
|---|---|---|---|---|
| A | Hand-authored 16 painterly PNGs (Procreate/Photoshop, manual) | 1-2 days art | highest | not reproducible |
| B | Halftone-derived REST PNG (Python from source portrait) + procedural 15 mouth-shape variants (overlay/affine in Swift or Python) | 1-2 days dev | medium-high | deterministic |
| C | Hand-authored REST PNG (one viseme, traced from portrait) + Metal-shader mouth deformation at runtime (16 variants generated on-the-fly) | 2 days dev | medium-high | runtime-dynamic |

User has not yet picked. Propose to revisit at scaffold start.

### Files I (Claude) over-wrote during the misinterpretation

- `spec/asset-pipeline.md` — to be DEMOTED to "asset-authoring options
  reference, not a contract". See `spec/scaffold-plan-proposal.md` for the
  authoritative plan.
- `runs/2026-05-05-spec/assets/SOURCE.md` — the "NOT runtime asset" framing
  added at correction time will be reverted; visual-brief role is restored.

## (e) M12 override — implications

User explicitly rejected the BP D3 mitigation (named sustainability partner)
as misaligned with the hackathon's purpose. This is a deliberate scope cut,
not an oversight. Implications for downstream artifacts:

- **`design-approved.json#mitigation_adopted_full[11]` (M12)** — must be
  marked `status: "rejected_by_user_2026-05-05"` with rationale: hackathon
  judging emphasizes storytelling + technical demo, not commercial viability
  validation; named-partner pursuit would consume W2 time better spent on
  video shoot + Writeup polish.
- **Writeup §Business / Sustainability** — should *acknowledge* the absence
  of a named partner explicitly with the framing: *"this is a research /
  educational artifact, Apache-2.0 + on-device, distributed as a
  free DMG. Sustainability path is OSS community + Mac App Store free tier,
  not enterprise procurement."* This converts a missing-partner risk into a
  positioning choice.
- **BP D3 dissent** — moves from "unmitigated" to "consciously declined".
  Risk of judge bringing this up in Q&A — prepare a 1-line answer:
  *"우리는 이걸 즉시 상품화할 의도가 없습니다. on-device 오픈소스 도구로,
  교육 커뮤니티가 자유롭게 가져다 쓸 수 있는 형태로 출시합니다."*
- **TestDD / scaffold** — no impact. M12 was a Writeup/positioning concern,
  not a code/spec concern.

## (d) Portrait provenance — partial

User confirmed: **AI 생성**. Pending detail:
- Generator (Midjourney / DALL·E / Stable Diffusion / Sora / 기타)
- Prompt (verbatim, for reproducibility per M02 compound-risk hygiene)
- 생성 날짜 (KST)
- 후처리 여부 (배경 투명화, 색상 조정, 등)

Once received, update `assets/socrates-portrait.PROVENANCE.md` and clear
the `MAS-blocker` flag.

## Implications of (a) (b) (c)

- **(a) espeak-ng drop**: `design-approved.json#design_tokens.viseme_set.g2p_engine_primary`
  becomes `"AVSpeechSynthesizer phoneme delegate"` (was `"espeak-ng"`). The
  fallback line should reverse: espeak-ng removed entirely; if AVSpeech
  delegate fails, the spec must declare a third fallback (recommend:
  pre-computed dictionary lookup for top-N most common Korean+English words,
  embedded in app bundle). SC4 i18n, SC2 api_design must verify in TestDD.
  Mac App Store path is now open.

- **(b) 256K reframe**: M01 mitigation text and demo-video script narration
  both change. Updated phrase: *"compressed multi-year recall — Gemma's
  long-context capability, surfaced through anonymous summarization rather
  than literal full-token replay"*. RAM ceiling stays at ~5GB (model + KV
  cache for working window of 32K-64K), well within the 16GB demo machine
  envelope. M01 ablation table in SPEC.md must be revised to reflect this:
  the load-bearing claim is *long-horizon recall*, not *literal 256K
  attention*.

- **(c) M2 Pro+ committed**: `demo-day-reliability.md` REQUIRED tier wording
  is canonical. M1 / M2 Air = unsupported for demo. SPEC.md §11 (hardware
  matrix) must explicitly mark M1 8GB and M2 Air as "user can install but
  demo-day claims do not apply." Backup demo machine must also be M2 Pro+.

## Pending (d) — portrait provenance

User has not yet declared the license/origin of the attached Socrates
illustration. App Store submission requires this. See
`/Users/kimsejun/Documents/GitHub/he-was-socrates/runs/2026-05-05-spec/assets/socrates-portrait.PROVENANCE.md`
for the form spec-lead pre-filled. User to supply: generator + prompt + date
(if AI-generated), OR artist + license (if hand-drawn), OR licensor +
license link (if stock).

## Pending (e) — M12 sustainability partner

User asked for clarification of what "sustainability partner" means.
Re-ask scheduled. See main-thread conversation.
