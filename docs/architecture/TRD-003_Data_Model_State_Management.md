# TRD-003: Data Model & State Management

**Project:** Whisper Crystals — A Space Pirates Game  
**Version:** 0.1  
**Date:** February 2026  
**Classification:** Creative Development — Confidential  

---

## Section 1: Entity Data Models

All entities are defined as Python dataclasses for type safety, serialisation support, and engine-agnostic portability.

### 1.1 Character Model

```python
from dataclasses import dataclass, field
from enum import Enum, auto

class Species(Enum):
    CAT = auto()
    DOG = auto()
    CAT_NOBLE = auto()
    WOLF = auto()
    FAIRY = auto()
    KNIGHT = auto()
    GOBLIN = auto()
    ALIEN = auto()

class BehaviourState(Enum):
    IDLE = auto()
    OBSERVING = auto()
    TRADING = auto()
    HOSTILE = auto()
    COVERT_ACTION = auto()
    REVEALED = auto()
    OPEN_CONFLICT = auto()
    ALLIED = auto()

@dataclass
class CharacterStats:
    cunning: int = 5
    leadership: int = 5
    negotiation: int = 5
    combat_skill: int = 5
    intimidation: int = 5
    stealth: int = 5

@dataclass
class Character:
    character_id: str
    name: str
    species: Species
    faction_id: str
    title: str = ""
    stats: CharacterStats = field(default_factory=CharacterStats)
    behaviour_state: BehaviourState = BehaviourState.IDLE
    relationship_with_player: int = 0          # -100 to +100
    current_arc: str = "arc_1"
    is_player: bool = False
    true_allegiance: str | None = None         # Set in Arc 3 for Death
    portrait_sprite: str = ""                  # Asset reference
    dialogue_tree_id: str = ""                 # Reference to dialogue data
```

**JSON Representation:**

```json
{
    "character_id": "aristotle",
    "name": "Aristotle",
    "species": "CAT",
    "faction_id": "felid_corsairs",
    "title": "Captain",
    "stats": {
        "cunning": 8,
        "leadership": 7,
        "negotiation": 6,
        "combat_skill": 6,
        "intimidation": 4,
        "stealth": 3
    },
    "behaviour_state": "IDLE",
    "relationship_with_player": 0,
    "current_arc": "arc_1",
    "is_player": true,
    "true_allegiance": null,
    "portrait_sprite": "characters/aristotle_portrait.png",
    "dialogue_tree_id": ""
}
```

### 1.2 Ship Model

```python
@dataclass
class ShipStats:
    speed: int = 5
    armour: int = 5
    firepower: int = 5
    crystal_capacity: int = 5
    crew_capacity: int = 5

@dataclass
class CrewMember:
    crew_id: str
    name: str
    species: Species            # Species of crew member (mixed-universe crews)
    role: str                   # "pilot", "gunner", "engineer", "diplomat"
    faction_origin: str         # Home faction ID — crew are NOT faction-pure
    skills: list[str] = field(default_factory=list)  # e.g. ["navigation", "repair", "espionage"]
    skill_level: int = 5       # 1-10, modifies associated stat by ±20%
    morale: int = 100          # 0-100; affected by faction standings and events
    morale_modifier: int = 0   # Bonus/penalty from faction relationship context
    faction_trait_bonus: str = ""  # e.g. "speed+5%", "armour+5%", "salvage+10%"

@dataclass
class ShipUpgrade:
    upgrade_id: str
    name: str
    target_stat: str            # Which stat this modifies
    modifier: int               # +/- value to base stat
    cost_crystals: int = 0
    cost_salvage: int = 0

@dataclass
class Ship:
    ship_id: str
    name: str
    faction_id: str
    ship_class: str             # "corsair_raider", "league_cruiser", etc.
    base_stats: ShipStats = field(default_factory=ShipStats)
    current_hull: int = 100     # 0 = destroyed
    max_hull: int = 100
    crew: list[CrewMember] = field(default_factory=list)
    upgrades: list[ShipUpgrade] = field(default_factory=list)
    crystal_cargo: int = 0      # Current crystals aboard
    sprite_id: str = ""         # Asset reference
```

**JSON Representation:**

```json
{
    "ship_id": "aristotle_flagship",
    "name": "The Whisper",
    "faction_id": "felid_corsairs",
    "ship_class": "corsair_raider",
    "base_stats": {
        "speed": 8,
        "armour": 3,
        "firepower": 5,
        "crystal_capacity": 6,
        "crew_capacity": 4
    },
    "current_hull": 100,
    "max_hull": 100,
    "crew": [
        {
            "crew_id": "crew_001",
            "name": "Whiskers",
            "role": "pilot",
            "faction_origin": "felid_corsairs",
            "skill_level": 7
        }
    ],
    "upgrades": [],
    "crystal_cargo": 12,
    "sprite_id": "ships/corsair_raider.png"
}
```

