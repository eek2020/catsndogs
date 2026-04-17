extends Node3D

## Root script for no_tail_cutscene.tscn.
##
## Finds the imported .glb nodes (Door, Aristotle, NoTail, etc.), wires up
## the CutsceneManager, CameraController, and CutsceneDialogueUI, and kicks off
## the cutscene when the scene loads.

@onready var cutscene_manager: CutsceneManager = $CutsceneManager
@onready var camera_controller: CameraController = $CameraController
@onready var camera: Camera3D = $CameraController/Camera3D
@onready var dialogue_ui: CutsceneDialogueUI = $DialogueUI
@onready var world: Node3D = $World


func _ready() -> void:
	# The .glb imports as a scene tree rooted at $World/NoTailOutpost.
	# We need to find the Door node by name so the cutscene manager can animate it.
	var door_node: Node3D = _find_node_by_name(world, "Door")
	if door_node == null:
		push_warning("Could not find 'Door' node in the imported scene.")
	else:
		print("CutsceneScene: Door found at %s" % str(door_node.global_position))

	# Add burn / scorch marks around the door frame.
	# (Interior room + doorway hole are modeled in no_tail_outpost.blend;
	# the runtime _build_interior / _hide_back_wall functions are gone.)
	if door_node:
		_apply_burn_marks($World/NoTailOutpost, door_node.global_position)

	# Hide placeholder character geometry baked into the outpost GLB.
	# The detailed character models are separate instanced scenes.
	_hide_placeholder_characters($World/NoTailOutpost)

	# Find character nodes placed in the World.
	var aristotle_node: Node3D = $World/Aristotle if has_node("World/Aristotle") else null
	var no_tail_node: Node3D = $World/NoTail if has_node("World/NoTail") else null
	if aristotle_node == null:
		push_warning("Could not find 'Aristotle' node in the scene.")
	else:
		print("CutsceneScene: Aristotle at %s, visible=%s, scale=%s" % [
			str(aristotle_node.global_position),
			str(aristotle_node.visible),
			str(aristotle_node.scale),
		])
	if no_tail_node == null:
		push_warning("Could not find 'NoTail' node in the scene.")
	else:
		print("CutsceneScene: NoTail at %s, visible=%s, scale=%s" % [
			str(no_tail_node.global_position),
			str(no_tail_node.visible),
			str(no_tail_node.scale),
		])

	# Dump all child names from the GLB for debugging mesh name matching.
	print("CutsceneScene: GLB subtree nodes:")
	_print_tree($World/NoTailOutpost, 0)

	# TODO(S7): delete MaterialApplicator entirely once the .blend ships with
	# proper material slots + UV unwraps (CODE_REVIEW §6A.6 step 3). Today
	# this runtime painter is ~370 lines that exist solely to compensate for
	# the untextured GLB.
	# Apply runtime materials to untextured geometry.
	var applicator := MaterialApplicator.new()
	applicator.apply($World/NoTailOutpost)

	# Force the door light fixture mesh to red (MaterialApplicator may not
	# match it by name — the GLB sphere mesh sits near the DoorRim light).
	_force_red_light_fixture($World/NoTailOutpost)

	# Override the Door mesh material so it reads as a door, not a wall panel.
	# MaterialApplicator assigns a near-identical dark metal to both, which
	# makes the door visually disappear into the outpost face.
	# Distinct warm-brown door panel, matte so it doesn't bloom.
	if door_node is MeshInstance3D:
		var door_mat := StandardMaterial3D.new()
		door_mat.albedo_color = Color(0.32, 0.20, 0.11)
		door_mat.roughness = 0.85
		door_mat.metallic = 0.15
		var dmi := door_node as MeshInstance3D
		for s in range(dmi.mesh.get_surface_count()):
			dmi.set_surface_override_material(s, door_mat)

	# Frame pieces: matte dark to stop them over-reflecting the rim light
	# (otherwise the bloom bleeds over the door and makes it look tiny).
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.14, 0.13, 0.12)
	frame_mat.roughness = 0.95
	frame_mat.metallic = 0.1
	for frame_name in ["Door_FrameLeft", "Door_FrameRight", "Door_FrameTop"]:
		var fn: Node = _find_node_by_name($World/NoTailOutpost, frame_name)
		if fn is MeshInstance3D:
			var fmi := fn as MeshInstance3D
			for s in range(fmi.mesh.get_surface_count()):
				fmi.set_surface_override_material(s, frame_mat)

	# Wire cross-references.
	cutscene_manager.dialogue_ui = dialogue_ui
	cutscene_manager.camera_controller = camera_controller
	cutscene_manager.door_node = door_node
	cutscene_manager.aristotle_node = aristotle_node
	cutscene_manager.no_tail_node = no_tail_node
	camera_controller.camera = camera

	# Connect dialogue UI to cutscene manager.
	cutscene_manager.choice_presented.connect(
		func(prompt: String, options: Array) -> void:
			dialogue_ui.show_choice(prompt, options)
	)
	cutscene_manager.cutscene_finished.connect(_on_cutscene_finished)
	cutscene_manager.event_triggered.connect(_on_event_triggered)

	# The CutsceneManager will autostart in its own _ready.


