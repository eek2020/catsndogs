## Headless smoke test for the planet-surface 3D prototype. Confirms the
## SpriteCharacter3D wrapper can spawn, wire its SubViewport, and plant a
## Character3D inside it without scene-tree timing issues.
extends SceneTree


func _initialize() -> void:
	print("====PLANET_3D_PROTO_VALIDATE_BEGIN====")
	var scene: PackedScene = load("res://scenes/characters/planet_3d_prototype.tscn")
	var node: Node = scene.instantiate()
	root.add_child(node)
	if node.has_method("initialize"):
		node.call("initialize")

	var world: Node2D = node.get_node("World")
	var char: SpriteCharacter3D = null
	for c in world.get_children():
		if c is SpriteCharacter3D:
			char = c
			break
	if char == null:
		print("  FAIL: no SpriteCharacter3D under World")
		quit()
		return
	# Prototype._ready fired on add_child → SpriteCharacter3D was spawned and
	# initialized. Assert the composition wired up cleanly.
	assert(char.viewport != null, "viewport must exist")
	assert(char.character != null, "character must exist")
	var anims: Array = char.character.available_anims()
	print("  character_id=%s anims=%s" % [char.character_id, anims])
	print("  viewport size=%s ortho_size=%0.2f" % [char.viewport.size, char.camera.size])
	print("  PASS")
	print("====PLANET_3D_PROTO_VALIDATE_END====")
	quit()
