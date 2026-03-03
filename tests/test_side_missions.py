"""Tests for side mission system — entity serialization, lifecycle, and rewards."""

from __future__ import annotations

import os

from whisper_crystals.core.data_loader import DataLoader
from whisper_crystals.core.event_bus import EventBus
from whisper_crystals.core.game_state import create_new_game_state
from whisper_crystals.entities.side_mission import MissionObjective, SideMission
from whisper_crystals.systems.side_mission import SideMissionSystem

DATA_ROOT = os.path.join(os.path.dirname(__file__), "..", "data")


# ------------------------------------------------------------------
# Entity serialization
# ------------------------------------------------------------------

class TestMissionObjectiveSerialization:
    def test_round_trip(self):
        obj = MissionObjective(
            objective_id="obj_1",
            description="Defeat the patrol",
            completed=True,
            encounter_id="enc_combat_1",
        )
        data = obj.to_dict()
        restored = MissionObjective.from_dict(data)
        assert restored.objective_id == "obj_1"
        assert restored.description == "Defeat the patrol"
        assert restored.completed is True
        assert restored.encounter_id == "enc_combat_1"

    def test_defaults(self):
        obj = MissionObjective.from_dict({
            "objective_id": "obj_2",
            "description": "Find the cargo",
        })
        assert obj.completed is False
        assert obj.encounter_id is None


class TestSideMissionSerialization:
    def test_round_trip(self):
        mission = SideMission(
            mission_id="sm_test",
            mission_type="bounty",
            title="Test Mission",
            description="A test mission.",
            region="test_region",
            status="active",
            objectives=[
                MissionObjective("obj_1", "Do thing", completed=False, encounter_id="enc_1"),
                MissionObjective("obj_2", "Do other thing", completed=True),
            ],
            rewards={"salvage": 50, "crystals": 10},
            faction_rewards={"felid_corsairs": 5},
            trigger_conditions={"current_arc": "arc_1"},
            discovery_encounter_id="enc_discover",
            priority=3,
        )
        data = mission.to_dict()
        restored = SideMission.from_dict(data)
        assert restored.mission_id == "sm_test"
        assert restored.mission_type == "bounty"
        assert restored.status == "active"
        assert len(restored.objectives) == 2
        assert restored.objectives[1].completed is True
        assert restored.rewards == {"salvage": 50, "crystals": 10}
        assert restored.faction_rewards == {"felid_corsairs": 5}
        assert restored.priority == 3

    def test_is_complete_all_done(self):
        mission = SideMission(
            mission_id="sm_done",
            mission_type="retrieval",
            title="Done",
            description="All done",
            objectives=[
                MissionObjective("o1", "A", completed=True),
                MissionObjective("o2", "B", completed=True),
            ],
        )
        assert mission.is_complete is True

    def test_is_complete_not_done(self):
        mission = SideMission(
            mission_id="sm_not",
            mission_type="escort",
            title="Not Done",
            description="Not done yet",
            objectives=[
                MissionObjective("o1", "A", completed=True),
                MissionObjective("o2", "B", completed=False),
            ],
        )
        assert mission.is_complete is False

    def test_is_complete_no_objectives(self):
        mission = SideMission(
            mission_id="sm_empty",
            mission_type="bounty",
            title="Empty",
            description="No objectives",
        )
        assert mission.is_complete is False


# ------------------------------------------------------------------
# Data loading
# ------------------------------------------------------------------

class TestDataLoading:
    def setup_method(self):
        self.loader = DataLoader(data_root=DATA_ROOT)

    def test_load_arc1_side_missions(self):
        missions = self.loader.load_side_missions("arc1")
        assert len(missions) >= 3
        ids = {m.mission_id for m in missions}
        assert "sm_arc1_bounty_goblin_raiders" in ids
        assert "sm_arc1_escort_fairy_envoy" in ids

    def test_load_side_missions_missing_arc(self):
        missions = self.loader.load_side_missions("arc99")
        assert missions == []

    def test_load_distress_signals(self):
        encounters = self.loader.load_distress_signals()
        assert len(encounters) >= 4
        ids = {e.encounter_id for e in encounters}
        assert "distress_stranded_merchant" in ids
        assert "distress_escape_pod" in ids
        for enc in encounters:
            assert enc.repeatable is True
            assert len(enc.choices) >= 2


# ------------------------------------------------------------------
# SideMissionSystem lifecycle
# ------------------------------------------------------------------

