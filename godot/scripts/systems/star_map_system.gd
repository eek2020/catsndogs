## Star map system — manages per-region fog of war, fixed story POIs,
## random encounter spawning, hidden locations, and map ownership.
class_name StarMapSystem
extends RefCounted

var region_maps: Dictionary = {}        # region_id -> map definition dict
var fog_grids: Dictionary = {}          # region_id -> PackedByteArray
var grid_dimensions: Dictionary = {}    # region_id -> Vector2i (cols, rows)
var owned_maps: Array[String] = []      # region_ids the player owns charts for
var cartographer_rescued: bool = false
var galaxy_layout: Dictionary = {}      # galaxy_layout.json data (nodes, galaxy_name)

# Random spawn tracking
var active_spawns: Dictionary = {}      # region_id -> Array of spawn dicts
var spawn_timers: Dictionary = {}       # "region_id:zone_id" -> float (seconds until next spawn)

# Vision radius in world units when the ship moves
const VISION_RADIUS: float = 200.0
# Despawn timeout for random POIs (seconds)
const RANDOM_POI_TIMEOUT: float = 300.0


func load_region_maps(data: Dictionary) -> void:
	region_maps = data
	for region_id in region_maps:
		_init_fog_grid(region_id)
		active_spawns[region_id] = []


func _init_fog_grid(region_id: String) -> void:
	var map_def: Dictionary = region_maps.get(region_id, {})
	var bounds: Dictionary = map_def.get("bounds", {"width": 6000, "height": 6000})
	var cell_size: int = map_def.get("fog_grid_size", 64)
	var cols: int = ceili(float(bounds["width"]) / cell_size)
	var rows: int = ceili(float(bounds["height"]) / cell_size)
	grid_dimensions[region_id] = Vector2i(cols, rows)
	if not fog_grids.has(region_id):
		var grid := PackedByteArray()
		grid.resize(cols * rows)
		grid.fill(0)
		fog_grids[region_id] = grid


## Reveal fog cells within a circle around a world position.
func reveal_around(region_id: String, world_x: float, world_y: float, radius: float = VISION_RADIUS) -> void:
	var map_def: Dictionary = region_maps.get(region_id, {})
	if map_def.is_empty():
		return
	var cell_size: int = map_def.get("fog_grid_size", 64)
	var dims: Vector2i = grid_dimensions.get(region_id, Vector2i.ZERO)
	if dims == Vector2i.ZERO:
		return
	var grid: PackedByteArray = fog_grids.get(region_id, PackedByteArray())
	if grid.size() == 0:
		return

	var cx: int = int(world_x / cell_size)
	var cy: int = int(world_y / cell_size)
	var cell_radius: int = ceili(radius / cell_size)

	for dy in range(-cell_radius, cell_radius + 1):
		for dx in range(-cell_radius, cell_radius + 1):
			var gx: int = cx + dx
			var gy: int = cy + dy
			if gx < 0 or gy < 0 or gx >= dims.x or gy >= dims.y:
				continue
			var dist_sq: float = float(dx * dx + dy * dy)
			if dist_sq <= float(cell_radius * cell_radius):
				var idx: int = gy * dims.x + gx
				grid[idx] = 1
	fog_grids[region_id] = grid


## Reveal a percentage of fog cells randomly (for purchased maps).
func reveal_percentage(region_id: String, percentage: float) -> void:
	var dims: Vector2i = grid_dimensions.get(region_id, Vector2i.ZERO)
	if dims == Vector2i.ZERO:
		return
	var grid: PackedByteArray = fog_grids.get(region_id, PackedByteArray())
	if grid.size() == 0:
		return

	var total: int = dims.x * dims.y
	var hidden_indices: Array[int] = []
	for i in total:
		if grid[i] == 0:
			hidden_indices.append(i)

	var to_reveal: int = mini(int(total * percentage), hidden_indices.size())
	hidden_indices.shuffle()
	for i in to_reveal:
		grid[hidden_indices[i]] = 1
	fog_grids[region_id] = grid


## Reveal all fog in a region.
func reveal_all_fog(region_id: String) -> void:
	var grid: PackedByteArray = fog_grids.get(region_id, PackedByteArray())
	if grid.size() == 0:
		return
	grid.fill(1)
	fog_grids[region_id] = grid


