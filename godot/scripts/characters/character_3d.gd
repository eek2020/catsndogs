## Reusable 3D character — mesh + runtime-assembled AnimationLibrary.
##
## Loads a T-pose mesh (`<char>_t_pose_3d_baseline.fbx`) and a set of mesh-less
## animation FBX files (`<char>_anim_<name>.fbx`), each containing a single
## Mixamo `mixamo_com` animation. The animations are hoisted into an
## AnimationLibrary keyed by short name (idle/walk/run/jump/laugh), so the
## AnimationPlayer can play them by name. Drop a new
## `<char>_anim_<new>.fbx` into `anim_dir` and add the short name to `anim_names`.
##
## All four characters (aristotle, nine_lives, no_tail, dave) follow the same
## on-disk shape: `assets/characters/<base>/3d/<char>_t_pose_3d_baseline.fbx`
## plus `assets/characters/<base>/3d/animations/<char>_anim_<name>.fbx`.
class_name Character3D
extends Node3D

const DEFAULT_ANIMS: Array[String] = ["idle", "walk", "run", "jump", "laugh"]

# Maps character_id → asset base path under `res://assets/characters/`.
# Aristotle and Dave live at the root; crew live under `crew/`.
const CHARACTER_BASES: Dictionary = {
	"aristotle": "aristotle",
	"dave": "dave",
	"nine_lives": "crew/nine_lives",
	"no_tail": "crew/no_tail",
	"blood_paw": "crew/blood_paw",
	"silky": "crew/silky",
	"charlie": "crew/charlie",
	"bombardier": "crew/bombardier",
	"luna": "crew/luna",
	"thistle": "crew/thistle",
	"death": "death",
	"felid_corsair_guard": "npc/felid_corsair_guard",
}

@export var character_id: String = "nine_lives"
@export var mesh_path: String = ""
@export var anim_dir: String = ""
@export var anim_names: Array[String] = DEFAULT_ANIMS
@export var anim_prefix: String = ""
@export var autoplay: String = "idle"
@export_range(0.1, 20.0, 0.1) var model_scale: float = 1.0
## Euler degrees applied to the mesh root. Needed per-character to counter
## FBX-export axis artifacts on cm-authored rigs.
@export var mesh_rotation_deg: Vector3 = Vector3.ZERO
## Extra Y lift applied on top of bone/AABB grounding. Use when the rig has
## scale quirks (e.g. Armature at 0.01) that throw off automatic measurement.
@export var ground_offset_y: float = 0.0

var animation_player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var mesh_root: Node3D = null
var _current_anim: String = ""


static func paths_for(char_id: String) -> Dictionary:
	## Per-character asset locations. Layout is uniform across all characters,
	## so paths derive from `character_id` + `CHARACTER_BASES[char_id]`. Add a
	## new character by adding a row to `CHARACTER_BASES`. Per-rig overrides
	## (rotation_deg / scale / ground_offset_y) live below.
	if not CHARACTER_BASES.has(char_id):
		return {}
	var base: String = CHARACTER_BASES[char_id]
	var out: Dictionary = {
		"mesh": "res://assets/characters/%s/3d/%s_t_pose_3d_baseline.fbx" % [base, char_id],
		"anims": "res://assets/characters/%s/3d/animations" % base,
		"anim_prefix": "%s_anim_" % char_id,
		"scale": 1.0,
	}
	# Per-rig corrections for FBX axis / scale artifacts. Empty for clean rigs.
	match char_id:
		_:
			pass
	return out


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
		if anim_prefix.is_empty():
			anim_prefix = paths.get("anim_prefix", "")
		if model_scale == 1.0 and paths.has("scale"):
			model_scale = paths["scale"]
		if mesh_rotation_deg == Vector3.ZERO and paths.has("rotation_deg"):
			mesh_rotation_deg = paths["rotation_deg"]
		if ground_offset_y == 0.0 and paths.has("ground_offset_y"):
			ground_offset_y = paths["ground_offset_y"]
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


