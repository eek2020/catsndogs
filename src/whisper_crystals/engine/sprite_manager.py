"""Centralised sprite loading, caching, and faction-keyed registry.

All sprite loading goes through this module to maintain EAL compliance.
UI states reference sprites via abstract string IDs, never file paths.
Missing sprites fall back gracefully to None (callers use vector shapes).
"""

from __future__ import annotations

import logging
import os
from typing import Any

import pygame

from whisper_crystals.engine.image_utils import load_image_alpha, remove_background_by_corners

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Sprite registry — maps abstract IDs to relative asset paths
# ---------------------------------------------------------------------------

# Ship sprites keyed by ship_template_id from faction_registry.json
SHIP_SPRITES: dict[str, str] = {
    "corsair_raider": "design/ships/ship_r_side.png",
    "league_cruiser": "design/ships/league_cruiser.png",
    "league_destroyer": "design/ships/league_destroyer.jpg",
    "royal_galleon": "design/ships/royal_galleon.jpg",
    "wolf_strike_craft": "design/ships/wolf_ship.png",
    "fairy_vessel": "design/ships/fairy_ship.png",
    "knight_warship": "design/ships/knight_ship.png",
    "goblin_scrapship": "design/ships/goblin_scrapper.png",
    "alien_craft": "design/ships/alien_vessel.png",
}

# Character portraits keyed by character_id
CHARACTER_PORTRAITS: dict[str, str] = {
    "aristotle": "design/charcters/aristotle_head.png",
    "dave": "design/charcters/dave_head.png",
    "death": "design/charcters/death_head.png",
}

# Character full-body sprites
CHARACTER_SPRITES: dict[str, str] = {
    "aristotle": "design/charcters/aristotle.png",
    "dave": "design/charcters/dave.png",
    "death": "design/charcters/death.jpg",
}

# UI sprites
UI_SPRITES: dict[str, str] = {
    "fight_cutlass": "design/ui_ux/fight_cutlass.png",
    "splash_screen": "design/artwork/wc_splash_screen.png",
    "title": "design/artwork/whisper_crystals_title.png",
}

# Faction colour palettes (from art direction guide)
FACTION_COLOURS: dict[str, tuple[int, int, int]] = {
    "felid_corsairs": (180, 50, 220),      # Purple
    "canis_league": (40, 120, 200),         # Blue
    "lion_sovereignty": (200, 170, 40),     # Gold
    "wolf_clans": (80, 100, 80),            # Dark green
    "fairy_court": (180, 130, 220),         # Iridescent lavender
    "knight_order": (190, 190, 210),        # Silver
    "goblin_syndicate": (160, 90, 40),      # Rust
    "ancient_ones": (0, 220, 220),          # Cyan
}


