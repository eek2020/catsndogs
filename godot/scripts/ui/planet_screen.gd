## Planet screen — top-down exploration mode for planetary surfaces.
##
## Handles 4-way player movement, NPC interaction, treasure collection,
## and merchant access on a planet surface.
extends Control

const PLAYER_SPEED: float = 200.0
const TILE_SIZE: int = 32
const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 15
const INTERACT_RADIUS: float = 40.0

## Spritesheet layout — frame dimensions derived from sheet size (1172×4192)
const SPRITE_COLS: int = 4        # max frames per row
const SPRITE_ROWS: int = 29       # total animation rows
const FRAME_W: int = 293          # 1172 / 4
const FRAME_H: int = 144          # 4192 / 29 ≈ 144 (16px padding at sheet bottom)
const SPRITE_DRAW_SIZE := Vector2(64.0, 64.0)  # on-screen display size
const ANIM_FPS: float = 8.0       # walk cycle speed

## Animation row indices — adjust these if the row order differs
enum AnimRow {
	WALK_DOWN = 0, WALK_UP = 1, WALK_LEFT = 2, WALK_RIGHT = 3,
	WALK_DL = 4, WALK_DR = 5, WALK_UL = 6, WALK_UR = 7,
	RUN_DOWN = 8, RUN_UP = 9, RUN_LEFT = 10, RUN_RIGHT = 11,
	RUN_DL = 12, RUN_DR = 13, RUN_UL = 14, RUN_UR = 15,
	IDLE_DOWN = 16, IDLE_UP = 17, IDLE_LEFT = 18, IDLE_RIGHT = 19,
	IDLE_DL = 20, IDLE_DR = 21, IDLE_UL = 22, IDLE_UR = 23,
	ATK_DOWN = 24, ATK_LEFT = 25, ATK_RIGHT = 26, ATK_DL = 27, ATK_DR = 28,
}

## Frame counts per row (most rows have 4; override exceptions here)
const FRAME_COUNTS: Dictionary = {}  # row_index -> count; default is 4

## Direction → walk row lookup (keyed by rounded angle octant 0-7)
const DIR_TO_WALK_ROW: Array = [
	AnimRow.WALK_RIGHT,      # 0  — east
	AnimRow.WALK_DR,         # 1  — south-east
	AnimRow.WALK_DOWN,       # 2  — south
	AnimRow.WALK_DL,         # 3  — south-west
	AnimRow.WALK_LEFT,       # 4  — west
	AnimRow.WALK_UL,         # 5  — north-west
	AnimRow.WALK_UP,         # 6  — north
	AnimRow.WALK_UR,         # 7  — north-east
]

## Direction → idle row lookup (same octant order)
const DIR_TO_IDLE_ROW: Array = [
	AnimRow.IDLE_RIGHT, AnimRow.IDLE_DR, AnimRow.IDLE_DOWN, AnimRow.IDLE_DL,
	AnimRow.IDLE_LEFT, AnimRow.IDLE_UL, AnimRow.IDLE_UP, AnimRow.IDLE_UR,
]

@onready var title_label: Label = $HUD/TopBar/TitleLabel
@onready var loot_label: Label = $HUD/TopBar/LootLabel
@onready var flash_label: Label = $HUD/FlashLabel
@onready var depart_btn: Button = $HUD/DepartBtn

var _sprite_texture: Texture2D = null
var _planet: Planet = null
var _planet_state: Dictionary = {}
var _player_pos := Vector2(320.0, 360.0)
var _flash_timer: float = 0.0
var _elapsed: float = 0.0
var _anim_row: int = AnimRow.IDLE_DOWN
var _anim_frame: int = 0
var _anim_timer: float = 0.0
var _facing_octant: int = 2  # default facing south
var _is_moving: bool = false
var _merchants: Array = []
var _treasures: Array = []
var _treasure_positions: Dictionary = {}  # treasure_id -> Vector2
var _merchant_positions: Dictionary = {}  # merchant_id -> Vector2


