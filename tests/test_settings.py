"""Tests for settings load/save."""

from __future__ import annotations

import json
import os

import pytest

from whisper_crystals.ui.settings_screen import (
    DEFAULT_SETTINGS,
    load_settings,
    save_settings,
)


@pytest.fixture
def settings_path(tmp_path):
    return str(tmp_path / "settings.json")


class TestSettings:
    def test_load_defaults_when_no_file(self, tmp_path):
        """Should return defaults when file doesn't exist."""
        path = str(tmp_path / "nonexistent" / "settings.json")
        result = load_settings(path)
        assert result == DEFAULT_SETTINGS

    def test_save_and_load_roundtrip(self, settings_path):
        """Save then load should restore settings."""
        settings = {"music_volume": 50, "sfx_volume": 30, "difficulty": "Hard"}
        assert save_settings(settings, settings_path)
        loaded = load_settings(settings_path)
        assert loaded["music_volume"] == 50
        assert loaded["sfx_volume"] == 30
        assert loaded["difficulty"] == "Hard"

    def test_load_merges_with_defaults(self, settings_path):
        """Partial settings file should be merged with defaults."""
        with open(settings_path, "w") as f:
            json.dump({"music_volume": 42}, f)
        loaded = load_settings(settings_path)
        assert loaded["music_volume"] == 42
        assert loaded["sfx_volume"] == DEFAULT_SETTINGS["sfx_volume"]

    def test_corrupted_file_returns_defaults(self, settings_path):
        """Corrupted file should fall back to defaults."""
        with open(settings_path, "w") as f:
            f.write("invalid json!!!")
        result = load_settings(settings_path)
        assert result == DEFAULT_SETTINGS

    def test_save_creates_directory(self, tmp_path):
        """Save should create directories as needed."""
        path = str(tmp_path / "sub" / "dir" / "settings.json")
        assert save_settings({"test": 1}, path)
        assert os.path.exists(path)
