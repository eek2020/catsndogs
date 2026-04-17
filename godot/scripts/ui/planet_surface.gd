## Planet surface — tile-based exploration mode for planetary surfaces.
##
## Generates a procedural tilemap layout from planet data, places NPCs,
## merchants, and treasures as interactive entities. Player moves with
## arrow keys and interacts with E.
extends Control

const TILE_SIZE: int = 32
const MAP_W: int = 30        # map width in tiles
const MAP_H: int = 22        # map height in tiles
const PLAYER_SPEED: float = 120.0
const INTERACT_RADIUS: float = 28.0

## Spritesheet layout — clean uniform grid: 8 cols × N rows of 128×128 frames
const SPRITE_COLS: int = 8
const SPRITE_FRAME_SIZE: int = 128
const SPRITE_DRAW_SIZE := Vector2(28.0, 28.0)
const ANIM_FPS: float = 8.0

enum AnimRow {
	WALK_DOWN = 0, WALK_UP = 1, WALK_LEFT = 2, WALK_RIGHT = 3,
	WALK_DL = 4, WALK_DR = 5, WALK_UL = 6, WALK_UR = 7,
	RUN_DOWN = 8, RUN_UP = 9, RUN_LEFT = 10, RUN_RIGHT = 11,
	RUN_DL = 12, RUN_DR = 13, RUN_UL = 14, RUN_UR = 15,
	IDLE_DOWN = 16, IDLE_UP = 17, IDLE_LEFT = 18, IDLE_RIGHT = 19,
	IDLE_DL = 20, IDLE_DR = 21, IDLE_UL = 22, IDLE_UR = 23,
	ATK_DOWN = 24, ATK_LEFT = 25, ATK_RIGHT = 26, ATK_DL = 27, ATK_DR = 28,
}

const FRAME_COUNTS: Dictionary = {}

const DIR_TO_WALK_ROW: Array = [
	AnimRow.WALK_RIGHT, AnimRow.WALK_DR, AnimRow.WALK_DOWN, AnimRow.WALK_DL,
	AnimRow.WALK_LEFT, AnimRow.WALK_UL, AnimRow.WALK_UP, AnimRow.WALK_UR,
]

const DIR_TO_IDLE_ROW: Array = [
	AnimRow.IDLE_RIGHT, AnimRow.IDLE_DR, AnimRow.IDLE_DOWN, AnimRow.IDLE_DL,
	AnimRow.IDLE_LEFT, AnimRow.IDLE_UL, AnimRow.IDLE_UP, AnimRow.IDLE_UR,
]

# ── Atlas tile coordinates (col, row in 16x24 atlas) ───────────────────
# Ground tiles — grass variants (rows 0-2, cols 3-5 = pure grass)
const GRASS_TILES: Array = [
	Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
	Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1),
	Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
]
# Grass with flowers (rows 0-2, cols 6-8)
const FLOWER_TILES: Array = [
	Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0),
	Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1),
]
# Dirt path variants (rows 3-5, cols 3-5)
const DIRT_TILES: Array = [
	Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
	Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4),
	Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
]
# Stone/cobble variants (rows 6-8, cols 0-2+)
const STONE_TILES: Array = [
	Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6),
	Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
]
# Water variants (row 9)
const WATER_TILES: Array = [
	Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9),
]
# Tree canopy (row 10, cols 0-2)
const TREE_CANOPY_TILES: Array = [
	Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10),
]
# Tree trunk (row 10, cols 3-4)
const TREE_TRUNK_TILES: Array = [
	Vector2i(3, 10), Vector2i(4, 10),
]
# Hedge (row 10, cols 8-10)
const HEDGE_TILES: Array = [
	Vector2i(8, 10), Vector2i(9, 10), Vector2i(10, 10),
]
# Building wall (row 11, cols 0-4)
const WALL_TILES: Array = [
	Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11),
	Vector2i(3, 11), Vector2i(4, 11),
]
# Building roof (row 12, cols 4-12)
const ROOF_TILES: Array = [
	Vector2i(4, 12), Vector2i(5, 12), Vector2i(6, 12),
	Vector2i(7, 12), Vector2i(8, 12), Vector2i(9, 12),
	Vector2i(10, 12), Vector2i(11, 12), Vector2i(12, 12),
]
# Wood planks (row 11, cols 10-12)
const WOOD_TILES: Array = [
	Vector2i(10, 11), Vector2i(11, 11), Vector2i(12, 11),
]
# Door (row 12, cols 0-1)
const DOOR_TILES: Array = [Vector2i(0, 12), Vector2i(1, 12)]
# Window (row 12, cols 2-3)
const WINDOW_TILES: Array = [Vector2i(2, 12), Vector2i(3, 12)]
# Sign (row 12, cols 13-14)
const SIGN_TILES: Array = [Vector2i(13, 12), Vector2i(14, 12)]
# Lamp (row 12, col 15)
const LAMP_TILES: Array = [Vector2i(15, 12)]
# Chest (row 23, col 8 = closed, col 9 = opened)
const CHEST_CLOSED: Vector2i = Vector2i(8, 23)
const CHEST_OPEN: Vector2i = Vector2i(9, 23)
# Barrel (row 23, cols 10-11)
const BARREL_TILES: Array = [Vector2i(10, 23), Vector2i(11, 23)]
# Crate (row 23, cols 12-13)
const CRATE_TILES: Array = [Vector2i(12, 23), Vector2i(13, 23)]
# Fence H/V (row 14)
const FENCE_H: Vector2i = Vector2i(0, 14)
const FENCE_V: Vector2i = Vector2i(2, 14)
# Bridge (row 14, cols 4-5)
const BRIDGE_TILES: Array = [Vector2i(4, 14), Vector2i(5, 14)]

