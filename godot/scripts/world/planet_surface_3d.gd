## Procedural 3D planet surface — replaces the 2D `planet_surface.tscn` flow.
##
## Routed to via main.gd's SCENES["planet"] key. Reads the current planet
## from `GameSession.planet_system.get_planet(gs.current_planet_id)` and lays
## out a procedural outpost seeded on `planet_id` so each planet has a
## consistent (but distinct) layout. Merchants + treasures come from the
## planet data; depart routes through `planet_system.depart(gs)` which
## flushes the planet inventory into the ship before returning to navigation.
##
## Kept in one file for the same reason as `fringe_haven_3d.gd` — iterating
## on a procedural 3D layer is faster when the whole composition is legible
## end-to-end. Patterns (CharacterBody3D player, ortho camera, building
## primitives, interaction distance-poll, HUD) mirror fringe_haven_3d.
extends Control

const MOVE_SPEED: float = 1.8
const SPRINT_SPEED: float = 4.5
const CAMERA_ORTHO_SIZE: float = 6.0
const CAMERA_PITCH_DEG: float = 55.0
const CAMERA_YAW_DEG: float = 0.0
const CAMERA_DISTANCE: float = 18.0
const GROUND_SIZE: float = 60.0
const INTERACT_RADIUS: float = 2.5
const CHARACTER_3D_SCENE: PackedScene = preload(
	"res://scenes/characters/character_3d.tscn"
)

# Layout tunables — hand-picked so the scene reads the same as fringe_haven
# at this camera distance. Buildings avoid the central crossroads.
const BUILDING_COUNT_MIN: int = 4
const BUILDING_COUNT_MAX: int = 8
const CROSSROADS_KEEPOUT: float = 3.5   # metres from (0,0) where nothing spawns
const WORLD_RADIUS: float = 18.0         # outer extent for placement

enum InteractKind { NONE, MERCHANT, TREASURE }

# ── Node references (built in _ready, not a .tscn) ──────────────────────
var _world: Node3D = null
var _player: CharacterBody3D = null
var _character: Character3D = null
var _camera_rig: Node3D = null
var _camera: Camera3D = null
var _velocity_planar: Vector3 = Vector3.ZERO

# Planet state
var _planet: Planet = null

# Interaction registry (pattern from fringe_haven_3d.gd).
var _interact_points: Dictionary = {}
var _next_interact_id: int = 1
var _active_zones: Dictionary = {}

# Treasure bookkeeping — `_treasure_chests[treasure_id] = { "lid": MeshInstance3D,
# "sparkle": MeshInstance3D, "zone_id": int }` so _collect_treasure can update
# the visuals and remove the zone.
var _treasure_chests: Dictionary = {}
# Merchant data lookup by zone id so _open_merchant can grab the faction id.
var _merchant_zone_data: Dictionary = {}

# HUD
var _hud_title: Label = null
var _hud_loot: Label = null
var _hud_hint_depart: Label = null
var _hud_hint_interact: Label = null
var _hud_flash: Label = null
var _flash_timer: float = 0.0

var _elapsed: float = 0.0


func _ready() -> void:
	# Fill screen so the ortho camera's viewport covers the whole window.
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gs: GameStateData = GameSession.game_state
	if gs == null or gs.current_planet_id.is_empty():
		return
	_planet = GameSession.planet_system.get_planet(gs.current_planet_id)
	if _planet == null:
		return
	GameSession.planet_system.get_planet_state(gs, _planet.planet_id)
	MusicManager.on_state_change("trade")

	_build_world_root()
	_build_environment()
	_build_ground()
	_build_buildings_procedural()
	_build_trees_procedural()
	_build_merchants(gs)
	_build_treasures(gs)
	_build_player()
	_build_camera()
	_build_hud()
	_update_loot_label()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	_update_hud(delta)


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_up") - Input.get_action_strength("move_down"),
	)
	var yaw := deg_to_rad(CAMERA_YAW_DEG)
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var sprinting := Input.is_action_pressed("sprint")
	var speed: float = SPRINT_SPEED if sprinting else MOVE_SPEED
	var v := right * input.x + forward * input.y
	if v.length() > 0.1:
		v = v.normalized() * speed
	else:
		v = Vector3.ZERO
	_player.velocity = v
	_player.move_and_slide()

	if _character:
		var want := "idle"
		if v.length() > 0.1:
			want = "run" if sprinting else "walk"
			if sprinting and not _character.available_anims().has("run"):
				want = "walk"
		if _character.current_anim() != want:
			_character.play_anim(want)
		if v.length() > 0.1:
			_character.rotation.y = atan2(v.x, v.z)

	if _camera_rig:
		_camera_rig.global_position = _player.global_position

	_poll_interact_zones()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_depart()
			return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_try_interact()


