## Fringe Haven — full 3D reimplementation (Option A prototype).
##
## Step 1: minimal scene — ground plane, sun, player (Character3D on a
## CharacterBody3D), ortho camera following the player. Once this renders
## cleanly we layer in paths, buildings, props, NPCs, and interactions.
##
## Built procedurally from code rather than a hand-crafted .tscn so iteration
## is fast and the composition stays legible in a single file.
extends Node3D

const MOVE_SPEED: float = 1.8
const SPRINT_SPEED: float = 4.5    # Shift / L3 — roughly 2.5× walk
const CAMERA_ORTHO_SIZE: float = 6.0
const CAMERA_PITCH_DEG: float = 55.0   # degrees below horizontal
const CAMERA_YAW_DEG: float = 0.0      # look straight down -Z so W = screen-up
const CAMERA_DISTANCE: float = 18.0
const GROUND_SIZE: float = 60.0        # metres; big enough to not see the edge
const TILESET_PATH: String = "res://assets/tiles/fringe_haven/overworld_tileset_16x16.png"
const WATER_PATH: String = "res://assets/tiles/fringe_haven/water_waves_32x32.png"
const SERENE_PATH: String = "res://assets/tiles/fringe_haven/serene_village_32x32.png"
const TILE_PX: int = 16
const SERENE_PX: int = 32
# Tileset atlas coords retained for billboard props (trees/campfire) that
# still read better as pixel-art sprites. Ground/paths moved to CC0 seamless
# textures in step 16 (2026-04-21) — see CC0_* paths below.
const GRASS_TILE: Vector2i = Vector2i(10, 4)
const DIRT_TILE: Vector2i = Vector2i(0, 3)
const STONE_TILE: Vector2i = Vector2i(7, 7)
# World size of a single tile, in metres. 1 tile ≈ half a character.
const TILE_METRES: float = 0.5

# CC0 seamless textures (Poly Haven, 1K JPG) — see assets/textures/fringe_haven/CREDITS.txt.
# One physical repeat covers GROUND_TEXTURE_METRES of world space. Tuned so tiling
# isn't obvious from the 3/4 ortho camera but detail still reads close-up.
const CC0_GRASS_PATH: String = "res://assets/textures/fringe_haven/grass_diff_1k.jpg"
const CC0_COBBLE_PATH: String = "res://assets/textures/fringe_haven/cobblestone_diff_1k.jpg"
const CC0_MUD_PATH: String = "res://assets/textures/fringe_haven/mud_diff_1k.jpg"
const CC0_PLASTER_PATH: String = "res://assets/textures/fringe_haven/plaster_diff_1k.jpg"
const CC0_WOOD_PATH: String = "res://assets/textures/fringe_haven/wood_planks_diff_1k.jpg"
const CC0_ROOF_PATH: String = "res://assets/textures/fringe_haven/roof_tiles_diff_1k.jpg"
const GROUND_TEXTURE_METRES: float = 4.0
const PATH_TEXTURE_METRES: float = 2.5
const WALL_TEXTURE_METRES: float = 2.0
const ROOF_TEXTURE_METRES: float = 1.6
const CHARACTER_3D_SCENE: PackedScene = preload(
	"res://scenes/characters/character_3d.tscn"
)

# Step 5 interaction tunables.
const MERCHANT_FACTION_ID: String = "felid_corsairs"
const CHEST_STORY_FLAG: String = "fringe_haven_chest_opened"
const CHEST_REWARD_CRYSTALS: int = 25
const CHEST_REWARD_SALVAGE: int = 10
const INTERACT_RADIUS: float = 2.5    # metres — distance-poll trigger radius

enum InteractKind { NONE, MERCHANT, CHEST }

var _player: CharacterBody3D = null
var _character: Character3D = null
var _camera_rig: Node3D = null
var _camera: Camera3D = null
var _velocity_planar: Vector3 = Vector3.ZERO
var _campfire_lights: Array[OmniLight3D] = []
var _campfire_flames: Array[MeshInstance3D] = []
var _anim_accum: float = 0.0

# Registered interaction points — `_physics_process` polls distance each
# tick and rebuilds `_active_zones`. Dict-based for stable IDs so the
# chest can remove its own entry once collected.
# _interact_points[id] = { "pos": Vector3, "kind": int, "data": Variant, "radius": float }
var _interact_points: Dictionary = {}
var _next_interact_id: int = 1
# Subset of _interact_points the player is currently within. Used by
# _try_interact and the HUD prompt.
var _active_zones: Dictionary = {}

# HUD
var _hud_hint_interact: Label = null
var _hud_hint_depart: Label = null
var _hud_flash: Label = null
var _flash_timer: float = 0.0

# Chest state — swapped between CLOSED/OPEN visuals on collect.
var _chest_lid: MeshInstance3D = null
var _chest_sparkle: MeshInstance3D = null
var _chest_light: OmniLight3D = null
var _chest_collected: bool = false


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_buildings()
	_build_props()
	_build_npcs()
	_build_chest()
	_build_player()
	_build_camera()
	_build_hud()
	set_process(true)


func _process(delta: float) -> void:
	_anim_accum += delta
	_update_hud(delta)
	_update_chest_sparkle()
	if _campfire_lights.is_empty():
		return
	# Deterministic per-fire flicker: two sine waves with different freqs per
	# index give each fire its own rhythm without an RNG.
	for i in range(_campfire_lights.size()):
		var l: OmniLight3D = _campfire_lights[i]
		if not is_instance_valid(l):
			continue
		var phase: float = _anim_accum * (6.0 + float(i) * 0.7)
		var flicker: float = 1.5 + 0.35 * sin(phase) + 0.2 * sin(phase * 2.3)
		l.light_energy = flicker
		if i < _campfire_flames.size() and is_instance_valid(_campfire_flames[i]):
			var s: float = 0.9 + 0.1 * sin(phase * 1.4)
			_campfire_flames[i].scale = Vector3(s, 0.9 + 0.15 * sin(phase), s)


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	# W/A/S/D (and arrows) should move camera-relative: W = toward top of
	# screen, D = toward right of screen, regardless of camera yaw. Input
	# axes are oriented so W makes y=+1 and D makes x=+1.
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_up") - Input.get_action_strength("move_down"),
	)
	var yaw := deg_to_rad(CAMERA_YAW_DEG)
	# Camera sits at (+sin, +, +cos) looking at origin, so into-screen from the
	# camera's view is -(+sin, 0, +cos). Right is forward rotated -90° about Y.
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
		# Pick idle / walk / run from current speed. "run" falls back to "walk"
		# automatically inside Character3D.play_anim if the rig has no run clip.
		var want := "idle"
		if v.length() > 0.1:
			want = "run" if sprinting else "walk"
			# Fall back to walk if the rig doesn't have a run clip so sprint
			# still reads as movement instead of snapping to idle.
			if sprinting and not _character.available_anims().has("run"):
				want = "walk"
		# Only dispatch on state change — calling play_anim every physics tick
		# (even for the same name) can re-seed the AnimationPlayer and cause a
		# visible skip at the cycle boundary.
		if _character.current_anim() != want:
			_character.play_anim(want)
		if v.length() > 0.1:
			# Rig's forward axis points opposite to the -Z convention; yaw at
			# velocity direction with no sign flip.
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
	# Fringe Haven is a hand-authored hub (not reached via planet_system.land_on),
	# so we skip planet_system.depart() — it would wipe planet_inventory that
	# belongs to a different (procedural) planet session. Just swap back.
	MusicManager.on_state_change("navigation")
	var main_node := get_tree().current_scene
	if main_node and main_node.has_method("switch_scene"):
		main_node.switch_scene("navigation")
	else:
		# Fallback for running the .tscn standalone via F6.
		get_tree().quit()


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.78, 0.95)  # sky blue
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.85)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(-35)) * Basis(Vector3.RIGHT, deg_to_rad(-50)),
		Vector3(0, 10, 0),
	)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	mi.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(CC0_GRASS_PATH)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# One texture repeat covers GROUND_TEXTURE_METRES of world. At 4m per repeat
	# across a 60m plane, the eye sees ~15 repeats — enough to avoid a "single
	# painted square" look without the repetition reading as a grid.
	var rep: float = GROUND_SIZE / GROUND_TEXTURE_METRES
	mat.uv1_scale = Vector3(rep, rep, 1.0)
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)

	# Paths — crossroads pattern roughly matching Fringe Haven layout.
	# N-S strip drawn first at y=0.01; E-W strip drawn on top at y=0.012 so the
	# intersection has one consistent winner (fixes per-frame z-fight jitter).
	_add_path_strip(
		Vector3(0.0, 0.0, -12.0), Vector3(0.0, 0.0, 12.0), 2.5, CC0_COBBLE_PATH, 0.010,
	)
	_add_path_strip(
		Vector3(-14.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0), 2.5, CC0_COBBLE_PATH, 0.012,
	)
	# NW + SE dirt branches.
	_add_path_strip(
		Vector3(-10.0, 0.0, -8.0), Vector3(-3.0, 0.0, -8.0), 1.5, CC0_MUD_PATH,
	)
	_add_path_strip(
		Vector3(3.0, 0.0, 6.0), Vector3(10.0, 0.0, 6.0), 1.5, CC0_MUD_PATH,
	)

	# Water — small lake in the NW corner, matching original layout.
	_add_water_patch(Vector3(-22.0, 0.0, -18.0), Vector2(14.0, 7.0))

	# Static collider so the player can't fall through.
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var col := CollisionShape3D.new()
	var shape := WorldBoundaryShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


