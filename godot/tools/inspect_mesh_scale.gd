## Probe the actual world-space AABB of each character mesh so we can pick a
## sensible model_scale and camera ortho_size. Mixamo FBX exports often come
## through at cm scale (characters 180 units tall) which explains why the
## planet prototype shows a ~pixel-sized speck.
extends SceneTree

const MESHES := [
	"res://assets/characters/aristotle/3d/rigged.glb",
	"res://assets/characters/crew/nine_lives/3d/nine_lives_t_pose_3d.fbx",
]


func _initialize() -> void:
	print("==MESH_SCALE==")
	for p in MESHES:
		_probe(p)
	quit()


func _probe(path: String) -> void:
	var scn: PackedScene = load(path)
	var node: Node = scn.instantiate()
	root.add_child(node)
	var mi: MeshInstance3D = node.find_child("*", true, false) as MeshInstance3D
	for c in _walk(node):
		if c is MeshInstance3D:
			mi = c
			break
	if mi == null:
		print("  %s: no MeshInstance3D" % path)
		node.queue_free()
		return
	var aabb: AABB = mi.get_aabb()
	var xformed: AABB = mi.global_transform * aabb
	var skel: Skeleton3D = node.find_child("Skeleton3D", true, false)
	print("  %s" % path)
	print("    root_scale=%s" % node.scale)
	if skel:
		print("    skeleton_scale=%s" % skel.scale)
	print("    mesh local AABB: pos=%s size=%s (height=%0.3f)" % [aabb.position, aabb.size, aabb.size.y])
	print("    mesh world AABB: pos=%s size=%s (height=%0.3f)" % [xformed.position, xformed.size, xformed.size.y])
	node.queue_free()


func _walk(node: Node, out: Array = []) -> Array:
	out.append(node)
	for c in node.get_children():
		_walk(c, out)
	return out
