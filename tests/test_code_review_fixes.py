"""Tests for code review fixes — BUG-1 through BUG-6, R-1 through R-5."""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest

from whisper_crystals.core.event_bus import EventBus
from whisper_crystals.core.game_state import GameStateData
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType
from whisper_crystals.entities.crystal import CrystalMarket
from whisper_crystals.entities.encounter import EncounterChoice, EncounterOutcome, Encounter
from whisper_crystals.entities.faction import Faction
from whisper_crystals.entities.ship import CrewMember, Ship, ShipStats, ShipUpgrade
from whisper_crystals.systems.crew_morale import CrewMoraleSystem, _morale_label
from whisper_crystals.systems.economy import EconomySystem, _VALID_UPGRADE_STATS
from whisper_crystals.systems.encounter_engine import EncounterEngine


# ---- Helpers ----

class DummyState(GameState):
    """Minimal GameState for testing the state machine."""

    state_type = GameStateType.MENU

    def __init__(self, machine: GameStateMachine, name: str = "") -> None:
        super().__init__(machine)
        self.name = name
        self.entered = False
        self.exited = False

    def enter(self) -> None:
        self.entered = True

    def exit(self) -> None:
        self.exited = True

    def handle_input(self, actions: list) -> None:
        pass

    def update(self, dt: float) -> None:
        pass

    def render(self, renderer) -> None:
        pass


# ---- BUG-1: Shadow DataLoader fixed ----

class TestEconomyDataLoaderInjection:
    """Verify EconomySystem uses injected DataLoader, not a shadow one."""

    def test_purchase_upgrade_uses_injected_loader(self) -> None:
        event_bus = EventBus()
        mock_loader = MagicMock()
        mock_loader.load_upgrades.return_value = [
            {
                "upgrade_id": "speed_boost",
                "name": "Speed Boost",
                "target_stat": "speed",
                "modifier": 2,
                "cost_crystals": 5,
                "cost_salvage": 10,
            }
        ]
        economy = EconomySystem(event_bus, data_loader=mock_loader)

        state = GameStateData()
        state.crystal_inventory = 20
        state.salvage = 100
        state.player_ship = Ship(
            ship_id="test", name="Test", faction_id="f", ship_class="c",
            base_stats=ShipStats(speed=5),
        )

        result = economy.purchase_upgrade(state, "speed_boost")
        assert result is True
        mock_loader.load_upgrades.assert_called_once()
        assert state.player_ship.base_stats.speed == 7

    def test_purchase_upgrade_fails_without_loader(self) -> None:
        economy = EconomySystem(EventBus())
        state = GameStateData()
        assert economy.purchase_upgrade(state, "anything") is False

    def test_purchase_ship_uses_injected_loader(self) -> None:
        event_bus = EventBus()
        mock_loader = MagicMock()
        mock_loader.load_ship_templates.return_value = {
            "new_ship": {
                "template_id": "new_ship",
                "name": "New Ship",
                "faction_id": "felid_corsairs",
                "base_stats": {"speed": 6, "armour": 6, "firepower": 6,
                               "crystal_capacity": 6, "crew_capacity": 6},
                "max_hull": 120,
            }
        }
        economy = EconomySystem(event_bus, data_loader=mock_loader)

        state = GameStateData()
        state.salvage = 5000
        state.crystal_inventory = 0
        state.player_ship = Ship(
            ship_id="old", name="Old Ship", faction_id="felid_corsairs",
            ship_class="c", base_stats=ShipStats(), current_hull=80, max_hull=100,
        )
        state.faction_registry = {
            "felid_corsairs": Faction(
                faction_id="felid_corsairs", name="Felid Corsairs",
                species="cat", alignment="chaotic", government="captains",
                reputation_with_player=60,
            ),
        }

        result = economy.purchase_ship(state, "new_ship")
        assert result is True
        mock_loader.load_ship_templates.assert_called_once()
        assert state.player_ship.name == "New Ship"

    def test_purchase_ship_fails_without_loader(self) -> None:
        economy = EconomySystem(EventBus())
        state = GameStateData()
        assert economy.purchase_ship(state, "anything") is False


# ---- R-5: target_stat validation ----

class TestTargetStatValidation:
    """Verify setattr is guarded against invalid target_stat values."""

    def test_valid_upgrade_stats_contains_expected_fields(self) -> None:
        expected = {"speed", "armour", "firepower", "crystal_capacity", "crew_capacity"}
        assert _VALID_UPGRADE_STATS == expected

    def test_invalid_target_stat_rejected(self) -> None:
        event_bus = EventBus()
        mock_loader = MagicMock()
        mock_loader.load_upgrades.return_value = [
            {
                "upgrade_id": "bad_upgrade",
                "name": "Bad Upgrade",
                "target_stat": "__class__",  # malicious
                "modifier": 1,
                "cost_crystals": 0,
                "cost_salvage": 0,
            }
        ]
        economy = EconomySystem(event_bus, data_loader=mock_loader)
        state = GameStateData()
        state.crystal_inventory = 100
        state.salvage = 100

        result = economy.purchase_upgrade(state, "bad_upgrade")
        assert result is False


