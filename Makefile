.PHONY: assets assets-clean assets-verify preview-server engine engine-test xcodeproj app help

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
	cd apps/macos/HeWasSocrates && \
		xcodebuild -project HeWasSocrates.xcodeproj \
		           -scheme HeWasSocrates \
		           -configuration Debug \
		           build

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
