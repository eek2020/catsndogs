extends GutTest

## Regression coverage for StarMapViewModel (Sprint 5a, NEXT_STEPS.md §2).
## The VM is the only path star_map_screen.gd and its layer components use to
## reach GameSession. Tests construct a VM with a SessionDouble + tiny
## RefCounted doubles for star_map_system and exploration so the screen's
## read + action paths can be exercised without the autoload wiring.


class SessionDouble:
	extends RefCounted
	var game_state: GameStateData = null
	var star_map_system = null
	var exploration = null
	var last_travel_region: String = ""
	var travel_result: bool = true

	func travel_to_region(region_id: String) -> bool:
		last_travel_region = region_id
		return travel_result

	# NB: `set_meta` is inherited from Object, so VM calls to
	# `_session.set_meta(...)` exercise the native implementation here. Tests
	# read it back via the native `get_meta(key)`.


class StarMapDouble:
	extends RefCounted
	var bounds_by_region: Dictionary = {}
	var galaxy_layout: Dictionary = {}
	var grid_dimensions: Dictionary = {}
	var region_maps: Dictionary = {}
	var cartographer_rescued: bool = false
	var owned_maps: Array = []
	var revealed_cells: Dictionary = {}  # region_id -> Dict[Vector2i, bool]
	var node_pos_by_region: Dictionary = {}
	var node_color_by_region: Dictionary = {}
	var fog_pct_by_region: Dictionary = {}
	var story_pois_by_region: Dictionary = {}
	var hidden_pois_by_region: Dictionary = {}
	var spawns_by_region: Dictionary = {}
	var last_get_story_pois_state: GameStateData = null

	func get_bounds(region_id: String) -> Vector2:
		return bounds_by_region.get(region_id, Vector2.ZERO)

	func get_galaxy_node_pos(region_id: String) -> Vector2:
		return node_pos_by_region.get(region_id, Vector2.ZERO)

	func get_galaxy_node_color(region_id: String) -> Color:
		return node_color_by_region.get(region_id, Color.WHITE)

	func get_region_fog_percentage(region_id: String) -> float:
		return fog_pct_by_region.get(region_id, 0.0)

	func has_map(region_id: String) -> bool:
		return region_id in owned_maps

	func is_cell_revealed(region_id: String, cx: int, cy: int) -> bool:
		var key := Vector2i(cx, cy)
		var region_map: Dictionary = revealed_cells.get(region_id, {})
		return region_map.get(key, false)

	func get_visible_story_pois(region_id: String, gs: GameStateData) -> Array:
		last_get_story_pois_state = gs
		return story_pois_by_region.get(region_id, [])

	func get_visible_hidden_pois(region_id: String) -> Array:
		return hidden_pois_by_region.get(region_id, [])

	func get_visible_spawns(region_id: String) -> Array:
		return spawns_by_region.get(region_id, [])


class ExplorationDouble:
	extends RefCounted
	var regions: Dictionary = {}  # region_id -> Region


func _make_region(id: String, name_: String = "", discovered: bool = true) -> ExplorationSystem.Region:
	var region := ExplorationSystem.Region.new()
	region.region_id = id
	region.region_name = name_ if not name_.is_empty() else id.capitalize()
	region.is_discovered = discovered
	return region


func _make_session_with_state(region_id: String = "starting_realm") -> SessionDouble:
	var session := SessionDouble.new()
	var gs := GameStateData.new()
	gs.current_region = region_id
	gs.position_x = 1000.0
	gs.position_y = 2000.0
	session.game_state = gs
	return session


# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------

func test_has_state_false_when_game_state_null() -> void:
	var session := SessionDouble.new()
	var vm := StarMapViewModel.new(session)
	assert_false(vm.has_state())


func test_has_state_true_when_game_state_set() -> void:
	var session := _make_session_with_state()
	var vm := StarMapViewModel.new(session)
	assert_true(vm.has_state())


func test_current_region_returns_state_region() -> void:
	var session := _make_session_with_state("feline_courts")
	var vm := StarMapViewModel.new(session)
	assert_eq(vm.current_region(), "feline_courts")


func test_current_region_empty_when_no_state() -> void:
	var session := SessionDouble.new()
	var vm := StarMapViewModel.new(session)
	assert_eq(vm.current_region(), "")


func test_player_position_reads_state() -> void:
	var session := _make_session_with_state()
	var vm := StarMapViewModel.new(session)
	assert_eq(vm.player_position(), Vector2(1000.0, 2000.0))


func test_player_position_zero_when_no_state() -> void:
	var session := SessionDouble.new()
	var vm := StarMapViewModel.new(session)
	assert_eq(vm.player_position(), Vector2.ZERO)


# ---------------------------------------------------------------------------
# Star map wrappers
# ---------------------------------------------------------------------------

func test_star_map_wrappers_tolerate_null_system() -> void:
	var session := _make_session_with_state()
	var vm := StarMapViewModel.new(session)
	# star_map_system intentionally left null on the SessionDouble.
	assert_false(vm.has_star_map())
	assert_eq(vm.region_bounds("r"), Vector2.ZERO)
	assert_eq(vm.galaxy_layout(), {})
	assert_eq(vm.galaxy_nodes(), {})
	assert_eq(vm.galaxy_node_pos("r"), Vector2.ZERO)
	assert_eq(vm.galaxy_node_color("r"), Color.WHITE)
	assert_eq(vm.region_fog_percentage("r"), 0.0)
	assert_false(vm.has_map("r"))
	assert_false(vm.cartographer_rescued())
	assert_eq(vm.region_map("r"), {})
	assert_eq(vm.grid_dimensions("r"), Vector2i.ZERO)
	assert_false(vm.is_cell_revealed("r", 0, 0))