func _ready() -> void:
	depart_btn.pressed.connect(_on_depart)
	var gs: GameStateData = GameSession.game_state
	var pid: String = gs.protagonist_id if gs else "aristotle"
	var sprite_path := "res://assets/sprites/%s_spritesheet.png" % pid
	_sprite_texture = load(sprite_path) if ResourceLoader.exists(sprite_path) else load("res://assets/sprites/aristotle_spritesheet.png")
	if gs == null or gs.current_planet_id.is_empty():
		return

	_planet = GameSession.planet_system.get_planet(gs.current_planet_id)
	if _planet == null:
		return
	_planet_state = GameSession.planet_system.get_planet_state(gs, _planet.planet_id)

	title_label.text = _planet.planet_name.to_upper()
	_merchants = _planet.merchants.duplicate(true)
	_treasures = _planet.treasures.duplicate(true)

	# Place merchants and treasures at spread positions
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_planet.planet_id)
	for m in _merchants:
		var mid: String = m.get("merchant_id", "")
		_merchant_positions[mid] = Vector2(
			rng.randf_range(100, MAP_WIDTH * TILE_SIZE - 100),
			rng.randf_range(100, MAP_HEIGHT * TILE_SIZE - 100),
		)
	for t in _treasures:
		var tid: String = t.get("treasure_id", "")
		_treasure_positions[tid] = Vector2(
			rng.randf_range(80, MAP_WIDTH * TILE_SIZE - 80),
			rng.randf_range(80, MAP_HEIGHT * TILE_SIZE - 80),
		)

	# Start player at center
	_player_pos = Vector2(MAP_WIDTH * TILE_SIZE * 0.5, MAP_HEIGHT * TILE_SIZE * 0.5)

	_update_loot_label()
	MusicManager.on_state_change("trade")

	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _process(dt: float) -> void:
	_elapsed += dt
	_handle_movement(dt)
	_update_flash(dt)
	queue_redraw()


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

	_is_moving = direction != Vector2.ZERO
	if _is_moving:
		direction = direction.normalized()
		_player_pos += direction * PLAYER_SPEED * dt
		_player_pos.x = clampf(_player_pos.x, 16.0, MAP_WIDTH * TILE_SIZE - 16.0)
		_player_pos.y = clampf(_player_pos.y, 16.0, MAP_HEIGHT * TILE_SIZE - 16.0)
		# Convert direction vector to octant (0=E, 1=SE, 2=S, … 7=NE)
		var angle: float = direction.angle()  # radians, 0=right, positive=clockwise in screen coords
		_facing_octant = int(round(angle / (TAU / 8.0))) % 8
		if _facing_octant < 0:
			_facing_octant += 8
		_anim_row = DIR_TO_WALK_ROW[_facing_octant]
	else:
		_anim_row = DIR_TO_IDLE_ROW[_facing_octant]

	# Advance animation frame
	_anim_timer += dt
	var spf: float = 1.0 / ANIM_FPS
	if _anim_timer >= spf:
		_anim_timer -= spf
		var max_frames: int = FRAME_COUNTS.get(_anim_row, 4)
		if _is_moving:
			_anim_frame = (_anim_frame + 1) % max_frames
		else:
			_anim_frame = 0  # idle frame


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("pause"):
		_on_depart()


func _try_interact() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null or _planet == null:
		return

	# Check treasure proximity
	for t in _treasures:
		var tid: String = t.get("treasure_id", "")
		var tpos: Vector2 = _treasure_positions.get(tid, Vector2.ZERO)
		if _player_pos.distance_to(tpos) <= INTERACT_RADIUS:
			if not GameSession.planet_system.is_treasure_cleared(gs, _planet.planet_id, tid):
				var reward: Dictionary = GameSession.planet_system.collect_treasure(gs, _planet.planet_id, tid)
				if not reward.is_empty():
					flash("Found: %s (+%dC +%dS)" % [
						reward.get("name", "Treasure"),
						reward.get("reward_crystals", 0),
						reward.get("reward_salvage", 0),
					], 3.0)
					_update_loot_label()
				return

	# Check merchant proximity
	for m in _merchants:
		var mid: String = m.get("merchant_id", "")
		var mpos: Vector2 = _merchant_positions.get(mid, Vector2.ZERO)
		if _player_pos.distance_to(mpos) <= INTERACT_RADIUS:
			_open_merchant(m)
			return

	flash("Nothing to interact with here.", 1.5)


func _open_merchant(merchant_data: Dictionary) -> void:
	var faction_id: String = merchant_data.get("faction_id", "")
	GameSession.open_trade_screen(faction_id)
	var main: Control = get_tree().current_scene
	if main.has_method("push_overlay"):
		main.push_overlay("trade")


func _on_depart() -> void:
	GameSession.planet_system.depart(GameSession.game_state)
	MusicManager.on_state_change("navigation")
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("navigation")


func _update_loot_label() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return
	var inv: Dictionary = gs.planet_inventory
	loot_label.text = "Loot: %dC %dS" % [inv.get("crystals", 0), inv.get("salvage", 0)]


func flash(message: String, duration: float = 3.0) -> void:
	flash_label.text = message
	_flash_timer = duration


func _update_flash(dt: float) -> void:
	if _flash_timer > 0:
		_flash_timer -= dt
		flash_label.visible = true
		if _flash_timer <= 1.0:
			flash_label.modulate.a = _flash_timer
		else:
			flash_label.modulate.a = 1.0
	else:
		flash_label.visible = false


