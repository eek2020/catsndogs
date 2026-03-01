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
    tolerance: int = 26,
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

    bg_r = sum(c.r for c in corners) // 4
    bg_g = sum(c.g for c in corners) // 4
    bg_b = sum(c.b for c in corners) // 4

    for y in range(height):
        for x in range(width):
            px = image_alpha.get_at((x, y))
            if (
                abs(px.r - bg_r) <= tolerance
                and abs(px.g - bg_g) <= tolerance
                and abs(px.b - bg_b) <= tolerance
            ):
                image_alpha.set_at((x, y), (px.r, px.g, px.b, 0))

    return image_alpha
