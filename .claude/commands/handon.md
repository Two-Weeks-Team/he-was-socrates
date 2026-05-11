---
description: 현재 폴더의 가장 최근 핸드오프를 즉시 로드한다. 사용자 추가 입력 없이 자동 진행.
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# /handon — Auto-load latest handoff in current folder

이 명령은 **현재 working directory**의 `claudedocs/` 안에서 가장 최근 핸드오프 문서를 **즉시** 읽어 컨텍스트를 회복한다. 사용자에게 묻기 전에 자동으로:

1. 가장 최근 핸드오프 파일 식별
2. 본문 전체 Read
3. git/PR 현재 상태와 핸드오프 시점 비교
4. 핵심 상태 + 결정 사항을 화면에 표시

추가 입력 없이 진행하라 — 사용자는 이미 `/handon` 호출로 의도를 표명했다.

## 1단계 (필수, 즉시 실행)

```bash
# Locate latest handoff in CURRENT folder (not parent/sibling repos)
HANDOFF=$(ls -t claudedocs/*-session-handoff*.md 2>/dev/null | head -1)
echo "Latest handoff: ${HANDOFF:-NONE}"
```

- 결과가 있으면 → Read로 전체 본문 로드 (offset/limit 없이)
- 결과가 없으면 → fallback (§3) 실행

**중요**: cwd가 git repo 루트가 아니면 git repo 루트로 이동 후 검색하지 않는다. 사용자가 `/handon`을 호출한 그 폴더에 국한.

## 2단계 (필수, 자동 실행)

핸드오프 시점 이후 변화 점검:

```bash
git log --oneline -10                              # 최근 10 commits
gh pr list --state all --limit 10 --json number,title,state,mergedAt  # PR 변화
git branch --show-current                          # 현재 branch
git status --short                                 # working tree
```

핸드오프 §2 "현재 상태"와 비교:
- 새 commit 있으면 → "핸드오프 이후 N개 commit 추가" 명시
- PR merge 발생 있으면 → 어떤 PR이 merge됐는지 표시
- branch 변경 있으면 → 명시

## 3단계 (자동 실행)

영구 메모리 일치 확인:

```bash
MEM=~/.claude/projects/$(pwd | sed 's|/|-|g')/memory/MEMORY.md
[ -f "$MEM" ] && head -20 "$MEM" || echo "no memory for this project"
```

핸드오프 + 메모리가 일치하지 않으면 어느 것이 최신인지 commit/mtime으로 판단.

## 4단계 (사용자 표시)

다음 형식으로 화면에 출력:

```
✓ Loaded: claudedocs/<YYYY-MM-DD>-session-handoff.md
  Date: <handoff date> → today (<delta days>)

# 핸드오프 §0 두 줄 요약
<핸드오프의 §0 본문 그대로>

# 핸드오프 이후 변화
- 새 commit: <count> (last: <hash> "<message>")
- PR merge: <count> (#NNN ...)
- 환경: <node/pnpm/python3 버전 변경 여부>

# 다음 결정 사항 (핸드오프 §6에서)
1. <결정 1>
2. <결정 2>
...
```

## 5단계 (조건부)

핸드오프 §6의 결정 사항이 **2개 이상**이면 AskUserQuestion으로 묻기.
- 1개 이하면 묻지 않고 바로 진행
- 사용자가 이미 다음 메시지에 명시적 지시를 했다면 그것을 우선

## fallback (§3 핸드오프 없음)

```bash
# Recent .md files in claudedocs/
ls -t claudedocs/*.md 2>/dev/null | head -5
# Or .html
ls -t claudedocs/*.html 2>/dev/null | head -5
```

핸드오프 doc 0개라면 다음을 자동 시도:
1. `CLAUDE.md` Read (project root invariants)
2. `HANDOFF.md` Read (있다면)
3. `README.md` Read (한 줄 요약만)
4. 메모리 MEMORY.md 인덱스 표시
5. AskUserQuestion으로 "어떤 작업 이어가시겠어요?" — 명령 본문에 fallback context 제공

## 출력 룰

- 추측 금지. 핸드오프 + 현재 git/PR 상태에서 사실로 확인된 것만 보고.
- D-day가 있으면 남은 일수 계산 (예: `D-12 → D-8` 4일 경과)
- 환경 issue (이전 세션의 막힘) 해소 여부 점검
- marketing superlative 금지 ("완벽", "최고", "99% 달성" 같은 검증 안 된 표현)
- 자유 텍스트 질문 금지 — 결정은 AskUserQuestion 사용 (CLAUDE.md memory 룰)

## 사용 방법

```text
/handon
```

추가 인자 없음. 새 세션의 첫 메시지로 호출하면 즉시 자동 로드 + 보고 + (조건부) 결정 묻기.

## 페어

- `/handoff` — 세션 종료 시 다음 세션 인계용 핸드오프 doc 생성
- `/handon` — 새 세션 시작 시 가장 최근 핸드오프 자동 로드 (이 명령)
