# Web Companion — Build & Deploy Spec

| Field | Value |
|---|---|
| Locked by | `runs/2026-05-05-spec/spec/SPEC.md.iter7-chosen-preview-publication.md` |
| Stack | **Next.js 16 (App Router) · React 19 · TypeScript 5.6+ · Tailwind CSS 4 · pnpm 9** |
| Output | **Static export** (`output: 'export'` → `out/`) — no Node.js in request path |
| Host | **Vercel** free tier, framework preset `Next.js`, default project config |
| Repo location | `apps/web/` (sibling to `apps/macos/`, does NOT touch the macOS app or the engine) |
| Browser support | Last 2 versions of Chrome/Edge/Firefox/Safari + Safari 17.4+ on macOS 14+ |
| Submission deadline | 2026-05-19 KST (D-12 from this spec) |

---

## §1 — Project bootstrap

```bash
# From repo root
mkdir -p apps/web
cd apps/web
pnpm create next-app@latest . \
  --ts \
  --app \
  --tailwind \
  --src-dir false \
  --eslint \
  --import-alias "@/*" \
  --no-turbopack    # Stable build first; turbopack production builds opt-in later if needed
```

Then immediately:

```bash
# Pin Next.js 16 (the bootstrap may install latest; explicit pin avoids drift)
pnpm add next@16 react@19 react-dom@19
pnpm add -D typescript@^5.6 @types/react@^19 @types/react-dom@^19 @types/node@^22

# A11y + lint
pnpm add -D eslint-plugin-jsx-a11y@^6 axe-core@^4.10
```

**No additional UI library.** No shadcn/ui, no Radix, no Headless UI. The component count (per `components.md`) is small and bespoke; pulling in a UI library inflates the bundle past the §5 budget.

**No CSS-in-JS.** Tailwind 4 + `globals.css` for OKLCH custom properties is sufficient. Styled-components / Emotion / styled-jsx-runtime would inflate the bundle.

---

## §2 — `next.config.ts` (locked shape)

```ts
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Static export — no Node in request path, no serverless functions.
  output: 'export',

  // Bypass Vercel image-CDN routing. Static export does not support next/image
  // optimisation anyway; explicit unoptimized prevents accidental egress.
  images: {
    unoptimized: true,
  },

  // Trailing slash off — cleaner anchor URLs (`/#hero` not `//#hero`).
  trailingSlash: false,

  // Skip Powered-By header (minor footprint, removes a server identity hint).
  poweredByHeader: false,

  // Strict mode for React 19.
  reactStrictMode: true,

  // No experimental flags. Stability over novelty for the D-12 window.
  experimental: {},

  // Forbid runtime env access in client bundles. Static export should not
  // be using any env vars (per SPEC.md.iter7), so this is belt-and-braces.
  env: {},
};

export default nextConfig;
```

---

## §3 — Tailwind 4 config

```css
/* app/globals.css */
@import "tailwindcss";

@theme {
  --color-ink: oklch(0.07 0.008 280);
  --color-bone: oklch(0.92 0.022 85);
  --color-accent: oklch(0.85 0.140 165);
  --color-warn: oklch(0.78 0.130 75);

  --font-serif: "Times New Roman", "Noto Serif", Georgia, serif;
  --font-sans: "Inter", -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
  --font-mono: "JetBrains Mono", "Fira Code", ui-monospace, monospace;
}

/* Scroll-snap (no-preference only — disabled for prefers-reduced-motion) */
@media (prefers-reduced-motion: no-preference) {
  html {
    scroll-snap-type: y proximity;
    scroll-behavior: smooth;
  }
  section {
    scroll-snap-align: start;
  }
}

/* Reduced-motion path */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

The four colour tokens are the **only** colour vocabulary. M02 (monochrome only) is enforced by the lint in §6.

---

## §4 — Font loading (self-hosted, zero CDN)

```ts
// app/layout.tsx (excerpt)
import localFont from 'next/font/local';

const inter = localFont({
  src: [
    { path: '../public/fonts/Inter-Regular.woff2', weight: '400' },
    { path: '../public/fonts/Inter-Medium.woff2', weight: '500' },
    { path: '../public/fonts/Inter-SemiBold.woff2', weight: '600' },
  ],
  display: 'swap',
  variable: '--font-inter',
});

const jetbrains = localFont({
  src: [
    { path: '../public/fonts/JetBrainsMono-Regular.woff2', weight: '400' },
  ],
  display: 'swap',
  variable: '--font-jetbrains',
});
```

`Times New Roman` and `Noto Serif` are not self-hosted — they're chained as system fallbacks. macOS ships Times New Roman natively; modern Linux ships Noto Serif via fontconfig defaults; Windows ships Times New Roman natively. The serif headings degrade gracefully across platforms without us shipping a heavy serif WOFF2.

