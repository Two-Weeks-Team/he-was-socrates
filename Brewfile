# Brewfile — He Was Socrates
# Run `brew bundle install` from the repo root to install all required CLI
# tooling. Python deps (Pillow, numpy) are NOT brewed; they live inside the
# ephemeral `.venv-build/` virtualenv that `make assets` creates on demand.

# --- Required to build / generate / lint --------------------------------------

# xcodegen — generates apps/macos/HeWasSocrates/HeWasSocrates.xcodeproj from
# the committed `project.yml`. Required by `make xcodeproj`.
brew "xcodegen"

# swift-format — Apple's official Swift formatter/linter. CI parity: the same
# binary runs in `.github/workflows/ci.yml::lint-swift`.
brew "swift-format"

# gitleaks — local secret scanning. Run via `make secret-scan` before pushing.
# Same version is invoked by CI's `security-scan` job.
brew "gitleaks"

# --- Optional ----------------------------------------------------------------

# `mas` (Mac App Store CLI) is NOT auto-installed. The Korean Yuna voice and
# enhanced/premium voices ship through System Settings > Accessibility >
# Spoken Content > System Voice > Manage Voices, which is GUI-only and cannot
# be driven by `mas`. If you want to script Mac App Store installs anyway:
#   brew "mas"
