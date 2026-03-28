extends Node2D
## Procedural map generator for the Fringe Haven Outpost world scene.
## Uses the Serene Village 32x32 tileset (Source 1) as primary atlas
## and legacy world_atlas (Source 0) for supplementary props.

const SRC := 1           # Serene Village atlas (Source 1)
const SRC_LEGACY := 0    # Old world atlas (Source 0, backward compat)
const SRC_WATER := 2     # Animated water waves (Source 2, 14-frame strip)
const SRC_CAMPFIRE := 3
const SRC_ICONS := 4     # Transparent icons atlas (Source 4)
const TILE_SIZE := 32
const MAP_W := 44
const MAP_H := 25

# ── Terrain Tiles (Serene Village atlas, Source 1) ────────────────────

const GRASS := [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1)]

# ── Water (animated tile from Source 2, shoreline from Serene Village Source 1) ──
const WATER_ANIM := Vector2i(0, 0)  # Animated water tile (14 frames, Source 2)
const EDGE_T  := Vector2i(12, 0)
const EDGE_B  := Vector2i(12, 2)
const EDGE_L  := Vector2i(11, 1)
const EDGE_R  := Vector2i(13, 1)
const EDGE_TL := Vector2i(11, 0)
const EDGE_TR := Vector2i(13, 0)
const EDGE_BL := Vector2i(11, 2)
const EDGE_BR := Vector2i(13, 2)
const WATER_ISLAND_ORIGIN := Vector2i(3, 4)
const WATER_ISLAND_SIZE := Vector2i(6, 3)

# Roads and paths use the legacy atlas (Source 0) — proper cobble/dirt textures
const ROAD := [Vector2i(0, 6), Vector2i(2, 6), Vector2i(5, 6)]
const DIRT := [Vector2i(3, 3), Vector2i(4, 4), Vector2i(5, 5)]
const DIRT_LIGHT := [Vector2i(3, 3), Vector2i(4, 4)]
const BRIDGE_H := Vector2i(12, 3)

# ── Trees (individual tree stamps) ─────────────────────────────────────

const TREE_VARIANTS := [
	Vector2i(9, 12),
	Vector2i(11, 12),
	Vector2i(13, 12),
	Vector2i(15, 12),
	Vector2i(17, 13),
]
const TREE_VARIANT_SIZES := [
	Vector2i(2, 3),
	Vector2i(2, 3),
	Vector2i(2, 3),
	Vector2i(2, 3),
	Vector2i(2, 2),
]


# ── Props & Decoration ────────────────────────────────────────────────

const FLOWER := [Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12)]
const FENCE_H := Vector2i(5, 12)
const FENCE_V := Vector2i(6, 12)
const HEDGE := Vector2i(7, 12)
const ROCK := [Vector2i(0, 15), Vector2i(3, 15), Vector2i(4, 15)]
const CAMPFIRE_ANIM := Vector2i(0, 0)

# Legacy props (old atlas, Source 1)
const L_WALL := [Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11), Vector2i(3, 11), Vector2i(4, 11)]
const L_CRATE := Vector2i(12, 23)
const L_SIGN := Vector2i(14, 12)
const HIDDEN_ICON := Vector2i(11, 11)


# ── Node References ───────────────────────────────────────────────────

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var decor_layer: TileMapLayer = $DecorLayer
@onready var roof_layer: TileMapLayer = $RoofLayer
@onready var player: CharacterBody2D = $Entities/Player
@onready var labels_root: Node2D = $Entities/WorldLabels
@onready var tavern_entrance: Area2D = $TavernEntrance
@onready var world_bounds: StaticBody2D = $WorldBounds
@onready var water_bounds: StaticBody2D = $WaterBounds

var _solid_rects: Array[Rect2i] = []


func _ready() -> void:
	_build_map()
	_build_water_colliders()
	_build_structure_colliders()
	_configure_world_bounds()
	_configure_camera_bounds()
	_place_labels()
	player.position = _tile_center(2, 13)  # Landing island, near bridge
	tavern_entrance.position = _tile_center(15, 11)  # At Tipsy Tankard door


# ── Map Construction ──────────────────────────────────────────────────

