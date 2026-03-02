"""Side mission entity — optional quests with tracking and rewards."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class MissionObjective:
    """A single trackable objective within a side mission."""

    objective_id: str
    description: str
    completed: bool = False
    encounter_id: str | None = None  # encounter that completes this objective

    def to_dict(self) -> dict:
        return {
            "objective_id": self.objective_id,
            "description": self.description,
            "completed": self.completed,
            "encounter_id": self.encounter_id,
        }

    @classmethod
    def from_dict(cls, data: dict) -> MissionObjective:
        return cls(
            objective_id=data["objective_id"],
            description=data["description"],
            completed=data.get("completed", False),
            encounter_id=data.get("encounter_id"),
        )


@dataclass
class SideMission:
    """An optional side mission with objectives and rewards.

    Side missions are discovered through encounters, distress signals,
    or faction NPCs. They track progress through objectives that link
    to encounter completions.
    """

    mission_id: str
    mission_type: str  # "bounty", "escort", "retrieval", "distress_signal"
    title: str
    description: str
    region: str = ""
    status: str = "available"  # "available", "active", "completed", "failed"
    objectives: list[MissionObjective] = field(default_factory=list)
    rewards: dict[str, int] = field(default_factory=dict)
    faction_rewards: dict[str, int] = field(default_factory=dict)
    trigger_conditions: dict[str, object] = field(default_factory=dict)
    discovery_encounter_id: str | None = None  # encounter that reveals this mission
    priority: int = 0

    @property
    def is_complete(self) -> bool:
        """True when all objectives are completed."""
        return len(self.objectives) > 0 and all(o.completed for o in self.objectives)

    def to_dict(self) -> dict:
        return {
            "mission_id": self.mission_id,
            "mission_type": self.mission_type,
            "title": self.title,
            "description": self.description,
            "region": self.region,
            "status": self.status,
            "objectives": [o.to_dict() for o in self.objectives],
            "rewards": self.rewards,
            "faction_rewards": self.faction_rewards,
            "trigger_conditions": self.trigger_conditions,
            "discovery_encounter_id": self.discovery_encounter_id,
            "priority": self.priority,
        }

    @classmethod
    def from_dict(cls, data: dict) -> SideMission:
        return cls(
            mission_id=data["mission_id"],
            mission_type=data["mission_type"],
            title=data["title"],
            description=data["description"],
            region=data.get("region", ""),
            status=data.get("status", "available"),
            objectives=[
                MissionObjective.from_dict(o)
                for o in data.get("objectives", [])
            ],
            rewards=data.get("rewards", {}),
            faction_rewards=data.get("faction_rewards", {}),
            trigger_conditions=data.get("trigger_conditions", {}),
            discovery_encounter_id=data.get("discovery_encounter_id"),
            priority=data.get("priority", 0),
        )
