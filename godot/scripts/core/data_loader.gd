## JSON data loader — loads all game content from data/ directory.
## Mirrors Python core/data_loader.py.
class_name DataLoader
extends RefCounted


var data_root: String
var _cache: Dictionary = {}


func _init(p_data_root: String = "res://data") -> void:
	data_root = p_data_root


func _load_json(relative_path: String) -> Variant:
	if _cache.has(relative_path):
		return _cache[relative_path]
	var full_path := data_root.path_join(relative_path)
	if not FileAccess.file_exists(full_path):
		push_error("Data file not found: %s" % full_path)
		return null
	var file := FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open: %s" % full_path)
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Failed to parse JSON in %s: %s" % [full_path, json.get_error_message()])
		return null
	_cache[relative_path] = json.data
	return json.data


func load_factions() -> Dictionary:
	var data := _load_json("factions/faction_registry.json")
	if data == null:
		return {}
	var factions: Dictionary = {}
	for faction_data in data.get("factions", []):
		var faction := Faction.from_dict(faction_data)
		factions[faction.faction_id] = faction
	return factions


func load_relationship_matrix() -> Dictionary:
	var data := _load_json("factions/faction_registry.json")
	if data == null:
		return {}
	return data.get("relationship_matrix", {})


func load_cascade_rules() -> Array:
	var data := _load_json("factions/faction_registry.json")
	if data == null:
		return []
	return data.get("cascade_rules", [])


func load_ship_templates() -> Dictionary:
	var data := _load_json("ships/ship_templates.json")
	if data == null:
		return {}
	var templates: Dictionary = {}
	for tmpl in data.get("ship_templates", []):
		templates[tmpl["template_id"]] = tmpl
	return templates


func load_upgrades() -> Array:
	var data := _load_json("ships/ship_templates.json")
	if data == null:
		return []
	return data.get("upgrades", [])


func load_encounters(arc_id: String) -> Array:
	var file_arc_id := arc_id.replace("_", "")
	var filename := "encounters/%s_encounters.json" % file_arc_id
	var data := _load_json(filename)
	if data == null:
		return []
	var encounters: Array = []
	for e in data.get("encounters", []):
		encounters.append(Encounter.from_dict(e))
	return encounters


func load_arc_definitions() -> Array:
	var data := _load_json("story/arc_definitions.json")
	if data == null:
		return []
	return data.get("arcs", [])


func load_ending_thresholds() -> Dictionary:
	var data := _load_json("story/arc_definitions.json")
	if data == null:
		return {}
	return data.get("ending_thresholds", {})


func load_crystal_deposits() -> Dictionary:
	var data := _load_json("economy/economy_data.json")
	if data == null:
		return {}
	var deposits: Dictionary = {}
	for d in data.get("crystal_deposits", []):
		var deposit := CrystalDeposit.from_dict(d)
		deposits[deposit.deposit_id] = deposit
	return deposits


func load_supply_routes() -> Dictionary:
	var data := _load_json("economy/economy_data.json")
	if data == null:
		return {}
	var routes: Dictionary = {}
	for r in data.get("supply_routes", []):
		var route := CrystalDeposit.SupplyRoute.from_dict(r)
		routes[route.route_id] = route
	return routes


func load_crystal_market() -> CrystalDeposit.CrystalMarket:
	var data := _load_json("economy/economy_data.json")
	if data == null:
		return CrystalDeposit.CrystalMarket.new()
	return CrystalDeposit.CrystalMarket.from_dict(data.get("crystal_market", {}))


func load_regions() -> Array:
	var data := _load_json("economy/regions.json")
	if data == null:
		return []
	return data.get("regions", [])


func load_regions_full() -> Dictionary:
	var data := _load_json("economy/regions.json")
	if data == null:
		return {}
	return data


func load_points_of_interest() -> Array:
	var data := _load_json("economy/regions.json")
	if data == null:
		return []
	return data.get("points_of_interest", [])


func load_side_missions(arc_id: String) -> Array:
	var file_arc_id := arc_id.replace("_", "")
	var filename := "side_missions/%s_side_missions.json" % file_arc_id
	var data := _load_json(filename)
	if data == null:
		return []
	var missions: Array = []
	for m in data.get("side_missions", []):
		missions.append(SideMission.from_dict(m))
	return missions


func load_distress_signals() -> Array:
	var data := _load_json("side_missions/distress_signals.json")
	if data == null:
		return []
	var signals_arr: Array = []
	for e in data.get("distress_signals", []):
		signals_arr.append(Encounter.from_dict(e))
	return signals_arr
