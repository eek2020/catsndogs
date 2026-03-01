"""Ship entity data model — stats, crew, upgrades."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class ShipStats:
    speed: int = 5
    armour: int = 5
    firepower: int = 5
    crystal_capacity: int = 5
    crew_capacity: int = 5

    @classmethod
    def from_dict(cls, data: dict) -> ShipStats:
        return cls(**{k: data[k] for k in cls.__dataclass_fields__ if k in data})

    def to_dict(self) -> dict:
        return {
            "speed": self.speed,
            "armour": self.armour,
            "firepower": self.firepower,
            "crystal_capacity": self.crystal_capacity,
            "crew_capacity": self.crew_capacity,
        }


@dataclass
class CrewMember:
    crew_id: str
    name: str
    species: str
    role: str  # "pilot", "gunner", "engineer", "diplomat"
    faction_origin: str
    skills: list[str] = field(default_factory=list)
    skill_level: int = 5
    morale: int = 100
    morale_modifier: int = 0
    faction_trait_bonus: str = ""

    @classmethod
    def from_dict(cls, data: dict) -> CrewMember:
        return cls(
            crew_id=data["crew_id"],
            name=data["name"],
            species=data.get("species", "cat"),
            role=data["role"],
            faction_origin=data.get("faction_origin", ""),
            skills=data.get("skills", []),
            skill_level=data.get("skill_level", 5),
            morale=data.get("morale", 100),
            morale_modifier=data.get("morale_modifier", 0),
            faction_trait_bonus=data.get("faction_trait_bonus", ""),
        )

    def to_dict(self) -> dict:
        return {
            "crew_id": self.crew_id,
            "name": self.name,
            "species": self.species,
            "role": self.role,
            "faction_origin": self.faction_origin,
            "skills": self.skills,
            "skill_level": self.skill_level,
            "morale": self.morale,
            "morale_modifier": self.morale_modifier,
            "faction_trait_bonus": self.faction_trait_bonus,
        }


@dataclass
class ShipUpgrade:
    upgrade_id: str
    name: str
    target_stat: str
    modifier: int
    cost_crystals: int = 0
    cost_salvage: int = 0

    @classmethod
    def from_dict(cls, data: dict) -> ShipUpgrade:
        return cls(
            upgrade_id=data["upgrade_id"],
            name=data["name"],
            target_stat=data["target_stat"],
            modifier=data["modifier"],
            cost_crystals=data.get("cost_crystals", 0),
            cost_salvage=data.get("cost_salvage", 0),
        )

    def to_dict(self) -> dict:
        return {
            "upgrade_id": self.upgrade_id,
            "name": self.name,
            "target_stat": self.target_stat,
            "modifier": self.modifier,
            "cost_crystals": self.cost_crystals,
            "cost_salvage": self.cost_salvage,
        }


@dataclass
class Ship:
    ship_id: str
    name: str
    faction_id: str
    ship_class: str
    base_stats: ShipStats = field(default_factory=ShipStats)
    current_hull: int = 100
    max_hull: int = 100
    crew: list[CrewMember] = field(default_factory=list)
    upgrades: list[ShipUpgrade] = field(default_factory=list)
    crystal_cargo: int = 0
    sprite_id: str = ""

    @classmethod
    def from_dict(cls, data: dict) -> Ship:
        stats = ShipStats.from_dict(data.get("base_stats", {}))
        crew = [CrewMember.from_dict(c) for c in data.get("crew", [])]
        upgrades = [ShipUpgrade.from_dict(u) for u in data.get("upgrades", [])]
        return cls(
            ship_id=data["ship_id"],
            name=data["name"],
            faction_id=data["faction_id"],
            ship_class=data.get("ship_class", ""),
            base_stats=stats,
            current_hull=data.get("current_hull", data.get("max_hull", 100)),
            max_hull=data.get("max_hull", 100),
            crew=crew,
            upgrades=upgrades,
            crystal_cargo=data.get("crystal_cargo", 0),
            sprite_id=data.get("sprite_id", ""),
        )

    @classmethod
    def from_template(cls, template: dict, ship_id: str, name: str) -> Ship:
        """Create a ship from a ship_templates.json entry."""
        stats = ShipStats.from_dict(template.get("base_stats", {}))
        return cls(
            ship_id=ship_id,
            name=name,
            faction_id=template.get("faction_id", ""),
            ship_class=template.get("template_id", ""),
            base_stats=stats,
            current_hull=template.get("max_hull", 100),
            max_hull=template.get("max_hull", 100),
            sprite_id=template.get("sprite_id", ""),
        )

    def to_dict(self) -> dict:
        return {
            "ship_id": self.ship_id,
            "name": self.name,
            "faction_id": self.faction_id,
            "ship_class": self.ship_class,
            "base_stats": self.base_stats.to_dict(),
            "current_hull": self.current_hull,
            "max_hull": self.max_hull,
            "crew": [c.to_dict() for c in self.crew],
            "upgrades": [u.to_dict() for u in self.upgrades],
            "crystal_cargo": self.crystal_cargo,
            "sprite_id": self.sprite_id,
        }