### 1.3 Faction Model

```python
class DiplomaticState(Enum):
    HOSTILE = auto()        # -100 to -51
    WARY = auto()           # -50 to -1
    NEUTRAL = auto()        # 0 to 25
    FRIENDLY = auto()       # 26 to 75
    ALLIED = auto()         # 76 to 100

@dataclass
class Faction:
    faction_id: str
    name: str
    species: str
    alignment: str                              # "chaotic_independent", "lawful_hierarchical", etc.
    government: str                             # "decentralised_captains", "military_command", etc.
    reputation_with_player: int = 0             # -100 to +100
    diplomatic_state: DiplomaticState = DiplomaticState.NEUTRAL
    ship_template_id: str = ""                  # Default ship class for this faction
    realm: str = ""                                  # Home realm ID
    ideology: str = ""                                 # Faction ideology string
    conquest_intent: int = 50                          # 0-100, drives AI competition behaviour
    traits: list[str] = field(default_factory=list)
    abilities: list[dict] = field(default_factory=list)  # Typed ability registry (faction_abilities[])
    # Faction-specific attributes
    military_strength: int = 50
    crystal_reserves: int = 0
    crystal_production_rate: int = 0            # Only non-zero for felid_corsairs
    internal_stability: int = 100               # Affected by Death's actions for corsairs
    aggression_level: int = 0                   # Escalates across arcs for canis_league
    political_influence: int = 0                # Primary for lions
    tactical_rating: int = 0                    # Primary for wolves

    def update_diplomatic_state(self):
        """Derive diplomatic state from reputation score."""
        score = self.reputation_with_player
        if score <= -51:
            self.diplomatic_state = DiplomaticState.HOSTILE
        elif score <= -1:
            self.diplomatic_state = DiplomaticState.WARY
        elif score <= 25:
            self.diplomatic_state = DiplomaticState.NEUTRAL
        elif score <= 75:
            self.diplomatic_state = DiplomaticState.FRIENDLY
        else:
            self.diplomatic_state = DiplomaticState.ALLIED
```

**Faction Relationship Matrix (JSON):**

```json
{
    "relationship_matrix": {
        "felid_corsairs": {
            "canis_league": -20,
            "lions": -10,
            "wolves": -30,
            "fairies": 15,
            "knights": 0,
            "goblins": 10,
            "aliens": 5
        },
        "canis_league": {
            "felid_corsairs": -20,
            "lions": -15,
            "wolves": 40,
            "fairies": 0,
            "knights": 20,
            "goblins": -10,
            "aliens": 0
        }
    },
    "cascade_rules": [
        {
            "trigger_faction": "canis_league",
            "affected_faction": "wolves",
            "cascade_ratio": 0.5,
            "description": "Improving relations with dogs slightly improves wolf relations"
        },
        {
            "trigger_faction": "lions",
            "affected_faction": "felid_corsairs",
            "cascade_ratio": -0.3,
            "description": "Appeasing lions slightly destabilises corsair independence"
        }
    ]
}
```

### 1.4 Encounter Model

```python
@dataclass
class EncounterOutcome:
    description: str
    faction_changes: dict[str, int] = field(default_factory=dict)  # faction_id → score delta
    resource_changes: dict[str, int] = field(default_factory=dict) # resource → quantity delta
    story_flags_set: list[str] = field(default_factory=list)
    story_flags_cleared: list[str] = field(default_factory=list)
    trigger_encounter_id: str | None = None     # Chain to another encounter

@dataclass
class EncounterChoice:
    choice_id: str
    text: str
    conditions: dict[str, any] = field(default_factory=dict)  # Required flags/scores
    outcome: EncounterOutcome = field(default_factory=EncounterOutcome)
    outcome_weight: float = 0.0                 # Contributes to ending calculation

@dataclass
class Encounter:
    encounter_id: str
    encounter_type: str         # "combat", "trade", "diplomatic", "exploration"
    title: str
    description: str
    arc_id: str                 # Which arc this belongs to
    location: str               # Region/realm ID
    trigger_conditions: dict = field(default_factory=dict)
    npc_ids: list[str] = field(default_factory=list)
    choices: list[EncounterChoice] = field(default_factory=list)
    priority: int = 0
    repeatable: bool = False
```

### 1.5 Choice/Decision Model

