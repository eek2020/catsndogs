#!/usr/bin/env python3
"""Generate a detailed pixel-art 32x32 tile atlas PNG for Godot TileMap.

Produces textured pixel-art tiles arranged in a grid atlas suitable for
building RPG town/settlement maps similar to classic 2D RPGs.

Layout (16 cols x 24 rows = 384 tiles, 512x768 atlas):
  Row 0-2:   Grass terrain (3x3 autotile + variants)
  Row 3-5:   Dirt/path terrain (3x3 autotile + variants)
  Row 6-8:   Stone/cobble terrain (3x3 autotile + variants)
  Row 9:     Water tiles (3x3 autotile + shores)
  Row 10:    Trees and vegetation
  Row 11:    Building walls (tan, grey stone, brown stone, timber)
  Row 12:    Building roofs (red, grey, brown, wood)
  Row 13:    Building details (doors, windows, signs, chimneys)
  Row 14:    Furniture and objects
  Row 15:    Fences, bridges (wood + stone), stairs
  Row 16:    Tower components (walls, roofs, windows)
  Row 17:    Roof edge pieces (all 3 colors, corners)
  Row 18:    Water transitions (grass-water edges)
  Row 19:    Decorative elements (gates, arches, wells)
  Row 20:    Extended vegetation (pine, bush variants)
  Row 21-23: Reserved for future expansion

Output: single atlas PNG ready for Godot TileSet import.
"""

import argparse
import os
import random
from PIL import Image, ImageDraw

TILE = 32
COLS = 16
ROWS = 24
WIDTH = COLS * TILE
HEIGHT = ROWS * TILE


def _hex(h: str) -> tuple:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def _rgba(r, g, b, a=255):
    return (int(r), int(g), int(b), int(a))


def _vary(base: tuple, amt: int = 12) -> tuple:
    """Add slight random variation to a color."""
    return _rgba(
        max(0, min(255, base[0] + random.randint(-amt, amt))),
        max(0, min(255, base[1] + random.randint(-amt, amt))),
        max(0, min(255, base[2] + random.randint(-amt, amt))),
        base[3] if len(base) > 3 else 255,
    )


def _darken(c: tuple, factor: float = 0.75) -> tuple:
    return _rgba(c[0] * factor, c[1] * factor, c[2] * factor, c[3] if len(c) > 3 else 255)


def _lighten(c: tuple, factor: float = 0.3) -> tuple:
    return _rgba(
        min(255, c[0] + (255 - c[0]) * factor),
        min(255, c[1] + (255 - c[1]) * factor),
        min(255, c[2] + (255 - c[2]) * factor),
        c[3] if len(c) > 3 else 255,
    )


def _blend(c1: tuple, c2: tuple, t: float) -> tuple:
    """Blend two colors. t=0 returns c1, t=1 returns c2."""
    return _rgba(
        c1[0] + (c2[0] - c1[0]) * t,
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        255,
    )


# ── Color Palettes ──────────────────────────────────────────────────────

GRASS_BASE = _hex("#4a8c38")
GRASS_LIGHT = _hex("#5ca045")
GRASS_DARK = _hex("#3a7228")
GRASS_ACCENT = _hex("#68b050")  # flower/blade highlights

DIRT_BASE = _hex("#8b7248")
DIRT_LIGHT = _hex("#a08858")
DIRT_DARK = _hex("#6e5a38")
DIRT_PEBBLE = _hex("#7a6840")

STONE_BASE = _hex("#808080")
STONE_LIGHT = _hex("#989898")
STONE_DARK = _hex("#606060")
STONE_CRACK = _hex("#505050")
STONE_MORTAR = _hex("#909088")

WATER_BASE = _hex("#2860a0")
WATER_LIGHT = _hex("#4080c0")
WATER_DARK = _hex("#1a4878")
WATER_FOAM = _hex("#88c0e8")
WATER_DEEP = _hex("#183860")

WOOD_BASE = _hex("#7a5428")
WOOD_LIGHT = _hex("#926830")
WOOD_DARK = _hex("#5c3e1e")
WOOD_GRAIN = _hex("#684820")

WALL_BASE = _hex("#c0a878")
WALL_LIGHT = _hex("#d0b888")
WALL_DARK = _hex("#a09060")
WALL_MORTAR = _hex("#b0a070")

ROOF_BASE = _hex("#8b4040")
ROOF_LIGHT = _hex("#a05050")
ROOF_DARK = _hex("#6e3030")
ROOF_TILE = _hex("#7a3838")

TREE_TRUNK = _hex("#5c3a1e")
TREE_TRUNK_DARK = _hex("#4a2e16")
TREE_CANOPY = _hex("#2a7a28")
TREE_CANOPY_LIGHT = _hex("#3a9a38")
TREE_CANOPY_DARK = _hex("#1e5e1c")

FENCE_BASE = _hex("#8a6a38")
FENCE_DARK = _hex("#6a5028")

DOOR_BASE = _hex("#6b3a1a")
DOOR_FRAME = _hex("#5a2e14")
DOOR_HANDLE = _hex("#c8a832")

WINDOW_BASE = _hex("#6aa8d0")
WINDOW_FRAME = _hex("#5a4030")
WINDOW_LIGHT = _hex("#90c8e8")

SIGN_BASE = _hex("#7a5a28")
SIGN_TEXT = _hex("#e0d0a0")

CHEST_BASE = _hex("#b88a30")
CHEST_DARK = _hex("#8a6820")
CHEST_CLASP = _hex("#d0c060")

BARREL_BASE = _hex("#7a5428")
BARREL_BAND = _hex("#585858")

FLOWER_RED = _hex("#d04040")
FLOWER_YELLOW = _hex("#d8c040")
FLOWER_PURPLE = _hex("#8040a0")
FLOWER_STEM = _hex("#3a7828")

# ── Fringe Haven Color Extensions ────────────────────────────────────────

# Stone variants for tower and stone buildings
STONE_GREY_BASE = _hex("#8a8a8a")      # Cool grey for tower/stone buildings
STONE_GREY_LIGHT = _hex("#aaaaaa")
STONE_GREY_DARK = _hex("#6a6a6a")
STONE_GREY_MORTAR = _hex("#7a7a7a")

STONE_BROWN_BASE = _hex("#9a7a5a")      # Warm brown-grey stone
STONE_BROWN_LIGHT = _hex("#ba9a7a")
STONE_BROWN_DARK = _hex("#7a5a3a")
STONE_BROWN_MORTAR = _hex("#8a6a4a")

# Roof color variants
ROOF_RED_BASE = _hex("#a05040")        # Terracotta red (Tipsy Tankard style)
ROOF_RED_LIGHT = _hex("#c07060")
ROOF_RED_DARK = _hex("#803020")
ROOF_RED_TILE = _hex("#904030")

ROOF_GREY_BASE = _hex("#708090")       # Slate grey (Bryn's Oddities style)
ROOF_GREY_LIGHT = _hex("#90a0b0")
ROOF_GREY_DARK = _hex("#506070")
ROOF_GREY_TILE = _hex("#607080")

ROOF_BROWN_BASE = _hex("#6a4a3a")      # Dark thatch/timber
ROOF_BROWN_LIGHT = _hex("#8a6a5a")
ROOF_BROWN_DARK = _hex("#4a2a1a")
ROOF_BROWN_TILE = _hex("#5a3a2a")

ROOF_GREEN_BASE = _hex("#4d7a4a")      # Fringe Haven green roof accents
ROOF_GREEN_LIGHT = _hex("#6a9c64")
ROOF_GREEN_DARK = _hex("#355834")
ROOF_GREEN_TILE = _hex("#436a40")

# Enhanced Fringe Haven grass (brighter, more vibrant)
GRASS_OAK_BASE = _hex("#5a9a45")
GRASS_OAK_LIGHT = _hex("#7bc462")
GRASS_OAK_DARK = _hex("#3d6b30")

# Water edge foam for shorelines
WATER_EDGE_FOAM = _hex("#c8e8f8")
WATER_EDGE_DEEP = _hex("#1a4878")

# Chimney stone
CHIMNEY_BASE = _hex("#7a7a7a")
CHIMNEY_DARK = _hex("#5a5a5a")
CHIMNEY_LIGHT = _hex("#9a9a9a")


# ── Tile Drawing Functions ──────────────────────────────────────────────

