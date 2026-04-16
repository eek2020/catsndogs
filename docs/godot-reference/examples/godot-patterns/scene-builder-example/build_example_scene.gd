extends SceneTree
## Example scene builder — creates a simple 2D scene with player and camera.
## Run: timeout 60 godot --headless --script scenes/build_example_scene.gd

func _initialize() -> void:
	print("Generating: ExampleScene")

	# Root node
	var root_node := Node2D.new()
	root_node.name = "ExampleScene"

	# Player (CharacterBody2D with collision and sprite)
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(640, 360)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 48)
	collision.shape = shape
	player.add_child(collision)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	# sprite.texture = load("res://assets/sprites/player.png")  # Uncomment with real asset
	player.add_child(sprite)

	# Attach runtime script (uncomment when script exists)
	# player.set_script(load("res://scripts/player_controller.gd"))

	root_node.add_child(player)

	# Camera following the player
	var camera := Camera2D.new()
	camera.name = "Camera"
	player.add_child(camera)

	# Ground (StaticBody2D)
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.position = Vector2(640, 680)

	var ground_collision := CollisionShape2D.new()
	ground_collision.name = "GroundCollision"
	var ground_shape := RectangleShape2D.new()
	ground_shape.size = Vector2(1280, 40)
	ground_collision.shape = ground_shape
	ground.add_child(ground_collision)

	root_node.add_child(ground)

	# CRITICAL: Set ownership chain (skips instantiated scene internals)
	set_owner_on_new_nodes(root_node, root_node)

	# Save
	var packed := PackedScene.new()
	var err := packed.pack(root_node)
	if err != OK:
		push_error("Pack failed: " + str(err))
		quit(1)
		return

	err = ResourceSaver.save(packed, "res://scenes/example_scene.tscn")
	if err != OK:
		push_error("Save failed: " + str(err))
		quit(1)
		return

	print("Saved: res://scenes/example_scene.tscn")
	quit(0)


func set_owner_on_new_nodes(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		if child.scene_file_path.is_empty():
			set_owner_on_new_nodes(child, scene_owner)
