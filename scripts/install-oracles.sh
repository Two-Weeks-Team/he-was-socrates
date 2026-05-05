#!/usr/bin/env bash
# install-oracles.sh — provision build-time test oracles per
# `runs/2026-05-05-spec/spec/viseme-best-practices.md` §7.7.
#
# Both tools live under `tools/oracles/` (gitignored binary blobs) and are
# invoked at build time only — they never ship in the .app bundle.
#
#   1. Rhubarb Lip Sync (MIT, https://github.com/DanielSWolf/rhubarb-lip-sync)
#      Run on TTS-rendered audio to produce ground-truth viseme timing TSVs.
#      PocketSphinx-backed → English-only acoustic model. We use it for the
#      en-US test fixtures.
#
#   2. g2pK (Apache-2.0, https://github.com/Kyubyong/g2pK) into .venv-build
#      Korean post-pronunciation-rule jamo sequence generator. Used to verify
#      that our PhonemeMap.hangulJamoToViseme + JamoTimeline reach the
#      academic-standard pronunciation per Korean phonological rules.
#
# Usage:
#   bash scripts/install-oracles.sh                       # default: install both
#   ORACLES_SKIP_RHUBARB=1 bash scripts/install-oracles.sh
#   ORACLES_SKIP_G2PK=1    bash scripts/install-oracles.sh
#
# The script is idempotent: re-runs are cheap and skip already-present tools.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORACLES_DIR="$REPO_ROOT/tools/oracles"
VENV_DIR="$REPO_ROOT/.venv-build"

RHUBARB_VERSION="${RHUBARB_VERSION:-1.13.0}"
RHUBARB_DIR="$ORACLES_DIR/rhubarb-$RHUBARB_VERSION"
RHUBARB_BIN="$RHUBARB_DIR/rhubarb"

mkdir -p "$ORACLES_DIR"

# -----------------------------------------------------------------------------
# 1. Rhubarb Lip Sync — GitHub release tarball, no brew formula
# -----------------------------------------------------------------------------
install_rhubarb() {
  if [ "${ORACLES_SKIP_RHUBARB:-}" = "1" ]; then
    echo "↷  rhubarb: skipped (ORACLES_SKIP_RHUBARB=1)"
    return 0
  fi
  if [ -x "$RHUBARB_BIN" ]; then
    echo "✓  rhubarb $RHUBARB_VERSION already installed at $RHUBARB_BIN"
    return 0
  fi

  local arch
  arch="$(uname -m)"
  case "$arch" in
    arm64|x86_64) ;;
    *) echo "✗  rhubarb: unsupported arch $arch" >&2; return 1 ;;
  esac

  # Rhubarb releases ship a single macOS universal zip:
  # rhubarb-lip-sync-${VERSION}-osx.zip
  local url="https://github.com/DanielSWolf/rhubarb-lip-sync/releases/download/v${RHUBARB_VERSION}/rhubarb-lip-sync-${RHUBARB_VERSION}-osx.zip"
  local tmp
  tmp="$(mktemp -d)"
  echo "⇢  rhubarb: downloading $url"
  if ! curl -fsSL "$url" -o "$tmp/rhubarb.zip"; then
    echo "✗  rhubarb: download failed. Check the version pin (RHUBARB_VERSION=$RHUBARB_VERSION)." >&2
    rm -rf "$tmp"
    return 1
  fi
  unzip -q "$tmp/rhubarb.zip" -d "$tmp"
  # The zip extracts to rhubarb-lip-sync-${VERSION}-osx/
  mkdir -p "$RHUBARB_DIR"
  cp -R "$tmp/rhubarb-lip-sync-${RHUBARB_VERSION}-osx/." "$RHUBARB_DIR/"
  chmod +x "$RHUBARB_BIN"
  rm -rf "$tmp"
  echo "✓  rhubarb $RHUBARB_VERSION installed: $RHUBARB_BIN"
  "$RHUBARB_BIN" --version 2>&1 | head -1 || true
}

# -----------------------------------------------------------------------------
# 2. g2pK — pip install into the build venv
# -----------------------------------------------------------------------------
install_g2pk() {
  if [ "${ORACLES_SKIP_G2PK:-}" = "1" ]; then
    echo "↷  g2pk: skipped (ORACLES_SKIP_G2PK=1)"
    return 0
  fi
  if [ ! -d "$VENV_DIR" ]; then
    echo "⇢  g2pk: provisioning venv at $VENV_DIR"
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --quiet --upgrade pip
  fi
  if "$VENV_DIR/bin/pip" show g2pk >/dev/null 2>&1; then
    echo "✓  g2pk already installed in $VENV_DIR"
    return 0
  fi
  echo "⇢  g2pk: installing into venv (pulls jamo + nltk + python-mecab-ko)"
  "$VENV_DIR/bin/pip" install --quiet g2pk || {
    echo "✗  g2pk: pip install failed. g2pK depends on a Korean MeCab build that may need" >&2
    echo "   system packages (mecab, mecab-ko, mecab-ko-dic). On macOS:" >&2
    echo "     brew install mecab mecab-ko mecab-ko-dic" >&2
    echo "   Then re-run this script." >&2
    return 1
  }
  echo "✓  g2pk installed: $($VENV_DIR/bin/python3 -c 'import g2pk; print(g2pk.__name__)' 2>&1)"
}

main() {
  echo "──────────────────────────────────────────────────────────"
  echo "Provisioning build-time oracles per viseme-best-practices §7.7"
  echo "──────────────────────────────────────────────────────────"
  install_rhubarb
  install_g2pk
  echo "──────────────────────────────────────────────────────────"
  echo "Oracles ready under tools/oracles/ + .venv-build/"
  echo "Generate fixtures with: make oracle-fixtures (planned)"
}

main "$@"
