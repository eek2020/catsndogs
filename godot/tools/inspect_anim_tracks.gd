## Dump the raw NodePaths the Mixamo animations use, vs the actual skeleton
## location in each character mesh. Diagnostic for the unresolved-track warning.
extends SceneTree


func _initialize() -> void:
	print("==ANIM_PATHS==")
	_dump_fbx_anim("res://assets/characters/aristotle/3d/animations/Idle.fbx")
	_dump_mesh("res://assets/characters/aristotle/3d/rigged.glb")
	_dump_mesh("res://assets/characters/crew/nine_lives/3d/nine_lives_t_pose_3d.fbx")
	quit()


func _dump_fbx_anim(path: String) -> void:
	print("\n-- %s --" % path)
	var scn: PackedScene = load(path)
	var root: Node = scn.instantiate()
	var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	if ap == null:
		print("  no AnimationPlayer")
		return
	print("  ap.root_node=%s ap_path=%s" % [ap.root_node, ap.get_path()])
	for nm in ap.get_animation_list():
		var an: Animation = ap.get_animation(nm)
		print("  anim '%s' first 3 tracks:" % nm)
		for i in range(min(3, an.get_track_count())):
			print("    %s" % an.track_get_path(i))
	root.queue_free()


func _dump_mesh(path: String) -> void:
	print("\n-- MESH %s --" % path)
	var scn: PackedScene = load(path)
	var root: Node = scn.instantiate()
	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false)
	if skel:
		print("  skeleton at: %s (relative from root: %s)" % [
			skel.get_path(),
			root.get_path_to(skel),
		])
	var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	if ap:
		print("  ap.root_node=%s" % ap.root_node)
	root.queue_free()
