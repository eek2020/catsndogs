## Walk the scene tree of each character mesh + print every Node3D's local
## transform so we can find where (if anywhere) a non-identity rotation
## tips the character over.
extends SceneTree

const TARGETS := [
	"res://assets/characters/aristotle/3d/rigged.glb",
	"res://assets/characters/crew/nine_lives/3d/nine_lives_t_pose_3d.fbx",
]


func _initialize() -> void:
	for p in TARGETS:
		print("\n== %s ==" % p)
		var scn: PackedScene = load(p)
		var root_node: Node = scn.instantiate()
		root.add_child(root_node)
		_walk(root_node, 0)
		# Also dump the first track's first 3 key values of Idle for this character
		root_node.queue_free()

	# Probe the idle animation's root-bone track values
	print("\n== Idle anim root-bone first keys ==")
	for path in [
		"res://assets/characters/aristotle/3d/animations/Idle.fbx",
		"res://assets/characters/crew/nine_lives/3d/animations/Idle.fbx",
	]:
		print("\n-- %s --" % path)
		var scn: PackedScene = load(path)
		var r: Node = scn.instantiate()
		root.add_child(r)
		var ap: AnimationPlayer = r.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation("mixamo_com"):
			var an: Animation = ap.get_animation("mixamo_com")
			for ti in range(min(3, an.get_track_count())):
				var p: NodePath = an.track_get_path(ti)
				var type: int = an.track_get_type(ti)
				var type_name: String = (["Value","Position3D","Rotation3D","Scale3D","BlendShape","Method","Bezier","Audio","Animation"][type]) if type < 9 else "?"
				print("  track %d path=%s type=%s keys=%d" % [ti, p, type_name, an.track_get_key_count(ti)])
				if type == Animation.TYPE_POSITION_3D or type == Animation.TYPE_ROTATION_3D:
					for ki in range(min(2, an.track_get_key_count(ti))):
						print("    key %d t=%.3f value=%s" % [ki, an.track_get_key_time(ti, ki), an.track_get_key_value(ti, ki)])
		r.queue_free()
	quit()


func _walk(node: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	if node is Node3D:
		var n3: Node3D = node
		print("%s%s (%s) pos=%s rot_deg=%s scale=%s" % [
			pad, node.name, node.get_class(),
			n3.position, n3.rotation_degrees, n3.scale,
		])
	else:
		print("%s%s (%s)" % [pad, node.name, node.get_class()])
	for c in node.get_children():
		_walk(c, depth + 1)
