## Exploration system — region discovery, points of interest, random events.
## Mirrors Python systems/exploration.py.
class_name ExplorationSystem
extends RefCounted

var regions: Dictionary = {}
var points_of_interest: Dictionary = {}

const EXPLORATION_EVENTS: Array = [
	{"type": "salvage_find", "weight": 30, "description": "Floating wreckage detected"},
	{"type": "crystal_trace", "weight": 20, "description": "Faint crystal signature"},
	{"type": "hostile_patrol", "weight": 25, "description": "Enemy patrol spotted"},
	{"type": "trader_vessel", "weight": 15, "description": "Merchant vessel hailing"},
	{"type": "anomaly", "weight": 10, "description": "Unknown energy signature"},
]


## -----------------------------------------------------------------------
## Region inner resource
## -----------------------------------------------------------------------
class Region extends Resource:
	@export var region_id: String = ""
	@export var region_name: String = ""
	@export var controlling_faction: String = ""
	@export var danger_level: int = 1
	@export var is_discovered: bool = false
	@export var is_accessible: bool = true
	@export var connected_regions: Array[String] = []

	func to_dict() -> Dictionary:
		return {
			"region_id": region_id,
			"name": region_name,
			"controlling_faction": controlling_faction,
			"danger_level": danger_level,
			"is_discovered": is_discovered,
			"is_accessible": is_accessible,
			"connected_regions": Array(connected_regions),
		}

	static func from_dict(data: Dictionary) -> Region:
		var r := Region.new()
		r.region_id = data.get("region_id", "")
		r.region_name = data.get("name", "")
		r.controlling_faction = data.get("controlling_faction", "")
		r.danger_level = data.get("danger_level", 1)
		r.is_discovered = data.get("is_discovered", false)
		r.is_accessible = data.get("is_accessible", true)
		r.connected_regions = Array(data.get("connected_regions", []), TYPE_STRING, "", null)
		return r


## -----------------------------------------------------------------------
## PointOfInterest inner resource
## -----------------------------------------------------------------------
class PointOfInterest extends Resource:
	@export var poi_id: String = ""
	@export var region: String = ""
	@export var poi_name: String = ""
	@export var poi_type: String = ""
	@export var description: String = ""
	@export var is_discovered: bool = false
	@export var is_visited: bool = false
	@export var rewards: Dictionary = {}
	@export var risk_level: int = 1

	func to_dict() -> Dictionary:
		return {
			"poi_id": poi_id,
			"region": region,
			"name": poi_name,
			"poi_type": poi_type,
			"description": description,
			"is_discovered": is_discovered,
			"is_visited": is_visited,
			"rewards": rewards.duplicate(),
			"risk_level": risk_level,
		}

	static func from_dict(data: Dictionary) -> PointOfInterest:
		var p := PointOfInterest.new()
		p.poi_id = data.get("poi_id", "")
		p.region = data.get("region", "")
		p.poi_name = data.get("name", "")
		p.poi_type = data.get("poi_type", "")
		p.description = data.get("description", "")
		p.is_discovered = data.get("is_discovered", false)
		p.is_visited = data.get("is_visited", false)
		p.rewards = data.get("rewards", {})
		p.risk_level = data.get("risk_level", 1)
		return p


func load_regions(region_data: Array) -> void:
	regions.clear()
	for data in region_data:
		var region := Region.from_dict(data)
		regions[region.region_id] = region


func load_pois(poi_data: Array) -> void:
	points_of_interest.clear()
	for data in poi_data:
		var poi := PointOfInterest.from_dict(data)
		points_of_interest[poi.poi_id] = poi


func discover_region(region_id: String) -> bool:
	var region: Region = regions.get(region_id)
	if region == null or region.is_discovered:
		return false
	region.is_discovered = true
	return true


func get_discovered_regions() -> Array:
	var result: Array = []
	for r in regions.values():
		if r.is_discovered:
			result.append(r)
	return result


func get_accessible_regions(current_region: String) -> Array:
	var region: Region = regions.get(current_region)
	if region == null:
		return []
	var result: Array = []
	for rid in region.connected_regions:
		if regions.has(rid) and regions[rid].is_accessible:
			result.append(regions[rid])
	return result


func travel_to_region(game_state: GameStateData, target_region: String) -> bool:
	var current: Region = regions.get(game_state.current_region)
	var target: Region = regions.get(target_region)
	if current == null or target == null:
		return false
	if not target.is_accessible:
		return false
	if target_region not in current.connected_regions:
		return false
	game_state.current_region = target_region
	if not target.is_discovered:
		discover_region(target_region)
	return true


func discover_poi(poi_id: String) -> bool:
	var poi: PointOfInterest = points_of_interest.get(poi_id)
	if poi == null or poi.is_discovered:
		return false
	poi.is_discovered = true
	return true


func visit_poi(game_state: GameStateData, poi_id: String) -> Dictionary:
	var poi: PointOfInterest = points_of_interest.get(poi_id)
	if poi == null or not poi.is_discovered or poi.is_visited:
		return {}
	if poi.region != game_state.current_region:
		return {}
	poi.is_visited = true
	var rewards := poi.rewards.duplicate()
	if rewards.has("crystals"):
		game_state.crystal_inventory += int(rewards["crystals"])
	if rewards.has("salvage"):
		game_state.salvage += int(rewards["salvage"])
	return rewards


func get_region_pois(region_id: String, discovered_only: bool = true) -> Array:
	var result: Array = []
	for p in points_of_interest.values():
		if p.region == region_id and (not discovered_only or p.is_discovered):
			result.append(p)
	return result


func roll_exploration_event(game_state: GameStateData) -> Dictionary:
	var region: Region = regions.get(game_state.current_region)
	var danger: int = region.danger_level if region else 1
	var trigger_chance := 0.2 + (danger * 0.05)
	if randf() > trigger_chance:
		return {}
	var total_weight: int = 0
	for e in EXPLORATION_EVENTS:
		total_weight += int(e["weight"])
	var roll := randi_range(1, total_weight)
	var cumulative: int = 0
	for event in EXPLORATION_EVENTS:
		cumulative += int(event["weight"])
		if roll <= cumulative:
			return {
				"type": event["type"],
				"description": event["description"],
				"region": game_state.current_region,
				"danger_level": danger,
			}
	return {}


func scan_region(game_state: GameStateData) -> Array[String]:
	var discovered: Array[String] = []
	for poi in points_of_interest.values():
		if poi.region == game_state.current_region and not poi.is_discovered:
			var chance := maxf(0.2, 0.8 - poi.risk_level * 0.1)
			if randf() < chance:
				discover_poi(poi.poi_id)
				discovered.append(poi.poi_id)
	return discovered


func get_state_dict() -> Dictionary:
	var region_dict: Dictionary = {}
	for rid in regions:
		region_dict[rid] = regions[rid].to_dict()
	var poi_dict: Dictionary = {}
	for pid in points_of_interest:
		poi_dict[pid] = points_of_interest[pid].to_dict()
	return {"regions": region_dict, "points_of_interest": poi_dict}


func load_state_dict(data: Dictionary) -> void:
	regions.clear()
	for rid in data.get("regions", {}):
		regions[rid] = Region.from_dict(data["regions"][rid])
	points_of_interest.clear()
	for pid in data.get("points_of_interest", {}):
		points_of_interest[pid] = PointOfInterest.from_dict(data["points_of_interest"][pid])