func _build_map() -> void:
	ground_layer.clear()
	decor_layer.clear()
	roof_layer.clear()
	_solid_rects.clear()
	_fill_ground()
	_paint_water()
	_place_water_island()
	_paint_roads()
	_place_bridge()
	_place_city_walls()
	_place_landmarks()
	_place_houses()
	_place_fences_and_hedges()
	_place_props()
	_place_trees()


func _fill_ground() -> void:
	for y in range(MAP_H):
		for x in range(MAP_W):
			_set_tile(ground_layer, x, y, GRASS[(x * 5 + y * 3) % GRASS.size()])


func _paint_water() -> void:
	var water_cells := _build_water_cells()

	for cell in water_cells:
		var x: int = cell.x
		var y: int = cell.y
		var has_t := not water_cells.has(Vector2i(x, y - 1)) and y > 0
		var has_b := not water_cells.has(Vector2i(x, y + 1)) and y < MAP_H - 1
		var has_l := not water_cells.has(Vector2i(x - 1, y)) and x > 0
		var has_r := not water_cells.has(Vector2i(x + 1, y))
		var edge_tile := Vector2i(-1, -1)
		if has_t and has_l:
			edge_tile = EDGE_TL
		elif has_t and has_r:
			edge_tile = EDGE_TR
		elif has_b and has_l:
			edge_tile = EDGE_BL
		elif has_b and has_r:
			edge_tile = EDGE_BR
		elif has_t:
			edge_tile = EDGE_T
		elif has_b:
			edge_tile = EDGE_B
		elif has_l:
			edge_tile = EDGE_L
		elif has_r:
			edge_tile = EDGE_R
		if edge_tile != Vector2i(-1, -1):
			decor_layer.set_cell(cell, SRC, edge_tile)
		else:
			decor_layer.set_cell(cell, SRC_WATER, WATER_ANIM)


func _place_water_island() -> void:
	for dy in range(WATER_ISLAND_SIZE.y):
		for dx in range(WATER_ISLAND_SIZE.x):
			_set_tile(
				decor_layer,
				1 + dx,
				4 + dy,
				Vector2i(WATER_ISLAND_ORIGIN.x + dx, WATER_ISLAND_ORIGIN.y + dy)
			)


func _build_water_cells() -> Dictionary:
	## Builds the water cell set with a landing island for the bridge.
	## Upper bay tapers into a narrow channel, then widens to lower bay.
	## Landing island at rows 11-16, cols 0-3 provides solid ground.
	var cells := {}
	# Upper bay: rows 0-10, cols 0-7
	for y in range(0, 11):
		for x in range(0, 8):
			cells[Vector2i(x, y)] = true
	# Narrow channel east of landing: rows 11-16, cols 4-6
	for y in range(11, 17):
		for x in range(4, 7):
			cells[Vector2i(x, y)] = true
	# Lower bay: rows 17-24, cols 0-6
	for y in range(17, MAP_H):
		for x in range(0, 7):
			cells[Vector2i(x, y)] = true
	# Exclude full bridge footprint through the channel
	for y in range(12, 15):
		for x in range(4, 7):
			cells.erase(Vector2i(x, y))
	return cells


func _paint_roads() -> void:
	# Main vertical road (stone cobble from legacy atlas)
	for y in range(MAP_H):
		for x in range(21, 24):
			_set_legacy(ground_layer, x, y, ROAD[(x + y) % ROAD.size()])

	# Main horizontal road (starts at col 7, after bridge end)
	for x in range(7, MAP_W):
		for y in range(12, 15):
			_set_legacy(ground_layer, x, y, ROAD[(x + y) % ROAD.size()])

	# Dirt paths to buildings (legacy atlas)
	_paint_rect_legacy(ground_layer, Rect2i(7, 7, 14, 2), DIRT)
	_paint_rect_legacy(ground_layer, Rect2i(10, 10, 10, 2), DIRT)
	_paint_rect_legacy(ground_layer, Rect2i(24, 7, 18, 2), DIRT)
	_paint_rect_legacy(ground_layer, Rect2i(9, 16, 11, 7), DIRT_LIGHT)
	_paint_rect_legacy(ground_layer, Rect2i(24, 15, 18, 3), DIRT_LIGHT)

	# Vertical side paths
	for y in range(7, 22):
		_set_legacy(ground_layer, 16, y, DIRT[y % DIRT.size()])
		_set_legacy(ground_layer, 17, y, DIRT[y % DIRT.size()])
	for y in range(7, 18):
		_set_legacy(ground_layer, 31, y, DIRT[y % DIRT.size()])
		_set_legacy(ground_layer, 32, y, DIRT[y % DIRT.size()])
	for y in range(6, 14):
		_set_legacy(ground_layer, 38, y, DIRT[y % DIRT.size()])
		_set_legacy(ground_layer, 39, y, DIRT[y % DIRT.size()])


