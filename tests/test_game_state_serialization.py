"""Tests for GameStateData round-trip serialization."""

import json
import os

from whisper_crystals.core.data_loader import DataLoader
from whisper_crystals.core.game_state import GameStateData, PlayerDecision, create_new_game_state

DATA_ROOT = os.path.join(os.path.dirname(__file__), "..", "data")


class TestPlayerDecisionSerialization:
    def test_round_trip(self):
        decision = PlayerDecision(
            decision_id="d1",
            encounter_id="enc_test",
            choice_id="opt_a",
            arc_id="arc_1",
            timestamp=42.5,
            outcome_weight=0.3,
            consequences_applied={"crystals": 10},
        )
        data = decision.to_dict()
        restored = PlayerDecision.from_dict(data)
        assert restored.decision_id == "d1"
        assert restored.encounter_id == "enc_test"
        assert restored.outcome_weight == 0.3
        assert restored.consequences_applied == {"crystals": 10}


class TestGameStateDataSerialization:
    def setup_method(self):
        self.loader = DataLoader(data_root=DATA_ROOT)
        self.state = create_new_game_state(self.loader)

    def test_round_trip_fresh_state(self):
        """A fresh game state should survive to_dict / from_dict unchanged."""
        data = self.state.to_dict()
        restored = GameStateData.from_dict(data)

        assert restored.version == self.state.version
        assert restored.current_arc == self.state.current_arc
        assert restored.player_character.character_id == "aristotle"
        assert restored.player_ship.name == self.state.player_ship.name
        assert restored.player_ship.base_stats.speed == self.state.player_ship.base_stats.speed
        assert restored.crystal_inventory == self.state.crystal_inventory
        assert restored.salvage == self.state.salvage
        assert restored.story_flags == self.state.story_flags
        assert len(restored.faction_registry) == len(self.state.faction_registry)
        assert len(restored.npc_registry) == len(self.state.npc_registry)

    def test_round_trip_modified_state(self):
        """Modified game state should round-trip accurately."""
        self.state.crystal_inventory = 42
        self.state.salvage = 15
        self.state.playtime_seconds = 123.5
        self.state.position_x = 500.0
        self.state.position_y = -200.0
        self.state.story_flags["arc1_crystal_discovered"] = True
        self.state.completed_encounters.append("enc_test")
        self.state.player_decisions.append(
            PlayerDecision(
                decision_id="d1",
                encounter_id="enc_test",
                choice_id="opt_a",
                arc_id="arc_1",
                timestamp=10.0,
                outcome_weight=0.5,
            )
        )

        data = self.state.to_dict()
        restored = GameStateData.from_dict(data)

        assert restored.crystal_inventory == 42
        assert restored.salvage == 15
        assert restored.playtime_seconds == 123.5
        assert restored.position_x == 500.0
        assert restored.position_y == -200.0
        assert restored.story_flags["arc1_crystal_discovered"] is True
        assert "enc_test" in restored.completed_encounters
        assert len(restored.player_decisions) == 1
        assert restored.player_decisions[0].decision_id == "d1"

    def test_json_serializable(self):
        """to_dict() output must be JSON-serializable."""
        data = self.state.to_dict()
        json_str = json.dumps(data)
        assert isinstance(json_str, str)
        parsed = json.loads(json_str)
        restored = GameStateData.from_dict(parsed)
        assert restored.player_character.character_id == "aristotle"

    def test_faction_registry_survives(self):
        """Faction data including reputation should survive serialization."""
        self.state.faction_registry["canis_league"].reputation_with_player = -30
        data = self.state.to_dict()
        restored = GameStateData.from_dict(data)
        assert restored.faction_registry["canis_league"].reputation_with_player == -30

    def test_npc_registry_survives(self):
        """NPC data should survive serialization."""
        self.state.npc_registry["dave"].relationship_with_player = 25
        data = self.state.to_dict()
        restored = GameStateData.from_dict(data)
        assert restored.npc_registry["dave"].relationship_with_player == 25
        assert restored.npc_registry["death"].character_id == "death"