func _on_depart() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs and GameSession.planet_system:
		GameSession.planet_system.depart(gs)
	MusicManager.on_state_change("navigation")
	var main_node := get_tree().current_scene
	if main_node and main_node.has_method("switch_scene"):
		main_node.switch_scene("navigation")


# ── World root ─────────────────────────────────────────────────────────

# All 3D content parents under a SubViewport so the Control-rooted scene can
# host a 3D world without rewriting main.gd's scene container (which expects
# every key to resolve to a Control).
func _build_world_root() -> void:
	var container := SubViewportContainer.new()
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	container.add_child(viewport)

	_world = Node3D.new()
	_world.name = "World"
	viewport.add_child(_world)


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.78, 0.95)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.85)
	e.ambient_light_energy = 0.6
	env.environment = e
	_world.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(-35)) * Basis(Vector3.RIGHT, deg_to_rad(-50)),
		Vector3(0, 10, 0),
	)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_world.add_child(sun)


func _build_ground() -> void:
	# Grass plane. No tileset here (fringe_haven's `overworld_tileset_16x16`
	# is Fringe-Haven-themed); flat colour keeps procedural planets neutral.
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.6, 0.35)
	mat.roughness = 0.95
	mi.material_override = mat
	_world.add_child(mi)

	# Stone crossroads at the origin — gives the player something to orient on.
	_add_path_strip(
		Vector3(0, 0, -12), Vector3(0, 0, 12), 2.5, Color(0.55, 0.55, 0.52), 0.010,
	)
	_add_path_strip(
		Vector3(-14, 0, 0), Vector3(14, 0, 0), 2.5, Color(0.55, 0.55, 0.52), 0.012,
	)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	body.add_child(col)
	_world.add_child(body)


func _add_path_strip(a: Vector3, b: Vector3, width: float, color: Color, y_offset: float = 0.01) -> void:
	var length := a.distance_to(b)
	if length <= 0.001:
		return
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(length, width)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	var mid := (a + b) * 0.5
	mi.position = mid + Vector3(0, y_offset, 0)
	var dir := (b - a).normalized()
	mi.rotation.y = atan2(dir.x, dir.z) - PI * 0.5
	_world.add_child(mi)


# ── Buildings ──────────────────────────────────────────────────────────

func _build_buildings_procedural() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_planet.planet_id)
	var count := rng.randi_range(BUILDING_COUNT_MIN, BUILDING_COUNT_MAX)
	var placed: Array = []    # Array of {pos: Vector3, half: Vector2}

	var attempts := 0
	while placed.size() < count and attempts < count * 6:
		attempts += 1
		var w := rng.randf_range(2.5, 4.5)
		var d := rng.randf_range(2.5, 4.0)
		# Pick a position avoiding the central crossroads and staying inside
		# WORLD_RADIUS. Bias toward the four quadrants (skip anything where
		# |x| or |z| is within CROSSROADS_KEEPOUT of the axis) so roads read.
		var px := rng.randf_range(-WORLD_RADIUS, WORLD_RADIUS)
		var pz := rng.randf_range(-WORLD_RADIUS, WORLD_RADIUS)
		if absf(px) < CROSSROADS_KEEPOUT or absf(pz) < CROSSROADS_KEEPOUT:
			continue
		var half := Vector2(w * 0.5 + 0.4, d * 0.5 + 0.4)  # +0.4m gap
		var pos := Vector3(px, 0, pz)
		var overlaps := false
		for other in placed:
			var other_pos: Vector3 = other["pos"]
			var other_half: Vector2 = other["half"]
			if absf(pos.x - other_pos.x) < (half.x + other_half.x) \
					and absf(pos.z - other_pos.z) < (half.y + other_half.y):
				overlaps = true
				break
		if overlaps:
			continue
		placed.append({"pos": pos, "half": half})
		var roof_color := _roof_color(rng)
		_make_building(pos, Vector2(w, d), rng.randf_range(1.8, 2.4), roof_color)