func _place_bridge() -> void:
	## Bridge spans the narrow channel from landing island (col 3) to mainland (col 7).
	## Full bridge sprite on decor_layer.
	# Dirt approach on the landing island side
	for y in range(12, 16):
		_set_legacy(ground_layer, 3, y, DIRT[y % DIRT.size()])
	for dy in range(3):
		for dx in range(3):
			_set_tile(decor_layer, 4 + dx, 12 + dy, Vector2i(BRIDGE_H.x + dx, BRIDGE_H.y + dy))


func _place_city_walls() -> void:
	_paint_rect_legacy(ground_layer, Rect2i(8, 0, 36, 2), ROAD)
	_paint_rect_legacy(ground_layer, Rect2i(42, 0, 2, 9), ROAD)
	_paint_rect_legacy(ground_layer, Rect2i(42, 14, 2, 11), ROAD)
	_paint_rect_legacy(ground_layer, Rect2i(7, 23, 37, 2), ROAD)
	for x in range(8, 44):
		_set_legacy(decor_layer, x, 0, L_WALL[x % L_WALL.size()])
		_set_legacy(decor_layer, x, 1, L_WALL[(x + 2) % L_WALL.size()])
	for y in range(0, 9):
		_set_legacy(decor_layer, 42, y, L_WALL[y % L_WALL.size()])
		_set_legacy(decor_layer, 43, y, L_WALL[(y + 1) % L_WALL.size()])
	for y in range(14, MAP_H):
		_set_legacy(decor_layer, 42, y, L_WALL[y % L_WALL.size()])
		_set_legacy(decor_layer, 43, y, L_WALL[(y + 1) % L_WALL.size()])
	for x in range(7, 44):
		_set_legacy(decor_layer, x, 23, L_WALL[x % L_WALL.size()])
		_set_legacy(decor_layer, x, 24, L_WALL[(x + 2) % L_WALL.size()])
	_register_solid_rect(Rect2i(8, 0, 36, 2))
	_register_solid_rect(Rect2i(42, 0, 2, 9))
	_register_solid_rect(Rect2i(42, 14, 2, 11))
	_register_solid_rect(Rect2i(7, 23, 37, 2))


# ── Buildings ─────────────────────────────────────────────────────────
# Buildings are pre-assembled multi-tile sprites stamped from the atlas.
# Each building has roof rows (placed on roof_layer) and wall/foundation
# rows (placed on decor_layer) for proper z-ordering.
#
# Serene Village building layout:
#   RED:   Large (0,22) 5x3  |  Compact (5,25) 5x4  |  Small (10,26) 3x3 / (13,26) 3x3
#   GREEN: Large (0,30) 5x3  |  Compact (0,33) 5x4  |  Small (10,34) 3x3 / (13,34) 3x3
#   BLUE:  Large (0,38) 5x3  |  Compact (0,41) 5x4  |  Small (10,42) 3x3 / (13,42) 3x3

func _place_landmarks() -> void:
	# Tower area — green compact building (tallest variant)
	_stamp_building(Vector2i(8, 3), Vector2i(0, 33), Vector2i(5, 4), 2)

	# Tipsy Tankard — red compact building (most prominent)
	_stamp_building(Vector2i(13, 7), Vector2i(5, 25), Vector2i(5, 4), 2)

	# Bryn's Oddities — red large building (roof_rows=2 for full roof on top layer)
	_stamp_building(Vector2i(24, 8), Vector2i(10, 21), Vector2i(5, 4), 2)

	# Blacksmith — green large building (roof_rows=2)
	_stamp_building(Vector2i(31, 8), Vector2i(10, 29), Vector2i(5, 4), 2)


