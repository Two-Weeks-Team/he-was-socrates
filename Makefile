.PHONY: assets assets-clean assets-verify preview-server engine engine-test xcodeproj app run bootstrap help \
        doctor probe-phonemes ci-local secret-scan install-gemma-weights

help:
	@echo "He Was Socrates — build targets"
	@echo ""
	@echo "  Asset pipeline (Phase 2 — pure Python, no Xcode needed):"
	@echo "    make assets          — generate assets/face_halftone.png + 16 viseme PNGs"
	@echo "    make assets-clean    — remove generated assets (keeps source-portrait.png)"
	@echo "    make assets-verify   — recompute manifest, fail if PNGs differ"
	@echo "    make preview-server  — start the editor at http://localhost:8765"
	@echo ""
	@echo "  Engine layer (Phase 1+ — Swift Package, only needs CommandLineTools):"
	@echo "    make engine          — swift build packages/SocraticEngine"
	@echo "    make engine-test     — swift test packages/SocraticEngine (swift-testing)"
	@echo ""
	@echo "  macOS app (Phase 1+ — needs full Xcode + xcodegen):"
	@echo "    make xcodeproj       — generate apps/macos/HeWasSocrates/HeWasSocrates.xcodeproj"
	@echo "    make app             — build the .app via xcodebuild"
	@echo ""
	@echo "Prerequisites for app builds:"
	@echo "  • Full Xcode (not just CommandLineTools): /Applications/Xcode.app"
	@echo "  • xcodegen:        brew install xcodegen"
	@echo "  • assets first:    make assets"
	@echo "  • Metal Toolchain: auto-downloaded by 'make app' on first run (~688 MB)"
	@echo "  • Optional signing override:"
	@echo "      cp apps/macos/HeWasSocrates/Local.xcconfig.example \\"
	@echo "         apps/macos/HeWasSocrates/Local.xcconfig"
	@echo "      # then edit DEVELOPMENT_TEAM and re-run: make xcodeproj"
	@echo ""
	@echo "  Local CI / tooling:"
	@echo "    make doctor          — check toolchain (Swift, Xcode, xcodegen, py3, gitleaks)"
	@echo "    make ci-local        — run the same gates CI does (assets-verify + tests + lint)"
	@echo "    make secret-scan     — gitleaks scan for committed secrets"
	@echo "    make probe-phonemes  — Stage-5 day-1 Apple phoneme availability probe"
	@echo ""
	@echo "  End-to-end:"
	@echo "    make bootstrap            — fresh-clone setup (assets + xcodeproj + app +"
	@echo "                                 install-gemma-weights)"
	@echo "    make install-gemma-weights — pre-fetch the ~3.97 GB Gemma 4 E4B 4-bit"
	@echo "                                 model into the sandbox container so the"
	@echo "                                 NO-CLOUD app can read it offline."
	@echo "    make run                  — launch the built .app"
	@echo "    HEWASSOCRATES_GEMMA_MODE=stub make run"
	@echo "                               — launch with canned stub responses (skips MLX"
	@echo "                                 load; useful for UI smoke tests)"

assets:
	bash scripts/build-visemes.sh

assets-clean:
	rm -f assets/face_halftone.png assets/.build-manifest.json
	rm -f assets/visemes/viseme_*.png

preview-server:
	@if [ ! -d .venv-build ]; then \
		echo "Creating Python venv..."; \
		python3 -m venv .venv-build && \
		.venv-build/bin/pip install --quiet --upgrade pip && \
		.venv-build/bin/pip install --quiet Pillow numpy; \
	fi
	@echo "Open http://localhost:8765/preview/index.html in your browser."
	@echo "Ctrl-C to stop."
	.venv-build/bin/python3 scripts/preview-server.py

engine:
	cd packages/SocraticEngine && swift build

engine-test:
	cd packages/SocraticEngine && swift test

xcodeproj:
	@if ! command -v xcodegen >/dev/null 2>&1; then \
		echo "xcodegen not installed. Run: brew install xcodegen" >&2; exit 1; \
	fi
	@if [ ! -f assets/face_halftone.png ]; then \
		echo "assets not built. Run: make assets" >&2; exit 1; \
	fi
	cd apps/macos/HeWasSocrates && xcodegen generate
	@echo "Generated: apps/macos/HeWasSocrates/HeWasSocrates.xcodeproj"
	@echo "Open in Xcode: open apps/macos/HeWasSocrates/HeWasSocrates.xcodeproj"

