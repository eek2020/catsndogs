"""Exploration system — region discovery, points of interest, random events.

Manages exploration mechanics: discovering new regions, points of interest
within regions, and generating exploration events based on player location.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData


@dataclass
class PointOfInterest:
    """A discoverable location within a region."""

    poi_id: str
    region: str
    name: str
    poi_type: str  # "deposit", "wreck", "settlement", "anomaly", "hazard"
    description: str = ""
    is_discovered: bool = False
    is_visited: bool = False
    rewards: dict = field(default_factory=dict)
    risk_level: int = 1

    def to_dict(self) -> dict:
        return {
            "poi_id": self.poi_id,
            "region": self.region,
            "name": self.name,
            "poi_type": self.poi_type,
            "description": self.description,
            "is_discovered": self.is_discovered,
            "is_visited": self.is_visited,
            "rewards": dict(self.rewards),
            "risk_level": self.risk_level,
        }

    @classmethod
    def from_dict(cls, data: dict) -> PointOfInterest:
        return cls(
            poi_id=data["poi_id"],
            region=data["region"],
            name=data["name"],
            poi_type=data["poi_type"],
            description=data.get("description", ""),
            is_discovered=data.get("is_discovered", False),
            is_visited=data.get("is_visited", False),
            rewards=data.get("rewards", {}),
            risk_level=data.get("risk_level", 1),
        )


@dataclass
class Region:
    """A navigable region of the game world."""

    region_id: str
    name: str
    controlling_faction: str = ""
    danger_level: int = 1  # 1-5
    is_discovered: bool = False
    is_accessible: bool = True
    connected_regions: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "region_id": self.region_id,
            "name": self.name,
            "controlling_faction": self.controlling_faction,
            "danger_level": self.danger_level,
            "is_discovered": self.is_discovered,
            "is_accessible": self.is_accessible,
            "connected_regions": list(self.connected_regions),
        }

    @classmethod
    def from_dict(cls, data: dict) -> Region:
        return cls(
            region_id=data["region_id"],
            name=data["name"],
            controlling_faction=data.get("controlling_faction", ""),
            danger_level=data.get("danger_level", 1),
            is_discovered=data.get("is_discovered", False),
            is_accessible=data.get("is_accessible", True),
            connected_regions=data.get("connected_regions", []),
        )


# Exploration event types that can be generated
EXPLORATION_EVENTS = [
    {"type": "salvage_find", "weight": 30, "description": "Floating wreckage detected"},
    {"type": "crystal_trace", "weight": 20, "description": "Faint crystal signature"},
    {"type": "hostile_patrol", "weight": 25, "description": "Enemy patrol spotted"},
    {"type": "trader_vessel", "weight": 15, "description": "Merchant vessel hailing"},
    {"type": "anomaly", "weight": 10, "description": "Unknown energy signature"},
]


class ExplorationSystem:
    """Manages region exploration, point-of-interest discovery, and events."""

    def __init__(self, event_bus: EventBus) -> None:
        self.event_bus = event_bus
        self.regions: dict[str, Region] = {}
        self.points_of_interest: dict[str, PointOfInterest] = {}

    def load_regions(self, region_data: list[dict]) -> None:
        """Load region definitions from data."""
        self.regions = {}
        for data in region_data:
            region = Region.from_dict(data)
            self.regions[region.region_id] = region

    def load_pois(self, poi_data: list[dict]) -> None:
        """Load points of interest from data."""
        self.points_of_interest = {}
        for data in poi_data:
            poi = PointOfInterest.from_dict(data)
            self.points_of_interest[poi.poi_id] = poi

    # ------------------------------------------------------------------
    # Region discovery
    # ------------------------------------------------------------------

    def discover_region(self, region_id: str) -> bool:
        """Mark a region as discovered. Returns True if newly discovered."""
        region = self.regions.get(region_id)
        if region is None or region.is_discovered:
            return False
        region.is_discovered = True
        self.event_bus.publish(
            "region_discovered",
            region_id=region_id,
            name=region.name,
        )
        return True

    def get_discovered_regions(self) -> list[Region]:
        """Return all discovered regions."""
        return [r for r in self.regions.values() if r.is_discovered]

    def get_accessible_regions(self, current_region: str) -> list[Region]:
        """Return regions accessible from the current region."""
        region = self.regions.get(current_region)
        if region is None:
            return []
        return [
            self.regions[rid]
            for rid in region.connected_regions
            if rid in self.regions and self.regions[rid].is_accessible
        ]

    def travel_to_region(
        self, game_state: GameStateData, target_region: str,
    ) -> bool:
        """Move player to a new region. Returns True on success."""
        current = self.regions.get(game_state.current_region)
        target = self.regions.get(target_region)
        if current is None or target is None:
            return False
        if not target.is_accessible:
            return False
        if target_region not in current.connected_regions:
            return False

        old_region = game_state.current_region
        game_state.current_region = target_region

        if not target.is_discovered:
            self.discover_region(target_region)

        self.event_bus.publish(
            "region_changed",
            old_region=old_region,
            new_region=target_region,
        )
        return True

    # ------------------------------------------------------------------
    # Points of interest
    # ------------------------------------------------------------------

    def discover_poi(self, poi_id: str) -> bool:
        """Mark a POI as discovered. Returns True if newly discovered."""
        poi = self.points_of_interest.get(poi_id)
        if poi is None or poi.is_discovered:
            return False
        poi.is_discovered = True
        self.event_bus.publish(
            "poi_discovered",
            poi_id=poi_id,
            name=poi.name,
            poi_type=poi.poi_type,
        )
        return True

    def visit_poi(self, game_state: GameStateData, poi_id: str) -> dict | None:
        """Visit a discovered POI and apply rewards. Returns rewards or None."""
        poi = self.points_of_interest.get(poi_id)
        if poi is None or not poi.is_discovered or poi.is_visited:
            return None
        if poi.region != game_state.current_region:
            return None

        poi.is_visited = True

        # Apply rewards
        rewards = dict(poi.rewards)
        if "crystals" in rewards:
            game_state.crystal_inventory += rewards["crystals"]
        if "salvage" in rewards:
            game_state.salvage += rewards["salvage"]

        self.event_bus.publish(
            "poi_visited",
            poi_id=poi_id,
            name=poi.name,
            rewards=rewards,
        )
        return rewards

    def get_region_pois(self, region_id: str, discovered_only: bool = True) -> list[PointOfInterest]:
        """Return POIs in a region."""
        return [
            p for p in self.points_of_interest.values()
            if p.region == region_id and (not discovered_only or p.is_discovered)
        ]

    # ------------------------------------------------------------------
    # Exploration events (procedural)
    # ------------------------------------------------------------------

    def roll_exploration_event(
        self, game_state: GameStateData, rng: random.Random | None = None,
    ) -> dict | None:
        """Roll for a random exploration event based on current region.

        Returns an event dict or None if no event triggers.
        Base trigger chance: 30% per roll, modified by region danger.
        """
        if rng is None:
            rng = random.Random()

        region = self.regions.get(game_state.current_region)
        danger = region.danger_level if region else 1

        # Higher danger = more frequent events
        trigger_chance = 0.2 + (danger * 0.05)
        if rng.random() > trigger_chance:
            return None

        # Weighted random selection
        total_weight = sum(e["weight"] for e in EXPLORATION_EVENTS)
        roll = rng.randint(1, total_weight)
        cumulative = 0
        for event in EXPLORATION_EVENTS:
            cumulative += event["weight"]
            if roll <= cumulative:
                result = {
                    "type": event["type"],
                    "description": event["description"],
                    "region": game_state.current_region,
                    "danger_level": danger,
                }
                self.event_bus.publish("exploration_event", **result)
                return result

        return None

    # ------------------------------------------------------------------
    # Scan / reveal mechanics
    # ------------------------------------------------------------------

    def scan_region(
        self, game_state: GameStateData, rng: random.Random | None = None,
    ) -> list[str]:
        """Scan current region for undiscovered POIs.

        Returns list of newly discovered POI IDs.
        """
        if rng is None:
            rng = random.Random()

        discovered: list[str] = []
        for poi in self.points_of_interest.values():
            if poi.region == game_state.current_region and not poi.is_discovered:
                # Discovery chance based on risk: harder to find dangerous stuff
                chance = max(0.2, 0.8 - poi.risk_level * 0.1)
                if rng.random() < chance:
                    self.discover_poi(poi.poi_id)
                    discovered.append(poi.poi_id)
        return discovered

    # ------------------------------------------------------------------
    # Serialization helpers
    # ------------------------------------------------------------------

    def get_state_dict(self) -> dict:
        """Serialize exploration state for save/load."""
        return {
            "regions": {rid: r.to_dict() for rid, r in self.regions.items()},
            "points_of_interest": {
                pid: p.to_dict() for pid, p in self.points_of_interest.items()
            },
        }

    def load_state_dict(self, data: dict) -> None:
        """Restore exploration state from save data."""
        self.regions = {
            rid: Region.from_dict(rdata)
            for rid, rdata in data.get("regions", {}).items()
        }
        self.points_of_interest = {
            pid: PointOfInterest.from_dict(pdata)
            for pid, pdata in data.get("points_of_interest", {}).items()
        }
