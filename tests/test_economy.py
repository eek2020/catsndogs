"""Tests for the economy system — extraction, routes, trade, faction economics."""

from __future__ import annotations

import pytest

from whisper_crystals.core.event_bus import EventBus
from whisper_crystals.core.game_state import GameStateData
from whisper_crystals.entities.crystal import CrystalDeposit, CrystalMarket, SupplyRoute
from whisper_crystals.entities.faction import Faction
from whisper_crystals.entities.ship import Ship, ShipStats
from whisper_crystals.systems.economy import EconomySystem


# ---- Fixtures ----

@pytest.fixture
def event_bus() -> EventBus:
    return EventBus()


@pytest.fixture
def economy(event_bus: EventBus) -> EconomySystem:
    return EconomySystem(event_bus)


@pytest.fixture
def game_state() -> GameStateData:
    """Minimal game state with economy data for testing."""
    state = GameStateData()
    state.crystal_inventory = 10
    state.salvage = 1000
    state.player_ship = Ship(
        ship_id="test_ship",
        name="Test Ship",
        faction_id="felid_corsairs",
        ship_class="corsair_raider",
        base_stats=ShipStats(crystal_capacity=5),  # capacity = 50
    )

    # Add deposits
    state.crystal_deposits = {
        "active_deposit": CrystalDeposit(
            deposit_id="active_deposit",
            location="feline_courts",
            quantity_remaining=100,
            quality_grade=3,
            extraction_rate=8,
            is_discovered=True,
            is_active=True,
        ),
        "undiscovered": CrystalDeposit(
            deposit_id="undiscovered",
            location="fairy_realms",
            quantity_remaining=200,
            quality_grade=4,
            extraction_rate=5,
            is_discovered=False,
            is_active=False,
        ),
        "empty_deposit": CrystalDeposit(
            deposit_id="empty_deposit",
            location="goblin_warrens",
            quantity_remaining=0,
            quality_grade=1,
            extraction_rate=10,
            is_discovered=True,
            is_active=False,
        ),
    }

    # Add supply routes
    state.supply_routes = {
        "route_a": SupplyRoute(
            route_id="route_a",
            origin="feline_courts",
            destination="goblin_warrens",
            status="active",
            capacity=15,
            risk_level=2,
        ),
        "route_b": SupplyRoute(
            route_id="route_b",
            origin="fairy_realms",
            destination="feline_courts",
            status="blockaded",
            capacity=10,
            risk_level=3,
            faction_threats=["canis_league"],
        ),
    }

    # Add factions
    state.faction_registry = {
        "felid_corsairs": Faction(
            faction_id="felid_corsairs",
            name="Felid Corsairs",
            species="cat",
            alignment="chaotic_independent",
            government="decentralised_captains",
            realm="feline_courts",
            crystal_reserves=200,
            crystal_production_rate=5,
            reputation_with_player=60,
        ),
        "canis_league": Faction(
            faction_id="canis_league",
            name="Canis League",
            species="dog",
            alignment="lawful_hierarchical",
            government="military_command",
            realm="canine_order",
            crystal_reserves=30,
            crystal_production_rate=0,
            reputation_with_player=-20,
        ),
    }

    # Market
    state.crystal_market = CrystalMarket(
        base_price=100,
        demand_multipliers={"felid_corsairs": 0.8, "canis_league": 1.5},
        supply_modifier=1.0,
    )

    return state


# ---- Crystal Extraction Tests ----

