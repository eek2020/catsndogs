"""Side mission system — manages mission lifecycle, objective tracking, and rewards."""

from __future__ import annotations

import logging
import random
from typing import TYPE_CHECKING

from whisper_crystals.entities.encounter import Encounter
from whisper_crystals.entities.side_mission import SideMission

if TYPE_CHECKING:
    from whisper_crystals.core.data_loader import DataLoader
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData

logger = logging.getLogger(__name__)

# How often distress signals can spawn (seconds between spawns)
DISTRESS_SPAWN_INTERVAL = 45.0
MAX_ACTIVE_DISTRESS = 2


class SideMissionSystem:
    """Manages side missions: discovery, objective tracking, completion, and rewards.

    Listens for encounter_completed events to auto-complete linked objectives.
    Provides distress signal encounters that spawn periodically during navigation.
    """

    def __init__(self, data_loader: DataLoader, event_bus: EventBus) -> None:
        self.data_loader = data_loader
        self.event_bus = event_bus
        self._mission_templates: list[SideMission] = []
        self._distress_pool: list[Encounter] = []
        self._distress_timer: float = 0.0
        self._active_distress_ids: list[str] = []

        # Listen for encounter completions to advance objectives
        self.event_bus.subscribe("encounter_completed", self._on_encounter_completed)

    def load_missions(self, arc_id: str) -> None:
        """Load side mission definitions for the given arc."""
        self._mission_templates = self.data_loader.load_side_missions(arc_id)
        logger.info(
            "Loaded %d side mission templates for %s",
            len(self._mission_templates), arc_id,
        )

    def load_distress_signals(self) -> None:
        """Load the distress signal encounter pool."""
        self._distress_pool = self.data_loader.load_distress_signals()
        logger.info("Loaded %d distress signal encounters", len(self._distress_pool))

    # ------------------------------------------------------------------
    # Mission discovery & activation
    # ------------------------------------------------------------------

    def get_available_missions(self, game_state: GameStateData) -> list[SideMission]:
        """Return missions whose trigger conditions are met and not yet known."""
        available: list[SideMission] = []
        for template in self._mission_templates:
            if template.mission_id in game_state.side_missions:
                continue
            if self._evaluate_conditions(template.trigger_conditions, game_state):
                available.append(template)
        return sorted(available, key=lambda m: -m.priority)

    def discover_mission(
        self, game_state: GameStateData, mission_id: str,
    ) -> SideMission | None:
        """Add a mission to the player's log as 'active'. Returns the mission or None."""
        for template in self._mission_templates:
            if template.mission_id == mission_id:
                mission = SideMission.from_dict(template.to_dict())
                mission.status = "active"
                game_state.side_missions[mission.mission_id] = mission
                self.event_bus.publish(
                    "mission_discovered",
                    mission_id=mission.mission_id,
                    title=mission.title,
                )
                logger.info("Mission discovered: %s", mission.title)
                return mission
        return None

    def activate_mission(
        self, game_state: GameStateData, mission_id: str,
    ) -> bool:
        """Activate a known mission. Returns True on success."""
        mission = game_state.side_missions.get(mission_id)
        if mission and mission.status == "available":
            mission.status = "active"
            self.event_bus.publish(
                "mission_activated", mission_id=mission_id,
            )
            return True
        return False

    def fail_mission(
        self, game_state: GameStateData, mission_id: str,
    ) -> bool:
        """Mark a mission as failed. Returns True on success."""
        mission = game_state.side_missions.get(mission_id)
        if mission and mission.status == "active":
            mission.status = "failed"
            self.event_bus.publish(
                "mission_failed", mission_id=mission_id,
            )
            return True
        return False

    # ------------------------------------------------------------------
    # Objective tracking
    # ------------------------------------------------------------------

    def _on_encounter_completed(
        self, encounter_id: str, choice_id: str, **kwargs,
    ) -> None:
        """Called via event bus when any encounter completes.

        We don't have game_state here, so we store the encounter_id and
        process it on the next update tick.
        """
        self._pending_encounter_ids.append(encounter_id)

    def check_objectives(self, game_state: GameStateData) -> list[str]:
        """Process pending encounter completions and return newly-completed mission IDs."""
        completed_missions: list[str] = []

        for mission in game_state.side_missions.values():
            if mission.status != "active":
                continue
            for obj in mission.objectives:
                if obj.completed:
                    continue
                if obj.encounter_id and obj.encounter_id in game_state.completed_encounters:
                    obj.completed = True
                    self.event_bus.publish(
                        "objective_completed",
                        mission_id=mission.mission_id,
                        objective_id=obj.objective_id,
                    )

            if mission.is_complete:
                mission.status = "completed"
                self._apply_rewards(game_state, mission)
                completed_missions.append(mission.mission_id)
                self.event_bus.publish(
                    "mission_completed",
                    mission_id=mission.mission_id,
                    title=mission.title,
                )
                logger.info("Mission completed: %s", mission.title)

        return completed_missions

    # ------------------------------------------------------------------
    # Rewards
    # ------------------------------------------------------------------

    def _apply_rewards(self, game_state: GameStateData, mission: SideMission) -> None:
        """Grant mission rewards to the player."""
        for resource, amount in mission.rewards.items():
            if resource == "crystals":
                game_state.crystal_inventory = max(
                    0, game_state.crystal_inventory + amount,
                )
            elif resource == "salvage":
                game_state.salvage = max(0, game_state.salvage + amount)

        for faction_id, delta in mission.faction_rewards.items():
            faction = game_state.faction_registry.get(faction_id)
            if faction:
                faction.reputation_with_player = max(
                    -100, min(100, faction.reputation_with_player + delta),
                )
                faction.update_diplomatic_state()
                self.event_bus.publish(
                    "faction_score_changed",
                    faction_id=faction_id,
                    new_score=faction.reputation_with_player,
                )

    # ------------------------------------------------------------------
    # Distress signals
    # ------------------------------------------------------------------

    def update_distress(self, dt: float, game_state: GameStateData) -> Encounter | None:
        """Tick the distress timer. Returns a distress encounter to spawn, or None."""
        if not self._distress_pool:
            return None

        # Clean up completed distress encounters from active list
        self._active_distress_ids = [
            eid for eid in self._active_distress_ids
            if eid not in game_state.completed_encounters
        ]

        if len(self._active_distress_ids) >= MAX_ACTIVE_DISTRESS:
            return None

        self._distress_timer += dt
        if self._distress_timer < DISTRESS_SPAWN_INTERVAL:
            return None

        self._distress_timer = 0.0

        # Pick a weighted random distress encounter
        candidates = [
            e for e in self._distress_pool
            if e.encounter_id not in self._active_distress_ids
        ]
        if not candidates:
            return None

        weights = [getattr(e, "spawn_weight", 1.0) for e in candidates]
        total = sum(weights)
        if total <= 0:
            return None

        pick = random.random() * total
        cumulative = 0.0
        chosen = candidates[0]
        for enc, w in zip(candidates, weights):
            cumulative += w
            if pick <= cumulative:
                chosen = enc
                break

        self._active_distress_ids.append(chosen.encounter_id)
        self.event_bus.publish(
            "distress_signal_detected",
            encounter_id=chosen.encounter_id,
            title=chosen.title,
        )
        return chosen

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def get_active_missions(self, game_state: GameStateData) -> list[SideMission]:
        """Return all missions with status 'active'."""
        return [
            m for m in game_state.side_missions.values()
            if m.status == "active"
        ]

    def get_completed_missions(self, game_state: GameStateData) -> list[SideMission]:
        """Return all missions with status 'completed'."""
        return [
            m for m in game_state.side_missions.values()
            if m.status == "completed"
        ]

    def get_mission_count(self, game_state: GameStateData) -> int:
        """Return the number of active missions."""
        return sum(
            1 for m in game_state.side_missions.values()
            if m.status == "active"
        )

    @staticmethod
    def _evaluate_conditions(conditions: dict, game_state: GameStateData) -> bool:
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
                    if actual is None and isinstance(expected, bool):
                        actual = False
                    if actual != expected:
                        return False
        return True

    @property
    def _pending_encounter_ids(self) -> list[str]:
        """Lazy-init pending encounter ID list."""
        if not hasattr(self, "_pending_encounters"):
            self._pending_encounters: list[str] = []
        return self._pending_encounters
