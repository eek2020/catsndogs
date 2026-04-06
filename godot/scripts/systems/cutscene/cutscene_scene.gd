extends Node3D

## Root script for no_tail_cutscene.tscn.
##
## Finds the imported .glb nodes (Door, Aristotle, NoTail, etc.), wires up
## the CutsceneManager, CameraController, and DialogueUI, and kicks off
## the cutscene when the scene loads.

@onready var cutscene_manager: CutsceneManager = $CutsceneManager
@onready var camera_controller: CameraController = $CameraController
@onready var camera: Camera3D = $CameraController/Camera3D
@onready var dialogue_ui: DialogueUI = $DialogueUI
@onready var world: Node3D = $World


func _ready() -> void:
    # The .glb imports as a scene tree rooted at $World/NoTailOutpost.
    # We need to find the Door node by name so the cutscene manager can animate it.
    var door_node: Node3D = _find_node_by_name(world, "Door")
    if door_node == null:
        push_warning("Could not find 'Door' node in the imported scene.")
    else:
        print("CutsceneScene: Door found at %s" % str(door_node.global_position))

    # Hide the back wall behind the door so NoTail is visible through the doorway.
    if door_node:
        _hide_back_wall($World/NoTailOutpost, door_node.global_position)

    # Build a visible interior room behind the doorway.
    if door_node:
        _build_interior($World/NoTailOutpost, door_node.global_position)

    # Add burn / scorch marks around the door frame.
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
        print("CutsceneScene: Aristotle at %s, visible=%s, scale=%s" % [str(aristotle_node.global_position), str(aristotle_node.visible), str(aristotle_node.scale)])
    if no_tail_node == null:
        push_warning("Could not find 'NoTail' node in the scene.")
    else:
        print("CutsceneScene: NoTail at %s, visible=%s, scale=%s" % [str(no_tail_node.global_position), str(no_tail_node.visible), str(no_tail_node.scale)])

    # Dump all child names from the GLB for debugging mesh name matching.
    print("CutsceneScene: GLB subtree nodes:")
    _print_tree($World/NoTailOutpost, 0)

    # Apply runtime materials to untextured geometry.
    var applicator := MaterialApplicator.new()
    applicator.apply($World/NoTailOutpost)

    # Force the door light fixture mesh to red (MaterialApplicator may not
    # match it by name — the GLB sphere mesh sits near the DoorRim light).
    _force_red_light_fixture($World/NoTailOutpost)

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


## Hide any mesh geometry directly behind the door that blocks the doorway view.
## Finds MeshInstance3D nodes whose AABB overlaps with the door's X/Y position
## but sits behind (further negative Z) the door — i.e. the back wall.
func _hide_back_wall(outpost: Node, door_pos: Vector3) -> void:
    if outpost == null:
        return
    _hide_back_wall_recursive(outpost, door_pos)


func _hide_back_wall_recursive(node: Node, door_pos: Vector3) -> void:
    if node is MeshInstance3D:
        var mi := node as MeshInstance3D
        if mi.mesh:
            var gpos: Vector3 = mi.global_position
            var aabb: AABB = mi.mesh.get_aabb()
            var size: Vector3 = aabb.size
            # Only hide meshes that are:
            # 1. Directly behind the door (within 3 units further -Z)
            # 2. Centered on the door X position (within 2 units)
            # 3. Thin in Z (< 1.0) — a flat wall panel, not a structural element
            # 4. Wide enough to block the doorway (> 2.0 in X)
            var behind_door: bool = gpos.z < door_pos.z - 0.3 and gpos.z > door_pos.z - 3.0
            var centered_x: bool = abs(gpos.x - door_pos.x) < 2.0
            var flat_wall: bool = size.z < 1.0 and size.x > 2.0 and size.y > 1.5
            if behind_door and centered_x and flat_wall:
                mi.visible = false
                print("CutsceneScene: Hiding back wall mesh '%s' at %s (size=%s)" % [mi.name, str(gpos), str(size)])
    for child in node.get_children():
        _hide_back_wall_recursive(child, door_pos)


