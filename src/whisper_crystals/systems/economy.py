"""Economy system — crystal extraction, supply routes, trade, and faction economics.

Manages the flow of whisper crystals through the game world: deposits produce
crystals, supply routes move them between regions, and the market determines
prices based on faction demand, supply, and player reputation.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from whisper_crystals.entities.crystal import CrystalDeposit, CrystalMarket, SupplyRoute
from whisper_crystals.entities.ship import Ship, ShipStats, ShipUpgrade

# Valid fields for upgrade target_stat validation
_VALID_UPGRADE_STATS: frozenset[str] = frozenset(ShipStats.__dataclass_fields__)

if TYPE_CHECKING:
    from whisper_crystals.core.data_loader import DataLoader
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData


class EconomySystem:
    """Manages crystal extraction, supply routes, market pricing, and trade."""

    def __init__(self, event_bus: EventBus, data_loader: DataLoader | None = None) -> None:
        self.event_bus = event_bus
        self.data_loader = data_loader

    # ------------------------------------------------------------------
    # Crystal extraction
    # ------------------------------------------------------------------

    def extract_crystals(self, game_state: GameStateData, deposit_id: str) -> int:
        """Extract crystals from an active deposit. Returns amount extracted."""
        deposit = game_state.crystal_deposits.get(deposit_id)
        if deposit is None or not deposit.is_active or not deposit.is_discovered:
            return 0

        amount = min(deposit.extraction_rate, deposit.quantity_remaining)
        if amount <= 0:
            return 0

        deposit.quantity_remaining -= amount
        game_state.crystal_inventory += amount

        # Update quality to match deposit if higher
        if deposit.quality_grade > game_state.crystal_quality:
            game_state.crystal_quality = deposit.quality_grade

        if deposit.quantity_remaining <= 0:
            deposit.is_active = False
            self.event_bus.publish(
                "deposit_depleted",
                deposit_id=deposit_id,
                location=deposit.location,
            )

        self.event_bus.publish(
            "crystals_extracted",
            deposit_id=deposit_id,
            amount=amount,
            remaining=deposit.quantity_remaining,
        )
        return amount

    def discover_deposit(self, game_state: GameStateData, deposit_id: str) -> bool:
        """Mark a deposit as discovered. Returns True if newly discovered."""
        deposit = game_state.crystal_deposits.get(deposit_id)
        if deposit is None or deposit.is_discovered:
            return False

        deposit.is_discovered = True
        self.event_bus.publish(
            "deposit_discovered",
            deposit_id=deposit_id,
            location=deposit.location,
            quality_grade=deposit.quality_grade,
        )
        return True

    def activate_deposit(self, game_state: GameStateData, deposit_id: str) -> bool:
        """Activate a discovered deposit for extraction. Returns True on success."""
        deposit = game_state.crystal_deposits.get(deposit_id)
        if deposit is None or not deposit.is_discovered or deposit.is_active:
            return False
        if deposit.quantity_remaining <= 0:
            return False

        deposit.is_active = True
        self.event_bus.publish(
            "deposit_activated",
            deposit_id=deposit_id,
            location=deposit.location,
        )
        return True

    # ------------------------------------------------------------------
    # Supply routes
    # ------------------------------------------------------------------

    def blockade_route(
        self, game_state: GameStateData, route_id: str, faction_id: str,
    ) -> bool:
        """Blockade a supply route. Returns True if status changed."""
        route = game_state.supply_routes.get(route_id)
        if route is None or route.status == "destroyed":
            return False

        old_status = route.status
        route.status = "blockaded"
        if faction_id not in route.faction_threats:
            route.faction_threats.append(faction_id)

        self.event_bus.publish(
            "route_status_changed",
            route_id=route_id,
            old_status=old_status,
            new_status="blockaded",
            faction_id=faction_id,
        )
        return True

    def restore_route(self, game_state: GameStateData, route_id: str) -> bool:
        """Restore a blockaded or rerouted supply route. Returns True if changed."""
        route = game_state.supply_routes.get(route_id)
        if route is None or route.status == "active" or route.status == "destroyed":
            return False

        old_status = route.status
        route.status = "active"
        self.event_bus.publish(
            "route_status_changed",
            route_id=route_id,
            old_status=old_status,
            new_status="active",
            faction_id=None,
        )
        return True

    def destroy_route(self, game_state: GameStateData, route_id: str) -> bool:
        """Permanently destroy a supply route. Returns True if changed."""
        route = game_state.supply_routes.get(route_id)
        if route is None or route.status == "destroyed":
            return False

        old_status = route.status
        route.status = "destroyed"
        self.event_bus.publish(
            "route_status_changed",
            route_id=route_id,
            old_status=old_status,
            new_status="destroyed",
            faction_id=None,
        )
        return True

    def get_active_routes(self, game_state: GameStateData) -> list[SupplyRoute]:
        """Return all active (non-blockaded, non-destroyed) supply routes."""
        return [
            r for r in game_state.supply_routes.values()
            if r.status == "active"
        ]

    def get_routes_for_region(
        self, game_state: GameStateData, region: str,
    ) -> list[SupplyRoute]:
        """Return all routes that touch a given region (origin or destination)."""
        return [
            r for r in game_state.supply_routes.values()
            if r.origin == region or r.destination == region
        ]

    # ------------------------------------------------------------------
    # Market & trade
    # ------------------------------------------------------------------

    def get_buy_price(
        self, game_state: GameStateData, faction_id: str, quantity: int = 1,
    ) -> int:
        """Calculate total cost to buy crystals from a faction."""
        faction = game_state.faction_registry.get(faction_id)
        if faction is None:
            return 0
        unit_price = game_state.crystal_market.calculate_price(
            faction_id, faction.reputation_with_player,
        )
        return unit_price * quantity

    def get_sell_price(
        self, game_state: GameStateData, faction_id: str, quantity: int = 1,
    ) -> int:
        """Calculate revenue from selling crystals to a faction.

        Sell price is 75% of buy price (trade margin).
        """
        buy_total = self.get_buy_price(game_state, faction_id, quantity)
        return max(1, int(buy_total * 0.75))

    def buy_crystals(
        self,
        game_state: GameStateData,
        faction_id: str,
        quantity: int,
    ) -> bool:
        """Buy crystals from a faction using salvage as currency.

        Returns True if purchase succeeded.
        """
        if quantity <= 0:
            return False

        faction = game_state.faction_registry.get(faction_id)
        if faction is None:
            return False

        # Faction must have reserves to sell
        if faction.crystal_reserves < quantity:
            return False

        cost = self.get_buy_price(game_state, faction_id, quantity)
        if game_state.salvage < cost:
            return False

        # Check cargo capacity
        capacity = game_state.player_ship.base_stats.crystal_capacity * 10
        current_load = game_state.crystal_inventory
        if current_load + quantity > capacity:
            return False

        game_state.salvage -= cost
        game_state.crystal_inventory += quantity
        faction.crystal_reserves -= quantity

        game_state.trade_ledger.append({
            "type": "buy",
            "faction_id": faction_id,
            "quantity": quantity,
            "cost": cost,
        })

        self.event_bus.publish(
            "trade_completed",
            trade_type="buy",
            faction_id=faction_id,
            quantity=quantity,
            cost=cost,
        )
        return True

    def sell_crystals(
        self,
        game_state: GameStateData,
        faction_id: str,
        quantity: int,
    ) -> bool:
        """Sell crystals to a faction, receiving salvage.

        Returns True if sale succeeded.
        """
        if quantity <= 0:
            return False

        faction = game_state.faction_registry.get(faction_id)
        if faction is None:
            return False

        if game_state.crystal_inventory < quantity:
            return False

        revenue = self.get_sell_price(game_state, faction_id, quantity)

        game_state.crystal_inventory -= quantity
        game_state.salvage += revenue
        faction.crystal_reserves += quantity

        game_state.trade_ledger.append({
            "type": "sell",
            "faction_id": faction_id,
            "quantity": quantity,
            "revenue": revenue,
        })

        self.event_bus.publish(
            "trade_completed",
            trade_type="sell",
            faction_id=faction_id,
            quantity=quantity,
            revenue=revenue,
        )
        return True

    # ------------------------------------------------------------------
    # Faction economics tick (called each game turn / navigation cycle)
    # ------------------------------------------------------------------

    def update_faction_economics(self, game_state: GameStateData) -> None:
        """Advance one tick of faction crystal production and consumption.

        Factions with crystal_production_rate > 0 gain reserves.
        Active supply routes distribute crystals.
        Blockaded routes reduce throughput.
        """
        for fid, faction in game_state.faction_registry.items():
            # Production
            if faction.crystal_production_rate > 0:
                faction.crystal_reserves += faction.crystal_production_rate

        # Supply route throughput: active routes move crystals between regions
        for route in game_state.supply_routes.values():
            if route.status != "active":
                continue
            # Find factions in origin that have production
            for fid, faction in game_state.faction_registry.items():
                if faction.realm == route.origin and faction.crystal_reserves > 0:
                    throughput = min(route.capacity, faction.crystal_reserves)
                    # Crystals flow through routes, increasing supply modifier
                    game_state.crystal_market.supply_modifier = min(
                        2.0,
                        game_state.crystal_market.supply_modifier + throughput * 0.001,
                    )

        # Demand pressure: factions without production increase demand
        for fid, faction in game_state.faction_registry.items():
            if faction.crystal_production_rate == 0 and faction.crystal_reserves < 50:
                current = game_state.crystal_market.demand_multipliers.get(fid, 1.0)
                game_state.crystal_market.demand_multipliers[fid] = min(
                    2.5, current + 0.02,
                )
            elif faction.crystal_reserves > 100:
                current = game_state.crystal_market.demand_multipliers.get(fid, 1.0)
                game_state.crystal_market.demand_multipliers[fid] = max(
                    0.5, current - 0.01,
                )

    # ------------------------------------------------------------------
    # Query helpers
    # ------------------------------------------------------------------

    def get_discovered_deposits(self, game_state: GameStateData) -> list[CrystalDeposit]:
        """Return all discovered deposits."""
        return [d for d in game_state.crystal_deposits.values() if d.is_discovered]

    def get_cargo_capacity(self, game_state: GameStateData) -> tuple[int, int]:
        """Return (current_load, max_capacity) for the player ship."""
        capacity = game_state.player_ship.base_stats.crystal_capacity * 10
        return game_state.crystal_inventory, capacity

    def get_trade_summary(self, game_state: GameStateData) -> dict:
        """Return summary of player's trade activity."""
        total_bought = sum(
            t["quantity"] for t in game_state.trade_ledger if t["type"] == "buy"
        )
        total_sold = sum(
            t["quantity"] for t in game_state.trade_ledger if t["type"] == "sell"
        )
        total_spent = sum(
            t.get("cost", 0) for t in game_state.trade_ledger if t["type"] == "buy"
        )
        total_earned = sum(
            t.get("revenue", 0) for t in game_state.trade_ledger if t["type"] == "sell"
        )
        return {
            "total_bought": total_bought,
            "total_sold": total_sold,
            "total_spent": total_spent,
            "total_earned": total_earned,
            "net_profit": total_earned - total_spent,
            "trade_count": len(game_state.trade_ledger),
        }

    # ------------------------------------------------------------------
    # Ship repair and upgrade system
    # ------------------------------------------------------------------

    def calculate_repair_cost(self, ship: Ship, repair_amount: int) -> int:
        """Calculate salvage cost to repair hull damage."""
        if repair_amount <= 0 or ship.current_hull >= ship.max_hull:
            return 0
        
        # Base cost per hull point varies by ship class
        base_cost_per_hull = ship.max_hull * 0.5  # 50% of max hull as base
        return int(base_cost_per_hull * (repair_amount / ship.max_hull))

    def repair_ship(self, game_state: GameStateData, repair_amount: int) -> bool:
        """Repair ship hull using salvage as currency."""
        ship = game_state.player_ship
        if repair_amount <= 0:
            return False
        
        # Can't repair beyond max hull
        actual_repair = min(repair_amount, ship.max_hull - ship.current_hull)
        if actual_repair <= 0:
            return False
        
        cost = self.calculate_repair_cost(ship, actual_repair)
        if game_state.salvage < cost:
            return False
        
        # Apply repair and cost
        game_state.salvage -= cost
        ship.current_hull += actual_repair
        
        game_state.trade_ledger.append({
            "type": "repair",
            "repair_amount": actual_repair,
            "cost": cost,
        })
        
        self.event_bus.publish(
            "ship_repaired",
            repair_amount=actual_repair,
            cost=cost,
            current_hull=ship.current_hull,
            max_hull=ship.max_hull,
        )
        return True

    def purchase_upgrade(self, game_state: GameStateData, upgrade_id: str) -> bool:
        """Purchase and install a ship upgrade."""
        if self.data_loader is None:
            return False
        upgrades = self.data_loader.load_upgrades()
        
        upgrade_data = None
        for upg in upgrades:
            if upg["upgrade_id"] == upgrade_id:
                upgrade_data = upg
                break
        
        if not upgrade_data:
            return False
        
        ship = game_state.player_ship
        
        # Check if upgrade already installed
        for existing in ship.upgrades:
            if existing.upgrade_id == upgrade_id:
                return False
        
        # Check resources
        if game_state.crystal_inventory < upgrade_data.get("cost_crystals", 0):
            return False
        if game_state.salvage < upgrade_data.get("cost_salvage", 0):
            return False
        
        # Check stat caps (max 15 for most stats)
        upgrade = ShipUpgrade.from_dict(upgrade_data)
        if upgrade.target_stat not in _VALID_UPGRADE_STATS:
            return False
        current_stat = getattr(ship.base_stats, upgrade.target_stat, 0)
        if current_stat + upgrade.modifier > 15:
            return False

        # Apply upgrade
        game_state.crystal_inventory -= upgrade.cost_crystals
        game_state.salvage -= upgrade.cost_salvage
        ship.upgrades.append(upgrade)

        # Apply stat modifier
        setattr(ship.base_stats, upgrade.target_stat, current_stat + upgrade.modifier)

        # Apply side effects if any
        if "side_effect" in upgrade_data:
            side_effect = upgrade_data["side_effect"]
            if side_effect["target_stat"] not in _VALID_UPGRADE_STATS:
                return True  # Upgrade applied, but skip invalid side effect
            side_stat = getattr(ship.base_stats, side_effect["target_stat"], 0)
            setattr(ship.base_stats, side_effect["target_stat"],
                    side_stat + side_effect["modifier"])
        
        game_state.trade_ledger.append({
            "type": "upgrade",
            "upgrade_id": upgrade_id,
            "cost_crystals": upgrade.cost_crystals,
            "cost_salvage": upgrade.cost_salvage,
        })
        
        self.event_bus.publish(
            "upgrade_purchased",
            upgrade_id=upgrade_id,
            target_stat=upgrade.target_stat,
            modifier=upgrade.modifier,
        )
        return True

    def calculate_ship_trade_in_value(self, ship: Ship) -> int:
        """Calculate trade-in value for current ship."""
        base_value = ship.max_hull * 2  # Base value from hull
        
        # Add value from upgrades
        upgrade_value = sum(upg.cost_salvage * 0.5 for upg in ship.upgrades)
        
        # Condition bonus/penalty
        condition_factor = ship.current_hull / ship.max_hull
        
        return int((base_value + upgrade_value) * condition_factor)

    def purchase_ship(self, game_state: GameStateData, template_id: str) -> bool:
        """Purchase a new ship, trading in current ship."""
        if self.data_loader is None:
            return False
        ship_templates = self.data_loader.load_ship_templates()
        
        template_data = ship_templates.get(template_id)
        if not template_data:
            return False
        
        # Check faction reputation
        faction_id = template_data["faction_id"]
        faction = game_state.faction_registry.get(faction_id)
        if not faction or faction.reputation_with_player < 0:
            return False
        
        # Calculate costs
        new_ship = Ship.from_template(template_data, "player_new_ship", template_data["name"])
        trade_in_value = self.calculate_ship_trade_in_value(game_state.player_ship)
        purchase_cost = new_ship.max_hull * 3  # Base cost
        net_cost = max(0, purchase_cost - trade_in_value)
        
        # Check resources
        if game_state.salvage < net_cost:
            return False
        
        # Handle cargo transfer
        old_capacity = game_state.player_ship.base_stats.crystal_capacity * 10
        new_capacity = new_ship.base_stats.crystal_capacity * 10
        
        if game_state.crystal_inventory > new_capacity:
            # Can't transfer all cargo, abort
            return False
        
        # Handle crew transfer
        if len(game_state.player_ship.crew) > new_ship.base_stats.crew_capacity:
            # Can't transfer all crew, abort
            return False
        
        # Execute purchase
        game_state.salvage -= net_cost
        
        # Transfer cargo and crew
        new_ship.crystal_cargo = game_state.player_ship.crystal_cargo
        new_ship.crew = game_state.player_ship.crew.copy()
        
        # Transfer compatible upgrades
        for upgrade in game_state.player_ship.upgrades:
            # Simple compatibility check - same target stat
            if hasattr(new_ship.base_stats, upgrade.target_stat):
                new_ship.upgrades.append(upgrade)
                # Apply upgrade stats to new ship
                current_stat = getattr(new_ship.base_stats, upgrade.target_stat, 0)
                setattr(new_ship.base_stats, upgrade.target_stat, current_stat + upgrade.modifier)
        
        # Replace player ship
        game_state.player_ship = new_ship
        
        game_state.trade_ledger.append({
            "type": "ship_purchase",
            "template_id": template_id,
            "trade_in_value": trade_in_value,
            "purchase_cost": purchase_cost,
            "net_cost": net_cost,
        })
        
        self.event_bus.publish(
            "ship_purchased",
            template_id=template_id,
            ship_name=new_ship.name,
            net_cost=net_cost,
        )
        return True
