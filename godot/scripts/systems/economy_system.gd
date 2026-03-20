## Economy system — crystal extraction, supply routes, trade, faction economics.
## Mirrors Python systems/economy.py.
class_name EconomySystem
extends RefCounted

var data_loader: DataLoader = null


func _init(p_data_loader: DataLoader = null) -> void:
	data_loader = p_data_loader


# ------------------------------------------------------------------
# Crystal extraction
# ------------------------------------------------------------------

func extract_crystals(game_state: GameStateData, deposit_id: String) -> int:
	var deposit: CrystalDeposit = game_state.crystal_deposits.get(deposit_id)
	if deposit == null or not deposit.is_active or not deposit.is_discovered:
		return 0
	var amount := mini(deposit.extraction_rate, deposit.quantity_remaining)
	if amount <= 0:
		return 0
	deposit.quantity_remaining -= amount
	game_state.crystal_inventory += amount
	if deposit.quality_grade > game_state.crystal_quality:
		game_state.crystal_quality = deposit.quality_grade
	if deposit.quantity_remaining <= 0:
		deposit.is_active = false
	EventBus.crystal_pickup.emit()
	return amount


func discover_deposit(game_state: GameStateData, deposit_id: String) -> bool:
	var deposit: CrystalDeposit = game_state.crystal_deposits.get(deposit_id)
	if deposit == null or deposit.is_discovered:
		return false
	deposit.is_discovered = true
	return true


func activate_deposit(game_state: GameStateData, deposit_id: String) -> bool:
	var deposit: CrystalDeposit = game_state.crystal_deposits.get(deposit_id)
	if deposit == null or not deposit.is_discovered or deposit.is_active:
		return false
	if deposit.quantity_remaining <= 0:
		return false
	deposit.is_active = true
	return true


# ------------------------------------------------------------------
# Supply routes
# ------------------------------------------------------------------

func blockade_route(game_state: GameStateData, route_id: String, faction_id: String) -> bool:
	var route: CrystalDeposit.SupplyRoute = game_state.supply_routes.get(route_id)
	if route == null or route.status == "destroyed":
		return false
	route.status = "blockaded"
	if faction_id not in route.faction_threats:
		route.faction_threats.append(faction_id)
	return true


func restore_route(game_state: GameStateData, route_id: String) -> bool:
	var route: CrystalDeposit.SupplyRoute = game_state.supply_routes.get(route_id)
	if route == null or route.status == "active" or route.status == "destroyed":
		return false
	route.status = "active"
	return true


func destroy_route(game_state: GameStateData, route_id: String) -> bool:
	var route: CrystalDeposit.SupplyRoute = game_state.supply_routes.get(route_id)
	if route == null or route.status == "destroyed":
		return false
	route.status = "destroyed"
	return true


func get_active_routes(game_state: GameStateData) -> Array:
	var result: Array = []
	for r in game_state.supply_routes.values():
		if r.status == "active":
			result.append(r)
	return result


# ------------------------------------------------------------------
# Market & trade
# ------------------------------------------------------------------

func get_buy_price(game_state: GameStateData, faction_id: String, quantity: int = 1) -> int:
	var faction: Faction = game_state.faction_registry.get(faction_id)
	if faction == null:
		return 0
	var unit_price: int = game_state.crystal_market.calculate_price(
		faction_id, faction.reputation_with_player
	)
	return unit_price * quantity


func get_sell_price(game_state: GameStateData, faction_id: String, quantity: int = 1) -> int:
	var buy_total := get_buy_price(game_state, faction_id, quantity)
	return maxi(1, int(buy_total * 0.75))


func buy_crystals(game_state: GameStateData, faction_id: String, quantity: int) -> bool:
	if quantity <= 0:
		return false
	var faction: Faction = game_state.faction_registry.get(faction_id)
	if faction == null:
		return false
	if faction.crystal_reserves < quantity:
		return false
	var cost := get_buy_price(game_state, faction_id, quantity)
	if game_state.salvage < cost:
		return false
	var capacity: int = game_state.player_ship.crystal_capacity * 10
	if game_state.crystal_inventory + quantity > capacity:
		return false
	game_state.salvage -= cost
	game_state.crystal_inventory += quantity
	faction.crystal_reserves -= quantity
	game_state.trade_ledger.append({
		"type": "buy", "faction_id": faction_id, "quantity": quantity, "cost": cost,
	})
	EventBus.trade_buy.emit()
	return true


