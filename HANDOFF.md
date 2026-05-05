# Handoff — Gallery 2026-05-04 → SpecDD Workspace

이 문서는 갤러리(planning artifact)에서 본 repo(submission build artifact)로의 단방향 인수인계 기록입니다.

| 필드 | 값 |
|---|---|
| **From** | `/Users/kimsejun/Documents/Hackathons/hackathon-submissions/projects/gemma-4-good-hackathon/planning/gallery-2026-05-04/` |
| **To** | `/Users/kimsejun/Documents/GitHub/he-was-socrates/` (this repo) |
| **Handoff date (KST)** | 2026-05-05 |
| **Hackathon** | The Gemma 4 Good Hackathon (Kaggle / Google DeepMind) |
| **Submission deadline** | 2026-05-19 08:59 KST (= 2026-05-18 23:59 UTC) |
| **Days remaining** | ~14 |
| **Gate 1 verdict** | Picked: **#14 He Was Socrates** (PF gallery preview ID 14) |
| **Mitigation policy** | All 12 panel-dissent rules adopted in full |

---

## 1. 갤러리에서 결정된 것 (immutable)

### 1.1 선택한 preview
- **#14 He Was Socrates** (P14 The Educator, revised pivot)
- 컨셉명 의미: 소크라테스(BC 470–399 사망)는 과거형이지만, 그가 남긴 산파술(maieutics)은 현재의 사용자에게 살아 돌아온다 — *"He **Was** Socrates"*는 그 역설의 진술
- 원안 'Wonder Ledger' (paper-style notebook UI, child-only) 에서 macOS 네이티브 풀스크린 + viseme lip-sync + 어른/학생 자동 감지로 피벗
- 원본 Wonder Ledger mockup은 갤러리의 `mockups/_archive/14-wonder-ledger.html`에 보존

### 1.2 4-Panel 평가 결과 (gallery 기준)
| 패널 | #14 점수 | 비고 |
|---|---|---|
| TP (Tech) | 미컬링·미KILL | revised pivot으로 'unique-feature load-bearing' 입증 가능 |
| UP (UX) | 미평가 | revised pivot으로 D2 (tonal monoculture) 해소 candidate |
| RP (Risk) | 미평가 | COPPA flag 유지 |
| BP (Business) | 미평가 | sustainability partner 명시 의무 (D3) |

### 1.3 Mitigation 12 (모두 SpecDD에 강제 적용)
| ID | Source | Rule | 본 SpecDD에서의 적용 방식 |
|---|---|---|---|
| M01 | TP D1 | A1 inflation down-weight | thinking mode + 256K + function-call 3가지가 load-bearing임을 SPEC.md에 architecture 다이어그램으로 명시 |
| M02 | TP D2 | 26B-MoE compound risk band | 26B 미사용 (E4B만), Special Tech 미선택으로 compound 회피 |
| M03 | TP D3 | Cross-axis halo guard | TP/UP/RP/BP 점수를 항목별로 분리 측정, 가중 합산 금지 |
| M04 | UP D1 | 30s 안에 visible on-device affordance | 영상 cold open에 macOS 메뉴바 사라지는 컷 + airplane-mode 토글 + 0KB counter |
| M05 | UP D2 | tonal monoculture watch | joy/curious 어른 시나리오를 영상 첫 30초에 배치 |
| M06 | UP D3 | WCAG 2.2 AA hard floor | macOS 시스템 설정 'Accessibility'와 호환 (VoiceOver, Increase Contrast, Reduce Motion 모두 존중) |
| M07 | RP D1 | regulated-advice gate | 소크라테스는 절대 답하지 않는다 = abstention이 product mechanic 자체 |
| M08 | RP D2 | child-data COPPA flow | 학생 모드는 학교 deployment 시 부모 동의 흐름 + on-device only + 외부 송신 0 byte 명시 |
| M09 | RP D3 | agent-autonomy cap | agent 행동 없음 (관찰자·질문자만) → action × |
| M10 | BP D1 | activated SOM 2× weighted | SAM 추정에서 active wondering 사용자 정의 명시 |
| M11 | BP D2 | judge story-bias exogenous | 대응하지 말고 storytelling 30점에 max 정렬 |
| M12 | BP D3 | named sustainability partner | submission 전에 1개 NGO/EdTech 파트너 (가능: PEAK 한국·OER 커뮤니티·Khan Academy 한국지부) 접촉 또는 OSS 커뮤니티 파일럿 명시 |

