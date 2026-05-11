---
description: 현재 세션을 다음 세션에 인계할 핸드오프 문서를 표준 형식으로 작성한다. `/handon` 페어로 사용.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
---

# /handoff — Session Handoff Document Generator

다음 세션이 컨텍스트를 빠르게 복원하고 이어서 작업할 수 있도록 표준 형식의 핸드오프 문서를 작성한다. `/handon` 명령으로 다시 로드 가능.

## 동작

1. **현재 상태 수집** (Bash):
   - `git log --oneline -10` — 최근 commit
   - `git branch --show-current` + `git status --short` — 현재 branch + working tree
   - `gh pr list --state open --json number,title,headRefName` — open PR 목록
   - `git remote get-url origin` — repo URL
   - `date +%Y-%m-%d` — 오늘 날짜
   - 환경 확인 (node/pnpm/python3 등 — 프로젝트 stack에 맞게)

2. **이전 세션 메모리 로드** (Read):
   - `claudedocs/*-session-handoff.md` — 이전 핸드오프 (있다면)
   - `~/.claude/projects/<project-hash>/memory/MEMORY.md` — 영구 메모리 index
   - 진행 중인 task list / PR 본문

3. **이 세션에서 한 작업 추출**:
   - 사용자와의 대화에서 핵심 결정 + 산출물 식별
   - 만든 파일 / 머지한 PR / 푸시한 branch / 변경한 spec
   - 미완 작업 + 막힌 지점

4. **표준 핸드오프 문서 작성**: `claudedocs/<YYYY-MM-DD>-session-handoff.md` 형식. 필수 섹션:

   - **§0 두 줄 요약** — 비기술자도 이해할 한줄 + 다음 세션 1순위 액션
   - **§1 진행한 작업 (시간순)** — Phase A/B/C/... 로 시간 진행
   - **§2 현재 상태** — git branches 표 + Live URLs + 빌드/점수 메트릭 + 환경 상태
   - **§3 다음 세션에서 할 수 있는 것** — "즉시 가능" + "사용자 입력 필요" 두 그룹
   - **§4 할 수 없는 것 (외부 변수)** — 솔직히 명시 (다른 팀원 / 외부 의존)
   - **§5 추가로 필요한 것** — 사용자 확인 필요한 항목 + 환경 점검
   - **§6 다음 세션 시작 프롬프트** — 복사-붙여넣기 가능한 plain text 블록
   - **§7 핵심 자산 위치 reference** — file path table
   - **§8 알려진 issue / open question** — 명시적

5. **시작 프롬프트 형식** (§6에 들어가는):

   ```text
   /handon

   이전 세션 핸드오프: claudedocs/<YYYY-MM-DD>-session-handoff.md

   읽고 다음 결정 사항에 답한 뒤 진행하세요:
   1. <결정 1>
   2. <결정 2>
   3. <결정 3>
   4. <결정 4>

   D-day: <마감일> (있으면)
   ```

6. **메모리 업데이트** (선택 — 영구 메모리에 핸드오프 위치 기록):
   - `~/.claude/projects/<hash>/memory/MEMORY.md` 에 한 줄 추가:
     `- [Session handoff YYYY-MM-DD](project_session_handoff.md) — <한 줄 요약>`

## 출력 규칙

- 한국어와 영어 혼용 OK (사용자가 두 언어 쓰면)
- 자유 텍스트 question 금지 — 결정 묻기는 AskUserQuestion 사용
- 객관적이고 측정 가능한 메트릭 (Lighthouse 점수, PR 수, commit hash 등)
- 미완 작업은 솔직히 "할 수 없는 것" 또는 "필요한 것"으로 분류
- marketing superlative 금지 (`완벽`, `최고`, `99% 달성` 등 검증 안 된 표현)

## 사용 방법

```bash
/handoff
# → 자동으로 현재 상태 수집 + claudedocs/<오늘-날짜>-session-handoff.md 작성
# → 작성 후 다음 세션 시작 프롬프트를 화면에 표시 (사용자 복사용)
```

## 페어 명령

- `/handon` — 이 명령으로 만든 핸드오프 문서를 다음 세션에서 로드
- 두 명령은 세트로 동작: `/handoff` (이 세션 닫기) → `/handon` (다음 세션 열기)
