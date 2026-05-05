# Setup — He Was Socrates

Complete setup guide for a new development machine. **Tested on macOS 14+
Apple Silicon with full Xcode installed.**

---

## Prerequisites

| Requirement | Why | Verify |
|---|---|---|
| **macOS 14+** (Apple Silicon) | MLX-Swift requires Metal on M-series | `sw_vers -productVersion` |
| **Full Xcode 15.2+** (not just CommandLineTools) | `.app` bundle build needs `xcodebuild` | `xcrun -find xcodebuild` |
| **Homebrew** | for `xcodegen` install | `brew --version` |
| **Git LFS** *(optional)* | only if you commit the Gemma weights bundle | `git lfs --version` |
| **Python 3.11+** | build-time asset pipeline (halftone) | `python3 --version` |

If `xcrun -find xcodebuild` errors with *"requires Xcode but active developer
directory is CommandLineTools"*, run:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

---

## One-shot setup (5 minutes on a clean Mac)

```bash
# 1. Clone
git clone https://github.com/ComBba/he-was-socrates.git
cd he-was-socrates

# 2. Install build tooling
brew bundle              # installs xcodegen + Pillow's system deps via Brewfile
# OR if you don't use bundle:
brew install xcodegen

# 3. Sanity-check the environment
make doctor              # prints what's installed + what's missing

# 4. Build assets (regenerates 17 PNGs from source-portrait.png)
make assets              # ~10 s, creates .venv-build, runs halftone + viseme-compose

# 5. Build engine + run tests (CommandLineTools-only OK)
make engine-test         # 41 swift-testing scenarios, ~1.5 s

# 6. Generate Xcode project
make xcodeproj           # apps/macos/HeWasSocrates/HeWasSocrates.xcodeproj

# 7. Build the .app
make app                 # xcodebuild -project ... -scheme HeWasSocrates build
```

---

## First launch

```bash
open apps/macos/HeWasSocrates/build/Debug/HeWasSocrates.app
```

On first launch the app will:

1. **Request microphone + speech recognition permissions** (TCC)
2. **Download Gemma 4 E4B 4-bit weights** (~3.97 GB) into
   `~/Library/Caches/com.apple.MLX/...` via the HuggingFace Hub
3. **Verify SHA-256** of cached weights against
   `runs/2026-05-05-spec/spec/model-integrity.md` (currently set to
   "skip in dev mode" — Stage-5 day-1 commits the canonical hash)
4. **Take fullscreen** (Cmd+Esc to exit)
5. **Wait for spacebar** to begin push-to-talk

---

## Stage 5 day-1 verification tasks

Per `runs/2026-05-05-spec/spec/SPEC.md.iter4-api-correction.md` §S4, before
shooting the demo video the developer MUST:

```bash
# Probe: do Apple's ko-KR voices (Yuna, Heami) actually emit
# AVSpeechSynthesisMarker.phoneme? If yes, JamoTimeline becomes the
# fallback; if no, JamoTimeline becomes the primary path.
swift run -c release ApplePhonemeProbe

# This writes runs/2026-05-05-spec/spec/apple-phoneme-availability.json
# Inspect it. Then either:
#   (a) commit the file (markers ARE emitted, JamoTimeline = fallback)
#   (b) update SPEC.md.iter4 to clarify "ko-KR uses JamoTimeline only"
```

Probe source: `tools/ApplePhonemeProbe/main.swift` (executable target,
included in the Swift Package).

Once verified, commit + push, and the codebase is ready for video shoot.

---

## Troubleshooting

### `make app` fails with "no such module 'SocraticEngine'"

The Xcode project lost its package reference. Re-run:

```bash
make xcodeproj          # rewrites .xcodeproj from project.yml
```

### Gemma weights download stalls

The HuggingFace Hub mirror may be slow. Override:

```bash
export HF_ENDPOINT=https://huggingface.co
make app
```

You can also manually pre-cache the model:

```bash
swift run -c release ModelDownload   # not yet wired; planned for day-1
# OR via Python (one-time):
python3 -c "from huggingface_hub import snapshot_download; snapshot_download('mlx-community/gemma-4-e4b-it-4bit')"
```

### `make engine-test` fails with "no such module 'Testing'"

This means swift-testing isn't fetched. Run:

```bash
cd packages/SocraticEngine && swift package resolve
```

### Preview server (`make preview-server`) won't bind to 8765

Another process is using the port. Override:

```bash
PREVIEW_PORT=8766 make preview-server
```

### Notarization fails

Apple Developer Team ID + App-Specific-Password required. Configure:

```bash
xcrun notarytool store-credentials \
  --apple-id YOUR_APPLE_ID@example.com \
  --team-id YOUR_TEAM_ID \
  --password YOUR_APP_SPECIFIC_PASSWORD \
  he-was-socrates-notary
```

Then `make notarize` (planned, not yet wired).

---

## What lives where

| Path | Purpose | Edit? |
|---|---|---|
| `apps/macos/HeWasSocrates/` | macOS app target (Xcode-driven) | yes |
| `apps/macos/HeWasSocrates/project.yml` | xcodegen config — RE-GENERATE the .xcodeproj after edits | yes |
| `packages/SocraticEngine/` | Swift Package (engine layer) | yes |
| `assets/` | source portrait + 17 generated runtime PNGs + manifest | mostly auto |
| `assets/source-portrait.png` | input to halftone pipeline | edit + `make assets` |
| `scripts/` | build-time Python toolchain (NOT shipped) | yes |
| `runs/2026-05-05-spec/spec/` | locked SpecDD artifacts (SHA `e5dfadf2…314c5`) | **DO NOT EDIT** |
| `docs/` | video script, writeup draft, architecture notes | yes |
| `memory/` | PreviewForge cross-cycle memory (auto-managed) | rarely |

---

## Branch policy

- `main` — last green build. PRs only.
- `phase-N-<topic>` — feature branches for next-stage work (Stage 5 day-1, etc.)
- All commits must be signed with the standard `Co-Authored-By` trailer for
  Claude-assisted work, or signed-off-by for human-only work.

---

## Acknowledgments

This setup follows `runs/2026-05-05-spec/spec/scaffold-plan-proposal.md`
phases 0–5 and incorporates user ratifications (a)–(m) per
`runs/2026-05-05-spec/spec/user-ratifications.md`. The frozen SpecDD lock
(`e5dfadf2c8…314c5`) governs the contract; `iter-2-amendment` and
`iter-4-api-correction` extend it without recomputing the SHA.
