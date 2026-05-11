# SPEC.md Iter-7 Amendment — Chosen-Preview Web Companion (Next.js 16 + Vercel)

| Field | Value |
|---|---|
| Authority | Preview Forge run **r-20260507-010321**, Gate H1 passed 2026-05-07 KST by user (Sejun Kim). User stack decision: Next.js 16 App Router + Vercel deploy. Submission set: notarized DMG + ≤3-min demo video + ≤1500-word Kaggle write-up; the published web companion is the surface that appears on the Kaggle entry page. |
| Source | `runs/r-20260507-010321/chosen_preview.json` (composite: P14 base + P22/P12/P18/P13/P20 references), `runs/r-20260507-010321/design-approved.json`, `runs/r-20260507-010321/chosen/index.html` (~37 KB self-contained scroll-snap, 9 sections, OKLCH, English-primary + Korean for identity surfaces) |
| Affects | New Next.js 16 web project (location TBD per build.md, candidate: `apps/web/`); Vercel deployment configuration; submission package composition. **Does NOT touch `apps/macos/HeWasSocrates/` or `packages/SocraticEngine/`.** |
| Builds on | `SPEC.md.iter2-amendment.md`, `SPEC.md.iter4-api-correction.md`, `SPEC.md.iter5-phoneme-pipeline-correction.md`, `SPEC.md.iter6-macos26-floor.md` |
| SHA-256 lock | **NOT recomputed.** Frozen v1 SHA `37538c5783ea51173a4eeccbea2b94d2cb1746a5bba9ce4a4562b6d98c1480f0` is preserved by Rule 5 of the project CLAUDE.md (`runs/2026-05-05-spec/` is read-only except for new delta documents). This file is a new delta document. |

---

## Background

The frozen `SPEC.md` covers the macOS app and the on-device Socratic engine. It does **not** cover the project's hackathon-submission surface. `The Gemma 4 Good Hackathon` (Kaggle/DeepMind, deadline 2026-05-19 KST, D-12 from this amendment) is judged from a Kaggle entry page that links the demo video, the Kaggle write-up, and a publishable web companion.

Preview Forge run `r-20260507-010321` produced 26 advocate previews and ran a 4-Panel deliberation. The user's H1 decision (2026-05-07) selected a **composite** preview rather than any single advocate output:

- **Base**: P14 *the-educator* — recursive Socratic pedagogy (4-lesson scaffold + maieutics sidebar + abstention demo as Lesson 3 highlight). The form is the message.
- **References**: P22 *the-researcher* (paper-style Limitations + numbered citations + TTFT distribution chart), P12 *the-privacy-hawk* (entitlements file inline, network.client-ABSENT highlight), P18 *the-designer* (5-act scroll-snap structure + bold serif typography), P13 *the-data-nerd* (4 KPI cards + p10/p50/p90 TTFT SVG + 7-step funnel), P20 *the-oss-maintainer* (GitHub-native badges + clone+make 30-second quickstart + Apache-2.0 + CC-BY-4.0 §2.5.a winner-grant compatibility).

The composite was synthesised into a single self-contained static HTML file at `runs/r-20260507-010321/chosen/index.html` (~37 KB, 9 sections: hero · lesson-1 · lesson-2 · lesson-3 · lesson-4 · methods · limitations · try · colophon). Aesthetic: 1-bit halftone bust + monochrome bone/ink + mint-green accent only on voted/active states, OKLCH throughout. Language policy: English-primary; Korean for identity surfaces only (system prompt verbatim, defer_to_human demo, hero subtitle, identity sidebars).

The chosen_preview.json originally listed `publish_target: "GitHub Pages (gh-pages branch root after H2)"`. The user's Stage-2 decision (2026-05-07) **supersedes** that hint with **Next.js 16 App Router + Vercel**. This amendment records the supersession and freezes the deployment contract for the web companion.

The composite is static (no backend, no DB, browser localStorage at most). The Next.js 16 spec must respect this: **static export, server components without a database layer, zero collected user data**. The plugin's default max-profile (Postgres + Docker + multi-stage CI) is over-engineered and is explicitly out of scope for this amendment.

---

## Amendment

### §1 — Chosen-preview migration to Next.js 16 App Router