# Extract a 16×16 region from the tileset PNG as a standalone ImageTexture.
# Reading pixels once at startup avoids shipping individual tile PNGs.
func _tile_texture(coord: Vector2i) -> Texture2D:
	var src: Texture2D = load(TILESET_PATH)
	if src == null:
		return null
	var img: Image = src.get_image()
	if img == null:
		return null
	var sub: Image = img.get_region(Rect2i(coord * TILE_PX, Vector2i(TILE_PX, TILE_PX)))
	return ImageTexture.create_from_image(sub)


# Lay down a rectangular path segment between two points, width metres wide,
# textured with a CC0 seamless JPG at PATH_TEXTURE_METRES per repeat. Sits
# 0.01m above ground to avoid z-fight.
func _add_path_strip(
	a: Vector3, b: Vector3, width: float, texture_path: String, y_offset: float = 0.01,
) -> void:
	var length := a.distance_to(b)
	if length <= 0.001:
		return
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(length, width)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(texture_path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.uv1_scale = Vector3(
		length / PATH_TEXTURE_METRES, width / PATH_TEXTURE_METRES, 1.0,
	)
	mat.roughness = 0.95
	mi.material_override = mat
	var mid := (a + b) * 0.5
	mi.position = mid + Vector3(0, y_offset, 0)
	var dir := (b - a).normalized()
	mi.rotation.y = atan2(dir.x, dir.z) - PI * 0.5
	add_child(mi)


# One building = a box for walls + a taller box rotated 45° for the pitched
# roof + a dark rectangle sprite stamped on the front for the door. All three
# pieces live under a Node3D so the caller can name/position the whole unit.
func _make_building(
	pos: Vector3,
	size: Vector2,       # x=width, y=depth (footprint on the ground)
	wall_height: float,
	roof_color: Color,
	label: String = ""
) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % label if label != "" else "Building"
	root.position = pos

	# Walls — a box centred vertically at wall_height/2. Plaster texture tints
	# against the warm albedo so buildings still read as "warm plaster" but gain
	# surface detail up close. BoxMesh wraps UVs per-face, so the triplanar
	# scale here is applied to the material's default UV channel.
	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, wall_height, size.y)
	walls.mesh = box
	walls.position = Vector3(0, wall_height * 0.5, 0)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.87, 0.75, 0.55)   # warm plaster tint
	wall_mat.albedo_texture = load(CC0_PLASTER_PATH)
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	wall_mat.uv1_triplanar = true
	wall_mat.uv1_scale = Vector3.ONE * (1.0 / WALL_TEXTURE_METRES)
	wall_mat.roughness = 0.95
	walls.material_override = wall_mat
	walls.add_to_group("building_walls")
	root.add_child(walls)

	# Static body so the player can't walk through.
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(size.x, wall_height, size.y)
	col.shape = col_shape
	col.position = Vector3(0, wall_height * 0.5, 0)
	body.add_child(col)
	root.add_child(body)

	# Roof — box rotated 45° around the building's long axis. Slightly wider
	# than walls for overhang, same depth. Height chosen to read as a pitch
	# from the 3/4 camera without breaking the painterly feel.
	var roof := MeshInstance3D.new()
	var roof_box := BoxMesh.new()
	var roof_height: float = 1.2
	var overhang: float = 0.25
	roof_box.size = Vector3(size.x + overhang * 2.0, roof_height, size.y + overhang * 2.0)
	roof.mesh = roof_box
	# Rotate around X so the roof "peaks" along the building's width.
	roof.rotation.x = deg_to_rad(30.0)
	# Lift so the rotated roof's lowest corner clears the wall top. For a box
	# rotated θ about X, the lowest corner's local y is
	# -(h/2)·cos(θ) - (d/2)·sin(θ). We want that + roof.y > wall_height by a
	# safe margin. 0.15m clears float-precision wobble at tangent grazes.
	var pitch: float = deg_to_rad(30.0)
	var depth_half: float = size.y * 0.5 + overhang
	var min_corner: float = roof_height * 0.5 * cos(pitch) + depth_half * sin(pitch)
	roof.position = Vector3(0, wall_height + min_corner + 0.15, 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = roof_color            # per-building tint
	roof_mat.albedo_texture = load(CC0_ROOF_PATH)
	roof_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	roof_mat.uv1_triplanar = true
	roof_mat.uv1_scale = Vector3.ONE * (1.0 / ROOF_TEXTURE_METRES)
	roof_mat.roughness = 0.85
	roof.material_override = roof_mat
	root.add_child(roof)

	# Door — small wood-plank box on the front face (+Z side).
	var door := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(0.9, 1.6, 0.05)
	door.mesh = door_box
	door.position = Vector3(0, 0.8, size.y * 0.5 + 0.03)
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.58, 0.4, 0.24)  # warmer brown than base wood
	door_mat.albedo_texture = load(CC0_WOOD_PATH)
	door_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Scale so a single door shows ~2 plank strips vertically.
	door_mat.uv1_scale = Vector3(1.0, 1.6, 1.0)
	door_mat.roughness = 0.9
	door.material_override = door_mat
	root.add_child(door)

	if label != "":
		var lbl := Label3D.new()
		lbl.text = label
		lbl.position = Vector3(0, wall_height + roof_height + 0.6, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.pixel_size = 0.012
		lbl.modulate = Color(1.0, 0.95, 0.7)
		lbl.outline_modulate = Color(0, 0, 0, 1)
		lbl.outline_size = 8
		root.add_child(lbl)

	add_child(root)
	return root


# Hollow building with a doorway in the +Z (front) wall. Same size/roof/label
# contract as `_make_building` — differs in: four separate wall segments
# (front split around a 1.2m doorway), no ceiling/floor-to-ceiling collider,
# plank floor inside, shopkeeper counter along the -Z wall, and a warm point
# light overhead so the interior reads from the 3/4 camera without needing a
# separate ambient pass.
#
# Returns the root Node3D so callers can place interior NPCs/props relative
# to the shop's local origin (the building centre).
func _make_shop_building(
	pos: Vector3,
	size: Vector2,
	wall_height: float,
	roof_color: Color,
	label: String = "",
) -> Node3D:
	var root := Node3D.new()
	root.name = "Shop_%s" % label if label != "" else "Shop"
	root.position = pos

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.87, 0.75, 0.55)
	wall_mat.albedo_texture = load(CC0_PLASTER_PATH)
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	wall_mat.uv1_triplanar = true
	wall_mat.uv1_scale = Vector3.ONE * (1.0 / WALL_TEXTURE_METRES)
	wall_mat.roughness = 0.95

	var wall_thick: float = 0.2
	var half_w: float = size.x * 0.5
	var half_d: float = size.y * 0.5
	var doorway_w: float = 1.2
	var side_w: float = (size.x - doorway_w) * 0.5  # per-side framing width

	# Helper: one wall segment (visual BoxMesh + StaticBody3D collider).
	var add_wall := func(seg_pos: Vector3, seg_size: Vector3) -> void:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = seg_size
		mi.mesh = mesh
		mi.position = seg_pos
		mi.material_override = wall_mat
		mi.add_to_group("building_walls")
		root.add_child(mi)
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = seg_size
		col.shape = cs
		col.position = seg_pos
		body.add_child(col)
		root.add_child(body)

	# Back wall (full width, -Z face).
	add_wall.call(
		Vector3(0, wall_height * 0.5, -half_d),
		Vector3(size.x, wall_height, wall_thick),
	)
	# Left and right side walls (full depth).
	add_wall.call(
		Vector3(-half_w, wall_height * 0.5, 0),
		Vector3(wall_thick, wall_height, size.y),
	)
	add_wall.call(
		Vector3(half_w, wall_height * 0.5, 0),
		Vector3(wall_thick, wall_height, size.y),
	)
	# Front wall split around a doorway. Left chunk.
	add_wall.call(
		Vector3(-(doorway_w * 0.5 + side_w * 0.5), wall_height * 0.5, half_d),
		Vector3(side_w, wall_height, wall_thick),
	)
	# Right chunk.
	add_wall.call(
		Vector3(doorway_w * 0.5 + side_w * 0.5, wall_height * 0.5, half_d),
		Vector3(side_w, wall_height, wall_thick),
	)

	# Interior floor — dark wood plank, slightly above grass to avoid z-fight.
	var floor_mi := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(size.x - wall_thick, size.y - wall_thick)
	floor_mi.mesh = floor_plane
	floor_mi.position = Vector3(0, 0.02, 0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.42, 0.28, 0.18)
	floor_mat.roughness = 0.9
	floor_mi.material_override = floor_mat
	root.add_child(floor_mi)

	# Counter along the back wall — a low box Bryn stands behind. Size leaves
	# a ~0.6m aisle on either side so the player can walk around it.
	var counter := MeshInstance3D.new()
	var counter_box := BoxMesh.new()
	counter_box.size = Vector3(size.x - 1.2, 1.0, 0.6)
	counter.mesh = counter_box
	counter.position = Vector3(0, 0.5, -half_d + 0.9)
	var counter_mat := StandardMaterial3D.new()
	counter_mat.albedo_color = Color(0.55, 0.38, 0.22)
	counter_mat.roughness = 0.85
	counter.material_override = counter_mat
	root.add_child(counter)
	# Counter collider so the player can't walk through it.
	var counter_body := StaticBody3D.new()
	var counter_col := CollisionShape3D.new()
	var counter_shape := BoxShape3D.new()
	counter_shape.size = counter_box.size
	counter_col.shape = counter_shape
	counter_col.position = counter.position
	counter_body.add_child(counter_col)
	root.add_child(counter_body)

	# Interior lamp — warm point light above the counter so the inside reads
	# well under the exterior sun + ambient. Unshaded emissive sphere sells it.
	var lamp := MeshInstance3D.new()
	var lamp_sphere := SphereMesh.new()
	lamp_sphere.radius = 0.12
	lamp_sphere.height = 0.24
	lamp.mesh = lamp_sphere
	lamp.position = Vector3(0, wall_height - 0.3, -half_d + 1.2)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.85, 0.5)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.85, 0.5)
	lamp_mat.emission_energy_multiplier = 3.0
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.material_override = lamp_mat
	root.add_child(lamp)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.55)
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position = lamp.position
	root.add_child(light)

	# Interior dressing — shelves, wares, stool, rug. Kept procedural (BoxMesh +
	# CylinderMesh primitives) so the shop reads as "stocked" under the 3/4
	# camera without pulling in new art. Everything sits on the plank floor;
	# side shelves hug the interior face of the left/right walls. Props are
	# visual-only (no colliders) — the player only bumps into walls + counter.
	var shelf_mat := StandardMaterial3D.new()
	shelf_mat.albedo_color = Color(0.38, 0.24, 0.14)
	shelf_mat.roughness = 0.9

	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.62, 0.44, 0.24)
	crate_mat.roughness = 0.95

	var jar_mat := StandardMaterial3D.new()
	jar_mat.albedo_color = Color(0.35, 0.55, 0.45)
	jar_mat.roughness = 0.3
	jar_mat.metallic = 0.1

	var bottle_mat := StandardMaterial3D.new()
	bottle_mat.albedo_color = Color(0.65, 0.25, 0.35)
	bottle_mat.roughness = 0.25
	bottle_mat.metallic = 0.15

	# Helper: a single shelf plank (visual only).
	var add_plank := func(plank_pos: Vector3, plank_size: Vector3) -> void:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = plank_size
		mi.mesh = m
		mi.position = plank_pos
		mi.material_override = shelf_mat
		root.add_child(mi)

	# Helper: a cube crate prop.
	var add_crate := func(crate_pos: Vector3, edge: float) -> void:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(edge, edge, edge)
		mi.mesh = m
		mi.position = crate_pos
		mi.material_override = crate_mat
		root.add_child(mi)

	# Helper: a bottle/jar (upright cylinder).
	var add_jar := func(jar_pos: Vector3, radius: float, height: float, mat: StandardMaterial3D) -> void:
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = radius
		m.bottom_radius = radius
		m.height = height
		mi.mesh = m
		mi.position = jar_pos + Vector3(0, height * 0.5, 0)
		mi.material_override = mat
		root.add_child(mi)

	# Left wall shelf — two planks at 0.9m and 1.5m, stocked with jars + a crate.
	var lshelf_x: float = -half_w + wall_thick + 0.2
	add_plank.call(Vector3(lshelf_x, 0.9, 0.0), Vector3(0.35, 0.05, size.y - 1.0))
	add_plank.call(Vector3(lshelf_x, 1.5, 0.0), Vector3(0.35, 0.05, size.y - 1.0))
	add_jar.call(Vector3(lshelf_x, 0.925, -0.8), 0.10, 0.28, jar_mat)
	add_jar.call(Vector3(lshelf_x, 0.925, -0.3), 0.10, 0.30, bottle_mat)
	add_jar.call(Vector3(lshelf_x, 0.925, 0.3), 0.10, 0.25, jar_mat)
	add_crate.call(Vector3(lshelf_x, 1.65, 0.8), 0.3)
	add_jar.call(Vector3(lshelf_x, 1.525, -0.5), 0.10, 0.26, bottle_mat)
	add_jar.call(Vector3(lshelf_x, 1.525, 0.1), 0.10, 0.28, jar_mat)

	# Right wall shelf — mirrored, slightly different stocking so it doesn't
	# look symmetric.
	var rshelf_x: float = half_w - wall_thick - 0.2
	add_plank.call(Vector3(rshelf_x, 0.9, 0.0), Vector3(0.35, 0.05, size.y - 1.0))
	add_plank.call(Vector3(rshelf_x, 1.5, 0.0), Vector3(0.35, 0.05, size.y - 1.0))
	add_crate.call(Vector3(rshelf_x, 1.05, -0.7), 0.3)
	add_jar.call(Vector3(rshelf_x, 0.925, 0.0), 0.10, 0.30, bottle_mat)
	add_jar.call(Vector3(rshelf_x, 0.925, 0.6), 0.10, 0.28, jar_mat)
	add_jar.call(Vector3(rshelf_x, 1.525, -0.6), 0.10, 0.26, jar_mat)
	add_jar.call(Vector3(rshelf_x, 1.525, -0.1), 0.10, 0.30, bottle_mat)
	add_jar.call(Vector3(rshelf_x, 1.525, 0.5), 0.10, 0.24, jar_mat)

	# Floor crates stacked in the back corners, below the shelves — sells "stock
	# room overflow" without cluttering the walkable aisle.
	add_crate.call(Vector3(lshelf_x + 0.05, 0.2, -half_d + 0.6), 0.4)
	add_crate.call(Vector3(rshelf_x - 0.05, 0.2, -half_d + 0.6), 0.4)
	add_crate.call(Vector3(rshelf_x - 0.05, 0.6, -half_d + 0.6), 0.35)

	# Wares on the counter — a row of three jars + one crate so the counter
	# isn't an empty slab. Counter top is at y=1.0 (counter.position.y + half
	# its height = 0.5 + 0.5). Jars sit right on top.
	var counter_top_y: float = 1.0
	var counter_z: float = -half_d + 0.9
	add_jar.call(Vector3(-1.2, counter_top_y, counter_z + 0.15), 0.09, 0.24, jar_mat)
	add_jar.call(Vector3(-0.5, counter_top_y, counter_z + 0.15), 0.09, 0.28, bottle_mat)
	add_jar.call(Vector3(0.3, counter_top_y, counter_z + 0.15), 0.09, 0.22, jar_mat)
	add_crate.call(Vector3(1.2, counter_top_y + 0.125, counter_z + 0.1), 0.25)

	# Stool behind the counter (between counter and back wall). Bryn can stand
	# next to it; visually suggests "this is her spot". Cylinder seat + thin leg.
	var stool_leg := MeshInstance3D.new()
	var stool_leg_mesh := CylinderMesh.new()
	stool_leg_mesh.top_radius = 0.04
	stool_leg_mesh.bottom_radius = 0.04
	stool_leg_mesh.height = 0.55
	stool_leg.mesh = stool_leg_mesh
	stool_leg.position = Vector3(-1.8, 0.275, -half_d + 0.4)
	stool_leg.material_override = shelf_mat
	root.add_child(stool_leg)
	var stool_seat := MeshInstance3D.new()
	var stool_seat_mesh := CylinderMesh.new()
	stool_seat_mesh.top_radius = 0.20
	stool_seat_mesh.bottom_radius = 0.20
	stool_seat_mesh.height = 0.06
	stool_seat.mesh = stool_seat_mesh
	stool_seat.position = Vector3(-1.8, 0.58, -half_d + 0.4)
	stool_seat.material_override = crate_mat
	root.add_child(stool_seat)

	# Welcome rug at the doorway threshold — ties the entry into the interior
	# colour palette and gives the player a visual "you're inside now" cue as
	# they step through the 1.2m gap.
	var rug := MeshInstance3D.new()
	var rug_plane := PlaneMesh.new()
	rug_plane.size = Vector2(1.6, 1.2)
	rug.mesh = rug_plane
	rug.position = Vector3(0, 0.025, half_d - 0.9)
	var rug_mat := StandardMaterial3D.new()
	rug_mat.albedo_color = Color(0.55, 0.18, 0.22)
	rug_mat.roughness = 0.95
	rug.material_override = rug_mat
	root.add_child(rug)

	# Second ceiling lamp above the doorway so the entry area isn't dimmer than
	# the counter. Matches the counter lamp styling but lower energy (accent).
	var lamp2 := MeshInstance3D.new()
	var lamp2_sphere := SphereMesh.new()
	lamp2_sphere.radius = 0.10
	lamp2_sphere.height = 0.20
	lamp2.mesh = lamp2_sphere
	lamp2.position = Vector3(0, wall_height - 0.3, half_d - 1.0)
	lamp2.material_override = lamp_mat
	root.add_child(lamp2)
	var light2 := OmniLight3D.new()
	light2.light_color = Color(1.0, 0.85, 0.55)
	light2.light_energy = 1.2
	light2.omni_range = 4.5
	light2.position = lamp2.position
	root.add_child(light2)

	# Shop has no pitched roof — an open-top storefront makes the interior
	# (counter, lamp, vendor) readable from the 3/4 camera. A thin awning
	# strip along the +Z edge suggests "shop frontage" without occluding.
	var awning := MeshInstance3D.new()
	var awning_box := BoxMesh.new()
	awning_box.size = Vector3(size.x + 0.5, 0.25, 0.8)
	awning.mesh = awning_box
	awning.position = Vector3(0, wall_height + 0.12, half_d + 0.4)
	var awning_mat := StandardMaterial3D.new()
	awning_mat.albedo_color = roof_color
	awning_mat.albedo_texture = load(CC0_ROOF_PATH)
	awning_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	awning_mat.uv1_triplanar = true
	awning_mat.uv1_scale = Vector3.ONE * (1.0 / ROOF_TEXTURE_METRES)
	awning_mat.roughness = 0.85
	awning.material_override = awning_mat
	root.add_child(awning)

	if label != "":
		var lbl := Label3D.new()
		lbl.text = label
		lbl.position = Vector3(0, wall_height + 0.9, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.pixel_size = 0.012
		lbl.modulate = Color(1.0, 0.95, 0.7)
		lbl.outline_modulate = Color(0, 0, 0, 1)
		lbl.outline_size = 8
		root.add_child(lbl)

	add_child(root)
	return root


# Place each named building from the original Fringe Haven layout. Positions
# are hand-picked to sit in the four quadrants around the stone crossroads
# (E-W road at z=0, N-S road at x=0), leaving the 2.5m-wide roads clear.
func _build_buildings() -> void:
	# NW quadrant — Tipsy Tankard (tavern, large red roof).
	_make_building(
		Vector3(-7.0, 0.0, -5.0),
		Vector2(4.5, 3.5),
		2.2,
		Color(0.72, 0.22, 0.22),
		"TIPSY TANKARD",
	)
	# NE quadrant — Bryn's Oddities. Shop-variant builds hollow walls with a
	# front doorway so the player can walk inside to trade. Counter + warm
	# interior light come along for free. Position/size match the original
	# solid building so the layout around it is unchanged.
	_make_shop_building(
		Vector3(6.0, 0.0, -5.0),
		Vector2(5.5, 4.0),
		2.2,
		Color(0.72, 0.22, 0.22),
		"BRYN'S ODDITIES",
	)
	# Far NE — Blacksmith (green roof).
	_make_building(
		Vector3(11.5, 0.0, -5.0),
		Vector2(3.5, 3.0),
		2.0,
		Color(0.32, 0.55, 0.32),
		"BLACKSMITH",
	)
	# SW quadrant — two houses side by side.
	_make_building(
		Vector3(-6.0, 0.0, 6.0),
		Vector2(3.0, 3.0),
		1.8,
		Color(0.72, 0.22, 0.22),
	)
	_make_building(
		Vector3(-2.0, 0.0, 6.0),
		Vector2(3.0, 3.0),
		1.8,
		Color(0.72, 0.22, 0.22),
	)
	# SE quadrant — doghouses (smaller). Spacing must exceed size.x + 2*overhang
	# (1.8 + 0.5 = 2.3m) or adjacent roofs intersect and z-fight along the seam.
	for i in range(4):
		var x := 3.5 + float(i) * 2.6
		_make_building(
			Vector3(x, 0.0, 6.5),
			Vector2(1.8, 1.8),
			1.1,
			Color(0.32, 0.55, 0.32) if i % 2 == 0 else Color(0.22, 0.42, 0.7),
		)


func _add_water_patch(center: Vector3, size: Vector2) -> void:
	# Tileset has no pure-water tile — flat blue works until we import a
	# dedicated water texture or animate the waves PNG.
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.42, 0.78)
	mat.roughness = 0.3
	mat.metallic = 0.2
	mi.material_override = mat
	mi.position = center + Vector3(0, 0.015, 0)
	add_child(mi)