func _roof_color(rng: RandomNumberGenerator) -> Color:
	var palette := [
		Color(0.72, 0.22, 0.22),   # red
		Color(0.32, 0.55, 0.32),   # green
		Color(0.22, 0.42, 0.7),    # blue
		Color(0.68, 0.5, 0.22),    # ochre
	]
	return palette[rng.randi() % palette.size()]


func _make_building(pos: Vector3, size: Vector2, wall_height: float, roof_color: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	_world.add_child(root)

	# Walls.
	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, wall_height, size.y)
	walls.mesh = box
	walls.position.y = wall_height * 0.5
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.87, 0.75, 0.55)
	wall_mat.roughness = 0.95
	walls.material_override = wall_mat
	root.add_child(walls)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, wall_height, size.y)
	col.shape = shape
	col.position.y = wall_height * 0.5
	body.add_child(col)
	root.add_child(body)

	# Pitched roof (copy of fringe_haven_3d's geometry).
	var roof := MeshInstance3D.new()
	var roof_box := BoxMesh.new()
	var roof_height: float = 1.2
	var overhang: float = 0.25
	roof_box.size = Vector3(size.x + overhang * 2.0, roof_height, size.y + overhang * 2.0)
	roof.mesh = roof_box
	roof.rotation.x = deg_to_rad(30.0)
	var pitch := deg_to_rad(30.0)
	var depth_half: float = size.y * 0.5 + overhang
	var min_corner: float = roof_height * 0.5 * cos(pitch) + depth_half * sin(pitch)
	roof.position.y = wall_height + min_corner + 0.15
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = roof_color
	roof_mat.roughness = 0.85
	roof.material_override = roof_mat
	root.add_child(roof)

	# Door (visual only).
	var door := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(0.9, 1.6, 0.05)
	door.mesh = door_box
	door.position = Vector3(0, 0.8, size.y * 0.5 + 0.03)
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.32, 0.2, 0.12)
	door_mat.roughness = 0.9
	door.material_override = door_mat
	root.add_child(door)


# ── Trees ──────────────────────────────────────────────────────────────

# Simple procedural trees (trunk cylinder + canopy sphere) — no dependency on
# the Fringe Haven sprite sheet, so every procedural planet gets trees.
func _build_trees_procedural() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_planet.planet_id) + 17
	var tree_count := rng.randi_range(16, 26)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.38, 0.24, 0.14)
	trunk_mat.roughness = 0.95
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.25, 0.45, 0.25)
	canopy_mat.roughness = 0.85
	for _i in tree_count:
		# Ring around the outpost, keeping trees outside the usable play area
		# but still on-screen.
		var r: float = rng.randf_range(WORLD_RADIUS + 1.5, WORLD_RADIUS + 6.0)
		var theta: float = rng.randf_range(0.0, TAU)
		var pos := Vector3(cos(theta) * r, 0, sin(theta) * r)
		_make_tree(pos, trunk_mat, canopy_mat)


func _make_tree(pos: Vector3, trunk_mat: StandardMaterial3D, canopy_mat: StandardMaterial3D) -> void:
	var root := Node3D.new()
	root.position = pos
	_world.add_child(root)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 1.4
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = 0.7
	root.add_child(trunk)

	var canopy := MeshInstance3D.new()
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.9
	canopy_mesh.height = 1.8
	canopy.mesh = canopy_mesh
	canopy.material_override = canopy_mat
	canopy.position.y = 1.9
	root.add_child(canopy)


