"""Economy system — crystal extraction, supply routes, trade, and faction economics.

Manages the flow of whisper crystals through the game world: deposits produce
crystals, supply routes move them between regions, and the market determines
prices based on faction demand, supply, and player reputation.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from whisper_crystals.entities.crystal import CrystalDeposit, CrystalMarket, SupplyRoute

if TYPE_CHECKING:
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData


class EconomySystem:
    """Manages crystal extraction, supply routes, market pricing, and trade."""

    def __init__(self, event_bus: EventBus) -> None:
        self.event_bus = event_bus

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