```python
@dataclass
class PlayerDecision:
    decision_id: str
    encounter_id: str
    choice_id: str
    arc_id: str
    timestamp: float                # Game time when decision was made
    outcome_weight: float           # Contribution toward ending calculation
    consequences_applied: dict = field(default_factory=dict)  # Snapshot of what changed
```

---

## Section 2: Game State Model

The game state is the master container for all runtime data. It is the single source of truth and the basis for save/load.

```python
@dataclass
class GameState:
    # Meta
    version: str = "0.1.0"
    save_slot: int = 0
    playtime_seconds: float = 0.0

    # Arc progression
    current_arc: str = "arc_1"
    active_state: str = "NAVIGATION"    # Current state machine state

    # Player
    player_character: Character = field(default_factory=lambda: Character(
        character_id="aristotle",
        name="Aristotle",
        species=Species.CAT,
        faction_id="felid_corsairs",
        title="Captain",
        is_player=True
    ))
    player_ship: Ship = field(default_factory=lambda: Ship(
        ship_id="aristotle_flagship",
        name="The Whisper",
        faction_id="felid_corsairs",
        ship_class="corsair_raider"
    ))
    fleet: list[Ship] = field(default_factory=list)

    # World position
    current_region: str = "starting_realm"
    position_x: float = 0.0
    position_y: float = 0.0

    # Resources
    crystal_inventory: int = 0
    crystal_quality: int = 1                    # Grade 1-5
    salvage: int = 0

    # Factions
    faction_registry: dict[str, Faction] = field(default_factory=dict)

    # NPCs
    npc_registry: dict[str, Character] = field(default_factory=dict)

    # Story
    story_flags: dict[str, any] = field(default_factory=dict)
    player_decisions: list[PlayerDecision] = field(default_factory=list)
    completed_encounters: list[str] = field(default_factory=list)

    # Crystal production
    production_sites: list[dict] = field(default_factory=list)
    supply_routes: list[dict] = field(default_factory=list)
```

---

## Section 3: Whisper Crystal Resource Model

```python
@dataclass
class CrystalDeposit:
    deposit_id: str
    location: str               # Region ID
    quantity_remaining: int      # Finite resource
    quality_grade: int           # 1 (raw) to 5 (refined premium)
    extraction_rate: int         # Units per game-day
    is_discovered: bool = False
    is_active: bool = False      # Being mined?

@dataclass
class SupplyRoute:
    route_id: str
    origin: str                 # Deposit location
    destination: str            # Trade post / port
    status: str = "active"      # "active", "blockaded", "destroyed", "rerouted"
    capacity: int = 10          # Max crystals per shipment
    risk_level: int = 1         # 1-5, affects encounter chance during transport
    faction_threats: list[str] = field(default_factory=list)  # Factions threatening route

@dataclass
class CrystalMarket:
    base_price: int = 100
    demand_multipliers: dict[str, float] = field(default_factory=dict)  # faction_id → multiplier
    supply_modifier: float = 1.0    # Decreases when routes are blockaded
    event_modifiers: list[dict] = field(default_factory=list)  # Temporary price effects

    def calculate_price(self, faction_id: str, faction_reputation: int) -> int:
        """Calculate crystal price for a specific faction."""
        base = self.base_price
        demand = self.demand_multipliers.get(faction_id, 1.0)
        supply = self.supply_modifier

        # Reputation discount/premium: -25% to +25%
        reputation_modifier = 1.0 - (faction_reputation / 400.0)

        price = int(base * demand * supply * reputation_modifier)
        return max(1, price)
```

**Crystal Market Data (JSON):**

```json
{
    "crystal_market": {
        "base_price": 100,
        "demand_multipliers": {
            "canis_league": 1.3,
            "lions": 1.1,
            "wolves": 1.4,
            "fairies": 0.9,
            "knights": 1.0,
            "goblins": 0.7,
            "aliens": 1.2
        },
        "supply_modifier": 1.0,
        "event_modifiers": []
    },
    "deposits": [
        {
            "deposit_id": "deposit_origin",
            "location": "forgotten_realm",
            "quantity_remaining": 10000,
            "quality_grade": 3,
            "extraction_rate": 5,
            "is_discovered": true,
            "is_active": true
        }
    ]
}
```

---

## Section 4: Save File Schema (JSON)

### Save File Structure