**No Google Fonts CDN.** Loading Inter from `fonts.googleapis.com` is an external network call that the iter7 §3 invariant forbids.

---

## §5 — Bundle budget

The Lighthouse Performance ≥95 target requires a tight bundle. The locked budgets:

| Asset class | Budget | Measurement |
|---|---|---|
| Total **gzipped** JS per route | ≤ **200 KB** | `gzip -9 -c .next/static/chunks/*.js \| wc -c`, summed |
| Total **gzipped** CSS | ≤ **30 KB** | same, on `.next/static/css/*.css` |
| Hero image (halftone bust PNG) | ≤ **80 KB** | `wc -c public/halftone-bust.png` |
| Viseme strip PNG | ≤ **40 KB** | same |
| First Contentful Paint (3G Fast) | ≤ **1.5 s** | Lighthouse |
| Largest Contentful Paint (3G Fast) | ≤ **2.5 s** | Lighthouse |
| Total Blocking Time | ≤ **200 ms** | Lighthouse |
| Cumulative Layout Shift | ≤ **0.1** | Lighthouse |
| Web fonts total | ≤ **120 KB** | `wc -c public/fonts/*.woff2`, summed |

A `pnpm budget` script (`scripts/check-budget.mjs`) enforces these in CI; budget breach fails the build.

---

## §6 — Build pipeline & verification gates

```bash
# Top-level build sequence (apps/web/)
pnpm install --frozen-lockfile
pnpm typecheck                     # tsc --noEmit
pnpm lint                          # eslint + jsx-a11y
pnpm lint:no-collection            # scripts/lint-no-collection.mjs (iter7 §3 enforcement)
pnpm lint:parity                   # system-prompt + entitlements byte-equivalence to macOS sources
pnpm lint:monochrome               # grep CSS for colour literals; fail on non-token hex
pnpm build                         # next build → out/
pnpm budget                        # scripts/check-budget.mjs
pnpm a11y                          # axe-core against the static export served from a temp http-server
```

Each step is run by Vercel during the deploy, AND by the local `make ci-web` target (added to the repo Makefile alongside the existing `ci-local`).

### `lint:no-collection` (iter7 §3 enforcement)

`scripts/lint-no-collection.mjs` greps `app/` + `components/` for these patterns and exits 1 on any match:

```
\b<form\b
\b<input\b
\b<textarea\b
\b<select\b
\bnavigator\.sendBeacon\b
\bfetch\s*\(
\bXMLHttpRequest\b
\blocalStorage\.(setItem|removeItem|clear)\b
\bsessionStorage\.(setItem|removeItem|clear)\b
\bindexedDB\.\w+
\bregisterServiceWorker\b
\bnavigator\.serviceWorker\.register\b
\bsrc=["']https?://(?!localhost)
```

The `fetch(` rule has explicit exceptions for build-time scripts (under `scripts/`); only `app/**` and `components/**` are scanned.

### `lint:parity`

Two scripts:

- `scripts/parity-system-prompt.mjs` — reads `Sources/SocraticEngine/Gemma/SystemPrompt.swift`, extracts the `let SOCRATIC_SYSTEM_PROMPT_KO = """ … """` literal, compares byte-for-byte to the Korean string in `<SystemPromptBlock>` JSX.
- `scripts/parity-entitlements.mjs` — reads `apps/macos/HeWasSocrates/HeWasSocrates/Resources/HeWasSocrates.entitlements`, compares to the inlined entitlements code block in `<EntitlementBlock>` JSX.

A drift fails the build. This is what keeps the web companion's narrative claims (NO-CLOUD, Korean prompt verbatim) honest without hand-editing two places.

### `lint:monochrome`

`scripts/lint-monochrome.mjs` greps `app/` + `components/` for hex colour literals (`#[0-9a-fA-F]{3,8}`) and `rgb(...)` / `hsl(...)` calls. Allowed: `#000`, `#fff`, `transparent`. Anything else fails the build (M02 enforcement).

### `a11y`

```bash
pnpm dlx http-server out -p 8123 &
SERVER_PID=$!
sleep 1
pnpm dlx @axe-core/cli http://localhost:8123/ --exit
KILL_RC=$?
kill $SERVER_PID
exit $KILL_RC
```

Axe runs against the static export. Zero violations required for green.

### Lighthouse (manual + CI)

Local manual: `pnpm dlx @lhci/cli autorun --config=.lighthouserc.json` against the deployed Vercel preview URL.

CI: same command in a `web-companion-lighthouse` GitHub Actions job that runs on PR. Performance ≥95, A11y ≥95, Best-Practices ≥95, SEO ≥95.

---

## §7 — Vercel deployment

