## Combat UI — turn-based combat with steampunk visuals.
## Full visual overhaul matching Python ui/combat_ui.py CombatState.
extends Control

# ---------------------------------------------------------------------------
# Design-resolution anchors — use project viewport size for consistency
# (Issue #8: was 1024×576, should match project viewport 1280×720)
# ---------------------------------------------------------------------------
const DESIGN_W: float = float(Config.SCREEN_WIDTH)
const DESIGN_H: float = float(Config.SCREEN_HEIGHT)

# Porthole glass centres
const PORTHOLE_LEFT := Vector2(253, 176)
const PORTHOLE_RIGHT := Vector2(773, 176)

# Hull text: render from top edge of brass strip label row
const HULL_TEXT_Y := 268.0

# Health-bar slot centres (inside the brass strip below portholes)
const HEALTHBAR_LEFT := Vector2(253, 252)
const HEALTHBAR_RIGHT := Vector2(773, 252)
const BAR_W := 180.0
const BAR_H := 20.0

# Ship name title: label bottom aligned to this design Y
const TITLE_MIDBOTTOM_Y := 105.0

# Parchment combat-log region
const LOG_TOP := 298.0
const LOG_BOT := 343.0
const LOG_MARGIN_X := 75.0

# Action / compass area
const ACTION_Y := 460.0

# Ship display size (pixels in design resolution)
const SHIP_SIZE := Vector2(120, 96)
const NAME_FONT_BASE := 20
const HULL_FONT_BASE := 13

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
# Steampunk colour palette
# ---------------------------------------------------------------------------
const HIGHLIGHT_BRIGHT := Color(0.94, 0.82, 0.51)
const HEALTH_GREEN := Color(0.235, 0.706, 0.275)
const HEALTH_RED := Color(0.745, 0.196, 0.137)
const HEALTH_BG := Color(0.118, 0.098, 0.078)
const HEALTH_FRAME := Color(0.549, 0.451, 0.294)
const LASER_PLAYER_COLOR := Color(0.392, 0.784, 1.0)
const LASER_ENEMY_COLOR := Color(1.0, 0.314, 0.196)
const LASER_GLOW_COLOR := Color(0.784, 0.902, 1.0)
const RESULT_VICTORY_COLOR := Color(0.235, 0.627, 0.235)
const RESULT_DEFEAT_COLOR := Color(0.745, 0.196, 0.137)
const RESULT_FLED_COLOR := Color(0.471, 0.392, 0.306)

# ---------------------------------------------------------------------------
# Node references
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

# Animation state
var _player_shake_time: float = 0.0
var _enemy_shake_time: float = 0.0
var _time: float = 0.0

# Cached screen positions (computed in _layout)
var _bg_offset := Vector2.ZERO
var _bg_scale := 1.0
var _player_pos := Vector2.ZERO
var _enemy_pos := Vector2.ZERO
var _player_bar_rect := Rect2()
var _enemy_bar_rect := Rect2()