# ---- BUG-3: morale_modifier scaling ----

class TestMoraleModifierScaling:
    """Verify morale_modifier scales delta rather than being added flat."""

    def test_zero_modifier_no_effect(self) -> None:
        system = CrewMoraleSystem(EventBus())
        state = GameStateData()
        state.player_ship = Ship(
            ship_id="t", name="T", faction_id="f", ship_class="c",
            crew=[CrewMember(
                crew_id="c1", name="A", species="cat",
                role="pilot", faction_origin="f", morale=50,
                morale_modifier=0,
            )],
        )
        system.change_crew_morale(state, 10)
        assert state.player_ship.crew[0].morale == 60

    def test_positive_modifier_amplifies_positive_delta(self) -> None:
        system = CrewMoraleSystem(EventBus())
        state = GameStateData()
        state.player_ship = Ship(
            ship_id="t", name="T", faction_id="f", ship_class="c",
            crew=[CrewMember(
                crew_id="c1", name="A", species="cat",
                role="pilot", faction_origin="f", morale=50,
                morale_modifier=5,  # +50% scaling
            )],
        )
        system.change_crew_morale(state, 10)
        # effective_delta = int(10 * (1 + 5/10)) = int(10 * 1.5) = 15
        assert state.player_ship.crew[0].morale == 65

    def test_negative_modifier_dampens_positive_delta(self) -> None:
        system = CrewMoraleSystem(EventBus())
        state = GameStateData()
        state.player_ship = Ship(
            ship_id="t", name="T", faction_id="f", ship_class="c",
            crew=[CrewMember(
                crew_id="c1", name="A", species="cat",
                role="pilot", faction_origin="f", morale=50,
                morale_modifier=-5,  # -50% scaling
            )],
        )
        system.change_crew_morale(state, 10)
        # effective_delta = int(10 * (1 + -5/10)) = int(10 * 0.5) = 5
        assert state.player_ship.crew[0].morale == 55

    def test_modifier_does_not_drift_on_idle(self) -> None:
        """The old bug: morale_modifier was added every tick, causing drift."""
        system = CrewMoraleSystem(EventBus())
        state = GameStateData()
        state.player_ship = Ship(
            ship_id="t", name="T", faction_id="f", ship_class="c",
            crew=[CrewMember(
                crew_id="c1", name="A", species="cat",
                role="pilot", faction_origin="f", morale=50,
                morale_modifier=5,
            )],
        )
        # Simulate 10 idle ticks (delta=-1 each)
        for _ in range(10):
            system.on_idle_tick(state)
        # With old bug: morale would gain +5 per tick = 50 + 10*(-1+5) = 90
        # With fix: effective_delta = int(-1 * 1.5) = -1; morale = 50 - 10 = 40
        assert state.player_ship.crew[0].morale == 40


# ---- R-1: _morale_label helper ----

class TestMoraleLabel:
    def test_mutiny(self) -> None:
        assert _morale_label(20) == "MUTINY"
        assert _morale_label(0) == "MUTINY"

    def test_disgruntled(self) -> None:
        assert _morale_label(21) == "DISGRUNTLED"
        assert _morale_label(40) == "DISGRUNTLED"

    def test_steady(self) -> None:
        assert _morale_label(41) == "STEADY"
        assert _morale_label(60) == "STEADY"

    def test_content(self) -> None:
        assert _morale_label(61) == "CONTENT"
        assert _morale_label(80) == "CONTENT"

    def test_inspired(self) -> None:
        assert _morale_label(81) == "INSPIRED"
        assert _morale_label(100) == "INSPIRED"


# ---- BUG-2: completed_encounters guard ----

class TestCompletedEncountersGuard:
    def test_no_duplicate_encounter_ids(self) -> None:
        event_bus = EventBus()
        data_loader = MagicMock()
        engine = EncounterEngine(data_loader, event_bus)

        encounter = Encounter(
            encounter_id="enc_1",
            encounter_type="combat",
            arc_id="arc_1",
            title="Test",
            description="Test",
            location="test_realm",
            trigger_conditions={"current_arc": "arc_1"},
            choices=[
                EncounterChoice(
                    choice_id="c1",
                    text="Do it",
                    outcome=EncounterOutcome(description="Done"),
                    outcome_weight=1.0,
                )
            ],
            priority=1,
            repeatable=True,
        )

        state = GameStateData()
        state.current_arc = "arc_1"

        # Resolve the same encounter twice
        engine.apply_choice_outcome(state, encounter, 0)
        engine.apply_choice_outcome(state, encounter, 0)

        # Should only appear once
        assert state.completed_encounters.count("enc_1") == 1


