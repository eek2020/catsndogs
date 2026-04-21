## Smoke test for planet_surface_3d — the procedural 3D planet scene shipped
## in Sprint 10 step 10.
##
## Covers what a visual-only check can't: the Control + SubViewportContainer
## tree actually instantiates, Character3D merchants mount under the 3D world,
## treasure persistence round-trips, and depart flushes planet_inventory into
## the ship. Guards against the step-11b invisibility bug sneaking back in at
## this camera scale, and against `planet_system.depart` regressions.
extends "res://addons/gut/test.gd"

const SCENE_PATH := "res://scenes/world/planet_surface_3d.tscn"
const TEST_PLANET_ID := "fringe_haven"  # has a treasure ("fringe_cache")


func _boot_session() -> void:
	GameSession.start_new_game("aristotle")
	GameSession.game_state.current_planet_id = TEST_PLANET_ID
	# start_new_game doesn't land; land() initialises planet_states entry.
	GameSession.planet_system.land(GameSession.game_state, TEST_PLANET_ID)


func _instantiate_scene() -> Control:
	var scene: PackedScene = load(SCENE_PATH)
	var root: Control = scene.instantiate()
	add_child_autofree(root)
	# Scene builds its world tree during _ready; wait a frame so child nodes exist.
	await get_tree().process_frame
	return root


func test_scene_instantiates_with_3d_world() -> void:
	_boot_session()
	var root := await _instantiate_scene()
	assert_not_null(root, "scene must instantiate")

	# The SubViewport + Node3D("World") tree must exist. If step-11b's
	# invisibility bug ever re-manifests at this camera distance, this is the
	# first place symptoms show.
	var container: SubViewportContainer = null
	for child in root.get_children():
		if child is SubViewportContainer:
			container = child
			break
	assert_not_null(container, "SubViewportContainer must be under the Control root")

	var viewport := container.get_child(0) as SubViewport
	assert_not_null(viewport, "SubViewport must be under the container")

	var world := viewport.get_node_or_null("World")
	assert_not_null(world, "World Node3D must exist under the SubViewport")


func test_merchants_mount_as_character3d_rigs() -> void:
	_boot_session()
	var root := await _instantiate_scene()

	# Find any Character3D under the 3D world — merchants are built from
	# `felid_corsair_guard` rigs and should end up in the tree as Character3D
	# descendants. If the scene can't mount rigs, there'd be zero.
	var found := _find_descendant_of_type(root, "Character3D")
	assert_not_null(found, "at least one Character3D must mount under the planet scene")


func test_treasure_collect_and_persist_round_trip() -> void:
	_boot_session()
	var gs: GameStateData = GameSession.game_state
	var ps: PlanetSystem = GameSession.planet_system

	assert_false(ps.is_treasure_cleared(gs, TEST_PLANET_ID, "fringe_cache"),
		"treasure must start uncleared")

	var before_crystals: int = int(gs.planet_inventory.get("crystals", 0))
	var before_salvage: int = int(gs.planet_inventory.get("salvage", 0))
	var reward := ps.collect_treasure(gs, TEST_PLANET_ID, "fringe_cache")
	assert_false(reward.is_empty(), "first collect must return reward")
	assert_true(ps.is_treasure_cleared(gs, TEST_PLANET_ID, "fringe_cache"),
		"treasure must be flagged cleared after collect")
	assert_eq(
		int(gs.planet_inventory.get("crystals", 0)),
		before_crystals + int(reward.get("reward_crystals", 0)),
		"crystals reward must land in planet_inventory"
	)
	assert_eq(
		int(gs.planet_inventory.get("salvage", 0)),
		before_salvage + int(reward.get("reward_salvage", 0)),
		"salvage reward must land in planet_inventory"
	)

	# Second collect must be a no-op — step 10 uses this to prevent double-grab.
	var second := ps.collect_treasure(gs, TEST_PLANET_ID, "fringe_cache")
	assert_true(second.is_empty(), "second collect must return empty")


func test_depart_flushes_planet_inventory_into_ship() -> void:
	_boot_session()
	var gs: GameStateData = GameSession.game_state
	var ps: PlanetSystem = GameSession.planet_system

	gs.planet_inventory = {"crystals": 7, "salvage": 13}
	var ship_crystals_before: int = gs.crystal_inventory
	var ship_salvage_before: int = gs.salvage

	ps.depart(gs)

	assert_eq(gs.current_planet_id, "", "depart must clear current_planet_id")
	assert_eq(gs.planet_inventory, {}, "depart must empty planet_inventory")
	assert_eq(gs.crystal_inventory, ship_crystals_before + 7,
		"crystals must merge into ship inventory")
	assert_eq(gs.salvage, ship_salvage_before + 13,
		"salvage must merge into ship inventory")


# ── helpers ─────────────────────────────────────────────────────────

func _find_descendant_of_type(root: Node, class_name_str: String) -> Node:
	for child in root.get_children():
		var scripted: bool = child.get_script() != null and _script_is(child, class_name_str)
		if child.get_class() == class_name_str or scripted:
			return child
		var nested := _find_descendant_of_type(child, class_name_str)
		if nested != null:
			return nested
	return null


func _script_is(node: Node, class_name_str: String) -> bool:
	var script: Script = node.get_script()
	if script == null:
		return false
	var s: Script = script
	while s != null:
		if s.resource_path.get_file().get_basename() == class_name_str.to_snake_case():
			return true
		s = s.get_base_script()
	return false
