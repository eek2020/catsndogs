"""Master game state — single source of truth for all runtime data."""

from __future__ import annotations

from dataclasses import dataclass, field

from whisper_crystals.entities.character import (
    BehaviourState,
    Character,
    CharacterStats,
    Species,
)
from whisper_crystals.entities.faction import Faction
from whisper_crystals.entities.ship import Ship, ShipStats


@dataclass
class PlayerDecision:
    decision_id: str
    encounter_id: str
    choice_id: str
    arc_id: str
    timestamp: float
    outcome_weight: float
    consequences_applied: dict = field(default_factory=dict)


@dataclass
class GameStateData:
    """All mutable game state. This is the save/load payload."""

    # Meta
    version: str = "0.1.0"
    save_slot: int = 0
    playtime_seconds: float = 0.0

    # Arc progression
    current_arc: str = "arc_1"

    # Player
    player_character: Character = field(default_factory=lambda: Character(
        character_id="aristotle",
        name="Aristotle",
        species=Species.CAT,
        faction_id="felid_corsairs",
        title="Captain",
        stats=CharacterStats(cunning=8, leadership=7, negotiation=6, combat_skill=6, intimidation=4, stealth=3),
        is_player=True,
    ))
    player_ship: Ship = field(default_factory=lambda: Ship(
        ship_id="aristotle_flagship",
        name="The Whisper",
        faction_id="felid_corsairs",
        ship_class="corsair_raider",
        base_stats=ShipStats(speed=8, armour=3, firepower=5, crystal_capacity=6, crew_capacity=4),
        current_hull=100,
        max_hull=100,
    ))
    fleet: list[Ship] = field(default_factory=list)

    # World position
    current_region: str = "starting_realm"
    position_x: float = 0.0
    position_y: float = 0.0

    # Resources
    crystal_inventory: int = 0
    crystal_quality: int = 1
    salvage: int = 0

    # Factions — populated by DataLoader
    faction_registry: dict[str, Faction] = field(default_factory=dict)
    relationship_matrix: dict[str, dict[str, int]] = field(default_factory=dict)
    cascade_rules: list[dict] = field(default_factory=list)

    # NPCs
    npc_registry: dict[str, Character] = field(default_factory=dict)

    # Story
    story_flags: dict[str, object] = field(default_factory=dict)
    player_decisions: list[PlayerDecision] = field(default_factory=list)
    completed_encounters: list[str] = field(default_factory=list)


def create_new_game_state(data_loader) -> GameStateData:
    """Initialise a fresh game state from JSON data files."""
    state = GameStateData()

    # Load factions
    state.faction_registry = data_loader.load_factions()
    state.relationship_matrix = data_loader.load_relationship_matrix()
    state.cascade_rules = data_loader.load_cascade_rules()

    # Load player ship from template
    templates = data_loader.load_ship_templates()
    corsair_tmpl = templates.get("corsair_raider")
    if corsair_tmpl:
        state.player_ship = Ship.from_template(corsair_tmpl, "aristotle_flagship", "The Whisper")

    # Initialise core NPCs
    state.npc_registry["dave"] = Character(
        character_id="dave",
        name="Dave",
        species=Species.DOG,
        faction_id="canis_league",
        title="Commander",
        stats=CharacterStats(cunning=5, leadership=8, negotiation=5, combat_skill=7, intimidation=7, stealth=3),
        behaviour_state=BehaviourState.OBSERVING,
        relationship_with_player=0,
    )
    state.npc_registry["death"] = Character(
        character_id="death",
        name="Death",
        species=Species.CAT,
        faction_id="felid_corsairs",
        title="Captain",
        stats=CharacterStats(cunning=7, leadership=5, negotiation=4, combat_skill=6, intimidation=9, stealth=8),
        behaviour_state=BehaviourState.HIDDEN,
        relationship_with_player=0,
        true_allegiance=None,
    )

    # Initialise story flags for Arc 1
    state.story_flags = {
        "arc1_crystal_discovered": False,
        "arc1_dave_met": False,
        "arc1_death_glimpsed": False,
        "arc1_stance": None,
    }

    return state
