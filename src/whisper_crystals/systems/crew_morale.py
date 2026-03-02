"""Crew morale system — tracks crew satisfaction and its effects on gameplay.

Crew morale affects combat effectiveness, trade prices, and event outcomes.
Low morale can trigger mutiny events; high morale grants combat bonuses.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData
    from whisper_crystals.entities.ship import CrewMember

# Morale thresholds
MUTINY_THRESHOLD = 20
LOW_THRESHOLD = 40
NEUTRAL_THRESHOLD = 60
HIGH_THRESHOLD = 80


def _morale_label(value: int) -> str:
    """Return a human-readable status label for a morale value."""
    if value <= MUTINY_THRESHOLD:
        return "MUTINY"
    elif value <= LOW_THRESHOLD:
        return "DISGRUNTLED"
    elif value <= NEUTRAL_THRESHOLD:
        return "STEADY"
    elif value <= HIGH_THRESHOLD:
        return "CONTENT"
    else:
        return "INSPIRED"


class CrewMoraleSystem:
    """Manages crew morale tracking and its gameplay effects."""

    def __init__(self, event_bus: EventBus) -> None:
        self.event_bus = event_bus

    # ------------------------------------------------------------------
    # Morale queries
    # ------------------------------------------------------------------

    def get_average_morale(self, game_state: GameStateData) -> int:
        """Calculate average morale across all crew members."""
        crew = game_state.player_ship.crew
        if not crew:
            return 100  # No crew = no morale problems
        total = sum(c.morale for c in crew)
        return total // len(crew)

    def get_morale_status(self, game_state: GameStateData) -> str:
        """Return human-readable morale status."""
        avg = self.get_average_morale(game_state)
        return _morale_label(avg)

    def get_crew_by_morale(
        self, game_state: GameStateData,
    ) -> list[tuple[str, int, str]]:
        """Return crew sorted by morale: (name, morale, status)."""
        result = [
            (c.name, c.morale, _morale_label(c.morale))
            for c in game_state.player_ship.crew
        ]
        result.sort(key=lambda x: x[1])
        return result

    # ------------------------------------------------------------------
    # Morale changes
    # ------------------------------------------------------------------

    def change_crew_morale(
        self,
        game_state: GameStateData,
        delta: int,
        crew_id: str | None = None,
    ) -> None:
        """Change morale for one crew member or all crew.

        Args:
            game_state: Current game state.
            delta: Morale change amount (positive or negative).
            crew_id: If provided, only affect this crew member.
        """
        crew = game_state.player_ship.crew
        affected = []

        for member in crew:
            if crew_id is not None and member.crew_id != crew_id:
                continue
            old_morale = member.morale
            # morale_modifier scales the delta (e.g. +2 means +20% effect)
            # rather than being added unconditionally each call
            effective_delta = int(delta * (1 + member.morale_modifier / 10))
            member.morale = max(0, min(100, member.morale + effective_delta))
            affected.append(member)

            # Check mutiny threshold crossing
            if old_morale > MUTINY_THRESHOLD and member.morale <= MUTINY_THRESHOLD:
                self.event_bus.publish(
                    "crew_mutiny_risk",
                    crew_id=member.crew_id,
                    name=member.name,
                    morale=member.morale,
                )

        if affected:
            self.event_bus.publish(
                "crew_morale_changed",
                delta=delta,
                affected_count=len(affected),
                average_morale=self.get_average_morale(game_state),
            )

    # ------------------------------------------------------------------
    # Combat modifiers from morale
    # ------------------------------------------------------------------

    def get_combat_modifier(self, game_state: GameStateData) -> float:
        """Return a combat effectiveness modifier based on crew morale.

        Returns a multiplier: 0.7 (mutiny) to 1.2 (inspired).
        """
        avg = self.get_average_morale(game_state)
        if avg <= MUTINY_THRESHOLD:
            return 0.7
        elif avg <= LOW_THRESHOLD:
            return 0.85
        elif avg <= NEUTRAL_THRESHOLD:
            return 1.0
        elif avg <= HIGH_THRESHOLD:
            return 1.1
        else:
            return 1.2

    def get_trade_modifier(self, game_state: GameStateData) -> float:
        """Return a trade price modifier based on crew morale.

        Happy crew negotiate better: 0.9 (inspired) to 1.1 (mutiny).
        """
        avg = self.get_average_morale(game_state)
        if avg <= MUTINY_THRESHOLD:
            return 1.1
        elif avg <= LOW_THRESHOLD:
            return 1.05
        elif avg <= NEUTRAL_THRESHOLD:
            return 1.0
        elif avg <= HIGH_THRESHOLD:
            return 0.95
        else:
            return 0.9

    # ------------------------------------------------------------------
    # Event-driven morale effects
    # ------------------------------------------------------------------

    def on_combat_victory(self, game_state: GameStateData) -> None:
        """Boost morale after winning combat."""
        self.change_crew_morale(game_state, 10)

    def on_combat_defeat(self, game_state: GameStateData) -> None:
        """Reduce morale after losing combat."""
        self.change_crew_morale(game_state, -15)

    def on_trade_completed(self, game_state: GameStateData, profit: int) -> None:
        """Adjust morale based on trade outcome."""
        if profit > 0:
            self.change_crew_morale(game_state, 5)
        elif profit < 0:
            self.change_crew_morale(game_state, -3)

    def on_idle_tick(self, game_state: GameStateData) -> None:
        """Gradual morale decay during idle time (called per game tick)."""
        self.change_crew_morale(game_state, -1)

    # ------------------------------------------------------------------
    # Faction loyalty effects
    # ------------------------------------------------------------------

    def check_faction_loyalty(self, game_state: GameStateData) -> list[str]:
        """Check if any crew have faction loyalty conflicts.

        Returns list of crew_ids with loyalty issues (their origin faction
        is hostile to the player).
        """
        conflicts: list[str] = []
        for member in game_state.player_ship.crew:
            faction = game_state.faction_registry.get(member.faction_origin)
            if faction and faction.reputation_with_player <= -50:
                conflicts.append(member.crew_id)
        return conflicts

    def apply_faction_loyalty_effects(self, game_state: GameStateData) -> None:
        """Apply morale penalties for crew whose factions are hostile."""
        for member in game_state.player_ship.crew:
            faction = game_state.faction_registry.get(member.faction_origin)
            if faction and faction.reputation_with_player <= -50:
                self.change_crew_morale(game_state, -5, crew_id=member.crew_id)
