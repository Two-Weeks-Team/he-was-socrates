#!/usr/bin/env python3
# Compose a 4x4 contact sheet of all 16 visemes on ink-black + labels.
# Build-time only; visual review tool, not part of the runtime pipeline.

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


VISEME_IDS = (
    "AA", "EE", "IH", "OH",
    "OW", "UH", "M",  "P",
    "B",  "F",  "V",  "TH",
    "S",  "SH", "R",  "REST",
)


INK_BLACK = (38, 36, 51, 255)
LABEL_FG = (235, 222, 196, 255)
LABEL_BAND = (12, 11, 18, 255)


def find_font(sizes=(36, 30, 24)):
    candidates = [
        "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
        "/System/Library/Fonts/Times.ttc",
        "/System/Library/Fonts/Supplemental/Iowan Old Style.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNS.ttf",
    ]
    for size in sizes:
        for c in candidates:
            try:
                return ImageFont.truetype(c, size)
            except (OSError, IOError):
                continue
    return ImageFont.load_default()


def build_sheet(visemes_dir: Path, out_path: Path, cell: int = 256, gap: int = 6, label_h: int = 44) -> None:
    cols = 4
    rows = 4
    W = cols * cell + (cols + 1) * gap
    H = rows * (cell + label_h) + (rows + 1) * gap
    sheet = Image.new("RGBA", (W, H), INK_BLACK)
    drawer = ImageDraw.Draw(sheet)
    font = find_font()

    for idx, vid in enumerate(VISEME_IDS):
        row = idx // cols
        col = idx % cols
        x = gap + col * (cell + gap)
        y = gap + row * (cell + label_h + gap)

        v_path = visemes_dir / f"viseme_{vid}.png"
        if not v_path.exists():
            continue

        v_img = Image.open(v_path).convert("RGBA").resize((cell, cell), Image.LANCZOS)
        bg_cell = Image.new("RGBA", (cell, cell), INK_BLACK)
        bg_cell.alpha_composite(v_img)
        sheet.paste(bg_cell, (x, y))

        label_y = y + cell
        drawer.rectangle(
            [x, label_y, x + cell, label_y + label_h],
            fill=LABEL_BAND,
        )
        try:
            bbox = drawer.textbbox((0, 0), vid, font=font)
            tw = bbox[2] - bbox[0]
            th = bbox[3] - bbox[1]
        except AttributeError:
            tw, th = drawer.textsize(vid, font=font)
        tx = x + (cell - tw) // 2
        ty = label_y + (label_h - th) // 2 - 2
        drawer.text((tx, ty), vid, fill=LABEL_FG, font=font)

    sheet.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"contact-sheet: {len(VISEME_IDS)} visemes -> {out_path} ({W}x{H})", file=sys.stderr)


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: contact_sheet.py VISEMES_DIR OUT", file=sys.stderr)
        return 2
    build_sheet(Path(sys.argv[1]), Path(sys.argv[2]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
