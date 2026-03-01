"""Encounter entity data model — triggers, choices, outcomes."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class EncounterOutcome:
    description: str = ""
    faction_changes: dict[str, int] = field(default_factory=dict)
    resource_changes: dict[str, int] = field(default_factory=dict)
    story_flags_set: list[str] = field(default_factory=list)
    story_flags_cleared: list[str] = field(default_factory=list)
    trigger_encounter_id: str | None = None

    @classmethod
    def from_dict(cls, data: dict) -> EncounterOutcome:
        return cls(
            description=data.get("description", ""),
            faction_changes=data.get("faction_changes", {}),
            resource_changes=data.get("resource_changes", {}),
            story_flags_set=data.get("story_flags_set", []),
            story_flags_cleared=data.get("story_flags_cleared", []),
            trigger_encounter_id=data.get("trigger_encounter_id"),
        )


@dataclass
class EncounterChoice:
    choice_id: str
    text: str
    conditions: dict = field(default_factory=dict)
    outcome: EncounterOutcome = field(default_factory=EncounterOutcome)
    outcome_weight: float = 0.0

    @classmethod
    def from_dict(cls, data: dict) -> EncounterChoice:
        outcome = EncounterOutcome.from_dict(data.get("outcome", {}))
        return cls(
            choice_id=data["choice_id"],
            text=data["text"],
            conditions=data.get("conditions", {}),
            outcome=outcome,
            outcome_weight=data.get("outcome_weight", 0.0),
        )


@dataclass
class Encounter:
    encounter_id: str
    encounter_type: str  # "combat", "trade", "diplomatic", "exploration"
    title: str
    description: str
    arc_id: str
    location: str
    trigger_conditions: dict = field(default_factory=dict)
    npc_ids: list[str] = field(default_factory=list)
    choices: list[EncounterChoice] = field(default_factory=list)
    priority: int = 0
    repeatable: bool = False

    @classmethod
    def from_dict(cls, data: dict) -> Encounter:
        choices = [EncounterChoice.from_dict(c) for c in data.get("choices", [])]
        return cls(
            encounter_id=data["encounter_id"],
            encounter_type=data["encounter_type"],
            title=data["title"],
            description=data["description"],
            arc_id=data["arc_id"],
            location=data.get("location", ""),
            trigger_conditions=data.get("trigger_conditions", {}),
            npc_ids=data.get("npc_ids", []),
            choices=choices,
            priority=data.get("priority", 0),
            repeatable=data.get("repeatable", False),
        )
