"""Encounter engine — evaluates triggers, dispatches encounters."""

from __future__ import annotations

from typing import TYPE_CHECKING

from whisper_crystals.entities.encounter import Encounter

if TYPE_CHECKING:
    from whisper_crystals.core.data_loader import DataLoader
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData


class EncounterEngine:
    """Manages encounter trigger evaluation and dispatch."""

    def __init__(self, data_loader: DataLoader, event_bus: EventBus) -> None:
        self.data_loader = data_loader
        self.event_bus = event_bus
        self.encounter_table: list[Encounter] = []

    def load_encounters(self, arc_id: str) -> None:
        """Load encounter definitions for the current story arc."""
        self.encounter_table = self.data_loader.load_encounters(arc_id)

    def check_triggers(self, game_state: GameStateData) -> Encounter | None:
        """Evaluate all encounter triggers against current game state.

        Returns the highest-priority encounter whose conditions are met
        and which hasn't been completed yet (unless repeatable).
        """
        for encounter in sorted(self.encounter_table, key=lambda e: -e.priority):
            if not encounter.repeatable and encounter.encounter_id in game_state.completed_encounters:
                continue
            if self._evaluate_conditions(encounter.trigger_conditions, game_state):
                return encounter
        return None

    def _evaluate_conditions(self, conditions: dict, game_state: GameStateData) -> bool:
        """Check if all trigger conditions are satisfied by the current game state."""
        for key, expected in conditions.items():
            if key == "current_arc":
                if game_state.current_arc != expected:
                    return False
            else:
                actual = game_state.story_flags.get(key)
                if expected == "!null":
                    if actual is None:
                        return False
                else:
                    # Coerce None to False for boolean expectations
                    if actual is None and isinstance(expected, bool):
                        actual = False
                    if actual != expected:
                        return False
        return True

    def apply_choice_outcome(
        self,
        game_state: GameStateData,
        encounter: Encounter,
        choice_index: int,
    ) -> str:
        """Apply the outcome of a player's choice. Returns the outcome description."""
        choice = encounter.choices[choice_index]
        outcome = choice.outcome

        # Set story flags
        for flag in outcome.story_flags_set:
            game_state.story_flags[flag] = True

        # Clear story flags
        for flag in outcome.story_flags_cleared:
            game_state.story_flags.pop(flag, None)

        # Apply resource changes
        for resource, delta in outcome.resource_changes.items():
            if resource == "crystal_inventory":
                game_state.crystal_inventory = max(0, game_state.crystal_inventory + delta)
            elif resource == "crystal_quality":
                game_state.crystal_quality = max(1, min(5, game_state.crystal_quality + delta))
            elif resource == "salvage":
                game_state.salvage = max(0, game_state.salvage + delta)

        # Apply faction reputation changes
        for faction_id, delta in outcome.faction_changes.items():
            if faction_id in game_state.faction_registry:
                faction = game_state.faction_registry[faction_id]
                faction.reputation_with_player = max(-100, min(100, faction.reputation_with_player + delta))
                faction.update_diplomatic_state()
                self.event_bus.publish(
                    "faction_score_changed",
                    faction_id=faction_id,
                    new_score=faction.reputation_with_player,
                )

        # Record decision
        from whisper_crystals.core.game_state import PlayerDecision
        decision = PlayerDecision(
            decision_id=f"{encounter.encounter_id}_{choice.choice_id}",
            encounter_id=encounter.encounter_id,
            choice_id=choice.choice_id,
            arc_id=encounter.arc_id,
            timestamp=game_state.playtime_seconds,
            outcome_weight=choice.outcome_weight,
        )
        game_state.player_decisions.append(decision)

        # Mark encounter as completed
        game_state.completed_encounters.append(encounter.encounter_id)

        self.event_bus.publish(
            "encounter_completed",
            encounter_id=encounter.encounter_id,
            choice_id=choice.choice_id,
        )

        return outcome.description