## Check if a specific fog cell is revealed.
func is_cell_revealed(region_id: String, grid_x: int, grid_y: int) -> bool:
	var dims: Vector2i = grid_dimensions.get(region_id, Vector2i.ZERO)
	if dims == Vector2i.ZERO:
		return false
	if grid_x < 0 or grid_y < 0 or grid_x >= dims.x or grid_y >= dims.y:
		return false
	var grid: PackedByteArray = fog_grids.get(region_id, PackedByteArray())
	if grid.size() == 0:
		return false
	return grid[grid_y * dims.x + grid_x] == 1


## Check if a world position is in revealed fog.
func is_position_revealed(region_id: String, world_x: float, world_y: float) -> bool:
	var map_def: Dictionary = region_maps.get(region_id, {})
	if map_def.is_empty():
		return false
	var cell_size: int = map_def.get("fog_grid_size", 64)
	var gx: int = int(world_x / cell_size)
	var gy: int = int(world_y / cell_size)
	return is_cell_revealed(region_id, gx, gy)


## Get the map bounds for a region.
func get_bounds(region_id: String) -> Vector2:
	var map_def: Dictionary = region_maps.get(region_id, {})
	var bounds: Dictionary = map_def.get("bounds", {"width": 6000, "height": 6000})
	return Vector2(bounds.get("width", 6000), bounds.get("height", 6000))


## Get visible story POIs for the current region and arc.
func get_visible_story_pois(region_id: String, game_state: GameStateData) -> Array:
	var map_def: Dictionary = region_maps.get(region_id, {})
	if map_def.is_empty():
		return []
	var result: Array = []
	for loc in map_def.get("story_locations", []):
		if loc.get("arc_id", "") != game_state.current_arc:
			continue
		var enc_id: String = loc.get("encounter_id", "")
		if enc_id in game_state.completed_encounters:
			continue
		var px: float = loc.get("x", 0.0)
		var py: float = loc.get("y", 0.0)
		if is_position_revealed(region_id, px, py):
			result.append(loc)
	return result


## Get visible hidden locations (requires cartographer + fog revealed).
func get_visible_hidden_pois(region_id: String) -> Array:
	if not cartographer_rescued:
		return []
	var map_def: Dictionary = region_maps.get(region_id, {})
	if map_def.is_empty():
		return []
	if region_id not in owned_maps:
		return []
	var result: Array = []
	for loc in map_def.get("hidden_locations", []):
		if not loc.get("requires_cartographer", false):
			result.append(loc)
			continue
		var px: float = loc.get("x", 0.0)
		var py: float = loc.get("y", 0.0)
		if is_position_revealed(region_id, px, py):
			result.append(loc)
	return result


## -----------------------------------------------------------------------
## Random spawn management
## -----------------------------------------------------------------------

## Update spawn timers and create new random POIs as needed.
func update_spawns(region_id: String, dt: float) -> void:
	var map_def: Dictionary = region_maps.get(region_id, {})
	if map_def.is_empty():
		return
	var zones: Array = map_def.get("spawn_zones", [])
	if not active_spawns.has(region_id):
		active_spawns[region_id] = []

	# Age existing spawns and despawn timed-out ones
	var retained: Array = []
	for spawn in active_spawns[region_id]:
		spawn["age"] = spawn.get("age", 0.0) + dt
		if spawn["age"] < RANDOM_POI_TIMEOUT:
			retained.append(spawn)
	active_spawns[region_id] = retained

	# Process each spawn zone
	for zone in zones:
		var zone_key: String = "%s:%s" % [region_id, zone.get("zone_id", "")]
		if not spawn_timers.has(zone_key):
			spawn_timers[zone_key] = randf_range(
				zone.get("respawn_min", 30),
				zone.get("respawn_max", 90)
			)

		spawn_timers[zone_key] -= dt
		if spawn_timers[zone_key] > 0:
			continue

		# Check if zone is at max active
		var zone_id: String = zone.get("zone_id", "")
		var zone_count: int = 0
		for spawn in active_spawns[region_id]:
			if spawn.get("zone_id", "") == zone_id:
				zone_count += 1
		var max_active: int = zone.get("max_active", 2)
		if zone_count >= max_active:
			spawn_timers[zone_key] = randf_range(
				zone.get("respawn_min", 30),
				zone.get("respawn_max", 90)
			)
			continue

		# Spawn a new random POI
		var types: Array = zone.get("types", ["combat"])
		var chosen_type: String = types[randi() % types.size()]
		var zx: float = zone.get("x", 0.0)
		var zy: float = zone.get("y", 0.0)
		var zr: float = zone.get("radius", 500.0)
		var angle: float = randf() * TAU
		var dist: float = randf() * zr
		var spawn_x: float = zx + cos(angle) * dist
		var spawn_y: float = zy + sin(angle) * dist
		# Clamp to region bounds with padding
		var bounds: Vector2 = get_bounds(region_id)
		var pad: float = 150.0
		spawn_x = clampf(spawn_x, pad, bounds.x - pad)
		spawn_y = clampf(spawn_y, pad, bounds.y - pad)

		var spawn_poi: Dictionary = {
			"poi_id": "%s_%d" % [zone_id, randi()],
			"zone_id": zone_id,
			"x": spawn_x,
			"y": spawn_y,
			"type": chosen_type,
			"age": 0.0,
			"label": _get_random_label(chosen_type),
		}
		active_spawns[region_id].append(spawn_poi)

		# Reset timer
		spawn_timers[zone_key] = randf_range(
			zone.get("respawn_min", 30),
			zone.get("respawn_max", 90)
		)


