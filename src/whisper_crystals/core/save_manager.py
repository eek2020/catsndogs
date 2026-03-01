"""Save/Load Manager — handles persisting and restoring GameStateData to disk.

This module is engine-agnostic: ZERO pygame imports.
Migration class: PORTABLE.
"""

from __future__ import annotations

import json
import logging
import os
import time
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData

logger = logging.getLogger(__name__)

MAX_SAVE_SLOTS = 3
SAVE_FILE_PREFIX = "save_slot_"
SAVE_FILE_EXT = ".json"


def _default_save_dir() -> str:
    """Return the platform-appropriate save directory."""
    home = Path.home()
    return str(home / ".whisper_crystals" / "saves")


class SaveManager:
    """Manages save/load operations for game state data.

    Saves are stored as human-readable JSON files, one per slot.
    """

    def __init__(self, save_dir: str | None = None) -> None:
        self.save_dir = save_dir or _default_save_dir()

    def _ensure_dir(self) -> None:
        """Create save directory if it doesn't exist."""
        os.makedirs(self.save_dir, exist_ok=True)

    def _slot_path(self, slot: int) -> str:
        """Return the file path for a given save slot."""
        return os.path.join(self.save_dir, f"{SAVE_FILE_PREFIX}{slot}{SAVE_FILE_EXT}")

    def save_game(self, game_state: GameStateData, slot: int) -> bool:
        """Write game state to disk as JSON. Returns True on success."""
        if not 0 <= slot < MAX_SAVE_SLOTS:
            logger.error("Invalid save slot: %d", slot)
            return False

        self._ensure_dir()
        game_state.save_slot = slot

        data = game_state.to_dict()
        data["_meta"] = {
            "saved_at": time.time(),
            "character_name": game_state.player_character.name,
            "arc": game_state.current_arc,
            "playtime": game_state.playtime_seconds,
        }

        path = self._slot_path(slot)
        tmp_path = path + ".tmp"
        try:
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            os.replace(tmp_path, path)
            logger.info("Game saved to slot %d: %s", slot, path)
            return True
        except OSError:
            logger.exception("Failed to save game to slot %d", slot)
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
            return False

    def load_game(self, slot: int) -> GameStateData | None:
        """Load game state from disk. Returns None if file doesn't exist or is invalid."""
        from whisper_crystals.core.game_state import GameStateData

        if not 0 <= slot < MAX_SAVE_SLOTS:
            logger.error("Invalid save slot: %d", slot)
            return None

        path = self._slot_path(slot)
        if not os.path.exists(path):
            logger.info("No save file for slot %d", slot)
            return None

        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            data.pop("_meta", None)
            return GameStateData.from_dict(data)
        except (OSError, json.JSONDecodeError, KeyError, TypeError):
            logger.exception("Failed to load save from slot %d", slot)
            return None

    def get_save_info(self) -> list[dict | None]:
        """Return metadata for all save slots.

        Returns a list of length MAX_SAVE_SLOTS. Each element is either
        a dict with save metadata or None if the slot is empty.
        """
        result: list[dict | None] = []
        for slot in range(MAX_SAVE_SLOTS):
            path = self._slot_path(slot)
            if not os.path.exists(path):
                result.append(None)
                continue
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                meta = data.get("_meta", {})
                result.append({
                    "slot": slot,
                    "character_name": meta.get("character_name", "Unknown"),
                    "arc": meta.get("arc", "???"),
                    "playtime": meta.get("playtime", 0.0),
                    "saved_at": meta.get("saved_at", 0.0),
                })
            except (OSError, json.JSONDecodeError):
                result.append(None)
        return result

    def delete_save(self, slot: int) -> bool:
        """Delete a save file. Returns True on success."""
        if not 0 <= slot < MAX_SAVE_SLOTS:
            return False
        path = self._slot_path(slot)
        if os.path.exists(path):
            try:
                os.remove(path)
                logger.info("Deleted save slot %d", slot)
                return True
            except OSError:
                logger.exception("Failed to delete save slot %d", slot)
                return False
        return True
