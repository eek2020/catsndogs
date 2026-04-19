## 2D-compatible wrapper around a Character3D rendered via SubViewport.
##
## Drops in alongside Sprite2D-based world entities: parent this Node2D at the
## entity's world position, call `play_anim()` / `face_direction()`, and the
## on-screen output is a textured rect fed from a transparent SubViewport whose
## camera stares at the 3D rigged mesh. The 3D scene stays lightweight (128²
## render target, ortho camera, single directional light, one rig).
##
## Designed to swap into planet_surface.gd (and later fringe_haven_outpost /
## oakhaven_outpost) in place of the per-entity Sprite2D without disturbing the
## tilemap, interaction radius, or movement math.
class_name SpriteCharacter3D
extends Node2D

@export var character_id: String = "nine_lives"
@export_range(32, 512, 16) var render_size: int = 256
@export_range(0.5, 10.0, 0.1) var ortho_size: float = 2.4
@export var autoplay: String = "idle"
## Convenience property — size to render on screen (Sprite2D equivalent).
@export var display_size: Vector2 = Vector2(128, 128)
## If true, override ortho_size + camera Y from the loaded mesh's AABB so the
## character always fills ~85 % of the frustum regardless of rig dimensions.
@export var autofit: bool = true
@export_range(0.05, 0.5, 0.01) var autofit_margin: float = 0.15

var container: SubViewportContainer = null
var viewport: SubViewport = null
var camera: Camera3D = null
var character: Character3D = null
var _facing_yaw: float = 0.0


func _ready() -> void:
	initialize()


## Synchronous init — safe to call from test harnesses that run outside the
## normal scene-tree _ready cycle. Idempotent.
func initialize() -> void:
	if viewport != null:
		return
	_build_tree()
	_spawn_character()


## Interface parity with the existing Sprite2D-based walk/idle dispatch.
func play_anim(name: String) -> void:
	if character:
		character.play_anim(name)


func current_anim() -> String:
	return character.current_anim() if character else ""


func face_direction(angle_rad: float) -> void:
	_facing_yaw = angle_rad
	if character:
		character.rotation.y = angle_rad


func _build_tree() -> void:
	container = SubViewportContainer.new()
	container.stretch = true
	container.size = display_size
	container.position = -display_size * 0.5  # center on this Node2D
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.size = Vector2i(render_size, render_size)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)

	var light := DirectionalLight3D.new()
	light.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(35)) * Basis(Vector3.RIGHT, deg_to_rad(-50)),
		Vector3(4, 6, 6)
	)
	light.light_energy = 1.6
	viewport.add_child(light)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ortho_size
	camera.current = true
	viewport.add_child(camera)
	_aim_camera(0.5)  # placeholder; re-aimed after mesh load when autofit on


func _spawn_character() -> void:
	character = preload("res://scenes/characters/character_3d.tscn").instantiate()
	character.character_id = character_id
	character.autoplay = autoplay
	viewport.add_child(character)
	character.initialize()
	if autofit:
		_fit_camera_to_mesh()


## Measure the loaded mesh's AABB and resize/position the camera so the
## character fills (1 - autofit_margin) of the frustum, framed by a 3/4 hero
## angle (slight side rotation, slight elevation) to match animation_preview.
## Pure side-view produced a confusing top-down read when the idle pose
## wasn't a tall T-pose (our cat/dog characters).
func _fit_camera_to_mesh() -> void:
	if character == null or character.mesh_root == null:
		return
	var mi: MeshInstance3D = null
	for c in _walk(character.mesh_root):
		if c is MeshInstance3D:
			mi = c
			break
	if mi == null or mi.mesh == null:
		return
	var aabb: AABB = mi.mesh.get_aabb()
	var max_extent: float = max(aabb.size.y, max(aabb.size.x, aabb.size.z))
	var target_frustum: float = max_extent * (1.0 + autofit_margin)
	if target_frustum <= 0.0:
		return
	ortho_size = target_frustum
	camera.size = ortho_size
	var center_y: float = aabb.position.y + aabb.size.y * 0.5
	_aim_camera(center_y)


## 3/4 hero-angle aim: camera pulled right and slightly above character
## center, always looking at character center. Matches animation_preview's
## proven framing.
func _aim_camera(center_y: float) -> void:
	var right: float = ortho_size * 0.75
	var up: float = ortho_size * 0.30
	var back: float = max(2.5, ortho_size * 2.0)
	camera.look_at_from_position(
		Vector3(right, center_y + up, back),
		Vector3(0, center_y, 0),
		Vector3.UP
	)


static func _walk(node: Node, out: Array = []) -> Array:
	out.append(node)
	for c in node.get_children():
		_walk(c, out)
	return out
