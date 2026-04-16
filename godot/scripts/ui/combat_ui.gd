## Combat UI — turn-based combat with steampunk visuals.
##
## Orchestrator for the decomposed combat screen (Sprint 3b). Layout math
## lives in CombatLayout; turn resolution in CombatLogic; laser and shake
## effects in CombatAnimations; health bar rendering in CombatHealthBar;
## GameSession access in CombatViewModel.
##
## The scene file still points here (`res://scripts/ui/combat_ui.gd`) — this
## script only wires nodes to the extracted components.
extends Control

# ---------------------------------------------------------------------------
# Design resolution (project viewport 1280×720, see Issue #8 & Config)
# ---------------------------------------------------------------------------
const DESIGN_W: float = float(Config.SCREEN_WIDTH)
const DESIGN_H: float = float(Config.SCREEN_HEIGHT)

# ---------------------------------------------------------------------------
# Ship sprite mapping (template_id → asset path)
# ---------------------------------------------------------------------------
const SHIP_SPRITES := {
	"corsair_raider": "res://assets/ships/ship_r_side.png",
	"corsair_smuggler": "res://assets/ships/ship_r_side.png",
	"corsair_interceptor": "res://assets/ships/ship_r_side.png",
	"league_cruiser": "res://assets/ships/league_cruiser.png",
	"league_destroyer": "res://assets/ships/league_destroyer.jpg",
	"royal_galleon": "res://assets/ships/royal_galleon.jpg",
	"wolf_strike_craft": "res://assets/ships/wolf_ship.png",
	"alien_vessel": "res://assets/ships/alien_vessel.png",
	"fairy_ship": "res://assets/ships/fairy_ship.png",
	"goblin_scrapper": "res://assets/ships/goblin_scrapper.png",
	"knight_ship": "res://assets/ships/knight_ship.png",
}

# ---------------------------------------------------------------------------
# Result overlay colours
# ---------------------------------------------------------------------------
const HIGHLIGHT_BRIGHT := Color(0.94, 0.82, 0.51)
const RESULT_VICTORY_COLOR := Color(0.235, 0.627, 0.235)
const RESULT_DEFEAT_COLOR := Color(0.745, 0.196, 0.137)
const RESULT_FLED_COLOR := Color(0.471, 0.392, 0.306)

# ---------------------------------------------------------------------------
# Scene node references
# ---------------------------------------------------------------------------
@onready var bg: TextureRect = $Background
@onready var player_ship_tex: TextureRect = $PlayerShip
@onready var enemy_ship_tex: TextureRect = $EnemyShip
@onready var player_name_label: Label = $PlayerName
@onready var enemy_name_label: Label = $EnemyName
@onready var player_hull_label: Label = $PlayerHull
@onready var enemy_hull_label: Label = $EnemyHull
@onready var combat_log_rtl: RichTextLabel = $CombatLog
@onready var actions: HBoxContainer = $Actions
@onready var attack_btn: Button = $Actions/AttackBtn
@onready var flee_btn: Button = $Actions/FleeBtn
@onready var result_label: Label = $ResultLabel
@onready var continue_label: Label = $ContinueLabel
@onready var laser_beam: Line2D = $LaserBeam
@onready var laser_glow: Line2D = $LaserGlow
@onready var health_bar_layer: Control = $HealthBarLayer

# ---------------------------------------------------------------------------
# Combat state
# ---------------------------------------------------------------------------
var player_ship: CombatSystem.CombatShip = null
var enemy_ship: CombatSystem.CombatShip = null
var log: CombatSystem.CombatLog = null
var _phase: String = "player_turn"  # player_turn, animating, enemy_turn, result
var _result: String = ""
var _anim_timer: float = 0.0
var _flee_attempts: int = 0
var _time: float = 0.0

# Extracted components (Sprint 3b)
var _vm: CombatViewModel = null
var _animations: CombatAnimations = null
var _layout_frame: Dictionary = {}


## Inject a CombatViewModel before _ready (used by tests). Production path
## falls back to wrapping the GameSession autoload in _ready.
func initialize(vm: CombatViewModel) -> void:
	_vm = vm


func _ready() -> void:
	if _vm == null:
		_vm = CombatViewModel.new(GameSession)

	_animations = CombatAnimations.new()
	_animations.name = "CombatAnimations"
	add_child(_animations)
	_animations.bind(laser_beam, laser_glow, player_ship_tex, enemy_ship_tex)

	log = CombatSystem.CombatLog.new()
	attack_btn.pressed.connect(_on_attack)
	flee_btn.pressed.connect(_on_flee)
	health_bar_layer.draw.connect(_on_health_bar_draw)
	attack_btn.grab_focus()
	result_label.visible = false
	continue_label.visible = false
	_layout()
	_refresh_ui()


