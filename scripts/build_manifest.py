#!/usr/bin/env python3
# Build a deterministic manifest of asset SHA-256 hashes.
# Reads assets/face_halftone.png + assets/visemes/viseme_*.png and writes
# assets/.build-manifest.json. CI verifies this manifest is unchanged
# across rebuilds (per spec/asset-pipeline.md determinism requirement).

import hashlib
import json
import sys
from pathlib import Path


VISEME_IDS = (
    "AA", "EE", "IH", "OH", "OW", "UH",
    "M", "P", "B", "F", "V", "TH",
    "S", "SH", "R", "REST",
)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


def build(assets_dir: Path) -> dict:
    files = ["face_halftone.png"] + [
        f"visemes/viseme_{v}.png" for v in VISEME_IDS
    ]
    manifest = {
        "schema_version": "1.0",
        "schema_note": "SHA-256 of build-time-generated runtime assets. Used for CI determinism check.",
        "files": {},
        "viseme_count": 16,
    }
    missing = []
    for rel in files:
        p = assets_dir / rel
        if not p.exists():
            missing.append(rel)
            continue
        manifest["files"][rel] = {
            "sha256": sha256(p),
            "size_bytes": p.stat().st_size,
        }
    if missing:
        print(f"build_manifest: missing assets: {missing}", file=sys.stderr)
        return manifest
    return manifest


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: build_manifest.py ASSETS_DIR", file=sys.stderr)
        return 2
    assets_dir = Path(sys.argv[1])
    if not assets_dir.is_dir():
        print(f"build_manifest: not a directory: {assets_dir}", file=sys.stderr)
        return 2

    manifest = build(assets_dir)
    out_path = assets_dir / ".build-manifest.json"
    out_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")

    n = len(manifest.get("files", {}))
    print(f"manifest: {n} files hashed -> {out_path}", file=sys.stderr)
    return 0 if n == 17 else 1


if __name__ == "__main__":
    raise SystemExit(main())
