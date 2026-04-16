class_name CameraController
extends Node3D

## Reads camera_path.json and moves a Camera3D between named keys.
##
## Each key has a position, look_at target, fov, and transition time.
## Call move_to_key("CAM_01_Establishing") and await the returned tween.

@export_file("*.json") var camera_path_path: String = "res://data/cutscenes/camera_path.json"
@export var camera: Camera3D

var _keys: Dictionary = {}   # name -> { position, look_at, fov, transition_seconds, ... }


func _ready() -> void:
	_load_keys()
	# Defer the initial snap so the parent scene has a chance to assign
	# our camera reference first (parent _ready runs after children).
	call_deferred("_snap_to_first_key")


func _snap_to_first_key() -> void:
	if camera and _keys.size() > 0:
		var first_name: String = _keys.keys()[0]
		_apply_key_instant(first_name)


func _load_keys() -> void:
	if not FileAccess.file_exists(camera_path_path):
		push_error("CameraController: file not found: %s" % camera_path_path)
		return
	var text := FileAccess.get_file_as_string(camera_path_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CameraController: camera path JSON is not a dictionary")
		return
	for cam in parsed.get("cameras", []):
		_keys[cam.name] = cam


func _apply_key_instant(key_name: String) -> void:
	if not _keys.has(key_name) or camera == null:
		return
	var key: Dictionary = _keys[key_name]
	var pos := _to_vec3(key.position)
	var target := _to_vec3(key.look_at)
	camera.position = pos
	camera.look_at(target, Vector3.UP)
	if key.has("fov"):
		camera.fov = float(key.fov)


## Move the camera to a named key, tweening over the key's transition time.
## Returns when the tween finishes. Use: await camera_controller.move_to_key("CAM_02_...")
func move_to_key(key_name: String) -> void:
	if not _keys.has(key_name):
		push_warning("CameraController: unknown key %s" % key_name)
		return
	if camera == null:
		push_warning("CameraController: no camera assigned")
		return

	var key: Dictionary = _keys[key_name]
	var target_pos := _to_vec3(key.position)
	var look_target := _to_vec3(key.look_at)
	var transition: float = float(key.get("transition_seconds", 2.0))
	var target_fov: float = float(key.get("fov", camera.fov))
	var hold: float = float(key.get("hold_seconds", 0.0))

	if transition <= 0.0:
		_apply_key_instant(key_name)
	else:
		var start_look := _current_look_target()
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(camera, "position", target_pos, transition)
		tween.tween_property(camera, "fov", target_fov, transition)
		# Tween a Vector3 through a method callback that re-aims the camera.
		tween.tween_method(
			func(v: Vector3) -> void:
				if is_instance_valid(camera):
					camera.look_at(v, Vector3.UP),
			start_look,
			look_target,
			transition
		)
		await tween.finished

	if hold > 0.0:
		await get_tree().create_timer(hold).timeout


## Estimate what the camera is currently looking at.
## Projects a point forward along the camera's -Z axis.
func _current_look_target() -> Vector3:
	if camera == null:
		return Vector3.ZERO
	return camera.global_position + -camera.global_transform.basis.z * 10.0


func _to_vec3(arr: Variant) -> Vector3:
	if typeof(arr) == TYPE_ARRAY and arr.size() >= 3:
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return Vector3.ZERO
