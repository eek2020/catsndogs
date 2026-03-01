"""Character entity data model — Aristotle, Dave, Death, NPCs."""

from __future__ import annotations

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
    HIDDEN = auto()


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
    relationship_with_player: int = 0  # -100 to +100
    current_arc: str = "arc_1"
    is_player: bool = False
    true_allegiance: str | None = None  # Set in Arc 3 for Death
    portrait_sprite: str = ""
    dialogue_tree_id: str = ""

    @classmethod
    def from_dict(cls, data: dict) -> Character:
        """Create a Character from a JSON-compatible dict."""
        stats_data = data.get("stats", {})
        stats = CharacterStats(**stats_data) if stats_data else CharacterStats()
        species = Species[data.get("species", "CAT").upper()]
        behaviour = BehaviourState[data.get("behaviour_state", "IDLE").upper()]
        return cls(
            character_id=data["character_id"],
            name=data["name"],
            species=species,
            faction_id=data["faction_id"],
            title=data.get("title", ""),
            stats=stats,
            behaviour_state=behaviour,
            relationship_with_player=data.get("relationship_with_player", 0),
            current_arc=data.get("current_arc", "arc_1"),
            is_player=data.get("is_player", False),
            true_allegiance=data.get("true_allegiance"),
            portrait_sprite=data.get("portrait_sprite", ""),
            dialogue_tree_id=data.get("dialogue_tree_id", ""),
        )

    def to_dict(self) -> dict:
        """Serialise to a JSON-compatible dict."""
        return {
            "character_id": self.character_id,
            "name": self.name,
            "species": self.species.name,
            "faction_id": self.faction_id,
            "title": self.title,
            "stats": {
                "cunning": self.stats.cunning,
                "leadership": self.stats.leadership,
                "negotiation": self.stats.negotiation,
                "combat_skill": self.stats.combat_skill,
                "intimidation": self.stats.intimidation,
                "stealth": self.stats.stealth,
            },
            "behaviour_state": self.behaviour_state.name,
            "relationship_with_player": self.relationship_with_player,
            "current_arc": self.current_arc,
            "is_player": self.is_player,
            "true_allegiance": self.true_allegiance,
            "portrait_sprite": self.portrait_sprite,
            "dialogue_tree_id": self.dialogue_tree_id,
        }
