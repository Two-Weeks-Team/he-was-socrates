#!/usr/bin/env python3
# Convert a source portrait PNG (RGBA) to a 1-bit halftone derivative.
# Output: alabaster dots on transparent background, sized per dot_size cell.
# Stage 1 of the asset pipeline. Build-time only — does not ship in DMG.
# See runs/2026-05-05-spec/spec/asset-pipeline.md for the contract.

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw
import numpy as np


def halftone(
    src_path: Path,
    out_path: Path,
    dot_size: int = 6,
    fg_rgba: tuple = (235, 222, 196, 255),
    min_radius: float = 0.4,
    gamma: float = 1.0,
) -> None:
    src = Image.open(src_path).convert("RGBA")
    W, H = src.size

    arr = np.array(src)
    rgb = arr[..., :3].astype(np.float32) / 255.0
    alpha = arr[..., 3].astype(np.float32) / 255.0

    luminance = (
        0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    )
    luminance = np.power(luminance, gamma)
    luminance = luminance * alpha

    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    drawer = ImageDraw.Draw(out)

    n_cols = W // dot_size
    n_rows = H // dot_size
    half = dot_size / 2.0

    drawn = 0
    for j in range(n_rows):
        y0 = j * dot_size
        y1 = y0 + dot_size
        for i in range(n_cols):
            x0 = i * dot_size
            x1 = x0 + dot_size
            cell_lum = luminance[y0:y1, x0:x1].mean()
            cell_alpha = alpha[y0:y1, x0:x1].mean()
            if cell_alpha < 0.05:
                continue
            radius = cell_lum * half
            if radius < min_radius:
                continue
            cx = x0 + half
            cy = y0 + half
            drawer.ellipse(
                [cx - radius, cy - radius, cx + radius, cy + radius],
                fill=fg_rgba,
            )
            drawn += 1

    out.save(out_path, "PNG", optimize=True)
    print(
        f"halftone: {src_path.name} {W}x{H} -> {out_path.name}  "
        f"({n_cols}x{n_rows} cells, {drawn} dots)",
        file=sys.stderr,
    )


def parse_rgba(s: str) -> tuple:
    parts = [int(x.strip()) for x in s.split(",")]
    if len(parts) == 3:
        parts.append(255)
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("RGBA must be 3 or 4 comma-separated ints")
    return tuple(parts)


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Convert a source portrait PNG to a 1-bit halftone derivative."
    )
    ap.add_argument("input", type=Path, help="source RGBA PNG")
    ap.add_argument("output", type=Path, help="halftone RGBA PNG")
    ap.add_argument("--dot-size", type=int, default=6, help="cell side in px")
    ap.add_argument(
        "--fg-rgba",
        type=parse_rgba,
        default=(235, 222, 196, 255),
        help="dot fill color, comma RGBA (default alabaster)",
    )
    ap.add_argument(
        "--min-radius",
        type=float,
        default=0.4,
        help="suppress imperceptibly small dots",
    )
    ap.add_argument(
        "--gamma",
        type=float,
        default=1.0,
        help="luminance power curve; >1 darkens, <1 lifts",
    )
    args = ap.parse_args()

    if not args.input.exists():
        print(f"halftone: input not found: {args.input}", file=sys.stderr)
        return 2
    args.output.parent.mkdir(parents=True, exist_ok=True)

    halftone(
        args.input,
        args.output,
        dot_size=args.dot_size,
        fg_rgba=args.fg_rgba,
        min_radius=args.min_radius,
        gamma=args.gamma,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
