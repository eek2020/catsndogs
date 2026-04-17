## Headless inspector for the newly-added 3D assets. Prints bone counts, animation
## ranges, mesh stats, and texture sizes for each FBX/GLB. Run via:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/inspect_3d_assets.gd
extends SceneTree

const TARGETS: Array = [
	# Aristotle — T-pose + 5 anim FBX (new)
	"res://assets/characters/aristotle/3d/animations/Idle.fbx",
	"res://assets/characters/aristotle/3d/animations/Running.fbx",
	"res://assets/characters/aristotle/3d/animations/Walking.fbx",
	"res://assets/characters/aristotle/3d/animations/Sprint.fbx",
	"res://assets/characters/aristotle/3d/animations/Jumping.fbx",
	# Aristotle — already-shipped rigged.glb for comparison
	"res://assets/characters/aristotle/3d/rigged.glb",
	# Nine Lives — T-pose FBX + 5 animation FBX (new)
	"res://assets/characters/crew/nine_lives/3d/nine_lives_t_pose_3d.fbx",
	"res://assets/characters/crew/nine_lives/3d/animations/Idle.fbx",
	"res://assets/characters/crew/nine_lives/3d/animations/Running.fbx",
	"res://assets/characters/crew/nine_lives/3d/animations/Walking.fbx",
	"res://assets/characters/crew/nine_lives/3d/animations/Sprint.fbx",
	"res://assets/characters/crew/nine_lives/3d/animations/Jumping.fbx",
	# Nine Lives — already-shipped rigged.glb for comparison
	"res://assets/characters/crew/nine_lives/3d/rigged.glb",
	# Ship
	"res://assets/ships/ship_3d.fbx",
]

func _initialize() -> void:
	print("====3D_INSPECT_BEGIN====")
	var results: Array = []
	for path in TARGETS:
		results.append(_inspect(path))
	print(JSON.stringify(results, "  "))
	print("====3D_INSPECT_END====")
	quit()

func _inspect(path: String) -> Dictionary:
	var info: Dictionary = {"path": path}
	if not ResourceLoader.exists(path):
		info["error"] = "not_found"
		return info
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		info["error"] = "not_packedscene"
		return info
	var root: Node = packed.instantiate()
	if root == null:
		info["error"] = "instantiate_failed"
		return info

	info["root_type"] = root.get_class()
	info["root_name"] = root.name
	info["children_summary"] = _summarize_children(root)

	var skeletons: Array = []
	var anim_players: Array = []
	var meshes: Array = []
	_collect(root, skeletons, anim_players, meshes)

	var skel_data: Array = []
	for s in skeletons:
		var sk: Skeleton3D = s
		var bone_names: Array = []
		for i in range(sk.get_bone_count()):
			bone_names.append(sk.get_bone_name(i))
		skel_data.append({
			"name": sk.name,
			"bone_count": sk.get_bone_count(),
			"first_10": bone_names.slice(0, 10),
			"last_5": bone_names.slice(max(0, bone_names.size() - 5)),
		})
	info["skeletons"] = skel_data

	var ap_data: Array = []
	for a in anim_players:
		var ap: AnimationPlayer = a
		var lib_ids: Array = []
		for lib_name in ap.get_animation_library_list():
			lib_ids.append(str(lib_name))
		var anim_list: Array = []
		for anim_name in ap.get_animation_list():
			var an: Animation = ap.get_animation(anim_name)
			anim_list.append({
				"name": anim_name,
				"length": an.length,
				"track_count": an.get_track_count(),
				"loop_mode": an.loop_mode,
			})
		ap_data.append({
			"name": ap.name,
			"libraries": lib_ids,
			"animations": anim_list,
		})
	info["animation_players"] = ap_data

	var mesh_data: Array = []
	for m in meshes:
		var mi: MeshInstance3D = m
		var mesh: Mesh = mi.mesh
		var surf_count: int = mesh.get_surface_count() if mesh else 0
		var surfaces: Array = []
		var total_verts: int = 0
		var total_tris: int = 0
		for si in range(surf_count):
			var arrays: Array = mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > Mesh.ARRAY_VERTEX else PackedVector3Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else PackedInt32Array()
			var vcount: int = verts.size()
			var tri_count: int = indices.size() / 3 if indices.size() > 0 else vcount / 3
			total_verts += vcount
			total_tris += tri_count
			var mat: Material = mesh.surface_get_material(si)
			surfaces.append({
				"idx": si,
				"verts": vcount,
				"tris": tri_count,
				"material": mat.resource_name if mat else "",
				"material_class": mat.get_class() if mat else "",
			})
		mesh_data.append({
			"name": mi.name,
			"total_verts": total_verts,
			"total_tris": total_tris,
			"surfaces": surfaces,
			"skin": mi.skin != null,
			"has_skeleton_path": mi.skeleton != NodePath(""),
		})
	info["meshes"] = mesh_data

	root.queue_free()
	return info

func _collect(node: Node, skeletons: Array, anim_players: Array, meshes: Array) -> void:
	if node is Skeleton3D:
		skeletons.append(node)
	if node is AnimationPlayer:
		anim_players.append(node)
	if node is MeshInstance3D:
		meshes.append(node)
	for c in node.get_children():
		_collect(c, skeletons, anim_players, meshes)

func _summarize_children(node: Node, depth: int = 0, buf: Array = []) -> Array:
	if depth > 3:
		return buf
	buf.append({"type": node.get_class(), "name": node.name, "depth": depth})
	for c in node.get_children():
		_summarize_children(c, depth + 1, buf)
	return buf
