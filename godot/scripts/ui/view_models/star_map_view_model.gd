## StarMapViewModel — narrow adapter between GameSession and star_map_screen.gd.
## Same pattern as NavigationViewModel / CombatViewModel (CODE_REVIEW.md §2.1).
## star_map_screen.gd and its layer components reach GameSession only through
## this VM so the screen can be exercised without the autoload (tests inject
## a session double with the same duck-typed shape).
class_name StarMapViewModel
extends RefCounted

var _session  # GameSession autoload, or a test double with the same shape


func _init(session) -> void:
	_session = session


# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------

func has_state() -> bool:
	return _session.game_state != null


func state() -> GameStateData:
	return _session.game_state


func current_region() -> String:
	if _session.game_state == null:
		return ""
	return _session.game_state.current_region


func player_position() -> Vector2:
	if _session.game_state == null:
		return Vector2.ZERO
	return Vector2(_session.game_state.position_x, _session.game_state.position_y)


# ---------------------------------------------------------------------------
# Star map system — escape hatch + wrappers
# ---------------------------------------------------------------------------

## Escape hatch for callers that need structured access to fog / region data.
## Prefer the narrow wrappers below when possible.
func star_map() -> StarMapSystem:
	return _session.star_map_system


func has_star_map() -> bool:
	return _session.star_map_system != null


func region_bounds(region_id: String) -> Vector2:
	if _session.star_map_system == null:
		return Vector2.ZERO
	return _session.star_map_system.get_bounds(region_id)


func galaxy_layout() -> Dictionary:
	if _session.star_map_system == null:
		return {}
	return _session.star_map_system.galaxy_layout


func galaxy_nodes() -> Dictionary:
	return galaxy_layout().get("nodes", {})


func galaxy_node_pos(region_id: String) -> Vector2:
	if _session.star_map_system == null:
		return Vector2.ZERO
	return _session.star_map_system.get_galaxy_node_pos(region_id)


func galaxy_node_color(region_id: String) -> Color:
	if _session.star_map_system == null:
		return Color.WHITE
	return _session.star_map_system.get_galaxy_node_color(region_id)


func region_fog_percentage(region_id: String) -> float:
	if _session.star_map_system == null:
		return 0.0
	return _session.star_map_system.get_region_fog_percentage(region_id)


func has_map(region_id: String) -> bool:
	if _session.star_map_system == null:
		return false
	return _session.star_map_system.has_map(region_id)


func cartographer_rescued() -> bool:
	if _session.star_map_system == null:
		return false
	return _session.star_map_system.cartographer_rescued


func region_map(region_id: String) -> Dictionary:
	if _session.star_map_system == null:
		return {}
	return _session.star_map_system.region_maps.get(region_id, {})


func grid_dimensions(region_id: String) -> Vector2i:
	if _session.star_map_system == null:
		return Vector2i.ZERO
	return _session.star_map_system.grid_dimensions.get(region_id, Vector2i.ZERO)


func is_cell_revealed(region_id: String, cx: int, cy: int) -> bool:
	if _session.star_map_system == null:
		return false
	return _session.star_map_system.is_cell_revealed(region_id, cx, cy)


# ---------------------------------------------------------------------------
# POIs
# ---------------------------------------------------------------------------

func visible_story_pois(region_id: String) -> Array:
	if _session.star_map_system == null or _session.game_state == null:
		return []
	return _session.star_map_system.get_visible_story_pois(region_id, _session.game_state)


func visible_hidden_pois(region_id: String) -> Array:
	if _session.star_map_system == null:
		return []
	return _session.star_map_system.get_visible_hidden_pois(region_id)


func visible_spawns(region_id: String) -> Array:
	if _session.star_map_system == null:
		return []
	return _session.star_map_system.get_visible_spawns(region_id)


# ---------------------------------------------------------------------------
# Exploration
# ---------------------------------------------------------------------------

func exploration() -> ExplorationSystem:
	return _session.exploration


func has_exploration() -> bool:
	return _session.exploration != null


func region_info(region_id: String) -> ExplorationSystem.Region:
	if _session.exploration == null:
		return null
	return _session.exploration.regions.get(region_id)


func region_is_discovered(region_id: String) -> bool:
	var region := region_info(region_id)
	if region == null:
		return false
	return region.is_discovered


func region_display_name(region_id: String) -> String:
	var region := region_info(region_id)
	if region != null:
		return region.region_name
	return region_id.replace("_", " ").capitalize()


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func travel_to_region(region_id: String) -> bool:
	return _session.travel_to_region(region_id)


## Mark the region the player is about to enter so the world scene can pick
## it up on _ready. Uses Godot's `Node.set_meta` on the GameSession autoload
## so the value survives the scene change.
func set_world_entry_region(region_id: String) -> void:
	_session.set_meta("world_entry_region", region_id)