func sell_crystals(game_state: GameStateData, faction_id: String, quantity: int) -> bool:
	if quantity <= 0:
		return false
	var faction: Faction = game_state.faction_registry.get(faction_id)
	if faction == null:
		return false
	if game_state.crystal_inventory < quantity:
		return false
	var revenue := get_sell_price(game_state, faction_id, quantity)
	game_state.crystal_inventory -= quantity
	game_state.salvage += revenue
	faction.crystal_reserves += quantity
	game_state.trade_ledger.append({
		"type": "sell", "faction_id": faction_id, "quantity": quantity, "revenue": revenue,
	})
	EventBus.trade_sell.emit()
	return true


# ------------------------------------------------------------------
# Faction economics tick
# ------------------------------------------------------------------

func update_faction_economics(game_state: GameStateData) -> void:
	for fid in game_state.faction_registry:
		var faction: Faction = game_state.faction_registry[fid]
		if faction.crystal_production_rate > 0:
			faction.crystal_reserves += faction.crystal_production_rate
	for route in game_state.supply_routes.values():
		if route.status != "active":
			continue
		for fid in game_state.faction_registry:
			var faction: Faction = game_state.faction_registry[fid]
			if faction.realm == route.origin and faction.crystal_reserves > 0:
				var throughput := mini(route.capacity, faction.crystal_reserves)
				game_state.crystal_market.supply_modifier = minf(
					2.0, game_state.crystal_market.supply_modifier + throughput * 0.001
				)
	for fid in game_state.faction_registry:
		var faction: Faction = game_state.faction_registry[fid]
		if faction.crystal_production_rate == 0 and faction.crystal_reserves < 50:
			var current: float = game_state.crystal_market.demand_multipliers.get(fid, 1.0)
			game_state.crystal_market.demand_multipliers[fid] = minf(2.5, current + 0.02)
		elif faction.crystal_reserves > 100:
			var current: float = game_state.crystal_market.demand_multipliers.get(fid, 1.0)
			game_state.crystal_market.demand_multipliers[fid] = maxf(0.5, current - 0.01)


# ------------------------------------------------------------------
# Ship repair and upgrade
# ------------------------------------------------------------------

func calculate_repair_cost(ship: Ship, repair_amount: int) -> int:
	if repair_amount <= 0 or ship.current_hull >= ship.max_hull:
		return 0
	var base_cost_per_hull: float = ship.max_hull * 0.5
	var cost := int(base_cost_per_hull * (float(repair_amount) / ship.max_hull))
	if GameSession.crew_trait_system != null:
		var repair_bonus: float = GameSession.crew_trait_system.get_bonus(ship, "hull_repair_rate")
		if repair_bonus > 0.0:
			cost = maxi(1, int(cost * (1.0 - repair_bonus)))
	return cost


func repair_ship(game_state: GameStateData, repair_amount: int) -> bool:
	var ship := game_state.player_ship
	if repair_amount <= 0:
		return false
	var actual_repair := mini(repair_amount, ship.max_hull - ship.current_hull)
	if actual_repair <= 0:
		return false
	var cost := calculate_repair_cost(ship, actual_repair)
	if game_state.salvage < cost:
		return false
	game_state.salvage -= cost
	ship.current_hull += actual_repair
	game_state.trade_ledger.append({
		"type": "repair", "repair_amount": actual_repair, "cost": cost,
	})
	return true


