"""Music theme manager — maps game states to BGM tracks with fade transitions.

Engine-agnostic: uses AudioInterface ABC. No pygame imports.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from whisper_crystals.core.interfaces import AudioInterface

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Theme registry — maps game state/context keys to music track IDs.
# Track IDs correspond to filenames in assets/audio/music/ (without extension).
# ---------------------------------------------------------------------------

STATE_THEMES: dict[str, str] = {
    "menu": "theme_menu",
    "navigation": "theme_navigation",
    "combat": "theme_combat",
    "trade": "theme_trade",
    "dialogue": "theme_dialogue",
    "cutscene": "theme_cutscene",
    "ending": "theme_ending",
    "pause": "",          # No music change on pause (keeps current track)
    "settings": "",       # No music change on settings
    "faction_screen": "", # No music change
    "ship_screen": "",    # No music change
    "purchase": "",       # No music change
    "mission_log": "",    # No music change
}

# Arc-specific navigation themes override the default navigation theme
ARC_THEMES: dict[str, str] = {
    "arc_1": "theme_arc1",
    "arc_2": "theme_arc2",
    "arc_3": "theme_arc3",
    "arc_4": "theme_arc4",
}

# SFX event registry — maps event bus event names to SFX IDs.
# SFX IDs correspond to filenames in assets/audio/sfx/ (without extension).
SFX_EVENTS: dict[str, str] = {
    "combat_hit": "laser_hit",
    "combat_miss": "laser_fire",
    "combat_victory": "laser_hit",
    "combat_defeat": "laser_hit",
    "combat_flee": "menu_tick",
    "crystal_pickup": "menu_tick",
    "salvage_pickup": "menu_tick",
    "encounter_triggered": "menu_tick",
    "trade_buy": "menu_tick",
    "trade_sell": "menu_tick",
    "mission_accepted": "menu_tick",
    "mission_completed": "menu_tick",
    "mission_failed": "laser_hit",
    "ui_select": "menu_tick",
    "ui_cancel": "menu_tick",
    "ui_navigate": "menu_tick",
    "save_game": "menu_tick",
    "load_game": "menu_tick",
}


class MusicManager:
    """Manages background music themes and SFX triggers.

    Tracks the current playing theme and only changes music when the
    theme actually differs (avoids restarting the same track).
    Overlay states (pause, settings, etc.) don't change music.
    """

    def __init__(self, audio: AudioInterface | None) -> None:
        self._audio = audio
        self._current_theme: str = ""
        self._current_arc: str = ""
        self._music_enabled: bool = True
        self._sfx_enabled: bool = True

    # ------------------------------------------------------------------
    # Music theme control
    # ------------------------------------------------------------------

    def on_state_change(self, state_key: str) -> None:
        """Called when the active game state changes.

        Args:
            state_key: One of the keys in STATE_THEMES (e.g. "navigation", "combat").
        """
        theme = STATE_THEMES.get(state_key, "")
        if not theme:
            # Overlay state — keep current music
            return

        # Use arc-specific theme for navigation if available
        if state_key == "navigation" and self._current_arc in ARC_THEMES:
            theme = ARC_THEMES[self._current_arc]

        self._play_theme(theme)

    def on_arc_change(self, arc_id: str) -> None:
        """Called when the game advances to a new arc.

        Updates the arc-specific navigation theme.
        """
        self._current_arc = arc_id
        # If currently in navigation, switch to the new arc theme
        if self._current_theme in ARC_THEMES.values() or self._current_theme == "theme_navigation":
            arc_theme = ARC_THEMES.get(arc_id, "theme_navigation")
            self._play_theme(arc_theme)

    def stop(self) -> None:
        """Stop all music."""
        if self._audio:
            self._audio.stop_music()
        self._current_theme = ""

    def set_music_enabled(self, enabled: bool) -> None:
        """Enable or disable music playback."""
        self._music_enabled = enabled
        if not enabled:
            self.stop()

    def set_sfx_enabled(self, enabled: bool) -> None:
        """Enable or disable SFX playback."""
        self._sfx_enabled = enabled

    @property
    def current_theme(self) -> str:
        """The currently playing theme ID."""
        return self._current_theme

    # ------------------------------------------------------------------
    # SFX triggers
    # ------------------------------------------------------------------

    def play_sfx_for_event(self, event_name: str) -> None:
        """Play the SFX associated with a game event.

        Args:
            event_name: An event bus event name (e.g. "combat_hit").
        """
        if not self._sfx_enabled or not self._audio:
            return
        sfx_id = SFX_EVENTS.get(event_name)
        if sfx_id:
            self._audio.play_sfx(sfx_id)

    def play_sfx(self, sfx_id: str) -> None:
        """Play a specific SFX by ID."""
        if not self._sfx_enabled or not self._audio:
            return
        self._audio.play_sfx(sfx_id)

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _play_theme(self, theme_id: str) -> None:
        """Switch to a new music theme if it differs from the current one."""
        if theme_id == self._current_theme:
            return
        if not self._music_enabled or not self._audio:
            self._current_theme = theme_id
            return

        logger.info("Music theme change: %s -> %s", self._current_theme, theme_id)
        self._audio.stop_music()
        self._audio.play_music(theme_id, loop=True)
        self._current_theme = theme_id
