## Planet system — manages planetary exploration, landing, and departure.
##
## Handles planet data loading, state persistence, and the transition
## between space navigation and top-down planet exploration.
class_name PlanetSystem
extends RefCounted

var _planets: Dictionary = {}  # planet_id -> Planet
var _biomes: Dictionary = {}


func load_planet_data(planet_data: Array) -> void:
	_planets.clear()
	for data in planet_data:
		var planet := Planet.from_dict(data)
		_planets[planet.planet_id] = planet


func load_biomes(biome_data: Dictionary) -> void:
	_biomes = biome_data.get("biomes", {})


## Return a planet by ID.
func get_planet(planet_id: String) -> Planet:
	return _planets.get(planet_id)


## Return all planets in a given region.
func get_planets_in_region(region_id: String) -> Array:
	var result: Array = []
	for planet in _planets.values():
		if planet.region_id == region_id:
			result.append(planet)
	return result


## Return the biome data for a given biome ID.
func get_biome(biome_id: String) -> Dictionary:
	return _biomes.get(biome_id, {})


## Land the player on a planet.
func land(game_state: GameStateData, planet_id: String) -> bool:
	var planet: Planet = _planets.get(planet_id)
	if planet == null:
		return false
	game_state.current_planet_id = planet_id
	# Initialise planet state if first visit
	if not game_state.planet_states.has(planet_id):
		game_state.planet_states[planet_id] = {
			"cleared_treasures": [],
			"defeated_hostiles": [],
			"faction_aggro": {},
			"visited": true,
			"last_visit_arc": game_state.current_arc,
		}
	else:
		game_state.planet_states[planet_id]["visited"] = true
		game_state.planet_states[planet_id]["last_visit_arc"] = game_state.current_arc
	EventBus.planet_landed.emit(planet_id)
	return true


## Depart from the current planet back to space navigation.
func depart(game_state: GameStateData) -> void:
	var old_planet: String = game_state.current_planet_id
	game_state.current_planet_id = ""
	# Merge planet_inventory into main inventory
	var planet_inv: Dictionary = game_state.planet_inventory
	game_state.crystal_inventory += int(planet_inv.get("crystals", 0))
	game_state.salvage += int(planet_inv.get("salvage", 0))
	game_state.planet_inventory = {}
	if not old_planet.is_empty():
		EventBus.planet_departed.emit(old_planet)


## Get the persistent state for a planet.
func get_planet_state(game_state: GameStateData, planet_id: String) -> Dictionary:
	return game_state.planet_states.get(planet_id, {})


## Check if a treasure has been cleared on a planet.
func is_treasure_cleared(game_state: GameStateData, planet_id: String, treasure_id: String) -> bool:
	var state: Dictionary = get_planet_state(game_state, planet_id)
	var cleared: Array = state.get("cleared_treasures", [])
	return treasure_id in cleared


## Mark a treasure as cleared and add rewards to planet inventory.
func collect_treasure(game_state: GameStateData, planet_id: String, treasure_id: String) -> Dictionary:
	var planet: Planet = _planets.get(planet_id)
	if planet == null:
		return {}
	if is_treasure_cleared(game_state, planet_id, treasure_id):
		return {}
	var treasure_data: Dictionary = {}
	for t in planet.treasures:
		if t.get("treasure_id", "") == treasure_id:
			treasure_data = t
			break
	if treasure_data.is_empty():
		return {}
	# Mark as cleared
	if not game_state.planet_states.has(planet_id):
		game_state.planet_states[planet_id] = {"cleared_treasures": [], "defeated_hostiles": [], "faction_aggro": {}, "visited": true, "last_visit_arc": game_state.current_arc}
	game_state.planet_states[planet_id]["cleared_treasures"].append(treasure_id)
	# Add to planet inventory
	game_state.planet_inventory["crystals"] = game_state.planet_inventory.get("crystals", 0) + treasure_data.get("reward_crystals", 0)
	game_state.planet_inventory["salvage"] = game_state.planet_inventory.get("salvage", 0) + treasure_data.get("reward_salvage", 0)
	EventBus.planet_treasure_found.emit(treasure_id)
	return treasure_data


## Check if a position is within landing range of a planet.
const LANDING_RADIUS: float = 50.0

func check_landing_proximity(game_state: GameStateData, x: float, y: float) -> String:
	var region_id: String = game_state.current_region
	for planet in get_planets_in_region(region_id):
		var dx: float = x - planet.position_x
		var dy: float = y - planet.position_y
		if dx * dx + dy * dy <= LANDING_RADIUS * LANDING_RADIUS:
			return planet.planet_id
	return ""
