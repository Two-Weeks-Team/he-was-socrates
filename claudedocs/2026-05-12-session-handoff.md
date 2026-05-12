# Session Handoff — 2026-05-12

**작성일**: 2026-05-12 (cwd: `he-was-socrates` repo)
**Latest commit**: `0f1dccf` (`feat/mnemo-engine-phase1` branch HEAD)
**Main**: `76157ad` (PR #42 merged — submission narratives + strategy artifacts)
**Open PR**: #43 `feat(mnemo): Phase-1 engine core + validated implementation plan` — CI green, mergeable CLEAN
**Hackathon (deprioritized)**: The Gemma 4 Good Hackathon · deadline 2026-05-19 08:59 KST (= D-7) — the user pivoted away from it this session toward Mnemo.

---

## 0. 두 줄 요약

- **이번 세션은 두 가닥**: ① 해커톤 작업 마무리 (8 PR 머지 + CI fix + app↔landing 통합 + "Out Loud" 마스터 플랜) → ② 사용자가 해커톤을 옆에 놓고 **"Mnemo"** 라는 새 제품 방향으로 전환 — on-device로 사용자가 필요한 모든 것을 기록하고 어떤 형태(음성·소리·화면·진동·큰 글씨·평이한 말)로든 다시 표현해주는 시스템. 계획을 3-critic 루프로 검증하고 **Phase-1 엔진 코어를 구현** (`packages/MnemoEngine`, 컴파일됨, 35 테스트 통과, PR #43).
- **다음 세션 1순위**: PR #43 머지 여부 결정 → Mnemo Phase 2 (`SQLiteMemoryStore` + `SummaryEngine`) 실제 구현 시작, 또는 해커톤 마감(D-7) 처리 결정.

---

## 1. 진행한 작업 (시간순)

### Phase A — `/handon` + 해커톤 잔여 작업 (오전)
- `/handon` 으로 2026-05-11 핸드오프 로드. 사용자 결정: PR 머지는 팀원 검토 후 / 이번 세션 우선순위 perf 보강 / Vercel deploy 진행 (CLI 업그레이드 먼저) / 다른 팀원 진행 중.
- **Vercel CLI 50.3.2 → 53.3.2** — brew vercel-cli 제거 + npm 공식 채널 (sudo chown으로 EACCES 해소). 메모리: `feedback_vercel_official_install.md`.
- **apps/web perf 보강 (PR #36)** — `experimental.inlineCss` + Tailwind v4 제거 → 0 render-blocking stylesheet. commit `1d5eae7`.
- **Vercel deploy** — `2weeks-team/web`, public alias `he-was-socrates.vercel.app`, SSO disabled (`vercel project protection disable --sso`). 메모리: `project_vercel_deploy_state.md`.

### Phase B — 해커톤 audit + PR 전수 머지 (오후 1)
- `/hackathon-audit` 실행 — 4-축 readiness 평가 (`claudedocs/hackathon-audit-20260511-gemma-4-good-hackathon.html`).
- **CI 근본 원인 수정 (PR #40)**: runner `macos-15` ↔ 패키지 `macOS 26.0` floor 불일치 → 테스트 xctest 번들이 macOS 26 dylib 못 찾음. 수정: `ci.yml` runner를 `macos-26`으로 (GitHub이 2026 초 추가). main CI 4일만에 green 복구.
- **8 PR 전부 머지** (conflict 0): #40 → #34 (H1 lock) → #35 (spec iter7) → #36 (web+perf) → #37 (docs) → #38 (README hero) → #39 (handoff commands) → #41 (app↔landing 통합). main `76157ad`. main CI 6/6 SUCCESS.
- **PR #41** — README "Live preview" 링크를 실제 Vercel 배포로 수정 + "Two surfaces, one product" 단락.

### Phase C — 4-심사관 재평가 + 피벗 탐색 (오후 2)
- 컨텍스트-프리 4 심사 에이전트 (Hackathon Judge / Product Strategist / Technical Reviewer / Impact Skeptic) — Scenario A(현 트랙) vs B(Gemma 4 zero-cost 피벗) vs C(ambient memory companion), D-8 제약 유/무. 산출물: `claudedocs/2026-05-11-reevaluation-4judges-and-pivot-options.html`. 만장일치: 전면 피벗 금지, A 코드베이스 유지, "Safety & Trust" 트랙 재고.
- 케글 수상 사례 조사 (Gemma 3n Impact Challenge 8 winners — on-device 6/8, accessibility 5/8). 사용자 지적("로컬 전용이 윤리 답"): 맞음 — 대회 자신이 "a community where privacy is non-negotiable"를 명명.
- 두 제출 서사 완성: `docs/submission-out-loud.md` (PRIMARY — 글 못 읽거나 그 언어를 못 읽는 사람에게 문서를 소리 내어 읽어주는 폰), `docs/submission-maia.md` (FALLBACK — 인터넷·교사 없는 교실의 적응 튜터). 비교: `claudedocs/2026-05-11-submission-narratives-comparison.html`. PR #42 머지.
- **"Out Loud" 마스터 플랜** (`docs/out-loud-master-plan.md`, PR #42에 추가): Gemma 4 E4B model card 검증 (128K context 아니라 256K였던 오류 수정 / 내장 OCR·번역 / Android-first via LiteRT), 갭-클로저 표, 룰-준수 체크리스트, 검증 로그, 정직한 수상 확률 (트랙 placement ~20-35%, grand prize top-3 ~8-15%).

### Phase D — Mnemo 방향 전환 + Phase-1 구현 (오후 3 / 저녁)
- 사용자: 해커톤 무관, 시간 제한 무시 — "사용자가 필요로 하는 모든 것을 기록하고 어떤 형태로든 다시 표현해주는" 시스템을 계획·검증·구현·배포가능 상태까지.
- **계획** — `docs/mnemo-implementation-plan.md` (§0–§9: 아키텍처 capture→memory→recall→adaptive expression, 불변항, 기술 스택 [Gemma 4 E4B-it / 128K / text+image+audio / 내장 multilingual OCR+document parsing+ASR+speech-to-translated-text+native function calling / Apache 2.0], 모듈 맵, 프라이버시·윤리 모델, 빌드 단계, open questions).
- **루프 검증** — 3 컨텍스트-프리 critic (architecture / privacy-ethics / feasibility). 모든 수용 사항 §10에 반영 (embedding/entities/structure → OPTIONAL deferred enrichment; 프라이버시 기본값 보수화 [textOnly raw / pruneAfterDays 30 / push-to-capture audio / v1 recall-on-demand only]; adapter가 VALUE emit; ExpressionRouter가 RoutingDecision + 명시적 precedence lattice; MemoryStore actor; storage가 모든 backup/sync/Spotlight 밖; dependency gate; 별도 vault credential; Phase 1 re-scope; 3 feasibility-blocking open question 추가; "deployable" 5–9개월로 정직하게).
- **구현** — `packages/MnemoEngine/` Phase 1: Models · Clock(injectable time) · MemoryStore protocol(Actor)+InMemoryMemoryStore · VectorIndex protocol+FlatCosineVectorIndex+SqliteVecVectorIndex stub · EmbeddingService stub · EventEnricher seam · AbstentionGate(recall-don't-advise) · GemmaReasoning stub · 동결 RecallFunctionContract(5 함수) · ContextBudgeter(top-K raw retrieval any age + temporal scaffold, overhead 먼저, slack 양방향 roll, token counting 주입→순수) · RecallEngine skeleton · 6 value-emitting expression adapter · **ExpressionRouter — adaptive heart, 명시적 precedence lattice** · RecallService · CaptureControlling protocol · thin MnemoCoordinator. **CommandLineTools만으로 컴파일됨. 35 swift-testing 테스트 전부 통과.** README in `packages/MnemoEngine/README.md`. PR #43.
- 메모리: `project_mnemo_direction.md` + MEMORY.md 인덱스.

---

## 2. 현재 상태 (2026-05-12)

### Git branches
| Branch | HEAD | PR | 상태 |
|---|---|---|---|
| main | `76157ad` | — | 8 PR 머지 완료, CI 6/6 green |
| feat/mnemo-engine-phase1 | `0f1dccf` | #43 OPEN | Mnemo Phase-1 코어 — CI green, mergeable CLEAN, 머지 대기 |

### Live URLs (HTTP 200, 모두 공개)
- https://he-was-socrates.vercel.app (Vercel, SSO disabled)
- https://web-2weeks-team.vercel.app
- https://two-weeks-team.github.io/he-was-socrates/ · /web/ · /runs/r-20260507-010321/mockups/gallery.html

### 빌드/테스트 상태
- main: CI 6/6 SUCCESS on macos-26 (engine-build · assets-determinism · swift-format · gitleaks · install-oracles · LatencyBench)
- `packages/MnemoEngine`: `swift build` OK, `swift test` **35/35 pass** (standalone — 아직 Makefile/CI에 미연결)
- `packages/SocraticEngine`: 65 swift-testing tests (변화 없음)

### 환경
- node v24.15.0 · pnpm 10.27.0 · vercel CLI **53.3.2** (npm 단일 채널, brew 제거됨) · swift 6.3.1 · macOS 26
- `apps/web/.vercel/project.json` 존재 (`2weeks-team/web` 링크, gitignored)

### 객관적 수상 가능성 (해커톤 — deprioritized)
- "Out Loud" 출품 시, Gemma-3n-winner 수준 실행 가정: 트랙 placement ~20-35%, grand prize top-3 ~8-15%. 단 load-bearing 가정 = "the wow lands"(영상). 영상·DMG·Kaggle 페이지 미존재. D-7.

---

## 3. 다음 세션에서 할 수 있는 것

### 즉시 가능 (외부 의존 없음)
1. **PR #43 머지** — Mnemo Phase-1 코어. standalone이라 CI 영향 없음. 머지 후 `make mnemo` / `make mnemo-test` 타겟 + CI step 추가도 가능.
2. **Mnemo Phase 2** — `SQLiteMemoryStore` (암호화·dedup·tombstone delete, 모든 backup/sync/Spotlight scope 밖 [`isExcludedFromBackup`, `.metadata_never_index`], path 속성 CI 테스트) + `SummaryEngine` rollup job (closed day-bucket만, event in-place 변경 금지). in-memory store의 protocol이 이미 shape 정의 — slot-in.
3. **Mnemo Phase 3** — `GemmaService.real` (Gemma 4 E4B-it 4-bit via mlx-swift-lm — HF repo id / registry key 먼저 확인) + 실제 `EmbeddingService` (MiniLM-class) + 실제 function-calling round-trip.
4. **MnemoEngine을 Makefile/CI에 연결** — `make mnemo-test` 타겟 + `.github/workflows/ci.yml`에 step (별도 작은 작업).
5. **해커톤 마감 처리** (D-7) — "Out Loud"로 출품할지, 현 He Was Socrates macOS 빌드를 Safety & Trust에 출품할지, 출품 안 할지 결정. 출품한다면: 영상(`aapt`/`tcpdump` 0-패킷 비트), 노타라이즈 DMG, Kaggle 페이지, 앱 스크린샷 — 대부분 다른 팀원 작업.
6. **앱 스크린샷 캡처** (본인 가능, ~1h) — Preflight · idle bust · listening · thinking pulse · speaking viseme · abstention demo.
7. **Lighthouse 실측** — `npx -y lighthouse https://he-was-socrates.vercel.app` — perf 86→? 확인 (PR #36 inline CSS 이후).

### 사용자 입력 또는 환경 필요
1. **PR #43 머지 시점** — 지금? 검토 후?
2. **Mnemo vs 해커톤 우선순위** — D-7. Mnemo Phase 2 계속 vs 해커톤 마감 처리.
3. **Mnemo가 새 repo로 분리될지** — 현재 `packages/MnemoEngine`로 이 repo에 있음; 별도 제품이라 추출 가능 (사용자 결정).
4. **다른 팀원 진행 상황** — DMG / demo video / Kaggle write-up (해커톤).

---

## 4. 할 수 없는 것 (외부 변수)

- **Mnemo "실제 배포가능"** — 작은 팀 5–9개월 (Phase 2–3 ~weeks; macOS 데모 Phase 5 ~2–3개월; Phase 7 hardening — 프라이버시 리뷰, dependency gate, notarization for a bundled-LLM screen-recorder, accessibility audit, E4B latency/thermal tuning — months). 이 세션은 검증된 계획 + 컴파일·테스트 통과하는 엔진 코어를 만들었지 배포가능 앱이 아님. (plan §6, §10 + README에 명시.)
- **해커톤 demo video / DMG / Kaggle 최종 제출** — 다른 팀원 작업.
- **E4B 추론 throughput이 capture cadence를 따라가는지** — He Was Socrates는 M1 Max에서 ~6s/turn. 이게 Mnemo의 load-bearing unknown (lazy-OCR-at-recall이냐 thermal death냐). 실측 필요 — Phase 3+.
- **macOS App Store가 bundled-LLM screen-recorder를 통과시키는지** — Developer-ID-only일 수도. Phase 7.

---

## 5. 추가로 필요한 것들 (다음 세션 시작 전)

### 사용자 확인 필요
1. PR #43 머지 시점.
2. 우선순위: Mnemo Phase 2 vs 해커톤 마감(D-7).
3. Mnemo를 새 repo로 분리할지.
4. 해커톤 — 출품 트랙 결정 ("Out Loud" Digital Equity / He Was Socrates Safety & Trust / 미출품).

### 환경 점검
- node v24.15.0 · pnpm 10.27.0 · vercel 53.3.2 · swift 6.3.1 — 전부 동작.
- `packages/MnemoEngine`: `cd packages/MnemoEngine && swift test` → 35 pass 확인.

---

## 6. 다음 세션 시작 프롬프트 (복사용)

```text
/handon

이전 세션 핸드오프: claudedocs/2026-05-12-session-handoff.md

읽고 다음 결정 사항에 답한 뒤 진행하세요:
1. PR #43 (Mnemo Phase-1 엔진 코어) 머지 시점 — 지금 / 검토 후
2. 우선순위 — Mnemo Phase 2 (SQLiteMemoryStore + SummaryEngine) 계속 vs 해커톤 마감 처리 (D-7, 2026-05-19 08:59 KST)
3. Mnemo를 별도 repo로 분리할지 (현재 packages/MnemoEngine로 이 repo에 있음)
4. 해커톤 출품 트랙 결정 — "Out Loud" (Digital Equity) / 현 He Was Socrates macOS 빌드 (Safety & Trust) / 미출품

D-day (해커톤): 2026-05-19 08:59 KST
```

---

## 7. 핵심 자산 위치 reference

### Mnemo (이번 세션 신규 — PR #43)
- `docs/mnemo-implementation-plan.md` — 검증된 계획 (§10 = critic-loop revisions = 바인딩 버전)
- `packages/MnemoEngine/` — Phase-1 엔진 코어 (`Sources/MnemoEngine/{Models,Support,Memory,Reason,Recall,Express}/`, `MnemoCoordinator.swift`, `MnemoEngine.swift`; `Tests/MnemoEngineTests/`)
- `packages/MnemoEngine/README.md` — 레이아웃 + build/test + "여기 없는 것 / 배포까지 몇 달" + 다음 단계
- 메모리: `~/.claude/projects/-Users-kimsejun-Documents-GitHub-he-was-socrates/memory/project_mnemo_direction.md`

### 해커톤 전략 (이번 세션 — PR #42에 머지됨)
- `docs/out-loud-master-plan.md` — "Out Loud" 검증된 마스터 플랜
- `docs/submission-out-loud.md` (superseded note) · `docs/submission-maia.md`
- `claudedocs/2026-05-11-submission-narratives-comparison.html`
- `claudedocs/2026-05-11-reevaluation-4judges-and-pivot-options.html`
- `claudedocs/hackathon-audit-20260511-gemma-4-good-hackathon.html`

### 기존 (변화 없음)
- `apps/macos/HeWasSocrates/` — macOS 앱 (65 swift tests) · `apps/web/` — Next.js 16 web companion · `packages/SocraticEngine/` — He Was Socrates 엔진
- `runs/2026-05-05-spec/` — frozen SpecDD (read-only) · `runs/r-20260507-010321/` — PreviewDD run (untracked, PR #34 머지 후 일부 main에)
- `claudedocs/2026-05-11-session-handoff.md` (AM) · `claudedocs/2026-05-11-pm-session-handoff.md` (PM) — 이전 세션 핸드오프

---

## 8. 알려진 issue / open question

1. **`packages/MnemoEngine`가 Makefile/CI에 미연결** — standalone. `make mnemo-test` 타겟 + CI step 추가 필요 (다음 세션).
2. **Mnemo `MemoryStore` protocol의 `Actor` 제약** — protocol이 `Actor`를 요구; 구체 impl이 actor여야 함 (in-memory impl은 actor). Phase 2의 `SQLiteMemoryStore`도 actor.
3. **Gemma 4 E4B HF repo id / mlx-swift-lm registry key** — He Was Socrates는 `LLMRegistry.gemma4_e4b_it_4bit` 사용; Mnemo Phase 3의 `.real` 와이어링 전에 정확한 id 재확인 (cheap insurance; feasibility critic의 cutoff가 Gemma 4 출시 이전이라 "Gemma 3n E4B 오타"로 의심했으나 model card로 검증됨).
4. **E4B 추론 throughput vs capture cadence** — Mnemo의 load-bearing unknown. He Was Socrates ~6s/turn on M1 Max. lazy-OCR-at-recall fallback이 충분히 빠른지 실측 필요.
5. **해커톤 D-7** — Mnemo로 전환했으므로 해커톤은 deprioritized. 출품 여부 미결정.
6. **`apps/web/next-env.d.ts`** — Next.js 자동 생성, untracked. `.gitignore`에 추가 검토 (지금은 무해).

---

End of handoff. 페어: `/handon` (다음 세션에서 이 문서 로드).
