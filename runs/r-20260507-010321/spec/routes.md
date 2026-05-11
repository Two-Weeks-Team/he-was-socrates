# Web Companion — Route Map (Next.js 16 App Router)

| Field | Value |
|---|---|
| Locked by | `runs/2026-05-05-spec/spec/SPEC.md.iter7-chosen-preview-publication.md` |
| Source design | `runs/r-20260507-010321/chosen/index.html` (9 sections, scroll-snap) |
| Stack | Next.js 16 App Router, static export (`output: 'export'`), Vercel deploy |
| Deadline pressure | D-12 to 2026-05-19 — pragmatic, not enterprise |

---

## §1 — M3 recommendation: **single-page scroll-snap** (NOT multi-route)

**Decision: keep the single-page scroll-snap structure** from `chosen/index.html`. Reasons:

1. **Narrative pacing (P18 contribution)** — the chosen_preview's 5-act dramaturgy depends on a single uninterrupted scroll. Multi-route navigation breaks the dramaturgy with route-transition flashes that degrade Lighthouse Performance and the perceived "the form is the message" effect (P14 base contribution).
2. **Korean-text identity surfaces (M05)** — the system-prompt block, the defer_to_human demo, and the hero subtitle are visually placed against monochrome ink/bone backgrounds with bone-on-ink contrast tuning. Splitting them across routes risks per-route CSS-loading flicker that breaks M02 (monochrome only).
3. **Lighthouse Performance ≥95 budget** — multi-route navigation in App Router static export still requires a route-segment HTML payload per page, multiplying the gzip baseline. Single-page is the cheapest path to the budget.
4. **Search engine + Kaggle judge UX** — a single canonical URL is easier to link from the Kaggle entry page. Anchor-based deep links (`/#lesson-3`) cover the "I want to share lesson 3 specifically" use case without route fragmentation.
5. **TestDD scope reduction** — single-page means one route to test, axe, and Lighthouse-audit. Multi-route would multiply the TestDD matrix by the number of pages with no proportional gain in trust signal.

The trade-off accepted: the single-page bundle is heavier than any individual multi-route page would be. This is mitigated by `build.md`'s ≤200 KB gzip per-route ceiling, which the 9-section payload can stay under (the source HTML is ~37 KB; component-isation and Tailwind utility classes will inflate by ~3-4×, landing at ~120-150 KB gzip with React 19 + Next.js 16 client runtime — within budget).

---

## §2 — App Router file tree (single-page form)

```
apps/web/
├── app/
│   ├── layout.tsx              # Root layout: fonts, metadata, ProgressRail, theme
│   ├── page.tsx                # The single page: composes 9 section components in order
│   ├── globals.css             # OKLCH custom properties, scroll-snap, prefers-reduced-motion
│   ├── icon.png                # Favicon (halftone bust 32×32 derivation)
│   ├── apple-icon.png          # 180×180
│   ├── opengraph-image.png     # 1200×630 OG card (halftone bust + project title)
│   ├── twitter-image.png       # 1200×600 Twitter card (same aesthetic)
│   ├── robots.ts               # Allow all (it's a public hackathon entry)
│   └── sitemap.ts              # Single URL — production root
├── components/
│   └── ... (see runs/r-20260507-010321/spec/components.md)
├── public/
│   ├── halftone-bust.png       # Hero image (build artefact, copied from assets/)
│   ├── viseme-strip.png        # 16-cell viseme strip (Lesson 1)
│   └── fonts/
│       ├── Inter-Regular.woff2
│       ├── Inter-Medium.woff2
│       ├── Inter-SemiBold.woff2
│       └── JetBrainsMono-Regular.woff2
├── next.config.ts              # output: 'export', images.unoptimized: true
├── tsconfig.json
├── package.json
└── pnpm-lock.yaml
```

The `app/` tree has **only one route segment** (`/`), but multiple section components composed inside `page.tsx`. This is the single-page interpretation of App Router.

---

## §3 — Routes table (single-page recommendation)

