extends GutTest

## Regression coverage for NavigationViewModel (Sprint 3a, NEXT_STEPS.md §2).
## The VM is the only path navigation.gd uses to reach GameSession. Tests
## construct a SessionDouble with the same duck-typed shape and verify the VM
## reads / writes / delegates through it correctly.


class SessionDouble:
	extends RefCounted

	var game_state: GameStateData = null
	var star_map_system: StarMapDouble = null
	var encounter_engine: EncounterEngineDouble = null
	var side_mission_system: SideMissionDouble = null
	var narrative: NarrativeDouble = null
	var karma_system: KarmaDouble = null
	var exploration: ExplorationDouble = null
	var planet_system: PlanetSystemDouble = null
	var star_base_system: StarBaseDouble = null
	var astral_hazard_system = null

	var travel_calls: Array[String] = []
	var land_calls: Array[String] = []
	var travel_result: bool = true
	var land_result: bool = true

	func travel_to_region(target: String) -> bool:
		travel_calls.append(target)
		return travel_result

	func land_on_planet(id: String) -> bool:
		land_calls.append(id)
		return land_result


class StarMapDouble:
	extends RefCounted
	var bounds_by_region: Dictionary = {}
	var region_maps: Dictionary = {}
	var reveal_calls: Array = []
	var update_calls: Array = []
	var remove_calls: Array = []
	var visible_spawns_by_region: Dictionary = {}
	var visible_story_calls: Array = []

	func get_bounds(region: String) -> Vector2:
		return bounds_by_region.get(region, Vector2.ZERO)

	func reveal_around(region: String, x: float, y: float, radius: float) -> void:
		reveal_calls.append({"region": region, "x": x, "y": y, "radius": radius})

	func get_visible_spawns(region: String) -> Array:
		return visible_spawns_by_region.get(region, [])

	func get_visible_story_pois(region: String, gs) -> Array:
		visible_story_calls.append({"region": region, "gs": gs})
		return []

	func get_visible_hidden_pois(_region: String) -> Array:
		return []

	func update_spawns(region: String, dt: float) -> void:
		update_calls.append({"region": region, "dt": dt})

	func remove_spawn(region: String, poi_id: String) -> void:
		remove_calls.append({"region": region, "poi_id": poi_id})


class EncounterEngineDouble:
	extends RefCounted
	var available: Array = []
	var last_gs = null

	func get_available_encounters(gs) -> Array:
		last_gs = gs
		return available


class SideMissionDouble:
	extends RefCounted
	var next_distress = null
	var last_call: Dictionary = {}

	func update_distress(dt: float, gs):
		last_call = {"dt": dt, "gs": gs}
		return next_distress


class NarrativeDouble:
	extends RefCounted
	var arc_titles: Dictionary = {}
	var progress_value: Dictionary = {}

	func get_arc_title(arc: String) -> String:
		return arc_titles.get(arc, "")

	func get_arc_progress(_gs) -> Dictionary:
		return progress_value


class KarmaDouble:
	extends RefCounted
	var tier_label_value: String = ""
	var tier_color_value: String = ""

	func get_tier_label(_gs) -> String:
		return tier_label_value

	func get_tier_color(_gs) -> String:
		return tier_color_value


class ExplorationDouble:
	extends RefCounted
	var regions: Dictionary = {}


class RegionDouble:
	extends RefCounted
	var connected_regions: Array = []


class PlanetSystemDouble:
	extends RefCounted
	var landing_proximity_by_pos: Dictionary = {}
	var planets_by_id: Dictionary = {}
	var planets_by_region: Dictionary = {}

	func check_landing_proximity(_gs, x: float, y: float) -> String:
		return landing_proximity_by_pos.get(Vector2(x, y), "")

	func get_planet(id: String):
		return planets_by_id.get(id)

	func get_planets_in_region(region: String) -> Array:
		return planets_by_region.get(region, [])


class StarBaseDouble:
	extends RefCounted
	var dock_proximity_by_pos: Dictionary = {}
	var bases_by_id: Dictionary = {}
	var can_dock_by_id: Dictionary = {}
	var dock_calls: Array[String] = []
	var visible_bases_by_region: Dictionary = {}

	func check_dock_proximity(_gs, x: float, y: float) -> String:
		return dock_proximity_by_pos.get(Vector2(x, y), "")

	func get_base(id: String):
		return bases_by_id.get(id)

	func can_dock(_gs, id: String) -> bool:
		return can_dock_by_id.get(id, false)

	func dock(_gs, id: String) -> void:
		dock_calls.append(id)

	func get_visible_bases(_gs, region: String) -> Array:
		return visible_bases_by_region.get(region, [])


func _make_session_with_state() -> SessionDouble:
	var session := SessionDouble.new()
	session.star_map_system = StarMapDouble.new()
	session.encounter_engine = EncounterEngineDouble.new()
	session.side_mission_system = SideMissionDouble.new()
	session.narrative = NarrativeDouble.new()
	session.karma_system = KarmaDouble.new()
	session.exploration = ExplorationDouble.new()
	session.planet_system = PlanetSystemDouble.new()
	session.star_base_system = StarBaseDouble.new()
	var gs := GameStateData.new()
	gs.current_region = "starting_realm"
	gs.current_arc = "arc1"
	gs.position_x = 100.0
	gs.position_y = 200.0
	session.game_state = gs
	return session


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