**Project setup** (one-time, performed by user via Vercel dashboard or CLI):

```bash
# From apps/web/
pnpm dlx vercel link
pnpm dlx vercel --prod=false   # First push as preview to validate
```

**Project settings (Vercel dashboard)**:

| Setting | Value | Why |
|---|---|---|
| Framework Preset | Next.js | Auto-detected. |
| Build Command | `pnpm build` | Default. |
| Output Directory | `out` | Static export. |
| Install Command | `pnpm install --frozen-lockfile` | Reproducibility. |
| Node.js Version | `20.x` | LTS, matches local. |
| Vercel Analytics | **OFF** | iter7 §3. |
| Vercel Speed Insights | **OFF** | iter7 §3. |
| Web Analytics | **OFF** | iter7 §3. |
| Image Optimization | N/A (static export disables it; `unoptimized: true` belt-and-braces) | iter7 §3. |
| Environment Variables | **None** | iter7 §3 (no env access in client bundles). |
| Custom Domain | Default `*.vercel.app` for hackathon. Optional custom domain post-submission. | Simplicity for D-12. |

**Production deploy** (gated by user on H2 approval):

```bash
pnpm dlx vercel --prod
```

**Submission URL**: the production deployment URL (e.g. `https://he-was-socrates.vercel.app/`). The Kaggle entry page links this URL.

---

## §8 — Asset-pipeline integration

The macOS app's `make assets` target produces 17 PNGs in `assets/`. The web companion needs **two** of them: the front-facing halftone bust and the 16-cell viseme strip.

A new `scripts/copy-web-assets.sh` script handles the cross-tree copy:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
SRC_BUST="$ROOT/assets/halftone-front.png"
SRC_VISEMES="$ROOT/assets/viseme-strip.png"   # if not produced, build a tile from per-viseme PNGs
DEST="$ROOT/apps/web/public"
[ -f "$SRC_BUST" ] || { echo "Run 'make assets' first"; exit 1; }
cp "$SRC_BUST" "$DEST/halftone-bust.png"
[ -f "$SRC_VISEMES" ] && cp "$SRC_VISEMES" "$DEST/viseme-strip.png"
```

The script is invoked manually before `pnpm build`. The web build does NOT trigger `make assets` — that's the macOS toolchain's responsibility, and gating the web build on Pillow + numpy is unwanted coupling.

---

## §9 — Browser matrix

| Browser | Version | Status |
|---|---|---|
| Safari (macOS) | 17.4+ | **Primary** (the macOS app's audience uses this). |
| Chrome (any OS) | last 2 versions | Required (Kaggle judges' likely browser). |
| Edge (Windows) | last 2 versions | Required. |
| Firefox (any OS) | last 2 versions | Required. |
| Safari (iOS) | iOS 17+ | Best-effort (mobile not the primary surface but should not break). |
| Chrome (Android) | last 2 versions | Best-effort. |

OKLCH colour support is universal across all listed browser versions (Safari 16.4+, Chrome 111+, Firefox 113+). No fallback colours required.

---

## §10 — Verification (full)

The build + deploy spec is satisfied when **all of**:

1. `apps/web/` exists at the repo root, sibling to `apps/macos/`.
2. `pnpm install --frozen-lockfile && pnpm build` succeeds in `apps/web/`.
3. All §6 lint scripts pass (`no-collection`, `parity`, `monochrome`).
4. `out/` is produced; serving it locally renders the same 9 sections as `chosen/index.html`.
5. Bundle budget (§5) is met.
6. Lighthouse on the deployed Vercel URL: ≥95 on all 4 axes.
7. axe-core: zero violations.
8. iter7 §3 invariants verified: zero `Set-Cookie` headers, zero off-origin runtime requests on initial load, zero forms.
9. The Vercel project has Analytics, Speed Insights, and Web Analytics OFF.
10. The macOS CI gates (`make ci-local`, the existing `.github/workflows/ci.yml` jobs) remain green and unchanged.
11. The submission URL is recorded in the Kaggle write-up draft.

---

## §11 — Estimated effort (D-12 sanity check)

| Phase | Effort | Owner |
|---|---|---|
| Project bootstrap + config (§1-§4) | ~2 hours | Web companion track |
| Component port (per `components.md`) | ~12 hours | Web companion track |
| Lint scripts (§6) | ~3 hours | Web companion track |
| Vercel setup + first deploy (§7) | ~1 hour | User (one-time) |
| Bundle / Lighthouse / axe iteration | ~4 hours | Web companion track |
| Asset copy + parity verification (§8) | ~1 hour | Web companion track |
| **Total** | **~23 hours** | One developer working ~3 hours/day fits in D-12. |

The macOS DMG, the demo video, and the Kaggle write-up are parallel tracks not gated by this spec.