func test_region_bounds_delegates() -> void:
	var session := _make_session_with_state()
	var sms := StarMapDouble.new()
	sms.bounds_by_region = {"starting_realm": Vector2(4000.0, 3000.0)}
	session.star_map_system = sms
	var vm := StarMapViewModel.new(session)
	assert_eq(vm.region_bounds("starting_realm"), Vector2(4000.0, 3000.0))


func test_galaxy_nodes_reads_layout_dict() -> void:
	var session := _make_session_with_state()
	var sms := StarMapDouble.new()
	sms.galaxy_layout = {"nodes": {"a": {"gx": 0.2, "gy": 0.5}, "b": {"gx": 0.7, "gy": 0.4}}}
	session.star_map_system = sms
	var vm := StarMapViewModel.new(session)
	var nodes := vm.galaxy_nodes()
	assert_eq(nodes.size(), 2)
	assert_true(nodes.has("a"))
	assert_true(nodes.has("b"))


func test_has_map_reflects_owned_maps() -> void:
	var session := _make_session_with_state()
	var sms := StarMapDouble.new()
	sms.owned_maps = ["starting_realm"]
	session.star_map_system = sms
	var vm := StarMapViewModel.new(session)
	assert_true(vm.has_map("starting_realm"))
	assert_false(vm.has_map("feline_courts"))


func test_is_cell_revealed_routes_to_system() -> void:
	var session := _make_session_with_state()
	var sms := StarMapDouble.new()
	sms.revealed_cells = {"starting_realm": {Vector2i(3, 4): true}}
	session.star_map_system = sms
	var vm := StarMapViewModel.new(session)
	assert_true(vm.is_cell_revealed("starting_realm", 3, 4))
	assert_false(vm.is_cell_revealed("starting_realm", 0, 0))


func test_cartographer_rescued_reflects_flag() -> void:
	var session := _make_session_with_state()
	var sms := StarMapDouble.new()
	sms.cartographer_rescued = true
	session.star_map_system = sms
	var vm := StarMapViewModel.new(session)
	assert_true(vm.cartographer_rescued())


# ---------------------------------------------------------------------------
# POIs
# ---------------------------------------------------------------------------

func test_visible_story_pois_passes_game_state() -> void:
	var session := _make_session_with_state()
	var sms := StarMapDouble.new()
	sms.story_pois_by_region = {"starting_realm": [{"id": "p1", "x": 100.0, "y": 200.0}]}
	session.star_map_system = sms
	var vm := StarMapViewModel.new(session)
	var pois := vm.visible_story_pois("starting_realm")
	assert_eq(pois.size(), 1)
	assert_eq(sms.last_get_story_pois_state, session.game_state)


func test_visible_story_pois_empty_when_no_state() -> void:
	var session := SessionDouble.new()
	var sms := StarMapDouble.new()
	session.star_map_system = sms
	var vm := StarMapViewModel.new(session)
	assert_eq(vm.visible_story_pois("r"), [])


func test_visible_hidden_and_spawn_pois_delegate() -> void:
	var session := _make_session_with_state()
	var sms := StarMapDouble.new()
	sms.hidden_pois_by_region = {"r": [{"id": "h"}]}
	sms.spawns_by_region = {"r": [{"id": "s"}, {"id": "s2"}]}
	session.star_map_system = sms
	var vm := StarMapViewModel.new(session)
	assert_eq(vm.visible_hidden_pois("r").size(), 1)
	assert_eq(vm.visible_spawns("r").size(), 2)


# ---------------------------------------------------------------------------
# Exploration
# ---------------------------------------------------------------------------

func test_region_is_discovered_reads_region_flag() -> void:
	var session := _make_session_with_state()
	var exp_double := ExplorationDouble.new()
	exp_double.regions = {
		"known": _make_region("known", "Known", true),
		"fog": _make_region("fog", "Fog", false),
	}
	session.exploration = exp_double
	var vm := StarMapViewModel.new(session)
	assert_true(vm.region_is_discovered("known"))
	assert_false(vm.region_is_discovered("fog"))
	assert_false(vm.region_is_discovered("missing_region"))


func test_region_display_name_falls_back_to_title_case_id() -> void:
	var session := _make_session_with_state()
	var exp_double := ExplorationDouble.new()
	exp_double.regions = {"known": _make_region("known", "The Known Sector")}
	session.exploration = exp_double
	var vm := StarMapViewModel.new(session)
	assert_eq(vm.region_display_name("known"), "The Known Sector")
	assert_eq(vm.region_display_name("feline_courts"), "Feline Courts")


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func test_travel_to_region_delegates_and_returns_result() -> void:
	var session := _make_session_with_state()
	session.travel_result = true
	var vm := StarMapViewModel.new(session)
	var ok: bool = vm.travel_to_region("feline_courts")
	assert_true(ok)
	assert_eq(session.last_travel_region, "feline_courts")


func test_travel_to_region_returns_false_when_session_refuses() -> void:
	var session := _make_session_with_state()
	session.travel_result = false
	var vm := StarMapViewModel.new(session)
	assert_false(vm.travel_to_region("nowhere"))


func test_set_world_entry_region_writes_meta() -> void:
	var session := _make_session_with_state()
	var vm := StarMapViewModel.new(session)
	vm.set_world_entry_region("starting_realm")
	assert_eq(session.get_meta("world_entry_region", ""), "starting_realm")
