## Star base system — manages dockable space stations across regions.
##
## Handles base loading, visibility checks, docking eligibility,
## service availability, and artifact purchases.
class_name StarBaseSystem
extends RefCounted

var _bases: Dictionary = {}  # base_id -> StarBase
var _artifacts: Dictionary = {}  # artifact_id -> Dictionary

const DOCK_RADIUS: float = 60.0


func load_bases(bases_data: Array) -> void:
	_bases.clear()
	for data in bases_data:
		var base := StarBase.from_dict(data)
		_bases[base.base_id] = base


func load_artifacts(artifact_data: Array) -> void:
	_artifacts.clear()
	for data in artifact_data:
		_artifacts[data.get("artifact_id", "")] = data


## Return all bases in a given region.
func get_bases_in_region(region_id: String) -> Array:
	var result: Array = []
	for base in _bases.values():
		if base.region_id == region_id:
			result.append(base)
	return result


## Return bases visible to the player in a region (considering discovery state).
func get_visible_bases(game_state: GameStateData, region_id: String) -> Array:
	var result: Array = []
	for base in get_bases_in_region(region_id):
		if _is_visible(game_state, base):
			result.append(base)
	return result


## Check if a base is visible to the player.
func _is_visible(game_state: GameStateData, base: StarBase) -> bool:
	match base.base_type:
		"open":
			return true
		"hidden":
			if base.base_id in game_state.discovered_bases:
				return true
			if not base.discovery_flag.is_empty() and game_state.story_flags.get(base.discovery_flag, false):
				if base.base_id not in game_state.discovered_bases:
					game_state.discovered_bases.append(base.base_id)
				return true
			return false
		"stronghold":
			return true  # Visible but may not be dockable
	return true


## Check if the player can dock at a base.
func can_dock(game_state: GameStateData, base_id: String) -> bool:
	var base: StarBase = _bases.get(base_id)
	if base == null:
		return false
	if not _is_visible(game_state, base):
		return false
	if base.base_type == "stronghold":
		var faction: Faction = game_state.faction_registry.get(base.controlling_faction)
		if faction == null:
			return false
		if faction.reputation_with_player < base.required_reputation:
			return false
	return true


## Dock the player at a base.
func dock(game_state: GameStateData, base_id: String) -> bool:
	if not can_dock(game_state, base_id):
		return false
	game_state.docked_base_id = base_id
	EventBus.base_docked.emit(base_id)
	return true


## Undock the player from the current base.
func undock(game_state: GameStateData) -> void:
	var old_base: String = game_state.docked_base_id
	game_state.docked_base_id = ""
	if not old_base.is_empty():
		EventBus.base_undocked.emit(old_base)


## Return the list of services available at the currently docked base.
func get_available_services(game_state: GameStateData, base_id: String) -> Array:
	var base: StarBase = _bases.get(base_id)
	if base == null:
		return []
	return Array(base.services)


## Return artifacts available for purchase at a base (not yet acquired).
func get_available_artifacts(game_state: GameStateData, base_id: String) -> Array:
	var base: StarBase = _bases.get(base_id)
	if base == null:
		return []
	var result: Array = []
	for artifact_id in base.artifacts:
		if artifact_id not in game_state.acquired_artifacts:
			var artifact_data: Dictionary = _artifacts.get(artifact_id, {})
			if not artifact_data.is_empty():
				result.append(artifact_data)
	return result


## Purchase an artifact from the current base.
func purchase_artifact(game_state: GameStateData, base_id: String, artifact_id: String) -> bool:
	var base: StarBase = _bases.get(base_id)
	if base == null or artifact_id not in base.artifacts:
		return false
	if artifact_id in game_state.acquired_artifacts:
		return false
	var artifact_data: Dictionary = _artifacts.get(artifact_id, {})
	if artifact_data.is_empty():
		return false
	var cost_crystals: int = artifact_data.get("cost_crystals", 0)
	var cost_salvage: int = artifact_data.get("cost_salvage", 0)
	if game_state.crystal_inventory < cost_crystals or game_state.salvage < cost_salvage:
		return false
	game_state.crystal_inventory -= cost_crystals
	game_state.salvage -= cost_salvage
	game_state.acquired_artifacts.append(artifact_id)
	# Set story flag
	var flag: String = artifact_data.get("story_flag_on_acquire", "")
	if not flag.is_empty():
		game_state.story_flags[flag] = true
	EventBus.artifact_acquired.emit(artifact_id)
	return true


## Get a base by ID.
func get_base(base_id: String) -> StarBase:
	return _bases.get(base_id)


## Check if a world position is within docking range of any visible base.
## Returns the base_id or empty string.
func check_dock_proximity(game_state: GameStateData, x: float, y: float) -> String:
	var region_id: String = game_state.current_region
	for base in get_visible_bases(game_state, region_id):
		var dx: float = x - base.position_x
		var dy: float = y - base.position_y
		if dx * dx + dy * dy <= DOCK_RADIUS * DOCK_RADIUS:
			return base.base_id
	return ""


## Return the sum of all artifact passive bonuses the player has acquired.
func get_artifact_bonuses(game_state: GameStateData) -> Dictionary:
	var bonuses: Dictionary = {}
	for artifact_id in game_state.acquired_artifacts:
		var data: Dictionary = _artifacts.get(artifact_id, {})
		var passive: Dictionary = data.get("passive_bonus", {})
		for key in passive:
			bonuses[key] = bonuses.get(key, 0.0) + passive[key]
	return bonuses