func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "Player"
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	col.shape = capsule
	col.position.y = 0.8
	_player.add_child(col)

	# Spawn the rig using the existing Character3D pipeline.
	var gs: GameStateData = GameSession.game_state if GameSession else null
	var pid: String = gs.protagonist_id if gs and gs.protagonist_id != "" else "aristotle"
	_character = CHARACTER_3D_SCENE.instantiate()
	_character.character_id = pid
	_character.autoplay = "idle"
	_player.add_child(_character)
	_character.initialize()

	# If we're returning from a shop interior, spawn at the stashed doorway
	# position. Otherwise default to world origin (crossroads).
	var spawn := Vector3.ZERO
	if GameSession and GameSession.pending_fringe_haven_spawn != Vector3.ZERO:
		spawn = GameSession.pending_fringe_haven_spawn
		GameSession.pending_fringe_haven_spawn = Vector3.ZERO
	_player.global_position = spawn
	add_child(_player)


func _build_camera() -> void:
	# Rig follows the player; camera is a child at a fixed offset, always
	# aiming at the rig's local origin. Using Transform3D.looking_at avoids the
	# "must be in the tree" requirement of Node3D.look_at().
	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	add_child(_camera_rig)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_ORTHO_SIZE
	_camera.current = true
	var yaw := deg_to_rad(CAMERA_YAW_DEG)
	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch),
	) * CAMERA_DISTANCE
	# Build a transform whose origin is at `offset` and whose forward axis
	# points at the rig's local origin (0,0,0). Transform3D.looking_at uses
	# the transform's own origin as the eye — so we pass origin + target.
	_camera.transform = Transform3D(Basis(), offset).looking_at(Vector3.ZERO, Vector3.UP)
	_camera_rig.add_child(_camera)