```json
{
    "meta": {
        "version": "0.1.0",
        "save_slot": 1,
        "save_date": "2026-02-15T14:30:00Z",
        "playtime_seconds": 3600.0,
        "current_arc": "arc_2",
        "active_state": "NAVIGATION"
    },
    "player": {
        "character": {
            "character_id": "aristotle",
            "name": "Aristotle",
            "species": "CAT",
            "faction_id": "felid_corsairs",
            "title": "Captain",
            "stats": {
                "cunning": 9,
                "leadership": 7,
                "negotiation": 7,
                "combat_skill": 6,
                "intimidation": 4,
                "stealth": 3
            },
            "current_arc": "arc_2"
        },
        "ship": {
            "ship_id": "aristotle_flagship",
            "name": "The Whisper",
            "faction_id": "felid_corsairs",
            "ship_class": "corsair_raider",
            "base_stats": { "speed": 8, "armour": 4, "firepower": 6, "crystal_capacity": 7, "crew_capacity": 5 },
            "current_hull": 85,
            "max_hull": 100,
            "crew": [],
            "upgrades": [
                { "upgrade_id": "upg_001", "name": "Reinforced Hull", "target_stat": "armour", "modifier": 1, "cost_crystals": 20, "cost_salvage": 10 }
            ],
            "crystal_cargo": 25
        },
        "fleet": [],
        "position": { "region": "trade_hub_alpha", "x": 1200.0, "y": 450.0 }
    },
    "resources": {
        "crystal_inventory": 150,
        "crystal_quality": 3,
        "salvage": 45
    },
    "factions": {
        "felid_corsairs": { "reputation_with_player": 60, "internal_stability": 75, "crystal_production_rate": 5 },
        "canis_league": { "reputation_with_player": -35, "aggression_level": 60, "crystal_reserves": 20 },
        "lions": { "reputation_with_player": -15, "political_influence": 70, "tribute_demanded": true },
        "wolves": { "reputation_with_player": -50, "military_strength": 80, "tactical_rating": 85 },
        "fairies": { "reputation_with_player": 25 },
        "knights": { "reputation_with_player": 10 },
        "goblins": { "reputation_with_player": 15 },
        "aliens": { "reputation_with_player": 5 }
    },
    "npcs": {
        "dave": {
            "character_id": "dave",
            "behaviour_state": "HOSTILE",
            "relationship_with_player": -35,
            "current_arc": "arc_2"
        },
        "death": {
            "character_id": "death",
            "behaviour_state": "COVERT_ACTION",
            "relationship_with_player": -10,
            "current_arc": "arc_2",
            "true_allegiance": null
        }
    },
    "story": {
        "flags": {
            "arc1_crystal_discovered": true,
            "arc1_dave_met": true,
            "arc1_death_glimpsed": true,
            "arc1_stance": "aggressive_expansion",
            "arc2_route_resolved": "fight",
            "arc2_death_betrayal": true,
            "arc2_lion_response": null
        },
        "decisions": [
            {
                "decision_id": "dec_001",
                "encounter_id": "enc_arc1_dave_trade",
                "choice_id": "withhold_info",
                "arc_id": "arc_1",
                "timestamp": 1200.0,
                "outcome_weight": -0.3,
                "consequences_applied": {
                    "canis_league_reputation": -15,
                    "flag_set": "arc1_dave_met"
                }
            }
        ],
        "completed_encounters": [
            "enc_arc1_crystal_discovery",
            "enc_arc1_dave_trade",
            "enc_arc1_death_shadow",
            "enc_arc2_route_seizure"
        ]
    },
    "production": {
        "sites": [
            { "deposit_id": "deposit_origin", "location": "forgotten_realm", "quantity_remaining": 9500, "is_active": true }
        ],
        "routes": [
            { "route_id": "route_001", "origin": "forgotten_realm", "destination": "trade_hub_alpha", "status": "active", "capacity": 10 }
        ]
    }
}
```

### Save File Validation

```python
REQUIRED_SAVE_KEYS = ["meta", "player", "resources", "factions", "npcs", "story", "production"]

def validate_save(data: dict) -> tuple[bool, str]:
    """Validate a save file structure and version."""
    for key in REQUIRED_SAVE_KEYS:
        if key not in data:
            return False, f"Missing required key: {key}"

    meta = data.get("meta", {})
    version = meta.get("version", "")
    if not version:
        return False, "Missing version in meta"

    # Version compatibility check
    major, minor, patch = version.split(".")
    if int(major) != 0:
        return False, f"Incompatible save version: {version}"

    return True, "OK"
```

---

## Section 5: Story Flag & Choice History Model

### Story Flags

Story flags are key-value pairs stored in `game_state.story_flags`. They track narrative progression and gate content availability.

**Flag Naming Convention:** `{arc_id}_{event_description}`

