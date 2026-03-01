"""Tests for faction conquest AI and realm control systems."""

from __future__ import annotations

import random

import pytest

from whisper_crystals.core.event_bus import EventBus
from whisper_crystals.core.game_state import GameStateData
from whisper_crystals.entities.faction import Faction
from whisper_crystals.systems.faction_conquest import ConquestAction, FactionConquestAI
from whisper_crystals.systems.realm_control import RealmControlSystem, RealmState


def _make_faction(
    faction_id: str,
    name: str,
    realm: str = "",
    military: int = 50,
    aggression: int = 20,
    political: int = 30,
    tactical: int = 40,
    stability: int = 80,
    crystals: int = 50,
    conquest_intent: int = 50,
) -> Faction:
    return Faction(
        faction_id=faction_id,
        name=name,
        species="test",
        alignment="neutral",
        government="council",
        realm=realm,
        military_strength=military,
        aggression_level=aggression,
        political_influence=political,
        tactical_rating=tactical,
        internal_stability=stability,
        crystal_reserves=crystals,
        conquest_intent=conquest_intent,
    )


@pytest.fixture
def event_bus() -> EventBus:
    return EventBus()


@pytest.fixture
def game_state() -> GameStateData:
    state = GameStateData()
    state.faction_registry = {
        "felid_corsairs": _make_faction(
            "felid_corsairs", "Felid Corsairs", "feline_courts",
            military=50, conquest_intent=40,
        ),
        "canis_league": _make_faction(
            "canis_league", "Canis League", "canine_order",
            military=75, aggression=40, conquest_intent=70,
        ),
        "wolves": _make_faction(
            "wolves", "Wolves", "canine_order",
            military=90, aggression=50, conquest_intent=85, tactical=95,
        ),
        "fairies": _make_faction(
            "fairies", "Fairies", "fairy_realms",
            military=15, political=50, conquest_intent=25,
        ),
    }
    state.relationship_matrix = {
        "felid_corsairs": {"canis_league": -20, "wolves": -30, "fairies": 15},
        "canis_league": {"felid_corsairs": -20, "wolves": 40, "fairies": 0},
        "wolves": {"felid_corsairs": -30, "canis_league": 40, "fairies": -10},
        "fairies": {"felid_corsairs": 15, "canis_league": 0, "wolves": -10},
    }
    return state


# ---- Faction Conquest AI ----

