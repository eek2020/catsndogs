#!/usr/bin/env python3
"""Generate a 32x32px tile atlas PNG for Godot TileMap.

Produces color-coded placeholder tiles with labels arranged in a grid atlas.
Supports terrain-compatible layout (3x3 minimal autotile per terrain type).

Terrain types produced:
  - Grass  (3x3 block, row 0-2, col 0-2)
  - Dirt   (3x3 block, row 0-2, col 3-5)
  - Stone  (3x3 block, row 0-2, col 6-8)
  - Wall   (3x3 block, row 3-5, col 0-2)
  - Water  (3x3 block, row 3-5, col 3-5)
  - Roof   (3x3 block, row 3-5, col 6-8)
  - Decor row (row 6): hedge, tree_trunk, tree_top, flower,
    barrel, crate, lamp, sign, door
  - Extra row (row 7): door_top, window, stairs_up, stairs_down,
    chest, table, chair, bed, rug

Output: single atlas PNG ready for Godot TileSet import.
"""

import argparse
import os
from PIL import Image, ImageDraw, ImageFont

TILE = 32
COLS = 9
ROWS = 8
WIDTH = COLS * TILE
HEIGHT = ROWS * TILE

# 3x3 autotile positions: top-left, top, top-right, left, center,
# right, bottom-left, bottom, bottom-right
AUTOTILE_LABELS = ["TL", "T", "TR", "L", "C", "R", "BL", "B", "BR"]

# Terrain definitions: (name, base_color, row_offset, col_offset)
TERRAINS = [
    ("Grass", "#3a7d32", 0, 0),
    ("Dirt", "#8b6c42", 0, 3),
    ("Stone", "#707070", 0, 6),
    ("Wall", "#4a4a5e", 3, 0),
    ("Water", "#2a5c8a", 3, 3),
    ("Roof", "#8b4040", 3, 6),
]

# Decor tiles: (label, color) — row 6
DECOR_TILES = [
    ("Hedge", "#2d6b2d"),
    ("Trunk", "#5c3a1e"),
    ("TreeT", "#1e7a1e"),
    ("Flower", "#d94ab0"),
    ("Barrel", "#7a5c28"),
    ("Crate", "#9e7a3c"),
    ("Lamp", "#d4c84a"),
    ("Sign", "#6e5020"),
    ("Door", "#6b3a1a"),
]

# Extra tiles: row 7
EXTRA_TILES = [
    ("DoorT", "#5a2e12"),
    ("Window", "#6aa0c8"),
    ("StUp", "#888888"),
    ("StDn", "#666666"),
    ("Chest", "#c8a832"),
    ("Table", "#7a5020"),
    ("Chair", "#6a4520"),
    ("Bed", "#9a3030"),
    ("Rug", "#8a4070"),
]