def draw_grass_tile(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a textured grass tile with random blade patterns."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    # Base fill
    for y in range(TILE):
        for x in range(TILE):
            c = GRASS_BASE
            noise = rng.randint(-8, 8)
            c = _rgba(max(0, min(255, c[0] + noise)), max(0, min(255, c[1] + noise + 3)), max(0, min(255, c[2] + noise - 2)))
            img.putpixel((ox + x, oy + y), c)
    # Grass blades
    for _ in range(rng.randint(8, 15)):
        bx = rng.randint(1, TILE - 2)
        by = rng.randint(2, TILE - 1)
        blade_h = rng.randint(2, 5)
        blade_c = GRASS_LIGHT if rng.random() > 0.4 else GRASS_ACCENT
        for bh in range(blade_h):
            py = by - bh
            if 0 <= py < TILE:
                img.putpixel((ox + bx, oy + py), _vary(blade_c, 6))
    # Dark spots
    for _ in range(rng.randint(3, 6)):
        dx = rng.randint(0, TILE - 2)
        dy = rng.randint(0, TILE - 2)
        img.putpixel((ox + dx, oy + dy), _vary(GRASS_DARK, 8))


def draw_grass_edge(img: Image.Image, ox: int, oy: int, edge: str, other_base: tuple):
    """Draw grass tile with edge transition to another terrain."""
    rng = random.Random(hash(edge) + ox * 100 + oy)
    # Fill grass first
    draw_grass_tile(img, ox, oy, variant=hash(edge))
    # Draw transition edge strip
    edge_width = 6
    for y in range(TILE):
        for x in range(TILE):
            t = 0.0
            if "T" in edge and y < edge_width:
                t = max(t, 1.0 - y / edge_width)
            if "B" in edge and y >= TILE - edge_width:
                t = max(t, (y - (TILE - edge_width)) / edge_width)
            if "L" in edge and x < edge_width:
                t = max(t, 1.0 - x / edge_width)
            if "R" in edge and x >= TILE - edge_width:
                t = max(t, (x - (TILE - edge_width)) / edge_width)
            if t > 0:
                current = img.getpixel((ox + x, oy + y))
                blended = _blend(current, other_base, t * 0.7)
                img.putpixel((ox + x, oy + y), blended)


def draw_dirt_tile(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a textured dirt/path tile with pebbles."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    for y in range(TILE):
        for x in range(TILE):
            noise = rng.randint(-10, 10)
            c = _rgba(max(0, min(255, DIRT_BASE[0] + noise)), max(0, min(255, DIRT_BASE[1] + noise - 2)), max(0, min(255, DIRT_BASE[2] + noise - 4)))
            img.putpixel((ox + x, oy + y), c)
    # Pebbles
    for _ in range(rng.randint(4, 10)):
        px = rng.randint(1, TILE - 3)
        py = rng.randint(1, TILE - 3)
        pc = _vary(DIRT_PEBBLE, 15) if rng.random() > 0.5 else _vary(DIRT_DARK, 10)
        img.putpixel((ox + px, oy + py), pc)
        if rng.random() > 0.5:
            img.putpixel((ox + px + 1, oy + py), _vary(pc, 5))


def draw_dirt_edge(img: Image.Image, ox: int, oy: int, edge: str, other_base: tuple):
    """Draw dirt tile with edge transition."""
    rng = random.Random(hash(edge) + ox * 100 + oy)
    draw_dirt_tile(img, ox, oy, variant=hash(edge))
    edge_width = 5
    for y in range(TILE):
        for x in range(TILE):
            t = 0.0
            if "T" in edge and y < edge_width:
                t = max(t, 1.0 - y / edge_width)
            if "B" in edge and y >= TILE - edge_width:
                t = max(t, (y - (TILE - edge_width)) / edge_width)
            if "L" in edge and x < edge_width:
                t = max(t, 1.0 - x / edge_width)
            if "R" in edge and x >= TILE - edge_width:
                t = max(t, (x - (TILE - edge_width)) / edge_width)
            if t > 0:
                current = img.getpixel((ox + x, oy + y))
                blended = _blend(current, other_base, t * 0.6)
                img.putpixel((ox + x, oy + y), blended)


def draw_stone_tile(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a cobblestone tile with mortar lines."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    draw = ImageDraw.Draw(img)
    # Fill base
    for y in range(TILE):
        for x in range(TILE):
            noise = rng.randint(-6, 6)
            c = _rgba(STONE_BASE[0] + noise, STONE_BASE[1] + noise, STONE_BASE[2] + noise)
            img.putpixel((ox + x, oy + y), c)
    # Cobblestone grid — irregular brick pattern
    mortar_color = _vary(STONE_MORTAR, 5)
    brick_h = 8
    for row in range(4):
        y_line = row * brick_h
        if 0 <= y_line < TILE:
            for x in range(TILE):
                img.putpixel((ox + x, oy + y_line), _vary(STONE_CRACK, 8))
        offset = (row % 2) * 10 + rng.randint(-2, 2)
        for col_pos in range(offset, TILE, rng.randint(10, 16)):
            if 0 <= col_pos < TILE:
                for dy in range(brick_h):
                    py = y_line + dy
                    if 0 <= py < TILE:
                        img.putpixel((ox + col_pos, oy + py), _vary(STONE_CRACK, 8))
    # Highlight some stones
    for _ in range(rng.randint(3, 6)):
        sx = rng.randint(2, TILE - 4)
        sy = rng.randint(2, TILE - 4)
        sc = STONE_LIGHT if rng.random() > 0.5 else STONE_DARK
        for dy in range(2):
            for dx in range(2):
                if 0 <= ox + sx + dx < WIDTH and 0 <= oy + sy + dy < HEIGHT:
                    img.putpixel((ox + sx + dx, oy + sy + dy), _vary(sc, 8))


def draw_water_tile(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw an animated-style water tile with ripples."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    import math
    for y in range(TILE):
        for x in range(TILE):
            wave = math.sin((x + variant * 3) * 0.3) * 8 + math.cos((y + variant * 5) * 0.4) * 5
            base_val = int(wave)
            c = _rgba(
                max(0, min(255, WATER_BASE[0] + base_val)),
                max(0, min(255, WATER_BASE[1] + base_val + 3)),
                max(0, min(255, WATER_BASE[2] + base_val + 8)),
            )
            img.putpixel((ox + x, oy + y), c)
    # Light ripple highlights
    for _ in range(rng.randint(3, 8)):
        rx = rng.randint(2, TILE - 4)
        ry = rng.randint(2, TILE - 4)
        rlen = rng.randint(3, 8)
        for dx in range(rlen):
            if rx + dx < TILE:
                img.putpixel((ox + rx + dx, oy + ry), _vary(WATER_LIGHT, 10))


def draw_water_shore(img: Image.Image, ox: int, oy: int, edge: str):
    """Draw water tile with land edge (foam/shore)."""
    draw_water_tile(img, ox, oy, variant=hash(edge))
    shore_width = 5
    for y in range(TILE):
        for x in range(TILE):
            in_shore = False
            if "T" in edge and y < shore_width:
                in_shore = True
            if "B" in edge and y >= TILE - shore_width:
                in_shore = True
            if "L" in edge and x < shore_width:
                in_shore = True
            if "R" in edge and x >= TILE - shore_width:
                in_shore = True
            if in_shore:
                current = img.getpixel((ox + x, oy + y))
                img.putpixel((ox + x, oy + y), _blend(current, WATER_FOAM, 0.4))


def draw_tree_canopy(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a tree canopy top tile (lush round tree top)."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    cx, cy = TILE // 2, TILE // 2
    radius = 13
    for y in range(TILE):
        for x in range(TILE):
            dx = x - cx
            dy = y - cy
            dist = (dx * dx + dy * dy) ** 0.5
            if dist <= radius:
                # Inside canopy
                noise = rng.randint(-10, 10)
                t = dist / radius
                if t < 0.5:
                    c = _vary(TREE_CANOPY_LIGHT, 8)
                elif t < 0.8:
                    c = _vary(TREE_CANOPY, 8)
                else:
                    c = _vary(TREE_CANOPY_DARK, 8)
                img.putpixel((ox + x, oy + y), c)
            elif dist <= radius + 1:
                # Edge pixel — dark outline
                img.putpixel((ox + x, oy + y), TREE_CANOPY_DARK)
    # Leaf highlights
    for _ in range(rng.randint(5, 10)):
        lx = cx + rng.randint(-10, 10)
        ly = cy + rng.randint(-10, 10)
        if 0 <= lx < TILE and 0 <= ly < TILE:
            dx = lx - cx
            dy = ly - cy
            if (dx * dx + dy * dy) ** 0.5 < radius - 2:
                img.putpixel((ox + lx, oy + ly), _vary(TREE_CANOPY_LIGHT, 12))


def draw_tree_trunk(img: Image.Image, ox: int, oy: int):
    """Draw a tree trunk base tile (trunk on grass)."""
    draw_grass_tile(img, ox, oy, variant=99)
    # Trunk in center
    trunk_w = 6
    trunk_left = TILE // 2 - trunk_w // 2
    for y in range(TILE):
        for x in range(trunk_w):
            tx = trunk_left + x
            if x == 0 or x == trunk_w - 1:
                c = TREE_TRUNK_DARK
            else:
                c = _vary(TREE_TRUNK, 8)
            img.putpixel((ox + tx, oy + y), c)
    # Root flare at bottom
    for x in range(trunk_left - 2, trunk_left + trunk_w + 2):
        if 0 <= x < TILE:
            img.putpixel((ox + x, oy + TILE - 1), _vary(TREE_TRUNK_DARK, 5))
            img.putpixel((ox + x, oy + TILE - 2), _vary(TREE_TRUNK, 8))


def draw_building_wall(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a building wall tile (plaster/wood with beam accents)."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    for y in range(TILE):
        for x in range(TILE):
            noise = rng.randint(-5, 5)
            c = _rgba(WALL_BASE[0] + noise, WALL_BASE[1] + noise - 2, WALL_BASE[2] + noise - 3)
            img.putpixel((ox + x, oy + y), c)
    # Horizontal beam
    beam_y = TILE // 2
    for x in range(TILE):
        for dy in range(-1, 2):
            if 0 <= beam_y + dy < TILE:
                img.putpixel((ox + x, oy + beam_y + dy), _vary(WOOD_BASE, 8))
    # Vertical beams
    for bx in [0, TILE - 1]:
        for y in range(TILE):
            img.putpixel((ox + bx, oy + y), _vary(WOOD_DARK, 5))


def draw_building_roof(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a roof tile with shingle pattern."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    for y in range(TILE):
        for x in range(TILE):
            noise = rng.randint(-6, 6)
            c = _rgba(ROOF_BASE[0] + noise, ROOF_BASE[1] + noise - 2, ROOF_BASE[2] + noise - 2)
            img.putpixel((ox + x, oy + y), c)
    # Shingle rows
    for row in range(0, TILE, 6):
        offset = (row // 6 % 2) * 8
        for x in range(TILE):
            img.putpixel((ox + x, oy + row), _vary(ROOF_DARK, 5))
        for col in range(offset, TILE, 16):
            if 0 <= col < TILE:
                for dy in range(min(6, TILE - row)):
                    img.putpixel((ox + col, oy + row + dy), _vary(ROOF_DARK, 8))
    # Highlights
    for _ in range(rng.randint(2, 5)):
        hx = rng.randint(2, TILE - 3)
        hy = rng.randint(2, TILE - 3)
        img.putpixel((ox + hx, oy + hy), _vary(ROOF_LIGHT, 10))


def draw_door(img: Image.Image, ox: int, oy: int):
    """Draw a wooden door tile."""
    # Frame background
    draw_building_wall(img, ox, oy, variant=77)
    # Door shape
    door_w = 14
    door_h = 24
    dx_start = TILE // 2 - door_w // 2
    dy_start = TILE - door_h
    draw = ImageDraw.Draw(img)
    # Door frame
    draw.rectangle([ox + dx_start - 1, oy + dy_start - 1, ox + dx_start + door_w, oy + TILE - 1], fill=DOOR_FRAME)
    # Door panels
    for y in range(door_h):
        for x in range(door_w):
            noise_val = random.randint(-4, 4)
            c = _rgba(DOOR_BASE[0] + noise_val, DOOR_BASE[1] + noise_val, DOOR_BASE[2] + noise_val)
            img.putpixel((ox + dx_start + x, oy + dy_start + y), c)
    # Wood grain lines
    for gy in range(dy_start, dy_start + door_h, 4):
        for x in range(door_w):
            if 0 <= oy + gy < HEIGHT:
                img.putpixel((ox + dx_start + x, oy + gy), _vary(WOOD_GRAIN, 5))
    # Handle
    hx = dx_start + door_w - 4
    hy = dy_start + door_h // 2
    img.putpixel((ox + hx, oy + hy), DOOR_HANDLE)
    img.putpixel((ox + hx + 1, oy + hy), DOOR_HANDLE)


def draw_window(img: Image.Image, ox: int, oy: int):
    """Draw a window tile on a wall."""
    draw_building_wall(img, ox, oy, variant=88)
    win_w = 14
    win_h = 12
    wx = TILE // 2 - win_w // 2
    wy = TILE // 2 - win_h // 2
    draw = ImageDraw.Draw(img)
    # Frame
    draw.rectangle([ox + wx - 1, oy + wy - 1, ox + wx + win_w, oy + wy + win_h], fill=WINDOW_FRAME)
    # Glass
    for y in range(win_h):
        for x in range(win_w):
            c = WINDOW_LIGHT if (x + y) % 3 == 0 else WINDOW_BASE
            img.putpixel((ox + wx + x, oy + wy + y), _vary(c, 5))
    # Cross frame
    mid_x = wx + win_w // 2
    mid_y = wy + win_h // 2
    for x in range(win_w):
        img.putpixel((ox + wx + x, oy + mid_y), WINDOW_FRAME)
    for y in range(win_h):
        img.putpixel((ox + mid_x, oy + wy + y), WINDOW_FRAME)


def draw_sign(img: Image.Image, ox: int, oy: int):
    """Draw a hanging sign on a post."""
    draw_grass_tile(img, ox, oy, variant=55)
    # Post
    post_x = TILE // 2
    for y in range(8, TILE):
        img.putpixel((ox + post_x, oy + y), _vary(WOOD_DARK, 5))
    # Sign board
    sw = 18
    sh = 10
    sx = TILE // 2 - sw // 2
    sy = 4
    draw = ImageDraw.Draw(img)
    draw.rectangle([ox + sx, oy + sy, ox + sx + sw - 1, oy + sy + sh - 1], fill=SIGN_BASE)
    draw.rectangle([ox + sx, oy + sy, ox + sx + sw - 1, oy + sy + sh - 1], outline=WOOD_DARK)
    # "Text" lines
    for ly in range(sy + 2, sy + sh - 2, 3):
        for lx in range(sx + 2, sx + sw - 3):
            img.putpixel((ox + lx, oy + ly), _vary(SIGN_TEXT, 10))


def draw_chest(img: Image.Image, ox: int, oy: int, opened: bool = False):
    """Draw a treasure chest."""
    draw_grass_tile(img, ox, oy, variant=44)
    cw = 16
    ch = 12
    cx_start = TILE // 2 - cw // 2
    cy_start = TILE // 2 - ch // 2 + 4
    draw = ImageDraw.Draw(img)
    # Body
    body_color = CHEST_BASE if not opened else CHEST_DARK
    draw.rectangle([ox + cx_start, oy + cy_start, ox + cx_start + cw - 1, oy + cy_start + ch - 1], fill=body_color)
    draw.rectangle([ox + cx_start, oy + cy_start, ox + cx_start + cw - 1, oy + cy_start + ch - 1], outline=CHEST_DARK)
    # Lid highlight
    for x in range(cw):
        img.putpixel((ox + cx_start + x, oy + cy_start), _vary(_lighten(body_color, 0.2), 3))
        img.putpixel((ox + cx_start + x, oy + cy_start + 1), _vary(body_color, 3))
    # Band
    mid_y = cy_start + ch // 2
    for x in range(cw):
        img.putpixel((ox + cx_start + x, oy + mid_y), BARREL_BAND)
    # Clasp
    clasp_x = TILE // 2
    img.putpixel((ox + clasp_x, oy + mid_y), CHEST_CLASP)
    img.putpixel((ox + clasp_x - 1, oy + mid_y), CHEST_CLASP)


def draw_barrel(img: Image.Image, ox: int, oy: int):
    """Draw a barrel."""
    draw_grass_tile(img, ox, oy, variant=33)
    bw = 14
    bh = 16
    bx = TILE // 2 - bw // 2
    by = TILE // 2 - bh // 2 + 2
    for y in range(bh):
        # Barrel is wider in middle
        bulge = 1 if abs(y - bh // 2) < bh // 3 else 0
        for x in range(-bulge, bw + bulge):
            px = bx + x
            if 0 <= px < TILE:
                noise = random.randint(-5, 5)
                c = _rgba(BARREL_BASE[0] + noise, BARREL_BASE[1] + noise, BARREL_BASE[2] + noise)
                img.putpixel((ox + px, oy + by + y), c)
    # Metal bands
    for band_y in [by + 2, by + bh - 3, by + bh // 2]:
        for x in range(bw + 2):
            px = bx - 1 + x
            if 0 <= px < TILE and 0 <= band_y < TILE:
                img.putpixel((ox + px, oy + band_y), _vary(BARREL_BAND, 5))


def draw_fence_h(img: Image.Image, ox: int, oy: int):
    """Draw a horizontal fence segment on grass."""
    draw_grass_tile(img, ox, oy, variant=22)
    # Posts at edges
    for post_x in [4, TILE - 5]:
        for y in range(8, TILE - 4):
            for dx in range(3):
                img.putpixel((ox + post_x + dx, oy + y), _vary(FENCE_BASE, 5))
        # Post top
        for dx in range(3):
            img.putpixel((ox + post_x + dx, oy + 8), _vary(FENCE_DARK, 3))
    # Horizontal rails
    for rail_y in [12, 18]:
        for x in range(4, TILE - 4):
            img.putpixel((ox + x, oy + rail_y), _vary(FENCE_BASE, 5))
            img.putpixel((ox + x, oy + rail_y + 1), _vary(FENCE_DARK, 5))


def draw_fence_v(img: Image.Image, ox: int, oy: int):
    """Draw a vertical fence segment on grass."""
    draw_grass_tile(img, ox, oy, variant=23)
    # Post in center
    post_x = TILE // 2 - 1
    for y in range(TILE):
        for dx in range(3):
            img.putpixel((ox + post_x + dx, oy + y), _vary(FENCE_BASE, 5))
    # Horizontal rail nubs
    for rail_y in [6, TILE - 7]:
        for x in range(post_x - 4, post_x + 7):
            if 0 <= x < TILE:
                img.putpixel((ox + x, oy + rail_y), _vary(FENCE_BASE, 5))


def draw_flower_patch(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw flowers on grass."""
    draw_grass_tile(img, ox, oy, variant=variant + 60)
    rng = random.Random(variant * 1000 + ox + oy)
    colors = [FLOWER_RED, FLOWER_YELLOW, FLOWER_PURPLE]
    for _ in range(rng.randint(4, 8)):
        fx = rng.randint(3, TILE - 4)
        fy = rng.randint(3, TILE - 4)
        fc = colors[rng.randint(0, 2)]
        # Stem
        img.putpixel((ox + fx, oy + fy + 1), FLOWER_STEM)
        img.putpixel((ox + fx, oy + fy + 2), FLOWER_STEM)
        # Petals
        img.putpixel((ox + fx, oy + fy), fc)
        img.putpixel((ox + fx - 1, oy + fy), _vary(fc, 15))
        img.putpixel((ox + fx + 1, oy + fy), _vary(fc, 15))


def draw_lamp(img: Image.Image, ox: int, oy: int):
    """Draw a street lamp on grass."""
    draw_grass_tile(img, ox, oy, variant=11)
    post_x = TILE // 2
    # Post
    for y in range(8, TILE - 2):
        img.putpixel((ox + post_x, oy + y), _vary(BARREL_BAND, 5))
    # Lamp top
    lamp_color = _hex("#d8c050")
    glow = _hex("#f0e880")
    for dx in range(-2, 3):
        img.putpixel((ox + post_x + dx, oy + 8), _vary(BARREL_BAND, 3))
    for dx in range(-1, 2):
        for dy in range(5, 8):
            img.putpixel((ox + post_x + dx, oy + dy), _vary(lamp_color, 5))
    # Glow
    img.putpixel((ox + post_x, oy + 6), glow)


def draw_crate(img: Image.Image, ox: int, oy: int):
    """Draw a wooden crate on grass."""
    draw_grass_tile(img, ox, oy, variant=66)
    cw = 14
    ch = 14
    cx = TILE // 2 - cw // 2
    cy = TILE // 2 - ch // 2 + 2
    draw = ImageDraw.Draw(img)
    crate_color = _hex("#9e7a3c")
    crate_dark = _hex("#7a5e28")
    draw.rectangle([ox + cx, oy + cy, ox + cx + cw - 1, oy + cy + ch - 1], fill=crate_color)
    draw.rectangle([ox + cx, oy + cy, ox + cx + cw - 1, oy + cy + ch - 1], outline=crate_dark)
    # Cross boards
    draw.line([ox + cx, oy + cy, ox + cx + cw - 1, oy + cy + ch - 1], fill=crate_dark, width=1)
    draw.line([ox + cx + cw - 1, oy + cy, ox + cx, oy + cy + ch - 1], fill=crate_dark, width=1)


def draw_bridge_h(img: Image.Image, ox: int, oy: int):
    """Draw a horizontal bridge tile over water."""
    draw_water_tile(img, ox, oy, variant=7)
    # Bridge planks
    plank_top = 8
    plank_bot = TILE - 8
    for y in range(plank_top, plank_bot):
        for x in range(TILE):
            c = WOOD_BASE if (x // 8) % 2 == 0 else WOOD_LIGHT
            img.putpixel((ox + x, oy + y), _vary(c, 5))
    # Rails
    for x in range(TILE):
        img.putpixel((ox + x, oy + plank_top), WOOD_DARK)
        img.putpixel((ox + x, oy + plank_bot - 1), WOOD_DARK)


def draw_stairs(img: Image.Image, ox: int, oy: int, going_up: bool = True):
    """Draw stairs tile."""
    draw_stone_tile(img, ox, oy, variant=5)
    step_count = 5
    step_h = TILE // step_count
    for i in range(step_count):
        y = i * step_h if going_up else (step_count - 1 - i) * step_h
        shade = 0.7 + 0.06 * i
        c = _rgba(STONE_BASE[0] * shade, STONE_BASE[1] * shade, STONE_BASE[2] * shade)
        for dy in range(step_h):
            for x in range(TILE):
                img.putpixel((ox + x, oy + y + dy), _vary(c, 4))
        # Step edge highlight
        for x in range(TILE):
            img.putpixel((ox + x, oy + y), _vary(STONE_LIGHT, 5))


def draw_empty(img: Image.Image, ox: int, oy: int):
    """Draw a transparent/empty tile."""
    for y in range(TILE):
        for x in range(TILE):
            img.putpixel((ox + x, oy + y), (0, 0, 0, 0))


def draw_marker(img: Image.Image, ox: int, oy: int, color: tuple, label: str = ""):
    """Draw a colored marker tile (for sparkle/interact indicators)."""
    draw_empty(img, ox, oy)
    cx, cy = TILE // 2, TILE // 2
    for y in range(TILE):
        for x in range(TILE):
            dx = x - cx
            dy = y - cy
            dist = (dx * dx + dy * dy) ** 0.5
            if dist < 6:
                a = int(255 * (1.0 - dist / 6.0))
                img.putpixel((ox + x, oy + y), _rgba(color[0], color[1], color[2], a))


def draw_stone_grey_wall(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a cool grey stone wall tile (tower/stone buildings)."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    # Base fill with noise
    for y in range(TILE):
        for x in range(TILE):
            noise = rng.randint(-6, 6)
            c = _rgba(STONE_GREY_BASE[0] + noise, STONE_GREY_BASE[1] + noise, STONE_GREY_BASE[2] + noise)
            img.putpixel((ox + x, oy + y), c)
    # Irregular stone block pattern
    block_h = 10
    for row in range(4):
        y_line = row * block_h
        offset = (row % 2) * 8 + rng.randint(-2, 2)
        # Horizontal mortar
        for x in range(TILE):
            img.putpixel((ox + x, oy + y_line), _vary(STONE_GREY_MORTAR, 5))
        # Vertical mortar lines
        for col_pos in range(offset, TILE, rng.randint(12, 18)):
            for dy in range(block_h):
                py = y_line + dy
                if 0 <= py < TILE:
                    img.putpixel((ox + col_pos, oy + py), _vary(STONE_GREY_MORTAR, 5))
    # Highlight some stones
    for _ in range(rng.randint(4, 8)):
        sx = rng.randint(2, TILE - 6)
        sy = rng.randint(2, TILE - 6)
        sc = STONE_GREY_LIGHT if rng.random() > 0.5 else STONE_GREY_DARK
        for dy in range(3):
            for dx in range(3):
                img.putpixel((ox + sx + dx, oy + sy + dy), _vary(sc, 8))


def draw_stone_brown_wall(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a warm brown-grey stone wall tile."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    # Base fill with noise
    for y in range(TILE):
        for x in range(TILE):
            noise = rng.randint(-6, 6)
            c = _rgba(STONE_BROWN_BASE[0] + noise, STONE_BROWN_BASE[1] + noise - 2, STONE_BROWN_BASE[2] + noise - 4)
            img.putpixel((ox + x, oy + y), c)
    # Irregular stone block pattern
    block_h = 10
    for row in range(4):
        y_line = row * block_h
        offset = (row % 2) * 8 + rng.randint(-2, 2)
        # Horizontal mortar
        for x in range(TILE):
            img.putpixel((ox + x, oy + y_line), _vary(STONE_BROWN_MORTAR, 5))
        # Vertical mortar lines
        for col_pos in range(offset, TILE, rng.randint(12, 18)):
            for dy in range(block_h):
                py = y_line + dy
                if 0 <= py < TILE:
                    img.putpixel((ox + col_pos, oy + py), _vary(STONE_BROWN_MORTAR, 5))
    # Highlight some stones
    for _ in range(rng.randint(4, 8)):
        sx = rng.randint(2, TILE - 6)
        sy = rng.randint(2, TILE - 6)
        sc = STONE_BROWN_LIGHT if rng.random() > 0.5 else STONE_BROWN_DARK
        for dy in range(3):
            for dx in range(3):
                img.putpixel((ox + sx + dx, oy + sy + dy), _vary(sc, 8))


def draw_roof_red(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a terracotta red roof tile."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    # Base fill
    for y in range(TILE):
        for x in range(TILE):
            noise = rng.randint(-6, 6)
            c = _rgba(ROOF_RED_BASE[0] + noise, ROOF_RED_BASE[1] + noise - 2, ROOF_RED_BASE[2] + noise - 2)
            img.putpixel((ox + x, oy + y), c)
    # Shingle rows
    for row in range(0, TILE, 6):
        offset = (row // 6 % 2) * 8
        for x in range(TILE):
            img.putpixel((ox + x, oy + row), _vary(ROOF_RED_DARK, 5))
        for col in range(offset, TILE, 16):
            if 0 <= col < TILE:
                for dy in range(min(6, TILE - row)):
                    img.putpixel((ox + col, oy + row + dy), _vary(ROOF_RED_DARK, 8))
    # Highlights
    for _ in range(rng.randint(2, 5)):
        hx = rng.randint(2, TILE - 3)
        hy = rng.randint(2, TILE - 3)
        img.putpixel((ox + hx, oy + hy), _vary(ROOF_RED_LIGHT, 10))


def draw_roof_grey(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a slate grey roof tile."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    # Base fill
    for y in range(TILE):
        for x in range(TILE):
            noise = rng.randint(-6, 6)
            c = _rgba(ROOF_GREY_BASE[0] + noise, ROOF_GREY_BASE[1] + noise, ROOF_GREY_BASE[2] + noise)
            img.putpixel((ox + x, oy + y), c)
    # Shingle rows
    for row in range(0, TILE, 6):
        offset = (row // 6 % 2) * 8
        for x in range(TILE):
            img.putpixel((ox + x, oy + row), _vary(ROOF_GREY_DARK, 5))
        for col in range(offset, TILE, 16):
            if 0 <= col < TILE:
                for dy in range(min(6, TILE - row)):
                    img.putpixel((ox + col, oy + row + dy), _vary(ROOF_GREY_DARK, 8))
    # Highlights
    for _ in range(rng.randint(2, 5)):
        hx = rng.randint(2, TILE - 3)
        hy = rng.randint(2, TILE - 3)
        img.putpixel((ox + hx, oy + hy), _vary(ROOF_GREY_LIGHT, 10))


def draw_roof_brown(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a dark brown thatch/timber roof tile."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    # Base fill
    for y in range(TILE):
        for x in range(TILE):
            noise = rng.randint(-6, 6)
            c = _rgba(ROOF_BROWN_BASE[0] + noise, ROOF_BROWN_BASE[1] + noise - 2, ROOF_BROWN_BASE[2] + noise - 2)
            img.putpixel((ox + x, oy + y), c)
    # Thatch pattern - more organic lines
    for row in range(0, TILE, 5):
        offset = rng.randint(0, 8)
        for x in range(TILE):
            if (x + offset) % 12 < 2:
                img.putpixel((ox + x, oy + row), _vary(ROOF_BROWN_DARK, 6))
    # Highlights
    for _ in range(rng.randint(2, 4)):
        hx = rng.randint(2, TILE - 3)
        hy = rng.randint(2, TILE - 3)
        img.putpixel((ox + hx, oy + hy), _vary(ROOF_BROWN_LIGHT, 10))


def draw_roof_green(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw a moss-green shingle roof tile."""
    rng = random.Random(variant * 1000 + ox * 100 + oy)
    for y in range(TILE):
        for x in range(TILE):
            noise = rng.randint(-6, 6)
            c = _rgba(ROOF_GREEN_BASE[0] + noise, ROOF_GREEN_BASE[1] + noise - 1, ROOF_GREEN_BASE[2] + noise - 1)
            img.putpixel((ox + x, oy + y), c)
    for row in range(0, TILE, 6):
        offset = (row // 6 % 2) * 8
        for x in range(TILE):
            img.putpixel((ox + x, oy + row), _vary(ROOF_GREEN_DARK, 5))
        for col in range(offset, TILE, 16):
            if 0 <= col < TILE:
                for dy in range(min(6, TILE - row)):
                    img.putpixel((ox + col, oy + row + dy), _vary(ROOF_GREEN_DARK, 8))
    for _ in range(rng.randint(2, 5)):
        hx = rng.randint(2, TILE - 3)
        hy = rng.randint(2, TILE - 3)
        img.putpixel((ox + hx, oy + hy), _vary(ROOF_GREEN_LIGHT, 10))


def draw_stone_bridge(img: Image.Image, ox: int, oy: int):
    """Draw a grey stone arch bridge over water."""
    # Water base
    draw_water_tile(img, ox, oy, variant=7)
    # Stone arch silhouette at bottom
    arch_height = 10
    for y in range(TILE - arch_height, TILE):
        for x in range(TILE):
            # Create arch curve
            arch_depth = int(((y - (TILE - arch_height)) / arch_height) ** 2 * 8)
            if arch_depth <= x < TILE - arch_depth:
                noise = random.randint(-5, 5)
                c = _rgba(STONE_GREY_BASE[0] + noise, STONE_GREY_BASE[1] + noise, STONE_GREY_BASE[2] + noise)
                img.putpixel((ox + x, oy + y), c)
    # Bridge walkway
    walk_top = 10
    walk_bot = 22
    for y in range(walk_top, walk_bot):
        for x in range(TILE):
            noise = random.randint(-4, 4)
            c = _rgba(STONE_BASE[0] + noise, STONE_BASE[1] + noise, STONE_BASE[2] + noise)
            img.putpixel((ox + x, oy + y), c)
    # Stone railings
    for x in range(TILE):
        img.putpixel((ox + x, oy + walk_top), STONE_GREY_DARK)
        img.putpixel((ox + x, oy + walk_bot - 1), STONE_GREY_DARK)


def draw_grass_water_edge(img: Image.Image, ox: int, oy: int, edge: str):
    """Draw grass tile with water edge and foam transition."""
    rng = random.Random(hash(edge) + ox * 100 + oy)
    # Determine which side is land vs water
    land_side = []
    water_side = []
    if "T" in edge:
        land_side.append("T")
    else:
        water_side.append("T")
    if "B" in edge:
        land_side.append("B")
    else:
        water_side.append("B")
    if "L" in edge:
        land_side.append("L")
    else:
        water_side.append("L")
    if "R" in edge:
        land_side.append("R")
    else:
        water_side.append("R")
    # Fill base based on majority
    if len(land_side) >= len(water_side):
        draw_grass_tile(img, ox, oy, variant=hash(edge) % 50)
    else:
        draw_water_tile(img, ox, oy, variant=hash(edge) % 7)
    # Draw shoreline foam
    shore_width = 6
    for y in range(TILE):
        for x in range(TILE):
            is_shore = False
            if "T" in edge and y < shore_width:
                is_shore = True
            if "B" in edge and y >= TILE - shore_width:
                is_shore = True
            if "L" in edge and x < shore_width:
                is_shore = True
            if "R" in edge and x >= TILE - shore_width:
                is_shore = True
            if is_shore:
                current = img.getpixel((ox + x, oy + y))
                foam_blend = _blend(current, WATER_EDGE_FOAM, 0.5)
                img.putpixel((ox + x, oy + y), foam_blend)
                # Add foam speckles
                if rng.random() > 0.7:
                    img.putpixel((ox + x, oy + y), _vary(WATER_FOAM, 15))


def draw_tower_roof(img: Image.Image, ox: int, oy: int, color_variant: str = "grey"):
    """Draw a conical tower roof tile."""
    rng = random.Random(ox * 100 + oy)
    # Select color palette
    if color_variant == "red":
        base_c, dark_c, light_c = ROOF_RED_BASE, ROOF_RED_DARK, ROOF_RED_LIGHT
    elif color_variant == "brown":
        base_c, dark_c, light_c = ROOF_BROWN_BASE, ROOF_BROWN_DARK, ROOF_BROWN_LIGHT
    else:  # grey default
        base_c, dark_c, light_c = ROOF_GREY_BASE, ROOF_GREY_DARK, ROOF_GREY_LIGHT
    # Draw conical roof shape (triangle with rounded top)
    cx = TILE // 2
    for y in range(TILE):
        for x in range(TILE):
            # Cone shape: wider at bottom, narrower at top
            progress = y / TILE  # 0 at top, 1 at bottom
            width_at_y = int(4 + progress * (TILE - 8))  # 4px at top, nearly full at bottom
            left = cx - width_at_y // 2
            right = cx + width_at_y // 2
            if left <= x <= right:
                noise = rng.randint(-5, 5)
                c = _rgba(base_c[0] + noise, base_c[1] + noise - 2, base_c[2] + noise - 2)
                img.putpixel((ox + x, oy + y), c)
            elif x == left - 1 or x == right + 1:
                img.putpixel((ox + x, oy + y), dark_c)
    # Roof tile lines following slope
    for row in range(0, TILE, 4):
        offset = (row // 4 % 2) * 4
        for x in range(offset, TILE, 8):
            progress = row / TILE
            width_at_y = int(4 + progress * (TILE - 8))
            left = cx - width_at_y // 2
            right = cx + width_at_y // 2
            if left <= x <= right:
                img.putpixel((ox + x, oy + row), _vary(dark_c, 5))


def draw_tower_battlement(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw tower battlements on grey stone."""
    draw_stone_grey_wall(img, ox, oy, variant=variant)
    crenel_w = 4
    for x in range(0, TILE, crenel_w * 2):
        for y in range(0, 6):
            for dx in range(crenel_w):
                if x + dx < TILE:
                    img.putpixel((ox + x + dx, oy + y), _vary(STONE_GREY_DARK, 4))


def draw_tower_window_arch(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw arched tower window on stone wall."""
    draw_stone_grey_wall(img, ox, oy, variant=variant)
    cx = TILE // 2
    top = 8
    height = 14
    width = 8
    for y in range(height):
        for x in range(-width // 2, width // 2 + 1):
            px = cx + x
            py = top + y
            if 0 <= px < TILE and 0 <= py < TILE:
                if y < 4:
                    if abs(x) <= (4 - y):
                        img.putpixel((ox + px, oy + py), WINDOW_BASE)
                else:
                    img.putpixel((ox + px, oy + py), WINDOW_BASE)
    for y in range(height):
        for x in range(-width // 2 - 1, width // 2 + 2):
            px = cx + x
            py = top + y
            if 0 <= px < TILE and 0 <= py < TILE and abs(x) == width // 2 + 1:
                img.putpixel((ox + px, oy + py), WINDOW_FRAME)


def draw_blacksmith_forge(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw blacksmith forge oven front."""
    draw_stone_grey_wall(img, ox, oy, variant=variant)
    forge_w = 16
    forge_h = 12
    fx = TILE // 2 - forge_w // 2
    fy = TILE - forge_h - 4
    for y in range(forge_h):
        for x in range(forge_w):
            c = _vary(STONE_DARK, 6)
            img.putpixel((ox + fx + x, oy + fy + y), c)
    mouth_w = 10
    mouth_h = 6
    mx = TILE // 2 - mouth_w // 2
    my = fy + 3
    for y in range(mouth_h):
        for x in range(mouth_w):
            heat = _blend(_hex("#ff8a30"), _hex("#c02a10"), y / max(1, mouth_h - 1))
            img.putpixel((ox + mx + x, oy + my + y), _vary(heat, 10))


def draw_blacksmith_anvil(img: Image.Image, ox: int, oy: int):
    """Draw a compact anvil prop on stone floor."""
    draw_stone_tile(img, ox, oy, variant=90)
    base_y = TILE - 10
    for x in range(10, 22):
        for y in range(base_y, base_y + 3):
            img.putpixel((ox + x, oy + y), _vary(STONE_DARK, 5))
    horn_pts = [(12, base_y), (18, base_y - 4), (23, base_y)]
    for i in range(len(horn_pts) - 1):
        x0, y0 = horn_pts[i]
        x1, y1 = horn_pts[i + 1]
        for t in range(12):
            px = int(x0 + (x1 - x0) * t / 11)
            py = int(y0 + (y1 - y0) * t / 11)
            img.putpixel((ox + px, oy + py), _vary(STONE_LIGHT, 4))


def draw_storefront_awning(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw storefront wall with striped awning."""
    draw_building_wall(img, ox, oy, variant=200 + variant)
    top = 8
    for y in range(top, top + 6):
        for x in range(3, TILE - 3):
            stripe = (x // 3) % 2
            color = _hex("#d84a3a") if stripe == 0 else _hex("#f4d8b0")
            img.putpixel((ox + x, oy + y), _vary(color, 8))


def draw_storefront_window(img: Image.Image, ox: int, oy: int, variant: int = 0):
    """Draw large storefront display window."""
    draw_building_wall(img, ox, oy, variant=210 + variant)
    wx = 5
    wy = 9
    ww = 22
    wh = 13
    for y in range(wh):
        for x in range(ww):
            c = WINDOW_LIGHT if (x + y) % 4 == 0 else WINDOW_BASE
            img.putpixel((ox + wx + x, oy + wy + y), _vary(c, 6))
    for x in range(ww):
        img.putpixel((ox + wx + x, oy + wy - 1), WINDOW_FRAME)
        img.putpixel((ox + wx + x, oy + wy + wh), WINDOW_FRAME)
    for y in range(wh):
        img.putpixel((ox + wx - 1, oy + wy + y), WINDOW_FRAME)
        img.putpixel((ox + wx + ww, oy + wy + y), WINDOW_FRAME)


def draw_hanging_shop_sign(img: Image.Image, ox: int, oy: int):
    """Draw wall-mounted hanging shop sign."""
    draw_building_wall(img, ox, oy, variant=220)
    arm_y = 10
    for x in range(12, 22):
        img.putpixel((ox + x, oy + arm_y), WOOD_DARK)
    sx = 18
    sy = 12
    for y in range(10):
        for x in range(8):
            img.putpixel((ox + sx + x, oy + sy + y), _vary(SIGN_BASE, 6))
    for x in range(8):
        img.putpixel((ox + sx + x, oy + sy), WOOD_DARK)


def draw_road_curb(img: Image.Image, ox: int, oy: int, edge: str = "center"):
    """Draw road/curb stone tile with edge/corner variants."""
    draw_stone_tile(img, ox, oy, variant=300 + hash(edge) % 100)
    curb_color = _hex("#c8c8c8")
    width = 4
    for y in range(TILE):
        for x in range(TILE):
            mark = False
            if edge in ("top", "t") and y < width:
                mark = True
            elif edge in ("bottom", "b") and y >= TILE - width:
                mark = True
            elif edge in ("left", "l") and x < width:
                mark = True
            elif edge in ("right", "r") and x >= TILE - width:
                mark = True
            elif edge == "corner_tl" and (x < width or y < width):
                mark = True
            elif edge == "corner_tr" and (x >= TILE - width or y < width):
                mark = True
            elif edge == "corner_bl" and (x < width or y >= TILE - width):
                mark = True
            elif edge == "corner_br" and (x >= TILE - width or y >= TILE - width):
                mark = True
            elif edge == "center" and (x in (0, TILE - 1) or y in (0, TILE - 1)):
                mark = True
            if mark:
                img.putpixel((ox + x, oy + y), _vary(curb_color, 6))


def draw_tower_balcony(img: Image.Image, ox: int, oy: int, variant: str = "center"):
    """Draw a wooden watchtower balcony/walkway over stone base."""
    draw_stone_grey_wall(img, ox, oy, variant=400 + hash(variant) % 50)

    top = 11
    bottom = 21
    left = 4
    right = TILE - 5

    if variant == "left":
        left = 1
    elif variant == "right":
        right = TILE - 2
    elif variant == "corner":
        left = 1
        top = 8

    for y in range(top, bottom):
        for x in range(left, right):
            c = WOOD_LIGHT if (x // 3) % 2 == 0 else WOOD_BASE
            img.putpixel((ox + x, oy + y), _vary(c, 5))

    for x in range(left, right):
        img.putpixel((ox + x, oy + top), _vary(WOOD_DARK, 4))
        img.putpixel((ox + x, oy + bottom - 1), _vary(WOOD_DARK, 4))

    rail_y = top - 3
    if rail_y >= 0:
        for x in range(left, right):
            img.putpixel((ox + x, oy + rail_y), _vary(WOOD_DARK, 4))
        for post_x in range(left + 1, right, 5):
            for y in range(rail_y + 1, top):
                img.putpixel((ox + post_x, oy + y), _vary(WOOD_DARK, 4))


# ── Atlas Layout ────────────────────────────────────────────────────────

def generate_atlas(output_path: str) -> None:
    """Generate the complete tile atlas PNG."""
    random.seed(42)  # Deterministic output
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))

    # Row 0-2: Grass autotile (3x3) + variants
    # Col 0-2, Row 0-2: Grass with dirt edges
    edges_3x3 = ["TL", "T", "TR", "L", "", "R", "BL", "B", "BR"]
    for row in range(3):
        for col in range(3):
            edge = edges_3x3[row * 3 + col]
            ox = col * TILE
            oy = row * TILE
            if edge:
                draw_grass_edge(img, ox, oy, edge, DIRT_BASE)
            else:
                draw_grass_tile(img, ox, oy, variant=0)

    # Col 3-5: Pure grass variants
    for i in range(3):
        for j in range(3):
            draw_grass_tile(img, (3 + i) * TILE, j * TILE, variant=i * 3 + j + 10)

    # Col 6-8: Grass with flowers
    for i in range(3):
        for j in range(3):
            draw_flower_patch(img, (6 + i) * TILE, j * TILE, variant=i * 3 + j)

    # Col 9-11: Grass with stone edges
    for row in range(3):
        for col in range(3):
            edge = edges_3x3[row * 3 + col]
            ox = (9 + col) * TILE
            oy = row * TILE
            if edge:
                draw_grass_edge(img, ox, oy, edge, STONE_BASE)
            else:
                draw_grass_tile(img, ox, oy, variant=20)

    # Col 12-15: More grass variants (plain)
    for i in range(4):
        for j in range(3):
            draw_grass_tile(img, (12 + i) * TILE, j * TILE, variant=30 + i * 3 + j)

    # Row 3-5: Dirt/path autotile + variants
    for row in range(3):
        for col in range(3):
            edge = edges_3x3[row * 3 + col]
            ox = col * TILE
            oy = (3 + row) * TILE
            if edge:
                draw_dirt_edge(img, ox, oy, edge, GRASS_BASE)
            else:
                draw_dirt_tile(img, ox, oy, variant=0)

    for i in range(3):
        for j in range(3):
            draw_dirt_tile(img, (3 + i) * TILE, (3 + j) * TILE, variant=i * 3 + j + 10)

    # Dirt with stone edges
    for row in range(3):
        for col in range(3):
            edge = edges_3x3[row * 3 + col]
            ox = (6 + col) * TILE
            oy = (3 + row) * TILE
            if edge:
                draw_dirt_edge(img, ox, oy, edge, STONE_BASE)
            else:
                draw_dirt_tile(img, ox, oy, variant=20)

    # More dirt variants
    for i in range(7):
        for j in range(3):
            draw_dirt_tile(img, (9 + i) * TILE, (3 + j) * TILE, variant=30 + i * 3 + j)

    # Row 6-8: Stone/cobble autotile + variants
    for row in range(3):
        for col in range(3):
            ox = col * TILE
            oy = (6 + row) * TILE
            draw_stone_tile(img, ox, oy, variant=row * 3 + col)

    for i in range(13):
        for j in range(3):
            draw_stone_tile(img, (3 + i) * TILE, (6 + j) * TILE, variant=10 + i * 3 + j)

    # Row 9: Water tiles
    draw_water_tile(img, 0, 9 * TILE, variant=0)
    draw_water_tile(img, TILE, 9 * TILE, variant=1)
    draw_water_tile(img, 2 * TILE, 9 * TILE, variant=2)
    draw_water_shore(img, 3 * TILE, 9 * TILE, "T")
    draw_water_shore(img, 4 * TILE, 9 * TILE, "B")
    draw_water_shore(img, 5 * TILE, 9 * TILE, "L")
    draw_water_shore(img, 6 * TILE, 9 * TILE, "R")
    draw_water_shore(img, 7 * TILE, 9 * TILE, "TL")
    draw_water_shore(img, 8 * TILE, 9 * TILE, "TR")
    draw_water_shore(img, 9 * TILE, 9 * TILE, "BL")
    draw_water_shore(img, 10 * TILE, 9 * TILE, "BR")
    draw_water_tile(img, 11 * TILE, 9 * TILE, variant=3)
    draw_water_tile(img, 12 * TILE, 9 * TILE, variant=4)
    draw_bridge_h(img, 13 * TILE, 9 * TILE)
    draw_water_tile(img, 14 * TILE, 9 * TILE, variant=5)
    draw_water_tile(img, 15 * TILE, 9 * TILE, variant=6)

    # Row 10: Trees and vegetation
    draw_tree_canopy(img, 0, 10 * TILE, variant=0)
    draw_tree_canopy(img, TILE, 10 * TILE, variant=1)
    draw_tree_canopy(img, 2 * TILE, 10 * TILE, variant=2)
    draw_tree_trunk(img, 3 * TILE, 10 * TILE)
    draw_tree_trunk(img, 4 * TILE, 10 * TILE)
    draw_flower_patch(img, 5 * TILE, 10 * TILE, variant=10)
    draw_flower_patch(img, 6 * TILE, 10 * TILE, variant=11)
    draw_flower_patch(img, 7 * TILE, 10 * TILE, variant=12)
    # Hedges (dark green blocks)
    for i in range(3):
        ox = (8 + i) * TILE
        oy = 10 * TILE
        draw_grass_tile(img, ox, oy, variant=70 + i)
        for y in range(4, TILE - 4):
            for x in range(2, TILE - 2):
                c = _vary(TREE_CANOPY_DARK, 8)
                img.putpixel((ox + x, oy + y), c)
    # Fill rest with empty
    for i in range(11, COLS):
        draw_grass_tile(img, i * TILE, 10 * TILE, variant=80 + i)

    # Row 11: Building walls (tan, grey stone, brown stone, timber)
    for i in range(3):
        draw_building_wall(img, i * TILE, 11 * TILE, variant=i)
    # Grey stone walls (3 tiles)
    for i in range(3):
        draw_stone_grey_wall(img, (3 + i) * TILE, 11 * TILE, variant=i)
    # Brown stone walls (3 tiles)
    for i in range(3):
        draw_stone_brown_wall(img, (6 + i) * TILE, 11 * TILE, variant=i)
    # Wood planks (3 tiles)
    for i in range(3):
        ox = (9 + i) * TILE
        oy = 11 * TILE
        for y in range(TILE):
            for x in range(TILE):
                plank_idx = x // 8
                base = WOOD_BASE if plank_idx % 2 == 0 else WOOD_LIGHT
                img.putpixel((ox + x, oy + y), _vary(base, 5))
            # Plank seams
            for seam_x in range(0, TILE, 8):
                if 0 <= seam_x < TILE:
                    img.putpixel((ox + seam_x, oy + y), _vary(WOOD_DARK, 3))
    # More wall variants
    for i in range(13, COLS):
        draw_building_wall(img, i * TILE, 11 * TILE, variant=10 + i)

    # Row 12: Building roofs (red, grey, brown, wood) + doors, windows, signs
    # Original doors/windows (columns 0-3)
    draw_door(img, 0, 12 * TILE)
    draw_door(img, TILE, 12 * TILE)
    draw_window(img, 2 * TILE, 12 * TILE)
    draw_window(img, 3 * TILE, 12 * TILE)
    # Red roofs (3 tiles)
    for i in range(3):
        draw_roof_red(img, (4 + i) * TILE, 12 * TILE, variant=i)
    # Grey roofs (3 tiles)
    for i in range(3):
        draw_roof_grey(img, (7 + i) * TILE, 12 * TILE, variant=i)
    # Brown roofs (3 tiles)
    for i in range(3):
        draw_roof_brown(img, (10 + i) * TILE, 12 * TILE, variant=i)
    # Signs and lamps
    draw_sign(img, 13 * TILE, 12 * TILE)
    draw_sign(img, 14 * TILE, 12 * TILE)
    draw_lamp(img, 15 * TILE, 12 * TILE)

    # Row 13: Building details - chimneys, more doors/windows on stone walls
    # Chimneys on grey stone (3 tiles)
    for i in range(3):
        ox = i * TILE
        oy = 13 * TILE
        draw_stone_grey_wall(img, ox, oy, variant=100 + i)
        # Add chimney
        chim_x = TILE // 2 - 2
        for cy in range(6, 18):
            for dx in range(4):
                img.putpixel((ox + chim_x + dx, oy + cy), _vary(CHIMNEY_BASE, 5))
        # Chimney top
        for cy in range(4, 6):
            for dx in range(-1, 5):
                img.putpixel((ox + chim_x + dx, oy + cy), _vary(CHIMNEY_DARK, 3))
    # Doors on stone walls (2 tiles)
    for i in range(2):
        ox = (3 + i) * TILE
        oy = 13 * TILE
        draw_stone_grey_wall(img, ox, oy, variant=110 + i)
    # Draw doors on top
    door_w = 12
    door_h = 20
    dx_start = TILE // 2 - door_w // 2
    dy_start = TILE - door_h - 2
    for dy in range(door_h):
        for dx in range(door_w):
            noise_val = random.randint(-4, 4)
            c = _rgba(DOOR_BASE[0] + noise_val, DOOR_BASE[1] + noise_val, DOOR_BASE[2] + noise_val)
            for i in range(2):
                img.putpixel(((3 + i) * TILE + dx_start + dx, 13 * TILE + dy_start + dy), c)
    # Windows on stone walls (2 tiles)
    for i in range(2):
        ox = (5 + i) * TILE
        oy = 13 * TILE
        draw_stone_grey_wall(img, ox, oy, variant=120 + i)
    # Draw windows
    win_w = 12
    win_h = 10
    for i in range(2):
        wx = (5 + i) * TILE + TILE // 2 - win_w // 2
        wy = 13 * TILE + TILE // 2 - win_h // 2
        for wy_local in range(win_h):
            for wx_local in range(win_w):
                wc = WINDOW_LIGHT if (wx_local + wy_local) % 3 == 0 else WINDOW_BASE
                img.putpixel((wx + wx_local, wy + wy_local), _vary(wc, 5))
        # Window frame
        for fx in range(win_w):
            img.putpixel((wx + fx, wy - 1), WINDOW_FRAME)
            img.putpixel((wx + fx, wy + win_h), WINDOW_FRAME)
        for fy in range(win_h):
            img.putpixel((wx - 1, wy + fy), WINDOW_FRAME)
            img.putpixel((wx + win_w, wy + fy), WINDOW_FRAME)
    # Fill rest with stone
    for i in range(7, COLS):
        draw_stone_grey_wall(img, i * TILE, 13 * TILE, variant=130 + i)

    # Row 14: Fences, bridges (wood + stone), stairs
    draw_fence_h(img, 0, 14 * TILE)
    draw_fence_h(img, TILE, 14 * TILE)
    draw_fence_v(img, 2 * TILE, 14 * TILE)
    draw_fence_v(img, 3 * TILE, 14 * TILE)
    draw_bridge_h(img, 4 * TILE, 14 * TILE)
    draw_stone_bridge(img, 5 * TILE, 14 * TILE)  # NEW: Stone arch bridge
    draw_stairs(img, 6 * TILE, 14 * TILE, going_up=True)
    draw_stairs(img, 7 * TILE, 14 * TILE, going_up=False)
    for i in range(8, COLS):
        draw_stone_tile(img, i * TILE, 14 * TILE, variant=50 + i)

    # Row 15: Special markers and indicators
    draw_marker(img, 0, 15 * TILE, (255, 215, 0), "treasure")      # Gold sparkle
    draw_marker(img, TILE, 15 * TILE, (100, 180, 255), "merchant")  # Blue glow
    draw_marker(img, 2 * TILE, 15 * TILE, (255, 100, 100), "danger")  # Red
    draw_marker(img, 3 * TILE, 15 * TILE, (100, 255, 150), "interact")  # Green
    draw_empty(img, 4 * TILE, 15 * TILE)
    for i in range(5, COLS):
        draw_empty(img, i * TILE, 15 * TILE)

    # Row 16: Tower components (walls, roofs, windows)
    # Grey stone tower walls (4 tiles)
    for i in range(4):
        draw_stone_grey_wall(img, i * TILE, 16 * TILE, variant=200 + i)
    # Tower roofs - grey, red, brown variants (3 tiles)
    draw_tower_roof(img, 4 * TILE, 16 * TILE, "grey")
    draw_tower_roof(img, 5 * TILE, 16 * TILE, "red")
    draw_tower_roof(img, 6 * TILE, 16 * TILE, "brown")
    # Tower windows on stone (2 tiles)
    for i in range(2):
        ox = (7 + i) * TILE
        oy = 16 * TILE
        draw_stone_grey_wall(img, ox, oy, variant=210 + i)
        # Narrow tower window
        tw = 6
        th = 10
        tx = ox + TILE // 2 - tw // 2
        ty = oy + TILE // 2 - th // 2
        for wy in range(th):
            for wx in range(tw):
                tc = WINDOW_LIGHT if (wx + wy) % 2 == 0 else WINDOW_BASE
                img.putpixel((tx + wx, ty + wy), _vary(tc, 5))
        # Frame
        for fx in range(tw):
            img.putpixel((tx + fx, ty - 1), WINDOW_FRAME)
            img.putpixel((tx + fx, ty + th), WINDOW_FRAME)
        for fy in range(th):
            img.putpixel((tx - 1, ty + fy), WINDOW_FRAME)
            img.putpixel((tx + tw, ty + fy), WINDOW_FRAME)
    # Fill rest with grey stone
    for i in range(9, COLS):
        draw_stone_grey_wall(img, i * TILE, 16 * TILE, variant=220 + i)

    # Row 17: Roof edge pieces (corners and slopes)
    # Red roof edges (4 tiles: top, bottom, left, right edges)
    draw_roof_red(img, 0, 17 * TILE, variant=10)
    draw_roof_red(img, TILE, 17 * TILE, variant=11)
    draw_roof_red(img, 2 * TILE, 17 * TILE, variant=12)
    # Grey roof edges (4 tiles)
    draw_roof_grey(img, 4 * TILE, 17 * TILE, variant=10)
    draw_roof_grey(img, 5 * TILE, 17 * TILE, variant=11)
    draw_roof_grey(img, 6 * TILE, 17 * TILE, variant=12)
    # Brown roof edges (4 tiles)
    draw_roof_brown(img, 8 * TILE, 17 * TILE, variant=10)
    draw_roof_brown(img, 9 * TILE, 17 * TILE, variant=11)
    draw_roof_brown(img, 10 * TILE, 17 * TILE, variant=12)
    # Green roof variants (3 tiles)
    draw_roof_green(img, 11 * TILE, 17 * TILE, variant=0)
    draw_roof_green(img, 12 * TILE, 17 * TILE, variant=1)
    draw_roof_green(img, 13 * TILE, 17 * TILE, variant=2)
    # Fill rest
    for i in range(14, COLS):
        draw_empty(img, i * TILE, 17 * TILE)

    # Row 18: Water transitions (grass-water edges in 8 directions)
    edges_water = ["T", "B", "L", "R", "TL", "TR", "BL", "BR"]
    for i, edge in enumerate(edges_water):
        draw_grass_water_edge(img, i * TILE, 18 * TILE, edge)
    # More water variants
    for i in range(8, COLS):
        draw_water_tile(img, i * TILE, 18 * TILE, variant=i)

    # Row 19: Decorative elements (gates, arches, wells)
    # Stone arch gateway (2 tiles wide)
    for i in range(2):
        ox = i * TILE
        oy = 19 * TILE
        draw_stone_grey_wall(img, ox, oy, variant=300 + i)
    # Arch cutout at top
    for i in range(2):
        ox = i * TILE
        oy = 19 * TILE
        for y in range(8):
            for x in range(8, 24):
                img.putpixel((ox + x, oy + y), (0, 0, 0, 0))  # Transparent arch
    # Well on stone
    draw_stone_grey_wall(img, 2 * TILE, 19 * TILE, variant=302)
    # Simple well circle
    wc = 2 * TILE + TILE // 2
    wy = 19 * TILE + TILE // 2
    for y in range(TILE):
        for x in range(TILE):
            dx = x - TILE // 2
            dy = y - TILE // 2
            if 8 < (dx*dx + dy*dy)**0.5 < 12:
                img.putpixel((2 * TILE + x, 19 * TILE + y), _vary(STONE_GREY_DARK, 5))
    # Fill rest
    for i in range(3, COLS):
        draw_stone_grey_wall(img, i * TILE, 19 * TILE, variant=310 + i)

    # Row 20: Extended vegetation (pine trees, bush variants)
    # Pine tree (darker, triangular)
    draw_grass_tile(img, 0, 20 * TILE, variant=150)
    pc = TILE // 2
    for y in range(TILE):
        for x in range(TILE):
            dx = x - pc
            dy = y - pc
            # Triangle shape for pine
            if dy > 0 and abs(dx) < (TILE - dy) / 2:
                c = _vary(TREE_CANOPY_DARK, 8)
                img.putpixel((x, 20 * TILE + y), c)
    # Pine trunk
    for y in range(TILE):
        for x in range(3):
            img.putpixel((pc - 1 + x, 20 * TILE + y), TREE_TRUNK_DARK)
    # Bush variants (3 tiles)
    for i in range(3):
        draw_grass_tile(img, (1 + i) * TILE, 20 * TILE, variant=160 + i)
        # Round bush
        bc = (1 + i) * TILE + TILE // 2
        by = 20 * TILE + TILE // 2
        for y in range(TILE):
            for x in range(TILE):
                dx = x - TILE // 2
                dy = y - TILE // 2
                if (dx*dx + dy*dy)**0.5 < 10:
                    c = _vary(TREE_CANOPY, 10) if i % 2 == 0 else _vary(TREE_CANOPY_LIGHT, 10)
                    img.putpixel((bc + x - TILE//2, by + y - TILE//2), c)
    # Fill rest with grass
    for i in range(4, COLS):
        draw_grass_tile(img, i * TILE, 20 * TILE, variant=170 + i)

    # Row 21: Tower kit (high-impact)
    draw_tower_battlement(img, 0 * TILE, 21 * TILE, variant=0)
    draw_tower_battlement(img, 1 * TILE, 21 * TILE, variant=1)
    draw_tower_window_arch(img, 2 * TILE, 21 * TILE, variant=0)
    draw_tower_window_arch(img, 3 * TILE, 21 * TILE, variant=1)
    draw_tower_roof(img, 4 * TILE, 21 * TILE, "grey")
    draw_tower_roof(img, 5 * TILE, 21 * TILE, "red")
    draw_tower_roof(img, 6 * TILE, 21 * TILE, "brown")
    # Tower door on stone
    draw_stone_grey_wall(img, 7 * TILE, 21 * TILE, variant=20)
    door_w = 12
    door_h = 20
    dx_start = TILE // 2 - door_w // 2
    dy_start = TILE - door_h - 2
    for dy in range(door_h):
        for dx in range(door_w):
            noise_val = random.randint(-4, 4)
            c = _rgba(DOOR_BASE[0] + noise_val, DOOR_BASE[1] + noise_val, DOOR_BASE[2] + noise_val)
            img.putpixel((7 * TILE + dx_start + dx, 21 * TILE + dy_start + dy), c)
    draw_tower_balcony(img, 8 * TILE, 21 * TILE, "center")
    draw_tower_balcony(img, 9 * TILE, 21 * TILE, "left")
    draw_tower_balcony(img, 10 * TILE, 21 * TILE, "right")
    draw_tower_balcony(img, 11 * TILE, 21 * TILE, "corner")
    for i in range(12, COLS):
        draw_stone_grey_wall(img, i * TILE, 21 * TILE, variant=240 + i)

    # Row 22: Blacksmith (0-7) + Storefront (8-15) kits
    # Blacksmith kit
    draw_blacksmith_forge(img, 0 * TILE, 22 * TILE, variant=0)
    draw_blacksmith_forge(img, 1 * TILE, 22 * TILE, variant=1)
    draw_blacksmith_anvil(img, 2 * TILE, 22 * TILE)
    draw_blacksmith_anvil(img, 3 * TILE, 22 * TILE)
    draw_stone_grey_wall(img, 4 * TILE, 22 * TILE, variant=300)
    # Chimney stack
    for y in range(5, 20):
        for x in range(12, 20):
            img.putpixel((4 * TILE + x, 22 * TILE + y), _vary(CHIMNEY_BASE, 5))
    draw_sign(img, 5 * TILE, 22 * TILE)
    draw_stone_grey_wall(img, 6 * TILE, 22 * TILE, variant=301)
    draw_stone_grey_wall(img, 7 * TILE, 22 * TILE, variant=302)

    # Storefront kit
    draw_storefront_awning(img, 8 * TILE, 22 * TILE, variant=0)
    draw_storefront_awning(img, 9 * TILE, 22 * TILE, variant=1)
    draw_storefront_window(img, 10 * TILE, 22 * TILE, variant=0)
    draw_storefront_window(img, 11 * TILE, 22 * TILE, variant=1)
    draw_hanging_shop_sign(img, 12 * TILE, 22 * TILE)
    draw_hanging_shop_sign(img, 13 * TILE, 22 * TILE)
    draw_building_wall(img, 14 * TILE, 22 * TILE, variant=220)
    draw_building_wall(img, 15 * TILE, 22 * TILE, variant=221)

    # Row 23: Road/curb kit (0-7) + reusable props (8-15)
    draw_road_curb(img, 0 * TILE, 23 * TILE, "top")
    draw_road_curb(img, 1 * TILE, 23 * TILE, "bottom")
    draw_road_curb(img, 2 * TILE, 23 * TILE, "left")
    draw_road_curb(img, 3 * TILE, 23 * TILE, "right")
    draw_road_curb(img, 4 * TILE, 23 * TILE, "corner_tl")
    draw_road_curb(img, 5 * TILE, 23 * TILE, "corner_tr")
    draw_road_curb(img, 6 * TILE, 23 * TILE, "corner_bl")
    draw_road_curb(img, 7 * TILE, 23 * TILE, "corner_br")

    # Keep key props available for map generation compatibility
    draw_chest(img, 8 * TILE, 23 * TILE, opened=False)
    draw_chest(img, 9 * TILE, 23 * TILE, opened=True)
    draw_barrel(img, 10 * TILE, 23 * TILE)
    draw_barrel(img, 11 * TILE, 23 * TILE)
    draw_crate(img, 12 * TILE, 23 * TILE)
    draw_crate(img, 13 * TILE, 23 * TILE)
    draw_sign(img, 14 * TILE, 23 * TILE)
    draw_lamp(img, 15 * TILE, 23 * TILE)

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    img.save(output_path)
    print(f"Saved {output_path} ({WIDTH}x{HEIGHT}, {COLS}x{ROWS} grid, {TILE}px tiles)")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Detailed pixel-art tile atlas generator for Godot TileMap")
    default_out = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..", "..", "..", "godot", "assets", "tiles", "world_atlas.png"
    )
    p.add_argument("-o", "--output", default=default_out, help="Output PNG path")
    args = p.parse_args()
    output = os.path.normpath(args.output)
    generate_atlas(output)
