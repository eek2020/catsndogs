## Fringe Haven — full 3D reimplementation (Option A prototype).
##
## Step 1: minimal scene — ground plane, sun, player (Character3D on a
## CharacterBody3D), ortho camera following the player. Once this renders
## cleanly we layer in paths, buildings, props, NPCs, and interactions.
##
## Built procedurally from code rather than a hand-crafted .tscn so iteration
## is fast and the composition stays legible in a single file.
extends Node3D

const MOVE_SPEED: float = 4.0
const CAMERA_ORTHO_SIZE: float = 6.0
const CAMERA_PITCH_DEG: float = 55.0   # degrees below horizontal
const CAMERA_YAW_DEG: float = 30.0     # clockwise from north
const CAMERA_DISTANCE: float = 18.0
const GROUND_SIZE: float = 60.0        # metres; big enough to not see the edge
const TILESET_PATH: String = "res://assets/tiles/fringe_haven/overworld_tileset_16x16.png"
const WATER_PATH: String = "res://assets/tiles/fringe_haven/water_waves_32x32.png"
const SERENE_PATH: String = "res://assets/tiles/fringe_haven/serene_village_32x32.png"
const TILE_PX: int = 16
const SERENE_PX: int = 32
# Tileset atlas coords (col, row) — centres of the solid 3×3 floor panels
# on the 18×13 sheet. Picked visually from the PNG to avoid edge/transition
# tiles (which read as diagonal stripes when tiled).
const GRASS_TILE: Vector2i = Vector2i(10, 4)
const DIRT_TILE: Vector2i = Vector2i(0, 3)
const STONE_TILE: Vector2i = Vector2i(7, 7)
# World size of a single tile, in metres. 1 tile ≈ half a character.
const TILE_METRES: float = 0.5
const CHARACTER_3D_SCENE: PackedScene = preload(
	"res://scenes/characters/character_3d.tscn"
)

# Step 5 interaction tunables.
const MERCHANT_FACTION_ID: String = "felid_corsairs"
const CHEST_STORY_FLAG: String = "fringe_haven_chest_opened"
const CHEST_REWARD_CRYSTALS: int = 25
const CHEST_REWARD_SALVAGE: int = 10
const INTERACT_RADIUS: float = 2.0    # metres — Area3D trigger radius

enum InteractKind { NONE, MERCHANT, CHEST }

var _player: CharacterBody3D = null
var _character: Character3D = null
var _camera_rig: Node3D = null
var _camera: Camera3D = null
var _velocity_planar: Vector3 = Vector3.ZERO
var _campfire_lights: Array[OmniLight3D] = []
var _campfire_flames: Array[MeshInstance3D] = []
var _anim_accum: float = 0.0

# Active interaction zones the player is currently inside. Each Area3D's
# `on_enter`/`on_exit` flips an entry here; _input reads it when E fires.
# Dict: { area_instance_id: { "kind": InteractKind, "data": Variant } }
var _active_zones: Dictionary = {}

# HUD
var _hud_hint_interact: Label = null
var _hud_hint_depart: Label = null
var _hud_flash: Label = null
var _flash_timer: float = 0.0