## Get active random spawn POIs that are in revealed fog.
func get_visible_spawns(region_id: String) -> Array:
	var result: Array = []
	for spawn in active_spawns.get(region_id, []):
		var px: float = spawn.get("x", 0.0)
		var py: float = spawn.get("y", 0.0)
		if is_position_revealed(region_id, px, py):
			result.append(spawn)
	return result


## Remove a random spawn POI by poi_id (e.g. after player interacts with it).
func remove_spawn(region_id: String, poi_id: String) -> void:
	var spawns: Array = active_spawns.get(region_id, [])
	for i in spawns.size():
		if spawns[i].get("poi_id", "") == poi_id:
			spawns.remove_at(i)
			return


func _get_random_label(spawn_type: String) -> String:
	match spawn_type:
		"combat":
			var labels := ["Hostile Contact", "Pirate Ambush", "Patrol Intercept", "Raider Party"]
			return labels[randi() % labels.size()]
		"rescue":
			var labels := ["Distress Beacon", "Stranded Vessel", "Escape Pod Detected", "Mayday Signal"]
			return labels[randi() % labels.size()]
		"distress_signal":
			return "Distress Signal"
		"trade":
			var labels := ["Merchant Vessel", "Trader Convoy", "Supply Ship"]
			return labels[randi() % labels.size()]
		"exploration":
			var labels := ["Unknown Signal", "Anomaly Detected", "Energy Signature"]
			return labels[randi() % labels.size()]
		_:
			return "Unknown Contact"


## -----------------------------------------------------------------------
## Map ownership
## -----------------------------------------------------------------------

## Purchase a map for a region.
func purchase_map(region_id: String, reveal_pct: float = 0.6) -> void:
	if region_id in owned_maps:
		return
	owned_maps.append(region_id)
	if reveal_pct > 0.0:
		reveal_percentage(region_id, reveal_pct)
	EventBus.map_purchased.emit(region_id)


## Check if the player owns a map for a region.
func has_map(region_id: String) -> bool:
	return region_id in owned_maps


## -----------------------------------------------------------------------
## Cartographer
## -----------------------------------------------------------------------

## Called when the fairy cartographer is rescued.
## Reveals fog around hidden locations Pip has charted, not the entire map.
func on_cartographer_rescued() -> void:
	cartographer_rescued = true
	# Reveal fog in a radius around each hidden location across all regions
	for region_id in region_maps:
		var map_def: Dictionary = region_maps[region_id]
		for loc in map_def.get("hidden_locations", []):
			if loc.get("requires_cartographer", false):
				var lx: float = loc.get("x", 0.0)
				var ly: float = loc.get("y", 0.0)
				reveal_around(region_id, lx, ly, 400.0)
	EventBus.cartographer_rescued.emit()


## -----------------------------------------------------------------------
## Galaxy layout
## -----------------------------------------------------------------------

## Load galaxy layout data (node positions for galaxy map rendering).
func load_galaxy_layout(data: Dictionary) -> void:
	galaxy_layout = data


