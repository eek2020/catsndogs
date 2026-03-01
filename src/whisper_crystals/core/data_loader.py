"""JSON data loader — loads all game content from data/ directory."""

from __future__ import annotations

import json
import os
from typing import Any

from whisper_crystals.entities.encounter import Encounter
from whisper_crystals.entities.faction import Faction
from whisper_crystals.entities.ship import Ship, ShipStats


class DataLoader:
    """Loads and caches game data from JSON files in the data/ directory."""

    def __init__(self, data_root: str = "data") -> None:
        self.data_root = data_root
        self._cache: dict[str, Any] = {}

    def _load_json(self, relative_path: str) -> Any:
        """Load a JSON file, with caching."""
        if relative_path in self._cache:
            return self._cache[relative_path]
        full_path = os.path.join(self.data_root, relative_path)
        with open(full_path, encoding="utf-8") as f:
            data = json.load(f)
        self._cache[relative_path] = data
        return data

    def load_factions(self) -> dict[str, Faction]:
        """Load all factions from faction_registry.json."""
        data = self._load_json("factions/faction_registry.json")
        factions: dict[str, Faction] = {}
        for faction_data in data.get("factions", []):
            faction = Faction.from_dict(faction_data)
            factions[faction.faction_id] = faction
        return factions

    def load_relationship_matrix(self) -> dict[str, dict[str, int]]:
        """Load the inter-faction relationship matrix."""
        data = self._load_json("factions/faction_registry.json")
        return data.get("relationship_matrix", {})

    def load_cascade_rules(self) -> list[dict]:
        """Load faction cascade rules."""
        data = self._load_json("factions/faction_registry.json")
        return data.get("cascade_rules", [])

    def load_ship_templates(self) -> dict[str, dict]:
        """Load ship templates keyed by template_id."""
        data = self._load_json("ships/ship_templates.json")
        templates: dict[str, dict] = {}
        for tmpl in data.get("ship_templates", []):
            templates[tmpl["template_id"]] = tmpl
        return templates

    def load_upgrades(self) -> list[dict]:
        """Load available ship upgrades."""
        data = self._load_json("ships/ship_templates.json")
        return data.get("upgrades", [])

    def load_encounters(self, arc_id: str) -> list[Encounter]:
        """Load encounter definitions for a given arc."""
        filename = f"encounters/{arc_id}_encounters.json"
        try:
            data = self._load_json(filename)
        except FileNotFoundError:
            return []
        return [Encounter.from_dict(e) for e in data.get("encounters", [])]

    def load_arc_definitions(self) -> list[dict]:
        """Load story arc definitions."""
        data = self._load_json("story/arc_definitions.json")
        return data.get("arcs", [])

    def load_ending_thresholds(self) -> dict:
        """Load ending threshold configuration."""
        data = self._load_json("story/arc_definitions.json")
        return data.get("ending_thresholds", {})