# Chest state — swapped between CLOSED/OPEN visuals on collect.
var _chest_lid: MeshInstance3D = null
var _chest_sparkle: MeshInstance3D = null
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
	var v := right * input.x + forward * input.y
	if v.length() > 0.1:
		v = v.normalized() * MOVE_SPEED
	else:
		v = Vector3.ZERO
	_player.velocity = v
	_player.move_and_slide()

	if _character:
		var want := "walk" if v.length() > 0.1 else "idle"
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
	var grass := _tile_texture(GRASS_TILE)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	mi.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = grass
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Repeat the 16px tile across the whole plane at TILE_METRES per tile.
	mat.uv1_scale = Vector3(GROUND_SIZE / TILE_METRES, GROUND_SIZE / TILE_METRES, 1.0)
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)

	# Paths — crossroads pattern roughly matching Fringe Haven layout.
	# N-S strip drawn first at y=0.01; E-W strip drawn on top at y=0.012 so the
	# intersection has one consistent winner (fixes per-frame z-fight jitter).
	_add_path_strip(
		Vector3(0.0, 0.0, -12.0), Vector3(0.0, 0.0, 12.0), 2.5, STONE_TILE, 0.010,
	)
	_add_path_strip(
		Vector3(-14.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0), 2.5, STONE_TILE, 0.012,
	)
	# NW + SE dirt branches.
	_add_path_strip(
		Vector3(-10.0, 0.0, -8.0), Vector3(-3.0, 0.0, -8.0), 1.5, DIRT_TILE,
	)
	_add_path_strip(
		Vector3(3.0, 0.0, 6.0), Vector3(10.0, 0.0, 6.0), 1.5, DIRT_TILE,
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
# textured with the given tileset coord. Sits 0.01m above ground to avoid z-fight.
func _add_path_strip(
	a: Vector3, b: Vector3, width: float, tile: Vector2i, y_offset: float = 0.01,
) -> void:
	var length := a.distance_to(b)
	if length <= 0.001:
		return
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(length, width)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _tile_texture(tile)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(length / TILE_METRES, width / TILE_METRES, 1.0)
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

	# Walls — a box centred vertically at wall_height/2.
	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, wall_height, size.y)
	walls.mesh = box
	walls.position = Vector3(0, wall_height * 0.5, 0)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.87, 0.75, 0.55)   # warm plaster
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
	roof_mat.albedo_color = roof_color
	roof_mat.roughness = 0.85
	roof.material_override = roof_mat
	root.add_child(roof)

	# Door — small dark box on the front face (+Z side).
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
	# NE quadrant — Bryn's Oddities (merchant).
	_make_building(
		Vector3(6.0, 0.0, -5.0),
		Vector2(4.0, 3.0),
		2.0,
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

	_player.global_position = Vector3(0, 0, 0)
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


# A small campfire: ring of stones (dark grey torus), three crossed logs
# (brown cylinders), emissive orange flame cone, warm OmniLight3D. The
# light + flame scale animate in _process for flicker.
func _make_campfire_3d(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	var stones := MeshInstance3D.new()
	var stone_mesh := TorusMesh.new()
	stone_mesh.inner_radius = 0.35
	stone_mesh.outer_radius = 0.55
	stones.mesh = stone_mesh
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.35, 0.33, 0.3)
	stone_mat.roughness = 1.0
	stones.material_override = stone_mat
	stones.position.y = 0.08
	root.add_child(stones)

	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.32, 0.2, 0.12)
	log_mat.roughness = 0.95
	for i in range(3):
		var log_m := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.08
		cyl.height = 0.8
		log_m.mesh = cyl
		log_m.material_override = log_mat
		log_m.rotation = Vector3(0, float(i) * PI / 3.0, deg_to_rad(80.0))
		log_m.position.y = 0.15
		root.add_child(log_m)

	var flame := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.35
	cone.height = 0.7
	flame.mesh = cone
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.55, 0.15)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.6, 0.2)
	flame_mat.emission_energy_multiplier = 2.5
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = flame_mat
	flame.position.y = 0.55
	root.add_child(flame)
	_campfire_flames.append(flame)

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
	# Bryn stands just outside her storefront and opens the trade overlay.
	_spawn_3d_npc(
		"felid_corsair_guard",
		Vector3(6.0, 0.0, -2.5),
		"BRYN — trade",
		PI * 0.5,
		InteractKind.MERCHANT,
	)


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
		_attach_interact_zone(pos, interact, null)


# Spawns an Area3D sphere at `pos` that tracks the player and drives the
# HUD interact prompt. `data` is stored on the entry and passed to the
# interaction dispatcher (used by the chest to resolve its own state).
func _attach_interact_zone(pos: Vector3, kind: int, data: Variant) -> void:
	var area := Area3D.new()
	area.position = pos
	# Monitor only — NPCs already have StaticBody3D colliders for push-back.
	area.monitoring = true
	area.monitorable = false
	var zone_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = INTERACT_RADIUS
	zone_col.shape = sphere
	# Raise the sphere centre so the player's capsule (radius 0.35, centred at
	# y=0.8) overlaps at its midsection — keeps the trigger proportional to the
	# actor height rather than a flat disc at ground level.
	zone_col.position.y = 0.8
	area.add_child(zone_col)
	add_child(area)
	var aid := area.get_instance_id()
	area.body_entered.connect(func(body: Node) -> void:
		if body == _player:
			_active_zones[aid] = {"kind": kind, "data": data}
	)
	area.body_exited.connect(func(body: Node) -> void:
		if body == _player:
			_active_zones.erase(aid)
	)


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
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.52, 0.34, 0.18)
	lid_mat.roughness = 0.85
	_chest_lid.material_override = lid_mat
	root.add_child(_chest_lid)

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
	if _chest_lid:
		_chest_lid.rotation.x = deg_to_rad(-55.0)
		# Slide the lid so its hinge stays at the back of the base.
		_chest_lid.position = Vector3(0, 0.65, -0.1)
	if _chest_sparkle:
		_chest_sparkle.visible = false


func _update_chest_sparkle() -> void:
	if _chest_sparkle == null or not _chest_sparkle.visible:
		return
	var s: float = 0.85 + 0.2 * sin(_anim_accum * 3.2)
	_chest_sparkle.scale = Vector3(s, s, s)
	_chest_sparkle.position.y = 1.1 + 0.05 * sin(_anim_accum * 2.1)


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
	GameSession.open_trade_screen(MERCHANT_FACTION_ID)
	var main_node := get_tree().current_scene
	if main_node and main_node.has_method("push_overlay"):
		main_node.push_overlay("trade")
	else:
		_flash("Trade unavailable (standalone scene).", 2.0)


func _collect_chest(zone_id: int) -> void:
	if _chest_collected:
		return
	_chest_collected = true
	var gs: GameStateData = GameSession.game_state if GameSession else null
	if gs:
		gs.crystal_inventory += CHEST_REWARD_CRYSTALS
		gs.salvage += CHEST_REWARD_SALVAGE
		gs.story_flags[CHEST_STORY_FLAG] = true
	_apply_chest_opened_visuals()
	# Remove the trigger so the prompt clears immediately.
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
		"DEPART — ESC",
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