## Build a small interior room visible through the open doorway.
## Creates floor, back wall, side walls, ceiling, a dim interior light, and
## a few prop silhouettes (crates, shelves) so the space behind No Tail
## looks like a real room instead of void.
func _build_interior(outpost: Node, door_pos: Vector3) -> void:
    if outpost == null:
        return

    var room_depth: float = 6.0   # how far back the room extends (-Z)
    var room_width: float = 5.0   # side-to-side
    var room_height: float = 4.5  # floor to ceiling
    var z_back: float = door_pos.z - room_depth
    var z_mid: float = door_pos.z - room_depth * 0.5

    # ── Materials (plain colors — no noise textures for performance) ────
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color(0.14, 0.12, 0.10)
    floor_mat.roughness = 0.8
    floor_mat.metallic = 0.4

    var wall_mat := StandardMaterial3D.new()
    wall_mat.albedo_color = Color(0.18, 0.16, 0.14)
    wall_mat.roughness = 0.7
    wall_mat.metallic = 0.5

    var ceiling_mat := StandardMaterial3D.new()
    ceiling_mat.albedo_color = Color(0.12, 0.11, 0.10)
    ceiling_mat.roughness = 0.85
    ceiling_mat.metallic = 0.3

    var crate_mat := StandardMaterial3D.new()
    crate_mat.albedo_color = Color(0.22, 0.16, 0.08)
    crate_mat.roughness = 0.85
    crate_mat.metallic = 0.15

    # ── Helper to add a box mesh ────────────────────────────────────────
    var interior_root := Node3D.new()
    interior_root.name = "Interior"
    outpost.add_child(interior_root)

    # Floor
    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(room_width, 0.15, room_depth)
    var floor_mi := MeshInstance3D.new()
    floor_mi.mesh = floor_mesh
    floor_mi.name = "InteriorFloor"
    floor_mi.position = Vector3(door_pos.x, door_pos.y - 0.08, z_mid)
    floor_mi.set_surface_override_material(0, floor_mat)
    interior_root.add_child(floor_mi)

    # Back wall
    var back_wall_mesh := BoxMesh.new()
    back_wall_mesh.size = Vector3(room_width, room_height, 0.2)
    var back_wall_mi := MeshInstance3D.new()
    back_wall_mi.mesh = back_wall_mesh
    back_wall_mi.name = "InteriorBackWall"
    back_wall_mi.position = Vector3(door_pos.x, door_pos.y + room_height * 0.5, z_back)
    back_wall_mi.set_surface_override_material(0, wall_mat)
    interior_root.add_child(back_wall_mi)

    # Left wall
    var left_wall_mesh := BoxMesh.new()
    left_wall_mesh.size = Vector3(0.2, room_height, room_depth)
    var left_wall_mi := MeshInstance3D.new()
    left_wall_mi.mesh = left_wall_mesh
    left_wall_mi.name = "InteriorLeftWall"
    left_wall_mi.position = Vector3(door_pos.x - room_width * 0.5, door_pos.y + room_height * 0.5, z_mid)
    left_wall_mi.set_surface_override_material(0, wall_mat)
    interior_root.add_child(left_wall_mi)

    # Right wall
    var right_wall_mesh := BoxMesh.new()
    right_wall_mesh.size = Vector3(0.2, room_height, room_depth)
    var right_wall_mi := MeshInstance3D.new()
    right_wall_mi.mesh = right_wall_mesh
    right_wall_mi.name = "InteriorRightWall"
    right_wall_mi.position = Vector3(door_pos.x + room_width * 0.5, door_pos.y + room_height * 0.5, z_mid)
    right_wall_mi.set_surface_override_material(0, wall_mat)
    interior_root.add_child(right_wall_mi)

    # Ceiling
    var ceil_mesh := BoxMesh.new()
    ceil_mesh.size = Vector3(room_width, 0.15, room_depth)
    var ceil_mi := MeshInstance3D.new()
    ceil_mi.mesh = ceil_mesh
    ceil_mi.name = "InteriorCeiling"
    ceil_mi.position = Vector3(door_pos.x, door_pos.y + room_height, z_mid)
    ceil_mi.set_surface_override_material(0, ceiling_mat)
    interior_root.add_child(ceil_mi)

    # Interior light — dim warm point light inside the room
    var interior_light := OmniLight3D.new()
    interior_light.name = "InteriorLight"
    interior_light.light_color = Color(0.9, 0.65, 0.35)
    interior_light.light_energy = 1.2
    interior_light.omni_range = 6.0
    interior_light.shadow_enabled = false
    interior_light.position = Vector3(door_pos.x, door_pos.y + room_height - 0.5, z_mid)
    interior_root.add_child(interior_light)

    # ── Props ────────────────────────────────────────────────────────────
    # Crate stack against back-left corner
    var crate1_mesh := BoxMesh.new()
    crate1_mesh.size = Vector3(0.8, 0.8, 0.8)
    var crate1 := MeshInstance3D.new()
    crate1.mesh = crate1_mesh
    crate1.name = "InteriorCrate1"
    crate1.position = Vector3(door_pos.x - room_width * 0.35, door_pos.y + 0.4, z_back + 0.6)
    crate1.set_surface_override_material(0, crate_mat)
    interior_root.add_child(crate1)

    var crate2_mesh := BoxMesh.new()
    crate2_mesh.size = Vector3(0.7, 0.7, 0.7)
    var crate2 := MeshInstance3D.new()
    crate2.mesh = crate2_mesh
    crate2.name = "InteriorCrate2"
    crate2.position = Vector3(door_pos.x - room_width * 0.35, door_pos.y + 1.15, z_back + 0.6)
    crate2.rotation.y = 0.3
    crate2.set_surface_override_material(0, crate_mat)
    interior_root.add_child(crate2)

    # Barrel on right side
    var barrel_mesh := CylinderMesh.new()
    barrel_mesh.top_radius = 0.35
    barrel_mesh.bottom_radius = 0.35
    barrel_mesh.height = 0.9
    var barrel := MeshInstance3D.new()
    barrel.mesh = barrel_mesh
    barrel.name = "InteriorBarrel"
    barrel.position = Vector3(door_pos.x + room_width * 0.3, door_pos.y + 0.45, z_back + 0.8)
    barrel.set_surface_override_material(0, crate_mat)
    interior_root.add_child(barrel)

    # Shelf / workbench along right wall
    var shelf_mesh := BoxMesh.new()
    shelf_mesh.size = Vector3(0.4, 1.2, 2.5)
    var shelf := MeshInstance3D.new()
    shelf.mesh = shelf_mesh
    shelf.name = "InteriorShelf"
    shelf.position = Vector3(door_pos.x + room_width * 0.5 - 0.3, door_pos.y + 0.6, z_mid + 0.5)
    shelf.set_surface_override_material(0, wall_mat)
    interior_root.add_child(shelf)

    # Small item on shelf
    var item_mesh := BoxMesh.new()
    item_mesh.size = Vector3(0.25, 0.25, 0.25)
    var item := MeshInstance3D.new()
    item.mesh = item_mesh
    item.name = "InteriorItem"
    item.position = Vector3(door_pos.x + room_width * 0.5 - 0.3, door_pos.y + 1.35, z_mid + 0.3)
    item.rotation.y = 0.7
    var item_mat := StandardMaterial3D.new()
    item_mat.albedo_color = Color(0.3, 0.25, 0.15)
    item_mat.roughness = 0.6
    item_mat.metallic = 0.5
    item.set_surface_override_material(0, item_mat)
    interior_root.add_child(item)

    print("CutsceneScene: Built interior room behind door at %s (depth=%.1f)" % [str(door_pos), room_depth])


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
    print("CutsceneScene: Added %d burn marks around door at %s" % [burn_positions.size(), str(door_pos)])


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