func setup(p_player: CombatSystem.CombatShip, p_enemy: CombatSystem.CombatShip) -> void:
	player_ship = p_player
	enemy_ship = p_enemy
	log = CombatSystem.CombatLog.new()
	log.add("Combat! %s vs %s" % [p_player.ship_name, p_enemy.ship_name])
	log.add("Choose your action.")
	_phase = "player_turn"
	_result = ""
	_flee_attempts = 0
	_load_ship_sprites()
	_layout()
	_refresh_ui()


# ---------------------------------------------------------------------------
# Layout — delegates geometry to CombatLayout and applies the frame to nodes
# ---------------------------------------------------------------------------
func _layout() -> void:
	var vp_size := get_viewport_rect().size
	_layout_frame = CombatLayout.compute(vp_size, DESIGN_W, DESIGN_H)
	if _layout_frame.is_empty():
		return

	player_ship_tex.position = _layout_frame["player_ship_pos"]
	player_ship_tex.size = _layout_frame["ship_screen_size"]
	enemy_ship_tex.position = _layout_frame["enemy_ship_pos"]
	enemy_ship_tex.size = _layout_frame["ship_screen_size"]

	player_name_label.position = _layout_frame["player_name_pos"]
	player_name_label.size = _layout_frame["name_label_size"]
	enemy_name_label.position = _layout_frame["enemy_name_pos"]
	enemy_name_label.size = _layout_frame["name_label_size"]
	player_name_label.add_theme_font_size_override("font_size", _layout_frame["name_font_size"])
	enemy_name_label.add_theme_font_size_override("font_size", _layout_frame["name_font_size"])

	player_hull_label.position = _layout_frame["player_hull_pos"]
	player_hull_label.size = _layout_frame["hull_label_size"]
	enemy_hull_label.position = _layout_frame["enemy_hull_pos"]
	enemy_hull_label.size = _layout_frame["hull_label_size"]
	player_hull_label.add_theme_font_size_override("font_size", _layout_frame["hull_font_size"])
	enemy_hull_label.add_theme_font_size_override("font_size", _layout_frame["hull_font_size"])

	combat_log_rtl.position = _layout_frame["log_pos"]
	combat_log_rtl.size = _layout_frame["log_size"]

	actions.position = _layout_frame["actions_pos"]
	actions.size = _layout_frame["actions_size"]
	result_label.position = _layout_frame["result_pos"]
	result_label.size = _layout_frame["result_size"]
	continue_label.position = _layout_frame["continue_pos"]
	continue_label.size = _layout_frame["continue_size"]

	if _animations != null:
		_animations.set_base_positions(
			_layout_frame["player_ship_pos"],
			_layout_frame["enemy_ship_pos"],
		)


func _load_ship_sprites() -> void:
	if player_ship:
		var player_path: String = SHIP_SPRITES.get(
			player_ship.ship_template_id, "res://assets/ships/ship_r_side.png"
		)
		if ResourceLoader.exists(player_path):
			player_ship_tex.texture = load(player_path)

	if enemy_ship:
		var enemy_path: String = SHIP_SPRITES.get(enemy_ship.ship_template_id, "")
		if not enemy_path.is_empty() and ResourceLoader.exists(enemy_path):
			enemy_ship_tex.texture = load(enemy_path)


# ---------------------------------------------------------------------------
# Input (for continue prompt in result phase)
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if _phase == "result" and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_finish()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Turn routing — resolves via CombatLogic, applies results + animations
# ---------------------------------------------------------------------------
func _on_attack() -> void:
	if player_ship == null or enemy_ship == null or _phase != "player_turn":
		return
	_set_buttons_disabled(true)

	var result := CombatLogic.resolve_player_attack(player_ship, enemy_ship)
	_apply_log_and_events(result)
	_fire_laser("player", result["hit"])

	if result["target_dead"]:
		_show_result("victory")
		return

	_phase = "animating"
	_anim_timer = 0.6
	_refresh_ui()


func _on_flee() -> void:
	if player_ship == null or enemy_ship == null or _phase != "player_turn":
		return
	_set_buttons_disabled(true)

	var result := CombatLogic.resolve_flee(player_ship, enemy_ship, _flee_attempts)
	_flee_attempts = result["new_attempts"]
	_apply_log_and_events(result)

	if result["success"]:
		_show_result("flee")
		return

	# Failed to flee — enemy gets a free attack
	_enemy_attack()
	if _phase != "result":
		_phase = "player_turn"
		_set_buttons_disabled(false)
		attack_btn.grab_focus()
	_refresh_ui()


