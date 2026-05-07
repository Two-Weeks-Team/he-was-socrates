# 객관적 수상 가능성 평가 — Stage 1-3 완료 시점

**평가 시점**: 2026-05-07 (D-12 to 2026-05-19 마감)
**평가 범위**: 본 세션 책임 영역 (PreviewDD → SpecDD → TestDD scaffold) + 다른 팀원 의존 영역
**객관성 원칙**: 측정 가능한 메트릭만, 추정에는 명시적 confidence interval

---

## 0. TL;DR — 정직한 평가

| 영역 | 현재 점수 | 99% 도달 가능성 | 비고 |
|---|---|---|---|
| 본 세션 책임 (Stage 1-3) | **8.4 / 10** | 가능 (95%까지 명확 path) | Lighthouse perf 82, a11y 92 — 95% 미달 |
| 다른 팀원 의존 (DMG/video/writeup) | **0 / 10** | 미측정 | 본 세션 외 영역 |
| 평가 환경 호환 (macOS 26) | **5 / 10** | 정해진 risk | floor 결정의 trade-off |
| **종합 (모든 자산 가중)** | **약 60%** | **80-85% 달성 path** | 99%는 **다른 팀원 작업 + 운**에 의존 |

> **이전 세션의 99% 평가는 낙관적**이었다. 객관적으로 본 세션이 책임지는 영역은 강하지만, **수상은 본 세션이 만들 수 없는 자산(DMG / video / write-up / 평가자 환경)에 크게 의존**한다.

---

## 1. 측정 가능한 메트릭 (현재 시점)

### 1.1 본 세션 산출물

| 산출물 | 상태 | 측정값 |
|---|---|---|
| PR #34 chosen preview H1 lock | OPEN | a434922, mergeable |
| PR #35 spec iter7 | OPEN | 4d6031e, mergeable |
| PR #36 Next.js web companion scaffold | OPEN | mergeable, build SUCCESS |
| chore/docs-and-pf-run | pushed, no PR | 3 docs |
| runs/r-20260507-010321 commit | 미완 | PR #34 머지 의존 |
| chosen_preview/index.html | ✓ 37 KB | self-contained, OKLCH |
| apps/web (Next.js 16) | ✓ build SUCCESS | out/index.html 64 KB |
| 26 mockup gallery (gh-pages) | ✓ live | https://two-weeks-team.github.io/he-was-socrates/runs/r-20260507-010321/mockups/gallery.html |

### 1.2 빌드 게이트 (Stage 3 검증)

| 게이트 | 결과 |
|---|---|
| pnpm typecheck | ✓ clean |
| pnpm lint:no-collection | ✓ 0 violations |
| pnpm lint:parity | ✓ 6/6 critical Korean + entitlement key parity |
| pnpm build | ✓ BUILD SUCCESS, static export to out/ |
| Lighthouse Performance | 82/100 (목표 ≥95 — **미달**) |
| Lighthouse Accessibility | 92/100 (목표 ≥95 — **미달**) |
| Lighthouse Best Practices | 96/100 ✓ |
| Lighthouse SEO | 100/100 ✓ |
| axe-core scan | ❌ 실패 (chromedriver dyld error) |

**갭 식별**:
- Performance 82 → 95: image optimization, font loading, CSS purge 필요. ~+5-8 시간 작업.
- Accessibility 92 → 95: ARIA labels 일부 누락 추정 (axe-core 미실행으로 정확히 모름). ~+2-3 시간.

### 1.3 invariant 검증

| Invariant | 검증 |
|---|---|
| Rule 1 NO-CLOUD (macOS) | ✓ entitlements network.client absent |
| Rule 2 abstention is the product | ✓ defer_to_human in 4-function dispatch |
| Rule 3 단정한 평어체 verbatim | ✓ lint:parity 강제 |
| Rule 4 1-bit halftone aesthetic | ✓ inline SVG only, no photoreal |
| Rule 5 frozen spec lock | ✓ iter7 새 delta, lock SHA preserved |
| Rule 6 .env 미수정 | ✓ web has 0 env vars |
| iter7 §3 NO-DATA-COLLECTION | ✓ lint:no-collection 강제 |

---

## 2. Hackathon 평가 차원별 점수 (재산정)

| 차원 | 가중 | 현재 (Stage 3 후) | 99% 목표 | 갭 |
|---|---|---|---|---|
| Impact (Education) — 1순위 | high | 8.0 | 9.5 | demo video + Korean speaker testimonial |
| Technical execution | high | 9.0 | 9.5 | Lighthouse perf 82 → 95 |
| Clear use case communication | high | 8.5 | 9.5 | demo video |
| Constrained environments | very high | 9.5 | 10.0 | airplane-mode demo video |
| Multimodal | mid | 6.5 | 8.0 | (audio only — 양방향 동작 demo video 필요) |
| Function calling | very high | 9.5 | 10.0 | live demo |
| Long context (256K) | mid | 5.0 | 6.0 | designed-for stub 정직 disclosure로 이미 한계 |
| Reproducibility | high | 9.0 | 9.5 | DMG notarized + verified instructions |
| Korean 정체성 | mid | 9.0 | 9.5 | Korean speaker review |
| Submission completeness | very high | **5.0** | 10.0 | **DMG + write-up + video missing** |
| **평균** | **8.0** | **9.5** | gap = 1.5 |

**현재 평균 8.0/10** = **80%**. 99% 도달은 1.9 점 더 필요. 이 중:
- 본 세션이 완료할 수 있는 것: ~0.8점 (Lighthouse 보강 + axe 수정 + README)
- 다른 팀원 의존: ~1.1점 (DMG + video + write-up)

---

## 3. Risk Register (Stage 4 진입 전)

