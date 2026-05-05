# He Was Socrates

> *macOS 풀스크린 위에 살아 돌아온 산파술. 듣고, 생각하고, 답하지 않는다 — 단 묻는다.*

A submission for **The Gemma 4 Good Hackathon** (Kaggle / Google DeepMind, deadline 2026-05-19 08:59 KST).

## What

전체 화면이 한 명의 소크라테스가 되어, 사용자의 발화를 듣고 (Speech framework), 256K wondering log를 가로질러 생각하고 (Gemma 4 E4B + thinking mode), 입 모양을 동기화해 (16-viseme @30fps + AVSpeechSynthesizer) 단 한 가지 행위만 수행하는 macOS 네이티브 앱: **답하지 않고 역질문한다**.

| 발화 | 응답 |
|---|---|
| "왜 어떤 노래는 들으면 우는지?" | "그 노래를 처음 들은 건 누구와 함께였나?" |
| "얼음이 왜 미끄럽지?" | "미끄러운 건 얼음 때문일까, 네 손가락이 밀어낸 무엇 때문일까?" |
| "지구는 왜 둥글까?" | "네가 만져본 가장 큰 둥근 것은? 그것이 둥근 이유가 같을까?" |

단일 UI, Gemma 4의 function-call이 사용자의 톤·복잡도로 모드를 자동 분류한다 — 어른은 호기심, 학생은 배움, 둘 다 같은 얼굴 앞에서.

## Why

- **사용자에게**: 답을 받는 챗봇은 이미 많다. 답하지 않는 도구는 거의 없다. 본 앱의 KPI는 **Gemma가 답하지 않은 횟수** — 그 후 48시간 내 사용자가 직접 답한 비율.
- **Gemma 4 unique features를 load-bearing**: thinking mode (가시화), 256K context (다년 wondering log), native function calling (mode_classify·surface_past_wonder·defer_to_human·ask_back). 셋 중 하나만 빠져도 product가 성립하지 않음.
- **Privacy**: 모든 추론·STT·TTS·로그는 on-device only. 0 byte cloud. macOS 시스템 권한 'Microphone'·'Speech Recognition' 둘만 요청.
- **Future of Education + Curious Adult** 두 페르소나를 단일 인터페이스로.

## Stack

| 레이어 | 기술 |
|---|---|
| OS | macOS 14+ |
| UI | Swift + SwiftUI (fullscreen, menu-bar auto-hide) |
| Gemma 4 | MLX-Swift, gemma-4-e4b-it-4bit (on-device, ~3.97GB peak) |
| STT | Speech framework (`SFSpeechRecognizer`, on-device only) |
| TTS | AVSpeechSynthesizer (시스템 voices) |
| Lip-sync | 16 viseme + g2p + 30fps frame swap |
| Memory | Core Data / SwiftData |
| Distribution | DMG (notarized) + Apache 2.0 OSS |

## Status

- **2026-05-04 KST**: PreviewDD (26 advocates) → 4-Panel 평가 → Gate 1 picked #14
- **2026-05-05 KST**: Pivot to macOS native + viseme + adult/student 자동 감지. Handoff to this repo.
- **다음**: SpecDD cycle (SPEC.md + function-call schema + Core Data schema + 7 critic evaluator-optimizer)

자세한 내력은 [`HANDOFF.md`](./HANDOFF.md) 참고.

## Layout

```
he-was-socrates/
├── HANDOFF.md              # 갤러리 → 이 repo 인수인계
├── README.md               # 본 파일
├── LICENSE                 # Apache-2.0 (code) + CC-BY-4.0 (docs)
├── memory/                 # PF cross-cycle memory
│   ├── CLAUDE.md           # 운영 규칙·금지선
│   ├── PROGRESS.md         # cycle별 진행 로그
│   └── LESSONS.md          # cross-cycle 실패 카탈로그
├── runs/
│   └── 2026-05-05-spec/    # 활성 SpecDD cycle
│       ├── idea.spec.json
│       ├── chosen_preview.json
│       ├── design-approved.json
│       └── blackboard/
├── spec/                   # SpecDD 산출물 (Stage 4 결과)
├── apps/macos/HeWasSocrates/
├── packages/SocraticEngine/
├── docs/                   # writeup·architecture diagram·video script
└── scripts/                # demo recording, viseme g2p, model 다운로드
```

## Hackathon facts (compressed)

| | |
|---|---|
| Sponsor | Google LLC (Google DeepMind) via Kaggle |
| Prize | $200K (Main 100K · Impact 5×10K · Special Tech 5×10K) |
| Submission | Writeup ≤1500w + YouTube ≤3min + public repo + live demo + media |
| Rubric | Impact 40 / Story 30 / Tech 30 |
| Deadline | 2026-05-19 08:59 KST |
| Winner license | CC-BY 4.0 |

본 프로젝트의 트랙 선택: **Main + Impact: Future of Education** (Special Tech bonus 미선택).

## License

- **Code**: Apache-2.0 (Gemma 4와 일치)
- **Docs / Spec / Media**: CC-BY-4.0 (hackathon winner license와 일치)

자세히는 [`LICENSE`](./LICENSE).

## Acknowledgements

이 프로젝트의 ideation은 `Two-Weeks-Team` 의 26-advocate Preview Forge 갤러리(2026-05-04)에서 도출되었으며, 4-Panel 평가(Tech / UX / Risk / Business 40명 simulation) + Mitigation 12 권고를 모두 수용했습니다. 갤러리 원본은 `hackathon-submissions/projects/gemma-4-good-hackathon/planning/gallery-2026-05-04/`에 read-only로 보존됩니다.