class SpriteManager:
    """Loads, caches, and serves sprite surfaces by abstract ID.

    Usage:
        sprites = SpriteManager(project_root)
        ship_surf = sprites.get_ship("league_cruiser", size=(64, 64))
        portrait = sprites.get_portrait("aristotle", size=(80, 80))

    All returned surfaces are pygame.Surface or None if the asset is missing.
    Callers should fall back to vector shapes when None is returned.
    """

    def __init__(self, project_root: str) -> None:
        self._root = project_root
        self._cache: dict[str, pygame.Surface] = {}
        self._scaled_cache: dict[tuple[str, int, int], pygame.Surface] = {}

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def get_ship(
        self,
        template_id: str,
        size: tuple[int, int] | None = None,
        flip_x: bool = False,
    ) -> pygame.Surface | None:
        """Return a ship sprite by ship_template_id.

        Args:
            template_id: Key from SHIP_SPRITES (e.g. "league_cruiser").
            size: Optional (w, h) to scale the sprite.
            flip_x: If True, horizontally flip the sprite (for enemy-side display).
        """
        rel_path = SHIP_SPRITES.get(template_id, "")
        if not rel_path:
            return None
        surf = self._load(f"ship:{template_id}", rel_path, remove_bg=True)
        if surf is None:
            return None
        if flip_x:
            cache_key = f"ship:{template_id}:flipped"
            if cache_key not in self._cache:
                self._cache[cache_key] = pygame.transform.flip(surf, True, False)
            surf = self._cache[cache_key]
        return self._scale(surf, f"ship:{template_id}:{'f' if flip_x else 'n'}", size)

    def get_portrait(
        self,
        character_id: str,
        size: tuple[int, int] | None = None,
    ) -> pygame.Surface | None:
        """Return a character portrait by character_id."""
        rel_path = CHARACTER_PORTRAITS.get(character_id, "")
        if not rel_path:
            return None
        surf = self._load(f"portrait:{character_id}", rel_path, remove_bg=True)
        return self._scale(surf, f"portrait:{character_id}", size) if surf else None

    def get_character(
        self,
        character_id: str,
        size: tuple[int, int] | None = None,
    ) -> pygame.Surface | None:
        """Return a full-body character sprite by character_id."""
        rel_path = CHARACTER_SPRITES.get(character_id, "")
        if not rel_path:
            return None
        surf = self._load(f"char:{character_id}", rel_path, remove_bg=True)
        return self._scale(surf, f"char:{character_id}", size) if surf else None

    def get_ui(
        self,
        sprite_id: str,
        size: tuple[int, int] | None = None,
        remove_bg: bool = False,
    ) -> pygame.Surface | None:
        """Return a UI sprite (icons, artwork) by abstract ID.

        Args:
            sprite_id: Key from UI_SPRITES.
            size: Optional (w, h) to scale the sprite.
            remove_bg: If True, apply corner-based background removal.
        """
        rel_path = UI_SPRITES.get(sprite_id, "")
        if not rel_path:
            return None
        cache_key = f"ui:{sprite_id}" if not remove_bg else f"ui:{sprite_id}:nobg"
        surf = self._load(cache_key, rel_path, remove_bg=remove_bg)
        return self._scale(surf, cache_key, size) if surf else None

    def get_faction_colour(self, faction_id: str) -> tuple[int, int, int]:
        """Return the primary colour for a faction. Defaults to white."""
        return FACTION_COLOURS.get(faction_id, (255, 255, 255))

    def get_ship_for_faction(
        self,
        faction_id: str,
        faction_registry: dict[str, Any],
        size: tuple[int, int] | None = None,
        flip_x: bool = False,
    ) -> pygame.Surface | None:
        """Look up the ship_template_id for a faction and return the sprite."""
        faction = faction_registry.get(faction_id)
        if faction is None:
            return None
        template_id = getattr(faction, "ship_template_id", None)
        if not template_id:
            return None
        return self.get_ship(template_id, size=size, flip_x=flip_x)

    def preload_all(self) -> int:
        """Eagerly load all registered sprites. Returns count loaded."""
        count = 0
        for template_id, path in SHIP_SPRITES.items():
            if path and self._load(f"ship:{template_id}", path, remove_bg=True):
                count += 1
        for char_id, path in CHARACTER_PORTRAITS.items():
            if path and self._load(f"portrait:{char_id}", path, remove_bg=True):
                count += 1
        for char_id, path in CHARACTER_SPRITES.items():
            if path and self._load(f"char:{char_id}", path, remove_bg=True):
                count += 1
        for sprite_id, path in UI_SPRITES.items():
            if path and self._load(f"ui:{sprite_id}", path, remove_bg=False):
                count += 1
        logger.info("Preloaded %d sprites", count)
        return count

    def clear_cache(self) -> None:
        """Release all cached surfaces."""
        self._cache.clear()
        self._scaled_cache.clear()

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _load(
        self,
        cache_key: str,
        rel_path: str,
        remove_bg: bool = False,
    ) -> pygame.Surface | None:
        """Load a sprite from disk with caching. Returns None on failure."""
        if cache_key in self._cache:
            return self._cache[cache_key]

        full_path = os.path.join(self._root, rel_path)
        surf = load_image_alpha(full_path)
        if surf is None:
            logger.debug("Sprite not found: %s", full_path)
            return None

        if remove_bg:
            surf = remove_background_by_corners(surf)

        self._cache[cache_key] = surf
        return surf

    def _scale(
        self,
        surface: pygame.Surface,
        base_key: str,
        size: tuple[int, int] | None,
    ) -> pygame.Surface:
        """Return a scaled copy of the surface (cached). No-op if size is None."""
        if size is None:
            return surface
        w, h = max(1, size[0]), max(1, size[1])
        scaled_key = (base_key, w, h)
        if scaled_key not in self._scaled_cache:
            self._scaled_cache[scaled_key] = pygame.transform.smoothscale(surface, (w, h))
        return self._scaled_cache[scaled_key]
