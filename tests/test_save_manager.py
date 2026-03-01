"""Tests for the Save/Load Manager."""

from __future__ import annotations

import json
import os
import tempfile

import pytest

from whisper_crystals.core.game_state import GameStateData
from whisper_crystals.core.save_manager import MAX_SAVE_SLOTS, SaveManager


@pytest.fixture
def tmp_save_dir(tmp_path):
    """Return a temporary directory for save files."""
    return str(tmp_path / "saves")


@pytest.fixture
def save_manager(tmp_save_dir):
    return SaveManager(save_dir=tmp_save_dir)


@pytest.fixture
def game_state():
    """Return a minimal GameStateData for testing."""
    state = GameStateData()
    state.crystal_inventory = 42
    state.playtime_seconds = 123.4
    state.current_arc = "arc_2"
    state.story_flags["test_flag"] = True
    return state


class TestSaveManager:
    def test_save_and_load_roundtrip(self, save_manager, game_state):
        """Save then load should restore the same data."""
        assert save_manager.save_game(game_state, 0)
        loaded = save_manager.load_game(0)
        assert loaded is not None
        assert loaded.crystal_inventory == 42
        assert loaded.playtime_seconds == pytest.approx(123.4)
        assert loaded.current_arc == "arc_2"
        assert loaded.story_flags["test_flag"] is True

    def test_save_creates_directory(self, tmp_save_dir, game_state):
        """Save should create the save directory if it doesn't exist."""
        mgr = SaveManager(save_dir=tmp_save_dir)
        assert not os.path.exists(tmp_save_dir)
        mgr.save_game(game_state, 0)
        assert os.path.isdir(tmp_save_dir)

    def test_load_nonexistent_slot(self, save_manager):
        """Loading from an empty slot returns None."""
        assert save_manager.load_game(0) is None

    def test_invalid_slot_save(self, save_manager, game_state):
        """Saving to an out-of-range slot returns False."""
        assert not save_manager.save_game(game_state, -1)
        assert not save_manager.save_game(game_state, MAX_SAVE_SLOTS)

    def test_invalid_slot_load(self, save_manager):
        """Loading from an out-of-range slot returns None."""
        assert save_manager.load_game(-1) is None
        assert save_manager.load_game(MAX_SAVE_SLOTS) is None

    def test_get_save_info_empty(self, save_manager):
        """All slots should be None when no saves exist."""
        info = save_manager.get_save_info()
        assert len(info) == MAX_SAVE_SLOTS
        assert all(s is None for s in info)

    def test_get_save_info_with_save(self, save_manager, game_state):
        """After saving, save info should contain metadata."""
        save_manager.save_game(game_state, 1)
        info = save_manager.get_save_info()
        assert info[0] is None
        assert info[1] is not None
        assert info[1]["slot"] == 1
        assert info[1]["character_name"] == "Aristotle"
        assert info[1]["arc"] == "arc_2"
        assert info[1]["playtime"] == pytest.approx(123.4)

    def test_delete_save(self, save_manager, game_state):
        """Deleting a save should remove it from disk."""
        save_manager.save_game(game_state, 0)
        assert save_manager.load_game(0) is not None
        assert save_manager.delete_save(0)
        assert save_manager.load_game(0) is None

    def test_save_file_is_valid_json(self, save_manager, game_state, tmp_save_dir):
        """Save files should be human-readable JSON."""
        save_manager.save_game(game_state, 0)
        path = save_manager._slot_path(0)
        with open(path, "r") as f:
            data = json.load(f)
        assert isinstance(data, dict)
        assert data["crystal_inventory"] == 42
        assert "_meta" in data

    def test_overwrite_save(self, save_manager, game_state):
        """Saving to the same slot should overwrite."""
        save_manager.save_game(game_state, 0)
        game_state.crystal_inventory = 999
        save_manager.save_game(game_state, 0)
        loaded = save_manager.load_game(0)
        assert loaded.crystal_inventory == 999

    def test_multiple_slots(self, save_manager, game_state):
        """Different slots should hold independent saves."""
        game_state.crystal_inventory = 10
        save_manager.save_game(game_state, 0)
        game_state.crystal_inventory = 20
        save_manager.save_game(game_state, 1)

        assert save_manager.load_game(0).crystal_inventory == 10
        assert save_manager.load_game(1).crystal_inventory == 20

    def test_corrupted_save_returns_none(self, save_manager, tmp_save_dir):
        """A corrupted save file should return None, not crash."""
        os.makedirs(tmp_save_dir, exist_ok=True)
        path = save_manager._slot_path(0)
        with open(path, "w") as f:
            f.write("not valid json {{{")
        assert save_manager.load_game(0) is None