app:
	@if ! xcrun -find xcodebuild >/dev/null 2>&1; then \
		echo "Full Xcode not found (CommandLineTools only?)." >&2; \
		echo "Install Xcode from the App Store or run: xcode-select --switch /Applications/Xcode.app" >&2; \
		exit 1; \
	fi
	@if [ ! -f apps/macos/HeWasSocrates/HeWasSocrates.xcodeproj/project.pbxproj ]; then \
		echo "xcodeproj missing. Run: make xcodeproj" >&2; exit 1; \
	fi
	@# Probe for Metal Toolchain (Xcode 26+ ships it as a downloadable component).
	@# mlx-swift's Cmlx target invokes `metal` to compile shaders, so the
	@# toolchain MUST be installed before the build can succeed. Auto-download
	@# is non-interactive (no Apple ID required, ~688 MB).
	@if ! xcrun --sdk macosx --find metal >/dev/null 2>&1; then \
		echo "Metal Toolchain missing — downloading (~688 MB, ~1 min on fast link)..."; \
		xcodebuild -downloadComponent MetalToolchain || { \
			echo "Metal Toolchain download failed. Run manually: xcodebuild -downloadComponent MetalToolchain" >&2; \
			exit 1; \
		}; \
	fi
	@# -skipMacroValidation: mlx-swift-lm exports MLXHuggingFaceMacros (a Swift
	@# Macro target). Xcode 15+ requires explicit user trust via the UI on first
	@# use; CLI builds need this flag to bypass the trust prompt. Same pattern
	@# Apple's own CI uses for projects depending on third-party macros.
	cd apps/macos/HeWasSocrates && \
		xcodebuild -project HeWasSocrates.xcodeproj \
		           -scheme HeWasSocrates \
		           -configuration Debug \
		           -skipMacroValidation \
		           build

# `make bootstrap` — full fresh-clone setup. Runs assets, generates the
# xcodeproj, builds the .app, then pre-fetches the Gemma weights into the
# sandbox container (the NO-CLOUD invariant means the app itself cannot
# download them at runtime). Designed to "just work" on a clean Apple
# Silicon Mac with full Xcode + Homebrew deps installed (see Brewfile).
bootstrap: assets xcodeproj app install-gemma-weights
	@echo ""
	@echo "Bootstrap complete. Launch with: make run"
	@echo "  • Optional signing override: cp apps/macos/HeWasSocrates/Local.xcconfig.example \\"
	@echo "                                  apps/macos/HeWasSocrates/Local.xcconfig"

# `make install-gemma-weights` — pre-fetch the Gemma 4 E4B 4-bit model from
# HuggingFace and stage it into the sandboxed app's cache.
#
# Why: the app ships with App Sandbox enabled and *no* network entitlements
# (NO-CLOUD invariant). swift-huggingface's CacheLocationProvider resolves to
# `~/Library/Caches/huggingface/hub` for sandboxed Apple apps, which under
# sandboxing redirects to
# `~/Library/Containers/<bundle>/Data/Library/Caches/huggingface/hub`.
# We download into that container path here, OUTSIDE the sandbox, so the
# sandboxed app process only ever has to READ from the cache at runtime.
#
# Idempotent: huggingface_hub's snapshot_download skips files that match the
# expected hash, so re-running is cheap once the bundle is present.
install-gemma-weights:
	@if [ ! -d .venv-build ]; then \
		echo "Creating Python venv (.venv-build)..."; \
		python3 -m venv .venv-build && \
		.venv-build/bin/pip install --quiet --upgrade pip; \
	fi
	@.venv-build/bin/pip show huggingface_hub >/dev/null 2>&1 || { \
		echo "Installing huggingface_hub into .venv-build..."; \
		.venv-build/bin/pip install --quiet huggingface_hub; \
	}
	@.venv-build/bin/python3 scripts/install_gemma_weights.py

# `make run` — launch the built .app. Resolves the actual build product path
# from xcodebuild's settings so DerivedData relocations don't break this.
run:
	@APP_DIR="$$(cd apps/macos/HeWasSocrates && \
		xcodebuild -project HeWasSocrates.xcodeproj \
		           -scheme HeWasSocrates \
		           -configuration Debug \
		           -showBuildSettings 2>/dev/null \
		| awk -F' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR =/ {print $$2; exit}')"; \
	APP="$$APP_DIR/HeWasSocrates.app"; \
	if [ ! -d "$$APP" ]; then \
		echo "App not built yet. Run: make app" >&2; exit 1; \
	fi; \
	echo "Launching $$APP"; \
	open "$$APP"