func _ready() -> void:
	log = CombatSystem.CombatLog.new()
	attack_btn.pressed.connect(_on_attack)
	flee_btn.pressed.connect(_on_flee)
	health_bar_layer.draw.connect(_on_health_bar_draw)
	attack_btn.grab_focus()
	result_label.visible = false
	continue_label.visible = false
	laser_beam.visible = false
	laser_glow.visible = false
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
# Layout — maps design coordinates to screen coordinates
# ---------------------------------------------------------------------------
func _layout() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	# Compute background mapping (KEEP_ASPECT_COVERED logic)
	_bg_scale = maxf(vp_size.x / DESIGN_W, vp_size.y / DESIGN_H)
	var bg_size := Vector2(DESIGN_W * _bg_scale, DESIGN_H * _bg_scale)
	_bg_offset = (vp_size - bg_size) / 2.0

	# Ship positions (porthole centres)
	_player_pos = _map(PORTHOLE_LEFT)
	_enemy_pos = _map(PORTHOLE_RIGHT)

	# Position ship sprites
	var ship_screen_size := Vector2(SHIP_SIZE.x * _bg_scale, SHIP_SIZE.y * _bg_scale)
	player_ship_tex.position = _player_pos - ship_screen_size / 2.0
	player_ship_tex.size = ship_screen_size
	enemy_ship_tex.position = _enemy_pos - ship_screen_size / 2.0
	enemy_ship_tex.size = ship_screen_size

	# Ship name labels — centered in top brass nameplates
	var title_bottom_y := _map_y(TITLE_MIDBOTTOM_Y)
	var name_label_w := 260.0 * _bg_scale
	var name_label_h := 36.0 * _bg_scale
	var name_font_size := maxi(NAME_FONT_BASE, int(round(NAME_FONT_BASE * _bg_scale)))
	player_name_label.position = Vector2(_player_pos.x - name_label_w / 2.0, title_bottom_y - name_label_h)
	player_name_label.size = Vector2(name_label_w, name_label_h)
	enemy_name_label.position = Vector2(_enemy_pos.x - name_label_w / 2.0, title_bottom_y - name_label_h)
	enemy_name_label.size = Vector2(name_label_w, name_label_h)
	player_name_label.add_theme_font_size_override("font_size", name_font_size)
	enemy_name_label.add_theme_font_size_override("font_size", name_font_size)

	# Health bars
	var bar_w := BAR_W * _bg_scale
	var bar_h := maxf(8.0, BAR_H * _bg_scale)
	var hb_left := _map(HEALTHBAR_LEFT)
	var hb_right := _map(HEALTHBAR_RIGHT)
	_player_bar_rect = Rect2(hb_left.x - bar_w / 2.0, hb_left.y - bar_h / 2.0, bar_w, bar_h)
	_enemy_bar_rect = Rect2(hb_right.x - bar_w / 2.0, hb_right.y - bar_h / 2.0, bar_w, bar_h)

	# Hull text labels — centered on upper line of brass strip
	var hull_y := _map_y(HULL_TEXT_Y)
	var hull_label_w := BAR_W * _bg_scale
	var hull_label_h := 24.0 * _bg_scale
	var hull_font_size := maxi(HULL_FONT_BASE, int(round(HULL_FONT_BASE * _bg_scale)))
	player_hull_label.position = Vector2(_player_pos.x - hull_label_w / 2.0, hull_y)
	player_hull_label.size = Vector2(hull_label_w, hull_label_h)
	enemy_hull_label.position = Vector2(_enemy_pos.x - hull_label_w / 2.0, hull_y)
	enemy_hull_label.size = Vector2(hull_label_w, hull_label_h)
	player_hull_label.add_theme_font_size_override("font_size", hull_font_size)
	enemy_hull_label.add_theme_font_size_override("font_size", hull_font_size)

	# Combat log — parchment strip
	var log_top := _map_y(LOG_TOP)
	var log_bot := _map_y(LOG_BOT)
	var log_margin := _map_x(LOG_MARGIN_X)
	combat_log_rtl.position = Vector2(log_margin, log_top)
	combat_log_rtl.size = Vector2(vp_size.x - log_margin * 2, log_bot - log_top)

	# Actions — compass area
	var action_y := _map_y(ACTION_Y)
	var action_w := 360.0 * _bg_scale
	actions.position = Vector2(vp_size.x / 2.0 - action_w / 2.0, action_y)
	actions.size = Vector2(action_w, 50)

	# Result label
	result_label.position = Vector2(vp_size.x / 2.0 - 200, action_y - 10)
	result_label.size = Vector2(400, 50)

	# Continue label
	continue_label.position = Vector2(vp_size.x / 2.0 - 200, action_y + 45)
	continue_label.size = Vector2(400, 30)


func _map(design_pos: Vector2) -> Vector2:
	return _bg_offset + design_pos * _bg_scale


func _map_x(dx: float) -> float:
	return _bg_offset.x + dx * _bg_scale


func _map_y(dy: float) -> float:
	return _bg_offset.y + dy * _bg_scale


