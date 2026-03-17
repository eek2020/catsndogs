## Whisper Crystal resource model — deposits, routes, market.
## Mirrors Python entities/crystal.py.
class_name CrystalDeposit
extends Resource

@export var deposit_id: String = ""
@export var location: String = ""
@export var quantity_remaining: int = 0
@export var quality_grade: int = 1
@export var extraction_rate: int = 5
@export var is_discovered: bool = false
@export var is_active: bool = false


func to_dict() -> Dictionary:
	return {
		"deposit_id": deposit_id,
		"location": location,
		"quantity_remaining": quantity_remaining,
		"quality_grade": quality_grade,
		"extraction_rate": extraction_rate,
		"is_discovered": is_discovered,
		"is_active": is_active,
	}


static func from_dict(data: Dictionary) -> CrystalDeposit:
	var d := CrystalDeposit.new()
	d.deposit_id = data.get("deposit_id", "")
	d.location = data.get("location", "")
	d.quantity_remaining = data.get("quantity_remaining", 0)
	d.quality_grade = data.get("quality_grade", 1)
	d.extraction_rate = data.get("extraction_rate", 5)
	d.is_discovered = data.get("is_discovered", false)
	d.is_active = data.get("is_active", false)
	return d


## -----------------------------------------------------------------------
## SupplyRoute
## -----------------------------------------------------------------------
class SupplyRoute extends Resource:
	@export var route_id: String = ""
	@export var origin: String = ""
	@export var destination: String = ""
	@export var status: String = "active"
	@export var capacity: int = 10
	@export var risk_level: int = 1
	@export var faction_threats: Array[String] = []

	func to_dict() -> Dictionary:
		return {
			"route_id": route_id,
			"origin": origin,
			"destination": destination,
			"status": status,
			"capacity": capacity,
			"risk_level": risk_level,
			"faction_threats": Array(faction_threats),
		}

	static func from_dict(data: Dictionary) -> SupplyRoute:
		var r := SupplyRoute.new()
		r.route_id = data.get("route_id", "")
		r.origin = data.get("origin", "")
		r.destination = data.get("destination", "")
		r.status = data.get("status", "active")
		r.capacity = data.get("capacity", 10)
		r.risk_level = data.get("risk_level", 1)
		r.faction_threats = Array(data.get("faction_threats", []), TYPE_STRING, "", null)
		return r


## -----------------------------------------------------------------------
## CrystalMarket
## -----------------------------------------------------------------------
class CrystalMarket extends Resource:
	@export var base_price: int = 100
	@export var demand_multipliers: Dictionary = {}
	@export var supply_modifier: float = 1.0

	func calculate_price(faction_id: String, faction_reputation: int) -> int:
		var base := base_price
		var demand: float = demand_multipliers.get(faction_id, 1.0)
		var supply := supply_modifier
		var reputation_modifier := 1.0 - (faction_reputation / 400.0)
		var price := int(base * demand * supply * reputation_modifier)
		return maxi(1, price)

	func to_dict() -> Dictionary:
		return {
			"base_price": base_price,
			"demand_multipliers": demand_multipliers.duplicate(),
			"supply_modifier": supply_modifier,
		}

	static func from_dict(data: Dictionary) -> CrystalMarket:
		var m := CrystalMarket.new()
		m.base_price = data.get("base_price", 100)
		m.demand_multipliers = data.get("demand_multipliers", {})
		m.supply_modifier = data.get("supply_modifier", 1.0)
		return m