# ---- R-2: Deduplicated encounter filtering ----

class TestEncounterDeduplication:
    def test_check_triggers_returns_first(self) -> None:
        engine = EncounterEngine(MagicMock(), EventBus())
        engine.encounter_table = [
            Encounter(
                encounter_id="low", encounter_type="combat", arc_id="arc_1",
                title="Low", description="", location="",
                trigger_conditions={"current_arc": "arc_1"},
                choices=[], priority=1,
            ),
            Encounter(
                encounter_id="high", encounter_type="combat", arc_id="arc_1",
                title="High", description="", location="",
                trigger_conditions={"current_arc": "arc_1"},
                choices=[], priority=10,
            ),
        ]
        state = GameStateData()
        state.current_arc = "arc_1"
        result = engine.check_triggers(state)
        assert result is not None
        assert result.encounter_id == "high"

    def test_get_available_returns_all(self) -> None:
        engine = EncounterEngine(MagicMock(), EventBus())
        engine.encounter_table = [
            Encounter(
                encounter_id="a", encounter_type="combat", arc_id="arc_1",
                title="A", description="", location="",
                trigger_conditions={"current_arc": "arc_1"},
                choices=[], priority=1,
            ),
            Encounter(
                encounter_id="b", encounter_type="combat", arc_id="arc_1",
                title="B", description="", location="",
                trigger_conditions={"current_arc": "arc_1"},
                choices=[], priority=5,
            ),
        ]
        state = GameStateData()
        state.current_arc = "arc_1"
        available = engine.get_available_encounters(state)
        assert len(available) == 2
        # Should be sorted by priority descending
        assert available[0].encounter_id == "b"


# ---- R-3: GameStateMachine.clear() ----

class TestStateMachineClear:
    def test_clear_empty_stack(self) -> None:
        machine = GameStateMachine()
        machine.clear()  # Should not raise
        assert machine.is_empty

    def test_clear_single_state(self) -> None:
        machine = GameStateMachine()
        state = DummyState(machine, "only")
        machine.push(state)
        machine.clear()
        assert machine.is_empty
        assert state.exited

    def test_clear_multiple_states_only_top_exits(self) -> None:
        machine = GameStateMachine()
        bottom = DummyState(machine, "bottom")
        middle = DummyState(machine, "middle")
        top = DummyState(machine, "top")

        machine.push(bottom)
        machine.push(middle)
        machine.push(top)

        # Reset exit flags (push calls exit on states below)
        bottom.exited = False
        middle.exited = False
        top.exited = False

        machine.clear()
        assert machine.is_empty
        assert top.exited
        # Bottom and middle should NOT get exit() called during clear
        assert not bottom.exited
        assert not middle.exited


# ---- R-4: EventBus error resilience ----

class TestEventBusErrorResilience:
    def test_failing_subscriber_does_not_block_others(self) -> None:
        bus = EventBus()
        results = []

        bus.subscribe("test_event", lambda: (_ for _ in ()).throw(ValueError("boom")))
        bus.subscribe("test_event", lambda: results.append("ok"))

        # Should not raise
        bus.publish("test_event")
        assert "ok" in results

    def test_failing_subscriber_with_kwargs(self) -> None:
        bus = EventBus()
        results = []

        def bad_handler(**kwargs):
            raise RuntimeError("crash")

        def good_handler(**kwargs):
            results.append(kwargs.get("value"))

        bus.subscribe("evt", bad_handler)
        bus.subscribe("evt", good_handler)
        bus.publish("evt", value=42)
        assert results == [42]


# ---- BUG-6: EventBus import in menu.py ----

class TestMenuEventBusImport:
    def test_event_bus_in_type_checking_block(self) -> None:
        """Verify EventBus is listed in menu.py's TYPE_CHECKING imports."""
        import ast
        import inspect
        from whisper_crystals.ui import menu

        source = inspect.getsource(menu)
        tree = ast.parse(source)
        # Check that EventBus appears in an import statement
        imports = [
            node for node in ast.walk(tree)
            if isinstance(node, (ast.Import, ast.ImportFrom))
        ]
        imported_names = []
        for imp in imports:
            if isinstance(imp, ast.ImportFrom):
                imported_names.extend(alias.name for alias in imp.names)
            else:
                imported_names.extend(alias.name for alias in imp.names)
        assert "EventBus" in imported_names