func _place_houses() -> void:
	# Lower-left residential (near tavern)
	_stamp_building(Vector2i(10, 16), Vector2i(0, 21), Vector2i(3, 4), 2)
	_stamp_building(Vector2i(14, 16), Vector2i(3, 21), Vector2i(3, 4), 2)

	# Lower-right residential (mixed colors)
	_stamp_building(Vector2i(24, 15), Vector2i(10, 33), Vector2i(3, 4), 2)
	_stamp_building(Vector2i(28, 15), Vector2i(13, 33), Vector2i(3, 4), 2)
	_stamp_building(Vector2i(33, 15), Vector2i(10, 41), Vector2i(3, 4), 2)
	_stamp_building(Vector2i(37, 15), Vector2i(13, 41), Vector2i(3, 4), 2)


func _stamp_building(map_pos: Vector2i, atlas_pos: Vector2i, size: Vector2i, roof_rows: int, doorway_width: int = 1) -> void:
	## Copies a rectangular block of atlas tiles onto the map.
	## Top roof_rows go on roof_layer; the rest on decor_layer.
	for dy in range(size.y):
		for dx in range(size.x):
			var atlas_coord := Vector2i(atlas_pos.x + dx, atlas_pos.y + dy)
			if dy < roof_rows:
				_set_tile(roof_layer, map_pos.x + dx, map_pos.y + dy, atlas_coord)
			else:
				_set_tile(decor_layer, map_pos.x + dx, map_pos.y + dy, atlas_coord)
	_register_building_solid(map_pos, size, doorway_width)


# ── Props & Decoration ────────────────────────────────────────────────

func _place_fences_and_hedges() -> void:
	# Fences around upper meadow
	for x in range(30, 43):
		_set_tile(decor_layer, x, 4, FENCE_H)
		_set_tile(decor_layer, x, 8, FENCE_H)
	for y in range(4, 9):
		_set_tile(decor_layer, 30, y, FENCE_V)
		_set_tile(decor_layer, 42, y, FENCE_V)

	# Hedges around lower residential
	for x in range(12, 21):
		_set_tile(decor_layer, x, 22, HEDGE)
	for y in range(20, 23):
		_set_tile(decor_layer, 20, y, HEDGE)
	_register_solid_rect(Rect2i(30, 4, 13, 1))
	_register_solid_rect(Rect2i(30, 8, 13, 1))
	_register_solid_rect(Rect2i(30, 4, 1, 5))
	_register_solid_rect(Rect2i(42, 4, 1, 5))
	_register_solid_rect(Rect2i(12, 22, 9, 1))
	_register_solid_rect(Rect2i(20, 20, 1, 3))


func _place_props() -> void:
	# Hidden markers
	_set_icon(decor_layer, 1, 12, HIDDEN_ICON)
	_set_icon(decor_layer, 2, 15, HIDDEN_ICON)
	_set_icon(decor_layer, 26, 6, HIDDEN_ICON)
	_set_icon(decor_layer, 35, 4, HIDDEN_ICON)
	_set_icon(decor_layer, 31, 7, HIDDEN_ICON)

	# Signs at key locations
	_set_legacy(decor_layer, 19, 12, L_SIGN)
	_set_legacy(decor_layer, 29, 12, L_SIGN)
	_set_legacy(decor_layer, 36, 12, L_SIGN)

	# Crates
	_set_legacy(decor_layer, 25, 16, L_CRATE)
	_set_legacy(decor_layer, 34, 16, L_CRATE)

	for pos in [Vector2i(12, 11), Vector2i(17, 19), Vector2i(31, 18)]:
		decor_layer.set_cell(pos, SRC_CAMPFIRE, CAMPFIRE_ANIM)

	# Flowers (serene village atlas)
	for pos in [Vector2i(10, 6), Vector2i(12, 7), Vector2i(19, 6),
				Vector2i(25, 5), Vector2i(36, 6), Vector2i(15, 19),
				Vector2i(18, 20), Vector2i(27, 18), Vector2i(35, 18)]:
		_set_tile(decor_layer, pos.x, pos.y, FLOWER[pos.x % FLOWER.size()])

	# Rocks
	for pos in [Vector2i(8, 15), Vector2i(9, 12), Vector2i(19, 19),
				Vector2i(36, 19), Vector2i(40, 13), Vector2i(7, 20)]:
		_set_tile(decor_layer, pos.x, pos.y, ROCK[pos.x % ROCK.size()])


