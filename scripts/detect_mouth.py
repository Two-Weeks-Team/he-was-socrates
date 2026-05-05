#!/usr/bin/env python3
# Estimate mouth position on a portrait by anatomical proportions on the
# alpha bbox. Outputs a JSON guess + an annotated diagnostic PNG with
# crosshairs at several candidate y values.

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw
import numpy as np


def estimate(src_path: Path) -> dict:
    src = Image.open(src_path).convert("RGBA")
    W, H = src.size
    alpha = np.array(src)[..., 3]

    # bbox of opaque content
    rows = np.any(alpha > 16, axis=1)
    cols = np.any(alpha > 16, axis=0)
    if not rows.any() or not cols.any():
        return {"error": "no opaque content"}
    y_top = int(np.argmax(rows))
    y_bot = int(H - 1 - np.argmax(rows[::-1]))
    x_left = int(np.argmax(cols))
    x_right = int(W - 1 - np.argmax(cols[::-1]))

    bbox_h = y_bot - y_top
    bbox_w = x_right - x_left
    cx = (x_left + x_right) // 2

    # Anatomical guess: head occupies upper ~70% of the bust bbox.
    # Within head, eyes ~0.40, nose tip ~0.55, mouth ~0.65, chin ~0.78.
    head_top = y_top
    head_bot = y_top + int(bbox_h * 0.70)
    head_h = head_bot - head_top
    eye_y = head_top + int(head_h * 0.40)
    nose_y = head_top + int(head_h * 0.55)
    mouth_y = head_top + int(head_h * 0.66)

    return {
        "canvas": [W, H],
        "bbox": [x_left, y_top, x_right, y_bot],
        "bbox_size": [bbox_w, bbox_h],
        "estimates": {
            "eye_y": eye_y,
            "nose_y": nose_y,
            "mouth_y": mouth_y,
            "center_x": cx,
        },
        "candidates_y_for_mouth": [
            mouth_y - 30,
            mouth_y - 15,
            mouth_y,
            mouth_y + 15,
            mouth_y + 30,
        ],
    }


def annotate(src_path: Path, est: dict, out_path: Path) -> None:
    src = Image.open(src_path).convert("RGBA")
    W, H = src.size
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    drawer = ImageDraw.Draw(overlay)

    cx = est["estimates"]["center_x"]
    eye_y = est["estimates"]["eye_y"]
    nose_y = est["estimates"]["nose_y"]
    mouth_y = est["estimates"]["mouth_y"]

    bbox = est["bbox"]
    drawer.rectangle(bbox, outline=(0, 255, 255, 200), width=3)

    for y, color, label in [
        (eye_y, (255, 80, 80, 220), "eye_y"),
        (nose_y, (80, 255, 80, 220), "nose_y"),
        (mouth_y, (255, 220, 60, 240), "mouth_y (best)"),
    ]:
        drawer.line([0, y, W, y], fill=color, width=2)
        drawer.text((20, y - 18), f"{label} = {y}", fill=color)

    for y in est["candidates_y_for_mouth"]:
        if y == mouth_y:
            continue
        drawer.line([cx - 60, y, cx + 60, y], fill=(255, 220, 60, 130), width=1)

    drawer.line([cx, 0, cx, H], fill=(255, 220, 60, 120), width=1)

    annotated = Image.alpha_composite(src, overlay)
    annotated.save(out_path, "PNG")


def main() -> int:
    ap = argparse.ArgumentParser(description="Estimate mouth position by anatomical proportions.")
    ap.add_argument("input", type=Path)
    ap.add_argument("--diagnostic", type=Path, default=None,
                    help="annotated PNG with crosshairs (optional)")
    args = ap.parse_args()

    if not args.input.exists():
        print(f"detect_mouth: not found: {args.input}", file=sys.stderr)
        return 2

    est = estimate(args.input)
    if "error" in est:
        print(json.dumps(est), file=sys.stderr)
        return 1

    print(json.dumps(est, indent=2, ensure_ascii=False))

    if args.diagnostic:
        annotate(args.input, est, args.diagnostic)
        print(f"diagnostic: {args.diagnostic}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
