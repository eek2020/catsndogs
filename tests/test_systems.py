"""Tests for encounter engine, narrative system, faction system, and combat."""

import os

from whisper_crystals.core.data_loader import DataLoader
from whisper_crystals.core.event_bus import EventBus
from whisper_crystals.core.game_state import create_new_game_state
from whisper_crystals.entities.faction import DiplomaticState
from whisper_crystals.systems.combat import CombatShip, calculate_damage, dodge_chance
from whisper_crystals.systems.encounter_engine import EncounterEngine
from whisper_crystals.systems.faction_system import FactionSystem
from whisper_crystals.systems.narrative import NarrativeSystem

DATA_ROOT = os.path.join(os.path.dirname(__file__), "..", "data")


class TestEncounterEngine:
    def setup_method(self):
        self.loader = DataLoader(data_root=DATA_ROOT)
        self.bus = EventBus()
        self.engine = EncounterEngine(self.loader, self.bus)
        self.state = create_new_game_state(self.loader)
        self.engine.load_encounters("arc1")

    def test_first_trigger_crystal_discovery(self):
        enc = self.engine.check_triggers(self.state)
        assert enc is not None
        assert enc.encounter_id == "enc_arc1_crystal_discovery"

    def test_apply_choice_outcome_sets_flags(self):
        enc = self.engine.check_triggers(self.state)
        desc = self.engine.apply_choice_outcome(self.state, enc, 0)
        assert self.state.story_flags["arc1_crystal_discovered"] is True
        assert self.state.crystal_inventory == 10
        assert len(self.state.player_decisions) == 1
        assert "enc_arc1_crystal_discovery" in self.state.completed_encounters
        assert desc != ""

    def test_encounter_chain_arc1(self):
        # Trigger and resolve crystal discovery
        enc = self.engine.check_triggers(self.state)
        assert enc.encounter_id == "enc_arc1_crystal_discovery"
        self.engine.apply_choice_outcome(self.state, enc, 0)

        # Next should be pirate skirmish (priority 3, repeatable, needs crystal_discovered)
        # or dave_trade (priority 8, needs crystal_discovered, dave_met=false)
        enc2 = self.engine.check_triggers(self.state)
        assert enc2 is not None
        assert enc2.encounter_id == "enc_arc1_dave_trade"  # higher priority

    def test_completed_encounters_not_retriggered(self):
        enc = self.engine.check_triggers(self.state)
        self.engine.apply_choice_outcome(self.state, enc, 0)
        # Crystal discovery is non-repeatable, so next trigger should be different
        enc2 = self.engine.check_triggers(self.state)
        assert enc2.encounter_id != "enc_arc1_crystal_discovery"


class TestNarrativeSystem:
    def setup_method(self):
        self.loader = DataLoader(data_root=DATA_ROOT)
        self.bus = EventBus()
        self.narrative = NarrativeSystem(self.loader, self.bus)
        self.state = create_new_game_state(self.loader)
        self.narrative.load()

    def test_arc_exit_not_met_initially(self):
        assert self.narrative.check_arc_exit(self.state) is False

    def test_arc_exit_met(self):
        self.state.story_flags["arc1_crystal_discovered"] = True
        self.state.story_flags["arc1_dave_met"] = True
        self.state.story_flags["arc1_death_glimpsed"] = True
        assert self.narrative.check_arc_exit(self.state) is True

    def test_advance_arc(self):
        self.state.story_flags["arc1_crystal_discovered"] = True
        self.state.story_flags["arc1_dave_met"] = True
        self.state.story_flags["arc1_death_glimpsed"] = True
        new_arc = self.narrative.advance_arc(self.state)
        assert new_arc == "arc_2"
        assert self.state.current_arc == "arc_2"

    def test_arc_progress_tracking(self):
        progress = self.narrative.get_arc_progress(self.state)
        assert progress["arc1_crystal_discovered"] is False
        assert progress["arc1_dave_met"] is False
        assert progress["arc1_death_glimpsed"] is False

        self.state.story_flags["arc1_crystal_discovered"] = True
        progress = self.narrative.get_arc_progress(self.state)
        assert progress["arc1_crystal_discovered"] is True

    def test_get_arc_title(self):
        assert self.narrative.get_arc_title("arc_1") == "The Upstart"
        assert self.narrative.get_arc_title("arc_2") == "The Squeeze"