| Flag Name | Type | Set By | Used By |
|-----------|------|--------|---------|
| `arc1_crystal_discovered` | bool | Exploration encounter | Arc 1 exit condition |
| `arc1_dave_met` | bool | Trade encounter with Dave | Arc 1 exit condition |
| `arc1_death_glimpsed` | bool | Cutscene event | Arc 1 exit condition |
| `arc1_stance` | str | Arc 1 decision point | Arc 2 mission availability |
| `arc2_route_resolved` | str | Supply route encounter | Arc 2 exit condition |
| `arc2_death_betrayal` | bool | Death betrayal encounter | Arc 2 exit condition |
| `arc2_lion_response` | str | Lion diplomatic encounter | Arc 2 exit condition |
| `arc2_priority` | str | Arc 2 decision point | Arc 3 content filtering |
| `arc3_alien_contact` | bool | Alien summit encounter | Arc 3 exit condition |
| `arc3_dave_parley` | bool | Dave parley encounter | Arc 3 exit condition |
| `arc3_death_allegiance` | str | Death revelation encounter | Arc 4 content, ending calc |

### Choice History & Ending Calculation

```python
@dataclass
class EndingCalculator:
    # Threshold ranges for each ending
    HOLD_THRESHOLD = (0.5, float('inf'))    # High positive weight = hold monopoly
    SHARE_THRESHOLD = (-0.2, 0.5)           # Moderate weight = share crystals
    DESTROY_THRESHOLD = (float('-inf'), -0.2) # Negative weight = destroy sites

    @staticmethod
    def calculate_ending(decisions: list[PlayerDecision]) -> str:
        """Determine ending based on cumulative outcome weights."""
        total_weight = sum(d.outcome_weight for d in decisions)

        if total_weight >= EndingCalculator.HOLD_THRESHOLD[0]:
            return "ending_a_hold"
        elif total_weight >= EndingCalculator.SHARE_THRESHOLD[0]:
            return "ending_b_share"
        else:
            return "ending_c_destroy"
```

**Ending Thresholds (Data-Driven, JSON):**

```json
{
    "ending_thresholds": {
        "ending_a_hold": { "min_weight": 0.5, "max_weight": null },
        "ending_b_share": { "min_weight": -0.2, "max_weight": 0.5 },
        "ending_c_destroy": { "min_weight": null, "max_weight": -0.2 }
    },
    "weight_examples": {
        "aggressive_expansion_choices": "+0.2 to +0.5 per choice",
        "diplomatic_sharing_choices": "-0.1 to +0.1 per choice",
        "isolationist_destruction_choices": "-0.2 to -0.5 per choice"
    }
}
```

### Arc Progression State Machine

```python
@dataclass
class ArcDefinition:
    arc_id: str
    title: str
    entry_conditions: dict[str, any]    # Required story flags
    exit_conditions: dict[str, any]     # Story flags that trigger transition
    next_arc_id: str | None             # None for final arc

ARC_DEFINITIONS = [
    ArcDefinition(
        arc_id="arc_1",
        title="The Upstart",
        entry_conditions={},  # No conditions — starting arc
        exit_conditions={
            "arc1_crystal_discovered": True,
            "arc1_dave_met": True,
            "arc1_death_glimpsed": True
        },
        next_arc_id="arc_2"
    ),
    ArcDefinition(
        arc_id="arc_2",
        title="The Squeeze",
        entry_conditions={"arc1_crystal_discovered": True, "arc1_dave_met": True, "arc1_death_glimpsed": True},
        exit_conditions={
            "arc2_route_resolved": lambda v: v is not None,
            "arc2_death_betrayal": True,
            "arc2_lion_response": lambda v: v is not None
        },
        next_arc_id="arc_3"
    ),
    ArcDefinition(
        arc_id="arc_3",
        title="The Alliance",
        entry_conditions={"arc2_route_resolved": lambda v: v is not None},
        exit_conditions={
            "arc3_alien_contact": True,
            "arc3_dave_parley": True,
            "arc3_death_allegiance": lambda v: v is not None
        },
        next_arc_id="arc_4"
    ),
    ArcDefinition(
        arc_id="arc_4",
        title="The Reckoning",
        entry_conditions={"arc3_alien_contact": True, "arc3_dave_parley": True},
        exit_conditions={},  # Ends with ending selection
        next_arc_id=None
    ),
]
```

---

*Cross-references: See PRD-002 for story arc and narrative choice requirements. See PRD-003 for character and faction requirements. See TRD-001 for module structure and architecture principles. See TRD-002 for encounter engine implementation.*

*TRD-003 v0.2 | Whisper Crystals | Creative Development Confidential*