func test_has_state_false_when_game_state_null() -> void:
	var session := SessionDouble.new()
	var vm := NavigationViewModel.new(session)
	assert_false(vm.has_state())


func test_has_state_true_when_game_state_set() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	assert_true(vm.has_state())


func test_current_region_returns_state_region() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	assert_eq(vm.current_region(), "starting_realm")


func test_current_arc_returns_state_arc() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	assert_eq(vm.current_arc(), "arc1")


func test_position_returns_vector_from_state() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	assert_eq(vm.position(), Vector2(100.0, 200.0))


func test_set_position_writes_through_to_state() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	vm.set_position(Vector2(42.5, -7.0))
	assert_eq(session.game_state.position_x, 42.5)
	assert_eq(session.game_state.position_y, -7.0)


# ---------------------------------------------------------------------------
# Star map
# ---------------------------------------------------------------------------

func test_region_bounds_delegates_to_star_map() -> void:
	var session := _make_session_with_state()
	session.star_map_system.bounds_by_region["starting_realm"] = Vector2(1000, 800)
	var vm := NavigationViewModel.new(session)
	assert_eq(vm.region_bounds("starting_realm"), Vector2(1000, 800))


func test_reveal_around_forwards_args() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	vm.reveal_around("r1", 50.0, 60.0, 300.0)
	assert_eq(session.star_map_system.reveal_calls.size(), 1)
	var call: Dictionary = session.star_map_system.reveal_calls[0]
	assert_eq(call["region"], "r1")
	assert_eq(call["x"], 50.0)
	assert_eq(call["y"], 60.0)
	assert_eq(call["radius"], 300.0)


func test_region_map_returns_empty_when_missing() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	assert_eq(vm.region_map("unknown"), {})


func test_region_map_returns_dict_when_present() -> void:
	var session := _make_session_with_state()
	session.star_map_system.region_maps["r1"] = {"fog_grid_size": 64}
	var vm := NavigationViewModel.new(session)
	assert_eq(vm.region_map("r1"), {"fog_grid_size": 64})


func test_visible_story_pois_passes_game_state_to_system() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	vm.visible_story_pois("r1")
	assert_eq(session.star_map_system.visible_story_calls.size(), 1)
	assert_same(session.star_map_system.visible_story_calls[0]["gs"], session.game_state)


# ---------------------------------------------------------------------------
# Encounters, missions, narrative, karma
# ---------------------------------------------------------------------------

func test_available_encounters_passes_game_state() -> void:
	var session := _make_session_with_state()
	session.encounter_engine.available = ["enc_a", "enc_b"]
	var vm := NavigationViewModel.new(session)
	var result: Array = vm.available_encounters()
	assert_eq(result, ["enc_a", "enc_b"])
	assert_same(session.encounter_engine.last_gs, session.game_state)


func test_update_distress_passes_dt_and_state() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	vm.update_distress(0.5)
	assert_eq(session.side_mission_system.last_call["dt"], 0.5)
	assert_same(session.side_mission_system.last_call["gs"], session.game_state)


func test_arc_title_delegates_with_current_arc() -> void:
	var session := _make_session_with_state()
	session.narrative.arc_titles["arc1"] = "Awakening"
	var vm := NavigationViewModel.new(session)
	assert_eq(vm.arc_title(), "Awakening")


func test_has_karma_system_true_when_set() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	assert_true(vm.has_karma_system())


func test_karma_tier_label_delegates() -> void:
	var session := _make_session_with_state()
	session.karma_system.tier_label_value = "Hero"
	var vm := NavigationViewModel.new(session)
	assert_eq(vm.karma_tier_label(), "Hero")


# ---------------------------------------------------------------------------
# Exploration / connected regions
# ---------------------------------------------------------------------------

func test_connected_regions_empty_when_region_missing() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	assert_eq(vm.connected_regions("missing_region"), [])


func test_connected_regions_returns_array() -> void:
	var session := _make_session_with_state()
	var region_obj := RegionDouble.new()
	region_obj.connected_regions = ["r2", "r3"]
	session.exploration.regions["r1"] = region_obj
	var vm := NavigationViewModel.new(session)
	assert_eq(vm.connected_regions("r1"), ["r2", "r3"])


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func test_travel_to_region_delegates_and_returns_result() -> void:
	var session := _make_session_with_state()
	session.travel_result = true
	var vm := NavigationViewModel.new(session)
	assert_true(vm.travel_to_region("r_target"))
	assert_eq(session.travel_calls, ["r_target"])


func test_land_on_planet_delegates_and_returns_result() -> void:
	var session := _make_session_with_state()
	session.land_result = false
	var vm := NavigationViewModel.new(session)
	assert_false(vm.land_on_planet("fringe_haven"))
	assert_eq(session.land_calls, ["fringe_haven"])


# ---------------------------------------------------------------------------
# Star base
# ---------------------------------------------------------------------------

func test_dock_forwards_call() -> void:
	var session := _make_session_with_state()
	var vm := NavigationViewModel.new(session)
	vm.dock("base_a")
	assert_eq(session.star_base_system.dock_calls, ["base_a"])


func test_can_dock_delegates() -> void:
	var session := _make_session_with_state()
	session.star_base_system.can_dock_by_id["base_a"] = true
	var vm := NavigationViewModel.new(session)
	assert_true(vm.can_dock("base_a"))
	assert_false(vm.can_dock("base_b"))
