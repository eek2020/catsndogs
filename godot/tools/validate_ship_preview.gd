## Headless smoke test for the Ship3DPreview scene. Confirms the ship model
## loads, spawns into the SubViewport pivot, and reports triangle count +
## post-normalisation scale.
##
## felid_cruiser.fbx is ~500k tris pre-decimation and ~1cm AABB (Blender
## export unit mismatch); the preview's auto-scale normalises the latter.
## Decimation is a separate pipeline step if we promote this to live scenes.
extends SceneTree

## Threshold is generous because the SubViewport target (512²) makes
## sub-pixel tris effectively free on desktop GPUs — raw-FBX counts are
## fine. Tighten only if we start compositing 3+ ships per frame or a
## perf regression shows up in combat.
const TRI_BUDGET_WARN: int = 600000


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
	print("  ship.scale=%s (auto-normalised)" % str(ship.scale))
	if total_tris > TRI_BUDGET_WARN:
		print("  WARN: %d tris above %d-tri threshold — decimate before live wiring" % [
			total_tris, TRI_BUDGET_WARN,
		])
	else:
		print("  PASS (tri budget OK)")
	node.queue_free()
	print("====SHIP_PREVIEW_VALIDATE_END====")
	quit()


func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)