## Translate the character so the lowest skeleton bone sits at local y=0.
## Mixamo/rigged.glb pivots are at the hips, which otherwise bury the feet below
## the ground plane. Using skeleton bones (rather than mesh AABB) sidesteps
## per-rig transform quirks (Armature scale/rotation artifacts from cm FBXs).
## Call after the mesh has loaded.
func ground_to_floor() -> void:
	if skeleton == null or skeleton.get_bone_count() == 0:
		return
	# Measure mesh extents in *character-local* space. The mesh vertices — not
	# skeleton bones — are what the player sees, and can extend below the
	# skeleton's foot bones via skinning / bind-pose offsets. Using the visual
	# AABB also handles rigs where the skeleton origin sits at the hips.
	var char_inv: Transform3D = global_transform.affine_inverse()
	var min_y: float = INF
	var stack: Array = [mesh_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is VisualInstance3D):
			continue
		var vi: VisualInstance3D = n
		var aabb: AABB = vi.get_aabb()
		if aabb.size == Vector3.ZERO:
			continue
		var to_char: Transform3D = char_inv * vi.global_transform
		for i in 8:
			var pt: Vector3 = to_char * aabb.get_endpoint(i)
			if pt.y < min_y:
				min_y = pt.y
	# Also consider the skeleton's rest-pose bones as a lower bound — helps
	# when VisualInstance3D AABBs haven't been computed yet this frame.
	var skel_xform: Transform3D = char_inv * skeleton.global_transform
	for i in skeleton.get_bone_count():
		var p: Vector3 = skel_xform * skeleton.get_bone_global_rest(i).origin
		if p.y < min_y:
			min_y = p.y
	var measured_lift: float = -min_y if (min_y != INF and min_y < 0.0) else 0.0
	var total_lift: float = measured_lift + ground_offset_y
	if total_lift > 0.0:
		position.y += total_lift


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
	# Force track resolution to start at mesh_root. GLB imports can stash the AP
	# anywhere and author `root_node = ".."` — which, under our class hierarchy,
	# points at the parent Character3D rather than mesh_root. That silently
	# breaks every animation track (animation player plays, no bones move).
	animation_player.root_node = animation_player.get_path_to(mesh_root)


func _build_animation_library() -> void:
	if animation_player == null:
		return
	var skel_rel_path: String = mesh_root.get_path_to(skeleton) if skeleton else ""
	var lib := AnimationLibrary.new()
	for nm in anim_names:
		var path := "%s/%s%s.fbx" % [anim_dir, anim_prefix, nm]
		var anim := _load_anim_from_fbx(path)
		if anim != null:
			_retarget_tracks(anim, skel_rel_path)
			# Mixamo FBX imports sometimes land with loop_mode=NONE, so the AP
			# plays once and freezes at the end frame. Force-loop every library
			# entry — every animation we ship is designed to be cycled.
			anim.loop_mode = Animation.LOOP_LINEAR
			# Strip XZ root motion. Mixamo walk/run clips translate the hip bone
			# forward during the cycle, so when the animation loops the mesh
			# snaps back to origin — visible as a "skip backward" every few
			# steps. We want in-place cycles: world position is driven by the
			# CharacterBody3D, not by bone translation.
			_strip_root_xz_motion(anim)
			lib.add_animation(StringName(nm), anim)
	# Replace or install as the default "" library so `play(nm)` works with bare name.
	if animation_player.has_animation_library(&""):
		animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", lib)


## Rewrite the node portion of every track's NodePath so it points at the
## current mesh's Skeleton3D, wherever it lives. Mixamo FBX animations author
## their paths as `Skeleton3D:<bone>` (skeleton at root); some rigs nest it
## under `Armature/Skeleton3D`.
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


## Zero the X and Z components of every position key on the root bone's
## TYPE_POSITION_3D track — keeps vertical bounce (Y) intact so jumps/crouches
## still animate, but removes the forward drift that Mixamo bakes into walk
## and run cycles. Hip bone is typically named "Hips" or "mixamorig:Hips".
static func _strip_root_xz_motion(anim: Animation) -> void:
	# Zero X/Z on every TYPE_POSITION_3D track. Walk/run/idle clips only have
	# position keys on the hip (root) bone by convention, so this is a safe
	# blanket strip and avoids fragile bone-name matching across rigs.
	# Y is kept so vertical bounce (jumps, crouches) still animates.
	for ti in range(anim.get_track_count()):
		if anim.track_get_type(ti) != Animation.TYPE_POSITION_3D:
			continue
		for ki in range(anim.track_get_key_count(ti)):
			var pos: Vector3 = anim.track_get_key_value(ti, ki)
			anim.track_set_key_value(ti, ki, Vector3(0.0, pos.y, 0.0))


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
