"""Master game state — single source of truth for all runtime data."""

from __future__ import annotations

from dataclasses import dataclass, field

from whisper_crystals.entities.character import (
    BehaviourState,
    Character,
    CharacterStats,
    Species,
)
from whisper_crystals.entities.crystal import CrystalDeposit, CrystalMarket, SupplyRoute
from whisper_crystals.entities.faction import Faction
from whisper_crystals.entities.ship import Ship, ShipStats
from whisper_crystals.entities.side_mission import SideMission


@dataclass
class PlayerDecision:
    decision_id: str
    encounter_id: str
    choice_id: str
    arc_id: str
    timestamp: float
    outcome_weight: float
    consequences_applied: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "decision_id": self.decision_id,
            "encounter_id": self.encounter_id,
            "choice_id": self.choice_id,
            "arc_id": self.arc_id,
            "timestamp": self.timestamp,
            "outcome_weight": self.outcome_weight,
            "consequences_applied": self.consequences_applied,
        }

    @classmethod
    def from_dict(cls, data: dict) -> PlayerDecision:
        return cls(
            decision_id=data["decision_id"],
            encounter_id=data["encounter_id"],
            choice_id=data["choice_id"],
            arc_id=data["arc_id"],
            timestamp=data["timestamp"],
            outcome_weight=data["outcome_weight"],
            consequences_applied=data.get("consequences_applied", {}),
        )


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

    # Economy
    crystal_deposits: dict[str, CrystalDeposit] = field(default_factory=dict)
    supply_routes: dict[str, SupplyRoute] = field(default_factory=dict)
    crystal_market: CrystalMarket = field(default_factory=CrystalMarket)
    trade_ledger: list[dict] = field(default_factory=list)

    # Story
    story_flags: dict[str, object] = field(default_factory=dict)
    player_decisions: list[PlayerDecision] = field(default_factory=list)
    completed_encounters: list[str] = field(default_factory=list)

    # Side missions
    side_missions: dict[str, SideMission] = field(default_factory=dict)

    def to_dict(self) -> dict:
        """Serialise the entire game state to a JSON-compatible dict."""
        return {
            "version": self.version,
            "save_slot": self.save_slot,
            "playtime_seconds": self.playtime_seconds,
            "current_arc": self.current_arc,
            "player_character": self.player_character.to_dict(),
            "player_ship": self.player_ship.to_dict(),
            "fleet": [s.to_dict() for s in self.fleet],
            "current_region": self.current_region,
            "position_x": self.position_x,
            "position_y": self.position_y,
            "crystal_inventory": self.crystal_inventory,
            "crystal_quality": self.crystal_quality,
            "salvage": self.salvage,
            "faction_registry": {
                fid: f.to_dict() for fid, f in self.faction_registry.items()
            },
            "relationship_matrix": self.relationship_matrix,
            "cascade_rules": self.cascade_rules,
            "npc_registry": {
                nid: n.to_dict() for nid, n in self.npc_registry.items()
            },
            "crystal_deposits": {
                did: d.to_dict() for did, d in self.crystal_deposits.items()
            },
            "supply_routes": {
                rid: r.to_dict() for rid, r in self.supply_routes.items()
            },
            "crystal_market": self.crystal_market.to_dict(),
            "trade_ledger": list(self.trade_ledger),
            "story_flags": self.story_flags,
            "player_decisions": [d.to_dict() for d in self.player_decisions],
            "completed_encounters": self.completed_encounters,
            "side_missions": {
                mid: m.to_dict() for mid, m in self.side_missions.items()
            },
        }

    @classmethod
    def from_dict(cls, data: dict) -> GameStateData:
        """Restore game state from a JSON-compatible dict."""
        state = cls(
            version=data.get("version", "0.1.0"),
            save_slot=data.get("save_slot", 0),
            playtime_seconds=data.get("playtime_seconds", 0.0),
            current_arc=data.get("current_arc", "arc_1"),
            player_character=Character.from_dict(data["player_character"]),
            player_ship=Ship.from_dict(data["player_ship"]),
            fleet=[Ship.from_dict(s) for s in data.get("fleet", [])],
            current_region=data.get("current_region", "starting_realm"),
            position_x=data.get("position_x", 0.0),
            position_y=data.get("position_y", 0.0),
            crystal_inventory=data.get("crystal_inventory", 0),
            crystal_quality=data.get("crystal_quality", 1),
            salvage=data.get("salvage", 0),
            relationship_matrix=data.get("relationship_matrix", {}),
            cascade_rules=data.get("cascade_rules", []),
            crystal_market=CrystalMarket.from_dict(data.get("crystal_market", {})),
            trade_ledger=data.get("trade_ledger", []),
            story_flags=data.get("story_flags", {}),
            player_decisions=[
                PlayerDecision.from_dict(d) for d in data.get("player_decisions", [])
            ],
            completed_encounters=data.get("completed_encounters", []),
        )
        # Restore faction registry
        for fid, fdata in data.get("faction_registry", {}).items():
            state.faction_registry[fid] = Faction.from_dict(fdata)
        # Restore NPC registry
        for nid, ndata in data.get("npc_registry", {}).items():
            state.npc_registry[nid] = Character.from_dict(ndata)
        # Restore crystal deposits
        for did, ddata in data.get("crystal_deposits", {}).items():
            state.crystal_deposits[did] = CrystalDeposit.from_dict(ddata)
        # Restore supply routes
        for rid, rdata in data.get("supply_routes", {}).items():
            state.supply_routes[rid] = SupplyRoute.from_dict(rdata)
        # Restore side missions
        for mid, mdata in data.get("side_missions", {}).items():
            state.side_missions[mid] = SideMission.from_dict(mdata)
        return state


def create_new_game_state(data_loader) -> GameStateData:
    """Initialise a fresh game state from JSON data files."""
    state = GameStateData()
    state.salvage = 50

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

    # Load economy data
    state.crystal_deposits = data_loader.load_crystal_deposits()
    state.supply_routes = data_loader.load_supply_routes()
    state.crystal_market = data_loader.load_crystal_market()

    # Initialise story flags for Arc 1
    state.story_flags = {
        "arc1_crystal_discovered": False,
        "arc1_dave_met": False,
        "arc1_death_glimpsed": False,
        "arc1_stance": None,
    }

    return state