assets-verify:
	@if [ ! -f assets/.build-manifest.json ]; then \
		echo "No manifest. Run 'make assets' first." >&2; exit 1; \
	fi
	@TMP=$$(mktemp); \
	cp assets/.build-manifest.json $$TMP; \
	bash scripts/build-visemes.sh > /dev/null; \
	if ! diff -q $$TMP assets/.build-manifest.json > /dev/null; then \
		echo "MANIFEST DIFFERS — non-deterministic build or asset drift." >&2; \
		diff $$TMP assets/.build-manifest.json >&2 || true; \
		rm $$TMP; exit 2; \
	fi; \
	rm $$TMP; \
	echo "manifest verified: deterministic build"

# -----------------------------------------------------------------------------
# Local CI / tooling targets (Phase 6 setup).
# -----------------------------------------------------------------------------

# `make doctor` — non-fatal toolchain audit. Prints a green-check / red-X table.
# Critical tools (Swift, Xcode/xcodebuild, xcodegen) — exit 1 if missing.
# Nice-to-haves (gitleaks, swift-format) — warn but do not fail.
doctor:
	@status=0; \
	check_critical() { \
		name="$$1"; cmd="$$2"; ver="$$3"; \
		if eval "$$cmd" >/dev/null 2>&1; then \
			printf "  \033[32m✓\033[0m  %-14s %s\n" "$$name" "$$ver"; \
		else \
			printf "  \033[31m✗\033[0m  %-14s MISSING (critical)\n" "$$name"; \
			status=1; \
		fi; \
	}; \
	check_optional() { \
		name="$$1"; cmd="$$2"; ver="$$3"; \
		if eval "$$cmd" >/dev/null 2>&1; then \
			printf "  \033[32m✓\033[0m  %-14s %s\n" "$$name" "$$ver"; \
		else \
			printf "  \033[33m–\033[0m  %-14s not installed (optional)\n" "$$name"; \
		fi; \
	}; \
	echo "He Was Socrates — toolchain doctor"; \
	echo "──────────────────────────────────"; \
	check_critical "swift"     'swift --version'              "$$(swift --version 2>/dev/null | head -1)"; \
	check_critical "xcodebuild" 'xcrun -find xcodebuild'      "$$(xcrun -find xcodebuild 2>/dev/null)"; \
	check_critical "xcodegen"  'xcodegen --version'           "$$(xcodegen --version 2>/dev/null | head -1)"; \
	check_critical "python3"   'python3 --version'            "$$(python3 --version 2>/dev/null)"; \
	check_optional "swift-format" 'swift-format --version'    "$$(swift-format --version 2>/dev/null)"; \
	check_optional "gitleaks"  'gitleaks version'             "$$(gitleaks version 2>/dev/null)"; \
	echo "──────────────────────────────────"; \
	if [ "$$status" -eq 0 ]; then \
		echo "All critical tools present."; \
	else \
		echo "One or more critical tools are missing — see brew bundle install." >&2; \
	fi; \
	exit $$status

# `make probe-phonemes` — Stage-5 day-1 Apple phoneme availability probe.
# Builds and runs the standalone tool at tools/ApplePhonemeProbe/. Always
# exits 0 (the probe is informational); writes the verdict JSON to
# runs/2026-05-05-spec/spec/apple-phoneme-availability.json.
probe-phonemes:
	@echo "Building tools/ApplePhonemeProbe..."
	cd tools/ApplePhonemeProbe && swift build -c release
	@echo "Running probe (informational, exits 0 even on missing voices)..."
	cd tools/ApplePhonemeProbe && \
		PROBE_BIN="$$(swift build -c release --show-bin-path)/ApplePhonemeProbe" && \
		(cd "$(CURDIR)" && "$$PROBE_BIN")

# `make ci-local` — run the same gates CI does, in the same order.
# Useful as a pre-push hook. Will exit non-zero on the first failing gate.
ci-local: assets-verify engine-test
	@if command -v swift-format >/dev/null 2>&1; then \
		echo "Running swift-format lint..."; \
		swift-format lint -r packages apps tools; \
	else \
		echo "swift-format not installed — skipping lint. Run 'brew bundle install'." >&2; \
		exit 1; \
	fi
	@echo "ci-local: all gates passed."

# `make secret-scan` — local gitleaks scan against the working tree.
secret-scan:
	@if ! command -v gitleaks >/dev/null 2>&1; then \
		echo "gitleaks not installed. Run: brew install gitleaks" >&2; exit 1; \
	fi
	gitleaks detect --no-banner --source . --redact
