## Preview harness for the 3D character + animation library pipeline.
##
## Spawns Aristotle or Nine Lives via Character3D, cycles through their
## animations, lets the user switch character with [1]/[2] and skip animations
## with Space. Used to validate the Mixamo animation library + T-pose mesh
## combinations before wiring them into gameplay.
extends Node3D

const CHARACTERS: Array[String] = ["aristotle", "nine_lives"]
const ANIM_CYCLE: Array[String] = ["Idle", "Walking", "Running", "Sprint", "Jumping"]
const SWITCH_INTERVAL: float = 3.0

@onready var camera: Camera3D = $Camera3D
@onready var hud_label: Label = $HUD/Label

var _character_idx: int = 0
var _anim_idx: int = 0
var _switch_timer: float = 0.0
var _character: Character3D = null
var _orbit_yaw: float = 0.0
var _orbit_enabled: bool = false


func _ready() -> void:
	_spawn_ground()
	_spawn_character(CHARACTERS[_character_idx])


## Reference ground plane + grid so the user can visually verify character is
## standing upright on Y=0, not lying on its side. Also provides shadow
## catcher for the directional light.
func _spawn_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.28)
	mat.roughness = 0.9
	plane.material = mat
	add_child(ground)

	# Simple grid decals: evenly spaced thin cubes along X and Z axes.
	for i in range(-2, 3):
		for axis in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
			var bar := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(6, 0.005, 0.02) if axis.x > 0 else Vector3(0.02, 0.005, 6)
			bar.mesh = box
			bar.position = Vector3(0, 0.003, i) if axis.x > 0 else Vector3(i, 0.003, 0)
			var line_mat := StandardMaterial3D.new()
			line_mat.albedo_color = Color(0.35, 0.38, 0.45)
			box.material = line_mat
			add_child(bar)


func _process(delta: float) -> void:
	_switch_timer += delta
	if _switch_timer >= SWITCH_INTERVAL:
		_switch_timer = 0.0
		_cycle_animation()
	if _orbit_enabled:
		_orbit_yaw += delta * 0.6
	# Continuous orbit controls via A/D even without _orbit_enabled.
	if Input.is_key_pressed(KEY_A):
		_orbit_yaw -= delta * 1.2
	if Input.is_key_pressed(KEY_D):
		_orbit_yaw += delta * 1.2
	_aim_camera()
	_refresh_hud()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_switch_timer = 0.0
		_cycle_animation()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_character(0)
			KEY_2:
				_set_character(1)
			KEY_O:
				_orbit_enabled = not _orbit_enabled


func _set_character(idx: int) -> void:
	if idx < 0 or idx >= CHARACTERS.size() or idx == _character_idx:
		return
	_character_idx = idx
	_anim_idx = 0
	_switch_timer = 0.0
	_spawn_character(CHARACTERS[idx])


func _spawn_character(char_id: String) -> void:
	if _character != null:
		_character.queue_free()
		_character = null
	_character = preload("res://scenes/characters/character_3d.tscn").instantiate()
	_character.character_id = char_id
	_character.autoplay = ANIM_CYCLE[_anim_idx]
	add_child(_character)
	_character.position = Vector3.ZERO
	_aim_camera()


## Place the camera at a fixed 3/4 hero-angle orbit (radius + elevation) and
## point it at the character's chest. `_orbit_yaw` advances in _process.
func _aim_camera() -> void:
	if camera == null:
		return
	var radius: float = 2.6
	var elevation: float = 0.7
	var target_y: float = 0.45  # chest height for ~0.95m-tall character
	var px: float = cos(_orbit_yaw) * radius
	var pz: float = sin(_orbit_yaw) * radius
	camera.look_at_from_position(
		Vector3(px, elevation, pz),
		Vector3(0, target_y, 0),
		Vector3.UP
	)


func _cycle_animation() -> void:
	if _character == null:
		return
	_anim_idx = (_anim_idx + 1) % ANIM_CYCLE.size()
	_character.play_anim(ANIM_CYCLE[_anim_idx])


func _refresh_hud() -> void:
	if hud_label == null:
		return
	var char_id := CHARACTERS[_character_idx]
	var anim_name: String = _character.current_anim() if _character else "-"
	hud_label.text = "%s — %s  yaw=%0.1f°\n[1]/[2] switch · Space next anim · A/D orbit · O auto-orbit" % [
		char_id, anim_name, rad_to_deg(_orbit_yaw)
	]
