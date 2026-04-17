## NavigationViewModel — narrow adapter between GameSession and navigation.gd.
## The navigation screen calls this VM; the VM is the only code path that touches
## GameSession. Tests construct a VM with a session double to exercise the screen
## without needing the full autoload wiring. Pattern from CODE_REVIEW.md §2.1.
class_name NavigationViewModel
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
	return _session.game_state.current_region


func current_arc() -> String:
	return _session.game_state.current_arc


func position() -> Vector2:
	return Vector2(_session.game_state.position_x, _session.game_state.position_y)


func set_position(pos: Vector2) -> void:
	_session.game_state.position_x = pos.x
	_session.game_state.position_y = pos.y


# ---------------------------------------------------------------------------
# Star map
# ---------------------------------------------------------------------------

## Escape hatch for draw loops that need deep fog/grid access. Anything simple
## should go through the wrapper methods below instead.
func star_map() -> StarMapSystem:
	return _session.star_map_system


func region_bounds(region: String) -> Vector2:
	return _session.star_map_system.get_bounds(region)


func reveal_around(region: String, x: float, y: float, radius: float) -> void:
	_session.star_map_system.reveal_around(region, x, y, radius)


func visible_spawns(region: String) -> Array:
	return _session.star_map_system.get_visible_spawns(region)


func visible_story_pois(region: String) -> Array:
	return _session.star_map_system.get_visible_story_pois(region, _session.game_state)


func visible_hidden_pois(region: String) -> Array:
	return _session.star_map_system.get_visible_hidden_pois(region)


func update_spawns(region: String, dt: float) -> void:
	_session.star_map_system.update_spawns(region, dt)


func remove_spawn(region: String, poi_id: String) -> void:
	_session.star_map_system.remove_spawn(region, poi_id)


func region_map(region: String) -> Dictionary:
	return _session.star_map_system.region_maps.get(region, {})


# ---------------------------------------------------------------------------
# Astral hazards
# ---------------------------------------------------------------------------

## Escape hatch for the movement tick and hazard draw loop, both of which call
## several system methods in sequence. Wrapping each is pure noise.
func astral_hazards() -> AstralHazardSystem:
	return _session.astral_hazard_system


# ---------------------------------------------------------------------------
# Encounters & missions
# ---------------------------------------------------------------------------

func available_encounters() -> Array:
	return _session.encounter_engine.get_available_encounters(_session.game_state)


func update_distress(dt: float) -> Encounter:
	return _session.side_mission_system.update_distress(dt, _session.game_state)


# ---------------------------------------------------------------------------
# Narrative & karma
# ---------------------------------------------------------------------------

func arc_title() -> String:
	return _session.narrative.get_arc_title(_session.game_state.current_arc)


func arc_progress() -> Dictionary:
	return _session.narrative.get_arc_progress(_session.game_state)


## Sprint 5c part 2 — one-glance objective line shown on the HUD top bar.
func arc_objective() -> String:
	return _session.narrative.get_arc_objective(_session.game_state)


# ---------------------------------------------------------------------------
# Hull + crew + morale — HUD surfacing (Sprint 5c part 2)
# ---------------------------------------------------------------------------

func hull_current() -> int:
	var gs: GameStateData = _session.game_state
	if gs == null or gs.player_ship == null:
		return 0
	return gs.player_ship.current_hull


func hull_max() -> int:
	var gs: GameStateData = _session.game_state
	if gs == null or gs.player_ship == null:
		return 0
	return gs.player_ship.max_hull


func crew_count() -> int:
	var gs: GameStateData = _session.game_state
	if gs == null or gs.player_ship == null:
		return 0
	return gs.player_ship.crew.size()


func crew_capacity() -> int:
	var gs: GameStateData = _session.game_state
	if gs == null or gs.player_ship == null:
		return 0
	return gs.player_ship.crew_capacity


func has_crew_morale() -> bool:
	return _session.crew_morale != null


## Average crew morale 0..100; 100 when no crew / no system.
func crew_morale_average() -> int:
	if _session.crew_morale == null or _session.game_state == null:
		return 100
	return _session.crew_morale.get_average_morale(_session.game_state)


## Label for the HUD pip ("STEADY", "MUTINY", etc). Empty when morale system missing.
func crew_morale_label() -> String:
	if _session.crew_morale == null or _session.game_state == null:
		return ""
	return _session.crew_morale.get_morale_status(_session.game_state)


func has_karma_system() -> bool:
	return _session.karma_system != null


func karma_tier_label() -> String:
	return _session.karma_system.get_tier_label(_session.game_state)


func karma_tier_color() -> String:
	return _session.karma_system.get_tier_color(_session.game_state)


# ---------------------------------------------------------------------------
# Exploration
# ---------------------------------------------------------------------------

func connected_regions(region: String) -> Array:
	if _session.exploration == null:
		return []
	var region_obj = _session.exploration.regions.get(region)
	if region_obj == null:
		return []
	return Array(region_obj.connected_regions)


# ---------------------------------------------------------------------------
# Planets
# ---------------------------------------------------------------------------

func has_planet_system() -> bool:
	return _session.planet_system != null


func check_landing_proximity(x: float, y: float) -> String:
	return _session.planet_system.check_landing_proximity(_session.game_state, x, y)


func get_planet(id: String) -> Planet:
	return _session.planet_system.get_planet(id)


func planets_in_region(region: String) -> Array:
	return _session.planet_system.get_planets_in_region(region)


# ---------------------------------------------------------------------------
# Star bases
# ---------------------------------------------------------------------------

func has_star_base_system() -> bool:
	return _session.star_base_system != null


func check_dock_proximity(x: float, y: float) -> String:
	return _session.star_base_system.check_dock_proximity(_session.game_state, x, y)


func get_base(id: String) -> StarBase:
	return _session.star_base_system.get_base(id)


func can_dock(base_id: String) -> bool:
	return _session.star_base_system.can_dock(_session.game_state, base_id)


## Return the UI-facing reason the player cannot dock, or "" when docking is allowed.
## Sprint 5c — exposes realm-control and reputation gates to the HUD.
func get_dock_block_reason(base_id: String) -> String:
	return _session.star_base_system.get_dock_block_reason(_session.game_state, base_id)


func dock(base_id: String) -> void:
	_session.star_base_system.dock(_session.game_state, base_id)


func visible_star_bases(region: String) -> Array:
	return _session.star_base_system.get_visible_bases(_session.game_state, region)


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func travel_to_region(target: String) -> bool:
	return _session.travel_to_region(target)


func land_on_planet(id: String) -> bool:
	return _session.land_on_planet(id)
