"""Tests for entity data models."""

from whisper_crystals.entities.character import Character, CharacterStats, Species, BehaviourState
from whisper_crystals.entities.ship import Ship, ShipStats, CrewMember, ShipUpgrade
from whisper_crystals.entities.faction import Faction, DiplomaticState, FactionAbility
from whisper_crystals.entities.encounter import Encounter, EncounterChoice, EncounterOutcome
from whisper_crystals.entities.crystal import CrystalDeposit, CrystalMarket


class TestCharacter:
    def test_from_dict_roundtrip(self):
        data = {
            "character_id": "aristotle",
            "name": "Aristotle",
            "species": "CAT",
            "faction_id": "felid_corsairs",
            "title": "Captain",
            "stats": {"cunning": 8, "leadership": 7, "negotiation": 6,
                      "combat_skill": 6, "intimidation": 4, "stealth": 3},
            "behaviour_state": "IDLE",
            "is_player": True,
        }
        char = Character.from_dict(data)
        assert char.character_id == "aristotle"
        assert char.species == Species.CAT
        assert char.stats.cunning == 8
        assert char.is_player is True

        out = char.to_dict()
        assert out["character_id"] == "aristotle"
        assert out["stats"]["cunning"] == 8

    def test_defaults(self):
        char = Character(character_id="test", name="Test", species=Species.DOG, faction_id="canis_league")
        assert char.behaviour_state == BehaviourState.IDLE
        assert char.relationship_with_player == 0


class TestShip:
    def test_from_template(self):
        template = {
            "template_id": "corsair_raider",
            "faction_id": "felid_corsairs",
            "base_stats": {"speed": 8, "armour": 3, "firepower": 5,
                           "crystal_capacity": 6, "crew_capacity": 4},
            "max_hull": 100,
            "sprite_id": "ships/corsair_raider.png",
        }
        ship = Ship.from_template(template, "my_ship", "My Ship")
        assert ship.ship_id == "my_ship"
        assert ship.base_stats.speed == 8
        assert ship.max_hull == 100

    def test_from_dict_roundtrip(self):
        ship = Ship(
            ship_id="test",
            name="Test Ship",
            faction_id="felid_corsairs",
            ship_class="corsair_raider",
            base_stats=ShipStats(speed=8, armour=3, firepower=5, crystal_capacity=6, crew_capacity=4),
        )
        data = ship.to_dict()
        restored = Ship.from_dict(data)
        assert restored.ship_id == "test"
        assert restored.base_stats.speed == 8


class TestFaction:
    def test_diplomatic_state_derivation(self):
        faction = Faction(faction_id="test", name="Test", species="cat",
                          alignment="chaotic", government="captains",
                          reputation_with_player=-60)
        faction.update_diplomatic_state()
        assert faction.diplomatic_state == DiplomaticState.HOSTILE

        faction.reputation_with_player = 50
        faction.update_diplomatic_state()
        assert faction.diplomatic_state == DiplomaticState.FRIENDLY

        faction.reputation_with_player = 80
        faction.update_diplomatic_state()
        assert faction.diplomatic_state == DiplomaticState.ALLIED

    def test_from_dict(self):
        data = {
            "faction_id": "felid_corsairs",
            "name": "Felid Corsairs",
            "species": "cat",
            "alignment": "chaotic_independent",
            "government": "decentralised_captains",
            "starting_reputation": 60,
            "abilities": [
                {"ability_id": "crystal_refining", "name": "Crystal Refining",
                 "type": "production", "description": "Refine raw crystals",
                 "effect": {"target": "crystal_quality", "modifier": 1}},
            ],
        }
        faction = Faction.from_dict(data)
        assert faction.faction_id == "felid_corsairs"
        assert faction.reputation_with_player == 60
        assert faction.diplomatic_state == DiplomaticState.FRIENDLY
        assert len(faction.abilities) == 1
        assert faction.abilities[0].ability_id == "crystal_refining"


class TestEncounter:
    def test_from_dict(self):
        data = {
            "encounter_id": "enc_test",
            "encounter_type": "diplomatic",
            "title": "Test Encounter",
            "description": "A test.",
            "arc_id": "arc_1",
            "location": "test_zone",
            "trigger_conditions": {"current_arc": "arc_1"},
            "choices": [
                {
                    "choice_id": "opt_a",
                    "text": "Option A",
                    "outcome": {
                        "description": "You chose A.",
                        "faction_changes": {"canis_league": 10},
                        "story_flags_set": ["test_flag"],
                    },
                    "outcome_weight": 0.2,
                },
            ],
        }
        enc = Encounter.from_dict(data)
        assert enc.encounter_id == "enc_test"
        assert len(enc.choices) == 1
        assert enc.choices[0].outcome.faction_changes == {"canis_league": 10}
        assert enc.choices[0].outcome_weight == 0.2


class TestCrystalMarket:
    def test_price_calculation(self):
        market = CrystalMarket(
            base_price=100,
            demand_multipliers={"canis_league": 1.3, "fairies": 0.9},
        )
        # Neutral reputation (0) → modifier = 1.0
        price = market.calculate_price("canis_league", 0)
        assert price == 130

        # Friendly reputation (60) → modifier = 1.0 - 60/400 = 0.85
        price = market.calculate_price("canis_league", 60)
        assert price == 110  # int(100 * 1.3 * 1.0 * 0.85) = 110