class TestFactionSystem:
    def setup_method(self):
        self.bus = EventBus()
        self.loader = DataLoader(data_root=DATA_ROOT)
        self.faction_sys = FactionSystem(self.bus)
        self.state = create_new_game_state(self.loader)

    def test_change_reputation(self):
        old_rep = self.state.faction_registry["canis_league"].reputation_with_player
        self.faction_sys.change_reputation(self.state, "canis_league", 20, apply_cascade=False)
        new_rep = self.state.faction_registry["canis_league"].reputation_with_player
        assert new_rep == old_rep + 20

    def test_reputation_clamped(self):
        self.faction_sys.change_reputation(self.state, "canis_league", 200, apply_cascade=False)
        assert self.state.faction_registry["canis_league"].reputation_with_player == 100

    def test_diplomatic_state_updates(self):
        self.faction_sys.change_reputation(self.state, "canis_league", -100, apply_cascade=False)
        assert self.state.faction_registry["canis_league"].diplomatic_state == DiplomaticState.HOSTILE

    def test_cascade_rules(self):
        # Cascades are loaded from data; check they apply
        events_fired = []
        self.bus.subscribe("faction_score_changed", lambda **kw: events_fired.append(kw))
        self.faction_sys.change_reputation(self.state, "canis_league", 20, apply_cascade=True)
        # Should fire at least for canis_league, possibly cascaded factions
        assert len(events_fired) >= 1

    def test_get_all_standings(self):
        standings = self.faction_sys.get_all_standings(self.state)
        assert len(standings) == 8
        # Felid corsairs should be first (player's faction)
        assert standings[0]["faction_id"] == "felid_corsairs"


class TestCombat:
    def test_calculate_damage_minimum(self):
        # Firepower 1 vs armour 10 → min 1
        dmg = calculate_damage(1, 10)
        assert dmg >= 1

    def test_calculate_damage_normal(self):
        # Firepower 10 vs armour 3 → ~7 ± variance
        damages = [calculate_damage(10, 3) for _ in range(50)]
        assert all(d >= 1 for d in damages)
        avg = sum(damages) / len(damages)
        assert 5 <= avg <= 9  # ~7 with variance

    def test_dodge_chance_scaling(self):
        assert dodge_chance(0) == 0.0
        assert 0.0 < dodge_chance(5) < 0.35
        assert dodge_chance(10) == 0.30
        assert dodge_chance(20) == 0.35  # capped

    def test_combat_ship_from_template(self):
        template = {
            "base_stats": {"speed": 6, "armour": 7, "firepower": 6},
            "max_hull": 120,
        }
        ship = CombatShip.from_template(template, "Test Ship", "canis_league")
        assert ship.speed == 6
        assert ship.armour == 7
        assert ship.max_hull == 120
        assert ship.current_hull == 120


class TestEventBus:
    def test_publish_subscribe(self):
        bus = EventBus()
        received = []
        bus.subscribe("test_event", lambda value=None: received.append(value))
        bus.publish("test_event", value=42)
        assert received == [42]

    def test_unsubscribe(self):
        bus = EventBus()
        received = []
        handler = lambda value=None: received.append(value)
        bus.subscribe("test_event", handler)
        bus.unsubscribe("test_event", handler)
        bus.publish("test_event", value=42)
        assert received == []


class TestFullArc1Flow:
    """Integration test: walk through all Arc 1 encounters programmatically."""

    def setup_method(self):
        self.loader = DataLoader(data_root=DATA_ROOT)
        self.bus = EventBus()
        self.engine = EncounterEngine(self.loader, self.bus)
        self.narrative = NarrativeSystem(self.loader, self.bus)
        self.state = create_new_game_state(self.loader)
        self.engine.load_encounters("arc1")
        self.narrative.load()

    def test_complete_arc1(self):
        # 1. Crystal discovery
        enc = self.engine.check_triggers(self.state)
        assert enc.encounter_id == "enc_arc1_crystal_discovery"
        self.engine.apply_choice_outcome(self.state, enc, 0)
        assert self.state.story_flags["arc1_crystal_discovered"] is True
        assert self.state.crystal_inventory == 10

        # 2. Dave trade (next highest priority)
        enc = self.engine.check_triggers(self.state)
        assert enc.encounter_id == "enc_arc1_dave_trade"
        self.engine.apply_choice_outcome(self.state, enc, 0)  # share_info
        assert self.state.story_flags["arc1_dave_met"] is True

        # 3. Death shadow
        enc = self.engine.check_triggers(self.state)
        assert enc.encounter_id == "enc_arc1_death_shadow"
        self.engine.apply_choice_outcome(self.state, enc, 0)  # pursue
        assert self.state.story_flags["arc1_death_glimpsed"] is True

        # 4. Stance choice — all 3 key flags set
        enc = self.engine.check_triggers(self.state)
        assert enc.encounter_id == "enc_arc1_stance_choice"
        self.engine.apply_choice_outcome(self.state, enc, 1)  # cautious_trade
        assert self.state.story_flags.get("arc1_stance") is True

        # Arc exit conditions should now be met
        assert self.narrative.check_arc_exit(self.state) is True

        # Advance to Arc 2
        new_arc = self.narrative.advance_arc(self.state)
        assert new_arc == "arc_2"
        assert self.state.current_arc == "arc_2"

        # Verify decisions were tracked
        assert len(self.state.player_decisions) == 4
        assert len(self.state.completed_encounters) == 4
