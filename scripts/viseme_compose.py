#!/usr/bin/env python3
# Generate 16 viseme variants from a halftone face PNG.
# For each viseme, draws a parametric mouth-opening ellipse over the mouth
# region. Produces 16 PNGs at the same canvas size as the input face.
# Stage 2 of the asset pipeline. Build-time only.
# See runs/2026-05-05-spec/spec/asset-pipeline.md.

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter
import numpy as np


VISEME_IDS = (
    "AA", "EE", "IH", "OH", "OW", "UH",
    "M", "P", "B", "F", "V", "TH",
    "S", "SH", "R", "REST",
)


VISEME_DIMS = {
    "AA":   (100, 75),
    "EE":   (118, 18),
    "IH":   (105, 26),   # 2026-05-05 research §7.2: was 98×22, indistinguishable from EE.
    "OH":   (58, 58),
    "OW":   (44, 44),
    "UH":   (82, 32),
    "M":    (94, 8),
    "P":    (94, 8),
    "B":    (94, 8),
    "F":    (80, 14),    # 2026-05-05 research §7.2: was 88×22, identical to IH; flatter implies teeth bite.
    "V":    (80, 14),    # 2026-05-05 research §7.2: was 88×22, match F.
    "TH":   (76, 26),    # 2026-05-05 research §7.2: was 82×32, identical to UH.
    "S":    (74, 24),
    "SH":   (68, 32),
    "R":    (58, 38),
    "REST": (82, 8),     # 2026-05-05 research §7.2: was 78×18, more open than M (industry-convention violation).
}


def _build_mouth_mask(W: int, H: int, cx: int, cy: int, w: int, h: int, feather: float) -> np.ndarray:
    """Return 0..1 alpha-erase mask (1 = fully erase) with soft feather edges."""
    mask_img = Image.new("L", (W, H), 0)
    drawer = ImageDraw.Draw(mask_img)
    x0 = cx - w // 2
    x1 = cx + w // 2
    y0 = cy - h // 2
    y1 = cy + h // 2
    drawer.ellipse([x0, y0, x1, y1], fill=255)
    if feather > 0:
        mask_img = mask_img.filter(ImageFilter.GaussianBlur(radius=feather))
    return np.array(mask_img, dtype=np.float32) / 255.0


def compose(
    face_path: Path,
    out_dir: Path,
    mouth_xy: tuple = (514, 540),
    scale: float = 1.0,
    feather: float = 3.0,
    mode: str = "erase",
    mouth_color: tuple = (12, 6, 4, 255),
) -> int:
    """Render 16 viseme variants from a halftone face PNG.

    Modes:
        'erase' — alpha-channel erase (default, recommended). The mouth region
            becomes transparent so the runtime ink-black bg shows through as a
            natural cavity. Soft feather smooths the edge.
        'fill'  — legacy behavior. Draws a solid ellipse with mouth_color over
            the halftone. Hard edges, may look too 'painted'.
    """
    face = Image.open(face_path).convert("RGBA")
    W, H = face.size
    cx, cy = mouth_xy

    face_arr_template = np.array(face)  # uint8, shape (H, W, 4)

    out_dir.mkdir(parents=True, exist_ok=True)

    written = 0
    for vid in VISEME_IDS:
        w_base, h_base = VISEME_DIMS[vid]
        w = max(1, int(w_base * scale))
        h = max(1, int(h_base * scale))

        if mode == "erase":
            erase = _build_mouth_mask(W, H, cx, cy, w, h, feather)
            arr = face_arr_template.copy()
            new_alpha = arr[..., 3].astype(np.float32) * (1.0 - erase)
            arr[..., 3] = np.clip(new_alpha, 0, 255).astype(np.uint8)
            layer = Image.fromarray(arr, "RGBA")
        else:
            layer = face.copy()
            drawer = ImageDraw.Draw(layer)
            x0 = cx - w // 2
            x1 = cx + w // 2
            y0 = cy - h // 2
            y1 = cy + h // 2
            drawer.ellipse([x0, y0, x1, y1], fill=mouth_color)

        out_path = out_dir / f"viseme_{vid}.png"
        layer.save(out_path, "PNG", optimize=True)
        written += 1

    print(
        f"visemes: face {W}x{H} -> {written} PNGs in {out_dir}/  "
        f"(mouth=({cx},{cy}) scale={scale} mode={mode} feather={feather})",
        file=sys.stderr,
    )
    return written


def parse_xy(s: str) -> tuple:
    parts = [int(x.strip()) for x in s.split(",")]
    if len(parts) != 2:
        raise argparse.ArgumentTypeError("XY must be 2 comma-separated ints")
    return tuple(parts)


def parse_rgba(s: str) -> tuple:
    parts = [int(x.strip()) for x in s.split(",")]
    if len(parts) == 3:
        parts.append(255)
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("RGBA must be 3 or 4 comma-separated ints")
    return tuple(parts)


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Generate 16 viseme variants from a halftone face PNG."
    )
    ap.add_argument("face", type=Path, help="input halftone face PNG")
    ap.add_argument("out_dir", type=Path, help="output directory for viseme_*.png")
    ap.add_argument(
        "--mouth-xy",
        type=parse_xy,
        default=(514, 540),
        help="mouth center on the face PNG canvas (default tuned for 1024x1024)",
    )
    ap.add_argument(
        "--mouth-color",
        type=parse_rgba,
        default=(12, 6, 4, 255),
        help="legacy fill color (only used when --mode fill)",
    )
    ap.add_argument(
        "--scale",
        type=float,
        default=1.0,
        help="scale viseme dims (use if canvas != 1024x1024)",
    )
    ap.add_argument(
        "--mode",
        choices=("erase", "fill"),
        default="erase",
        help="erase = alpha cutout (recommended), fill = solid ellipse (legacy)",
    )
    ap.add_argument(
        "--feather",
        type=float,
        default=3.0,
        help="Gaussian blur radius on alpha mask edge (px); 0 = hard edge",
    )
    args = ap.parse_args()

    if not args.face.exists():
        print(f"viseme_compose: face PNG not found: {args.face}", file=sys.stderr)
        return 2

    compose(
        args.face,
        args.out_dir,
        mouth_xy=args.mouth_xy,
        scale=args.scale,
        feather=args.feather,
        mode=args.mode,
        mouth_color=args.mouth_color,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