# High-impact exact-match kit rows
const TOWER_KIT_TILES: Array = [
	Vector2i(0, 21), Vector2i(1, 21), Vector2i(2, 21), Vector2i(3, 21),
	Vector2i(4, 21), Vector2i(5, 21), Vector2i(6, 21), Vector2i(7, 21),
]
const BLACKSMITH_KIT_TILES: Array = [
	Vector2i(0, 22), Vector2i(1, 22), Vector2i(2, 22), Vector2i(3, 22),
	Vector2i(4, 22), Vector2i(5, 22), Vector2i(6, 22), Vector2i(7, 22),
]
const STOREFRONT_KIT_TILES: Array = [
	Vector2i(8, 22), Vector2i(9, 22), Vector2i(10, 22), Vector2i(11, 22),
	Vector2i(12, 22), Vector2i(13, 22), Vector2i(14, 22), Vector2i(15, 22),
]
const ROAD_CURB_TILES: Array = [
	Vector2i(0, 23), Vector2i(1, 23), Vector2i(2, 23), Vector2i(3, 23),
	Vector2i(4, 23), Vector2i(5, 23), Vector2i(6, 23), Vector2i(7, 23),
]
const GREEN_ROOF_TILES: Array = [
	Vector2i(11, 17), Vector2i(12, 17), Vector2i(13, 17),
]
const TOWER_BALCONY_TILES: Array = [
	Vector2i(8, 21), Vector2i(9, 21), Vector2i(10, 21), Vector2i(11, 21),
]

# ── Node references ─────────────────────────────────────────────────────
@onready var camera: Camera2D = $ViewportContainer/SubViewport/World/Camera
@onready var ground_layer: TileMapLayer = $ViewportContainer/SubViewport/World/GroundLayer
@onready var path_layer: TileMapLayer = $ViewportContainer/SubViewport/World/PathLayer
@onready var decor_layer: TileMapLayer = $ViewportContainer/SubViewport/World/DecorLayer
@onready var roof_layer: TileMapLayer = $ViewportContainer/SubViewport/World/RoofLayer
@onready var entities: Node2D = $ViewportContainer/SubViewport/World/Entities
@onready var sub_viewport: SubViewport = $ViewportContainer/SubViewport
@onready var title_label: Label = $TopBar/TitleLabel
@onready var loot_label: Label = $TopBar/LootLabel
@onready var flash_label: Label = $FlashLabel
@onready var depart_btn: Button = $DepartBtn