func purchase_ship(game_state: GameStateData, template: Dictionary) -> bool:
	"""Buy a new ship, replacing the player's current vessel. Crew transfers over."""
	var ship := game_state.player_ship
	if ship == null:
		return false
	var cost_crystals: int = template.get("cost_crystals", 0)
	var cost_salvage: int = template.get("cost_salvage", 0)
	if game_state.crystal_inventory < cost_crystals or game_state.salvage < cost_salvage:
		return false
	# Already flying this class?
	if ship.ship_class == template.get("template_id", ""):
		return false
	# Deduct costs
	game_state.crystal_inventory -= cost_crystals
	game_state.salvage -= cost_salvage
	# Create new ship from template, preserving crew and cargo
	var old_crew: Array = ship.crew.duplicate()
	var old_cargo: int = ship.crystal_cargo
	var new_ship := Ship.from_template(template, ship.ship_id, ship.ship_name)
	new_ship.crew = old_crew
	new_ship.crystal_cargo = old_cargo
	game_state.player_ship = new_ship
	game_state.trade_ledger.append({
		"type": "ship_purchase",
		"template_id": template.get("template_id", ""),
		"cost_crystals": cost_crystals,
		"cost_salvage": cost_salvage,
	})
	EventBus.ship_purchased.emit(template.get("template_id", ""))
	return true


func purchase_upgrade(game_state: GameStateData, upgrade_data: Dictionary) -> bool:
	"""Buy and apply an upgrade to the player's ship."""
	var ship := game_state.player_ship
	if ship == null:
		return false
	var cost_crystals: int = upgrade_data.get("cost_crystals", 0)
	var cost_salvage: int = upgrade_data.get("cost_salvage", 0)
	if game_state.crystal_inventory < cost_crystals or game_state.salvage < cost_salvage:
		return false
	# Check for duplicate upgrade
	var uid: String = upgrade_data.get("upgrade_id", "")
	for existing in ship.upgrades:
		if existing.upgrade_id == uid:
			return false
	# Deduct costs
	game_state.crystal_inventory -= cost_crystals
	game_state.salvage -= cost_salvage
	# Apply stat modifier
	var target_stat: String = upgrade_data.get("target_stat", "")
	var modifier: int = upgrade_data.get("modifier", 0)
	_apply_stat_modifier(ship, target_stat, modifier)
	# Apply side effect if present
	var side_effect: Dictionary = upgrade_data.get("side_effect", {})
	if not side_effect.is_empty():
		_apply_stat_modifier(ship, side_effect.get("target_stat", ""), side_effect.get("modifier", 0))
	# Record the upgrade
	var su := Ship.ShipUpgrade.from_dict(upgrade_data)
	ship.upgrades.append(su)
	EventBus.upgrade_purchased.emit(uid)
	return true


func _apply_stat_modifier(ship: Ship, stat: String, modifier: int) -> void:
	"""Apply a numeric modifier to a ship stat."""
	match stat:
		"speed":
			ship.speed = maxi(1, ship.speed + modifier)
		"armour":
			ship.armour = maxi(1, ship.armour + modifier)
		"firepower":
			ship.firepower = maxi(1, ship.firepower + modifier)
		"crystal_capacity":
			ship.crystal_capacity = maxi(1, ship.crystal_capacity + modifier)
		"crew_capacity":
			ship.crew_capacity = maxi(1, ship.crew_capacity + modifier)


func get_discovered_deposits(game_state: GameStateData) -> Array:
	var result: Array = []
	for d in game_state.crystal_deposits.values():
		if d.is_discovered:
			result.append(d)
	return result


func get_cargo_capacity(game_state: GameStateData) -> Array:
	var capacity: int = game_state.player_ship.crystal_capacity * 10
	return [game_state.crystal_inventory, capacity]


func get_trade_summary(game_state: GameStateData) -> Dictionary:
	var total_bought: int = 0
	var total_sold: int = 0
	var total_spent: int = 0
	var total_earned: int = 0
	for t in game_state.trade_ledger:
		if t["type"] == "buy":
			total_bought += int(t["quantity"])
			total_spent += int(t.get("cost", 0))
		elif t["type"] == "sell":
			total_sold += int(t["quantity"])
			total_earned += int(t.get("revenue", 0))
	return {
		"total_bought": total_bought,
		"total_sold": total_sold,
		"total_spent": total_spent,
		"total_earned": total_earned,
		"net_profit": total_earned - total_spent,
		"trade_count": game_state.trade_ledger.size(),
	}
