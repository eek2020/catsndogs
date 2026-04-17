extends Node3D

var character: Node3D
var animation_player: AnimationPlayer
var camera: Camera3D
var animations = ["Idle", "Walk", "Run", "Jump", "Fall"]
var current_index = 0
var switch_timer = 0.0
var switch_interval = 3.0  # Switch animations every 3 seconds

func _ready() -> void:
	print("Animation Preview Controller Ready")
	
	# Get the camera
	camera = $Camera3D
	
	# Load the GLB programmatically
	var glb_path = "res://assets/characters/crew/nine_lives/3d/rigged.glb"
	var gltf_resource = load(glb_path)
	
	if gltf_resource:
		print("Loaded GLB resource")
		character = gltf_resource.instantiate()
		add_child(character)
		character.position = Vector3(0, 0, 0)
		character.scale = Vector3(3, 3, 3)  # Scale up significantly
		
		# Make camera look at character
		camera.look_at(character.position)
		print("Character position: ", character.position)
		print("Camera position: ", camera.position)
		
		# Find the AnimationPlayer
		animation_player = character.find_child("AnimationPlayer", true, false)
		
		if animation_player:
			print("Found AnimationPlayer")
			print("Available animations: ", animation_player.get_animation_list())
			
			# Start with Idle animation specifically
			if "Idle" in animation_player.get_animation_list():
				animation_player.play("Idle")
				print("Playing: Idle")
				animations = ["Idle", "Walk", "Run", "Jump", "Sprint"]
			else:
				var anims = animation_player.get_animation_list()
				if anims.size() > 0:
					animations = anims
					animation_player.play(anims[0])
					print("Playing: ", anims[0])
		else:
			print("ERROR: No AnimationPlayer found in loaded GLB")
	else:
		print("ERROR: Failed to load GLB: ", glb_path)

func _process(delta: float) -> void:
	switch_timer += delta
	
	if switch_timer >= switch_interval:
		switch_timer = 0.0
		current_index = (current_index + 1) % animations.size()
		
		var anim_name = animations[current_index]
		if anim_name in animation_player.get_animation_list():
			animation_player.play(anim_name)
			print("Playing: ", anim_name)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		# Skip to next animation on space/enter
		current_index = (current_index + 1) % animations.size()
		var anim_name = animations[current_index]
		if anim_name in animation_player.get_animation_list():
			animation_player.play(anim_name)
			print("Playing: ", anim_name)