# ── State ────────────────────────────────────────────────────────────────
var _planet: Planet = null
var _planet_state: Dictionary = {}
var _player_pos := Vector2.ZERO
var _sprite_texture: Texture2D = null
var _player_sprite: Sprite2D = null
var _elapsed: float = 0.0
var _flash_timer: float = 0.0
var _anim_row: int = AnimRow.IDLE_DOWN
var _anim_frame: int = 0
var _anim_timer: float = 0.0
var _facing_octant: int = 2
var _is_moving: bool = false
var _merchants: Array = []
var _treasures: Array = []
var _merchant_nodes: Dictionary = {}  # merchant_id -> Node2D
var _treasure_nodes: Dictionary = {}  # treasure_id -> Node2D
var _label_nodes: Dictionary = {}     # entity_id -> Label


# Resolve a character's spritesheet under the per-character asset layout.
# Tries protagonist → crew → npc locations and returns the first that exists.
static func _resolve_character_spritesheet(char_id: String) -> String:
	var candidates := [
		"res://assets/characters/%s/2d/spritesheet.png" % char_id,
		"res://assets/characters/crew/%s/2d/spritesheet.png" % char_id,
		"res://assets/characters/npc/%s/2d/spritesheet.png" % char_id,
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			return p
	return candidates[0]


func _ready() -> void:
	depart_btn.pressed.connect(_on_depart)
	depart_btn.text = "DEPART (ESC)"
	depart_btn.custom_minimum_size = Vector2(160, 48)
	depart_btn.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	depart_btn.add_theme_font_size_override("font_size", 16)
	depart_btn.call_deferred("grab_focus")
	var gs: GameStateData = GameSession.game_state
	var pid: String = gs.protagonist_id if gs else "aristotle"

	# Load sprite texture (already has transparent background)
	var sprite_path := _resolve_character_spritesheet(pid)
	var fallback := "res://assets/characters/aristotle/2d/spritesheet.png"
	_sprite_texture = load(sprite_path) if ResourceLoader.exists(sprite_path) else load(fallback)

	# Create player sprite node
	_player_sprite = Sprite2D.new()
	_player_sprite.texture = _sprite_texture
	_player_sprite.hframes = SPRITE_COLS
	_player_sprite.vframes = _sprite_texture.get_height() / SPRITE_FRAME_SIZE
	_player_sprite.z_index = 5
	entities.add_child(_player_sprite)

	if gs == null or gs.current_planet_id.is_empty():
		return

	_planet = GameSession.planet_system.get_planet(gs.current_planet_id)
	if _planet == null:
		return
	_planet_state = GameSession.planet_system.get_planet_state(gs, _planet.planet_id)

	title_label.text = _planet.planet_name.to_upper()
	_merchants = _planet.merchants.duplicate(true)
	_treasures = _planet.treasures.duplicate(true)

	# Generate tilemap
	_generate_map()

	# Place player at center
	_player_pos = Vector2(MAP_W * TILE_SIZE * 0.5, MAP_H * TILE_SIZE * 0.5)
	_player_sprite.position = _player_pos

	# Place merchants and treasures
	_place_entities(gs)

	_update_loot_label()
	MusicManager.on_state_change("trade")

	camera.position = _player_pos


func _process(dt: float) -> void:
	_elapsed += dt
	_handle_movement(dt)
	_update_animation(dt)
	_update_camera()
	_update_flash(dt)
	_update_proximity_labels()


func _handle_movement(dt: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
		direction.x += 1

	_is_moving = direction != Vector2.ZERO
	if _is_moving:
		direction = direction.normalized()
		var new_pos := _player_pos + direction * PLAYER_SPEED * dt
		# Clamp to map bounds
		new_pos.x = clampf(new_pos.x, 16.0, MAP_W * TILE_SIZE - 16.0)
		new_pos.y = clampf(new_pos.y, 16.0, MAP_H * TILE_SIZE - 16.0)
		# Simple collision — check if destination tile is walkable
		var tile_coord := Vector2i(int(new_pos.x) / TILE_SIZE, int(new_pos.y) / TILE_SIZE)
		if _is_walkable(tile_coord):
			_player_pos = new_pos
		# Update facing
		var angle: float = direction.angle()
		_facing_octant = int(round(angle / (TAU / 8.0))) % 8
		if _facing_octant < 0:
			_facing_octant += 8
		_anim_row = DIR_TO_WALK_ROW[_facing_octant]
	else:
		_anim_row = DIR_TO_IDLE_ROW[_facing_octant]

	_player_sprite.position = _player_pos


func _is_walkable(tile_coord: Vector2i) -> bool:
	# Check decor layer for blocking objects (walls, trees, water, hedges)
	var decor_data = decor_layer.get_cell_source_id(tile_coord)
	if decor_data != -1:
		var atlas_coord = decor_layer.get_cell_atlas_coords(tile_coord)
		# Block on walls, roofs, hedges, water
		if atlas_coord.y == 11 and atlas_coord.x < 10:
			return false  # Wall or roof
		if atlas_coord.y == 10 and atlas_coord.x >= 8 and atlas_coord.x <= 10:
			return false  # Hedge
		if atlas_coord.y == 9:
			return false  # Water
	# Check roof layer
	var roof_data = roof_layer.get_cell_source_id(tile_coord)
	if roof_data != -1:
		return false
	return true


func _update_animation(dt: float) -> void:
	_anim_timer += dt
	var spf: float = 1.0 / ANIM_FPS
	if _anim_timer >= spf:
		_anim_timer -= spf
		var max_frames: int = FRAME_COUNTS.get(_anim_row, SPRITE_COLS)
		if _is_moving:
			_anim_frame = (_anim_frame + 1) % max_frames
		else:
			_anim_frame = 0

	# Update sprite frame — frame index = row * cols + col
	_player_sprite.frame = _anim_row * SPRITE_COLS + _anim_frame
	# Scale sprite to desired size
	if _sprite_texture != null:
		var tex_frame_w: float = _sprite_texture.get_width() / float(SPRITE_COLS)
		var tex_frame_h: float = float(SPRITE_FRAME_SIZE)
		_player_sprite.scale = SPRITE_DRAW_SIZE / Vector2(tex_frame_w, tex_frame_h)


func _update_camera() -> void:
	# Smooth camera follow
	var target := _player_pos
	camera.position = camera.position.lerp(target, 0.1)


func _input(event: InputEvent) -> void:
	# Pre-UI handler so ESC/interact fire even if DepartBtn or the SubViewport
	# container has focus. Without this, clicking the button once gave it focus
	# and subsequent ESC presses didn't reach `_unhandled_input` on some systems.
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_depart()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_try_interact()


func _try_interact() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null or _planet == null:
		return

	# Check treasure proximity
	for t in _treasures:
		var tid: String = t.get("treasure_id", "")
		var tnode: Node2D = _treasure_nodes.get(tid)
		if tnode == null:
			continue
		if _player_pos.distance_to(tnode.position) <= INTERACT_RADIUS:
			if not GameSession.planet_system.is_treasure_cleared(gs, _planet.planet_id, tid):
				var reward: Dictionary = GameSession.planet_system.collect_treasure(gs, _planet.planet_id, tid)
				if not reward.is_empty():
					flash("Found: %s (+%dC +%dS)" % [
						reward.get("name", "Treasure"),
						reward.get("reward_crystals", 0),
						reward.get("reward_salvage", 0),
					], 3.0)
					_update_loot_label()
					# Swap chest tile to open
					var tile_pos := Vector2i(int(tnode.position.x) / TILE_SIZE, int(tnode.position.y) / TILE_SIZE)
					decor_layer.set_cell(tile_pos, 0, CHEST_OPEN)
				return

	# Check merchant proximity
	for m in _merchants:
		var mid: String = m.get("merchant_id", "")
		var mnode: Node2D = _merchant_nodes.get(mid)
		if mnode == null:
			continue
		if _player_pos.distance_to(mnode.position) <= INTERACT_RADIUS:
			_open_merchant(m)
			return

	flash("Nothing to interact with here.", 1.5)


func _open_merchant(merchant_data: Dictionary) -> void:
	var faction_id: String = merchant_data.get("faction_id", "")
	GameSession.open_trade_screen(faction_id)
	var main_node = get_tree().current_scene
	if main_node.has_method("push_overlay"):
		main_node.push_overlay("trade")


func _on_depart() -> void:
	GameSession.planet_system.depart(GameSession.game_state)
	MusicManager.on_state_change("navigation")
	var main_node = get_tree().current_scene
	if main_node.has_method("switch_scene"):
		main_node.switch_scene("navigation")


func _update_loot_label() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return
	var inv: Dictionary = gs.planet_inventory
	loot_label.text = "Loot: %dC %dS" % [inv.get("crystals", 0), inv.get("salvage", 0)]


func flash(message: String, duration: float = 3.0) -> void:
	flash_label.text = message
	_flash_timer = duration
	flash_label.visible = true


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


func _update_proximity_labels() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null or _planet == null:
		return
	# Show/hide interact prompts near entities
	for tid in _label_nodes:
		var lbl: Label = _label_nodes[tid]
		var node: Node2D = _treasure_nodes.get(tid, _merchant_nodes.get(tid))
		if node != null:
			var dist := _player_pos.distance_to(node.position)
			lbl.visible = dist <= INTERACT_RADIUS * 1.5


# ── Map Generation ──────────────────────────────────────────────────────

func _generate_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_planet.planet_id) if _planet != null else 42

	# Step 1: Fill ground with grass
	for x in range(MAP_W):
		for y in range(MAP_H):
			var grass_tile: Vector2i = GRASS_TILES[rng.randi() % GRASS_TILES.size()]
			ground_layer.set_cell(Vector2i(x, y), 0, grass_tile)

	# Step 2: Scatter flower patches
	for i in range(rng.randi_range(8, 18)):
		var fx: int = rng.randi_range(1, MAP_W - 2)
		var fy: int = rng.randi_range(1, MAP_H - 2)
		var ftile: Vector2i = FLOWER_TILES[rng.randi() % FLOWER_TILES.size()]
		ground_layer.set_cell(Vector2i(fx, fy), 0, ftile)

	# Step 3: Lay down dirt paths — main roads
	var center_x: int = MAP_W / 2
	var center_y: int = MAP_H / 2
	# Horizontal road
	for x in range(2, MAP_W - 2):
		for dy in range(-1, 2):
			var ty: int = center_y + dy
			if 0 <= ty and ty < MAP_H:
				path_layer.set_cell(Vector2i(x, ty), 0, DIRT_TILES[rng.randi() % DIRT_TILES.size()])
	# Vertical road
	for y in range(2, MAP_H - 2):
		for dx in range(-1, 2):
			var tx: int = center_x + dx
			if 0 <= tx and tx < MAP_W:
				path_layer.set_cell(Vector2i(tx, y), 0, DIRT_TILES[rng.randi() % DIRT_TILES.size()])
	# Secondary paths — random branches
	var branch_count: int = rng.randi_range(2, 4)
	for _b in range(branch_count):
		var start_x: int = rng.randi_range(4, MAP_W - 5)
		var start_y: int = rng.randi_range(4, MAP_H - 5)
		var length: int = rng.randi_range(5, 12)
		var horizontal: bool = rng.randi() % 2 == 0
		for step in range(length):
			var px: int = start_x + (step if horizontal else 0)
			var py: int = start_y + (0 if horizontal else step)
			if 0 <= px and px < MAP_W and 0 <= py and py < MAP_H:
				path_layer.set_cell(Vector2i(px, py), 0, DIRT_TILES[rng.randi() % DIRT_TILES.size()])

	# Step 4: Place stone plazas near crossroads
	for px in range(center_x - 2, center_x + 3):
		for py in range(center_y - 2, center_y + 3):
			if 0 <= px and px < MAP_W and 0 <= py and py < MAP_H:
				path_layer.set_cell(Vector2i(px, py), 0, STONE_TILES[rng.randi() % STONE_TILES.size()])

	# Step 5: Place buildings (wall clusters with roofs)
	var building_spots: Array = _get_building_spots(rng)
	for spot in building_spots:
		_place_building(spot.x, spot.y, spot.z, spot.w, rng)

	# Step 6: Place trees around edges and scattered
	_place_trees(rng)

	# Step 7: Place water feature (small pond in a corner)
	_place_water_feature(rng)

	# Step 8: Place fences around some areas
	_place_fences(rng)

	# Step 9: Scatter decorative objects (barrels, crates, lamps)
	_place_scatter_decor(rng)


func _get_building_spots(rng: RandomNumberGenerator) -> Array:
	var spots: Array = []
	var used_rects: Array = []  # Rect2i to check overlap

	var num_buildings: int = rng.randi_range(4, 8)
	for _i in range(num_buildings * 3):  # Try more times than needed
		if spots.size() >= num_buildings:
			break
		var bw: int = rng.randi_range(3, 5)
		var bh: int = rng.randi_range(3, 4)
		var bx: int = rng.randi_range(2, MAP_W - bw - 2)
		var by: int = rng.randi_range(2, MAP_H - bh - 2)
		var rect := Rect2i(bx - 1, by - 1, bw + 2, bh + 2)
		var overlaps := false
		for used in used_rects:
			if rect.intersects(used):
				overlaps = true
				break
		# Don't build on the main crossroads
		var center_rect := Rect2i(MAP_W / 2 - 3, MAP_H / 2 - 3, 6, 6)
		if rect.intersects(center_rect):
			overlaps = true
		if not overlaps:
			spots.append(Vector4i(bx, by, bw, bh))
			used_rects.append(rect)
	return spots


func _place_building(bx: int, by: int, bw: int, bh: int, rng: RandomNumberGenerator) -> void:
	# Walls
	for dx in range(bw):
		for dy in range(bh):
			var tile_pos := Vector2i(bx + dx, by + dy)
			var wall_tile: Vector2i = WALL_TILES[rng.randi() % WALL_TILES.size()]
			decor_layer.set_cell(tile_pos, 0, wall_tile)
	# Roof on top row
	for dx in range(bw):
		var roof_tile: Vector2i = ROOF_TILES[rng.randi() % ROOF_TILES.size()]
		roof_layer.set_cell(Vector2i(bx + dx, by), 0, roof_tile)
	# Door at bottom center
	var door_x: int = bx + bw / 2
	var door_y: int = by + bh - 1
	decor_layer.set_cell(Vector2i(door_x, door_y), 0, DOOR_TILES[0])
	# Windows
	if bw >= 4:
		decor_layer.set_cell(Vector2i(bx + 1, by + 1), 0, WINDOW_TILES[0])
		if bw >= 5:
			decor_layer.set_cell(Vector2i(bx + bw - 2, by + 1), 0, WINDOW_TILES[0])
	# Wood floor inside
	for dx in range(1, bw - 1):
		for dy in range(1, bh - 1):
			var tile_pos := Vector2i(bx + dx, by + dy)
			if decor_layer.get_cell_atlas_coords(tile_pos) != DOOR_TILES[0]:
				path_layer.set_cell(tile_pos, 0, WOOD_TILES[rng.randi() % WOOD_TILES.size()])


func _place_trees(rng: RandomNumberGenerator) -> void:
	# Edge trees
	for _i in range(rng.randi_range(12, 22)):
		var tx: int
		var ty: int
		if rng.randi() % 2 == 0:
			tx = rng.randi_range(0, 2) if rng.randi() % 2 == 0 else rng.randi_range(MAP_W - 3, MAP_W - 1)
			ty = rng.randi_range(0, MAP_H - 1)
		else:
			tx = rng.randi_range(0, MAP_W - 1)
			ty = rng.randi_range(0, 2) if rng.randi() % 2 == 0 else rng.randi_range(MAP_H - 3, MAP_H - 1)
		# Only place if ground is grass (no building or path)
		if decor_layer.get_cell_source_id(Vector2i(tx, ty)) == -1 and path_layer.get_cell_source_id(Vector2i(tx, ty)) == -1:
			decor_layer.set_cell(Vector2i(tx, ty), 0, TREE_CANOPY_TILES[rng.randi() % TREE_CANOPY_TILES.size()])
	# Scattered interior trees
	for _i in range(rng.randi_range(4, 10)):
		var tx: int = rng.randi_range(2, MAP_W - 3)
		var ty: int = rng.randi_range(2, MAP_H - 3)
		if decor_layer.get_cell_source_id(Vector2i(tx, ty)) == -1 and path_layer.get_cell_source_id(Vector2i(tx, ty)) == -1:
			decor_layer.set_cell(Vector2i(tx, ty), 0, TREE_CANOPY_TILES[rng.randi() % TREE_CANOPY_TILES.size()])


func _place_water_feature(rng: RandomNumberGenerator) -> void:
	# Small pond in a random corner
	var corner: int = rng.randi() % 4
	var wx: int = 1 if corner % 2 == 0 else MAP_W - 5
	var wy: int = 1 if corner < 2 else MAP_H - 5
	var pw: int = rng.randi_range(3, 4)
	var ph: int = rng.randi_range(2, 3)
	for dx in range(pw):
		for dy in range(ph):
			var pos := Vector2i(wx + dx, wy + dy)
			if decor_layer.get_cell_source_id(pos) == -1:
				decor_layer.set_cell(pos, 0, WATER_TILES[rng.randi() % WATER_TILES.size()])


func _place_fences(rng: RandomNumberGenerator) -> void:
	# Place some fences along property edges
	var fence_segments: int = rng.randi_range(2, 5)
	for _i in range(fence_segments):
		var fx: int = rng.randi_range(3, MAP_W - 6)
		var fy: int = rng.randi_range(3, MAP_H - 4)
		var flen: int = rng.randi_range(3, 6)
		var horizontal: bool = rng.randi() % 2 == 0
		for step in range(flen):
			var pos: Vector2i
			if horizontal:
				pos = Vector2i(fx + step, fy)
			else:
				pos = Vector2i(fx, fy + step)
			if pos.x >= 0 and pos.x < MAP_W and pos.y >= 0 and pos.y < MAP_H:
				if decor_layer.get_cell_source_id(pos) == -1:
					decor_layer.set_cell(pos, 0, FENCE_H if horizontal else FENCE_V)


func _place_scatter_decor(rng: RandomNumberGenerator) -> void:
	# Barrels, crates, lamps near buildings and paths
	var scatter_items: Array = [BARREL_TILES[0], CRATE_TILES[0], LAMP_TILES[0]]
	for _i in range(rng.randi_range(6, 15)):
		var sx: int = rng.randi_range(2, MAP_W - 3)
		var sy: int = rng.randi_range(2, MAP_H - 3)
		if decor_layer.get_cell_source_id(Vector2i(sx, sy)) == -1:
			var item: Vector2i = scatter_items[rng.randi() % scatter_items.size()]
			decor_layer.set_cell(Vector2i(sx, sy), 0, item)
	# Signs near some paths
	for _i in range(rng.randi_range(1, 3)):
		var sx: int = rng.randi_range(3, MAP_W - 4)
		var sy: int = rng.randi_range(3, MAP_H - 4)
		if decor_layer.get_cell_source_id(Vector2i(sx, sy)) == -1:
			decor_layer.set_cell(Vector2i(sx, sy), 0, SIGN_TILES[0])


# ── Entity Placement ────────────────────────────────────────────────────

func _place_entities(gs: GameStateData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_planet.planet_id) + 999

	# Place merchants as labeled markers
	for m in _merchants:
		var mid: String = m.get("merchant_id", "")
		var mname: String = m.get("name", "Merchant")
		var pos := _find_walkable_position(rng)
		var marker := Node2D.new()
		marker.position = pos
		entities.add_child(marker)
		_merchant_nodes[mid] = marker
		# Sprite instead of circle indicator
		var sprite := Sprite2D.new()
		# Fallback to merchant sprite
		var npc_key := "merchant"
		if mid.find("guard") != -1:
			npc_key = "guard"
		elif mid.find("fairy") != -1:
			npc_key = "fairy_cartographer"
		elif mid.find("urchin") != -1 or mid.find("goblin") != -1:
			npc_key = "urchin"
		elif mid.find("bard") != -1:
			npc_key = "bard"
		var tex_path := _resolve_character_spritesheet(npc_key)
		var tex_fallback := "res://assets/characters/npc/merchant/2d/spritesheet.png"
		sprite.texture = load(tex_path) if ResourceLoader.exists(tex_path) else load(tex_fallback)
		if sprite.texture != null:
			sprite.hframes = SPRITE_COLS
			sprite.vframes = sprite.texture.get_height() / SPRITE_FRAME_SIZE
			sprite.frame = AnimRow.IDLE_DOWN * SPRITE_COLS
			sprite.scale = SPRITE_DRAW_SIZE / Vector2(float(SPRITE_FRAME_SIZE), float(SPRITE_FRAME_SIZE))
			sprite.y_sort_enabled = true
		marker.add_child(sprite)
		# Label
		var lbl := _create_entity_label(mname, Color(1.0, 1.0, 1.0))
		marker.add_child(lbl)
		_label_nodes[mid] = lbl

	# Place treasures as chests
	for t in _treasures:
		var tid: String = t.get("treasure_id", "")
		var tname: String = t.get("name", "Treasure")
		var pos := _find_walkable_position(rng)
		var marker := Node2D.new()
		marker.position = pos
		entities.add_child(marker)
		_treasure_nodes[tid] = marker
		# Place chest tile on decor layer
		var tile_pos := Vector2i(int(pos.x) / TILE_SIZE, int(pos.y) / TILE_SIZE)
		var cleared: bool = GameSession.planet_system.is_treasure_cleared(gs, _planet.planet_id, tid)
		decor_layer.set_cell(tile_pos, 0, CHEST_OPEN if cleared else CHEST_CLOSED)
		# Sparkle indicator (keep as is or adjust)
		if not cleared:
			var indicator := _create_circle_indicator(Color(1.0, 0.82, 0.25, 0.5), 10.0)
			marker.add_child(indicator)
		# Label
		var lbl := _create_entity_label("HIDDEN ARTEFACT\n" + tname, Color(1.0, 0.9, 0.5))
		lbl.visible = false  # Only show on proximity
		marker.add_child(lbl)
		_label_nodes[tid] = lbl


func _find_walkable_position(rng: RandomNumberGenerator) -> Vector2:
	for _attempt in range(50):
		var x: int = rng.randi_range(4, MAP_W - 5)
		var y: int = rng.randi_range(4, MAP_H - 5)
		var tile_pos := Vector2i(x, y)
		if decor_layer.get_cell_source_id(tile_pos) == -1 and roof_layer.get_cell_source_id(tile_pos) == -1:
			return Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
	# Fallback to center area
	return Vector2(MAP_W * TILE_SIZE * 0.5 + rng.randf_range(-64, 64), MAP_H * TILE_SIZE * 0.5 + rng.randf_range(-64, 64))


func _create_circle_indicator(color: Color, radius: float) -> Sprite2D:
	# Create a simple colored circle texture and use a Sprite2D for pulsing
	var img_size: int = int(radius * 4)
	var img := Image.create(img_size, img_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(img_size * 0.5, img_size * 0.5)
	var r: float = radius
	for y in range(img_size):
		for x in range(img_size):
			var dist: float = Vector2(x, y).distance_to(center)
			if dist <= r:
				var alpha: float = 1.0 - (dist / r) * 0.6
				img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
			elif dist <= r + 1.0:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.1))
	var tex := ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	return sprite