# ── Merchants ──────────────────────────────────────────────────────────

func _build_merchants(_gs: GameStateData) -> void:
	if _planet == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_planet.planet_id) + 31
	for m in _planet.merchants:
		var mid: String = m.get("merchant_id", "")
		var mname: String = m.get("name", "Merchant")
		var faction_id: String = m.get("faction_id", "")
		var pos := _find_npc_position(rng)
		_spawn_merchant_rig(pos, mname)
		var zone_id := _attach_interact_zone(pos, InteractKind.MERCHANT, null)
		_merchant_zone_data[zone_id] = {"faction_id": faction_id, "name": mname, "merchant_id": mid}


# Spawn a Character3D rig as an NPC — uses felid_corsair_guard for all
# procedural merchants (the rig we know is wired end-to-end). Real per-faction
# rigs can replace this once more characters ship with Mixamo anims.
func _spawn_merchant_rig(pos: Vector3, label: String) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	col.shape = capsule
	col.position.y = 0.8
	body.add_child(col)
	_world.add_child(body)

	var npc: Character3D = CHARACTER_3D_SCENE.instantiate()
	npc.character_id = "felid_corsair_guard"
	npc.autoplay = "idle"
	body.add_child(npc)
	npc.initialize()

	var tag := Label3D.new()
	tag.text = label
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.008
	tag.no_depth_test = true
	tag.modulate = Color(1.0, 0.95, 0.7)
	tag.outline_modulate = Color(0, 0, 0, 1)
	tag.outline_size = 6
	tag.position = pos + Vector3(0, 2.2, 0)
	_world.add_child(tag)


# ── Treasures ──────────────────────────────────────────────────────────

func _build_treasures(gs: GameStateData) -> void:
	if _planet == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_planet.planet_id) + 59
	for t in _planet.treasures:
		var tid: String = t.get("treasure_id", "")
		var pos := _find_npc_position(rng)
		var cleared := GameSession.planet_system.is_treasure_cleared(gs, _planet.planet_id, tid)
		var parts := _make_treasure_chest(pos, cleared)
		_treasure_chests[tid] = parts
		if not cleared:
			var zone_id := _attach_interact_zone(pos, InteractKind.TREASURE, tid)
			parts["zone_id"] = zone_id


func _make_treasure_chest(pos: Vector3, opened: bool) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	_world.add_child(root)

	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(0.9, 0.55, 0.6)
	base.mesh = base_box
	base.position.y = 0.275
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.42, 0.26, 0.14)
	base_mat.roughness = 0.9
	base.material_override = base_mat
	root.add_child(base)

	var chest_body := StaticBody3D.new()
	var chest_col := CollisionShape3D.new()
	var chest_shape := BoxShape3D.new()
	chest_shape.size = Vector3(0.95, 0.75, 0.65)
	chest_col.shape = chest_shape
	chest_col.position.y = 0.375
	chest_body.add_child(chest_col)
	root.add_child(chest_body)

	var lid := MeshInstance3D.new()
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(0.95, 0.2, 0.65)
	lid.mesh = lid_box
	lid.position.y = 0.65
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.52, 0.34, 0.18)
	lid_mat.roughness = 0.85
	lid.material_override = lid_mat
	root.add_child(lid)

	var band := MeshInstance3D.new()
	var band_box := BoxMesh.new()
	band_box.size = Vector3(0.92, 0.08, 0.02)
	band.mesh = band_box
	band.position = Vector3(0, 0.35, 0.31)
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.85, 0.65, 0.22)
	band_mat.metallic = 0.6
	band_mat.roughness = 0.3
	band.material_override = band_mat
	root.add_child(band)

	var sparkle := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.24
	sparkle.mesh = sp
	sparkle.position = Vector3(0, 1.1, 0)
	var sp_mat := StandardMaterial3D.new()
	sp_mat.albedo_color = Color(1.0, 0.92, 0.45)
	sp_mat.emission_enabled = true
	sp_mat.emission = Color(1.0, 0.85, 0.35)
	sp_mat.emission_energy_multiplier = 3.0
	sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle.material_override = sp_mat
	sparkle.visible = not opened
	root.add_child(sparkle)

	if opened:
		lid.rotation.x = deg_to_rad(-55.0)
		lid.position = Vector3(0, 0.65, -0.1)

	return {"lid": lid, "sparkle": sparkle, "zone_id": -1}


