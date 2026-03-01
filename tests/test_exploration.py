"""Tests for the exploration system — regions, POIs, events."""

from __future__ import annotations

import random

import pytest

from whisper_crystals.core.event_bus import EventBus
from whisper_crystals.core.game_state import GameStateData
from whisper_crystals.systems.exploration import (
    ExplorationSystem,
    PointOfInterest,
    Region,
)


@pytest.fixture
def event_bus() -> EventBus:
    return EventBus()


@pytest.fixture
def exploration(event_bus: EventBus) -> ExplorationSystem:
    system = ExplorationSystem(event_bus)
    system.load_regions([
        {
            "region_id": "starting_realm",
            "name": "The Fringe",
            "controlling_faction": "felid_corsairs",
            "danger_level": 1,
            "is_discovered": True,
            "is_accessible": True,
            "connected_regions": ["feline_courts", "goblin_warrens"],
        },
        {
            "region_id": "feline_courts",
            "name": "Feline Courts",
            "danger_level": 1,
            "is_discovered": False,
            "is_accessible": True,
            "connected_regions": ["starting_realm"],
        },
        {
            "region_id": "goblin_warrens",
            "name": "Goblin Warrens",
            "danger_level": 2,
            "is_discovered": True,
            "is_accessible": True,
            "connected_regions": ["starting_realm"],
        },
        {
            "region_id": "deep_space",
            "name": "Deep Space",
            "danger_level": 5,
            "is_discovered": False,
            "is_accessible": False,
            "connected_regions": [],
        },
    ])
    system.load_pois([
        {
            "poi_id": "wreck_01",
            "region": "starting_realm",
            "name": "Derelict Freighter",
            "poi_type": "wreck",
            "is_discovered": True,
            "is_visited": False,
            "rewards": {"salvage": 50},
            "risk_level": 1,
        },
        {
            "poi_id": "hidden_cave",
            "region": "starting_realm",
            "name": "Hidden Cave",
            "poi_type": "deposit",
            "is_discovered": False,
            "is_visited": False,
            "rewards": {"crystals": 20},
            "risk_level": 2,
        },
        {
            "poi_id": "goblin_market",
            "region": "goblin_warrens",
            "name": "Black Market",
            "poi_type": "settlement",
            "is_discovered": True,
            "is_visited": False,
            "rewards": {"salvage": 30},
            "risk_level": 3,
        },
    ])
    return system


@pytest.fixture
def game_state() -> GameStateData:
    state = GameStateData()
    state.current_region = "starting_realm"
    state.crystal_inventory = 5
    state.salvage = 100
    return state


class TestRegionDiscovery:
    def test_discover_region(
        self, exploration: ExplorationSystem, event_bus: EventBus,
    ) -> None:
        events: list[str] = []
        event_bus.subscribe("region_discovered", lambda **kw: events.append(kw["region_id"]))
        assert exploration.discover_region("feline_courts")
        assert exploration.regions["feline_courts"].is_discovered
        assert "feline_courts" in events

    def test_discover_already_discovered(self, exploration: ExplorationSystem) -> None:
        assert not exploration.discover_region("starting_realm")

    def test_get_discovered_regions(self, exploration: ExplorationSystem) -> None:
        discovered = exploration.get_discovered_regions()
        ids = {r.region_id for r in discovered}
        assert "starting_realm" in ids
        assert "goblin_warrens" in ids
        assert "feline_courts" not in ids

    def test_get_accessible_regions(self, exploration: ExplorationSystem) -> None:
        accessible = exploration.get_accessible_regions("starting_realm")
        ids = {r.region_id for r in accessible}
        assert "feline_courts" in ids
        assert "goblin_warrens" in ids


class TestTravel:
    def test_travel_to_connected_region(
        self, exploration: ExplorationSystem, game_state: GameStateData,
    ) -> None:
        assert exploration.travel_to_region(game_state, "feline_courts")
        assert game_state.current_region == "feline_courts"
        # Auto-discover on travel
        assert exploration.regions["feline_courts"].is_discovered

    def test_travel_to_inaccessible_fails(
        self, exploration: ExplorationSystem, game_state: GameStateData,
    ) -> None:
        assert not exploration.travel_to_region(game_state, "deep_space")

    def test_travel_to_unconnected_fails(
        self, exploration: ExplorationSystem, game_state: GameStateData,
    ) -> None:
        # goblin_warrens is not connected to feline_courts directly in fixture
        game_state.current_region = "feline_courts"
        assert not exploration.travel_to_region(game_state, "goblin_warrens")