# Extract an arbitrary region from an image-backed texture as a standalone
# ImageTexture. Returns null if the source fails to load.
func _sub_texture(path: String, region: Rect2i) -> Texture2D:
	var src: Texture2D = load(path)
	if src == null:
		return null
	var img: Image = src.get_image()
	if img == null:
		return null
	var rect: Rect2i = region.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return null
	return ImageTexture.create_from_image(img.get_region(rect))


# Spawn a billboarded sprite at `pos`, world-height `world_height` metres tall,
# aspect preserved from the texture's pixel size. Base of the sprite sits on
# the ground (y=pos.y); the sprite's centre is lifted by world_height/2.
func _make_billboard(
	tex: Texture2D, pos: Vector3, world_height: float, parent: Node = self,
) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	# pixel_size = world_height / texture_pixel_height keeps aspect ratio intact.
	var tex_h: int = tex.get_height() if tex else 1
	s.pixel_size = world_height / float(max(tex_h, 1))
	s.position = pos + Vector3(0, world_height * 0.5, 0)
	parent.add_child(s)
	return s


# Trees, campfires, rocks/flowers — static set-dressing. Kept compact: tree
# positions are authored inline; they're the only prop that needs deliberate
# placement to keep roads/buildings readable.
func _build_props() -> void:
	# Trees — five variants at (9,12) (11,12) (13,12) (15,12) are 2×3 tiles
	# (64×96 px) and (17,13) is 2×2 (64×64). All on the serene_village sheet.
	var tree_variants: Array = [
		{"coord": Vector2i(9, 12), "size": Vector2i(2, 3)},
		{"coord": Vector2i(11, 12), "size": Vector2i(2, 3)},
		{"coord": Vector2i(13, 12), "size": Vector2i(2, 3)},
		{"coord": Vector2i(15, 12), "size": Vector2i(2, 3)},
		{"coord": Vector2i(17, 13), "size": Vector2i(2, 2)},
	]
	var tree_textures: Array[Texture2D] = []
	for v in tree_variants:
		var coord: Vector2i = v["coord"]
		var size_tiles: Vector2i = v["size"]
		var region := Rect2i(
			coord * SERENE_PX,
			size_tiles * SERENE_PX,
		)
		var t := _sub_texture(SERENE_PATH, region)
		tree_textures.append(t)

	# Place trees around the town perimeter — never on paths or inside the
	# ±12m inner square (keeps centre clear for movement/NPCs). Hand-picked
	# so the silhouettes read around the skyline.
	var tree_positions: Array = [
		Vector3(-18.0, 0.0, -14.0),
		Vector3(-14.0, 0.0, -16.0),
		Vector3(-10.0, 0.0, -15.0),
		Vector3(14.0, 0.0, -14.0),
		Vector3(18.0, 0.0, -10.0),
		Vector3(20.0, 0.0, -2.0),
		Vector3(19.0, 0.0, 8.0),
		Vector3(15.0, 0.0, 14.0),
		Vector3(8.0, 0.0, 16.0),
		Vector3(-5.0, 0.0, 15.0),
		Vector3(-12.0, 0.0, 14.0),
		Vector3(-18.0, 0.0, 10.0),
		Vector3(-20.0, 0.0, 2.0),
		Vector3(-19.0, 0.0, -4.0),
	]
	for i in range(tree_positions.size()):
		var tex: Texture2D = tree_textures[i % tree_textures.size()]
		if tex == null:
			continue
		# Trees read ~2.5m tall at this camera scale.
		_make_billboard(tex, tree_positions[i], 2.5)

	# Campfires — procedural 3D (crossed logs + emissive flame cone + light).
	# Pixel-sprite campfire clashed against the painterly-3D player and
	# buildings; this reads consistently with the rest of the world.
	var campfire_positions: Array = [
		Vector3(-10.0, 0.0, 2.5),   # near tavern
		Vector3(9.5, 0.0, 9.0),     # doghouse meeting spot
	]
	for p in campfire_positions:
		_make_campfire_3d(p)