func _enemy_attack() -> void:
	if player_ship == null or enemy_ship == null:
		return

	var result := CombatLogic.resolve_enemy_attack(player_ship, enemy_ship)
	_apply_log_and_events(result)

	# Legacy parity: shake player synchronously on hit, before the laser travels.
	# The laser tween also triggers shake on arrival (see CombatAnimations).
	if result["hit"]:
		_animations.trigger_shake("player")

	_fire_laser("enemy", result["hit"])

	if result["target_dead"]:
		_show_result("defeat")


func _apply_log_and_events(result: Dictionary) -> void:
	for msg in result.get("log_messages", []):
		log.add(msg)
	for sig in result.get("event_signals", []):
		EventBus.emit_signal(sig)


func _fire_laser(from: String, hit: bool) -> void:
	if _layout_frame.is_empty() or _animations == null:
		return
	var ship_size: Vector2 = _layout_frame["ship_screen_size"]
	var player_pos: Vector2 = _layout_frame["player_pos"]
	var enemy_pos: Vector2 = _layout_frame["enemy_pos"]
	var offset := Vector2(ship_size.x * 0.4, 0)
	var start: Vector2
	var target: Vector2
	if from == "player":
		start = player_pos + offset
		target = enemy_pos - offset
	else:
		start = enemy_pos - offset
		target = player_pos + offset
	_animations.fire_laser(from, start, target, hit)


func _show_result(result: String) -> void:
	_phase = "result"
	_result = result
	_set_buttons_disabled(true)
	actions.visible = false

	var text := ""
	var color := HIGHLIGHT_BRIGHT
	match result:
		"victory":
			text = "VICTORY!"
			color = RESULT_VICTORY_COLOR
		"defeat":
			text = "DEFEATED"
			color = RESULT_DEFEAT_COLOR
		"flee":
			text = "ESCAPED"
			color = RESULT_FLED_COLOR

	result_label.text = text
	result_label.add_theme_color_override("font_color", color)
	result_label.visible = true
	continue_label.visible = true
	_refresh_ui()


func _finish() -> void:
	if player_ship:
		_vm.sync_player_hull(player_ship.current_hull)

	if _result == "victory":
		var crystal_loot := randi_range(3, 10)
		var salvage_loot := randi_range(5, 15)
		_vm.apply_victory_loot(crystal_loot, salvage_loot)
		EventBus.crystal_pickup.emit(crystal_loot)

	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()


# ---------------------------------------------------------------------------
# Per-frame update
# ---------------------------------------------------------------------------
func _process(dt: float) -> void:
	_time += dt

	if _animations != null:
		_animations.tick(dt)

	# Animating phase timer (delay before enemy turn)
	if _phase == "animating":
		_anim_timer -= dt
		if _anim_timer <= 0:
			_phase = "enemy_turn"
			_enemy_attack()
			if _phase != "result":
				_phase = "player_turn"
				_set_buttons_disabled(false)
				attack_btn.grab_focus()
			_refresh_ui()

	# Pulsing continue label
	if continue_label.visible:
		var alpha := 0.5 + 0.5 * sin(_time * 5.0)
		continue_label.modulate.a = alpha

	health_bar_layer.queue_redraw()


# ---------------------------------------------------------------------------
# Health bar draw handler — delegates to CombatHealthBar
# ---------------------------------------------------------------------------
func _on_health_bar_draw() -> void:
	if _layout_frame.is_empty():
		return
	if player_ship:
		CombatHealthBar.draw(
			health_bar_layer,
			_layout_frame["player_bar_rect"],
			player_ship.current_hull,
			player_ship.max_hull,
		)
	if enemy_ship:
		CombatHealthBar.draw(
			health_bar_layer,
			_layout_frame["enemy_bar_rect"],
			enemy_ship.current_hull,
			enemy_ship.max_hull,
		)


# ---------------------------------------------------------------------------
# UI refresh
# ---------------------------------------------------------------------------
func _refresh_ui() -> void:
	if player_ship:
		player_hull_label.text = "HULL: %d/%d" % [player_ship.current_hull, player_ship.max_hull]
		player_name_label.text = player_ship.ship_name
	if enemy_ship:
		enemy_hull_label.text = "HULL: %d/%d" % [enemy_ship.current_hull, enemy_ship.max_hull]
		enemy_name_label.text = enemy_ship.ship_name
	_refresh_combat_log()


func _refresh_combat_log() -> void:
	if log == null:
		return
	combat_log_rtl.clear()
	for entry in log.entries:
		var color := "black"
		var lower := entry.to_lower()
		if "destroyed" in lower or "defeat" in lower or "damage" in lower:
			color = "#a01e14"
		elif "dodge" in lower or "escaped" in lower:
			color = "#1e4678"
		elif "victory" in lower:
			color = "#3ca03c"
		combat_log_rtl.append_text("[color=%s]> %s[/color]\n" % [color, entry])


func _set_buttons_disabled(disabled: bool) -> void:
	attack_btn.disabled = disabled
	flee_btn.disabled = disabled