class TestFactionConquestAI:
    def test_plan_actions_generates_actions(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        ai = FactionConquestAI(event_bus)
        rng = random.Random(42)
        actions = ai.plan_faction_actions(game_state, rng)
        # With seed 42, at least some factions should act
        assert isinstance(actions, list)
        # Player faction should never auto-act
        for a in actions:
            assert a.aggressor_id != "felid_corsairs"

    def test_resolve_attack(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        ai = FactionConquestAI(event_bus)
        # Wolves attack fairies (90 military vs 15)
        action = ConquestAction(
            action_id="test_attack",
            aggressor_id="wolves",
            target_id="fairies",
            action_type="attack",
            strength=90,
        )
        ai.pending_actions.append(action)

        events: list[dict] = []
        event_bus.subscribe("faction_conflict", lambda **kw: events.append(kw))

        resolved = ai.resolve_actions(game_state)
        assert len(resolved) == 1
        assert resolved[0].outcome == "victory"
        assert len(events) == 1

    def test_resolve_attack_repelled(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        ai = FactionConquestAI(event_bus)
        # Fairies attack wolves (15 military vs 90) - should be repelled
        action = ConquestAction(
            action_id="test_repelled",
            aggressor_id="fairies",
            target_id="wolves",
            action_type="attack",
            strength=15,
        )
        ai.pending_actions.append(action)
        resolved = ai.resolve_actions(game_state)
        assert resolved[0].outcome == "repelled"

    def test_resolve_blockade(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        ai = FactionConquestAI(event_bus)
        action = ConquestAction(
            action_id="test_blockade",
            aggressor_id="canis_league",
            target_id="felid_corsairs",
            action_type="blockade",
            strength=75,
        )
        ai.pending_actions.append(action)
        resolved = ai.resolve_actions(game_state)
        assert resolved[0].outcome == "blockade_effective"

    def test_resolve_diplomacy(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        ai = FactionConquestAI(event_bus)
        action = ConquestAction(
            action_id="test_diplo",
            aggressor_id="fairies",
            target_id="canis_league",
            action_type="diplomacy",
            strength=0,
        )
        ai.pending_actions.append(action)
        resolved = ai.resolve_actions(game_state)
        assert resolved[0].outcome == "improved_relations"

    def test_resolve_fortify(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        ai = FactionConquestAI(event_bus)
        old_military = game_state.faction_registry["canis_league"].military_strength
        action = ConquestAction(
            action_id="test_fortify",
            aggressor_id="canis_league",
            target_id="canis_league",
            action_type="fortify",
            strength=0,
        )
        ai.pending_actions.append(action)
        ai.resolve_actions(game_state)
        assert game_state.faction_registry["canis_league"].military_strength > old_military

    def test_power_rankings(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        ai = FactionConquestAI(event_bus)
        rankings = ai.get_power_rankings(game_state)
        assert len(rankings) == 4
        # Wolves should be #1 (highest military + tactical)
        assert rankings[0]["faction_id"] == "wolves"

    def test_conquest_action_serialization(self) -> None:
        action = ConquestAction(
            action_id="test", aggressor_id="a", target_id="b",
            action_type="attack", strength=50, outcome="victory",
        )
        restored = ConquestAction.from_dict(action.to_dict())
        assert restored.action_id == "test"
        assert restored.outcome == "victory"


# ---- Realm Control ----

class TestRealmControl:
    def test_initialize_realms(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        rc = RealmControlSystem(event_bus)
        rc.initialize_realms(game_state)
        assert "feline_courts" in rc.realm_states
        assert "canine_order" in rc.realm_states
        # Feline courts should be controlled by felid_corsairs
        assert rc.realm_states["feline_courts"].controlling_faction == "felid_corsairs"

    def test_canine_order_contested(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        rc = RealmControlSystem(event_bus)
        rc.initialize_realms(game_state)
        # canine_order has both canis_league and wolves
        state = rc.realm_states["canine_order"]
        assert "canis_league" in state.faction_influence
        assert "wolves" in state.faction_influence

    def test_add_influence(self, event_bus: EventBus) -> None:
        rc = RealmControlSystem(event_bus)
        rc.realm_states["test"] = RealmState(
            region_id="test",
            controlling_faction="a",
            faction_influence={"a": 60.0, "b": 30.0},
        )
        rc.add_influence("test", "b", 40.0)
        assert rc.realm_states["test"].faction_influence["b"] == 70.0

    def test_control_changes_on_influence_shift(
        self, event_bus: EventBus,
    ) -> None:
        events: list[dict] = []
        event_bus.subscribe("realm_control_changed", lambda **kw: events.append(kw))

        rc = RealmControlSystem(event_bus)
        rc.realm_states["test"] = RealmState(
            region_id="test",
            controlling_faction="a",
            faction_influence={"a": 50.0, "b": 45.0},
        )
        rc.add_influence("test", "b", 20.0)
        assert rc.realm_states["test"].controlling_faction == "b"
        assert len(events) == 1
        assert events[0]["new_controller"] == "b"

    def test_get_faction_territories(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        rc = RealmControlSystem(event_bus)
        rc.initialize_realms(game_state)
        territories = rc.get_faction_territories("felid_corsairs")
        assert "feline_courts" in territories

    def test_is_contested(self, event_bus: EventBus) -> None:
        rc = RealmControlSystem(event_bus)
        rc.realm_states["test"] = RealmState(
            region_id="test",
            faction_influence={"a": 50.0, "b": 48.0},
        )
        rc._recalculate_control(rc.realm_states["test"])
        assert rc.is_contested("test")

    def test_apply_conflict_result(self, event_bus: EventBus) -> None:
        rc = RealmControlSystem(event_bus)
        rc.realm_states["test"] = RealmState(
            region_id="test",
            controlling_faction="a",
            faction_influence={"a": 60.0, "b": 40.0},
        )
        rc.apply_conflict_result("test", "b", "a", intensity=30.0)
        # b gains 30, a loses 21
        assert rc.realm_states["test"].faction_influence["b"] == 70.0
        assert rc.realm_states["test"].faction_influence["a"] == 39.0

    def test_realm_overview(
        self, event_bus: EventBus, game_state: GameStateData,
    ) -> None:
        rc = RealmControlSystem(event_bus)
        rc.initialize_realms(game_state)
        overview = rc.get_realm_overview()
        assert len(overview) > 0
        assert all("region_id" in r for r in overview)

    def test_serialization_round_trip(self, event_bus: EventBus) -> None:
        rc = RealmControlSystem(event_bus)
        rc.realm_states["test"] = RealmState(
            region_id="test",
            controlling_faction="a",
            faction_influence={"a": 60.0, "b": 30.0},
            contested=False,
        )
        data = rc.get_state_dict()
        rc2 = RealmControlSystem(event_bus)
        rc2.load_state_dict(data)
        assert "test" in rc2.realm_states
        assert rc2.realm_states["test"].controlling_faction == "a"