The static asset at `runs/r-20260507-010321/chosen/index.html` is the **design contract** for a Next.js 16 (App Router) implementation. The migration MUST preserve, byte-equivalent where practical and visually-equivalent everywhere:

| Asset | Source | Migration target |
|---|---|---|
| Section IDs / order | `chosen/index.html` (`#hero`, `#lesson-1`..`#lesson-4`, `#methods`, `#limitations`, `#try`, `#colophon`) | Same IDs, same order, used as scroll anchors. Preserved across SPA navigation if multi-route is chosen. |
| Color tokens | `design-approved.json.design_tokens` (ink/bone/accent/warn in OKLCH) | CSS custom properties in `globals.css` or Tailwind theme config. **No semantic colour tokens.** Mitigation M02 stays in force. |
| Typography | `design-approved.json.typography` (Times New Roman serif headings; Inter sans body; JetBrains Mono code) | `next/font/local` for self-hosted Inter + JetBrains Mono (zero CDN); `Times New Roman` and `Noto Serif` chained in CSS as system-available fallbacks. Self-hosted only — no Google Fonts CDN. |
| Motion | `design-approved.json.motion` (scroll-snap y proximity; slow-fade + soft-pulse keyframes; `prefers-reduced-motion` honoured) | Same CSS keyframes preserved. `prefers-reduced-motion: reduce` MUST disable scroll-snap and animations. |
| Korean text | `chosen/index.html` (identity surfaces: hero subtitle, system-prompt block, defer_to_human demo, sidebars) | Hard-coded as React string literals (no i18n framework). Must remain visually identical to the static file. |
| TTFT SVG chart | `chosen/index.html` (inline SVG with p10/p50/p90 reference lines) | Inline SVG in a `<TTFTChart>` server component (zero JS shipped). |
| Halftone bust | source-portrait → `assets/halftone-*.png` build artifact | Imported as `next/image` with `priority` on hero, `unoptimized: true` to bypass Vercel image-CDN routing (sandbox the asset, see §3). |

The 9 sections are individually addressable via fragment URLs (`/#hero`, `/#lesson-3`, etc.) regardless of whether the final route shape is single-page or multi-route (see `runs/r-20260507-010321/spec/routes.md` for the M3-recommended structure).

### §2 — Vercel publish target

**Production target**: Vercel free-tier, default zero-config, `next build` with `output: 'export'` (static export). The static export produces a fully prerendered HTML bundle at `out/`; Vercel serves the bundle from its CDN with no serverless functions. This:

- Eliminates the serverless-function attack surface (there are no functions).
- Eliminates Edge runtime data exposure (there is no edge code).
- Eliminates the cold-start latency that would degrade the first-paint metric the chosen_preview KPI grid claims for the macOS engine.

**Custom domain**: optional. The default `*.vercel.app` subdomain is acceptable for hackathon submission; if a custom domain is added, it MUST be DNS-only (no Vercel proxy intercepting analytics).

**Vercel project config**:
- Framework preset: **Next.js**.
- Build command: `pnpm build` (which runs `next build`).
- Output directory: `out` (static export default).
- Install command: `pnpm install --frozen-lockfile`.
- Node version: **20.x LTS** (the runtime Vercel uses to *build* — the deployed asset is plain HTML/CSS/JS so no Node is in the request path).
- Environment variables: **none required**. Any environment variable defined at the Vercel project level is a spec violation unless added by a subsequent delta amendment.

**Vercel features that MUST be disabled** (hackathon-relevant trust posture):
- **Vercel Analytics** — disabled. Adds a tracking script and `/_vercel/insights/*` requests, contradicting §3.
- **Vercel Speed Insights** — disabled. Same reason as Analytics.
- **Vercel Web Analytics** — disabled. Same reason.
- **Image Optimization** — disabled (use `images.unoptimized = true` in `next.config.js`); Vercel's image CDN routes images through `_next/image` which is a server endpoint we don't want in scope.
- **Preview Deployments** — allowed for development; production submission link MUST be the production deployment URL.

### §3 — NO-DATA-COLLECTION invariant for the web companion