# A small campfire. Rebuilt 2026-04-21 to read painterly at the 3/4 ortho
# camera instead of "three primitives": charred ground disc + 7 scattered
# stone chunks (rotated individually so no two read the same) + 3 wood-grain
# logs crossed at 80° + layered inner/outer emissive flame cones + warm
# OmniLight3D. The outer flame + light animate in _process for flicker; the
# inner flame inherits the parent flame's scale pulse.
func _make_campfire_3d(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	# Charred disc — mud texture darkened to burn-mark grey-brown. Sits at
	# y=0.016 so it draws over the grass but below the path y-offsets (0.010
	# N-S, 0.012 E-W). Using a real texture (instead of the flat ellipse it
	# was) gives it surface variation so it stops reading as a painted shape
	# under the rocks.
	var char_disc := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.75
	disc.height = 0.01
	char_disc.mesh = disc
	char_disc.position.y = 0.016
	var char_mat := StandardMaterial3D.new()
	char_mat.albedo_color = Color(0.22, 0.17, 0.13)
	char_mat.albedo_texture = load(CC0_MUD_PATH)
	char_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	char_mat.uv1_scale = Vector3(1.5, 1.5, 1.0)
	char_mat.roughness = 1.0
	char_disc.material_override = char_mat
	root.add_child(char_disc)

	# Scattered stone chunks — low-poly faceted spheres (5 radial × 3 rings)
	# give the angular "hand-carved rock" silhouette that boxes couldn't. Each
	# stone gets a non-uniform scale + random tilt so no two read the same.
	# Seeded on position for stable rendering across reloads.
	var stone_rng := RandomNumberGenerator.new()
	stone_rng.seed = hash(pos)
	var stone_count: int = 7
	var ring_radius: float = 0.48
	var plaster_tex: Texture2D = load(CC0_PLASTER_PATH)
	for i in range(stone_count):
		var angle: float = TAU * float(i) / float(stone_count)
		var jitter: float = stone_rng.randf_range(-0.06, 0.06)
		var r: float = ring_radius + jitter
		# Non-uniform scale: wider than tall, slightly squashed on one axis,
		# so each sphere reads as a weathered lump rather than a perfect ball.
		var sx: float = 0.22 + stone_rng.randf_range(-0.04, 0.05)
		var sy: float = 0.13 + stone_rng.randf_range(-0.03, 0.03)
		var sz: float = 0.22 + stone_rng.randf_range(-0.04, 0.05)
		var stone := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		# 8×4 reads as faceted stone without the pentagon/d20 silhouette that
		# 5×3 produces. The random non-uniform scale does more shape work than
		# low segment count at this camera distance.
		sm.radial_segments = 8
		sm.rings = 4
		stone.mesh = sm
		stone.scale = Vector3(sx, sy, sz)
		# Sit stones partly buried so they read as settled into the char disc
		# rather than perched on top. Burying half a stone's height pushes the
		# visible lump to ~sy*0.6 which matches "weathered rock in soot".
		stone.position = Vector3(cos(angle) * r, sy * 0.25, sin(angle) * r)
		stone.rotation.y = stone_rng.randf_range(0.0, TAU)
		stone.rotation.x = stone_rng.randf_range(-0.2, 0.2)
		stone.rotation.z = stone_rng.randf_range(-0.2, 0.2)
		var s_mat := StandardMaterial3D.new()
		var tint: float = stone_rng.randf_range(0.32, 0.48)
		s_mat.albedo_color = Color(tint, tint * 0.95, tint * 0.9)
		s_mat.albedo_texture = plaster_tex
		s_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s_mat.uv1_triplanar = true
		s_mat.uv1_scale = Vector3.ONE * 3.0   # tight tiling reads as rock grain
		s_mat.roughness = 1.0
		stone.material_override = s_mat
		root.add_child(stone)

	# Logs — wood-grain texture with charred darker tint so they look burnt
	# rather than freshly cut. Darker than the chest lid/door on purpose. Logs
	# sit at ~80° tilt (near-flat, small rise toward the centre) and barely
	# above the char disc so they read as "thrown in" instead of hovering.
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.28, 0.18, 0.10)   # charred brown
	log_mat.albedo_texture = load(CC0_WOOD_PATH)
	log_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	log_mat.uv1_scale = Vector3(4.0, 1.0, 1.0)
	log_mat.roughness = 0.95
	for i in range(3):
		var log_m := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.07
		cyl.height = 0.75
		log_m.mesh = cyl
		log_m.material_override = log_mat
		# Tilt 85° (closer to horizontal) + per-log yaw. Position y=0.06 so the
		# log rests on the char disc instead of floating 15cm up.
		log_m.rotation = Vector3(
			stone_rng.randf_range(-0.08, 0.08),
			float(i) * PI / 3.0 + stone_rng.randf_range(-0.1, 0.1),
			deg_to_rad(85.0),
		)
		log_m.position = Vector3(
			stone_rng.randf_range(-0.05, 0.05),
			0.06,
			stone_rng.randf_range(-0.05, 0.05),
		)
		root.add_child(log_m)

	# Flame — GPUParticles3D spawning rising billboarded emissive quads.
	# Replaces the solid cones that read as "traffic cone stickers". Each
	# particle is a small emissive square that rises ~0.6m, shrinks from
	# 0.25m→0m, and colour-shifts orange→yellow-white→out over its ~1.1s
	# lifetime. At 60 particles/s this gives the "licking flame" silhouette
	# with no custom shader. Core glow = small unshaded orange cone so the
	# base of the fire still reads warm when particles thin out.
	var flame_core := MeshInstance3D.new()
	var core_cone := CylinderMesh.new()
	core_cone.top_radius = 0.0
	core_cone.bottom_radius = 0.22
	core_cone.height = 0.35
	flame_core.mesh = core_cone
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.5, 0.12)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.55, 0.15)
	core_mat.emission_energy_multiplier = 3.0
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_core.material_override = core_mat
	flame_core.position.y = 0.35
	root.add_child(flame_core)
	# _campfire_flames drives the existing scale-pulse on the core so the
	# base of the flame still breathes in sync with the OmniLight flicker.
	_campfire_flames.append(flame_core)

	# Two-stream particle flame: dense small "tongues" + sparse high "embers".
	# Splitting avoids the "same particles everywhere" look where big sprites
	# at the base and tiny sparks at the top would otherwise share one config.

	# Stream 1 — tongues. Short-lived, tiny, tight cluster around the core.
	var tongues := GPUParticles3D.new()
	tongues.amount = 80
	tongues.lifetime = 0.6
	tongues.preprocess = 0.5
	tongues.position.y = 0.15
	tongues.visibility_aabb = AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 1.4, 1.2))

	var tongue_proc := ParticleProcessMaterial.new()
	tongue_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	tongue_proc.emission_sphere_radius = 0.08
	tongue_proc.direction = Vector3(0, 1, 0)
	tongue_proc.spread = 12.0
	tongue_proc.initial_velocity_min = 0.7
	tongue_proc.initial_velocity_max = 1.1
	tongue_proc.gravity = Vector3(0, 0.2, 0)
	tongue_proc.scale_min = 0.10
	tongue_proc.scale_max = 0.18
	var tongue_curve := Curve.new()
	tongue_curve.add_point(Vector2(0.0, 0.4))   # start small (just lit)
	tongue_curve.add_point(Vector2(0.25, 1.0))  # swell
	tongue_curve.add_point(Vector2(1.0, 0.0))   # taper to nothing
	var tongue_curve_tex := CurveTexture.new()
	tongue_curve_tex.curve = tongue_curve
	tongue_proc.scale_curve = tongue_curve_tex
	var tongue_grad := Gradient.new()
	tongue_grad.set_offset(0, 0.0)
	tongue_grad.set_color(0, Color(1.0, 0.55, 0.12, 0.95))
	tongue_grad.set_offset(1, 1.0)
	tongue_grad.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	tongue_grad.add_point(0.4, Color(1.0, 0.75, 0.25, 0.9))
	tongue_grad.add_point(0.75, Color(1.0, 0.55, 0.15, 0.5))
	var tongue_grad_tex := GradientTexture1D.new()
	tongue_grad_tex.gradient = tongue_grad
	tongue_proc.color_ramp = tongue_grad_tex
	tongues.process_material = tongue_proc

	var tongue_quad := QuadMesh.new()
	tongue_quad.size = Vector2(0.18, 0.24)
	var tongue_mat := StandardMaterial3D.new()
	tongue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tongue_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tongue_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	tongue_mat.billboard_keep_scale = true
	tongue_mat.vertex_color_use_as_albedo = true
	tongue_mat.emission_enabled = true
	tongue_mat.emission = Color(1.0, 0.65, 0.25)
	tongue_mat.emission_energy_multiplier = 2.5
	tongue_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tongue_quad.material = tongue_mat
	tongues.draw_pass_1 = tongue_quad
	root.add_child(tongues)

	# Stream 2 — embers. Sparse, high, rise further before fading.
	var embers := GPUParticles3D.new()
	embers.amount = 18
	embers.lifetime = 1.4
	embers.preprocess = 0.8
	embers.position.y = 0.35
	embers.visibility_aabb = AABB(Vector3(-0.8, 0.0, -0.8), Vector3(1.6, 2.6, 1.6))

	var ember_proc := ParticleProcessMaterial.new()
	ember_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	ember_proc.emission_sphere_radius = 0.12
	ember_proc.direction = Vector3(0, 1, 0)
	ember_proc.spread = 22.0
	ember_proc.initial_velocity_min = 0.8
	ember_proc.initial_velocity_max = 1.4
	ember_proc.gravity = Vector3(0, -0.3, 0)  # real gravity so embers arc + fall
	ember_proc.scale_min = 0.04
	ember_proc.scale_max = 0.08
	var ember_curve := Curve.new()
	ember_curve.add_point(Vector2(0.0, 1.0))
	ember_curve.add_point(Vector2(0.7, 0.9))
	ember_curve.add_point(Vector2(1.0, 0.0))
	var ember_curve_tex := CurveTexture.new()
	ember_curve_tex.curve = ember_curve
	ember_proc.scale_curve = ember_curve_tex
	var ember_grad := Gradient.new()
	ember_grad.set_offset(0, 0.0)
	ember_grad.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	ember_grad.set_offset(1, 1.0)
	ember_grad.set_color(1, Color(0.7, 0.2, 0.05, 0.0))
	ember_grad.add_point(0.6, Color(1.0, 0.55, 0.15, 0.8))
	var ember_grad_tex := GradientTexture1D.new()
	ember_grad_tex.gradient = ember_grad
	ember_proc.color_ramp = ember_grad_tex
	embers.process_material = ember_proc

	var ember_quad := QuadMesh.new()
	ember_quad.size = Vector2(0.08, 0.08)
	var ember_mat := StandardMaterial3D.new()
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	ember_mat.billboard_keep_scale = true
	ember_mat.vertex_color_use_as_albedo = true
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.7, 0.3)
	ember_mat.emission_energy_multiplier = 3.5
	ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ember_quad.material = ember_mat
	embers.draw_pass_1 = ember_quad
	root.add_child(embers)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.6
	light.omni_range = 4.0
	light.position.y = 0.7
	root.add_child(light)
	_campfire_lights.append(light)


