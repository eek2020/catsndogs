"""Whisper Crystal resource model — deposits, routes, market."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class CrystalDeposit:
    deposit_id: str
    location: str
    quantity_remaining: int
    quality_grade: int = 1  # 1 (raw) to 5 (refined premium)
    extraction_rate: int = 5
    is_discovered: bool = False
    is_active: bool = False

    def to_dict(self) -> dict:
        return {
            "deposit_id": self.deposit_id,
            "location": self.location,
            "quantity_remaining": self.quantity_remaining,
            "quality_grade": self.quality_grade,
            "extraction_rate": self.extraction_rate,
            "is_discovered": self.is_discovered,
            "is_active": self.is_active,
        }

    @classmethod
    def from_dict(cls, data: dict) -> CrystalDeposit:
        return cls(
            deposit_id=data["deposit_id"],
            location=data["location"],
            quantity_remaining=data["quantity_remaining"],
            quality_grade=data.get("quality_grade", 1),
            extraction_rate=data.get("extraction_rate", 5),
            is_discovered=data.get("is_discovered", False),
            is_active=data.get("is_active", False),
        )


@dataclass
class SupplyRoute:
    route_id: str
    origin: str
    destination: str
    status: str = "active"  # "active", "blockaded", "destroyed", "rerouted"
    capacity: int = 10
    risk_level: int = 1
    faction_threats: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "route_id": self.route_id,
            "origin": self.origin,
            "destination": self.destination,
            "status": self.status,
            "capacity": self.capacity,
            "risk_level": self.risk_level,
            "faction_threats": list(self.faction_threats),
        }

    @classmethod
    def from_dict(cls, data: dict) -> SupplyRoute:
        return cls(
            route_id=data["route_id"],
            origin=data["origin"],
            destination=data["destination"],
            status=data.get("status", "active"),
            capacity=data.get("capacity", 10),
            risk_level=data.get("risk_level", 1),
            faction_threats=data.get("faction_threats", []),
        )


@dataclass
class CrystalMarket:
    base_price: int = 100
    demand_multipliers: dict[str, float] = field(default_factory=dict)
    supply_modifier: float = 1.0

    def calculate_price(self, faction_id: str, faction_reputation: int) -> int:
        """Calculate crystal price for a specific faction."""
        base = self.base_price
        demand = self.demand_multipliers.get(faction_id, 1.0)
        supply = self.supply_modifier
        # Reputation discount/premium: -25% to +25%
        reputation_modifier = 1.0 - (faction_reputation / 400.0)
        price = int(base * demand * supply * reputation_modifier)
        return max(1, price)

    def to_dict(self) -> dict:
        return {
            "base_price": self.base_price,
            "demand_multipliers": dict(self.demand_multipliers),
            "supply_modifier": self.supply_modifier,
        }

    @classmethod
    def from_dict(cls, data: dict) -> CrystalMarket:
        return cls(
            base_price=data.get("base_price", 100),
            demand_multipliers=data.get("demand_multipliers", {}),
            supply_modifier=data.get("supply_modifier", 1.0),
        )
