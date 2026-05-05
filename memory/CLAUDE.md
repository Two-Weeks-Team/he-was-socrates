# PF Memory · CLAUDE.md (project-scoped operating rules)

본 repo 안에서 동작하는 모든 AI agent가 읽는 공통 운영 규칙.

## 프로젝트 식별
- 이름: He Was Socrates
- 목적: The Gemma 4 Good Hackathon 제출작 (Kaggle, deadline 2026-05-19 08:59 KST)
- 트랙: Main + Impact: Future of Education
- 라이선스: Apache 2.0 (code) + CC-BY 4.0 (docs/spec)

## 절대 위반 금지
1. **클라우드 송신 0 byte**. App Sandbox > Network > Outgoing 미체크. URLSession/Network.framework 외부 host 금지.
2. **Hackathon 공식 source 변경 금지**: `~/Documents/Hackathons/hackathon-submissions/projects/gemma-4-good-hackathon/sources/` read-only.
3. **갤러리 read-only**: `.../planning/gallery-2026-05-04/` 변경 금지. 새 idea는 본 repo의 docs/ 또는 spec/.
4. **사칭 금지**: 살아있는 사람 음성·얼굴 합성 금지. 소크라테스(BC 470–399 사망)는 historical figure로 허용, but 시스템 TTS voice 그대로 사용.
5. **`.env` 변경은 사용자 명시 승인 시만**.

## SpecDD 결정 잠금 (re-litigate 금지 — `runs/2026-05-05-spec/design-approved.json` 참조)
1. 컨셉명: He Was Socrates
2. Surface: macOS 14+ native fullscreen
3. 언어: Swift + SwiftUI
4. 추론: MLX-Swift + gemma-4-e4b-it-4bit
5. STT: Speech framework, TTS: AVSpeechSynthesizer, Lip-sync: 16 viseme + g2p + 30fps
6. 모드: 단일 UI · Gemma 자동 감지
7. Impact track: Future of Education
8. Special Tech bonus: none
9. Memory: Core Data 또는 SwiftData

## Mitigation 12 적용 (HANDOFF.md §1.3 참조)
모든 산출물은 12개 mitigation rule에 부합 자체 검증.

## 코드 품질 룰
- TODO 주석으로 핵심 기능 미루기 금지
- mock·placeholder·stub 금지 (실동작 최소 구현 또는 명시적 "Stage 5 scaffold" 마커)
- pre-commit/lint/typecheck 우회 (`--no-verify`) 금지
- 라이브러리 추가 전 Package.swift 명시

## 영상 평가 운영 모드
사용자 명시: "평가의 기준이 영상이기 때문에 실패는 할 수 있어. 검증과 재시도만 하면 돼."
- 데모 영상 1회 freeze 안 함, 재촬영 사이클 deadline 직전까지 허용
- `scripts/verify-pipeline.sh`로 매 시도 전 STT·Gemma·TTS·viseme drift 자동 측정
- 실패는 PROGRESS.md 즉시 기록, LESSONS.md에 패턴 누적

## 외부 도구
- `/pf:*`, `codex:*` 호출 가능
- subagent 다수 dispatch OK
- 진입 시 본 CLAUDE.md 반드시 읽기

## 메타
| | |
|---|---|
| 작성 | 2026-05-05 KST handoff |
| 갱신 권한 | 사용자만 |
| 우선순위 | 본 파일 > User CLAUDE.md (본 프로젝트 한정) |
