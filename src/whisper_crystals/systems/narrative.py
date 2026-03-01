"""Narrative system — tracks story flags, arc progression, exit conditions."""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from whisper_crystals.core.data_loader import DataLoader
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData


class NarrativeSystem:
    """Manages arc progression and story flag evaluation."""

    def __init__(self, data_loader: DataLoader, event_bus: EventBus) -> None:
        self.data_loader = data_loader
        self.event_bus = event_bus
        self.arc_definitions: list[dict] = []
        self._loaded = False

    def load(self) -> None:
        """Load arc definitions from data files."""
        self.arc_definitions = self.data_loader.load_arc_definitions()
        self._loaded = True

    def get_current_arc_def(self, game_state: GameStateData) -> dict | None:
        """Return the arc definition matching the current arc."""
        if not self._loaded:
            self.load()
        for arc in self.arc_definitions:
            if arc["arc_id"] == game_state.current_arc:
                return arc
        return None

    def check_arc_exit(self, game_state: GameStateData) -> bool:
        """Check if all exit conditions for the current arc are met."""
        arc_def = self.get_current_arc_def(game_state)
        if arc_def is None:
            return False

        exit_conditions = arc_def.get("exit_conditions", {})
        if not exit_conditions:
            return False

        for flag_name, expected in exit_conditions.items():
            actual = game_state.story_flags.get(flag_name)
            if expected == "!null":
                if actual is None:
                    return False
            elif actual != expected:
                return False

        return True

    def advance_arc(self, game_state: GameStateData) -> str | None:
        """Advance to the next arc if exit conditions are met.

        Returns the new arc_id, or None if no transition occurred.
        """
        arc_def = self.get_current_arc_def(game_state)
        if arc_def is None:
            return None

        next_arc_id = arc_def.get("next_arc_id")
        if next_arc_id is None:
            # Final arc — trigger ending
            self.event_bus.publish("game_ending_reached")
            return None

        old_arc = game_state.current_arc
        game_state.current_arc = next_arc_id

        self.event_bus.publish(
            "arc_advanced",
            old_arc=old_arc,
            new_arc=next_arc_id,
        )

        return next_arc_id

    def get_arc_title(self, arc_id: str) -> str:
        """Return the human-readable title for an arc."""
        if not self._loaded:
            self.load()
        for arc in self.arc_definitions:
            if arc["arc_id"] == arc_id:
                return arc.get("title", arc_id)
        return arc_id

    def get_arc_progress(self, game_state: GameStateData) -> dict:
        """Return a summary of which exit conditions are met/unmet."""
        arc_def = self.get_current_arc_def(game_state)
        if arc_def is None:
            return {}

        exit_conditions = arc_def.get("exit_conditions", {})
        progress = {}
        for flag_name, expected in exit_conditions.items():
            actual = game_state.story_flags.get(flag_name)
            if expected == "!null":
                progress[flag_name] = actual is not None
            else:
                progress[flag_name] = actual == expected

        return progress