func _create_entity_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = Vector2(-30, -32)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(60, 12)
	return lbl


# ── Utilities ───────────────────────────────────────────────────────────

static func _remove_background_by_corners(tex: Texture2D, tolerance: float = 0.13, feather: float = 0.05) -> Texture2D:
	if tex == null:
		return tex
	var image: Image = tex.get_image()
	if image == null:
		return tex
	image.convert(Image.FORMAT_RGBA8)
	var w: int = image.get_width()
	var h: int = image.get_height()
	if w == 0 or h == 0:
		return tex
	var corners: Array[Color] = [
		image.get_pixel(0, 0),
		image.get_pixel(w - 1, 0),
		image.get_pixel(0, h - 1),
		image.get_pixel(w - 1, h - 1),
	]
	for c in corners:
		if c.a < 0.95:
			return tex
	var best_idx: int = 0
	var best_score: float = INF
	for i in 4:
		var score: float = 0.0
		for j in 4:
			if i != j:
				score += absf(corners[i].r - corners[j].r) + absf(corners[i].g - corners[j].g) + absf(corners[i].b - corners[j].b)
		if score < best_score:
			best_score = score
			best_idx = i
	var bg: Color = corners[best_idx]
	for y_px in h:
		for x_px in w:
			var px: Color = image.get_pixel(x_px, y_px)
			var delta: float = maxf(absf(px.r - bg.r), maxf(absf(px.g - bg.g), absf(px.b - bg.b)))
			if delta <= tolerance:
				image.set_pixel(x_px, y_px, Color(px.r, px.g, px.b, 0.0))
			elif delta <= tolerance + feather:
				var alpha_scale: float = (delta - tolerance) / feather
				image.set_pixel(x_px, y_px, Color(px.r, px.g, px.b, px.a * alpha_scale))
	return ImageTexture.create_from_image(image)
