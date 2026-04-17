## Reusable 3D character — mesh + runtime-assembled AnimationLibrary.
##
## Loads a T-pose mesh (`mesh_path`) and a set of mesh-less animation FBX files
## (`anim_dir`/`anim_names`.fbx), each containing a single Mixamo `mixamo_com`
## animation. The animations are hoisted into an AnimationLibrary keyed by
## filename (Idle/Walk/Run/Sprint/Jump), so the AnimationPlayer can play them by
## short name and additional animations can be added by dropping FBXs into
## `anim_dir` with no code change.
##
## Bone-name compatibility: all Mixamo animation FBXs and the T-pose meshes in
## this project share the `mixamorig_*` prefix. Minor bone-count mismatches
## (34 vs 41 for Aristotle — fingers absent on the rig) are tolerated by Godot:
## tracks targeting missing bones silently no-op.
class_name Character3D
extends Node3D

const DEFAULT_ANIMS: Array[String] = ["Idle", "Walking", "Running", "Sprint", "Jumping"]

@export var character_id: String = "aristotle"
@export var mesh_path: String = ""
@export var anim_dir: String = ""
@export var anim_names: Array[String] = DEFAULT_ANIMS
@export var autoplay: String = "Idle"
@export_range(0.1, 20.0, 0.1) var model_scale: float = 1.0
## Euler degrees applied to the mesh root. Needed per-character to counter
## FBX-export axis artifacts (e.g. Aristotle's rigged.glb has an inner
## Armature at 90° X rotation + 0.01 scale — legacy of cm-based authoring).
@export var mesh_rotation_deg: Vector3 = Vector3.ZERO

var animation_player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var mesh_root: Node3D = null
var _current_anim: String = ""


static func paths_for(char_id: String) -> Dictionary:
	## Known per-character asset locations. Adding a character means adding a row.
	match char_id:
		"aristotle":
			return {
				"mesh": "res://assets/characters/aristotle/3d/rigged.glb",
				"anims": "res://assets/characters/aristotle/3d/animations",
				"scale": 1.0,
				# rigged.glb's inner Armature carries (90°, 0°, 0°) + 0.01 scale
				# from the cm-based FBX authoring. Counter-rotate so the
				# character stands on +Y rather than lying on -Z.
				"rotation_deg": Vector3(-90, 0, 0),
			}
		"nine_lives":
			return {
				"mesh": "res://assets/characters/crew/nine_lives/3d/nine_lives_t_pose_3d.fbx",
				"anims": "res://assets/characters/crew/nine_lives/3d/animations",
				"scale": 1.0,
				"rotation_deg": Vector3.ZERO,
			}
		_:
			return {}


func _ready() -> void:
	initialize()


## Synchronous initialization. Called by `_ready` in normal scene use, and
## directly by tests/validators that run outside the scene tree's ready cycle.
func initialize() -> void:
	if mesh_root != null:
		return  # already initialized
	if mesh_path.is_empty() or anim_dir.is_empty():
		var paths := paths_for(character_id)
		if paths.is_empty():
			push_warning("Character3D: unknown character_id '%s'" % character_id)
			return
		if mesh_path.is_empty():
			mesh_path = paths.get("mesh", "")
		if anim_dir.is_empty():
			anim_dir = paths.get("anims", "")
		if model_scale == 1.0 and paths.has("scale"):
			model_scale = paths["scale"]
		if mesh_rotation_deg == Vector3.ZERO and paths.has("rotation_deg"):
			mesh_rotation_deg = paths["rotation_deg"]
	_load_mesh()
	_build_animation_library()
	if autoplay != "" and animation_player and animation_player.has_animation(autoplay):
		play_anim(autoplay)


func play_anim(name: String) -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation(name):
		push_warning("Character3D(%s): animation '%s' not found" % [character_id, name])
		return
	_current_anim = name
	animation_player.play(name)


func current_anim() -> String:
	return _current_anim


func available_anims() -> Array:
	if animation_player == null:
		return []
	return animation_player.get_animation_list()


func _load_mesh() -> void:
	if not ResourceLoader.exists(mesh_path):
		push_warning("Character3D(%s): mesh not found at %s" % [character_id, mesh_path])
		return
	var packed: PackedScene = load(mesh_path) as PackedScene
	if packed == null:
		push_warning("Character3D(%s): mesh is not a PackedScene at %s" % [character_id, mesh_path])
		return
	mesh_root = packed.instantiate()
	mesh_root.scale = Vector3.ONE * model_scale
	mesh_root.rotation_degrees = mesh_rotation_deg
	add_child(mesh_root)
	skeleton = mesh_root.find_child("Skeleton3D", true, false) as Skeleton3D
	# Use the mesh FBX/GLB's own AnimationPlayer as the target — it's already wired
	# to the Skeleton3D via relative paths. We rebuild its library below.
	animation_player = mesh_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		mesh_root.add_child(animation_player)


func _build_animation_library() -> void:
	if animation_player == null:
		return
	var skel_rel_path: String = mesh_root.get_path_to(skeleton) if skeleton else ""
	var lib := AnimationLibrary.new()
	for nm in anim_names:
		var path := "%s/%s.fbx" % [anim_dir, nm]
		var anim := _load_anim_from_fbx(path)
		if anim != null:
			_retarget_tracks(anim, skel_rel_path)
			lib.add_animation(StringName(nm), anim)
	# Replace or install as the default "" library so `play(nm)` works with bare name.
	if animation_player.has_animation_library(&""):
		animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", lib)


## Rewrite the node portion of every track's NodePath so it points at the
## current mesh's Skeleton3D, wherever it lives. Mixamo FBX animations author
## their paths as `Skeleton3D:<bone>` (skeleton at root); some rigs (e.g. the
## CC0-UAL-derived Aristotle rigged.glb) nest it under `Armature/Skeleton3D`.
## Without this rewrite, Godot silently skips every track and the character
## locks in T-pose while logging unresolved-track warnings.
static func _retarget_tracks(anim: Animation, skel_rel_path: String) -> void:
	if skel_rel_path.is_empty() or skel_rel_path == ".":
		return
	for ti in range(anim.get_track_count()):
		var p: NodePath = anim.track_get_path(ti)
		var sub: String = String(p.get_concatenated_subnames())
		if sub.is_empty():
			continue
		anim.track_set_path(ti, NodePath("%s:%s" % [skel_rel_path, sub]))


static func _load_anim_from_fbx(fbx_path: String) -> Animation:
	if not ResourceLoader.exists(fbx_path):
		return null
	var packed: PackedScene = load(fbx_path) as PackedScene
	if packed == null:
		return null
	var root: Node = packed.instantiate()
	var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var anim: Animation = null
	if ap and ap.has_animation("mixamo_com"):
		anim = ap.get_animation("mixamo_com").duplicate(true)
	root.queue_free()
	return anim