func _place_trees() -> void:
	for placement in [
		Vector3i(14, 5, 0),
		Vector3i(18, 5, 1),
		Vector3i(27, 6, 2),
		Vector3i(33, 6, 3),
		Vector3i(40, 7, 0),
		Vector3i(26, 21, 4),
		Vector3i(36, 21, 1),
	]:
		_place_tree(placement.x, placement.y, placement.z)


func _place_tree(x: int, y: int, variant_index: int) -> void:
	if variant_index < 0 or variant_index >= TREE_VARIANTS.size():
		return
	if not _can_place_tree(x, y, variant_index):
		return
	var origin: Vector2i = TREE_VARIANTS[variant_index]
	var size: Vector2i = TREE_VARIANT_SIZES[variant_index]
	for dy in range(size.y):
		for dx in range(size.x):
			_set_tile(decor_layer, x + dx, y - (size.y - 1) + dy, Vector2i(origin.x + dx, origin.y + dy))


func _can_place_tree(x: int, y: int, variant_index: int) -> bool:
	var size: Vector2i = TREE_VARIANT_SIZES[variant_index]
	for dy in range(size.y):
		for dx in range(size.x):
			var map_x := x + dx
			var map_y := y - (size.y - 1) + dy
			if not _in_bounds(map_x, map_y):
				return false
			var map_pos := Vector2i(map_x, map_y)
			if decor_layer.get_cell_source_id(map_pos) != -1:
				return false
			if roof_layer.get_cell_source_id(map_pos) != -1:
				return false
			if ground_layer.get_cell_source_id(map_pos) != SRC:
				return false
	return true


# ── Labels ────────────────────────────────────────────────────────────

func _place_labels() -> void:
	for child in labels_root.get_children():
		child.queue_free()

	_add_label("FRINGE HAVEN OUTPOST", Vector2(560, 20), Color(0.95, 0.9, 0.8), 18, 300)

	_add_label("LANDING\nIsland", Vector2(16, 370), Color(0.95, 0.9, 0.8), 11, 110)
	_add_label("HIDDEN ARTEFACT\nGolden Monocles", Vector2(735, 92), Color(1.0, 0.92, 0.64), 11, 200)
	_add_label("HIDDEN CHEST\nSmall Chest", Vector2(1010, 50), Color(1.0, 0.92, 0.64), 11, 170)
	_add_label("HIDDEN ARTEFACT\nSmall Chest", Vector2(1070, 150), Color(1.0, 0.92, 0.64), 11, 190)

	_add_building_scroll_label("TIPSY TANKARD", Vector2(386, 192), 220)
	_add_building_scroll_label("BRYN'S ODDITIES", Vector2(738, 206), 220)
	_add_building_scroll_label("BLACKSMITH", Vector2(977, 206), 190)