class TestCrystalExtraction:
    def test_extract_from_active_deposit(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        initial = game_state.crystal_inventory
        amount = economy.extract_crystals(game_state, "active_deposit")
        assert amount == 8
        assert game_state.crystal_inventory == initial + 8
        assert game_state.crystal_deposits["active_deposit"].quantity_remaining == 92

    def test_extract_updates_quality(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        game_state.crystal_quality = 1
        economy.extract_crystals(game_state, "active_deposit")
        assert game_state.crystal_quality == 3  # deposit quality grade

    def test_extract_from_undiscovered_returns_zero(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        amount = economy.extract_crystals(game_state, "undiscovered")
        assert amount == 0

    def test_extract_from_empty_deposit(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        amount = economy.extract_crystals(game_state, "empty_deposit")
        assert amount == 0

    def test_extract_depletes_deposit(
        self, economy: EconomySystem, game_state: GameStateData, event_bus: EventBus,
    ) -> None:
        game_state.crystal_deposits["active_deposit"].quantity_remaining = 3
        events: list[str] = []
        event_bus.subscribe("deposit_depleted", lambda **kw: events.append("depleted"))
        amount = economy.extract_crystals(game_state, "active_deposit")
        assert amount == 3
        assert not game_state.crystal_deposits["active_deposit"].is_active
        assert "depleted" in events

    def test_extract_nonexistent_deposit(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert economy.extract_crystals(game_state, "no_such_deposit") == 0


class TestDepositDiscovery:
    def test_discover_deposit(
        self, economy: EconomySystem, game_state: GameStateData, event_bus: EventBus,
    ) -> None:
        events: list[str] = []
        event_bus.subscribe("deposit_discovered", lambda **kw: events.append("found"))
        assert economy.discover_deposit(game_state, "undiscovered")
        assert game_state.crystal_deposits["undiscovered"].is_discovered
        assert "found" in events

    def test_discover_already_discovered(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert not economy.discover_deposit(game_state, "active_deposit")

    def test_activate_deposit(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        # First discover, then activate
        economy.discover_deposit(game_state, "undiscovered")
        assert economy.activate_deposit(game_state, "undiscovered")
        assert game_state.crystal_deposits["undiscovered"].is_active

    def test_activate_empty_deposit_fails(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert not economy.activate_deposit(game_state, "empty_deposit")


# ---- Supply Route Tests ----

class TestSupplyRoutes:
    def test_blockade_route(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert economy.blockade_route(game_state, "route_a", "wolves")
        assert game_state.supply_routes["route_a"].status == "blockaded"
        assert "wolves" in game_state.supply_routes["route_a"].faction_threats

    def test_restore_route(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert economy.restore_route(game_state, "route_b")
        assert game_state.supply_routes["route_b"].status == "active"

    def test_restore_active_route_no_op(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert not economy.restore_route(game_state, "route_a")

    def test_destroy_route(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert economy.destroy_route(game_state, "route_a")
        assert game_state.supply_routes["route_a"].status == "destroyed"

    def test_blockade_destroyed_route_fails(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        economy.destroy_route(game_state, "route_a")
        assert not economy.blockade_route(game_state, "route_a", "wolves")

    def test_get_active_routes(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        active = economy.get_active_routes(game_state)
        assert len(active) == 1
        assert active[0].route_id == "route_a"

    def test_get_routes_for_region(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        routes = economy.get_routes_for_region(game_state, "feline_courts")
        assert len(routes) == 2  # route_a (origin) and route_b (destination)


# ---- Trade Tests ----

class TestTrade:
    def test_buy_crystals(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        initial_salvage = game_state.salvage
        initial_crystals = game_state.crystal_inventory
        initial_reserves = game_state.faction_registry["canis_league"].crystal_reserves

        assert economy.buy_crystals(game_state, "canis_league", 5)
        assert game_state.crystal_inventory == initial_crystals + 5
        assert game_state.salvage < initial_salvage
        assert game_state.faction_registry["canis_league"].crystal_reserves == (
            initial_reserves - 5
        )
        assert len(game_state.trade_ledger) == 1

    def test_buy_insufficient_salvage(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        game_state.salvage = 0
        assert not economy.buy_crystals(game_state, "canis_league", 5)

    def test_buy_exceeds_cargo_capacity(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        game_state.crystal_inventory = 49  # capacity is 50
        assert not economy.buy_crystals(game_state, "canis_league", 5)

    def test_buy_exceeds_faction_reserves(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert not economy.buy_crystals(game_state, "canis_league", 999)

    def test_sell_crystals(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        initial_salvage = game_state.salvage
        initial_crystals = game_state.crystal_inventory
        initial_reserves = game_state.faction_registry["canis_league"].crystal_reserves

        assert economy.sell_crystals(game_state, "canis_league", 5)
        assert game_state.crystal_inventory == initial_crystals - 5
        assert game_state.salvage > initial_salvage
        assert game_state.faction_registry["canis_league"].crystal_reserves == (
            initial_reserves + 5
        )

    def test_sell_insufficient_crystals(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        game_state.crystal_inventory = 0
        assert not economy.sell_crystals(game_state, "canis_league", 5)

    def test_sell_price_less_than_buy(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        buy = economy.get_buy_price(game_state, "canis_league", 10)
        sell = economy.get_sell_price(game_state, "canis_league", 10)
        assert sell < buy

    def test_buy_zero_quantity(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert not economy.buy_crystals(game_state, "canis_league", 0)

    def test_sell_zero_quantity(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert not economy.sell_crystals(game_state, "canis_league", 0)

    def test_trade_with_nonexistent_faction(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        assert not economy.buy_crystals(game_state, "no_faction", 1)
        assert not economy.sell_crystals(game_state, "no_faction", 1)

    def test_trade_events(
        self, economy: EconomySystem, game_state: GameStateData, event_bus: EventBus,
    ) -> None:
        events: list[dict] = []
        event_bus.subscribe("trade_completed", lambda **kw: events.append(kw))
        economy.sell_crystals(game_state, "canis_league", 2)
        assert len(events) == 1
        assert events[0]["trade_type"] == "sell"
        assert events[0]["quantity"] == 2


# ---- Faction Economics Tests ----

class TestFactionEconomics:
    def test_production_increases_reserves(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        initial = game_state.faction_registry["felid_corsairs"].crystal_reserves
        economy.update_faction_economics(game_state)
        assert game_state.faction_registry["felid_corsairs"].crystal_reserves == (
            initial + 5
        )

    def test_non_producer_reserves_unchanged(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        initial = game_state.faction_registry["canis_league"].crystal_reserves
        economy.update_faction_economics(game_state)
        assert game_state.faction_registry["canis_league"].crystal_reserves == initial

    def test_demand_increases_for_low_reserves(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        initial_demand = game_state.crystal_market.demand_multipliers.get(
            "canis_league", 1.0,
        )
        economy.update_faction_economics(game_state)
        new_demand = game_state.crystal_market.demand_multipliers.get(
            "canis_league", 1.0,
        )
        assert new_demand > initial_demand


# ---- Query Helper Tests ----

class TestQueryHelpers:
    def test_get_discovered_deposits(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        discovered = economy.get_discovered_deposits(game_state)
        ids = {d.deposit_id for d in discovered}
        assert "active_deposit" in ids
        assert "empty_deposit" in ids
        assert "undiscovered" not in ids

    def test_get_cargo_capacity(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        current, cap = economy.get_cargo_capacity(game_state)
        assert current == 10
        assert cap == 50

    def test_get_trade_summary_empty(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        summary = economy.get_trade_summary(game_state)
        assert summary["trade_count"] == 0
        assert summary["net_profit"] == 0

    def test_get_trade_summary_after_trades(
        self, economy: EconomySystem, game_state: GameStateData,
    ) -> None:
        economy.sell_crystals(game_state, "canis_league", 5)
        economy.buy_crystals(game_state, "felid_corsairs", 3)
        summary = economy.get_trade_summary(game_state)
        assert summary["trade_count"] == 2
        assert summary["total_sold"] == 5
        assert summary["total_bought"] == 3


# ---- Serialisation Round-Trip ----

class TestSerialization:
    def test_crystal_deposit_round_trip(self) -> None:
        deposit = CrystalDeposit(
            deposit_id="test",
            location="test_realm",
            quantity_remaining=50,
            quality_grade=3,
        )
        restored = CrystalDeposit.from_dict(deposit.to_dict())
        assert restored.deposit_id == deposit.deposit_id
        assert restored.quantity_remaining == deposit.quantity_remaining
        assert restored.quality_grade == deposit.quality_grade

    def test_supply_route_round_trip(self) -> None:
        route = SupplyRoute(
            route_id="test_route",
            origin="a",
            destination="b",
            faction_threats=["wolves"],
        )
        restored = SupplyRoute.from_dict(route.to_dict())
        assert restored.route_id == route.route_id
        assert restored.faction_threats == route.faction_threats

    def test_crystal_market_round_trip(self) -> None:
        market = CrystalMarket(
            base_price=150,
            demand_multipliers={"test": 1.5},
            supply_modifier=0.8,
        )
        restored = CrystalMarket.from_dict(market.to_dict())
        assert restored.base_price == market.base_price
        assert restored.demand_multipliers == market.demand_multipliers
        assert restored.supply_modifier == market.supply_modifier