## Get normalized (0-1) position for a region on the galaxy map.
func get_galaxy_node_pos(region_id: String) -> Vector2:
	var nodes: Dictionary = galaxy_layout.get("nodes", {})
	var node: Dictionary = nodes.get(region_id, {})
	return Vector2(node.get("gx", 0.5), node.get("gy", 0.5))


## Get the color assigned to a region on the galaxy map.
func get_galaxy_node_color(region_id: String) -> Color:
	var nodes: Dictionary = galaxy_layout.get("nodes", {})
	var node: Dictionary = nodes.get(region_id, {})
	var hex: String = node.get("color", "#FFFFFF")
	return Color.html(hex)


## Get the fraction of fog cells revealed for a region (0.0 to 1.0).
func get_region_fog_percentage(region_id: String) -> float:
	var dims: Vector2i = grid_dimensions.get(region_id, Vector2i.ZERO)
	if dims == Vector2i.ZERO:
		return 0.0
	var grid: PackedByteArray = fog_grids.get(region_id, PackedByteArray())
	if grid.size() == 0:
		return 0.0
	var total: int = dims.x * dims.y
	var revealed: int = 0
	for i in total:
		if grid[i] == 1:
			revealed += 1
	return float(revealed) / float(total)


## -----------------------------------------------------------------------
## Connected regions for boundary transitions
## -----------------------------------------------------------------------

## Get the entry position when transitioning from one region to another.
## Uses galaxy layout positions to determine which edge to enter from.
func get_entry_position(from_region: String, to_region: String) -> Vector2:
	var bounds: Vector2 = get_bounds(to_region)
	var pad: float = 150.0

	# Use galaxy layout to determine entry direction
	var nodes: Dictionary = galaxy_layout.get("nodes", {})
	if not nodes.is_empty() and nodes.has(from_region) and nodes.has(to_region):
		var from_pos: Vector2 = get_galaxy_node_pos(from_region)
		var to_pos: Vector2 = get_galaxy_node_pos(to_region)
		var dir: Vector2 = (from_pos - to_pos).normalized()  # direction FROM the source
		# Enter from the side closest to where we came from
		var entry_x: float = bounds.x * 0.5
		var entry_y: float = bounds.y * 0.5
		if absf(dir.x) > absf(dir.y):
			# Horizontal dominant — enter left or right
			entry_x = pad if dir.x < 0 else bounds.x - pad
		else:
			# Vertical dominant — enter top or bottom
			entry_y = pad if dir.y < 0 else bounds.y - pad
		return Vector2(entry_x, entry_y)

	# Fallback: enter from center-left
	return Vector2(pad, bounds.y * 0.5)


## -----------------------------------------------------------------------
## Serialization
## -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	var fog_dict: Dictionary = {}
	for region_id in fog_grids:
		fog_dict[region_id] = Marshalls.raw_to_base64(fog_grids[region_id])
	var spawn_dict: Dictionary = {}
	for region_id in active_spawns:
		var arr: Array = []
		for spawn in active_spawns[region_id]:
			arr.append(spawn.duplicate())
		spawn_dict[region_id] = arr
	return {
		"owned_maps": Array(owned_maps),
		"cartographer_rescued": cartographer_rescued,
		"fog_grids": fog_dict,
		"active_spawns": spawn_dict,
		"spawn_timers": spawn_timers.duplicate(),
	}


func load_from_dict(data: Dictionary) -> void:
	owned_maps = Array(data.get("owned_maps", []), TYPE_STRING, "", null)
	cartographer_rescued = data.get("cartographer_rescued", false)
	# Restore fog grids
	var fog_dict: Dictionary = data.get("fog_grids", {})
	for region_id in fog_dict:
		if region_maps.has(region_id):
			_init_fog_grid(region_id)
			var decoded: PackedByteArray = Marshalls.base64_to_raw(fog_dict[region_id])
			var dims: Vector2i = grid_dimensions.get(region_id, Vector2i.ZERO)
			if decoded.size() == dims.x * dims.y:
				fog_grids[region_id] = decoded
	# Restore spawns
	var spawn_dict: Dictionary = data.get("active_spawns", {})
	for region_id in spawn_dict:
		active_spawns[region_id] = []
		for spawn in spawn_dict[region_id]:
			active_spawns[region_id].append(spawn)
	spawn_timers = data.get("spawn_timers", {})
