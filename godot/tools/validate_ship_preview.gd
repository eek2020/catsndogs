## Headless smoke test for the Ship3DPreview scene. Confirms the decimated GLB
## loads, spawns into the SubViewport pivot, and has a sane triangle count
## (≤ 12k guard against someone accidentally reintroducing the 500k-tri raw FBX).
extends SceneTree


func _initialize() -> void:
	print("====SHIP_PREVIEW_VALIDATE_BEGIN====")
	var scene: PackedScene = load("res://scenes/ships/ship_3d_preview.tscn")
	assert(scene != null, "scene must load")
	var node: Node = scene.instantiate()
	root.add_child(node)
	node._ready()

	var pivot: Node3D = node.get_node("ViewportContainer/SubViewport/Pivot")
	print("  pivot children: %d" % pivot.get_child_count())
	var ship: Node = pivot.get_child(0) if pivot.get_child_count() > 0 else null
	if ship == null:
		print("  FAIL: no ship under pivot")
		quit()
		return

	var mesh_instances: Array = []
	_collect_meshes(ship, mesh_instances)
	var total_tris: int = 0
	for mi in mesh_instances:
		var mesh: Mesh = mi.mesh
		for si in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(si)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else PackedInt32Array()
			total_tris += idx.size() / 3
	print("  mesh_instances=%d total_tris=%d" % [mesh_instances.size(), total_tris])

	if total_tris > 12000:
		print("  FAIL: triangle count %d > 12000 guard" % total_tris)
	else:
		print("  PASS")
	node.queue_free()
	print("====SHIP_PREVIEW_VALIDATE_END====")
	quit()


func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)