The macOS app's NO-CLOUD invariant (Rule 1 of `memory/CLAUDE.md`) covers the binary that runs on the user's machine. The web companion is *intentionally* cloud-deployed (Vercel CDN), so a strict NO-CLOUD rule cannot apply. A different but equally load-bearing invariant applies:

**The web companion MUST NOT collect or process any user input or telemetry.**

Concretely:

| Forbidden surface | Why it's forbidden |
|---|---|
| `<form>` elements with submission targets | The site has nothing for users to type. Adding any form re-opens an attack surface that contradicts the trust narrative. |
| `<input>`, `<textarea>`, `<select>` | Same as above. |
| `localStorage`, `sessionStorage`, `IndexedDB` writes that capture user data | Reading `prefers-color-scheme` from `matchMedia` is allowed; writing user-derived data is not. |
| Cookies | The site MUST set zero cookies, including session cookies. Vercel does not set cookies for static export by default; verify in `curl -I` headers. |
| Third-party scripts | No analytics, no font CDNs, no JS libraries from unpkg/jsdelivr. All assets self-hosted. |
| `navigator.sendBeacon`, `fetch()` to external hosts at runtime | The compiled JS bundle MUST contain zero network calls to external hosts. The build-time fetch (during `next build`) is allowed. |
| `<script>` tags with `src` pointing off-origin | Forbidden. CSP (see verification gates) enforces this. |
| Service workers | Disabled. No `next-pwa`, no manual `register()`. |
| Microphone / camera / geolocation `navigator.permissions` calls | Forbidden. The site is read-only. |

This invariant is the web-companion equivalent of the macOS app's NO-CLOUD invariant. It IS load-bearing — the abstention mechanic is the product (Rule 2 of `memory/CLAUDE.md`), and a web companion that quietly collects user data while the underlying macOS product brags about not collecting any would be a trust-narrative collapse on Kaggle's judging table.

### §4 — Submission package

The Kaggle submission references three artefacts. This amendment defines the web-companion artefact only; the other two are out of scope:

| Artefact | Owner | Status |
|---|---|---|
| Notarised DMG | macOS app teammate (out of scope for this amendment) | Existing track. iter6 floor stands. |
| Demo video ≤3 min | Recording task | Out of scope for this amendment. |
| **Web companion (Vercel-published Next.js 16 site)** | **This amendment** | Defined here, scaffolded per `runs/r-20260507-010321/spec/build.md`. |
| Kaggle write-up ≤1500 words | Authoring task | Out of scope for this amendment. May reference / link the web companion URL. |

---

## NOT changed by this amendment

- **NO-CLOUD invariant for the macOS app** — `network.client` / `network.server` entitlements remain absent in `apps/macos/HeWasSocrates/Resources/HeWasSocrates.entitlements`. The web companion's existence on Vercel does NOT relax the macOS app's posture.
- **The Korean Socratic system prompt verbatim text** in `Sources/SocraticEngine/Gemma/SystemPrompt.swift`. The web companion DISPLAYS an excerpt of this text as a code block; it does NOT modify the source.
- **The Gemma 4 E4B 4-bit MLX variant choice and the four-function dispatch contract.** The web companion documents these; it does not run them.
- **The `EngineCoordinator.Phase` enum, `Mode`, `VisemeID`, `PhonemeMap.default`, `TurnOutput`** — public engine surface unchanged.
- **`runs/2026-05-05-spec/` lock SHAs** — this amendment is a delta document at the same path, not an edit to a locked file. Lock SHA `37538c5783ea51173a4eeccbea2b94d2cb1746a5bba9ce4a4562b6d98c1480f0` is preserved.
- **macOS 26 deployment floor** (iter6) — the floor is for the binary; the web companion's browser support is a separate concern (see `build.md` browser matrix).
- **Mitigations M01–M06** (per `design-approved.json.mitigations_applied`) — all six remain in force; the migration MUST preserve their visual/semantic effect in the Next.js port.

---

## Trade-off acknowledgement

The Vercel target was chosen over GitHub Pages (the chosen_preview.json hint). Trade-offs:

- **In favour of Vercel**: First-class Next.js 16 support, instant preview URLs for design QA, zero-config static export, free tier sufficient for hackathon traffic.
- **Against Vercel**: A third-party CDN with telemetry capabilities by default. §3's invariant disables the telemetry surfaces explicitly to neutralise this.
- **Against GitHub Pages**: No first-class Next.js support (would force a custom build pipeline producing the same `out/` directory then pushing to `gh-pages`), no preview deployments, slower to iterate during the D-12 window.

Decision: Vercel with §3 enforcement. Reverting to GitHub Pages would require a follow-up delta amendment.

The Next.js 16 + App Router + static-export combination is a deliberate choice over plain static HTML hand-edited in place. Trade-offs:

- **In favour of Next.js**: React component reuse for the lesson scaffold, automatic CSS bundling, `next/image` optimisation pipeline at build time, type-safe routing if multi-route chosen, ergonomic DX for teammate handoff.
- **Against Next.js**: Larger build artefact than hand-written HTML; bundle size is the dominant Lighthouse-Performance lever and MUST be controlled (see `build.md` budget targets).
- **Against plain static HTML**: No componentisation, no font self-hosting via `next/font`, harder to maintain Korean-text identity surfaces with build-time linting.

Decision: Next.js 16. The bundle-size risk is mitigated by static export + the `build.md` ≤200 KB gzip per route ceiling.

---

## Verification gates

The amendment is satisfied when **all of**:

1. **Section parity** — every `<section id="...">` from `chosen/index.html` exists in the Next.js port at the same fragment ID, and the visual layout matches at desktop ≥1280 px and mobile ≤390 px viewports (manual screenshot diff acceptable; pixel-diff tooling not required).
2. **Mitigation parity** — M01..M06 visually preserved (see §1 table). M02 (monochrome only) verified by zero non-token colours in shipped CSS — `grep` for hex literals in the built CSS bundle returns only `#000`, `#fff`, or empty.
3. **NO-DATA-COLLECTION** — manual `curl -I https://<deployment-url>/` shows zero `Set-Cookie` headers. `grep -ri "fetch\|XMLHttpRequest\|sendBeacon" .next/` after `next build` returns zero matches in user-authored chunks (build chunks may contain framework strings; the spirit is zero runtime egress). Browser DevTools Network tab on initial load shows only same-origin requests.
4. **Lighthouse ≥95** on Performance / Accessibility / Best-Practices / SEO at desktop preset, against the production Vercel URL. Reproduce with `pnpm dlx @lhci/cli autorun` against the deployed URL.
5. **WCAG 2.2 AA** — `axe-core` reports zero violations on `/` and on each `#section` anchor. Korean-text contrast against `oklch(0.92 0.022 85)` bone background MUST clear 4.5:1.
6. **Bundle budget** — built `.next/static/chunks/*.js` total per route ≤ **200 KB gzipped** (measured by `gzip -9 -c file.js | wc -c`).
7. **Engine layer untouched** — `git diff main -- packages/SocraticEngine/` is empty after the migration PR. `git diff main -- apps/macos/` is empty. `git diff main -- runs/2026-05-05-spec/spec/` shows ONLY this new iter7 file (no edits to existing iter docs).
8. **Submission URL** — the Kaggle entry page links the production Vercel URL. The URL returns HTTP 200 and renders the hero section above the fold within ≤1.5 s on a cold Vercel CDN edge.
9. **CI** — a new `web-companion-ci` job on the PR builds the Next.js project, runs `next build`, runs `axe` on the static export, and fails on any of: type errors, lint errors, axe violations, bundle-size budget breach. The macOS CI gates remain unchanged and continue to pass.

---

## Cross-reference

- Chosen-preview composite — `runs/r-20260507-010321/chosen_preview.json`
- H1 design approval — `runs/r-20260507-010321/design-approved.json`
- Source HTML to migrate — `runs/r-20260507-010321/chosen/index.html`
- API contract (intentionally empty) — `runs/r-20260507-010321/spec/openapi.yaml`
- Route map — `runs/r-20260507-010321/spec/routes.md`
- Component breakdown — `runs/r-20260507-010321/spec/components.md`
- Build / deploy spec — `runs/r-20260507-010321/spec/build.md`
- Hackathon — The Gemma 4 Good Hackathon (Kaggle/DeepMind), submission deadline 2026-05-19 KST.