# ---------------------------------------------------------------------------
# Ship sprite loading
# ---------------------------------------------------------------------------
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
# Combat logic
# ---------------------------------------------------------------------------
func _on_attack() -> void:
	if player_ship == null or enemy_ship == null or _phase != "player_turn":
		return
	_set_buttons_disabled(true)

	# Player attacks enemy
	var dodge := CombatSystem.dodge_chance(enemy_ship.speed)
	var hit := randf() >= dodge
	if not hit:
		log.add("%s dodges!" % enemy_ship.ship_name)
		EventBus.combat_miss.emit()
	else:
		var dmg := CombatSystem.calculate_damage(player_ship.firepower, enemy_ship.armour)
		enemy_ship.current_hull = maxi(0, enemy_ship.current_hull - dmg)
		log.add("You deal %d damage to %s!" % [dmg, enemy_ship.ship_name])
		EventBus.combat_hit.emit()

	# Fire laser beam from player to enemy
	_fire_laser("player", hit)

	# Check victory
	if enemy_ship.current_hull <= 0:
		log.add("%s destroyed!" % enemy_ship.ship_name)
		EventBus.combat_victory.emit()
		_show_result("victory")
		return

	# Transition to enemy turn after animation delay
	_phase = "animating"
	_anim_timer = 0.6
	_refresh_ui()


func _on_flee() -> void:
	if player_ship == null or enemy_ship == null or _phase != "player_turn":
		return
	_set_buttons_disabled(true)

	var base_chance := float(player_ship.speed) / maxf(1.0, float(player_ship.speed + enemy_ship.speed))
	var flee_chance := minf(0.95, base_chance + _flee_attempts * 0.15)
	_flee_attempts += 1

	if randf() < flee_chance:
		log.add("You escaped!")
		EventBus.combat_flee.emit()
		_show_result("flee")
		return

	# Failed to flee — enemy gets free attack
	log.add("Failed to flee!")
	_enemy_attack()
	if _phase != "result":
		_phase = "player_turn"
		_set_buttons_disabled(false)
		attack_btn.grab_focus()
	_refresh_ui()


func _enemy_attack() -> void:
	if player_ship == null or enemy_ship == null:
		return

	var dodge := CombatSystem.dodge_chance(player_ship.speed)
	var hit := randf() >= dodge
	if not hit:
		log.add("You dodge!")
		EventBus.combat_miss.emit()
	else:
		var dmg := CombatSystem.calculate_damage(enemy_ship.firepower, player_ship.armour)
		player_ship.current_hull = maxi(0, player_ship.current_hull - dmg)
		log.add("%s deals %d damage!" % [enemy_ship.ship_name, dmg])
		EventBus.combat_hit.emit()
		_player_shake_time = 0.3

	# Fire laser beam from enemy to player
	_fire_laser("enemy", hit)

	if player_ship.current_hull <= 0:
		log.add("Your ship is destroyed!")
		EventBus.combat_defeat.emit()
		_show_result("defeat")
		return


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
	# Apply combat results to game state
	if player_ship and GameSession.game_state:
		GameSession.game_state.player_ship.current_hull = player_ship.current_hull

	if _result == "victory" and GameSession.game_state:
		var crystal_loot := randi_range(3, 10)
		var salvage_loot := randi_range(5, 15)
		GameSession.game_state.crystal_inventory += crystal_loot
		GameSession.game_state.salvage += salvage_loot
		EventBus.crystal_pickup.emit(crystal_loot)

	# Return to previous screen
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()