## Force the light fixture mesh (small sphere near the door) to use a red
## emissive material.  The GLB mesh name may not contain "light" so the
## MaterialApplicator won't match it by keyword — we find it by proximity
## to the DoorRim light position instead.
func _force_red_light_fixture(outpost: Node) -> void:
    if outpost == null:
        return
    var door_light_pos := Vector3(0, 4, -16.5)  # matches DoorRim transform in .tscn
    var red_mat := StandardMaterial3D.new()
    red_mat.albedo_color = Color(1.0, 0.1, 0.05)
    red_mat.emission_enabled = true
    red_mat.emission = Color(1.0, 0.15, 0.1)
    red_mat.emission_energy_multiplier = 3.0
    red_mat.roughness = 0.3
    red_mat.metallic = 0.1
    _force_red_recursive(outpost, door_light_pos, red_mat)


func _force_red_recursive(node: Node, target_pos: Vector3, mat: StandardMaterial3D) -> void:
    if node is MeshInstance3D:
        var mi := node as MeshInstance3D
        if mi.mesh:
            var gpos := mi.global_position
            var dist := gpos.distance_to(target_pos)
            var aabb := mi.mesh.get_aabb()
            var vol: float = aabb.size.x * aabb.size.y * aabb.size.z
            # Small mesh within 3 units of the light position = fixture
            if dist < 3.0 and vol < 4.0:
                for s in range(mi.mesh.get_surface_count()):
                    mi.set_surface_override_material(s, mat)
                print("CutsceneScene: Forced red material on light fixture '%s' at %s (dist=%.1f)" % [mi.name, str(gpos), dist])
    for child in node.get_children():
        _force_red_recursive(child, target_pos, mat)


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
            extra = " surfaces=%d aabb=%s" % [mi.mesh.get_surface_count(), str(mi.mesh.get_aabb().size)]
    print("%s%s [%s]%s" % [indent, node.name, type_str, extra])
    for child in node.get_children():
        _print_tree(child, depth + 1)


func _on_cutscene_finished() -> void:
    print("Cutscene complete. Returning to game...")
    # In a real game, transition back to the main scene here.


func _on_event_triggered(event_name: String) -> void:
    print("Event: %s" % event_name)
    # Parent scenes can intercept events here to trigger real gameplay
    # (combat encounters, scene transitions, save points, etc.)
