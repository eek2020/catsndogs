## Headless validator for the Character3D pipeline. Instantiates the scene for
## each known character, reports which animations resolve, which bones are
## present, and whether each Mixamo animation targets bones that exist on the
## mesh's skeleton. Run via:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/validate_character_3d.gd
extends SceneTree

const CHARACTERS: Array[String] = ["aristotle", "nine_lives", "no_tail", "dave", "blood_paw", "silky", "death", "charlie", "bombardier", "luna", "thistle"]
const EXPECTED_ANIMS: Array[String] = ["idle", "walk", "run", "jump", "laugh"]


func _initialize() -> void:
	print("====CHARACTER_3D_VALIDATE_BEGIN====")
	for char_id in CHARACTERS:
		_validate(char_id)
	print("====CHARACTER_3D_VALIDATE_END====")
	quit()


func _validate(char_id: String) -> void:
	print("\n== %s ==" % char_id)
	var scene: PackedScene = load("res://scenes/characters/character_3d.tscn")
	var char: Character3D = scene.instantiate()
	char.character_id = char_id
	root.add_child(char)
	char.initialize()

	if char.animation_player == null:
		print("  FAIL: no AnimationPlayer")
		char.queue_free()
		return
	if char.skeleton == null:
		print("  WARN: no Skeleton3D found on mesh")

	var lib_anims: Array = char.available_anims()
	print("  library size=%d anims=%s" % [lib_anims.size(), lib_anims])

	var bone_names: Dictionary = {}
	if char.skeleton:
		for i in range(char.skeleton.get_bone_count()):
			bone_names[char.skeleton.get_bone_name(i)] = true
		print("  skeleton bone_count=%d" % char.skeleton.get_bone_count())

	for exp in EXPECTED_ANIMS:
		if not char.animation_player.has_animation(exp):
			print("  FAIL: missing animation '%s'" % exp)
			continue
		var anim: Animation = char.animation_player.get_animation(exp)
		var matched: int = 0
		var unmatched: int = 0
		for ti in range(anim.get_track_count()):
			var track_path: NodePath = anim.track_get_path(ti)
			var bone: String = String(track_path.get_concatenated_subnames())
			if bone_names.has(bone):
				matched += 1
			else:
				unmatched += 1
		print("  anim %-10s len=%5.2fs tracks=%d matched_bones=%d unmatched=%d" % [
			exp, anim.length, anim.get_track_count(), matched, unmatched
		])

	char.queue_free()