### 1.4 결정된 기술 스택 (Gate 1 회의)
| 영역 | 결정 |
|---|---|
| 런타임 OS | macOS 14+ |
| 언어 | Swift + SwiftUI |
| Gemma 4 추론 | MLX-Swift, gemma-4-e4b-it-4bit (Q4 quant on-device) |
| STT | macOS Speech framework (`SFSpeechRecognizer`, on-device only) |
| TTS | AVSpeechSynthesizer (시스템 voices: 한국어 Yuna/Heami, 영어 Samantha/Alex) |
| Lip-sync | 16-viseme set + g2p (espeak-ng or 시스템 phoneme map) + 30fps frame swap (CSS-/SwiftUI-driven) |
| Wondering log | Core Data (또는 SwiftData), on-device only, JSON export 지원 |
| 풀스크린 | `NSWindow.toggleFullScreen` + `NSApplication.presentationOptions` (auto-hide menu bar) |
| 모드 감지 | Gemma function-call `mode_classify(curious_adult \| learning_student \| skeptical \| other)` |
| Special Tech bonus | **none** (Main + Future of Education = 100K+10K 풀어택) |

---

## 2. 본 Repo에 있는 것 (this repo)

| 경로 | 용도 |
|---|---|
| `HANDOFF.md` | 이 문서 |
| `README.md` | 프로젝트 1페이지 소개 |
| `LICENSE` | dual: `Apache-2.0` (code) + `CC-BY-4.0` (docs/spec/media) — Gemma 4와 hackathon winner license에 일치 |
| `.gitignore` | Swift/MLX 표준 |
| `memory/CLAUDE.md` | PF 메모리: 본 repo의 운영 규칙·금지선 |
| `memory/PROGRESS.md` | PF 메모리: cycle별 진행 로그 (append-only) |
| `memory/LESSONS.md` | PF 메모리: cross-cycle failure catalog |
| `runs/2026-05-05-spec/` | SpecDD cycle workspace |
| `runs/2026-05-05-spec/idea.spec.json` | 9-field semantic anchor (모든 advocate가 공유했어야 할 ground truth) |
| `runs/2026-05-05-spec/chosen_preview.json` | gallery #14의 6-tuple 잠금 사본 |
| `runs/2026-05-05-spec/design-approved.json` | mitigation 12개 + Gate 1 의사결정 잠금 (SHA-256 hash 추후) |
| `runs/2026-05-05-spec/blackboard/blackboard.jsonl` | PF blackboard event stream (M1 supervisor가 관찰) |
| `spec/` | SpecDD 산출물 (다음 단계에 채워짐) |
| `apps/macos/HeWasSocrates/` | Swift 앱 스캐폴드 자리 (Stage 5 scaffold에서 채워짐) |
| `packages/SocraticEngine/` | Swift Package: STT↔Gemma↔TTS↔Viseme 파이프라인 (Stage 5) |
| `docs/` | 산출물용 (writeup·architecture diagram·video script) |
| `scripts/` | viseme g2p, model 다운로드, 빌드 자동화 |

## 3. Repo에 없는 것 (gallery에 남아있음)

| 자료 | 위치 | 이유 |
|---|---|---|
| 26 advocate previews + 11 legacy 갤러리 | `~/Documents/Hackathons/hackathon-submissions/projects/gemma-4-good-hackathon/planning/gallery-2026-05-04/` | planning artifact, audit·재참조용. 변경 금지 |
| 4-Panel 풀 스윈 평가 raw output | gallery `previews.json` 안 `panels` key | audit 가능성 보존 |
| Cross-panel meta-tally seed | gallery `previews.json` 안 `cross_panel_meta_tally_seed` | 추후 다른 hackathon에서 재사용할 패턴 |
| 25개 비채택 mockup HTML | gallery `mockups/0[1-9].html`, `1[0-3,5-9].html`, `2[0-6].html` | 향후 다른 hackathon에서 fork 가능한 idea bank |
| 원안 Wonder Ledger mockup | gallery `mockups/_archive/14-wonder-ledger.html` | pivot 이전 상태 보존 |
| Hackathon 공식 source captures | `~/Documents/Hackathons/hackathon-submissions/projects/gemma-4-good-hackathon/sources/` | rules·timeline·evaluation·foundational rules HTML 원본 |
| Gemma 4 official docs (rendered) | gallery 같은 sources/ 하위 `gemma4-docs/` | 모델 카드·function calling docs 등 |

