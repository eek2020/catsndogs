## Celestial Codex — orchestrator for the 3-layer map overlay
## (Galaxy / Region / Local). Heavy drawing lives in focused components under
## `scripts/ui/star_map/*_layer.gd`; GameSession access routes through
## `StarMapViewModel`. Sprint 5a decomposition.
extends Control

enum Layer { GALAXY, REGION, LOCAL }

@onready var close_btn: Button = $Panel/VBox/CloseBtn
@onready var title_label: Label = $Panel/VBox/Title
@onready var map_canvas: Control = $Panel/VBox/MapCanvas

# Screen state
var _vm: StarMapViewModel
var _layer: Layer = Layer.GALAXY
var _region_id: String = ""
var _bounds: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _selected_region: String = ""

# Procedural backdrops (cached across frames; regenerated on layer change)
var _galaxy_backdrop: ImageTexture = null
var _region_backdrop: ImageTexture = null
var _region_backdrop_id: String = ""

# Layer components
var _galaxy_layer: StarMapGalaxyLayer
var _region_layer: StarMapRegionLayer
var _local_layer: StarMapLocalLayer

# Travel confirmation
var _travel_confirm_visible: bool = false
var _travel_target_region: String = ""

const REDRAW_INTERVAL: float = 0.5
var _redraw_timer: float = 0.0

const WORLD_SCENE_MAP := {
	"starting_realm": "res://scenes/world/fringe_haven_outpost.tscn",
	"tavern": "res://scenes/world/tavern.tscn",
}


## Inject a pre-built view model. `main.gd` / tests can call this before
## `_ready` runs; otherwise the screen falls back to the `GameSession`
## autoload to stay compatible with the existing scene-switch flow.
func initialize(vm: StarMapViewModel) -> void:
	_vm = vm
	_build_layers()


func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	map_canvas.draw.connect(_on_map_canvas_draw)
	close_btn.grab_focus()
	if _vm == null:
		_vm = StarMapViewModel.new(GameSession)
		_build_layers()
	_load_map_data()


func _build_layers() -> void:
	_galaxy_layer = StarMapGalaxyLayer.new(_vm)
	_region_layer = StarMapRegionLayer.new(_vm)
	_local_layer = StarMapLocalLayer.new(_vm)


func _process(dt: float) -> void:
	_elapsed += dt
	_redraw_timer -= dt
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		map_canvas.queue_redraw()


func _load_map_data() -> void:
	if not _vm.has_state():
		return
	_region_id = _vm.current_region()
	if not _vm.has_star_map():
		return
	_bounds = _vm.region_bounds(_region_id)
	_selected_region = _region_id
	_update_title()


func _update_title() -> void:
	match _layer:
		Layer.GALAXY:
			title_label.text = "CELESTIAL CODEX"
		Layer.REGION:
			var region_name: String = _selected_region.replace("_", " ").capitalize()
			title_label.text = "CELESTIAL CODEX — %s" % region_name.to_upper()
		Layer.LOCAL:
			title_label.text = "CELESTIAL CODEX — LOCAL SCAN"


# ---------------------------------------------------------------------------
# Draw dispatcher
# ---------------------------------------------------------------------------

func _on_map_canvas_draw() -> void:
	if not _vm.has_state():
		return
	match _layer:
		Layer.GALAXY:
			_refresh_galaxy_backdrop()
			_galaxy_layer.draw(map_canvas, _galaxy_ctx())
		Layer.REGION:
			_refresh_region_backdrop()
			_region_layer.draw(map_canvas, _region_ctx())
		Layer.LOCAL:
			_local_layer.draw(map_canvas, _local_ctx())


func _refresh_galaxy_backdrop() -> void:
	if _galaxy_backdrop != null:
		return
	var canvas_size: Vector2 = map_canvas.size
	# Third-resolution backdrop — integer division is intentional (Vector2i)
	var backdrop_size := Vector2i(int(canvas_size.x / 3.0), int(canvas_size.y / 3.0))
	_galaxy_backdrop = ProceduralMapManager.generate_codex_texture(
		7777,
		backdrop_size,
		3.0,
		Vector2.ZERO,
	)


func _refresh_region_backdrop() -> void:
	var view_region: String = _selected_region if not _selected_region.is_empty() else _region_id
	if _region_backdrop != null and _region_backdrop_id == view_region:
		return
	var canvas_size: Vector2 = map_canvas.size
	var map_radius: float = (minf(canvas_size.x, canvas_size.y) - 40.0) * 0.5
	var region_seed: int = ProceduralMapManager.REGION_SEEDS.get(view_region, hash(view_region))
	_region_backdrop = ProceduralMapManager.generate_codex_texture(
		region_seed,
		Vector2i(int(map_radius * 0.5), int(map_radius * 0.5)),
		6.0,
		Vector2.ZERO,
	)
	_region_backdrop_id = view_region


func _galaxy_ctx() -> Dictionary:
	return {
		"elapsed": _elapsed,
		"selected_region": _selected_region,
		"backdrop": _galaxy_backdrop,
		"travel_confirm_visible": _travel_confirm_visible,
		"travel_target_region": _travel_target_region,
	}


