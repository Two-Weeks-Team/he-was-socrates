#!/usr/bin/env python3
# Close-up 4x4 contact sheet centered on the configured mouth_xy.
# Reads assets/.preview-config.json (or uses default) so the crop follows
# whatever position the user chose in the editor.

import json
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


def find_font(sizes=(40, 32, 26)):
    candidates = [
        "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
        "/System/Library/Fonts/Times.ttc",
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


def load_mouth_xy(config_path: Path, default=(514, 540)):
    if not config_path.exists():
        return default
    try:
        d = json.loads(config_path.read_text())
        xy = d.get("mouth_xy")
        if isinstance(xy, list) and len(xy) == 2:
            return (int(xy[0]), int(xy[1]))
    except Exception:
        pass
    return default


def build_sheet(
    visemes_dir: Path,
    out_path: Path,
    mouth_xy: tuple,
    crop_size=(300, 220),
    cell_w: int = 320,
    cell_h: int = 234,
    gap: int = 8,
    label_h: int = 50,
) -> None:
    cx, cy = mouth_xy
    w_crop, h_crop = crop_size
    x_crop = max(0, cx - w_crop // 2)
    y_crop = max(0, cy - h_crop // 2)

    cols = 4
    rows = 4
    W = cols * cell_w + (cols + 1) * gap
    H = rows * (cell_h + label_h) + (rows + 1) * gap
    sheet = Image.new("RGBA", (W, H), INK_BLACK)
    drawer = ImageDraw.Draw(sheet)
    font = find_font()

    for idx, vid in enumerate(VISEME_IDS):
        row = idx // cols
        col = idx % cols
        x = gap + col * (cell_w + gap)
        y = gap + row * (cell_h + label_h + gap)

        v_path = visemes_dir / f"viseme_{vid}.png"
        if not v_path.exists():
            continue

        v_img = Image.open(v_path).convert("RGBA")
        cropped = v_img.crop((x_crop, y_crop, x_crop + w_crop, y_crop + h_crop))
        cropped = cropped.resize((cell_w, cell_h), Image.LANCZOS)
        bg_cell = Image.new("RGBA", (cell_w, cell_h), INK_BLACK)
        bg_cell.alpha_composite(cropped)
        sheet.paste(bg_cell, (x, y))

        label_y = y + cell_h
        drawer.rectangle(
            [x, label_y, x + cell_w, label_y + label_h],
            fill=LABEL_BAND,
        )
        try:
            bbox = drawer.textbbox((0, 0), vid, font=font)
            tw = bbox[2] - bbox[0]
            th = bbox[3] - bbox[1]
        except AttributeError:
            tw, th = drawer.textsize(vid, font=font)
        tx = x + (cell_w - tw) // 2
        ty = label_y + (label_h - th) // 2 - 4
        drawer.text((tx, ty), vid, fill=LABEL_FG, font=font)

    sheet.convert("RGB").save(out_path, "PNG", optimize=True)
    print(
        f"mouth-sheet: 16 visemes -> {out_path} ({W}x{H}, "
        f"crop centered on ({cx},{cy}) {w_crop}x{h_crop})",
        file=sys.stderr,
    )


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: contact_sheet_mouth.py VISEMES_DIR OUT [CONFIG_PATH]", file=sys.stderr)
        return 2
    visemes_dir = Path(sys.argv[1])
    out_path = Path(sys.argv[2])
    config_path = Path(sys.argv[3]) if len(sys.argv) > 3 else visemes_dir.parent / ".preview-config.json"
    mouth_xy = load_mouth_xy(config_path)
    build_sheet(visemes_dir, out_path, mouth_xy=mouth_xy)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