# Corsair guards using the real Character3D pipeline — Fringe Haven is
# controlled by the felid_corsairs faction, so guards are cats in corsair
# kit. Rigs live at res://assets/characters/npc/felid_corsair_guard/.
# Merchant (Bryn) keeps her sprite placeholder for now — step 5 will route
# interactions through an Area3D per NPC.
func _build_npcs() -> void:
	_spawn_3d_npc("felid_corsair_guard", Vector3(2.0, 0.0, 1.0), "GUARD", PI, InteractKind.NONE)
	_spawn_3d_npc("felid_corsair_guard", Vector3(-2.0, 0.0, -1.0), "GUARD", 0.0, InteractKind.NONE)
	# Bryn stands behind the counter inside her shop (centre = (6, 0, -5),
	# counter depth 0.6m against the back wall). Yaw = 0 so she faces the
	# +Z doorway. Interact radius is the default 2m — covers the counter
	# apron so the prompt fires the moment the player steps up to trade.
	# No Mixamo anims yet — idle falls back to T-pose until
	# animations/trader_bryn_anim_<name>.fbx files are added.
	var bryn_pos := Vector3(6.0, 0.0, -5.4)
	_spawn_3d_npc(
		"trader_bryn",
		bryn_pos,
		"BRYN — trade",
		0.0,
		InteractKind.MERCHANT,
	)
	# Warm emissive disc at her feet so she's locatable even if the rig
	# imports without an albedo texture. Doubles as a visual "vendor spot"
	# cue, which helps readability from the 3/4 camera.
	var spot := MeshInstance3D.new()
	var spot_mesh := CylinderMesh.new()
	spot_mesh.top_radius = 0.55
	spot_mesh.bottom_radius = 0.55
	spot_mesh.height = 0.04
	spot.mesh = spot_mesh
	spot.position = bryn_pos + Vector3(0, 0.03, 0)
	var spot_mat := StandardMaterial3D.new()
	spot_mat.albedo_color = Color(1.0, 0.75, 0.35)
	spot_mat.emission_enabled = true
	spot_mat.emission = Color(1.0, 0.75, 0.35)
	spot_mat.emission_energy_multiplier = 1.8
	spot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spot.material_override = spot_mat
	add_child(spot)


