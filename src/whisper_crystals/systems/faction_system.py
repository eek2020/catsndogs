"""Faction system — reputation tracking, cascade rules, diplomatic state."""

from __future__ import annotations

from typing import TYPE_CHECKING

from whisper_crystals.entities.faction import DiplomaticState

if TYPE_CHECKING:
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData


class FactionSystem:
    """Manages faction reputation changes and cascade effects."""

    def __init__(self, event_bus: EventBus) -> None:
        self.event_bus = event_bus

    def change_reputation(
        self,
        game_state: GameStateData,
        faction_id: str,
        delta: int,
        apply_cascade: bool = True,
    ) -> None:
        """Change a faction's reputation with the player.

        Optionally applies cascade rules to related factions.
        """
        faction = game_state.faction_registry.get(faction_id)
        if faction is None:
            return

        old_score = faction.reputation_with_player
        faction.reputation_with_player = max(-100, min(100, old_score + delta))
        faction.update_diplomatic_state()

        self.event_bus.publish(
            "faction_score_changed",
            faction_id=faction_id,
            old_score=old_score,
            new_score=faction.reputation_with_player,
        )

        if apply_cascade:
            self._apply_cascade(game_state, faction_id, delta)

    def _apply_cascade(
        self,
        game_state: GameStateData,
        trigger_faction_id: str,
        delta: int,
    ) -> None:
        """Apply cascade rules: changing one faction's rep can ripple to allies/enemies."""
        for rule in game_state.cascade_rules:
            if rule.get("trigger_faction") == trigger_faction_id:
                affected_id = rule.get("affected_faction")
                ratio = rule.get("cascade_ratio", 0.0)
                if affected_id and affected_id in game_state.faction_registry:
                    cascade_delta = int(delta * ratio)
                    if cascade_delta != 0:
                        # Recursive=False to prevent infinite cascades
                        self.change_reputation(
                            game_state, affected_id, cascade_delta, apply_cascade=False,
                        )

    def get_diplomatic_state(
        self,
        game_state: GameStateData,
        faction_id: str,
    ) -> DiplomaticState | None:
        """Get the current diplomatic state for a faction."""
        faction = game_state.faction_registry.get(faction_id)
        if faction is None:
            return None
        return faction.diplomatic_state

    def get_all_standings(self, game_state: GameStateData) -> list[dict]:
        """Return a sorted list of faction standings for UI display."""
        standings = []
        for fid, faction in game_state.faction_registry.items():
            standings.append({
                "faction_id": fid,
                "name": faction.name,
                "reputation": faction.reputation_with_player,
                "state": faction.diplomatic_state,
                "ideology": faction.ideology,
                "species": faction.species,
            })
        # Sort: player faction first, then by reputation descending
        standings.sort(key=lambda s: (s["faction_id"] != "felid_corsairs", -s["reputation"]))
        return standings
