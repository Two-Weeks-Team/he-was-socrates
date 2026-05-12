# Session Handoff — 2026-05-12 (PM)

**작성**: 2026-05-12 PM (cwd: `he-was-socrates`). 페어: `/handon`.
**이전 핸드오프**: `claudedocs/2026-05-12-session-handoff.md` (AM — hackathon wrap → Mnemo pivot → Phase-1 engine core, PR #43 OPEN).
**이번 세션 한 일**: `/handon` → 사용자 결정 4건 수령 → PR #43 머지 → **Mnemo를 별도 public repo로 추출** → Phase 2 구현 → Phase 3 (순수 부분) 구현 → 해커톤 트랙 "Out Loud"로 확정.

---

## 0. 두 줄 요약

- Mnemo가 자기 repo로 독립했다: **`Two-Weeks-Team/mnemo`** (PUBLIC, `git subtree split`로 히스토리 보존). he-was-socrates에서는 제거 + 포인터만 남김 (PR #44). 새 repo에 자체 Makefile/CI/CLAUDE.md/dual-license. **Phase 2 완료** (`SQLiteMemoryStore` + `StorageHardening` [path-attributes CI 테스트 포함] + `SummaryStore` + `SummaryEngine`) + **Phase 3 순수 부분 완료** (`FunctionCallParser` + `FunctionCallGenerating` seam + Gemma 4 모델 ID 확인). **67 swift-testing 테스트 통과, CI green.** 엔진 라이브러리는 `swift-testing` 외 의존성 0 — MLX는 안 들어감.
- 다음: mnemo repo에서 **`MnemoEngineMLX` 타겟** (Phase 3 나머지 — Xcode + mlx-swift-lm + ~4GB weights 필요) → Phase 4 (실제 macOS capture + 프라이버시 UX). 해커톤(D-7, 2026-05-19 08:59 KST)은 "Out Loud" (Digital Equity) 트랙으로 출품 결정 — 영상/DMG/Kaggle 페이지는 대부분 다른 팀원 작업.

---

## 1. 사용자 결정 (이번 세션 시작 시 `/handon` 후)

1. **PR #43 머지 시점** → "머지 + Makefile/CI 연결" → PR #43 머지함 (main `ba0ea86`). "Makefile/CI 연결"은 추출 후 *새 repo*에서 이뤄짐 (he-was-socrates의 Makefile/CI는 SocraticEngine만 다룸; MnemoEngine은 원래 미연결이었음).
2. **우선순위** → "페이즈2뿐만 아니라 끝까지 진행하세요. 단계별로 검증하면서." → Phase 2 전부 + Phase 3 순수 부분 구현, 각 단계 build+test+lint 검증. 그 이상(MLX 타겟·실제 capture·앱)은 Xcode/MLX/수개월 — 이번 세션 범위 밖, 핸드오프로 넘김.
3. **별도 repo 분리** → "별도 repo로 추출", 이름/소유자 `Two-Weeks-Team/mnemo`, **Public**, 원본은 "제거 + 포인터 커밋".
4. **해커톤 트랙** → "Out Loud" (Digital Equity / Impact-focused). `docs/out-loud-master-plan.md` 기준. 산출물(데모 영상·노타라이즈 DMG·Kaggle write-up)은 미존재 — 대부분 다른 팀원 작업. (이번 세션에선 해커톤 작업 안 함.)

---

## 2. 진행한 작업 (시간순)

### A. PR #43 머지 + 시작 정리
- `gh pr merge 43 --merge` → he-was-socrates main `ba0ea86` ("Merge pull request #43 ... feat/mnemo-engine-phase1").
- working tree에 `.claude/commands/handoff.md` / `handon.md`가 삭제된 채로 남아 있던 drift 발견 → `git checkout -- .claude/commands/` 로 복원 (이전 세션의 미커밋 삭제였음, 의도치 않음).

### B. Mnemo 추출 → `Two-Weeks-Team/mnemo`
- `git subtree split --prefix=packages/MnemoEngine -b mnemo-extract` → 새 dir `/Users/kimsejun/Documents/GitHub/mnemo` 에 `git init` + `git pull <hws> mnemo-extract` (히스토리 1커밋 보존: `131d1ab feat(mnemo): Phase-1 engine core...`).
- 새 repo 스캐폴드 (커밋 `e191d34`): `Makefile` (build/test/lint/format/ci-local) · `.github/workflows/ci.yml` (build-and-test · swift-format lint · gitleaks, `macos-15` — Phase 1엔 macOS-26 API 없음) · `.swift-format` (parent에서 복사) · `.gitignore` · `CLAUDE.md` (invariants + 컨벤션) · `LICENSE` (Apache-2.0 code / CC-BY-4.0 docs, Gemma-compatible) · `docs/mnemo-implementation-plan.md` (복사) · README 갱신 (make 빌드, CI note, 추출 provenance).
- `gh repo create Two-Weeks-Team/mnemo --public --source ... --remote origin --push`. CI green.
- he-was-socrates에서 제거 (PR #44, 머지됨 `2026-05-12T05:57:14Z`): `packages/MnemoEngine/` 삭제, `docs/mnemo-implementation-plan.md` → 포인터 스텁으로 교체 (경로 살려둠), README에 "Spin-off: Mnemo" 단락. **빌드/CI 영향 0** (MnemoEngine은 standalone, parent Makefile/CI에 미연결이었음).
  - 주의: 처음 `git add -A`가 untracked `runs/r-20260507-010321/*` + `.pf-current-run` + `apps/web/next-env.d.ts`를 쓸어담아서 → `git reset --soft HEAD~1` + `git restore --staged` 로 되돌리고 의도한 27파일만 재커밋. (그 untracked 파일들은 여전히 untracked로 남아 있음 — handoff §8 known issue.)

### C. Mnemo Phase 2 (mnemo PR #1, 머지됨)
- `Sources/MnemoEngine/Memory/SQLiteSupport.swift` — 시스템 `SQLite3` C 모듈 위의 작은 래퍼 (SPM 의존성 X — dependency gate 깨끗하게 유지). open + WAL pragmas + prepared statements + transactions + VACUUM. `Sendable` 아님 (actor 안에서만 사용).
- `StorageHardening.swift` — invariant #5: `isExcludedFromBackup`, `.metadata_never_index` Spotlight 마커, iOS `FileProtectionType`. 앱이 넘기는 경로를 hardening (위치 선택 = 앱 레이어 책임, Phase 4/5).
- `SQLiteMemoryStore.swift` — actor, 기존 `MemoryStore` 프로토콜 준수. event 1행 = 인덱스 스칼라 컬럼 + Codable event를 JSON blob으로. flat-cosine 벡터 인덱스는 메모리에 두고 open 시 디스크에서 재구성 (~10⁶ events까지 OK). **삭제는 진짜**: payload 컬럼 null + `deleted=1` 툼스톤 (sync 레이어가 "없었음" vs "있었는데 지움" 구분 가능), `compact()` = VACUUM. 재오픈해도 삭제 유지.
- `SummaryStore.swift` — `SummaryStore` 프로토콜 + `InMemorySummaryStore` + `SQLiteSummaryStore` (자체 hardened `summaries.sqlite3`).
- `SummaryEngine.swift` — actor. rollup 잡: **CLOSED** day/week/month/year 버킷만 (ISO-8601, UTC), 버킷당 summary 없으면 생성, **CaptureEvent 절대 mutate 안 함** (오래된 디테일은 옆에서 요약될 뿐 편집 안 됨). idempotent.
- `GemmaService.swift` — `GemmaReasoning`에 `summarizeDay`/`summarizeRollup` 추가; stub은 deterministic; 진짜 모델은 Phase 3.
- 테스트 +16 (35→51): `SQLiteMemoryStoreTests` (append/dedup/enrich+retrieve/range/real-delete+reopen/persistence+index-rebuild/compact), `StorageHardeningTests` (디렉토리 excluded-from-backup + Spotlight 마커; 스토어가 자기 경로 hardening; idempotent — **plan §7이 요구하는 path-attributes CI 테스트, 일찍 착지**), `SummaryEngineTests` (closed-buckets-only / idempotent / no-event-mutation / 월이 닫힌 뒤 monthly rollup / SQLite summary store).
- mnemo `main` 커밋: `b50faa6` (feat) → `c64e6dc` (merge PR #1).

### D. Mnemo Phase 3 — 순수 부분 (mnemo PR #2, 머지됨)
- `Sources/MnemoEngine/Recall/FunctionCallParser.swift` — 모델 텍스트 → 타입드 `RecallFunctionCall` (5-함수 contract: recall_events / summarize_period / find_entity_mentions / set_reminder / flag_for_human). 관대함: ```fences```, `<tool_call>` 태그, JSON 앞뒤 prose, 대체 키명 (`function`/`parameters`/`args`/`q`/…), inlined args, 범위 3형태 (`{start,end}` / `[a,b]` / `"yyyy-MM"` 등 기간 문자열), ISO-8601 날짜; brace 매처는 string-aware (JSON 문자열 안의 `}`에 안 속음). 진짜 파싱 불가 → `.unparseable(rawText:)` (호출자가 fallback).
- `Sources/MnemoEngine/Reason/FunctionCallGenerating.swift` — Phase-3 seam: `FunctionCallGenerating { func generate(prompt:maxTokens:) async throws -> String }` (MLX 제공자가 구현) + **확인된 모델 ID를 헤더에 기록** + `UnavailableFunctionCallGenerator` (의존성 없는 엔진은 런타임 없음 — throw).
- `docs/mnemo-implementation-plan.md` §10 open question #3 → **CLOSED** 표시 + 확인된 ID + ("128K"/"256K" 컨텍스트 수치와 `mlx-community/...` vs `google/gemma-4-E4B` repo 참조 나중에 reconcile하라는 노트).
- 테스트 +16 (51→67): `FunctionCallParserTests` — 5함수 전부, fenced/tagged/prose-wrapped, 대체 키, inlined args, brace-in-string, 범위 3형태, missing-required-arg → unparseable, unknown function → unparseable, generator throws.
- mnemo `main` 커밋: `39751c0` (feat) → `d99dbe1` (merge PR #2).

---

## 3. 현재 상태 (2026-05-12 PM)

### Repos
| Repo | main HEAD | 상태 |
|---|---|---|
| `Two-Weeks-Team/he-was-socrates` | `ba0ea86` (PR #43) + 그 위에 PR #44 머지 | MnemoEngine 제거됨; "Spin-off: Mnemo" note; CI green |
| `Two-Weeks-Team/mnemo` (NEW, PUBLIC) | `d99dbe1` (PR #2) | Phase 1 ✅ · Phase 2 ◑ · Phase 3 ◑; 67 tests; CI green; 로컬 `/Users/kimsejun/Documents/GitHub/mnemo` |

### 검증
- mnemo: `make ci-local` → build OK · `swift test` 67/67 pass · `swift-format lint` exit 0. GitHub CI (build-and-test · swift-format · gitleaks, macos-15) 전부 pass.
- he-was-socrates: PR #44 CI 전부 pass (engine build & swift-testing · assets-determinism · swift-format · gitleaks · install-oracles · LatencyBench compile).

### 환경
- node v24.15.0 · pnpm 10.27.0 · vercel 53.3.2 · swift 6.3.1 · macOS 26 · swift-format 602.0.0 · `git-filter-repo` 설치돼 있음 (사용 안 함; `git subtree split` 사용). `import SQLite3` 동작 확인 (SQLite 3.51.0, CommandLineTools).

### 해커톤 (D-7, 2026-05-19 08:59 KST) — deprioritized
- 트랙 결정: **"Out Loud"** (Digital Equity / Impact-focused). 기준 문서 `docs/out-loud-master-plan.md` (he-was-socrates). 미존재: 데모 영상 (0-패킷 비트 포함), 노타라이즈 DMG, Kaggle 페이지, 앱 스크린샷 — 대부분 다른 팀원. 이번 세션에선 해커톤 작업 0.

---

## 4. 다음 세션에서 할 수 있는 것

### Mnemo (우선) — 모두 `/Users/kimsejun/Documents/GitHub/mnemo` 에서
1. **`MnemoEngineMLX` 타겟 (Phase 3 나머지)** — 별도 Swift 패키지/타겟. `mlx-swift-lm` ≥ 3.31.3 의존, `LLMRegistry.gemma4_e4b_it_4bit` (HF `mlx-community/gemma-4-e4b-it-4bit`) 로드. 구현: (a) `FunctionCallGenerating` (Gemma 4 → raw text → `FunctionCallParser`), (b) `GemmaReasoning` (recall/simplify/summarizeDay/summarizeRollup — generator + 기존 ContextBudgeter 위 얇은 레이어), (c) 진짜 `EmbeddingService` (all-MiniLM-class, ~25 MB, MLX 또는 Core ML). **Xcode (Swift 6.1+) 필요**, CI에 `setup-xcode` (he-was-socrates 미러), 첫 실행 ~4GB 다운로드 + E4B latency/thermal 질문 (plan §7) 감안. 엔진 라이브러리 프로토콜은 안 움직임 — 새 타겟이 뒤에 슬롯인. README "The MLX integration target" 섹션 참조.
2. **Phase 2 작은 후속** — `VectorIndex` 프로토콜 뒤의 on-disk ANN 인덱스 (flat은 ~10⁶까지 OK지만 open 시 메모리 재구성); at-rest 암호화 통합 (엔진은 `isExcludedFromBackup` + iOS FileProtection 설정; Mnemo-vault Keychain 키는 앱 레이어 = Phase 5).
3. **Phase 4** — 실제 macOS capture: `ScreenCaptureKit` (+ screen-recording entitlement, TCC flow, mic 라이브 중 dismiss 불가 인디케이터), `AVAudioEngine`+VAD+STT (audio 기본 = push-to-capture), clipboard (read-only), files, manual; `BlackoutPolicy` 강제.
4. **128K vs 256K 확정** — Gemma 4 model card 다시 확인 → plan + README 수치 reconcile.

### 해커톤 (D-7)
5. **"Out Loud" 출품 준비** — 데모 영상 (`aapt`/`tcpdump` 0-패킷 비트), 노타라이즈 DMG, Kaggle write-up, 앱 스크린샷. 대부분 다른 팀원; 본인 가능: 앱 스크린샷 캡처 (~1h, `make app` 헤들리스 빌드로) — 단 Xcode + (선택) 모델 필요.

### 사용자 입력 필요
- mnemo PR 머지 정책: 이번 세션처럼 CI green이면 바로 머지할지, 팀원 검토 둘지. (이번 세션은 PR #1, #2 둘 다 CI green 후 `--merge`로 머지함.)
- 해커톤: 다른 팀원 진행 상황 (DMG/영상/Kaggle). 출품 마감 D-7.

---

## 5. 할 수 없는 것 (이번 세션 범위 밖)

- **Phase 3 MLX 타겟 / Phase 4–7** — Xcode + MLX + ~4GB weights + 수 주~수 개월. plan §6/§10 + README 명시: "actually deployable" ≈ 5–9개월 (소규모 팀). 이번 세션은 추출 + Phase 2 (완전) + Phase 3 순수 부분 (의존성 없이 가능한 전부)을 했지 배포 가능한 앱이 아님.
- **해커톤 데모 영상 / DMG / Kaggle 제출** — 다른 팀원 작업.
- **E4B 추론 throughput이 capture cadence를 따라가는지** — Mnemo의 load-bearing unknown (He Was Socrates ~6s/turn on M1 Max). lazy-OCR-at-recall이 충분히 빠른지 실측 필요 — Phase 3+ MLX 타겟 이후.

---

## 6. 다음 세션 시작 프롬프트 (복사용)

```text
/handon

이전 핸드오프: claudedocs/2026-05-12-pm-session-handoff.md

Mnemo는 이제 별도 repo: /Users/kimsejun/Documents/GitHub/mnemo (Two-Weeks-Team/mnemo, PUBLIC).
Phase 1 ✅ · Phase 2 ◑ · Phase 3 ◑ (순수 부분). 67 tests, CI green.

다음 결정/작업:
1. Mnemo Phase 3 마무리 — MnemoEngineMLX 타겟 (mlx-swift-lm + 실제 Gemma 4 + 실제 EmbeddingService, Xcode 필요) 시작할지
2. 또는 Phase 2 작은 후속 (on-disk ANN 인덱스 / at-rest 암호화) 먼저
3. 또는 해커톤 "Out Loud" 출품 준비 (D-7, 2026-05-19 08:59 KST) — 본인 가능 작업은 앱 스크린샷 정도
4. mnemo PR 머지 정책 (CI green이면 바로 vs 팀원 검토)
```

---

## 7. 핵심 자산 위치 reference

### Mnemo (새 repo `Two-Weeks-Team/mnemo`)
- `/Users/kimsejun/Documents/GitHub/mnemo/CLAUDE.md` — invariants + 컨벤션 (이 repo용)
- `docs/mnemo-implementation-plan.md` — 검증된 계획 (§1 invariants, §10 binding revisions; open question #3 = CLOSED)
- `README.md` — phase 표 (1 ✅ · 2 ◑ · 3 ◑ · 4–7), "The MLX integration target" 섹션, "deployable는 5–9개월" 정직한 read
- `Sources/MnemoEngine/Memory/{SQLiteSupport,StorageHardening,SQLiteMemoryStore,SummaryStore,SummaryEngine}.swift` · `Recall/FunctionCallParser.swift` · `Reason/FunctionCallGenerating.swift`
- `Makefile` (`make build/test/lint/ci-local`) · `.github/workflows/ci.yml`
- 메모리: `~/.claude/projects/-Users-kimsejun-Documents-GitHub-he-was-socrates/memory/project_mnemo_direction.md` (갱신됨 — 단일 Mnemo 메모리)

### He Was Socrates (변화: PR #43 + PR #44 머지)
- `docs/mnemo-implementation-plan.md` — 이제 포인터 스텁 (canonical은 mnemo repo)
- `docs/out-loud-master-plan.md` — "Out Loud" 마스터 플랜 (해커톤 트랙 = 이것)
- `apps/macos/HeWasSocrates/` (65 swift tests) · `apps/web/` (Next.js 16) · `packages/SocraticEngine/` — Gemma `.real` 와이어링 참조 (`Gemma/GemmaService.swift`, `Gemma/ModelIntegrity.swift` — `mlx-community/gemma-4-e4b-it-4bit`, `LLMRegistry.gemma4_e4b_it_4bit`, mlx-swift-lm 3.31.3)
- `claudedocs/2026-05-12-session-handoff.md` — 이번 세션 AM 핸드오프 (PR #43 OPEN 상태 기준)

---

## 8. 알려진 issue / open question

1. **mnemo `MnemoEngineMLX` 미존재** — Phase 3 나머지. Xcode + mlx-swift-lm + ~4GB weights.
2. **he-was-socrates untracked 잔여** — `.pf-current-run`, `apps/web/next-env.d.ts`, `runs/r-20260507-010321/*` (PreviewDD run 산출물). 무해; `apps/web/next-env.d.ts`는 `.gitignore` 추가 검토 가능.
3. **Gemma 4 컨텍스트 길이** — plan은 "128K", "Out Loud" 마스터 플랜은 "256K"로 정정한 인스턴스 있음. model card로 재확인 필요. (Mnemo 코드엔 영향 없음 — ContextBudgeter는 파라미터화됨.)
4. **mnemo SQLiteMemoryStore at-rest 암호화** — 현재 평문 SQLite + path hardening (isExcludedFromBackup, .metadata_never_index, iOS FileProtection). 진짜 at-rest 암호화 (SQLCipher 또는 앱 레이어 키)는 의도적으로 미구현 — 앱 통합 관심사 (Phase 5 vault 키). README/CLAUDE에 명시.
5. **E4B 추론 throughput vs capture cadence** — load-bearing unknown. 실측은 MLX 타겟 이후.
6. **해커톤 D-7** — "Out Loud" 트랙 결정됨; 영상/DMG/Kaggle 미존재, 대부분 다른 팀원.

---

## 9. Addendum — 같은 세션 후반 ("나머지를 완성하세요" 이후)

사용자가 "중지하지 말고 나머지를 완성하세요"라고 지시 → mnemo repo에서 의존성/Xcode 없이 가능한 모든 것을 완성. mnemo `main`은 이제 PR #1–#5 머지 상태.

**추가로 한 일 (mnemo PR #3, #4, #5 — 전부 머지, CI green)**:
- **PR #3 — Phase 3 비-MLX 완성**: `NLEmbeddingService` (Apple `NaturalLanguage` 기반 *진짜* 온-디바이스 임베딩 — 시스템 프레임워크, SPM 의존성·다운로드 없음; sentence → averaged word → hashed stub fallback, L2-정규화; 엔진 기본값은 아님 — 결정론적 테스트 위해 stub이 기본), `RecallPromptBuilder` (recall/simplify/summary 프롬프트 조립; recall 프롬프트는 contract의 `flag_for_human`/`set_reminder` 탈출구 + answer-JSON 제공), `GemmaReasoningOverFunctionCalls` (**완전한** `GemmaReasoning` — `FunctionCallGenerating` + prompt builder + parser + answer-JSON 추출기로 구성; generator가 throw하면 `StubGemmaService`로 graceful 강등 — recall 절대 hard-fail 안 함). +19 테스트 (67→86).
- **PR #4 — `MnemoEngineMLX` 패키지** (`mlx/`): `MLXGemmaGenerator: FunctionCallGenerating` over `LLMRegistry.gemma4_e4b_it_4bit` (HF `mlx-community/gemma-4-e4b-it-4bit`); `#if canImport(MLXLLM)`-가드 (MLX 없어도 컴파일 — `#else`는 throw); He Was Socrates `GemmaService.real` 패턴 미러; `mlx-swift-lm` ≥ 3.31.3 의존 + 엔진 path-의존. **별도 패키지** = 엔진 패키지의 "CLT만으로 빌드, 서드파티 SPM 의존성 0" 속성 유지. **이 환경에서 빌드/검증 안 됨** (Xcode 없음; `mlx-swift-lm`은 Metal toolchain 필요) — Mac에서 `cd mlx && swift build`로 API drift 조정 + 검증 + CI 잡 추가 필요 (`mlx/README.md`에 체크리스트). `make build-mlx` 타겟 추가. 메인 CI는 의도적으로 MLX-free.
- **PR #5 — `BlackoutPolicy`** (`Sources/MnemoEngine/Capture/`): Phase 4의 *순수 결정 로직* — `decide(source:at:appContext:calendar:) → CaptureDecision`; 우선순위: global pause → absolute time windows → recurring `DailyTimeWindow` (wall-clock minute-of-day, 자정 wrap 인지) → app-bundle blocklist (exact+prefix; screen/clipboard에만 적용). +8 테스트 (86→94).

**현재 mnemo 상태 (2026-05-12 후반)**: `main` HEAD `9b846df`. **Phase 1 ✅ · Phase 2 ◑ · Phase 3 ◑ · Phase 4 ◔**. 94 swift-testing 테스트 통과, `make ci-local` green, GitHub CI green. 엔진 라이브러리는 `swift-testing` 외 의존성 0; `mlx/` 패키지만 `mlx-swift-lm` 의존 (설계상 분리).

**여기서 멈춘 이유 (정직한 경계)**: 남은 것 — `MnemoEngineMLX`의 실제 빌드/실행, Phase 4 플랫폼 capture providers (ScreenCaptureKit/AVAudioEngine/TCC), Phase 5 macOS 앱, Phase 6 iOS, Phase 7 hardening/배포 — 은 전부 Xcode-on-Apple-Silicon + GUI 세션 + entitlement provisioning + (Phase 7) Apple Developer 계정 + ~4GB 모델 weights를 필요로 함. 이 환경엔 없음. 컴파일/테스트 안 되는 플랫폼 코드를 stub으로 채우는 건 "real code only / no partial features" 룰 위반 — 그래서 작성·구조화·문서화하되 stub으로 채우지 않음. 다음 세션은 Mac에서 시작해야 함.

**다음 세션 (Mac + Xcode 필요)**: ① `cd mlx && swift build` → `mlx-swift-lm` API drift 조정 (`MLXGemmaGenerator.swift`; He Was Socrates `GemmaService.real` 참조) → recall 출력 검증 → CI 잡 추가. ② Phase 4 플랫폼 providers. ③ Phase 5 앱. — 또는 Xcode 없이 할 수 있는 엔진-사이드: on-disk ANN 벡터 인덱스, `BlackoutPolicy`를 non-noop `CaptureControlling`에 통합.

---

End of handoff. 페어: `/handon` (다음 세션에서 이 문서 로드).
