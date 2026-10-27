"""Split the v1 map-event icon board into individual 256x256 transparent PNGs.

Source: docs/美术/地图事件图标_生产简化稿_v1.png (2 rows x 4 columns).
Output: game/assets/map_icons/production_v1/<id>.png
The original art file is only read, never modified.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "美术" / "地图事件图标_生产简化稿_v1.png"
OUT_DIR = ROOT / "game" / "assets" / "map_icons" / "production_v1"
NAMES = [
    "battle_ordinary",
    "battle_elite",
    "event_clue",
    "rest",
    "shop_supply",
    "recruit",
    "memory_clue",
    "boss_acceptance",
]
CANVAS = 256
CONTENT_RATIO = 0.80  # icon body should fill ~80% of the canvas (design spec 76-82%)


def alpha_mask(image: Image.Image) -> np.ndarray:
    rgba = image.convert("RGBA")
    data = np.asarray(rgba)
    alpha = data[:, :, 3]
    if alpha.min() < 250:  # real alpha channel
        return alpha > 12
    # Fallback: treat near-white as background.
    rgb = data[:, :, :3].astype(np.int16)
    return rgb.min(axis=2) < 245


def runs(flags: np.ndarray) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    start = None
    for index, flag in enumerate(flags):
        if flag and start is None:
            start = index
        elif not flag and start is not None:
            result.append((start, index))
            start = None
    if start is not None:
        result.append((start, len(flags)))
    return [(a, b) for a, b in result if b - a > 8]


def main() -> int:
    if not SOURCE.exists():
        print(f"missing source: {SOURCE}")
        return 1
    image = Image.open(SOURCE).convert("RGBA")
    mask = alpha_mask(image)
    rows = runs(mask.any(axis=1))
    if len(rows) != 2:
        print(f"expected 2 icon rows, found {len(rows)}: {rows}")
        return 1
    cells: list[tuple[int, int, int, int]] = []
    for row_index, (y0, y1) in enumerate(rows):
        band = mask[y0:y1]
        cols = runs(band.any(axis=0))
        if len(cols) != 4:
            print(f"row {row_index}: expected 4 icons, found {len(cols)}: {cols}")
            return 1
        for x0, x1 in cols:
            sub = band[:, x0:x1]
            ys = np.where(sub.any(axis=1))[0]
            cells.append((x0, y0 + int(ys.min()), x1, y0 + int(ys.max()) + 1))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, (x0, y0, x1, y1) in zip(NAMES, cells):
        icon = image.crop((x0, y0, x1, y1))
        width, height = icon.size
        side = max(width, height)
        pad = int(round(side * (1.0 / CONTENT_RATIO - 1.0) * 0.5))
        canvas = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
        canvas.paste(icon, ((side - width) // 2 + pad, (side - height) // 2 + pad), icon)
        canvas = canvas.resize((CANVAS, CANVAS), Image.LANCZOS)
        target = OUT_DIR / f"{name}.png"
        canvas.save(target)
        print(f"{name}: cell=({x0},{y0},{x1},{y1}) size={width}x{height} -> {target.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
