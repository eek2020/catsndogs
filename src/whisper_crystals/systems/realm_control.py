"""Realm control system — regional dominance and faction territorial presence.

Tracks which factions control which regions and how regional control
affects gameplay (trade access, encounter rates, danger levels).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData


@dataclass
class RealmState:
    """Tracks faction influence and control over a single region."""

    region_id: str
    controlling_faction: str = ""
    faction_influence: dict[str, float] = field(default_factory=dict)
    contested: bool = False
    danger_modifier: int = 0

    def to_dict(self) -> dict:
        return {
            "region_id": self.region_id,
            "controlling_faction": self.controlling_faction,
            "faction_influence": dict(self.faction_influence),
            "contested": self.contested,
            "danger_modifier": self.danger_modifier,
        }

    @classmethod
    def from_dict(cls, data: dict) -> RealmState:
        return cls(
            region_id=data["region_id"],
            controlling_faction=data.get("controlling_faction", ""),
            faction_influence=data.get("faction_influence", {}),
            contested=data.get("contested", False),
            danger_modifier=data.get("danger_modifier", 0),
        )


class RealmControlSystem:
    """Manages faction territorial control and regional influence."""

    def __init__(self, event_bus: EventBus) -> None:
        self.event_bus = event_bus
        self.realm_states: dict[str, RealmState] = {}

    def initialize_realms(self, game_state: GameStateData) -> None:
        """Set up initial realm control based on faction home territories."""
        region_to_faction = {}
        for fid, faction in game_state.faction_registry.items():
            realm = faction.realm
            if realm:
                region_to_faction.setdefault(realm, []).append(fid)

        for region_id, faction_ids in region_to_faction.items():
            influence = {}
            controller = ""
            max_inf = 0.0

            for fid in faction_ids:
                faction = game_state.faction_registry[fid]
                inf = (
                    faction.military_strength * 0.3
                    + faction.political_influence * 0.4
                    + faction.crystal_reserves * 0.1
                    + faction.internal_stability * 0.2
                )
                influence[fid] = round(inf, 1)
                if inf > max_inf:
                    max_inf = inf
                    controller = fid

            # Check if contested (second-highest influence > 70% of highest)
            sorted_inf = sorted(influence.values(), reverse=True)
            contested = len(sorted_inf) > 1 and sorted_inf[1] > sorted_inf[0] * 0.7

            self.realm_states[region_id] = RealmState(
                region_id=region_id,
                controlling_faction=controller,
                faction_influence=influence,
                contested=contested,
            )

    # ------------------------------------------------------------------
    # Influence changes
    # ------------------------------------------------------------------

    def add_influence(
        self,
        region_id: str,
        faction_id: str,
        amount: float,
    ) -> None:
        """Add influence for a faction in a region."""
        state = self.realm_states.get(region_id)
        if state is None:
            state = RealmState(region_id=region_id)
            self.realm_states[region_id] = state

        current = state.faction_influence.get(faction_id, 0.0)
        state.faction_influence[faction_id] = max(0.0, min(100.0, current + amount))
        self._recalculate_control(state)

    def remove_influence(
        self,
        region_id: str,
        faction_id: str,
        amount: float,
    ) -> None:
        """Remove influence for a faction in a region."""
        self.add_influence(region_id, faction_id, -amount)

    def _recalculate_control(self, state: RealmState) -> None:
        """Recalculate which faction controls a region."""
        if not state.faction_influence:
            state.controlling_faction = ""
            state.contested = False
            return

        sorted_factions = sorted(
            state.faction_influence.items(),
            key=lambda x: -x[1],
        )

        old_controller = state.controlling_faction
        new_controller = sorted_factions[0][0]
        top_inf = sorted_factions[0][1]

        # Contested if second place is close
        state.contested = (
            len(sorted_factions) > 1
            and sorted_factions[1][1] > top_inf * 0.7
        )

        # Danger increases when contested
        state.danger_modifier = 2 if state.contested else 0

        if new_controller != old_controller and top_inf > 0:
            state.controlling_faction = new_controller
            self.event_bus.publish(
                "realm_control_changed",
                region_id=state.region_id,
                old_controller=old_controller,
                new_controller=new_controller,
                contested=state.contested,
            )

    # ------------------------------------------------------------------
    # Faction conflict effects on realms
    # ------------------------------------------------------------------

    def apply_conflict_result(
        self,
        region_id: str,
        winner_id: str,
        loser_id: str,
        intensity: float = 10.0,
    ) -> None:
        """Apply the result of a faction conflict to realm control."""
        self.add_influence(region_id, winner_id, intensity)
        self.remove_influence(region_id, loser_id, intensity * 0.7)

    # ------------------------------------------------------------------
    # Update tick
    # ------------------------------------------------------------------

    def update_realm_control(self, game_state: GameStateData) -> None:
        """Update realm influence based on current faction stats.

        Called periodically to drift influence towards faction strength.
        """
        for region_id, state in self.realm_states.items():
            for fid in list(state.faction_influence.keys()):
                faction = game_state.faction_registry.get(fid)
                if faction is None:
                    continue

                # Natural drift based on faction home realm
                if faction.realm == region_id:
                    # Home realm: influence grows slowly
                    self.add_influence(region_id, fid, 1.0)
                else:
                    # Foreign realm: influence decays slowly
                    current = state.faction_influence.get(fid, 0.0)
                    if current > 0:
                        self.remove_influence(region_id, fid, 0.5)

    # ------------------------------------------------------------------
    # Query helpers
    # ------------------------------------------------------------------

    def get_region_controller(self, region_id: str) -> str:
        """Return the faction controlling a region, or empty string."""
        state = self.realm_states.get(region_id)
        return state.controlling_faction if state else ""

    def is_contested(self, region_id: str) -> bool:
        """Check if a region is contested between factions."""
        state = self.realm_states.get(region_id)
        return state.contested if state else False

    def get_region_danger(self, region_id: str) -> int:
        """Return danger modifier for a region (0 = safe, 2 = contested)."""
        state = self.realm_states.get(region_id)
        return state.danger_modifier if state else 0

    def get_faction_territories(
        self, faction_id: str,
    ) -> list[str]:
        """Return list of region IDs controlled by a faction."""
        return [
            rid for rid, state in self.realm_states.items()
            if state.controlling_faction == faction_id
        ]

    def get_realm_overview(self) -> list[dict]:
        """Return overview of all realms for UI display."""
        overview = []
        for rid, state in self.realm_states.items():
            overview.append({
                "region_id": rid,
                "controller": state.controlling_faction,
                "contested": state.contested,
                "danger": state.danger_modifier,
                "influence": dict(state.faction_influence),
            })
        overview.sort(key=lambda r: r["region_id"])
        return overview

    # ------------------------------------------------------------------
    # Serialization
    # ------------------------------------------------------------------

    def get_state_dict(self) -> dict:
        """Serialize realm control state."""
        return {
            rid: state.to_dict()
            for rid, state in self.realm_states.items()
        }

    def load_state_dict(self, data: dict) -> None:
        """Restore realm control state."""
        self.realm_states = {
            rid: RealmState.from_dict(rdata)
            for rid, rdata in data.items()
        }