## 4. 다음 단계 (PF SpecDD entry)

본 repo에서 `/pf:bootstrap` 후 `/pf:new` fork 또는 직접 SpecDD cycle 진입:

```
PF SpecDD cycle (Stage 4):
  SPEC_LEAD
    ├─ SPEC_AUTHOR (초안: SPEC.md + function-call schema + Core Data schema + macOS app skeleton 명세)
    └─ 7 Specialist Critics (parallel evaluator-optimizer):
        ├─ SC1 a11y (VoiceOver, Reduce Motion, Increase Contrast, captions)
        ├─ SC2 api-design (function-call schema는 본 프로젝트의 'API'에 해당)
        ├─ SC3 error-model (STT/TTS 실패, 모델 OOM, viseme drift, 모드 감지 실패 등)
        ├─ SC4 i18n (한국어/영어 양립, AVSpeechSynthesizer voice fallback)
        ├─ SC5 idempotency (wondering log는 idempotent insert, retry 안전)
        ├─ SC6 performance (E4B Q4 on M-series, TTFT 6s 이하 목표, viseme 30fps no-drop)
        ├─ SC7 security (on-device only, no cloud, COPPA flow, 사칭 방지)
    → 합의 도달 시 → spec/openapi.yaml 대신 spec/function-call-schema.json + spec/core-data-schema.json + SPEC.md SHA-256 lock
    → Stage 5 scaffold 진입 (Swift Package + macOS app)
```

**중요한 PF 적응**:
- 표준 PF는 NestJS+Next.js+Prisma 가정. 본 프로젝트는 macOS 네이티브이므로 artifact를 substitute:
  - openapi.yaml → `function-call-schema.json` (Gemma 4 function-call 인터페이스)
  - prisma/schema.prisma → `core-data-schema.json` (또는 SwiftData model)
  - apps/api(NestJS) → `apps/macos/HeWasSocrates` (SwiftUI app)
  - apps/web(Next.js) → 없음 (풀스크린 데스크톱 앱이 surface)
  - packages/sdk → `packages/SocraticEngine` (Swift Package: STT↔Gemma↔TTS↔Viseme pipeline)
- Critic 7명 도메인은 그대로 적용 (a11y/api/error/i18n/idempotency/performance/security)
- 4-Panel·Auditor·Judge 단계는 hackathon 일정상 축소 가능 (단 SpecDD critic 7은 필수)

## 5. 결정 잠금 (do not re-litigate)

다음 결정들은 본 SpecDD cycle 진입 후 재론(re-litigate) 금지. 잠그지 않으면 evaluator-optimizer 루프가 무한 발산함.

1. 컨셉명 = **He Was Socrates**
2. Surface = **macOS 14+ native fullscreen**
3. 언어 = **Swift + SwiftUI** (Python 백업 옵션은 폐기)
4. 추론 = **MLX-Swift + gemma-4-e4b-it-4bit**
5. STT = **Speech framework**, TTS = **AVSpeechSynthesizer**, Lip-sync = **16 viseme + g2p + 30fps frame swap**
6. 모드 = **단일 UI · Gemma 자동 감지** (수동 선택 토글은 settings에 hidden)
7. Impact track = **Future of Education**
8. Special Tech bonus = **none**
9. 학습자 메모리 = **Core Data (또는 SwiftData)**, 256K context는 추론 시 wondering log 압축 후 주입

재론하려면 새로운 fork run을 만드세요 (PF /pf:new --fork pattern).

## 6. 영상 평가에 대한 사용자 명시

> "평가의 기준이 영상이기 때문에 실패는 할 수 있어. 검증과 재시도만 하면 되."

운영 의미:
- M-series 디바이스에서 viseme drift, TTS quality, mode detection 실패가 나면 **즉시 데모 재촬영 가능**한 testing infra를 SpecDD에 포함 (`scripts/demo-record.sh`, `scripts/verify-pipeline.sh`)
- 영상 1회 촬영 후 'shipping mode'로 freeze하지 말고, 데모-피드백-재촬영 사이클을 deadline 직전까지 허용
- SpecDD critic SC6 (performance)에서 'demo-day reliability' 단독 항목으로 검증

---

**Handoff acknowledged · SpecDD cycle ready to enter on user signal.**
