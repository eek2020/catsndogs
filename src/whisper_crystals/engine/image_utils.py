"""Pygame image loading and transformation utilities.

Centralises all raw pygame.image usage so UI code stays engine-agnostic.
"""

from __future__ import annotations

import os

import pygame


def load_image(path: str) -> pygame.Surface | None:
    """Load an opaque image surface if the file exists."""
    if not os.path.exists(path):
        return None
    try:
        return pygame.image.load(path).convert()
    except pygame.error:
        return None


def load_image_alpha(path: str) -> pygame.Surface | None:
    """Load an RGBA image surface if the file exists."""
    if not os.path.exists(path):
        return None
    try:
        return pygame.image.load(path).convert_alpha()
    except pygame.error:
        return None


def remove_near_white_bg(
    surface: pygame.Surface,
    hard_threshold: int = 232,
    soft_threshold: int = 196,
) -> pygame.Surface:
    """Make bright neutral background pixels transparent, with soft feathering."""
    cleaned = surface.copy().convert_alpha()
    width, height = cleaned.get_size()
    for x in range(width):
        for y in range(height):
            r, g, b, a = cleaned.get_at((x, y))
            whiteness = min(r, g, b)
            if whiteness >= hard_threshold:
                cleaned.set_at((x, y), (r, g, b, 0))
            elif whiteness >= soft_threshold:
                span = max(1, hard_threshold - soft_threshold)
                alpha_scale = (hard_threshold - whiteness) / span
                cleaned.set_at((x, y), (r, g, b, int(a * alpha_scale)))
            else:
                cleaned.set_at((x, y), (r, g, b, a))
    return cleaned


def remove_background_by_corners(
    surface: pygame.Surface,
    tolerance: int = 34,
) -> pygame.Surface:
    """Remove flat backdrop colour sampled from corner pixels."""
    image_alpha = surface.convert_alpha()
    width, height = image_alpha.get_size()
    corners = [
        image_alpha.get_at((0, 0)),
        image_alpha.get_at((width - 1, 0)),
        image_alpha.get_at((0, height - 1)),
        image_alpha.get_at((width - 1, height - 1)),
    ]
    if any(c.a < 250 for c in corners):
        return image_alpha

    # Pick the corner that best matches the others (robust to one noisy corner).
    rgb = [(c.r, c.g, c.b) for c in corners]

    def _distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
        return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])

    scores = [sum(_distance(candidate, other) for other in rgb) for candidate in rgb]
    bg_r, bg_g, bg_b = rgb[scores.index(min(scores))]

    feather = 12

    for y in range(height):
        for x in range(width):
            px = image_alpha.get_at((x, y))
            delta = max(abs(px.r - bg_r), abs(px.g - bg_g), abs(px.b - bg_b))
            if delta <= tolerance:
                image_alpha.set_at((x, y), (px.r, px.g, px.b, 0))
            elif delta <= tolerance + feather:
                alpha_scale = (delta - tolerance) / feather
                image_alpha.set_at((x, y), (px.r, px.g, px.b, int(px.a * alpha_scale)))

    return image_alpha