| Path | Purpose | Anchors served | Server/Client component |
|---|---|---|---|
| `/` | The single page. Composes all 9 sections in scroll order: hero → lesson-1 → lesson-2 → lesson-3 → lesson-4 → methods → limitations → try → colophon. | `#hero`, `#lesson-1`, `#lesson-2`, `#lesson-3`, `#lesson-4`, `#methods`, `#limitations`, `#try`, `#colophon` | Server (RSC) — every section is a server component. The only client components are interactive primitives: `<CopyButton>` inside `<TryBlock>` and `<AbstentionDemo>` for the 3-screen state machine. |

**Anchor URL contract**: every fragment ID listed above MUST be reachable via `https://<deployment>/#<id>` and MUST scroll the corresponding section to the viewport. Browsers honour this natively for `<section id="...">`; the spec verification gate is a curl + grep:

```bash
curl -s https://he-was-socrates.vercel.app/ | grep -E 'id="(hero|lesson-1|lesson-2|lesson-3|lesson-4|methods|limitations|try|colophon)"' | wc -l
# expected: 9
```

---

## §4 — Multi-route alternative (REJECTED but documented for traceability)

A multi-route shape was considered:

| Path | Section content |
|---|---|
| `/` | Hero + Lesson 0 anchor |
| `/lessons/1` | Lesson 1: Hold Spacebar |
| `/lessons/2` | Lesson 2: 단정한 평어체 |
| `/lessons/3` | Lesson 3: We refuse better |
| `/lessons/4` | Lesson 4: On-device by entitlement |
| `/methods` | 4-function dispatch + funnel |
| `/limitations` | Designed-for honest disclosure |
| `/try` | Clone + make commands |
| `/about` | Colophon |

**Rejected because**:
- Breaks P18 narrative pacing (cited above).
- Multiplies bundle baseline by ~9× (each route segment carries the React + Next runtime).
- Adds 9 axe + Lighthouse runs to the TestDD matrix.
- The chosen_preview.json structure list is ordered by scroll position, not by URL hierarchy — adopting a URL hierarchy would invent semantics the design did not specify.
- Korean-text identity surfaces span multiple lessons (cross-lesson sidebars on system prompt + identity); cleaving them into separate routes loses the cross-reference visual.

The multi-route shape MAY be reconsidered post-hackathon for SEO reasons. For the 2026-05-19 deadline submission, single-page is locked.

---

## §5 — Special routes (App Router conventions)

These are not user-facing routes but Next.js conventions Next.js 16 expects:

| File | Purpose | Required? |
|---|---|---|
| `app/not-found.tsx` | 404 page. The single-page design has no real 404 path (only `/` exists), but App Router requires this for graceful handling of typo'd URLs like `/lesson-1` (without the slash hash). | **Yes**. Renders a minimal "Lost? → /" page in the same monochrome aesthetic. |
| `app/icon.png`, `app/apple-icon.png`, `app/opengraph-image.png`, `app/twitter-image.png` | Favicon and social cards generated automatically by Next.js from these files. | **Yes** — sets the Kaggle judge's link-preview surface. |
| `app/robots.ts` | Allows all crawlers (it's a public hackathon submission, not a private staging URL). | **Yes**. |
| `app/sitemap.ts` | Lists the single canonical URL with `lastModified: new Date()`. | **Yes**. |
| `app/manifest.ts` (PWA manifest) | **NOT created.** SPEC.md.iter7 §3 forbids service workers and PWA installation prompts. Defining a manifest invites browsers to offer "install this app" affordances inconsistent with the read-only narrative. | **No**. |

---

## §6 — Verification

The route map is satisfied when:

1. `app/` directory contains exactly one route segment (`/`) plus the special files in §5.
2. The 9 anchors (`#hero`, `#lesson-1`, `#lesson-2`, `#lesson-3`, `#lesson-4`, `#methods`, `#limitations`, `#try`, `#colophon`) are reachable on the deployed URL and scroll to their corresponding sections.
3. The grep verification in §3 returns `9`.
4. `app/manifest.ts` does NOT exist (PWA manifest forbidden).
5. `app/not-found.tsx` exists and renders in the same monochrome aesthetic.