func _spawn_3d_npc(
	char_id: String,
	pos: Vector3,
	label: String,
	yaw: float,
	interact: int = InteractKind.NONE,
) -> void:
	# StaticBody3D wraps the rig so the player bumps into the NPC instead of
	# walking through. Capsule roughly matches the player's collider.
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	col.shape = capsule
	col.position.y = 0.8
	body.add_child(col)
	add_child(body)

	var npc: Character3D = CHARACTER_3D_SCENE.instantiate()
	npc.character_id = char_id
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
	add_child(tag)

	if interact != InteractKind.NONE:
		var _id := _attach_interact_zone(pos, interact, null)


# Register an interaction point at `pos`. `_poll_interact_zones` compares
# the player's XZ distance each physics tick and marks the entry active when
# inside `radius`. Area3D+body_entered was unreliable here (Godot 4 layer/mask
# quirks with CharacterBody3D in a procedural scene) — distance-poll is
# deterministic and survives scene rebuilds.
func _attach_interact_zone(pos: Vector3, kind: int, data: Variant) -> int:
	var id := _next_interact_id
	_next_interact_id += 1
	_interact_points[id] = {
		"pos": pos,
		"kind": kind,
		"data": data,
		"radius": INTERACT_RADIUS,
	}
	return id


# Called every physics tick. Compares player XZ distance to each registered
# interact point and rebuilds `_active_zones`. Y is ignored so vertical lift
# on chests/NPCs doesn't break proximity.
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


# ── Treasure chest ────────────────────────────────────────────────────

