#!/usr/bin/env python3
"""
install_gemma_weights.py — Stage the Gemma 4 E4B 4-bit MLX model into the
sandboxed He Was Socrates app's HuggingFace cache so the runtime can read
it without ever touching the network.

The macOS bundle ships with App Sandbox enabled and no `network.client`
entitlement (NO-CLOUD invariant per
runs/2026-05-05-spec/spec/entitlements.plist.md §3 and the lock at
runs/2026-05-05-spec/spec/SPEC.md). swift-huggingface's
CacheLocationProvider resolves to `Library/Caches/huggingface/hub` for
sandboxed Apple apps, which the kernel redirects to:

    ~/Library/Containers/<bundle-id>/Data/Library/Caches/huggingface/hub

We populate that path from outside the sandbox here, so the sandboxed
app only has to READ at runtime.

Idempotent: huggingface_hub's snapshot_download skips files that match the
expected hash. Safe to re-run.

Usage:
    .venv-build/bin/python3 scripts/install_gemma_weights.py
    HEWASSOCRATES_GEMMA_REPO=mlx-community/gemma-4-e4b-it-4bit \\
        .venv-build/bin/python3 scripts/install_gemma_weights.py
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

try:
    from huggingface_hub import snapshot_download
except ImportError:
    print(
        "huggingface_hub is not installed in this environment.\n"
        "Run via the Makefile target: `make install-gemma-weights`,\n"
        "which provisions .venv-build/ for you.",
        file=sys.stderr,
    )
    sys.exit(2)


BUNDLE_ID = "com.twoweeks.hewassocrates"
DEFAULT_REPO = "mlx-community/gemma-4-e4b-it-4bit"


def sandbox_cache_root() -> Path:
    home = Path.home()
    return (
        home
        / "Library"
        / "Containers"
        / BUNDLE_ID
        / "Data"
        / "Library"
        / "Caches"
        / "huggingface"
        / "hub"
    )


def human_size(num_bytes: int) -> str:
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if num_bytes < 1024:
            return f"{num_bytes:.1f} {unit}"
        num_bytes /= 1024
    return f"{num_bytes:.1f} PiB"


def directory_size(path: Path) -> int:
    total = 0
    for p in path.rglob("*"):
        if p.is_file() and not p.is_symlink():
            try:
                total += p.stat().st_size
            except OSError:
                pass
    return total


def main() -> int:
    repo_id = os.environ.get("HEWASSOCRATES_GEMMA_REPO", DEFAULT_REPO)
    cache_root = sandbox_cache_root()

    container_data = cache_root.parents[3]  # …/Data
    if not container_data.exists():
        print(
            f"sandbox container not found: {container_data}\n"
            "Launch the .app at least once (`make run`) so macOS provisions\n"
            "the sandbox container, then re-run this target.",
            file=sys.stderr,
        )
        return 3

    cache_root.mkdir(parents=True, exist_ok=True)

    print(f"⇢  repo:      {repo_id}")
    print(f"⇢  cache_dir: {cache_root}")
    print("⇢  fetching… (resumes if partially downloaded)")
    snapshot_path = snapshot_download(
        repo_id=repo_id,
        cache_dir=str(cache_root),
        local_dir_use_symlinks=False,
    )
    snapshot_dir = Path(snapshot_path)

    size = directory_size(snapshot_dir)
    print(f"✓  installed: {snapshot_dir}")
    print(f"✓  on-disk:   {human_size(size)} across "
          f"{sum(1 for _ in snapshot_dir.rglob('*') if _.is_file())} files")

    free = shutil.disk_usage(snapshot_dir).free
    print(f"ℹ  free space remaining on this volume: {human_size(free)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