## TODO(S7): delete once burn marks are painted into the door-frame texture
## in Blender (CODE_REVIEW §6A.6 step 1). Runtime QuadMesh + NoiseTexture2D
## stack here is a workaround for the untextured GLB.
##
## Apply burn / scorch marks around the door frame.
## Creates dark emissive quads positioned around the door opening to simulate
## blast damage from the League attack mentioned in the dialogue.
func _apply_burn_marks(outpost: Node, door_pos: Vector3) -> void:
	if outpost == null:
		return

	var scorch_mat := StandardMaterial3D.new()
	scorch_mat.albedo_color = Color(0.04, 0.02, 0.01)
	scorch_mat.roughness = 0.95
	scorch_mat.metallic = 0.1
	scorch_mat.emission_enabled = true
	scorch_mat.emission = Color(0.4, 0.1, 0.02)
	scorch_mat.emission_energy_multiplier = 0.6
	scorch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scorch_mat.albedo_color.a = 0.85
	scorch_mat.no_depth_test = true
	scorch_mat.render_priority = 1
	# Noise detail for irregular burn pattern.
	var noise_tex := NoiseTexture2D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.05
	noise.seed = 42
	noise_tex.noise = noise
	noise_tex.width = 128
	noise_tex.height = 128
	noise_tex.seamless = true
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.01, 0.01, 0.9))
	grad.add_point(0.4, Color(0.15, 0.05, 0.02, 0.6))
	grad.set_color(grad.get_point_count() - 1, Color(0.05, 0.03, 0.02, 0.3))
	noise_tex.color_ramp = grad
	scorch_mat.albedo_texture = noise_tex

	# Place scorch quads around the door frame.
	var burn_positions: Array[Dictionary] = [
		# Left side of door frame
		{"offset": Vector3(-1.8, 1.5, 0.15), "size": Vector2(1.5, 3.5), "rot": 0.0},
		# Right side of door frame
		{"offset": Vector3(1.8, 1.5, 0.15), "size": Vector2(1.5, 3.5), "rot": 0.0},
		# Top of door frame
		{"offset": Vector3(0.0, 3.8, 0.15), "size": Vector2(5.0, 1.4), "rot": 0.0},
		# Bottom of door frame
		{"offset": Vector3(0.0, -0.1, 0.15), "size": Vector2(4.5, 0.8), "rot": 0.0},
		# Ground in front of door
		{"offset": Vector3(0.0, 0.04, 1.8), "size": Vector2(3.5, 2.5), "rot": -PI / 2.0},
	]

	for i in range(burn_positions.size()):
		var bp: Dictionary = burn_positions[i]
		var quad_mesh := QuadMesh.new()
		quad_mesh.size = bp.size
		var mi := MeshInstance3D.new()
		mi.mesh = quad_mesh
		mi.set_surface_override_material(0, scorch_mat)
		mi.name = "BurnMark_%d" % i
		mi.position = door_pos + bp.offset
		if bp.rot != 0.0:
			mi.rotation.x = bp.rot
		outpost.add_child(mi)
	print("CutsceneScene: Added %d burn marks around door at %s" % [
		burn_positions.size(), str(door_pos),
	])