# ---------------------------------------------------------------------------
# Laser beam animation
# ---------------------------------------------------------------------------
func _fire_laser(from: String, hit: bool) -> void:
	var start: Vector2
	var target: Vector2
	var color: Color

	if from == "player":
		start = _player_pos + Vector2(SHIP_SIZE.x * _bg_scale * 0.4, 0)
		target = _enemy_pos - Vector2(SHIP_SIZE.x * _bg_scale * 0.4, 0)
		color = LASER_PLAYER_COLOR
	else:
		start = _enemy_pos - Vector2(SHIP_SIZE.x * _bg_scale * 0.4, 0)
		target = _player_pos + Vector2(SHIP_SIZE.x * _bg_scale * 0.4, 0)
		color = LASER_ENEMY_COLOR

	laser_beam.default_color = color
	laser_glow.default_color = Color(color.r, color.g, color.b, 0.3)
	laser_beam.clear_points()
	laser_glow.clear_points()
	laser_beam.add_point(start)
	laser_beam.add_point(start)
	laser_glow.add_point(start)
	laser_glow.add_point(start)
	laser_beam.visible = true
	laser_glow.visible = true

	# Animate laser traveling to target
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			var tip := start.lerp(target, t)
			var tail_t := maxf(0.0, t - 0.4)
			var tail := start.lerp(target, tail_t)
			laser_beam.set_point_position(0, tail)
			laser_beam.set_point_position(1, tip)
			laser_glow.set_point_position(0, tail)
			laser_glow.set_point_position(1, tip),
		0.0, 1.0, 0.3
	)

	# On hit — shake the target ship
	if hit:
		tween.tween_callback(func() -> void:
			if from == "player":
				_enemy_shake_time = 0.3
			else:
				_player_shake_time = 0.3
		)

	# Fade out laser
	tween.tween_callback(func() -> void:
		laser_beam.visible = false
		laser_glow.visible = false
	)


# ---------------------------------------------------------------------------
# Per-frame update
# ---------------------------------------------------------------------------
func _process(dt: float) -> void:
	_time += dt

	# Shake timers
	_player_shake_time = maxf(0.0, _player_shake_time - dt)
	_enemy_shake_time = maxf(0.0, _enemy_shake_time - dt)

	# Apply shake offsets to ship sprite positions
	_apply_ship_shake()

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

	# Trigger redraw for custom-drawn elements (health bars)
	health_bar_layer.queue_redraw()


func _apply_ship_shake() -> void:
	var ship_screen_size := Vector2(SHIP_SIZE.x * _bg_scale, SHIP_SIZE.y * _bg_scale)
	var base_player := _player_pos - ship_screen_size / 2.0
	var base_enemy := _enemy_pos - ship_screen_size / 2.0

	if _player_shake_time > 0:
		var shake := Vector2(
			sin(_player_shake_time * 40.0) * 8.0,
			cos(_player_shake_time * 30.0) * 4.0
		)
		player_ship_tex.position = base_player + shake
	else:
		player_ship_tex.position = base_player

	if _enemy_shake_time > 0:
		var shake := Vector2(
			sin(_enemy_shake_time * 40.0) * 8.0,
			cos(_enemy_shake_time * 30.0) * 4.0
		)
		enemy_ship_tex.position = base_enemy + shake
	else:
		enemy_ship_tex.position = base_enemy


# ---------------------------------------------------------------------------
# Custom drawing — health bars with steampunk brass frame (drawn on HealthBarLayer)
# ---------------------------------------------------------------------------
func _on_health_bar_draw() -> void:
	if player_ship:
		_draw_health_bar(_player_bar_rect, player_ship)
	if enemy_ship:
		_draw_health_bar(_enemy_bar_rect, enemy_ship)


func _draw_health_bar(rect: Rect2, ship: CombatSystem.CombatShip) -> void:
	if rect.size.x <= 0:
		return
	var pct := float(ship.current_hull) / maxf(1.0, float(ship.max_hull))
	var fill_color := HEALTH_GREEN if pct > 0.5 else HEALTH_RED

	# Brass frame background
	var frame_rect := rect.grow(2)
	health_bar_layer.draw_rect(frame_rect, HEALTH_FRAME)
	# Dark background
	health_bar_layer.draw_rect(rect, HEALTH_BG)

	# Health fill
	var fill_w := maxf(0, rect.size.x * pct)
	if fill_w > 0:
		health_bar_layer.draw_rect(
			Rect2(rect.position, Vector2(fill_w, rect.size.y)), fill_color
		)

	# Segment lines
	var seg_step := maxf(20, rect.size.x / 8.0)
	var seg_x := rect.position.x + seg_step
	while seg_x < rect.position.x + rect.size.x:
		health_bar_layer.draw_line(
			Vector2(seg_x, rect.position.y),
			Vector2(seg_x, rect.position.y + rect.size.y),
			Color(0.078, 0.071, 0.055), 1.0
		)
		seg_x += seg_step

	# Frame outline
	health_bar_layer.draw_rect(frame_rect, HEALTH_FRAME, false, 2.0)


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