func _draw() -> void:
	if _planet == null:
		return

	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return

	_draw_ground()
	_draw_treasures(gs)
	_draw_merchants()
	_draw_player()
	_draw_proximity_prompts(gs)


func _draw_ground() -> void:
	# Simple tiled ground
	var biome_data: Dictionary = GameSession.planet_system.get_biome(_planet.biome)
	var ambient_hex: String = biome_data.get("ambient_color", "#554433")
	var ground_color := Color(ambient_hex)
	var grid_color := ground_color.lightened(0.1)
	draw_rect(Rect2(0, 0, MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE), ground_color)
	# Grid lines
	for x in range(MAP_WIDTH + 1):
		draw_line(Vector2(x * TILE_SIZE, 0), Vector2(x * TILE_SIZE, MAP_HEIGHT * TILE_SIZE), grid_color, 1.0)
	for y in range(MAP_HEIGHT + 1):
		draw_line(Vector2(0, y * TILE_SIZE), Vector2(MAP_WIDTH * TILE_SIZE, y * TILE_SIZE), grid_color, 1.0)


func _draw_treasures(gs: GameStateData) -> void:
	var default_font: Font = ThemeDB.fallback_font
	for t in _treasures:
		var tid: String = t.get("treasure_id", "")
		var tpos: Vector2 = _treasure_positions.get(tid, Vector2.ZERO)
		var cleared: bool = GameSession.planet_system.is_treasure_cleared(gs, _planet.planet_id, tid)
		if cleared:
			# Greyed out
			draw_circle(tpos, 10.0, Color(0.4, 0.4, 0.4, 0.3))
		else:
			# Golden pulsing treasure
			var pulse: float = 1.0 + 0.2 * sin(_elapsed * 3.0)
			draw_circle(tpos, 12.0 * pulse, Color(1.0, 0.82, 0.25, 0.3))
			draw_circle(tpos, 6.0, Color(1.0, 0.82, 0.25))
			if default_font != null:
				draw_string(default_font, tpos + Vector2(-20, -14), t.get("name", "Treasure"), HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color(1.0, 0.9, 0.5))


func _draw_merchants() -> void:
	var default_font: Font = ThemeDB.fallback_font
	for m in _merchants:
		var mid: String = m.get("merchant_id", "")
		var mpos: Vector2 = _merchant_positions.get(mid, Vector2.ZERO)
		# Blue merchant marker
		draw_circle(mpos, 10.0, Color(0.3, 0.6, 1.0, 0.3))
		draw_circle(mpos, 5.0, Color(0.4, 0.7, 1.0))
		if default_font != null:
			draw_string(default_font, mpos + Vector2(-20, -14), m.get("name", "Merchant"), HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color(0.6, 0.85, 1.0))


func _draw_player() -> void:
	if _sprite_texture == null:
		# Fallback to placeholder if texture failed to load
		draw_circle(_player_pos, 10.0, Color(0.2, 0.8, 0.3, 0.3))
		draw_circle(_player_pos, 5.0, Color(0.3, 0.9, 0.4))
		return

	# Source rectangle on the spritesheet
	var src := Rect2(
		_anim_frame * FRAME_W,
		_anim_row * FRAME_H,
		FRAME_W,
		FRAME_H,
	)
	# Destination rectangle centered on player position
	var dst := Rect2(
		_player_pos - SPRITE_DRAW_SIZE * 0.5,
		SPRITE_DRAW_SIZE,
	)
	draw_texture_rect_region(_sprite_texture, dst, src)


func _draw_proximity_prompts(gs: GameStateData) -> void:
	var default_font: Font = ThemeDB.fallback_font
	if default_font == null:
		return
	# Check treasure proximity
	for t in _treasures:
		var tid: String = t.get("treasure_id", "")
		var tpos: Vector2 = _treasure_positions.get(tid, Vector2.ZERO)
		if _player_pos.distance_to(tpos) <= INTERACT_RADIUS:
			if not GameSession.planet_system.is_treasure_cleared(gs, _planet.planet_id, tid):
				draw_string(default_font, tpos + Vector2(-20, 20), "[E] Collect", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(1.0, 1.0, 0.6))
	# Check merchant proximity
	for m in _merchants:
		var mid: String = m.get("merchant_id", "")
		var mpos: Vector2 = _merchant_positions.get(mid, Vector2.ZERO)
		if _player_pos.distance_to(mpos) <= INTERACT_RADIUS:
			draw_string(default_font, mpos + Vector2(-20, 20), "[E] Trade", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.6, 0.9, 1.0))
