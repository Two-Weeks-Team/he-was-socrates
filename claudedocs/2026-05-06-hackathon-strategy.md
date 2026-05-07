# He Was Socrates — Hackathon Strategy & /pf:new Context Pack

**작성일**: 2026-05-06 (최신 갱신 2026-05-07)
**마감**: 2026-05-19 08:59 KST (D-12 from 2026-05-07)
**확정 결정 (2026-05-07 §11.5)**: 카테고리 Impact 1순위 + Technical 2순위 / Option C / PR #33 머지 가정 / 영어 우선 + 한국어 병기
**현재 main**: `3f02a34` (PR-Λ disk-mediated KV cache, ~192 ms TTFT)
**진행 중 PR**: #33 `feat/firstlaunch-ux-tier-b` — 첫 실행 UX 전면 개선 (양언어 + macOS 26 floor)

> 이 문서는 `/pf:new` 진입 직전에 정리한 **컨텍스트/목표/룰 패키지**다. PreviewDD cycle이 의미 있는 산출물(데모 preview / 발표 자료 / Kaggle 페이지 자산)을 만들도록 평가자 관점의 narrative와 제약 조건을 명시한다.

---

## 1. Hackathon Context

### 1.1 The Gemma 4 Good Hackathon (Kaggle / Google DeepMind)

| 항목 | 값 |
|---|---|
| 총 상금 | **$200,000** (3 카테고리에 분배) |
| 마감 | 2026-05-19 08:59 KST (= UTC 2026-05-18 23:59) |
| 평가 가중 | impact + technical execution + clear use-case communication |
| 강조 항목 | **social impact / multimodal + function calling / constrained environments** |
| 문제 영역 | **health / education / climate** (3개 중 하나 선택) |
| 카테고리 | **General / Impact-focused / Technical** (3개 부문) |
| 제출 요구 | working demo + 공개 repo + technical write-up + ≤3분 데모 영상 |

### 1.2 He Was Socrates 적합도

