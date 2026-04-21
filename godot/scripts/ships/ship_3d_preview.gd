## 2.5D ship preview — renders the 3D ship into a SubViewport and composites it
## back as a Sprite2D. Gives the source ship model a pixel-art target surface
## (no antialias, crisp texel edges), a slow yaw rotation, and a static
## orthographic Camera3D that matches the 2D ship sprite silhouette.
##
## Used as a perf/visual smoke test before wiring the 2.5D ship into the live
## navigation and combat screens.
##
## felid_cruiser.fbx is authored at ~1cm AABB (Blender export unit mismatch).
## SHIP_SCALE auto-normalises to a ~3m target so the ortho camera frames it.
extends Control

const SHIP_GLB := "res://assets/ships/3d/felid_cruiser.fbx"
const SHIP_TARGET_SIZE: float = 3.0  # metres, longest-axis target after scale

@onready var viewport: SubViewport = $ViewportContainer/SubViewport
@onready var hud: Label = $HUD/Label

var _ship: Node3D = null
var _yaw: float = 0.0


func _ready() -> void:
	_spawn_ship()


func _process(delta: float) -> void:
	if _ship:
		_yaw += delta * 0.35
		_ship.rotation.y = _yaw
	_refresh_hud()


func _spawn_ship() -> void:
	if not ResourceLoader.exists(SHIP_GLB):
		push_warning("ship_3d_preview: missing %s" % SHIP_GLB)
		return
	var packed: PackedScene = load(SHIP_GLB)
	_ship = packed.instantiate()
	var pivot: Node3D = $ViewportContainer/SubViewport/Pivot
	pivot.add_child(_ship)
	_ship.position = Vector3.ZERO
	# Auto-normalise unit scale so FBX-export mismatches (mm vs m) don't leave
	# the ship invisible at the ortho camera's 3m field, then re-centre so the
	# AABB centroid sits at the pivot origin (FBXes often export with origin
	# at the Blender world zero rather than geometry centre).
	var combined_aabb := _combined_aabb(_ship)
	var longest: float = max(combined_aabb.size.x, max(combined_aabb.size.y, combined_aabb.size.z))
	if longest > 0.0:
		var s: float = SHIP_TARGET_SIZE / longest
		_ship.scale = Vector3(s, s, s)
	var centred_aabb := _combined_aabb(_ship)
	_ship.position = -(centred_aabb.position + centred_aabb.size * 0.5)


func _combined_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for mi in _collect_meshes(node, []):
		var m: MeshInstance3D = mi
		var a: AABB = m.transform * m.mesh.get_aabb()
		if first:
			result = a
			first = false
		else:
			result = result.merge(a)
	return result


func _collect_meshes(node: Node, out: Array) -> Array:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)
	return out


func _refresh_hud() -> void:
	if hud == null:
		return
	var tri_count: int = 0
	if _ship:
		for c in _ship.get_children():
			if c is MeshInstance3D and c.mesh:
				for si in range(c.mesh.get_surface_count()):
					tri_count += c.mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX].size() / 3
	hud.text = "Ship 2.5D preview — yaw=%0.1f° · tris=%d" % [rad_to_deg(_yaw), tri_count]
