"""Faction entity data model — registry, relationships, abilities."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum, auto


class DiplomaticState(Enum):
    HOSTILE = auto()      # -100 to -51
    WARY = auto()         # -50 to -1
    NEUTRAL = auto()      # 0 to 25
    FRIENDLY = auto()     # 26 to 75
    ALLIED = auto()       # 76 to 100


@dataclass
class FactionAbility:
    ability_id: str
    name: str
    ability_type: str
    description: str
    effect: dict = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: dict) -> FactionAbility:
        return cls(
            ability_id=data["ability_id"],
            name=data["name"],
            ability_type=data.get("type", ""),
            description=data.get("description", ""),
            effect=data.get("effect", {}),
        )

    def to_dict(self) -> dict:
        return {
            "ability_id": self.ability_id,
            "name": self.name,
            "type": self.ability_type,
            "description": self.description,
            "effect": self.effect,
        }


@dataclass
class Faction:
    faction_id: str
    name: str
    species: str
    alignment: str
    government: str
    realm: str = ""
    ideology: str = ""
    reputation_with_player: int = 0  # -100 to +100
    diplomatic_state: DiplomaticState = DiplomaticState.NEUTRAL
    ship_template_id: str = ""
    conquest_intent: int = 50
    traits: list[str] = field(default_factory=list)
    abilities: list[FactionAbility] = field(default_factory=list)
    military_strength: int = 50
    crystal_reserves: int = 0
    crystal_production_rate: int = 0
    internal_stability: int = 100
    aggression_level: int = 0
    political_influence: int = 0
    tactical_rating: int = 0

    def update_diplomatic_state(self) -> None:
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

    @classmethod
    def from_dict(cls, data: dict) -> Faction:
        abilities = [FactionAbility.from_dict(a) for a in data.get("abilities", [])]
        faction = cls(
            faction_id=data["faction_id"],
            name=data["name"],
            species=data.get("species", ""),
            alignment=data.get("alignment", ""),
            government=data.get("government", ""),
            realm=data.get("realm", ""),
            ideology=data.get("ideology", ""),
            reputation_with_player=data.get(
                "reputation_with_player", data.get("starting_reputation", 0)
            ),
            ship_template_id=data.get("ship_template_id", ""),
            conquest_intent=data.get("conquest_intent", 50),
            traits=data.get("traits", []),
            abilities=abilities,
            military_strength=data.get("military_strength", 50),
            crystal_reserves=data.get("crystal_reserves", 0),
            crystal_production_rate=data.get("crystal_production_rate", 0),
            internal_stability=data.get("internal_stability", 100),
            aggression_level=data.get("aggression_level", 0),
            political_influence=data.get("political_influence", 0),
            tactical_rating=data.get("tactical_rating", 0),
        )
        faction.update_diplomatic_state()
        return faction

    def to_dict(self) -> dict:
        return {
            "faction_id": self.faction_id,
            "name": self.name,
            "species": self.species,
            "alignment": self.alignment,
            "government": self.government,
            "realm": self.realm,
            "ideology": self.ideology,
            "reputation_with_player": self.reputation_with_player,
            "diplomatic_state": self.diplomatic_state.name,
            "ship_template_id": self.ship_template_id,
            "conquest_intent": self.conquest_intent,
            "traits": self.traits,
            "abilities": [a.to_dict() for a in self.abilities],
            "military_strength": self.military_strength,
            "crystal_reserves": self.crystal_reserves,
            "crystal_production_rate": self.crystal_production_rate,
            "internal_stability": self.internal_stability,
            "aggression_level": self.aggression_level,
            "political_influence": self.political_influence,
            "tactical_rating": self.tactical_rating,
        }
