---
description: 가장 최근 핸드오프 문서를 읽어 컨텍스트를 복원하고 사용자에게 결정 사항을 묻는다. `/handoff` 페어.
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# /handon — Session Resumption from Handoff

이전 세션의 `/handoff` 결과를 자동으로 로드하여 새 세션에서 컨텍스트를 회복한다.

## 동작

1. **가장 최근 핸드오프 문서 식별** (Bash + Glob):
   ```bash
   ls -t claudedocs/*-session-handoff*.md 2>/dev/null | head -1
   ```
   가장 최근 mtime 핸드오프 파일을 찾아 Read.

2. **현재 git/PR 상태와 핸드오프 시점 비교** (Bash):
   - `git log --oneline -5` — 핸드오프 시점 이후 commit 있는지
   - `gh pr list --state open --json number,title,state,mergedAt` — PR 상태 변화
   - `git branch --show-current` — 현재 branch
   - 만약 핸드오프 이후 변경 사항이 있으면 명시적으로 표시

3. **메모리 메모리 자동 로드** (Read):
   - `~/.claude/projects/<project-hash>/memory/MEMORY.md`
   - 핸드오프와 메모리가 일치하지 않으면 어느 것이 최신인지 판단 + 보고

4. **컨텍스트 복원 요약 출력** — 사용자에게 다음 항목 보고:
   - 마지막 핸드오프 일자 + 파일
   - 그 이후 main / branch 변화 (commit / PR merge 등)
   - 진행 중이었던 작업 (§1 시간순 마지막 phase)
   - 미완 작업 + 막힌 지점 (§3-5)
   - **다음 세션에서 답할 결정 사항** (§6 시작 프롬프트의 결정 항목)

5. **결정 사항을 AskUserQuestion으로 묻기**:
   - 핸드오프 §6에 명시된 4개 이하의 결정 사항을 AskUserQuestion으로 제시
   - 5개 이상이면 우선순위 4개로 압축 또는 분할 round
   - **자유 텍스트 질문 금지** (CLAUDE.md memory feedback_always_use_askuserquestion 룰)

6. **답변 후 진행**:
   - 사용자가 답한 결정에 따라 다음 작업 시작
   - 핸드오프의 §3 "즉시 가능" 항목 중 사용자 우선순위에 맞춰 진행

## 출력 규칙

- 핸드오프 시점부터 현재까지 시간 경과 명시 (예: D-12 → D-8)
- 외부 변화 (다른 팀원 commit, PR merge) 있으면 노출
- 환경 issue (이전 세션의 막힘) 해소 여부 점검
- 추측 금지 — 핸드오프 + 현재 상태에서 사실로 확인된 것만 보고

## 사용 방법

```bash
/handon
# → 가장 최근 핸드오프 문서 자동 로드
# → 현재 상태와 diff 보고
# → AskUserQuestion으로 결정 사항 물음
# → 답변에 따라 작업 시작
```

## 페어 명령

- `/handoff` — 다음 세션을 위해 이번 세션 핸드오프 문서 생성
- `/handon` — 이번 명령 (이전 핸드오프 로드)

## fallback

핸드오프 문서가 없으면 (`claudedocs/*-session-handoff*.md` 0개):
- `claudedocs/` 전체에서 가장 최근 수정된 `.md` / `.html` 파일 5개 나열
- 사용자에게 AskUserQuestion으로 컨텍스트 소스 결정 받기
- CLAUDE.md / README.md / 메모리 기반 fallback 컨텍스트 회복