def _try_font(size: int):
    """Try to load a TrueType font, fall back to default."""
    # Ensure minimum size to avoid Pillow division-by-zero with tiny fonts
    size = max(size, 8)
    for path in [
        "/System/Library/Fonts/Geneva.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Courier.ttc",
        "/System/Library/Fonts/Avenir Next.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except (OSError, IOError):
            continue
    # Pillow 10+ default font supports size param
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def _hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    h = hex_color.lstrip("#")
    return (
        int(h[0:2], 16),
        int(h[2:4], 16),
        int(h[4:6], 16),
    )


def _darken(
    rgb: tuple[int, int, int], factor: float = 0.7
) -> tuple[int, int, int]:
    return (
        int(rgb[0] * factor),
        int(rgb[1] * factor),
        int(rgb[2] * factor),
    )


def _lighten(
    rgb: tuple[int, int, int], factor: float = 0.3
) -> tuple[int, int, int]:
    return (
        min(255, int(rgb[0] + (255 - rgb[0]) * factor)),
        min(255, int(rgb[1] + (255 - rgb[1]) * factor)),
        min(255, int(rgb[2] + (255 - rgb[2]) * factor)),
    )


def _draw_terrain_tile(
    draw: ImageDraw.ImageDraw, x: int, y: int, base_rgb: tuple,
    label: str, font
) -> None:
    """Draw a single terrain autotile cell with visual variation."""
    # Center tile is brightest, edges darker, corners darkest
    if label == "C":
        fill = base_rgb
    elif label in ("T", "B", "L", "R"):
        fill = _darken(base_rgb, 0.85)
    else:
        fill = _darken(base_rgb, 0.7)

    draw.rectangle(
        [x, y, x + TILE - 1, y + TILE - 1], fill=fill
    )

    # Edge indicators for non-center tiles
    edge_color = _darken(base_rgb, 0.5)
    if "T" in label and label != "TR":
        draw.line(
            [(x, y), (x + TILE - 1, y)], fill=edge_color, width=2
        )
    if "B" in label and label != "BR":
        draw.line(
            [(x, y + TILE - 1), (x + TILE - 1, y + TILE - 1)],
            fill=edge_color, width=2,
        )
    if "L" in label and label != "BL":
        draw.line(
            [(x, y), (x, y + TILE - 1)], fill=edge_color, width=2
        )
    if "R" in label and label != "TR":
        draw.line(
            [(x + TILE - 1, y), (x + TILE - 1, y + TILE - 1)],
            fill=edge_color, width=2,
        )

    # Label text
    text_color = _lighten(base_rgb, 0.6)
    bbox = draw.textbbox((0, 0), label, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = x + (TILE - tw) // 2
    ty = y + (TILE - th) // 2
    draw.text((tx, ty), label, fill=text_color, font=font)


def _draw_decor_tile(
    draw: ImageDraw.ImageDraw, x: int, y: int, hex_color: str, label: str, font
) -> None:
    """Draw a single decor/extra tile."""
    rgb = _hex_to_rgb(hex_color)
    # Background
    draw.rectangle([x, y, x + TILE - 1, y + TILE - 1], fill=rgb)
    # Border
    draw.rectangle(
        [x, y, x + TILE - 1, y + TILE - 1], outline=_darken(rgb, 0.5), width=1
    )
    # Centered label
    text_color = _lighten(rgb, 0.7)
    bbox = draw.textbbox((0, 0), label, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = x + (TILE - tw) // 2
    ty = y + (TILE - th) // 2
    draw.text((tx, ty), label, fill=text_color, font=font)


def generate_atlas(output_path: str) -> None:
    """Generate the complete tile atlas PNG."""
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    font = _try_font(7)

    # Draw terrain blocks (3x3 each)
    for name, hex_color, row_off, col_off in TERRAINS:
        base_rgb = _hex_to_rgb(hex_color)
        for local_row in range(3):
            for local_col in range(3):
                label = AUTOTILE_LABELS[local_row * 3 + local_col]
                px = (col_off + local_col) * TILE
                py = (row_off + local_row) * TILE
                _draw_terrain_tile(draw, px, py, base_rgb, label, font)

    # Draw decor row (row 6)
    for i, (label, hex_color) in enumerate(DECOR_TILES):
        px = i * TILE
        py = 6 * TILE
        _draw_decor_tile(draw, px, py, hex_color, label, font)

    # Draw extra row (row 7)
    for i, (label, hex_color) in enumerate(EXTRA_TILES):
        px = i * TILE
        py = 7 * TILE
        _draw_decor_tile(draw, px, py, hex_color, label, font)

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    img.save(output_path)
    print(
        f"Saved {output_path} ({WIDTH}x{HEIGHT}, "
        f"{COLS}x{ROWS} grid, {TILE}px tiles)"
    )


if __name__ == "__main__":
    p = argparse.ArgumentParser(
        description="Tile atlas generator for Godot TileMap"
    )
    default_out = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..",
        "..",
        "..",
        "godot",
        "assets",
        "tiles",
        "world_atlas.png",
    )
    p.add_argument(
        "-o", "--output", default=default_out, help="Output PNG path"
    )
    args = p.parse_args()
    output = os.path.normpath(args.output)
    generate_atlas(output)
