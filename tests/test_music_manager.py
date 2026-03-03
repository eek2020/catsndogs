"""Tests for the MusicManager — theme mapping, state transitions, and SFX triggers."""

from unittest.mock import MagicMock, call

from whisper_crystals.core.music_manager import (
    ARC_THEMES,
    SFX_EVENTS,
    STATE_THEMES,
    MusicManager,
)


def _make_audio() -> MagicMock:
    """Create a mock AudioInterface."""
    audio = MagicMock()
    audio.play_music = MagicMock()
    audio.stop_music = MagicMock()
    audio.play_sfx = MagicMock()
    return audio


class TestStateThemes:
    """Verify the theme registry has sensible defaults."""

    def test_all_primary_states_have_themes(self):
        for key in ("menu", "navigation", "combat", "trade", "dialogue", "cutscene", "ending"):
            assert STATE_THEMES[key] != "", f"{key} should have a theme"

    def test_overlay_states_have_no_theme(self):
        for key in ("pause", "settings", "faction_screen", "ship_screen", "purchase", "mission_log"):
            assert STATE_THEMES[key] == "", f"{key} should be empty (overlay)"

    def test_arc_themes_has_four_arcs(self):
        assert len(ARC_THEMES) == 4
        for arc in ("arc_1", "arc_2", "arc_3", "arc_4"):
            assert arc in ARC_THEMES


class TestMusicManagerThemes:
    """Test MusicManager theme switching logic."""

    def test_on_state_change_plays_theme(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.on_state_change("menu")
        audio.play_music.assert_called_once_with("theme_menu", loop=True)
        assert mgr.current_theme == "theme_menu"

    def test_same_theme_not_replayed(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.on_state_change("menu")
        mgr.on_state_change("menu")
        # Should only call play_music once
        assert audio.play_music.call_count == 1

    def test_overlay_state_keeps_current_theme(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.on_state_change("navigation")
        audio.play_music.reset_mock()
        mgr.on_state_change("pause")
        audio.play_music.assert_not_called()
        # Theme should still be navigation
        assert mgr.current_theme == "theme_navigation"

    def test_state_change_stops_then_plays(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.on_state_change("menu")
        audio.reset_mock()
        mgr.on_state_change("combat")
        audio.stop_music.assert_called_once()
        audio.play_music.assert_called_once_with("theme_combat", loop=True)

    def test_navigation_uses_arc_theme(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.on_arc_change("arc_2")
        mgr.on_state_change("navigation")
        audio.play_music.assert_called_with("theme_arc2", loop=True)
        assert mgr.current_theme == "theme_arc2"

    def test_arc_change_during_navigation_switches_theme(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.on_state_change("navigation")
        audio.reset_mock()
        mgr.on_arc_change("arc_3")
        audio.stop_music.assert_called_once()
        audio.play_music.assert_called_with("theme_arc3", loop=True)

    def test_arc_change_during_combat_does_not_switch(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.on_state_change("combat")
        audio.reset_mock()
        mgr.on_arc_change("arc_3")
        audio.play_music.assert_not_called()

    def test_stop_clears_theme(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.on_state_change("menu")
        mgr.stop()
        assert mgr.current_theme == ""
        audio.stop_music.assert_called()

    def test_music_disabled_does_not_play(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.set_music_enabled(False)
        mgr.on_state_change("menu")
        audio.play_music.assert_not_called()
        # Theme is still tracked even when disabled
        assert mgr.current_theme == "theme_menu"

    def test_no_audio_subsystem(self):
        mgr = MusicManager(None)
        # Should not crash
        mgr.on_state_change("menu")
        assert mgr.current_theme == "theme_menu"
        mgr.on_arc_change("arc_1")
        mgr.on_state_change("navigation")
        assert mgr.current_theme == "theme_arc1"
        mgr.stop()
        assert mgr.current_theme == ""


class TestMusicManagerSFX:
    """Test SFX event triggers."""

    def test_play_sfx_for_known_event(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.play_sfx_for_event("combat_hit")
        audio.play_sfx.assert_called_once_with("laser_hit")

    def test_play_sfx_for_unknown_event(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.play_sfx_for_event("unknown_event")
        audio.play_sfx.assert_not_called()

    def test_sfx_disabled(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.set_sfx_enabled(False)
        mgr.play_sfx_for_event("combat_hit")
        audio.play_sfx.assert_not_called()

    def test_play_sfx_direct(self):
        audio = _make_audio()
        mgr = MusicManager(audio)
        mgr.play_sfx("custom_sound")
        audio.play_sfx.assert_called_once_with("custom_sound")

    def test_sfx_events_registry_not_empty(self):
        assert len(SFX_EVENTS) > 0
        for event, sfx_id in SFX_EVENTS.items():
            assert isinstance(sfx_id, str) and sfx_id, f"{event} SFX ID must be a non-empty string"