class TestSideMissionSystem:
    def setup_method(self):
        self.loader = DataLoader(data_root=DATA_ROOT)
        self.bus = EventBus()
        self.system = SideMissionSystem(self.loader, self.bus)
        self.state = create_new_game_state(self.loader)
        self.system.load_missions("arc1")
        self.system.load_distress_signals()

    def test_get_available_missions_initial(self):
        # Only missions with no trigger conditions should be available at start
        available = self.system.get_available_missions(self.state)
        # sm_arc1_salvage_derelict has only current_arc condition (met at start)
        ids = {m.mission_id for m in available}
        assert "sm_arc1_salvage_derelict" in ids

    def test_get_available_after_flag_set(self):
        self.state.story_flags["arc1_crystal_discovered"] = True
        available = self.system.get_available_missions(self.state)
        ids = {m.mission_id for m in available}
        assert "sm_arc1_bounty_goblin_raiders" in ids
        assert "sm_arc1_escort_fairy_envoy" in ids

    def test_discover_mission(self):
        mission = self.system.discover_mission(self.state, "sm_arc1_salvage_derelict")
        assert mission is not None
        assert mission.status == "active"
        assert "sm_arc1_salvage_derelict" in self.state.side_missions
        # Should not appear in available anymore
        available = self.system.get_available_missions(self.state)
        ids = {m.mission_id for m in available}
        assert "sm_arc1_salvage_derelict" not in ids

    def test_discover_unknown_mission(self):
        result = self.system.discover_mission(self.state, "sm_nonexistent")
        assert result is None

    def test_check_objectives_completes_mission(self):
        # Discover and set up a mission
        self.system.discover_mission(self.state, "sm_arc1_salvage_derelict")
        mission = self.state.side_missions["sm_arc1_salvage_derelict"]
        assert mission.status == "active"

        # Simulate encounter completion
        obj_enc_id = mission.objectives[0].encounter_id
        self.state.completed_encounters.append(obj_enc_id)

        completed = self.system.check_objectives(self.state)
        assert "sm_arc1_salvage_derelict" in completed
        assert mission.status == "completed"

    def test_rewards_applied_on_completion(self):
        self.system.discover_mission(self.state, "sm_arc1_salvage_derelict")
        mission = self.state.side_missions["sm_arc1_salvage_derelict"]
        obj_enc_id = mission.objectives[0].encounter_id
        self.state.completed_encounters.append(obj_enc_id)

        initial_salvage = self.state.salvage
        self.system.check_objectives(self.state)
        expected_salvage = initial_salvage + mission.rewards.get("salvage", 0)
        assert self.state.salvage == expected_salvage

    def test_fail_mission(self):
        self.system.discover_mission(self.state, "sm_arc1_salvage_derelict")
        result = self.system.fail_mission(self.state, "sm_arc1_salvage_derelict")
        assert result is True
        assert self.state.side_missions["sm_arc1_salvage_derelict"].status == "failed"

    def test_fail_non_active_mission(self):
        # Can't fail a mission that isn't active
        result = self.system.fail_mission(self.state, "sm_nonexistent")
        assert result is False

    def test_get_active_missions(self):
        self.system.discover_mission(self.state, "sm_arc1_salvage_derelict")
        active = self.system.get_active_missions(self.state)
        assert len(active) == 1
        assert active[0].mission_id == "sm_arc1_salvage_derelict"

    def test_mission_count(self):
        assert self.system.get_mission_count(self.state) == 0
        self.system.discover_mission(self.state, "sm_arc1_salvage_derelict")
        assert self.system.get_mission_count(self.state) == 1

    def test_distress_timer(self):
        # Should not spawn immediately
        result = self.system.update_distress(1.0, self.state)
        assert result is None

        # After enough time, should spawn
        result = self.system.update_distress(100.0, self.state)
        assert result is not None
        assert result.encounter_type == "distress_signal"

    def test_event_published_on_discovery(self):
        events = []
        self.bus.subscribe("mission_discovered", lambda **kw: events.append(kw))
        self.system.discover_mission(self.state, "sm_arc1_salvage_derelict")
        assert len(events) == 1
        assert events[0]["mission_id"] == "sm_arc1_salvage_derelict"

    def test_event_published_on_completion(self):
        events = []
        self.bus.subscribe("mission_completed", lambda **kw: events.append(kw))
        self.system.discover_mission(self.state, "sm_arc1_salvage_derelict")
        mission = self.state.side_missions["sm_arc1_salvage_derelict"]
        self.state.completed_encounters.append(mission.objectives[0].encounter_id)
        self.system.check_objectives(self.state)
        assert len(events) == 1
        assert events[0]["mission_id"] == "sm_arc1_salvage_derelict"


# ------------------------------------------------------------------
# GameStateData serialization with side missions
# ------------------------------------------------------------------

class TestGameStateDataSideMissions:
    def setup_method(self):
        self.loader = DataLoader(data_root=DATA_ROOT)
        self.state = create_new_game_state(self.loader)

    def test_side_missions_in_to_dict(self):
        mission = SideMission(
            mission_id="sm_test",
            mission_type="bounty",
            title="Test",
            description="Test mission",
            status="active",
            objectives=[MissionObjective("o1", "Do it", encounter_id="enc_1")],
            rewards={"salvage": 20},
        )
        self.state.side_missions["sm_test"] = mission
        data = self.state.to_dict()
        assert "side_missions" in data
        assert "sm_test" in data["side_missions"]
        assert data["side_missions"]["sm_test"]["status"] == "active"

    def test_side_missions_from_dict(self):
        from whisper_crystals.core.game_state import GameStateData
        mission = SideMission(
            mission_id="sm_round",
            mission_type="escort",
            title="Round Trip",
            description="Test round trip",
            status="completed",
            objectives=[MissionObjective("o1", "Done", completed=True)],
        )
        self.state.side_missions["sm_round"] = mission
        data = self.state.to_dict()
        restored = GameStateData.from_dict(data)
        assert "sm_round" in restored.side_missions
        assert restored.side_missions["sm_round"].status == "completed"
        assert restored.side_missions["sm_round"].objectives[0].completed is True