# ── Placement helpers ──────────────────────────────────────────────────

# Find an NPC/treasure spawn position: inside WORLD_RADIUS, outside the
# crossroads keepout, with at least 1.8m separation from previously chosen
# spots. Falls back to a random in-ring position if no clean candidate found.
var _occupied_points: Array = []

func _find_npc_position(rng: RandomNumberGenerator) -> Vector3:
	for _attempt in 40:
		var r: float = rng.randf_range(4.0, WORLD_RADIUS - 2.0)
		var theta: float = rng.randf_range(0.0, TAU)
		var pos := Vector3(cos(theta) * r, 0, sin(theta) * r)
		if absf(pos.x) < CROSSROADS_KEEPOUT and absf(pos.z) < CROSSROADS_KEEPOUT:
			continue
		var too_close := false
		for other in _occupied_points:
			if (pos - (other as Vector3)).length() < 2.2:
				too_close = true
				break
		if too_close:
			continue
		_occupied_points.append(pos)
		return pos
	# Fallback
	var fallback := Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
	_occupied_points.append(fallback)
	return fallback


# ── Player + camera (same shape as fringe_haven_3d) ────────────────────

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "Player"
	# Spawn on the crossroads — always clear of buildings.
	_player.position = Vector3(0, 0, 0)
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.6
	col.shape = shape
	col.position.y = 0.8
	_player.add_child(col)
	_world.add_child(_player)

	var gs: GameStateData = GameSession.game_state
	var pid := gs.protagonist_id if gs else "aristotle"
	_character = CHARACTER_3D_SCENE.instantiate()
	_character.character_id = pid
	_character.autoplay = "idle"
	_player.add_child(_character)
	_character.initialize()


func _build_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	_world.add_child(_camera_rig)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_ORTHO_SIZE
	_camera.current = true

	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	var yaw := deg_to_rad(CAMERA_YAW_DEG)
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch),
	) * CAMERA_DISTANCE
	_camera.transform = Transform3D(Basis(), offset).looking_at(Vector3.ZERO, Vector3.UP)
	_camera_rig.add_child(_camera)


# ── Interaction (mirrors fringe_haven_3d.gd) ───────────────────────────

func _attach_interact_zone(pos: Vector3, kind: int, data: Variant) -> int:
	var id := _next_interact_id
	_next_interact_id += 1
	_interact_points[id] = {
		"pos": pos, "kind": kind, "data": data, "radius": INTERACT_RADIUS,
	}
	return id


func _poll_interact_zones() -> void:
	if _player == null:
		return
	var pp := _player.global_position
	var next: Dictionary = {}
	for id in _interact_points:
		var entry: Dictionary = _interact_points[id]
		var p: Vector3 = entry["pos"]
		var dx := pp.x - p.x
		var dz := pp.z - p.z
		var r: float = entry.get("radius", INTERACT_RADIUS)
		if (dx * dx + dz * dz) <= (r * r):
			next[id] = {"kind": entry["kind"], "data": entry["data"]}
	_active_zones = next


func _try_interact() -> void:
	if _active_zones.is_empty():
		_flash("Nothing to interact with here.", 1.2)
		return
	for aid in _active_zones:
		var entry: Dictionary = _active_zones[aid]
		var kind: int = entry.get("kind", InteractKind.NONE)
		if kind == InteractKind.MERCHANT:
			_open_merchant(aid)
			return
		if kind == InteractKind.TREASURE:
			_collect_treasure(aid, entry.get("data", ""))
			return


func _open_merchant(zone_id: int) -> void:
	var data: Dictionary = _merchant_zone_data.get(zone_id, {})
	var faction_id: String = data.get("faction_id", "")
	GameSession.open_trade_screen(faction_id)
	var main_node := get_tree().current_scene
	if main_node and main_node.has_method("push_overlay"):
		main_node.push_overlay("trade")


