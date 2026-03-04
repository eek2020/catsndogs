## Navigation screen — main gameplay view with ship movement and HUD.
## Mirrors Python ui/navigation.py NavigationState.
extends Control

@onready var arc_label: Label = $HUD/TopBar/ArcLabel
@onready var region_label: Label = $HUD/TopBar/RegionLabel
@onready var crystals_label: Label = $HUD/TopBar/CrystalsLabel
@onready var salvage_label: Label = $HUD/TopBar/SalvageLabel
@onready var hull_label: Label = $HUD/TopBar/HullLabel
@onready var flash_label: Label = $HUD/FlashLabel

var _flash_timer: float = 0.0
var _encounter_cooldown: float = 0.0

const ENCOUNTER_CHECK_INTERVAL: float = 5.0
const SHIP_SPEED: float = 200.0


func _ready() -> void:
	flash_label.text = ""
	_update_hud()


func _process(dt: float) -> void:
	if GameSession.game_state == null:
		return
	_handle_movement(dt)
	_update_encounter_timer(dt)
	_update_flash(dt)
	_update_hud()


func _handle_movement(dt: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		GameSession.game_state.position_x += direction.x * SHIP_SPEED * dt
		GameSession.game_state.position_y += direction.y * SHIP_SPEED * dt


func _update_encounter_timer(dt: float) -> void:
	_encounter_cooldown -= dt
	if _encounter_cooldown <= 0:
		_encounter_cooldown = ENCOUNTER_CHECK_INTERVAL
		var encounter = GameSession.encounter_engine.check_triggers(GameSession.game_state)
		if encounter:
			_on_encounter(encounter)


func _on_encounter(encounter) -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("push_overlay"):
		main.push_overlay("dialogue")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var main: Control = get_tree().current_scene
		if main.has_method("push_overlay"):
			main.push_overlay("pause")
	elif event.is_action_pressed("interact"):
		var main: Control = get_tree().current_scene
		if main.has_method("push_overlay"):
			main.push_overlay("faction")
	elif event.is_action_pressed("fire"):
		var main: Control = get_tree().current_scene
		if main.has_method("push_overlay"):
			main.push_overlay("ship")
	elif event.is_action_pressed("mission_log"):
		var main: Control = get_tree().current_scene
		if main.has_method("push_overlay"):
			main.push_overlay("mission_log")


func _update_hud() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return
	arc_label.text = gs.current_arc.to_upper()
	region_label.text = gs.current_region.replace("_", " ").capitalize()
	crystals_label.text = "Crystals: %d" % gs.crystal_inventory
	salvage_label.text = "Salvage: %d" % gs.salvage
	if gs.player_ship:
		hull_label.text = "Hull: %d/%d" % [gs.player_ship.current_hull, gs.player_ship.max_hull]


func flash(message: String, duration: float = 3.0) -> void:
	flash_label.text = message
	_flash_timer = duration


func _update_flash(dt: float) -> void:
	if _flash_timer > 0:
		_flash_timer -= dt
		if _flash_timer <= 0:
			flash_label.text = ""


func on_return_from_encounter() -> void:
	_encounter_cooldown = ENCOUNTER_CHECK_INTERVAL
	_update_hud()
