# Contributing to He Was Socrates

Thanks for looking. A few honest notes before you spend time on a patch.

## Welcome

This repository is a **hackathon submission** for [The Gemma 4 Good Hackathon](https://www.kaggle.com/competitions/gemma-4-good-hackathon) (deadline **2026-05-19 08:59 KST**). Until that deadline passes, iteration is tightly scoped to what gets the demo video shot and the Writeup polished — most external PRs will be deferred. After 2026-05-19, normal open-source contribution opens up and this document becomes the canonical guide.

If you're reading this in **post-submission** mode, welcome — let's talk.

## Code of Conduct

Participation in this project is governed by the [Code of Conduct](CODE_OF_CONDUCT.md) (Contributor Covenant 2.1). Reports go to `app.2weeks@gmail.com`.

## Before you start

1. Read **[SETUP.md](SETUP.md)** end-to-end and get a working dev environment. The engine layer (`packages/SocraticEngine`) builds with CommandLineTools alone; the `.app` target needs full Xcode 15.2+ and an Apple Silicon Mac.
2. Read **[README.md](README.md)** — particularly the "What this is" and "Architecture" sections — to understand what the bust does and (more importantly) what it deliberately does *not* do.
3. Skim **`runs/2026-05-05-spec/spec/SPEC.md`** for the locked spec, and **`runs/2026-05-05-spec/spec/user-ratifications.md`** for items (a)–(m) that record where the design was deliberately constrained.

## What we'll accept

- **Bug fixes** — accessibility (VoiceOver, Reduce Motion, Increase Contrast), the COPPA child-mode flow, performance regressions on supported hardware (M2 Pro+).
- **Voice/language extensions** — adding a new register via the `SystemPrompt` extension contract. The Korean Socratic prompt is locked, but English Stoic, Latin scholastic, and Japanese 禅問답 are explicitly named in `docs/writeup-draft.md` as future variants. Each one is its own composed `SystemPrompt`.
- **Asset pipeline improvements** — `scripts/halftone.py` and `scripts/viseme_compose.py` are deterministic build-time tooling. Speedups, reproducibility fixes, and cross-platform Pillow quirks are all in scope.
- **SocraticEngine refactors that preserve the public API surface.** The following symbols are stable and must not change shape without a delta document:
  - `Mode`
  - `VisemeID`
  - `PhonemeMap.default`
  - `EngineCoordinator.Phase`
  - `TurnOutput`

## What we'll NOT accept (yet)

- **Modifications to frozen SpecDD artifacts in `runs/2026-05-05-spec/`.** All changes there go through delta documents — see the established pattern in `SPEC.md.iter2-amendment.md` and `SPEC.md.iter4-api-correction.md`. The lock SHA `e5dfadf2c8…314c5` must never be recomputed casually.
- **Cloud network calls.** Any feature that introduces a `com.apple.security.network.client` or `network.server` entitlement requirement is out. Zero bytes leave the device. Ever. This is not a guideline — it's the product.
- **Anything that breaks the abstention mechanic.** The bust must never become an answering machine. `defer_to_human` is load-bearing. PRs that "improve" the bust by letting it solve user problems will be closed.
- **Korean honorifics (존댓말).** The locked Korean Socratic prompt mandates **단정한 평어체** — neither polite-form nor friendly. Do not "soften" it.
- **Photoreal lip-sync (SadTalker, Audio2Face, etc.).** Ruled out at gallery time for compound risk and license incompatibility. The 1-bit halftone PNG swap is the aesthetic.

## Workflow

1. **Fork** the repo on GitHub.
2. **Branch** from `main` with one of these prefixes:
   - `fix/` — bug fixes
   - `feat/` — new features
   - `docs/` — documentation only
   - `chore/` — tooling / housekeeping
   - `refactor/` — internal restructuring, no behavior change
   - `perf/` — performance improvements
   - `test/` — tests only
3. **Write Conventional Commits** in the form `type(scope): description`. Example:
   ```
   fix(viseme): handle audio-clock rollback on session restart
   ```
4. **Run `make ci-local` before pushing.** This runs lint, tests (41 swift-testing scenarios), and the asset manifest verifier. Tests must stay green.
5. **Open a PR** using the PR template. Link any related issue. Describe scope.
6. **AI-assisted commits** must include a `Co-Authored-By:` trailer per the project convention. See recent commits in `git log` for the format.

## Commit message format

We use **Conventional Commits**. The full type list:

| Type | Use for |
|---|---|
| `feat` | new user-visible capability |
| `fix` | bug fix |
| `docs` | documentation only |
| `style` | whitespace, formatting (no code change) |
| `refactor` | code change that neither fixes a bug nor adds a feature |
| `perf` | performance improvement |
| `test` | adding or correcting tests |
| `build` | build system, dependencies |
| `ci` | CI workflows |
| `chore` | other housekeeping |

Project scopes (use one):

`engine`, `viseme`, `audio`, `gemma`, `app`, `scripts`, `ci`, `docs`, `spec`

Examples from this repo's history:

```
feat(engine): EngineCoordinator + MLXLLM real integration via mlx-swift-lm 3.31.3
fix(viseme): clamp drift alert at 50ms per SC6-04
docs(setup): note Stage-5 day-1 phoneme probe sequence
```

## PR template (what to expect)

The repository has a `.github/PULL_REQUEST_TEMPLATE.md` (owned by the devops surface). When you open a PR, GitHub will pre-fill it. The template asks for:

- Summary of the change
- Related issue / spec section
- Hardware tested on (must include at least one Apple Silicon Mac for app-target changes)
- Tests added or updated
- Whether any frozen-spec invariant was touched (must be "no", or accompanied by a delta document under `runs/`)
- Whether the no-cloud invariant is preserved (entitlements unchanged)

If your PR touches the engine, **run `make engine-test` and paste the output.**

## Spec changes

The frozen SpecDD lock is `e5dfadf2c8…314c5`. Do not recompute it. Do not edit files inside `runs/2026-05-05-spec/spec/` that the lock covers.

If a spec change is genuinely needed, follow the established delta-document pattern:

1. Author a new file at `runs/2026-05-05-spec/spec/SPEC.md.iter<N>-<topic>.md`.
2. State the section it amends, the reason, and the post-amendment text.
3. Reference it from the PR description.
4. The original `SPEC.md` and its lock SHA stay untouched.

`SPEC.md.iter4-api-correction.md` is the canonical example of how to do this.

## License acknowledgment

By opening a PR, you agree that your contribution is licensed under:

- **Apache License 2.0** for code contributions (`apps/`, `packages/`, `scripts/`, `tools/`, root `*.swift` / `*.py` / `*.sh`)
- **Creative Commons CC-BY-4.0** for documentation, specifications, and media (`docs/`, `runs/`, `memory/`, `*.md`, asset derivatives)

This dual-license matches the repo and is required by the hackathon winner license rules. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

## Questions

Open a GitHub issue, or email `app.2weeks@gmail.com`. Korean and English are both fine.

*소크라테스는 답하지 않는다. 묻는다. — 그래도 PR은 환영이다.*