| 평가 기준 | 우리 자산 | 점수 |
|---|---|---|
| Constrained environments | NO-CLOUD invariant, 100% on-device Gemma 4 E4B 4-bit MLX, on-device STT/TTS | 🟢 매우 강함 |
| Function calling | 4개 함수 dispatch (`mode_classify` / `surface_past_wonder` / `ask_back` / `defer_to_human`) — architecture의 핵심 | 🟢 매우 강함 |
| Multimodal | 음성 in/out + 시각적 viseme + 1-bit halftone bust | 🟡 보통 (텍스트 모드 미사용) |
| Long context (256K) | wondering log 다년 회상 (`surface_past_wonder`) | 🟢 강함 |
| Configurable thinking mode | `Phase.thinking` 동안 흉상 soft pulse 시각화 | 🟢 강함 |
| Social impact | 한국어 사용자 대상 소크라테스식 학습 도구 + 안전 abstention | 🟢 강함 (education) |
| Real-world use | macOS native fullscreen, 비기술 사용자 대상 첫 실행 UX | 🟡 (PR #33 머지 후 강해짐) |

### 1.3 Problem Area 선택: **Education**

- 소크라테스 대화법(maieutics)은 교육의 원형
- 한국어 학습자에게 평어체 톤의 Gemma 4가 사고의 산파 역할
- defer_to_human이 안전한 학습 경계를 만듦 (의료/법률/금융/응급/복지/보험 영역으로 빠지지 않음)
- 부수적: mental health 영역의 안전한 대화 (defer_to_human이 health에도 부분 부합)

---

## 2. Goal (수상 시나리오)

### 2.1 1순위 타깃: **Impact-focused 카테고리 (Education)**

**Narrative**: "AI 시대에 사람이 사람에게 묻는 법을 잃지 않도록, 소크라테스가 평어체 한국어로 다시 묻는다. 모든 대화가 사용자 기기 안에서만 일어나며, AI가 답할 수 없는 영역(의료/법률/금융/응급)은 솔직하게 사람에게 위임한다 — 'abstention as product'."

**평가자 어필 요소** (Impact / Education):
- **소크라테스 maieutics를 학습 도구로 재구성** — answering machine을 만드는 흔한 LLM 데모와 정반대로, 묻는 법을 가르치는 도구
- **defer_to_human 메커니즘** — 의료/법률/금융/응급/복지/보험 영역 자동 거절. AI 안전성을 회피가 아닌 honest product mechanic으로
- **한국어 단정한 평어체** — 한국어 학습자에게 영어 LLM 데모와 정체성 있는 차별화. 친근한 챗봇이 아닌, 사고의 산파 톤
- **Wondering log** (Phase 4 wiring 기반) — 학습자의 다년 사유 흐름이 사용자 Mac 밖으로 절대 나가지 않음
- **Privacy-first education** — 학생/학습자가 망설임 없이 솔직하게 묻는 환경 (대화가 외부로 새지 않음)
- **모든 학습자에게 동일하게 동작** — 인터넷 연결 / 클라우드 구독 / API 키 불필요

### 2.2 2순위 타깃: **Technical 카테고리**

**Narrative**: "$3.97 GB Gemma 4 E4B 4-bit를 100% on-device, NO-CLOUD invariant 안에서 구동하면서 PR-Λ disk-mediated KV cache reuse로 TTFT를 4.6 s → 192 ms (24×)로 줄였다. 부가 entitlement 0개, 외부 API 콜 0개, 평가자 PC 안에서만 동작 — Impact 위주 narrative를 떠받치는 엔지니어링 증거."

**평가자 어필 요소** (Technical):
- 측정 가능한 기술 성과: 192 ms TTFT, ~800 ms per-turn decode
- Constrained environment 정의의 교과서적 사례 (Apple Sandbox + zero network egress)
- Function calling 활용도 — 4개 함수의 abstention dispatch가 product의 핵심
- Apple Silicon MLX 최적화 (Apple platform 네이티브 통합)
- Pre-flight UX (PR #33) — macOS 26 `AssetInventory` API 적극 채택

### 2.3 차별화 포인트 (다른 출품작 대비)

| 차별화 | 왜 다른가 |
|---|---|
| **The Abstention Mechanic is the Product** | 대부분 LLM 데모는 "더 잘 답하기" 경쟁. 우리는 "솔직하게 못 답한다"가 1급 기능. |
| **Korean 단정한 평어체 lock** | system prompt verbatim, 톤 변경 금지. 한국어 학습자에게 정체성 있는 대화. |
| **1-bit halftone aesthetic** | 흔한 photoreal AI avatar / 챗봇 UI 거부. 시각적 일관성. |
| **Zero bytes leave the device** | demo 도중 비행기 모드 켜도 동작. 평가 영상의 강력한 비주얼. |
| **PR-Λ 24× TTFT 개선** | bench JSON 공개 (`claudedocs/bench/`). 측정 가능. |
| **Configurable thinking mode 시각화** | `Phase.thinking` soft pulse — Gemma 4 신 기능을 UX surface로. |

---

## 3. Rules (Frozen Invariants — 절대 변경 금지)

CLAUDE.md absolute invariants 발췌 + 본 핵카톤 작업에 적용:

### 3.1 Code-level invariants
1. **Zero bytes leave the device** — `network.client` / `network.server` entitlement 추가 금지. STT는 `requiresOnDeviceRecognition = true`. HuggingFace Gemma 가중치 다운로드만 sanctioned (OS-mediated MLX 캐시 경유).
2. **Korean tone locked to 단정한 평어체** — `Sources/SocraticEngine/Gemma/SystemPrompt.swift` verbatim, 사용자 작성. 변경 금지.
3. **No photoreal lip-sync** — 1-bit halftone PNG swap만. SadTalker / Audio2Face 류 제외.
4. **`runs/2026-05-05-spec/` read-only** — 변경은 새 `iter<N>-<topic>.md` delta 문서 추가만. 기존 파일 수정 금지.
5. **`.env` 미수정** — 사용자 명시 지시 없이는.
6. **`EngineCoordinator.Phase` 안정 surface** — case 추가 = SpecDD delta.

### 3.2 Product invariants
1. **defer_to_human은 product** — 의료/법률/금융/응급/복지/보험 영역에서 abstention. "improve into answering machine" 금지.
2. **Gemma 4 E4B 4-bit MLX variant 고정** — 다른 모델 변경 금지.
3. **PRIMARY/JamoTimeline lip-sync** — `SPEC.md.iter5` per Apple phoneme markers empirically absent.

### 3.3 Submission/Workflow invariants
1. **`make ci-local` before push** — 모든 변경.
2. **Conventional Commits** — `type(scope): description` with scopes from `{engine, viseme, audio, gemma, app, scripts, ci, docs, spec}`.
3. **`gh pr merge --merge`** (squash 금지, history 보존). Conflict 시에만 `--rebase`.
4. **AI-assisted commits** — `Co-Authored-By:` trailer 포함.
5. **Apple Developer Program $99** — 이미 enrolled (사용자 확인).

---

## 4. Submission Artifact 분담 현황

| 산출물 | 담당 | 상태 |
|---|---|---|
| Working demo (.app DMG, notarized) | 다른 팀원 | 진행 중 |
| 공개 코드 repo (GitHub Two-Weeks-Team/he-was-socrates) | 본인 (코드) | ✅ 가시 (현재) |
| Kaggle technical write-up ≤1500 words | 다른 팀원 | 미정 |
| YouTube demo video ≤3 min | 다른 팀원 | 미정 |
| Pre-flight UX (PR #33) | **이 세션** | 검토 대기 (상근님) |
| Hackathon strategy (이 문서) | **이 세션** | 작성 중 |
| **`/pf:new` cycle 산출물** (preview / 데모 자산) | **다음 세션** | 계획 |

---

## 5. /pf:new에 기대하는 산출물

PreviewDD cycle의 결과물로 다음 중 하나 또는 조합:

### 5.1 Option A — Kaggle 페이지 임베드용 인터랙티브 preview
- 스크롤 가능한 단일 HTML 페이지 (`claudedocs/preview-*.html` 류)
- 흉상 시뮬레이션 GIF/WebM + viseme 시퀀스 미리보기
- 핵심 메트릭 (TTFT 192 ms, 0 byte network egress, 4-function dispatch) 시각화
- defer_to_human 시연 시나리오 (의료 질문 → ⊘ 응답)
- 기술 stack diagram
- 평가 카테고리별 어필 표

### 5.2 Option B — 발표 영상용 슬라이드 (16:9)
- ~10–15장 슬라이드 HTML
- Section: Why / What / How / Demo / Metrics / Future
- ≤3 min 영상 narration script 포함

### 5.3 Option C — 두 가지 결합 + GitHub README 강화
- README hero section + 핵카톤 어필 섹션 추가
- 페이지에서 영상으로 deep-link

**제안된 default**: **Option C** (가장 큰 표면적 + 평가자 첫 인상 두 가지 (Kaggle 페이지 / GitHub repo) 모두 강화).

---

## 6. /pf:new 시작 시 제공할 압축 컨텍스트

```
Project: He Was Socrates
Tagline: 100% on-device Korean Socratic bust on macOS, powered by Gemma 4 E4B 4-bit MLX.

Hackathon: The Gemma 4 Good Hackathon (Kaggle/DeepMind)
Deadline: 2026-05-19 08:59 KST (D-13)
Target categories (priority): Impact-Education → Technical (general 보조)

Differentiators:
  - Zero bytes leave the device (NO-CLOUD invariant, no network entitlement)
  - The abstention mechanic is the product (defer_to_human)
  - Korean 단정한 평어체 system prompt locked
  - 1-bit halftone aesthetic, no photoreal lip-sync
  - PR-Λ disk-mediated KV cache: TTFT 4.6s → 192ms (24×)
  - 4-function dispatch: mode_classify / surface_past_wonder / ask_back / defer_to_human
  - macOS 26 SpeechAnalyzer + AssetInventory (PR #33)

Constraints:
  - 1-bit halftone only (no photoreal, no fancy AI avatars)
  - Korean tone verbatim ("단정한 평어체" — assertive 평어, neither 존댓말 nor friendly)
  - runs/2026-05-05-spec/ is frozen (deltas only)
  - All claims must be verifiable (bench/, code, commits)
  - No marketing superlatives ("blazingly fast", "100% secure")

Audience: Kaggle/DeepMind evaluators (technical-leaning) + general dev community on GitHub.

Inputs PreviewDD has access to:
  - Source code (~5500 LOC Swift, 100% on-device path)
  - claudedocs/2026-05-06-firstlaunch-ux-bestpractices.html (80KB best-practices report)
  - claudedocs/bench/ (PR-Λ latency benchmarks)
  - PR #33 first-launch UX walkthrough
  - 16 viseme PNGs + face_halftone.png (visual assets)
  - SPEC.md + iter2/4/5/6 deltas (frozen design)
```

---

## 7. /pf:new가 피해야 할 것 (anti-patterns)

1. **Marketing tone** — "blazingly fast", "혁신적", "unprecedented" 류 금지. 측정 가능한 숫자 + 증거.
2. **photoreal AI avatar mockups** — 1-bit halftone 미학 위반.
3. **Cloud architecture diagram** — 사실과 반대.
4. **English-only UI mockups** — 한국어 평어체 톤이 1순위.
5. **Photoreal lip-sync demo** — 16 viseme PNG swap만.
6. **Speculative features** — wondering log 다년 회상은 Phase 4 wiring (실제 구현은 stub). 이를 "as-shipped"로 표시 금지.
7. **잘못된 메트릭** — TTFT는 192 ms (PR-Λ verify-2 측정), 6 s가 아니다 (pre-PR-Λ baseline). 2 s 사용자 체감 (decode + STT endpoint + TTS prep).
8. **misattribution** — Gemma 4 = Google DeepMind (Apple 아님). MLX = Apple. mlx-swift-lm = Apple ML team.

---

## 8. /pf:new 첫 의사결정 (사전 가이드)

`/pf:new`가 묻거나 추론할 만한 결정 포인트와 우리의 답:

| 결정 | 답변 |
|---|---|
| 출력 layout | Scroll (긴 narrative) |
| Theme | Light (research 톤) 또는 Dark (제품 톤). **Dark + 단색 강조** 권장. |
| Audience | technical 평가자 1순위 + general dev 2순위 |
| Tone | 사실 기반 + 증거. Marketing 금지. 한국어/영어 혼용 가능. |
| Length | ~30–60 KB HTML (이전 보고서들과 일관) |
| Hero | 흉상 PNG (`assets/face_halftone.png`) + tagline |
| Metric cards | TTFT 192 ms · 0 byte egress · 4 function dispatch · 65 tests · macOS 26 floor |
| Section order | Hero → Why → What → How → Differentiation → Demo path → Metrics → Roadmap |
| Code snippets | Function-call YAML contract + Phase enum + AssetInventory call |
| 인용 출처 | Apple Developer (HIG, SpeechAnalyzer), WWDC25 #277, Kaggle/DeepMind Gemma 4, 본 repo의 verifiable commit |

---

## 9. Verification Gates (preview 산출 후)

`/pf:freeze` 또는 사용자 확증 전 다음 게이트 통과 확인:

- [ ] 모든 메트릭이 `claudedocs/bench/` 또는 `git log` 기준으로 검증 가능
- [ ] 1-bit halftone aesthetic 시각적 일관성
- [ ] 한국어 평어체 톤 일관성
- [ ] CLAUDE.md absolute invariants 위반 없음
- [ ] Kaggle 평가 기준 (impact / technical / clear use case) 모두 명시적 어필
- [ ] 카테고리 (Technical 1순위, Impact-Education 2순위) 명확히 표현
- [ ] PR #33 양언어 + macOS 26 floor 반영
- [ ] PR-Λ 192 ms TTFT 정확히 인용 (4.6 s baseline 대비 24×)
- [ ] No marketing superlatives
- [ ] 출처 인용 markdown hyperlink

---

## 10. 참고 자료 (PreviewDD가 읽을 자료들)

### 코드 / 사양
- `runs/2026-05-05-spec/spec/SPEC.md` (lock SHA `e5dfadf2c8…314c5`)
- `runs/2026-05-05-spec/spec/SPEC.md.iter*-*.md` (iter2/4/5/6 deltas)
- `runs/2026-05-05-spec/spec/function_call_contract.yaml`
- `Sources/SocraticEngine/Gemma/SystemPrompt.swift` (Korean 평어체 verbatim)
- `Sources/SocraticEngine/EngineCoordinator.swift` (Phase enum + turn loop)
- `apps/macos/HeWasSocrates/HeWasSocrates/Preflight.swift` (PR #33)
- `claudedocs/bench/2026-05-06-latency-bench.json` + `.log` (PR-Λ measurements)

### 보고서 / 문서
- `claudedocs/2026-05-06-firstlaunch-ux-bestpractices.html` (80 KB Apple-official-source-based)
- `claudedocs/2026-05-06-final-audit-merged-state-report.html`
- `claudedocs/2026-05-06-stack-comparison-research.html` (17-agent stack research)
- `CLAUDE.md` / `HANDOFF.md` / `CONTRIBUTING.md`

### 외부 자료
- [The Gemma 4 Good Hackathon — Kaggle](https://www.kaggle.com/competitions/gemma-4-good-hackathon)
- [Kaggle/Google DeepMind launch announcement](https://www.edtechinnovationhub.com/news/kaggle-and-google-deepmind-open-gemma-4-hackathon-focused-on-ai-skills-and-real-world-impact)
- [Gemma 4 Hackathon detail $200K prize pool](https://algo-mania.com/en/blog/hackathons-coding/gemma-4-hackathon-200000-to-create-ai-for-social-impact/)
- [Gemma 4 — Google DeepMind](https://deepmind.google/models/gemma/gemma-4/)
- [Apple HIG (Privacy / Progress Indicators / Onboarding)](https://developer.apple.com/design/human-interface-guidelines)
- [WWDC25 Session 277 — SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/)

---

## 11. /pf:new 시작 직전 사용자 확인 사항 (2026-05-07 확정 완료)

| # | 항목 | 확정 답 |
|---|---|---|
| 1 | 타깃 카테고리 우선순위 | **Impact-Education 1순위 + Technical 2순위** |
| 2 | 산출물 형태 | **Option C** (Kaggle preview HTML + GitHub README hero 패치) |
| 3 | PR #33 머지 가정 | **머지 가정** — 데모/스크린샷에 PreflightView, AssetInventory, macOS 26 floor 반영 |
| 4 | 카피 언어 비중 | **영어 우선 + 한국어 병기** (한국어 = 정체성 표현 영역에 한정) |
| 5 | 다른 팀원 산출물과의 조정 | 보류 — /pf:new 결과 본 후 사용자가 팀원과 소통 |
| 6 | 외부 입력 가정 | Kaggle 평가자 영어 audience: Gemma 4 / function calling 알고 있음, NO-CLOUD / defer_to_human / 단정한 평어체는 설명 필요 |

---

## 12. /pf:new 입력 프롬프트 (복사·붙여넣기 사용)

### 12.1 사용 방법

```bash
# 1. 터미널에서 (필요 시) 메모리/권한 시드 초기화
/pf:bootstrap

# 2. 새 cycle 시작 — Preview Forge가 주제/요구사항을 묻는 첫 화면에서
/pf:new
# → 아래 §12.2의 텍스트 블록을 그대로 붙여넣기
```

가능하면 H1 (디자인 게이트)에서 §12.3 의 디자인 가이드를, H2 (최종 freeze)에서 §12.4 의 verification 체크리스트를 추가 입력으로 활용한다.

### 12.2 메인 프롬프트 (한 번에 붙여넣기)

```text
프로젝트: He Was Socrates — 100% on-device Korean Socratic bust on macOS, powered by Gemma 4 E4B 4-bit MLX.

목적
The Gemma 4 Good Hackathon (Kaggle × Google DeepMind, 마감 2026-05-19 08:59 KST, 총상금 $200K) 출품용 평가자 어필 자산을 만든다. 두 가지 산출물:
  (A) Kaggle 페이지에 임베드/링크할 수 있는 인터랙티브 단일 HTML preview (`claudedocs/preview/index.html` 류, 30–60 KB self-contained)
  (B) GitHub repo README의 hero / hackathon 섹션 마크다운 패치 제안

핵심 컨텍스트는 `claudedocs/2026-05-06-hackathon-strategy.md` (이 문서)를 1차 source로 사용한다. 추가 자료는 §10 참조.

타깃 카테고리 (우선순위 — 사용자 확정 2026-05-07)
1. Impact-focused / Education — 1순위 narrative. 소크라테스 maieutics를 한국어 학습자 도구로. defer_to_human이 'abstention as product'로 AI 안전성 표현. 모든 대화 on-device.
2. Technical — 2순위 narrative. Impact 주장의 engineering 증거. NO-CLOUD invariant + PR-Λ 24× TTFT + 4-function dispatch.
3. General (보조)

문제 영역: Education

차별화 메시지 (반드시 모두 노출)
- "Zero bytes leave the device" — `network.client` / `network.server` entitlement 없음. STT는 `requiresOnDeviceRecognition = true`. 사용자 음성은 영원히 사용자 Mac을 떠나지 않는다.
- "The abstention mechanic is the product" — defer_to_human이 1급 함수. 의료/법률/금융/응급/복지/보험 영역에서 솔직히 사람에게 위임.
- 한국어 단정한 평어체 system prompt verbatim, 톤 lock — 영어 LLM 데모와 차별화된 한국어 정체성.
- 1-bit halftone 미학 — photoreal AI avatar 거부, 16개 viseme PNG swap만.
- PR-Λ disk-mediated KV cache: TTFT 4.6 s → 192 ms (24×) — `claudedocs/bench/2026-05-06-latency-bench.json`로 검증 가능.
- Native function calling 활용: 4개 함수 dispatch (`mode_classify` / `surface_past_wonder` / `ask_back` / `defer_to_human`).
- macOS 26 SpeechAnalyzer + AssetInventory in-app 자료 다운로드 (PR #33, ko_KR + en_US 양언어).
- Long context (256K) — wondering log 다년 회상 (Phase 4 wiring 기반, 현재는 stub — 표현 시 정확히 명시).

절대 준수할 룰 (CLAUDE.md absolute invariants)
- Zero bytes leave the device를 위반하는 표현 금지 (예: "AI가 학습한다", "전송된다" 같은 카피 금지).
- "단정한 평어체" 톤 lock — 한국어 카피는 평어체. 존댓말 / 반말 모두 부적합.
- 1-bit halftone aesthetic만. photoreal AI avatar mockup 금지.
- "blazingly fast", "혁신적", "100% secure", "unprecedented" 같은 marketing superlative 금지. 측정 가능한 숫자 + commit/bench 증거.
- Speculative features를 "as-shipped"로 표시 금지. wondering log 다년 회상은 Phase 4 wiring (현 stub) — 표현할 때 "designed to / 향후" 등으로 정확히.
- 잘못된 수치 금지: TTFT 192 ms (PR-Λ verify-2). Pre-PR-Λ 6 s baseline은 historical만.
- runs/2026-05-05-spec/ 기존 파일 수정 금지 (참조만).

핵심 메트릭 (반드시 등장, 출처 명시)
- TTFT 192 ms median (PR-Λ verify-2, n=10, M1 Max MBP 64GB) — `claudedocs/bench/2026-05-06-latency-bench.*`
- Per-turn user-facing ~2 s (decode + STT endpoint + TTS prep + 한국어 audio playback)
- 65 swift-testing 시나리오 통과 (`make engine-test`)
- 0 byte network egress (entitlement 검증: `apps/macos/HeWasSocrates/HeWasSocrates/Resources/HeWasSocrates.entitlements`)
- 3.97 GB Gemma 4 E4B 4-bit MLX weights (HuggingFace `mlx-community/gemma-4-e4b-it-4bit`, OS-mediated 1회 다운로드)
- macOS 26 Tahoe floor (PR #33, SPEC.md.iter6)
- 4 function dispatch + 16 visemes + 2 locales (ko-KR, en-US)

대상 평가자 mental model
- Kaggle / DeepMind 영어 audience 1순위 — Impact / Education 기준으로 평가. Gemma 4 / function calling은 알지만 NO-CLOUD / defer_to_human / 한국어 단정한 평어체는 설명 필요.
- 일반 GitHub dev (영어) 2순위 — repo README 진입.
- 한국어 사용자 정체성은 system prompt 톤 / defer_to_human 시연 한국어 캡처 / 흉상 음성 데모에서 표현.
- 가정: 평가 환경에 macOS 26 가용 (PR #33 floor 결정 근거 §3.4 참조).

지향 산출물 구조 (Option C — 카피 위계 영어 우선 + 한국어 병기)

A. Preview HTML (`claudedocs/preview/index.html`, scroll layout, dark theme, ink-black 단색 강조)
   1. Hero — 흉상 face_halftone.png + 영어 tagline "He Was Socrates" + 영어 한 줄 정의 + 한국어 부제 (평어체)
   2. The Abstention Mechanic (1순위 Impact narrative) — defer_to_human 시연 시나리오: 의료 질문(영어 user input) → ⊘ 한국어 평어체 응답 캡처. AI 안전성을 product mechanic으로 표현하는 사례.
   3. Why on-device — entitlement 파일 발췌 + 비행기 모드 데모 영상 placeholder. Privacy-first education narrative.
   4. The Engineering (2순위 Technical 증거) — TTFT 24× 개선 + bench JSON 발췌 + Phase enum 코드 + function-call YAML 발췌
   5. The Aesthetic — 16 viseme swap GIF/sequence + 1-bit halftone 원리
   6. macOS 26 Pre-flight UX — PR #33 스크린샷 (PreflightView, PermissionExplainerView). 양언어(ko/en) AssetInventory 단일 다운로드.
   7. Categories Mapping — Impact-Education 1순위 / Technical 2순위 어필 영역 표
   8. Verification — 측정 출처 + 코드 위치 link
   9. Roadmap — Phase 4 wondering log 다년 회상 (정확히 "designed for", 현 stub)
   10. Footer — repo / Kaggle entry / 라이선스 (Apache-2.0 코드 + CC-BY-4.0 콘텐츠)

카피 위계 규칙:
- Heading / 본문 / 메트릭 / 캡션 = 영어 우선
- system prompt 발췌 / defer_to_human 응답 시연 / 흉상 부제 / 한국어 정체성을 표현하는 sidebar = 한국어 평어체 (영어 번역 옆에 작게)
- 코드 주석은 영어
- 외부 인용 / 출처 / API doc link = 영어

B. README hero 패치 — 별도 마크다운 파일 (`claudedocs/preview/README-hero.md`)
   - 현재 README의 어느 위치에 어떤 섹션을 삽입/대체할지 diff hunk 형태
   - 한국어 + 영어 병기 (Kaggle 평가자 영어 + Korean 사용자 둘 다)

자료 위치 (PreviewDD가 우선 읽을 것)
- `claudedocs/2026-05-06-hackathon-strategy.md` (1차)
- `runs/2026-05-05-spec/spec/SPEC.md` + iter2/4/5/6 deltas
- `runs/2026-05-05-spec/spec/function_call_contract.yaml`
- `Sources/SocraticEngine/Gemma/SystemPrompt.swift` (Korean 평어체)
- `Sources/SocraticEngine/EngineCoordinator.swift` (Phase enum)
- `apps/macos/HeWasSocrates/HeWasSocrates/Preflight.swift` (PR #33)
- `apps/macos/HeWasSocrates/HeWasSocrates/Resources/HeWasSocrates.entitlements`
- `claudedocs/bench/2026-05-06-latency-bench.json` + `.log`
- `claudedocs/2026-05-06-firstlaunch-ux-bestpractices.html`
- `assets/face_halftone.png`, `assets/visemes/*.png` (16개)

성공 기준 (PreviewDD가 freeze 전 자가 검증)
1. 모든 메트릭이 commit / bench / file 인용으로 검증 가능
2. 평가 카테고리 (Impact-Education 1순위, Technical 2순위)가 명시적으로 매핑된 표 1개 이상
3. 한국어 평어체 톤 + 1-bit halftone 미학 일관성
4. Marketing superlative 0건
5. CLAUDE.md absolute invariants 위반 0건
6. PR #33 양언어 + macOS 26 floor 정확히 반영
7. 흉상 PNG + 16 viseme 시각 자산 활용
8. 출처 인용 모두 markdown hyperlink로
9. self-contained HTML (CDN 외 외부 의존성 0)
10. 30–60 KB 사이 (실제 측정)

피해야 할 것
- "blazingly fast", "revolutionary", "unprecedented" 류 marketing superlative
- photoreal AI avatar mockup (1-bit halftone 위반)
- 클라우드 architecture diagram (사실과 반대)
- speculative feature를 as-shipped로 표시 (wondering log 다년 회상은 designed-for, 현 stub)
- 잘못된 메트릭 (예: TTFT를 6 s로 표기 — 그건 pre-PR-Λ baseline)
- 한국어 단일 — Kaggle 평가자 영어 audience 1순위. 한국어는 정체성 표현(system prompt 톤 / defer_to_human 시연 / 흉상 부제)에 한정.
- "친근한 챗봇", "당신의 AI 친구" 류 카피 — 이 앱은 단정한 평어체. 친근하지 않다.
```

### 12.3 H1 게이트 (디자인 선택) 보충 입력

```text
디자인 가이드:
- Layout: scroll (단일 페이지, 긴 narrative)
- Theme: dark (ink-black 배경 #1F1D2F 류) + 단색 강조 (흰색 또는 옅은 금/베이지)
- Typography:
    Heading: "Times New Roman" serif (앱 자체와 일치)
    Body: Inter / system-ui sans-serif
    Code/Metric: JetBrains Mono / monospaced
- Hero 비주얼: assets/face_halftone.png 흉상 PNG 그대로 + 1-bit halftone 그라데이션
- Color accents: 단색 only (multi-color 그라데이션 / 무지개 류 거부)
- Iconography: 시스템 SF Symbols 스타일 또는 1-bit minimal
- Motion: 거의 없음. soft pulse (Gemma thinking 모드 시각화)만 GIF/CSS로 hero에서 한 번.
- 차트: 필요 시 Chart.js로 minimal bar / line. 단색.

거절할 디자인:
- 다채색 그라데이션 hero (흔한 AI 데모 외양)
- 둥근 챗 버블 + 챗봇 UI (이 앱은 챗 UI가 없다)
- photoreal 흉상 mockup
- 한국어 단독 위계 (영어 우선 + 한국어는 정체성 표현 영역에 한정 — system prompt 발췌, defer_to_human 시연 캡처, 흉상 부제)
- "Get Started" CTA 류 SaaS 스타일 (이 앱은 다운로드 → 실행 — Get Started 없음)
- "친근한 톤" / 둥근 모서리 + pastel — 단정한 평어체 + 1-bit halftone aesthetic 위반
```

### 12.4 H2 게이트 (freeze 직전) 검증 체크리스트

```text
freeze 승인 전 확인:
- [ ] §12.2 의 차별화 메시지 8개 모두 본문에 등장
- [ ] §12.2 의 핵심 메트릭 7개 모두 본문에 등장 + 출처 인용
- [ ] §12.2 의 "피해야 할 것" 7개 항목 모두 본문에 없음
- [ ] §12.2 의 카테고리 매핑 표 존재 + Technical / Impact 모두 다룸
- [ ] §12.3 의 디자인 가이드 준수
- [ ] CLAUDE.md absolute invariants 위반 0건
- [ ] HTML self-contained (외부 CDN 외 의존성 없음)
- [ ] HTML 크기 30–60 KB 범위
- [ ] 모든 외부 link가 markdown hyperlink + valid URL
- [ ] 한국어 평어체 톤 일관성
- [ ] 1-bit halftone aesthetic 일관성
- [ ] PR #33 + iter6 + PR-Λ 모두 정확히 반영
```

---

End of context pack.
