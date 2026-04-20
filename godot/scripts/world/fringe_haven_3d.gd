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
const TILE_PX: int = 16
# Tileset atlas coords (col, row) — centres of the solid 3×3 floor panels
# on the 18×13 sheet. Picked visually from the PNG to avoid edge/transition
# tiles (which read as diagonal stripes when tiled).
const GRASS_TILE: Vector2i = Vector2i(10, 4)
const DIRT_TILE: Vector2i = Vector2i(0, 3)
const STONE_TILE: Vector2i = Vector2i(7, 7)
# World size of a single tile, in metres. 1 tile ≈ half a character.
const TILE_METRES: float = 0.5

var _player: CharacterBody3D = null
var _character: Character3D = null
var _camera_rig: Node3D = null
var _camera: Camera3D = null
var _velocity_planar: Vector3 = Vector3.ZERO


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_buildings()
	_build_player()
	_build_camera()


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


func _on_depart() -> void:
	# Step 1: ESC just quits. Full depart wiring comes in step 5.
	var main_node := get_tree().current_scene
	if main_node and main_node.has_method("switch_scene"):
		main_node.switch_scene("navigation")
	else:
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
	_add_path_strip(Vector3(-14.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0), 2.5, STONE_TILE)  # E-W main road
	_add_path_strip(Vector3(0.0, 0.0, -12.0), Vector3(0.0, 0.0, 12.0), 2.5, STONE_TILE)  # N-S main road
	_add_path_strip(Vector3(-10.0, 0.0, -8.0), Vector3(-3.0, 0.0, -8.0), 1.5, DIRT_TILE)  # NW branch
	_add_path_strip(Vector3(3.0, 0.0, 6.0), Vector3(10.0, 0.0, 6.0), 1.5, DIRT_TILE)      # SE branch

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
func _add_path_strip(a: Vector3, b: Vector3, width: float, tile: Vector2i) -> void:
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
	mi.position = mid + Vector3(0, 0.01, 0)
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
	roof.position = Vector3(0, wall_height + roof_height * 0.4, 0)
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
	# SE quadrant — doghouses (smaller).
	for i in range(4):
		var x := 3.5 + float(i) * 2.2
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
	_character = preload("res://scenes/characters/character_3d.tscn").instantiate()
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