func _add_label(text: String, pos: Vector2, color: Color, font_size: int, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.custom_minimum_size = Vector2(width, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 50
	labels_root.add_child(label)


func _add_building_scroll_label(text: String, pos: Vector2, width: float) -> void:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(width, 28)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 55

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.95, 0.88, 0.66, 0.95)
	box.border_color = Color(0.35, 0.22, 0.09, 0.95)
	box.border_width_top = 2
	box.border_width_bottom = 2
	box.border_width_left = 6
	box.border_width_right = 6
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 2
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.2, 0.14, 0.08))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(label)

	labels_root.add_child(panel)

	var base_y := pos.y
	var tween := panel.create_tween()
	tween.set_loops()
	tween.tween_property(panel, "position:y", base_y - 2.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(panel, "position:y", base_y + 2.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ── Colliders ─────────────────────────────────────────────────────────

func _configure_world_bounds() -> void:
	if world_bounds == null:
		return
	world_bounds.collision_layer = 1
	world_bounds.collision_mask = 1


func _configure_camera_bounds() -> void:
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP_W * TILE_SIZE
	camera.limit_bottom = MAP_H * TILE_SIZE


func _build_water_colliders() -> void:
	if water_bounds == null:
		return
	for child in water_bounds.get_children():
		child.queue_free()
	# Upper bay
	_add_water_collider(Rect2i(0, 0, 8, 11))
	# Narrow channel — above bridge (rows 11-12)
	_add_water_collider(Rect2i(4, 11, 3, 2))
	# Narrow channel — below bridge (rows 15-16)
	_add_water_collider(Rect2i(4, 15, 3, 2))
	# Lower bay
	_add_water_collider(Rect2i(0, 17, 7, 8))


func _add_water_collider(rect: Rect2i) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(rect.size.x * TILE_SIZE, rect.size.y * TILE_SIZE)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(
		rect.position.x * TILE_SIZE + shape.size.x * 0.5,
		rect.position.y * TILE_SIZE + shape.size.y * 0.5
	)
	water_bounds.add_child(collider)


func _build_structure_colliders() -> void:
	if world_bounds == null:
		return
	for child in world_bounds.get_children():
		if child is CollisionShape2D and child.name.begins_with("Dynamic"):
			child.queue_free()
	for i in range(_solid_rects.size()):
		_add_world_collider(_solid_rects[i], "DynamicSolid%d" % i)


func _add_world_collider(rect: Rect2i, collider_name: String) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(rect.size.x * TILE_SIZE, rect.size.y * TILE_SIZE)
	var collider := CollisionShape2D.new()
	collider.name = collider_name
	collider.shape = shape
	collider.position = Vector2(
		rect.position.x * TILE_SIZE + shape.size.x * 0.5,
		rect.position.y * TILE_SIZE + shape.size.y * 0.5
	)
	world_bounds.add_child(collider)


func _register_solid_rect(rect: Rect2i) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	_solid_rects.append(rect)


func _register_building_solid(map_pos: Vector2i, size: Vector2i, doorway_width: int) -> void:
	if doorway_width <= 0 or doorway_width >= size.x or size.y <= 1:
		_register_solid_rect(Rect2i(map_pos, size))
		return
	_register_solid_rect(Rect2i(map_pos, Vector2i(size.x, size.y - 1)))
	var doorway_x := map_pos.x + int((size.x - doorway_width) * 0.5)
	var base_y := map_pos.y + size.y - 1
	var left_width := doorway_x - map_pos.x
	if left_width > 0:
		_register_solid_rect(Rect2i(map_pos.x, base_y, left_width, 1))
	var right_x := doorway_x + doorway_width
	var right_width := map_pos.x + size.x - right_x
	if right_width > 0:
		_register_solid_rect(Rect2i(right_x, base_y, right_width, 1))


# ── Utility ───────────────────────────────────────────────────────────

func _paint_rect(layer: TileMapLayer, rect: Rect2i, tiles: Array) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_set_tile(layer, x, y, tiles[(x + y) % tiles.size()])


func _paint_rect_legacy(layer: TileMapLayer, rect: Rect2i, tiles: Array) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_set_legacy(layer, x, y, tiles[(x + y) % tiles.size()])


func _set_tile(layer: TileMapLayer, x: int, y: int, atlas: Vector2i) -> void:
	if not _in_bounds(x, y):
		return
	layer.set_cell(Vector2i(x, y), SRC, atlas)


func _set_legacy(layer: TileMapLayer, x: int, y: int, atlas: Vector2i) -> void:
	## Sets a tile from the legacy world atlas (Source 1).
	if not _in_bounds(x, y):
		return
	layer.set_cell(Vector2i(x, y), SRC_LEGACY, atlas)


func _set_icon(layer: TileMapLayer, x: int, y: int, atlas: Vector2i) -> void:
	if not _in_bounds(x, y):
		return
	layer.set_cell(Vector2i(x, y), SRC_ICONS, atlas)


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < MAP_W and y < MAP_H


func _tile_center(x: int, y: int) -> Vector2:
	return Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
