#!/usr/bin/env python3
# Composite a halftone PNG onto an ink-black background for visual review.
# Build-time only; not part of the runtime asset pipeline.

import sys
from pathlib import Path

from PIL import Image


INK_BLACK = (38, 36, 51, 255)


def composite(in_path: Path, out_path: Path, bg=INK_BLACK) -> None:
    fg = Image.open(in_path).convert("RGBA")
    bg_img = Image.new("RGBA", fg.size, bg)
    bg_img.alpha_composite(fg)
    bg_img.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"preview: {in_path.name} on ink-black -> {out_path.name}", file=sys.stderr)


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: preview_on_black.py IN OUT", file=sys.stderr)
        return 2
    composite(Path(sys.argv[1]), Path(sys.argv[2]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
