"""Tests for data loader and game state initialisation."""

import os

from whisper_crystals.core.data_loader import DataLoader
from whisper_crystals.core.game_state import GameStateData, create_new_game_state
from whisper_crystals.entities.faction import DiplomaticState

# Resolve data/ path relative to project root
DATA_ROOT = os.path.join(os.path.dirname(__file__), "..", "data")


class TestDataLoader:
    def setup_method(self):
        self.loader = DataLoader(data_root=DATA_ROOT)

    def test_load_factions(self):
        factions = self.loader.load_factions()
        assert "felid_corsairs" in factions
        assert "canis_league" in factions
        assert "wolves" in factions
        assert len(factions) == 8
        corsairs = factions["felid_corsairs"]
        assert corsairs.realm == "feline_courts"
        assert len(corsairs.abilities) >= 3

    def test_load_relationship_matrix(self):
        matrix = self.loader.load_relationship_matrix()
        assert "felid_corsairs" in matrix
        assert matrix["felid_corsairs"]["canis_league"] == -20

    def test_load_cascade_rules(self):
        rules = self.loader.load_cascade_rules()
        assert len(rules) >= 2

    def test_load_ship_templates(self):
        templates = self.loader.load_ship_templates()
        assert "corsair_raider" in templates
        assert "league_cruiser" in templates
        assert templates["corsair_raider"]["base_stats"]["speed"] == 8

    def test_load_encounters_arc1(self):
        encounters = self.loader.load_encounters("arc1")
        assert len(encounters) == 6
        ids = [e.encounter_id for e in encounters]
        assert "enc_arc1_crystal_discovery" in ids
        assert "enc_arc1_dave_trade" in ids
        assert "enc_arc1_death_shadow" in ids
        assert "enc_arc1_canis_patrol" in ids
        assert "enc_arc1_pirate_skirmish" in ids
        assert "enc_arc1_stance_choice" in ids

    def test_load_encounters_missing_arc(self):
        encounters = self.loader.load_encounters("arc99")
        assert encounters == []

    def test_load_arc_definitions(self):
        arcs = self.loader.load_arc_definitions()
        assert len(arcs) == 4
        assert arcs[0]["arc_id"] == "arc_1"
        assert arcs[0]["title"] == "The Upstart"

    def test_load_ending_thresholds(self):
        thresholds = self.loader.load_ending_thresholds()
        assert "ending_a_hold" in thresholds
        assert "ending_b_share" in thresholds
        assert "ending_c_destroy" in thresholds


class TestGameStateInit:
    def test_create_new_game_state(self):
        loader = DataLoader(data_root=DATA_ROOT)
        state = create_new_game_state(loader)

        # Player
        assert state.player_character.character_id == "aristotle"
        assert state.player_character.is_player is True
        assert state.player_character.stats.cunning == 8

        # Ship
        assert state.player_ship.ship_id == "aristotle_flagship"
        assert state.player_ship.base_stats.speed == 8

        # Factions
        assert len(state.faction_registry) == 8
        corsairs = state.faction_registry["felid_corsairs"]
        assert corsairs.diplomatic_state == DiplomaticState.FRIENDLY

        # NPCs
        assert "dave" in state.npc_registry
        assert "death" in state.npc_registry
        assert state.npc_registry["death"].true_allegiance is None

        # Story flags
        assert state.story_flags["arc1_crystal_discovered"] is False
        assert state.story_flags["arc1_dave_met"] is False

        # Arc
        assert state.current_arc == "arc_1"