# Build a small wooden chest (base + lid) with an emissive sparkle puff while
# unopened. Placed on the hill behind the southern doghouses — off the roads
# and far enough from Bryn that the two interact prompts never fight.
func _build_chest() -> void:
	var gs: GameStateData = GameSession.game_state if GameSession else null
	_chest_collected = gs != null and gs.story_flags.get(CHEST_STORY_FLAG, false)

	var pos := Vector3(-14.0, 0.0, 7.0)

	var root := Node3D.new()
	root.name = "Chest"
	root.position = pos
	add_child(root)

	# Wood-grain base — reuses the exterior wood-planks texture (step 16). Tint
	# stays the warm brown we had before so the chest still reads as darker
	# wood than the doors. Triplanar so the grain wraps consistently across
	# the cuboid's 6 faces without per-face UV tuning.
	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(0.9, 0.55, 0.6)
	base.mesh = base_box
	base.position.y = 0.275
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.55, 0.35, 0.2)
	base_mat.albedo_texture = load(CC0_WOOD_PATH)
	base_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	base_mat.uv1_triplanar = true
	base_mat.uv1_scale = Vector3.ONE * 1.6
	base_mat.roughness = 0.9
	base.material_override = base_mat
	root.add_child(base)

	# Physical collider so the player can't walk through. Sized to the base +
	# lid bounding box (0.95 × 0.75 × 0.65) so the lid can't be clipped either.
	var chest_body := StaticBody3D.new()
	var chest_col := CollisionShape3D.new()
	var chest_shape := BoxShape3D.new()
	chest_shape.size = Vector3(0.95, 0.75, 0.65)
	chest_col.shape = chest_shape
	chest_col.position.y = 0.375
	chest_body.add_child(chest_col)
	root.add_child(chest_body)

	_chest_lid = MeshInstance3D.new()
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(0.95, 0.2, 0.65)
	_chest_lid.mesh = lid_box
	_chest_lid.position.y = 0.65
	# Lid shares the wood texture but with a slightly lighter tint so it reads
	# as a distinct piece from the base, not one continuous cuboid.
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.68, 0.46, 0.26)
	lid_mat.albedo_texture = load(CC0_WOOD_PATH)
	lid_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lid_mat.uv1_triplanar = true
	lid_mat.uv1_scale = Vector3.ONE * 1.6
	lid_mat.roughness = 0.85
	_chest_lid.material_override = lid_mat
	root.add_child(_chest_lid)

	# Metal corner rivets — 4 tiny brass cubes at the top corners of the base.
	# Give the chest silhouette some shape from the 3/4 camera; reuses the
	# gold tint from the band so the metalwork palette stays unified.
	var rivet_mat := StandardMaterial3D.new()
	rivet_mat.albedo_color = Color(0.75, 0.58, 0.22)
	rivet_mat.metallic = 0.7
	rivet_mat.roughness = 0.35
	var rivet_offsets: Array = [
		Vector3(-0.41, 0.5, 0.26),
		Vector3(0.41, 0.5, 0.26),
		Vector3(-0.41, 0.5, -0.26),
		Vector3(0.41, 0.5, -0.26),
	]
	for off in rivet_offsets:
		var rivet := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.09, 0.09, 0.09)
		rivet.mesh = rb
		rivet.position = off
		rivet.material_override = rivet_mat
		root.add_child(rivet)

	# Golden band across the front (purely decorative).
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

	# Sparkle — emissive sphere above the lid, visible only when uncollected.
	_chest_sparkle = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.24
	_chest_sparkle.mesh = sp
	_chest_sparkle.position = Vector3(0, 1.1, 0)
	var sp_mat := StandardMaterial3D.new()
	sp_mat.albedo_color = Color(1.0, 0.92, 0.45)
	sp_mat.emission_enabled = true
	sp_mat.emission = Color(1.0, 0.85, 0.35)
	sp_mat.emission_energy_multiplier = 3.0
	sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_chest_sparkle.material_override = sp_mat
	root.add_child(_chest_sparkle)

	# Warm pool of light around uncollected chests so they read as "important"
	# from across the square, not just when the player is close enough for the
	# sparkle to be visible. Hidden in _apply_chest_opened_visuals on collect.
	_chest_light = OmniLight3D.new()
	_chest_light.light_color = Color(1.0, 0.85, 0.45)
	_chest_light.light_energy = 1.2
	_chest_light.omni_range = 3.5
	_chest_light.position = Vector3(0, 1.0, 0)
	root.add_child(_chest_light)

	var tag := Label3D.new()
	tag.text = "HIDDEN CHEST" if not _chest_collected else "(empty)"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.008
	tag.no_depth_test = true
	tag.modulate = Color(1.0, 0.92, 0.5)
	tag.outline_modulate = Color(0, 0, 0, 1)
	tag.outline_size = 6
	tag.position = Vector3(0, 1.6, 0)
	root.add_child(tag)

	if _chest_collected:
		_apply_chest_opened_visuals()
	else:
		_attach_interact_zone(pos, InteractKind.CHEST, null)


func _apply_chest_opened_visuals() -> void:
	# Snap immediately — used on scene load when the chest was already opened
	# in a prior session (no satisfying animation possible after the fact).
	if _chest_lid:
		_chest_lid.rotation.x = deg_to_rad(-55.0)
		# Slide the lid so its hinge stays at the back of the base.
		_chest_lid.position = Vector3(0, 0.65, -0.1)
	if _chest_sparkle:
		_chest_sparkle.visible = false
	if _chest_light:
		_chest_light.visible = false


# Tweened version — used when the player collects the chest in-scene so the
# lid arcs open instead of snapping. Light fades in parallel. Sparkle hides
# immediately so the reward flash is the visual payoff.
func _animate_chest_opening() -> void:
	if _chest_sparkle:
		_chest_sparkle.visible = false
	if _chest_lid:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_chest_lid, "rotation:x", deg_to_rad(-55.0), 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_chest_lid, "position", Vector3(0, 0.65, -0.1), 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _chest_light:
		var lw := create_tween()
		lw.tween_property(_chest_light, "light_energy", 0.0, 0.6)
		lw.tween_callback(func() -> void:
			if _chest_light:
				_chest_light.visible = false
		)


func _update_chest_sparkle() -> void:
	if _chest_sparkle == null or not _chest_sparkle.visible:
		return
	var s: float = 0.85 + 0.2 * sin(_anim_accum * 3.2)
	_chest_sparkle.scale = Vector3(s, s, s)
	_chest_sparkle.position.y = 1.1 + 0.05 * sin(_anim_accum * 2.1)
	# Breathe the chest light in sync with the sparkle so the glow pulse
	# matches the bauble — reads as one radiance, not two.
	if _chest_light and _chest_light.visible:
		_chest_light.light_energy = 1.0 + 0.25 * sin(_anim_accum * 2.4)


# ── Interaction ───────────────────────────────────────────────────────

# When E is pressed, pick the first active zone and dispatch. Proximity
# filtering is already handled by the Area3D enter/exit events.
func _try_interact() -> void:
	if _active_zones.is_empty():
		_flash("Nothing to interact with here.", 1.2)
		return
	for aid in _active_zones:
		var entry: Dictionary = _active_zones[aid]
		var kind: int = entry.get("kind", InteractKind.NONE)
		if kind == InteractKind.MERCHANT:
			_open_merchant()
			return
		if kind == InteractKind.CHEST:
			_collect_chest(aid)
			return


func _open_merchant() -> void:
	# Enter Bryn's shop interior (face-on dialogue + trade flow). fringe_haven_3d
	# is loaded via change_scene_to_file from navigation, so main.gd's SceneContainer
	# is gone — we use change_scene_to_file again here (same pattern) to swap the
	# whole tree root rather than main.switch_scene.
	get_tree().call_deferred(
		"change_scene_to_file",
		"res://scenes/world/bryn_shop_interior.tscn",
	)


func _collect_chest(zone_id: int) -> void:
	if _chest_collected:
		return
	_chest_collected = true
	var gs: GameStateData = GameSession.game_state if GameSession else null
	if gs:
		gs.crystal_inventory += CHEST_REWARD_CRYSTALS
		gs.salvage += CHEST_REWARD_SALVAGE
		gs.story_flags[CHEST_STORY_FLAG] = true
	_animate_chest_opening()
	# Remove the trigger so the prompt clears immediately.
	# Drop the registration so the prompt stops showing even if the player
	# is still standing on top of the chest.
	_interact_points.erase(zone_id)
	_active_zones.erase(zone_id)
	_flash(
		"Found chest: +%d crystals, +%d salvage" % [CHEST_REWARD_CRYSTALS, CHEST_REWARD_SALVAGE],
		3.0,
	)


# ── HUD ───────────────────────────────────────────────────────────────

func _build_hud() -> void:
	# CanvasLayer sits above the 3D viewport so text renders crisp at 1:1
	# screen pixels regardless of the ortho camera's size.
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	_hud_hint_depart = _make_hud_label(
		"DEPART — ESC     RUN — SHIFT",
		Vector2(20, 20),
		Color(1.0, 0.95, 0.7),
		14,
	)
	layer.add_child(_hud_hint_depart)

	_hud_hint_interact = _make_hud_label(
		"[E] Interact",
		Vector2(20, 48),
		Color(1.0, 0.9, 0.55),
		14,
	)
	_hud_hint_interact.visible = false
	layer.add_child(_hud_hint_interact)

	_hud_flash = _make_hud_label(
		"",
		Vector2(0, 84),
		Color(1.0, 0.95, 0.7),
		16,
	)
	# Centre the flash across the screen width.
	_hud_flash.anchor_left = 0.0
	_hud_flash.anchor_right = 1.0
	_hud_flash.offset_left = 0
	_hud_flash.offset_right = 0
	_hud_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_flash.visible = false
	layer.add_child(_hud_flash)


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
