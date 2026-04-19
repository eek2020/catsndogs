## Regression tests for Character3D — the reusable 3D rigged-character scene
## that assembles an AnimationLibrary from the per-animation Mixamo FBX files.
##
## Guards:
## - Nine Lives instantiates without error.
## - Every expected animation resolves on the AnimationPlayer.
## - Every animation's tracks target bones that exist on the skeleton (prevents
##   silent-no-op regressions when somebody swaps in a mismatched rig).
extends "res://addons/gut/test.gd"

const SCENE_PATH := "res://scenes/characters/character_3d.tscn"
const CHARACTERS := ["aristotle", "nine_lives", "no_tail", "dave", "blood_paw", "silky", "death", "charlie", "bombardier", "luna", "thistle"]
const EXPECTED_ANIMS := ["idle", "walk", "run", "jump", "laugh"]


func _instantiate_character(char_id: String) -> Character3D:
	var scene: PackedScene = load(SCENE_PATH)
	var c: Character3D = scene.instantiate()
	c.character_id = char_id
	add_child_autofree(c)
	c.initialize()
	return c


func test_paths_known_for_both_characters() -> void:
	for char_id in CHARACTERS:
		var paths := Character3D.paths_for(char_id)
		assert_false(paths.is_empty(), "paths_for(%s) must not be empty" % char_id)
		assert_true(paths.has("mesh"), "paths_for(%s) must have 'mesh'" % char_id)
		assert_true(paths.has("anims"), "paths_for(%s) must have 'anims'" % char_id)
		assert_true(ResourceLoader.exists(paths["mesh"]),
			"mesh for %s must exist: %s" % [char_id, paths["mesh"]])


func test_library_has_all_expected_animations() -> void:
	for char_id in CHARACTERS:
		var c := _instantiate_character(char_id)
		assert_not_null(c.animation_player, "%s must expose an AnimationPlayer" % char_id)
		for nm in EXPECTED_ANIMS:
			assert_true(c.animation_player.has_animation(nm),
				"%s library missing '%s'" % [char_id, nm])


func test_animation_tracks_map_to_skeleton_bones() -> void:
	# All Mixamo animation tracks we ship should resolve to bones the rig actually
	# has; otherwise the animation silently no-ops in-game.
	for char_id in CHARACTERS:
		var c := _instantiate_character(char_id)
		assert_not_null(c.skeleton, "%s must have a Skeleton3D" % char_id)
		var bones := {}
		for i in range(c.skeleton.get_bone_count()):
			bones[c.skeleton.get_bone_name(i)] = true
		for nm in EXPECTED_ANIMS:
			var anim: Animation = c.animation_player.get_animation(nm)
			for ti in range(anim.get_track_count()):
				var sub: String = String(anim.track_get_path(ti).get_concatenated_subnames())
				assert_true(bones.has(sub),
					"%s anim '%s' track %d targets missing bone '%s'" % [char_id, nm, ti, sub])


func test_tracks_target_actual_skeleton_node_path() -> void:
	# The node portion (everything before the `:`) must match the real skeleton
	# location in the mesh tree — catches `Skeleton3D` vs `Armature/Skeleton3D`
	# mismatches on rigs that nest the skeleton under an Armature node.
	for char_id in CHARACTERS:
		var c := _instantiate_character(char_id)
		var expected: String = str(c.mesh_root.get_path_to(c.skeleton))
		for nm in EXPECTED_ANIMS:
			var anim: Animation = c.animation_player.get_animation(nm)
			for ti in range(anim.get_track_count()):
				var p: NodePath = anim.track_get_path(ti)
				var names: PackedStringArray = []
				for n in range(p.get_name_count()):
					names.append(p.get_name(n))
				var node_portion: String = "/".join(names)
				assert_eq(node_portion, expected,
					"%s anim '%s' track %d node portion '%s' != '%s'" % [
						char_id, nm, ti, node_portion, expected
					])


func test_play_anim_sets_current() -> void:
	var c := _instantiate_character("nine_lives")
	c.play_anim("run")
	assert_eq(c.current_anim(), "run")


func test_unknown_character_is_a_warning_not_a_crash() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	var c: Character3D = scene.instantiate()
	c.character_id = "ghost"
	add_child_autofree(c)
	c.initialize()
	# No mesh, no skeleton — the scene stays empty but doesn't crash.
	assert_null(c.skeleton)