## TODO(S7): delete once placeholder character geometry is removed from the
## exported no_tail_outpost GLB (CODE_REVIEW §6A.1). Only needed because
## the current .blend ships with baked-in Aristotle_ / NoTail_ stand-ins.
##
## Hide placeholder character meshes baked into the outpost GLB.
## These are flat shapes prefixed with "Aristotle_" and "NoTail_".
func _hide_placeholder_characters(outpost: Node) -> void:
	if outpost == null:
		return
	for child in outpost.get_children():
		var n: String = child.name
		if n.begins_with("Aristotle_") or n.begins_with("NoTail_"):
			if child is Node3D:
				child.visible = false
		# Recurse in case Godot nests GLB children.
		_hide_placeholder_characters(child)


## TODO(S7): delete once the fixture mesh is named meaningfully + has its
## red emissive material assigned in the .blend (CODE_REVIEW §6A.1 /
## §6A.6 step 1). Proximity-based classifier below is fragile.
##
## Force the Door_WarningLight sphere to use a red emissive material.
## The mesh in the .blend is named explicitly, so find it by name — the
## previous proximity heuristic also grabbed the frame pieces and turned
## them into giant red emissive slabs.
func _force_red_light_fixture(outpost: Node) -> void:
	if outpost == null:
		return
	var light_node: Node = _find_node_by_name(outpost, "Door_WarningLight")
	if light_node == null or not (light_node is MeshInstance3D):
		return
	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(1.0, 0.1, 0.05)
	red_mat.emission_enabled = true
	red_mat.emission = Color(1.0, 0.15, 0.1)
	red_mat.emission_energy_multiplier = 3.0
	red_mat.roughness = 0.3
	red_mat.metallic = 0.1
	var mi := light_node as MeshInstance3D
	for s in range(mi.mesh.get_surface_count()):
		mi.set_surface_override_material(s, red_mat)


## Depth-first search for a node by name anywhere in a subtree.
func _find_node_by_name(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var found: Node = _find_node_by_name(child, target)
		if found:
			return found
	return null


## Debug: print the node tree with indentation.
func _print_tree(node: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var type_str := node.get_class()
	var extra := ""
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			extra = " surfaces=%d aabb=%s" % [
				mi.mesh.get_surface_count(), str(mi.mesh.get_aabb().size),
			]
	print("%s%s [%s]%s" % [indent, node.name, type_str, extra])
	for child in node.get_children():
		_print_tree(child, depth + 1)


## Cutscene id used when emitting the EventBus completion signal. Must match
## the `id` in `res://data/cutscenes/_registry.json`. Sprint 7 will fold this
## into the registry-driven bootstrap.
@export var cutscene_id: String = "no_tail_outpost"


func _on_cutscene_finished() -> void:
	# Hand off to the rest of the game via EventBus. SceneManager / overlay
	# host listens for `cutscene_completed` and decides what to re-enter
	# (overlay pop, scene change, next arc transition, etc.). Karma delta
	# and recruited ids come from CutsceneManager's accumulated state.
	var karma_delta := 0
	var recruited: Array = []
	if cutscene_manager != null:
		if "_karma_delta" in cutscene_manager:
			karma_delta = cutscene_manager.get("_karma_delta")
		if "_recruited" in cutscene_manager:
			var r: Variant = cutscene_manager.get("_recruited")
			if r is Array:
				recruited = r
	EventBus.cutscene_completed.emit(cutscene_id, karma_delta, recruited)
	print("Cutscene %s complete. Karma delta: %d. Recruited: %s" % [
		cutscene_id, karma_delta, str(recruited),
	])


func _on_event_triggered(event_name: String) -> void:
	print("Event: %s" % event_name)
	# Parent scenes can intercept events here to trigger real gameplay
	# (combat encounters, scene transitions, save points, etc.)