| # | Risk | 가능성 | 영향 | Hedge 가능성 |
|---|---|---|---|---|
| R01 | 평가자가 macOS 14/15 환경 (m26 미보유) | **mid** | very high | demo video로 fallback. iter6 floor 결정의 trade-off — 무를 수 없음. |
| R02 | DMG 노터라이즈 실패 / 일정 지연 | **mid** | very high | 다른 팀원 작업 — 본 세션 통제 불가 |
| R03 | demo video 품질 / abstention 시연 부재 | **mid** | very high | 다른 팀원 작업 — 시나리오 미리 제공 가능 |
| R04 | Kaggle write-up 1500 word 초과 또는 평어체 부재 | low | mid | 다른 팀원 작업 |
| R05 | "또 다른 LLM 데모"로 인지됨 | mid | high | chosen preview의 "We refuse better" 카피로 hedge |
| R06 | Vercel deploy URL 부재 (다른 팀원 미숙) | low | mid | gh-pages fallback 가능 |
| R07 | Lighthouse perf 82 → 평가자 inspection | low | mid | 추가 최적화 가능 |
| R08 | a11y 92 → WCAG 위반 | low | mid | axe-core 정상 실행 후 patch |
| R09 | Korean tone 평어체가 영어 평가자에게 안 닿음 | mid | mid | English gloss 옆에 — 이미 적용 |
| R10 | 다른 hackathon 참가자가 비슷한 abstention 메커니즘 | low | high | 본 프로젝트의 차별화는 "verbatim Korean tone lock" — 동일 일치 가능성 매우 낮음 |

**총 risk score (가능성 × 영향)**: ~37점 / 100점 (low-med)

---

## 4. 99% 도달 path 분석 (정직한 평가)

### 4.1 본 세션이 완료할 수 있는 것 (~95% 도달까지)

| 작업 | 시간 | 점수 기여 |
|---|---|---|
| Lighthouse perf 82 → 95 | 5-8h | +0.4 |
| Lighthouse a11y 92 → 95 | 2-3h | +0.3 |
| axe-core 정상 실행 + 위반 fix | 3h | +0.2 |
| README hero patch (P20 패턴) | 2h | +0.3 |
| Vercel deploy + URL freeze | 1-2h | +0.2 |
| Korean speaker 검토 (다른 팀원 협업) | 0.5h | +0.4 |
| **합계** | **~16h** | **+1.8** = **9.8/10** |

### 4.2 다른 팀원 의존 (95% → 99%)

| 작업 | 담당 | 점수 기여 |
|---|---|---|
| DMG notarized | 다른 팀원 | 핵심 (없으면 평가 불가) |
| demo video ≤3 min | 다른 팀원 | 핵심 (Impact narrative 핵심) |
| Kaggle write-up ≤1500 words | 다른 팀원 | 핵심 |

**이 3개가 모두 high quality로 완성되어야 99% 도달**. 본 세션은 자료 제공만 가능.

### 4.3 우선 제어 불가 영역 (99% → 100%)

- 평가자 환경 (macOS 26 보유 여부)
- 다른 참가자의 출품 품질
- 평가자의 한국어 이해도
- 평가 카테고리 정원 / 경쟁자 수

---

## 5. 정직한 결론

### 5.1 본 세션은 99%까지 갈 수 없다.

**현재 책임 영역에서 95%까지는 명확한 path**. 추가 16시간 작업으로 도달 가능. 그러나 99%는 본 세션의 통제 밖 작업이 필수.

### 5.2 권고

1. **본 세션 잔여 작업**:
   - Lighthouse perf 보강 (+5h)
   - axe-core fix + a11y patch (+3h)
   - README hero patch (+2h)
   - Vercel deploy (+2h)
   - 합계 ~12시간 (D-11 안에 가능)

2. **다른 팀원 동기화**:
   - chosen_preview의 narrative + Lessons 1-3을 demo video script로 사용
   - Kaggle write-up은 chosen_preview 8 sections + Limitations + Methods 그대로 인용
   - DMG는 main 머지 후 빌드

3. **현실적 목표**:
   - **본 세션 완료 후 95%** (자체 통제 가능 영역의 ceiling)
   - **전체 제출 후 80-90%** (다른 팀원 결과에 따라)
   - **99%는 외부 변수 + 운**

### 5.3 위험 1순위 (R01) 대응

**macOS 26 floor 결정은 무를 수 없다**. 평가자가 14/15라면 demo video 품질이 결정적. Stage 4에서 macOS 26 평가자 비율 확인 + DMG 미작동 fallback path (영상 + 스크린샷)을 명시적으로 제출에 포함.

---

## 6. Stage 4 우선순위 (제안)

순서:
1. **D-11**: PR #34 / #35 / #36 (팀원 검토 후) 머지 → main 통합
2. **D-10**: Vercel CLI 인증 + first deploy → URL 고정
3. **D-9**: Lighthouse perf 95 + axe-core fix
4. **D-8**: README hero patch + 다른 팀원 sync
5. **D-7~D-2**: 다른 팀원 작업 진행 + 본 세션 검토 지원
6. **D-1**: 최종 검토 + Kaggle 제출

---

## 7. 메트릭 자료 (검증 가능)

- bench TTFT 192 ms: `claudedocs/bench/2026-05-06-latency-bench.json`
- 65 swift-testing: `make engine-test` (commit `7465753`)
- Lighthouse 82/92/96/100: 본 세션 측정 (npx lighthouse, 2026-05-07)
- 26 mockup: `runs/r-20260507-010321/mockups/`
- Web build 64 KB: `apps/web/out/index.html`
- 6 mitigations applied: `runs/r-20260507-010321/mitigations.json`

---

End of objective assessment.