func _region_ctx() -> Dictionary:
	return {
		"elapsed": _elapsed,
		"selected_region": _selected_region,
		"current_region": _region_id,
		"backdrop": _region_backdrop,
		"nav_pois": _nav_pois(),
	}


func _local_ctx() -> Dictionary:
	return {
		"elapsed": _elapsed,
		"current_region": _region_id,
		"nav_pois": _nav_pois(),
	}


## Navigation controller stores `_active_pois` as a screen-local cache. Pull
## them opportunistically when the navigation screen is live under our main
## scene, else return an empty list.
func _nav_pois() -> Array:
	var nav: Control = _find_navigation_controller()
	if nav != null and "_active_pois" in nav:
		return nav._active_pois
	return []


func _find_navigation_controller() -> Control:
	var scene_container: Node = get_tree().current_scene.get_node_or_null("SceneContainer")
	if scene_container == null:
		return null
	for child in scene_container.get_children():
		if child is Control and child.has_method("_refresh_pois"):
			return child
	return null


# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	match _layer:
		Layer.GALAXY:
			_handle_galaxy_input(event)
		Layer.REGION:
			_handle_region_input(event)
		Layer.LOCAL:
			_handle_local_input(event)


func _handle_galaxy_input(event: InputEvent) -> void:
	if _travel_confirm_visible:
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_confirm_travel()
		elif event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			_cancel_travel()
		return

	if event.is_action_pressed("star_map"):
		get_viewport().set_input_as_handled()
		_on_close()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_close()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_drill_to_region()
	elif event.is_action_pressed("fire"):
		get_viewport().set_input_as_handled()
		_request_travel()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_move_galaxy_selection(Vector2.LEFT)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_move_galaxy_selection(Vector2.RIGHT)
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_move_galaxy_selection(Vector2.UP)
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_move_galaxy_selection(Vector2.DOWN)


func _handle_region_input(event: InputEvent) -> void:
	if event.is_action_pressed("star_map"):
		get_viewport().set_input_as_handled()
		_on_close()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_zoom_to_galaxy()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _selected_region == _region_id:
			_zoom_to_local()


func _handle_local_input(event: InputEvent) -> void:
	if event.is_action_pressed("star_map"):
		get_viewport().set_input_as_handled()
		_on_close()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_zoom_to_region()


# ---------------------------------------------------------------------------
# Layer transitions
# ---------------------------------------------------------------------------

func _drill_to_region() -> void:
	if _selected_region.is_empty():
		return
	if not _vm.region_is_discovered(_selected_region):
		return
	_layer = Layer.REGION
	_region_backdrop = null  # force regeneration on first draw
	_update_title()
	EventBus.codex_layer_changed.emit("region")


func _zoom_to_galaxy() -> void:
	_layer = Layer.GALAXY
	_update_title()
	EventBus.codex_layer_changed.emit("galaxy")


func _zoom_to_local() -> void:
	_layer = Layer.LOCAL
	_update_title()
	EventBus.codex_layer_changed.emit("local")


func _zoom_to_region() -> void:
	_layer = Layer.REGION
	_selected_region = _region_id
	_region_backdrop = null
	_update_title()
	EventBus.codex_layer_changed.emit("region")


# ---------------------------------------------------------------------------
# Galaxy navigation
# ---------------------------------------------------------------------------

func _move_galaxy_selection(direction: Vector2) -> void:
	var nodes: Dictionary = _vm.galaxy_nodes()
	if nodes.is_empty():
		return

	var current_pos: Vector2 = _vm.galaxy_node_pos(_selected_region)

	var best_id: String = ""
	var best_score: float = -1.0
	for region_id in nodes:
		if region_id == _selected_region:
			continue
		var candidate_pos: Vector2 = _vm.galaxy_node_pos(region_id)
		var delta: Vector2 = candidate_pos - current_pos
		if delta.length() < 0.01:
			continue
		var dot: float = delta.normalized().dot(direction)
		if dot <= 0.1:
			continue
		var score: float = dot / delta.length()
		if score > best_score:
			best_score = score
			best_id = region_id

	if not best_id.is_empty():
		_selected_region = best_id


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()


# ---------------------------------------------------------------------------
# Travel to world scene
# ---------------------------------------------------------------------------

func _request_travel() -> void:
	if _selected_region.is_empty():
		return
	if _selected_region == _region_id:
		_travel_target_region = _selected_region
		_travel_confirm_visible = true
		return
	if not _vm.region_is_discovered(_selected_region):
		return
	_travel_target_region = _selected_region
	_travel_confirm_visible = true


func _confirm_travel() -> void:
	_travel_confirm_visible = false
	if _travel_target_region.is_empty():
		return

	if _travel_target_region != _region_id:
		var success: bool = _vm.travel_to_region(_travel_target_region)
		if not success:
			return
		_region_id = _travel_target_region

	var scene_path: String = WORLD_SCENE_MAP.get(_travel_target_region, "res://scenes/world/world.tscn")
	_vm.set_world_entry_region(_travel_target_region)
	_on_close()
	get_tree().call_deferred("change_scene_to_file", scene_path)


func _cancel_travel() -> void:
	_travel_confirm_visible = false
	_travel_target_region = ""
