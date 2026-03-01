"""Tests for the crew morale system."""

from __future__ import annotations

import pytest

from whisper_crystals.core.event_bus import EventBus
from whisper_crystals.core.game_state import GameStateData
from whisper_crystals.entities.faction import Faction
from whisper_crystals.entities.ship import CrewMember, Ship, ShipStats
from whisper_crystals.systems.crew_morale import CrewMoraleSystem


@pytest.fixture
def event_bus() -> EventBus:
    return EventBus()


@pytest.fixture
def morale(event_bus: EventBus) -> CrewMoraleSystem:
    return CrewMoraleSystem(event_bus)


@pytest.fixture
def game_state() -> GameStateData:
    state = GameStateData()
    state.player_ship = Ship(
        ship_id="test_ship",
        name="Test Ship",
        faction_id="felid_corsairs",
        ship_class="corsair_raider",
        base_stats=ShipStats(),
        crew=[
            CrewMember(
                crew_id="crew_1", name="Whiskers", species="cat",
                role="pilot", faction_origin="felid_corsairs",
                morale=80,
            ),
            CrewMember(
                crew_id="crew_2", name="Spot", species="dog",
                role="gunner", faction_origin="canis_league",
                morale=60,
            ),
            CrewMember(
                crew_id="crew_3", name="Tinker", species="goblin",
                role="engineer", faction_origin="goblins",
                morale=40,
            ),
        ],
    )
    state.faction_registry = {
        "felid_corsairs": Faction(
            faction_id="felid_corsairs", name="Felid Corsairs",
            species="cat", alignment="chaotic", government="captains",
            reputation_with_player=60,
        ),
        "canis_league": Faction(
            faction_id="canis_league", name="Canis League",
            species="dog", alignment="lawful", government="military",
            reputation_with_player=-60,
        ),
        "goblins": Faction(
            faction_id="goblins", name="Goblins",
            species="goblin", alignment="chaotic", government="guilds",
            reputation_with_player=10,
        ),
    }
    return state


class TestMoraleQueries:
    def test_average_morale(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        avg = morale.get_average_morale(game_state)
        assert avg == 60  # (80 + 60 + 40) / 3

    def test_average_morale_no_crew(self, morale: CrewMoraleSystem) -> None:
        state = GameStateData()
        assert morale.get_average_morale(state) == 100

    def test_morale_status(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        assert morale.get_morale_status(game_state) == "STEADY"

    def test_crew_by_morale(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        crew_list = morale.get_crew_by_morale(game_state)
        assert len(crew_list) == 3
        # Sorted by morale ascending
        assert crew_list[0][0] == "Tinker"
        assert crew_list[0][1] == 40


class TestMoraleChanges:
    def test_change_all_crew(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        morale.change_crew_morale(game_state, -10)
        assert game_state.player_ship.crew[0].morale == 70
        assert game_state.player_ship.crew[1].morale == 50
        assert game_state.player_ship.crew[2].morale == 30

    def test_change_single_crew(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        morale.change_crew_morale(game_state, 15, crew_id="crew_3")
        assert game_state.player_ship.crew[2].morale == 55
        # Others unchanged
        assert game_state.player_ship.crew[0].morale == 80

    def test_morale_clamped_at_0(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        morale.change_crew_morale(game_state, -200)
        for c in game_state.player_ship.crew:
            assert c.morale >= 0

    def test_morale_clamped_at_100(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        morale.change_crew_morale(game_state, 200)
        for c in game_state.player_ship.crew:
            assert c.morale <= 100

    def test_mutiny_event(
        self, morale: CrewMoraleSystem, game_state: GameStateData, event_bus: EventBus,
    ) -> None:
        events: list[dict] = []
        event_bus.subscribe("crew_mutiny_risk", lambda **kw: events.append(kw))
        # Tinker is at 40, drop by 25 to go below 20
        morale.change_crew_morale(game_state, -25, crew_id="crew_3")
        assert len(events) == 1
        assert events[0]["crew_id"] == "crew_3"


class TestCombatModifiers:
    def test_combat_modifier_steady(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        # Average is 60 = STEADY
        assert morale.get_combat_modifier(game_state) == 1.0

    def test_combat_modifier_inspired(self, morale: CrewMoraleSystem) -> None:
        state = GameStateData()
        state.player_ship = Ship(
            ship_id="test", name="Test", faction_id="f", ship_class="c",
            crew=[
                CrewMember(
                    crew_id="c1", name="A", species="cat",
                    role="pilot", faction_origin="f", morale=95,
                ),
            ],
        )
        assert morale.get_combat_modifier(state) == 1.2

    def test_trade_modifier(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        assert morale.get_trade_modifier(game_state) == 1.0


class TestEventDrivenEffects:
    def test_combat_victory_boosts(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        old_avg = morale.get_average_morale(game_state)
        morale.on_combat_victory(game_state)
        assert morale.get_average_morale(game_state) > old_avg

    def test_combat_defeat_reduces(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        old_avg = morale.get_average_morale(game_state)
        morale.on_combat_defeat(game_state)
        assert morale.get_average_morale(game_state) < old_avg


class TestFactionLoyalty:
    def test_check_faction_loyalty(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        # canis_league has rep -60 (hostile)
        conflicts = morale.check_faction_loyalty(game_state)
        assert "crew_2" in conflicts  # Spot is from canis_league
        assert "crew_1" not in conflicts  # Whiskers from felid_corsairs (friendly)

    def test_apply_loyalty_effects(
        self, morale: CrewMoraleSystem, game_state: GameStateData,
    ) -> None:
        old_morale = game_state.player_ship.crew[1].morale
        morale.apply_faction_loyalty_effects(game_state)
        # Spot (canis_league, hostile) should lose morale
        assert game_state.player_ship.crew[1].morale < old_morale