class TestPointsOfInterest:
    def test_discover_poi(
        self, exploration: ExplorationSystem, event_bus: EventBus,
    ) -> None:
        events: list[str] = []
        event_bus.subscribe("poi_discovered", lambda **kw: events.append(kw["poi_id"]))
        assert exploration.discover_poi("hidden_cave")
        assert exploration.points_of_interest["hidden_cave"].is_discovered
        assert "hidden_cave" in events

    def test_discover_already_discovered_poi(self, exploration: ExplorationSystem) -> None:
        assert not exploration.discover_poi("wreck_01")

    def test_visit_poi(
        self, exploration: ExplorationSystem, game_state: GameStateData,
    ) -> None:
        rewards = exploration.visit_poi(game_state, "wreck_01")
        assert rewards is not None
        assert rewards["salvage"] == 50
        assert game_state.salvage == 150
        assert exploration.points_of_interest["wreck_01"].is_visited

    def test_visit_already_visited(
        self, exploration: ExplorationSystem, game_state: GameStateData,
    ) -> None:
        exploration.visit_poi(game_state, "wreck_01")
        assert exploration.visit_poi(game_state, "wreck_01") is None

    def test_visit_wrong_region(
        self, exploration: ExplorationSystem, game_state: GameStateData,
    ) -> None:
        # goblin_market is in goblin_warrens, player is in starting_realm
        assert exploration.visit_poi(game_state, "goblin_market") is None

    def test_visit_undiscovered_poi(
        self, exploration: ExplorationSystem, game_state: GameStateData,
    ) -> None:
        assert exploration.visit_poi(game_state, "hidden_cave") is None

    def test_get_region_pois(self, exploration: ExplorationSystem) -> None:
        pois = exploration.get_region_pois("starting_realm", discovered_only=True)
        ids = {p.poi_id for p in pois}
        assert "wreck_01" in ids
        assert "hidden_cave" not in ids  # not discovered

        all_pois = exploration.get_region_pois("starting_realm", discovered_only=False)
        all_ids = {p.poi_id for p in all_pois}
        assert "hidden_cave" in all_ids


class TestExplorationEvents:
    def test_roll_event_with_seed(
        self, exploration: ExplorationSystem, game_state: GameStateData,
    ) -> None:
        rng = random.Random(42)
        # Run several rolls to get at least one event
        events = []
        for _ in range(20):
            event = exploration.roll_exploration_event(game_state, rng)
            if event is not None:
                events.append(event)
        assert len(events) > 0
        assert all("type" in e for e in events)

    def test_scan_region(
        self, exploration: ExplorationSystem, game_state: GameStateData,
    ) -> None:
        rng = random.Random(42)
        discovered = exploration.scan_region(game_state, rng)
        # hidden_cave should be in starting_realm and may be found
        # With seed 42 and 80% chance (risk=2: 0.8 - 0.2 = 0.6), likely found
        assert isinstance(discovered, list)


class TestSerialization:
    def test_region_round_trip(self) -> None:
        region = Region(
            region_id="test", name="Test", danger_level=3,
            connected_regions=["a", "b"],
        )
        restored = Region.from_dict(region.to_dict())
        assert restored.region_id == "test"
        assert restored.connected_regions == ["a", "b"]

    def test_poi_round_trip(self) -> None:
        poi = PointOfInterest(
            poi_id="test", region="r", name="Test", poi_type="wreck",
            rewards={"salvage": 10},
        )
        restored = PointOfInterest.from_dict(poi.to_dict())
        assert restored.poi_id == "test"
        assert restored.rewards == {"salvage": 10}

    def test_exploration_state_round_trip(self, exploration: ExplorationSystem) -> None:
        data = exploration.get_state_dict()
        new_system = ExplorationSystem(EventBus())
        new_system.load_state_dict(data)
        assert len(new_system.regions) == len(exploration.regions)
        assert len(new_system.points_of_interest) == len(exploration.points_of_interest)
