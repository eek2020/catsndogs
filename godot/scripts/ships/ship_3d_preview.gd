## 2.5D ship preview — renders the 3D ship into a SubViewport and composites it
## back as a Sprite2D. Gives the decimated ship_3d_gameready.glb a pixel-art
## target surface (no antialias, crisp texel edges), a slow yaw rotation, and
## a static orthographic Camera3D that matches the 2D ship sprite silhouette.
##
## Used as a perf/visual smoke test before wiring the 2.5D ship into the live
## navigation and combat screens.
extends Control

const SHIP_GLB := "res://assets/ships/ship_3d_gameready.glb"

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
