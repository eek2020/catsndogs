"""Combat system — pure logic: damage model, ship combat data, combat log.

CombatState (the UI/GameState subclass) lives in ui/combat_ui.py.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field


@dataclass
class CombatShip:
    """Simplified ship representation for combat."""

    name: str
    faction_id: str
    speed: int
    armour: int
    firepower: int
    current_hull: int
    max_hull: int
    is_player: bool = False

    @classmethod
    def from_game_ship(cls, ship, is_player: bool = False) -> CombatShip:
        return cls(
            name=ship.name,
            faction_id=ship.faction_id,
            speed=ship.base_stats.speed,
            armour=ship.base_stats.armour,
            firepower=ship.base_stats.firepower,
            current_hull=ship.current_hull,
            max_hull=ship.max_hull,
            is_player=is_player,
        )

    @classmethod
    def from_template(cls, template: dict, name: str, faction_id: str) -> CombatShip:
        stats = template.get("base_stats", {})
        return cls(
            name=name,
            faction_id=faction_id,
            speed=stats.get("speed", 5),
            armour=stats.get("armour", 5),
            firepower=stats.get("firepower", 5),
            current_hull=template.get("max_hull", 100),
            max_hull=template.get("max_hull", 100),
        )


@dataclass
class CombatLog:
    entries: list[str] = field(default_factory=list)

    def add(self, text: str) -> None:
        self.entries.append(text)
        if len(self.entries) > 8:
            self.entries.pop(0)


def calculate_damage(attacker_fp: int, defender_armour: int) -> int:
    """Damage = attacker_firepower - defender_armour, min 1, with +/-20% variance."""
    base = max(1, attacker_fp - defender_armour)
    variance = random.uniform(0.8, 1.2)
    return max(1, int(base * variance))


def dodge_chance(defender_speed: int) -> float:
    """Dodge probability based on speed: speed 10 -> 40%, speed 1 -> 4%."""
    return min(0.45, defender_speed * 0.04)
