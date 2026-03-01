"""Faction conquest AI — faction-vs-faction warfare and territorial expansion.

Simulates faction behaviour: aggression decisions, resource spending on
military actions, territorial claims, and alliances/conflicts between
non-player factions.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData


@dataclass
class ConquestAction:
    """A faction's planned military action."""

    action_id: str
    aggressor_id: str
    target_id: str
    action_type: str  # "attack", "blockade", "diplomacy", "fortify"
    strength: int = 0
    resolved: bool = False
    outcome: str = ""

    def to_dict(self) -> dict:
        return {
            "action_id": self.action_id,
            "aggressor_id": self.aggressor_id,
            "target_id": self.target_id,
            "action_type": self.action_type,
            "strength": self.strength,
            "resolved": self.resolved,
            "outcome": self.outcome,
        }

    @classmethod
    def from_dict(cls, data: dict) -> ConquestAction:
        return cls(
            action_id=data["action_id"],
            aggressor_id=data["aggressor_id"],
            target_id=data["target_id"],
            action_type=data["action_type"],
            strength=data.get("strength", 0),
            resolved=data.get("resolved", False),
            outcome=data.get("outcome", ""),
        )


class FactionConquestAI:
    """Simulates faction-vs-faction warfare and territorial dynamics."""

    def __init__(self, event_bus: EventBus) -> None:
        self.event_bus = event_bus
        self.pending_actions: list[ConquestAction] = []
        self.history: list[ConquestAction] = []
        self._turn_counter = 0

    # ------------------------------------------------------------------
    # AI decision-making
    # ------------------------------------------------------------------

    def plan_faction_actions(
        self, game_state: GameStateData, rng: random.Random | None = None,
    ) -> list[ConquestAction]:
        """Generate planned actions for all factions based on their AI traits.

        Called once per game tick/turn. Each faction decides whether to act
        based on conquest_intent, military_strength, and relationships.
        """
        if rng is None:
            rng = random.Random()

        self._turn_counter += 1
        new_actions: list[ConquestAction] = []

        for fid, faction in game_state.faction_registry.items():
            if fid == "felid_corsairs":
                continue  # Player faction doesn't auto-act

            # Decision threshold: compare conquest_intent against random roll
            if rng.randint(0, 100) > faction.conquest_intent:
                continue

            # Choose a target: faction with worst relationship
            target_id = self._pick_target(game_state, fid, rng)
            if target_id is None:
                continue

            # Choose action type based on faction personality
            action_type = self._choose_action_type(faction, rng)

            action = ConquestAction(
                action_id=f"turn{self._turn_counter}_{fid}_{target_id}",
                aggressor_id=fid,
                target_id=target_id,
                action_type=action_type,
                strength=faction.military_strength,
            )
            new_actions.append(action)

        self.pending_actions.extend(new_actions)
        return new_actions

    def _pick_target(
        self,
        game_state: GameStateData,
        faction_id: str,
        rng: random.Random,
    ) -> str | None:
        """Choose the most likely target for a faction's aggression."""
        relationships = game_state.relationship_matrix.get(faction_id, {})
        if not relationships:
            return None

        # Weight targets by negative relationship + some randomness
        candidates: list[tuple[str, int]] = []
        for target_id, rep in relationships.items():
            if target_id == faction_id:
                continue
            target = game_state.faction_registry.get(target_id)
            if target is None:
                continue
            # Lower reputation = higher target priority
            weight = max(1, 100 - rep + rng.randint(0, 30))
            candidates.append((target_id, weight))

        if not candidates:
            return None

        # Weighted random selection
        total = sum(w for _, w in candidates)
        roll = rng.randint(1, total)
        cumulative = 0
        for tid, w in candidates:
            cumulative += w
            if roll <= cumulative:
                return tid
        return candidates[-1][0]

    def _choose_action_type(self, faction, rng: random.Random) -> str:
        """Choose action type based on faction traits."""
        aggression = faction.aggression_level
        political = faction.political_influence

        if aggression > 30:
            options = ["attack", "attack", "blockade", "fortify"]
        elif political > 50:
            options = ["diplomacy", "diplomacy", "blockade", "fortify"]
        else:
            options = ["fortify", "blockade", "diplomacy", "attack"]

        return rng.choice(options)

    # ------------------------------------------------------------------
    # Action resolution
    # ------------------------------------------------------------------

    def resolve_actions(self, game_state: GameStateData) -> list[ConquestAction]:
        """Resolve all pending conquest actions.

        Returns list of resolved actions with outcomes.
        """
        resolved: list[ConquestAction] = []

        for action in self.pending_actions:
            if action.resolved:
                continue

            aggressor = game_state.faction_registry.get(action.aggressor_id)
            target = game_state.faction_registry.get(action.target_id)
            if aggressor is None or target is None:
                action.resolved = True
                action.outcome = "invalid"
                resolved.append(action)
                continue

            if action.action_type == "attack":
                self._resolve_attack(game_state, action, aggressor, target)
            elif action.action_type == "blockade":
                self._resolve_blockade(game_state, action, aggressor, target)
            elif action.action_type == "diplomacy":
                self._resolve_diplomacy(game_state, action, aggressor, target)
            elif action.action_type == "fortify":
                self._resolve_fortify(game_state, action, aggressor)

            action.resolved = True
            resolved.append(action)
            self.history.append(action)

        self.pending_actions = [a for a in self.pending_actions if not a.resolved]
        return resolved

    def _resolve_attack(self, game_state, action, aggressor, target) -> None:
        """Resolve an attack action: compare military strength."""
        attacker_power = aggressor.military_strength + aggressor.tactical_rating * 0.3
        defender_power = target.military_strength + target.internal_stability * 0.2

        if attacker_power > defender_power:
            # Attacker wins: target loses military strength and crystals
            loss = min(10, int((attacker_power - defender_power) * 0.2))
            target.military_strength = max(0, target.military_strength - loss)
            crystal_loot = min(target.crystal_reserves, loss * 2)
            target.crystal_reserves -= crystal_loot
            aggressor.crystal_reserves += crystal_loot
            target.internal_stability = max(0, target.internal_stability - 5)
            action.outcome = "victory"
        else:
            # Defender holds: attacker loses some strength
            loss = min(5, int((defender_power - attacker_power) * 0.1))
            aggressor.military_strength = max(0, aggressor.military_strength - loss)
            action.outcome = "repelled"

        self.event_bus.publish(
            "faction_conflict",
            aggressor_id=action.aggressor_id,
            target_id=action.target_id,
            action_type="attack",
            outcome=action.outcome,
        )

    def _resolve_blockade(self, game_state, action, aggressor, target) -> None:
        """Resolve a blockade: reduce target's supply effectiveness."""
        if aggressor.military_strength >= target.military_strength * 0.5:
            target.crystal_reserves = max(
                0, target.crystal_reserves - aggressor.military_strength // 5,
            )
            action.outcome = "blockade_effective"
        else:
            action.outcome = "blockade_broken"

        self.event_bus.publish(
            "faction_conflict",
            aggressor_id=action.aggressor_id,
            target_id=action.target_id,
            action_type="blockade",
            outcome=action.outcome,
        )

    def _resolve_diplomacy(self, game_state, action, aggressor, target) -> None:
        """Resolve diplomatic action: attempt to improve/worsen relations."""
        matrix = game_state.relationship_matrix
        current = matrix.get(action.aggressor_id, {}).get(action.target_id, 0)

        # Political influence determines success
        if aggressor.political_influence > 30:
            new_val = min(100, current + 10)
            action.outcome = "improved_relations"
        else:
            new_val = current  # Failed diplomacy
            action.outcome = "diplomacy_failed"

        if action.aggressor_id in matrix:
            matrix[action.aggressor_id][action.target_id] = new_val
        if action.target_id in matrix:
            matrix[action.target_id][action.aggressor_id] = new_val

        self.event_bus.publish(
            "faction_diplomacy",
            aggressor_id=action.aggressor_id,
            target_id=action.target_id,
            outcome=action.outcome,
        )

    def _resolve_fortify(self, game_state, action, aggressor) -> None:
        """Resolve fortify: faction invests in defense."""
        aggressor.military_strength = min(100, aggressor.military_strength + 3)
        aggressor.internal_stability = min(100, aggressor.internal_stability + 2)
        action.outcome = "fortified"

    # ------------------------------------------------------------------
    # Query helpers
    # ------------------------------------------------------------------

    def get_faction_threats(self, game_state: GameStateData, faction_id: str) -> list[str]:
        """Return faction IDs that have pending attack/blockade against this faction."""
        return [
            a.aggressor_id
            for a in self.pending_actions
            if a.target_id == faction_id and a.action_type in ("attack", "blockade")
        ]

    def get_recent_conflicts(self, limit: int = 10) -> list[dict]:
        """Return recent conflict history for UI display."""
        recent = self.history[-limit:] if self.history else []
        return [a.to_dict() for a in reversed(recent)]

    def get_power_rankings(self, game_state: GameStateData) -> list[dict]:
        """Return factions ranked by military power."""
        rankings = []
        for fid, faction in game_state.faction_registry.items():
            power = (
                faction.military_strength * 0.5
                + faction.tactical_rating * 0.3
                + faction.crystal_reserves * 0.1
                + faction.internal_stability * 0.1
            )
            rankings.append({
                "faction_id": fid,
                "name": faction.name,
                "military_strength": faction.military_strength,
                "power_score": round(power, 1),
            })
        rankings.sort(key=lambda r: -r["power_score"])
        return rankings