func _collect_treasure(zone_id: int, treasure_id: String) -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null or _planet == null:
		return
	if GameSession.planet_system.is_treasure_cleared(gs, _planet.planet_id, treasure_id):
		return
	var reward: Dictionary = GameSession.planet_system.collect_treasure(
		gs, _planet.planet_id, treasure_id
	)
	if reward.is_empty():
		return
	# Pop the visuals + zone.
	var parts: Dictionary = _treasure_chests.get(treasure_id, {})
	var lid: MeshInstance3D = parts.get("lid")
	var sparkle: MeshInstance3D = parts.get("sparkle")
	if lid:
		lid.rotation.x = deg_to_rad(-55.0)
		lid.position = Vector3(0, 0.65, -0.1)
	if sparkle:
		sparkle.visible = false
	_interact_points.erase(zone_id)
	_active_zones.erase(zone_id)
	_flash(
		"Found: %s (+%dC +%dS)" % [
			reward.get("name", "Treasure"),
			int(reward.get("reward_crystals", 0)),
			int(reward.get("reward_salvage", 0)),
		], 3.0,
	)
	_update_loot_label()


# ── HUD ────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	# Labels as direct children of the Control root — they sit above the
	# SubViewportContainer automatically (Control draw order).
	var planet_name := _planet.planet_name if _planet else "PLANET"
	_hud_title = _make_hud_label(
		planet_name.to_upper(), Vector2(0, 16),
		Color(1.0, 0.95, 0.7), 20,
	)
	_hud_title.anchor_left = 0.0
	_hud_title.anchor_right = 1.0
	_hud_title.offset_left = 0
	_hud_title.offset_right = 0
	_hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hud_title)

	_hud_loot = _make_hud_label(
		"Loot: 0C 0S", Vector2(-180, 16),
		Color(0.85, 0.95, 1.0), 14,
	)
	_hud_loot.anchor_left = 1.0
	_hud_loot.anchor_right = 1.0
	_hud_loot.offset_left = -180
	_hud_loot.offset_right = -20
	_hud_loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hud_loot)

	_hud_hint_depart = _make_hud_label(
		"DEPART — ESC     RUN — SHIFT",
		Vector2(20, 20), Color(1.0, 0.95, 0.7), 14,
	)
	add_child(_hud_hint_depart)

	_hud_hint_interact = _make_hud_label(
		"[E] Interact", Vector2(20, 48),
		Color(1.0, 0.9, 0.55), 14,
	)
	_hud_hint_interact.visible = false
	add_child(_hud_hint_interact)

	_hud_flash = _make_hud_label(
		"", Vector2(0, 84), Color(1.0, 0.95, 0.7), 16,
	)
	_hud_flash.anchor_left = 0.0
	_hud_flash.anchor_right = 1.0
	_hud_flash.offset_left = 0
	_hud_flash.offset_right = 0
	_hud_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_flash.visible = false
	add_child(_hud_flash)


func _make_hud_label(text: String, pos: Vector2, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _update_hud(delta: float) -> void:
	if _hud_hint_interact:
		_hud_hint_interact.visible = not _active_zones.is_empty()
	if _hud_flash:
		if _flash_timer > 0.0:
			_flash_timer -= delta
			_hud_flash.visible = true
			_hud_flash.modulate.a = clampf(_flash_timer, 0.0, 1.0) if _flash_timer < 1.0 else 1.0
		else:
			_hud_flash.visible = false


func _flash(message: String, duration: float = 2.0) -> void:
	if _hud_flash == null:
		return
	_hud_flash.text = message
	_flash_timer = duration
	_hud_flash.modulate.a = 1.0
	_hud_flash.visible = true


func _update_loot_label() -> void:
	if _hud_loot == null:
		return
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return
	var inv: Dictionary = gs.planet_inventory
	_hud_loot.text = "Loot: %dC %dS" % [
		int(inv.get("crystals", 0)),
		int(inv.get("salvage", 0)),
	]
