#!/usr/bin/env bash
# Build the 16 viseme PNGs + face_halftone.png from assets/source-portrait.png.
# Stage 1 (halftone) + Stage 2 (viseme compose) + Stage 3 (manifest).
# Idempotent: same input + same params produce byte-identical output.
# See runs/2026-05-05-spec/spec/asset-pipeline.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SRC="assets/source-portrait.png"
FACE="assets/face_halftone.png"
VISEME_DIR="assets/visemes"
VENV="$ROOT/.venv-build"

if [ ! -f "$SRC" ]; then
    echo "build-visemes: source missing: $SRC" >&2
    echo "  Drop the painterly portrait at that path and rerun." >&2
    exit 1
fi

if [ ! -d "$VENV" ]; then
    echo "build-visemes: creating Python venv at $VENV" >&2
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet --upgrade pip
    "$VENV/bin/pip" install --quiet Pillow numpy
fi

# shellcheck source=/dev/null
source "$VENV/bin/activate"

mkdir -p "$VISEME_DIR"

DOT_SIZE="${DOT_SIZE:-6}"
FG_RGBA="${FG_RGBA:-235,222,196,255}"
GAMMA="${GAMMA:-0.85}"

MOUTH_XY="${MOUTH_XY:-514,540}"
MOUTH_COLOR="${MOUTH_COLOR:-12,6,4,255}"
SCALE="${SCALE:-1.0}"
MODE="${MODE:-erase}"
FEATHER="${FEATHER:-3.0}"

# Optional config file overrides env defaults — used by preview-server tweak UI.
CONFIG="$ROOT/assets/.preview-config.json"
if [ -f "$CONFIG" ] && command -v python3 >/dev/null; then
    eval "$(python3 - <<PY
import json, pathlib
try:
    d = json.loads(pathlib.Path("$CONFIG").read_text())
except Exception:
    d = {}
def out(name, val):
    if val is None: return
    print(f"{name}={val!s}")
if "dot_size" in d: out("DOT_SIZE", d["dot_size"])
if "fg_rgba" in d: out("FG_RGBA", ",".join(str(x) for x in d["fg_rgba"]))
if "gamma" in d: out("GAMMA", d["gamma"])
if "mouth_xy" in d:
    xy = d["mouth_xy"]
    out("MOUTH_XY", f"{xy[0]},{xy[1]}")
if "mouth_color" in d:
    out("MOUTH_COLOR", ",".join(str(x) for x in d["mouth_color"]))
if "scale" in d: out("SCALE", d["scale"])
if "mode" in d: out("MODE", d["mode"])
if "feather" in d: out("FEATHER", d["feather"])
PY
)"
fi

# Stage 1 — halftone face
python3 scripts/halftone.py \
    "$SRC" \
    "$FACE" \
    --dot-size "$DOT_SIZE" \
    --fg-rgba "$FG_RGBA" \
    --gamma "$GAMMA"

# Stage 2 — 16 viseme variants
python3 scripts/viseme_compose.py \
    "$FACE" \
    "$VISEME_DIR" \
    --mouth-xy "$MOUTH_XY" \
    --mouth-color "$MOUTH_COLOR" \
    --scale "$SCALE" \
    --mode "$MODE" \
    --feather "$FEATHER"

# Stage 3 — SHA-256 manifest
python3 scripts/build_manifest.py "assets"

deactivate

echo "build-visemes: complete (1 face + 16 visemes + manifest)"
