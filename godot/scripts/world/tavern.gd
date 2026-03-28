extends Node2D

const SOURCE_ID := 0
const TILE_SIZE := 32
const MAP_W := 10
const MAP_H := 9

const FLOOR_TILES := [Vector2i(0, 6), Vector2i(2, 6), Vector2i(5, 6)]
const WALL_TILE := Vector2i(0, 11)
const TABLE_TILE := Vector2i(10, 23)
const CHAIR_TILE := Vector2i(12, 23)

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var decor_layer: TileMapLayer = $DecorLayer
@onready var roof_layer: TileMapLayer = $RoofLayer


func _ready() -> void:
	_build_map()


func _build_map() -> void:
	ground_layer.clear()
	decor_layer.clear()
	roof_layer.clear()

	for y in range(MAP_H):
		for x in range(MAP_W):
			var floor_tile: Vector2i = FLOOR_TILES[(x + y) % FLOOR_TILES.size()]
			ground_layer.set_cell(Vector2i(x, y), SOURCE_ID, floor_tile)

	for x in range(MAP_W):
		_set_decor(x, 0, WALL_TILE)
		_set_decor(x, MAP_H - 1, WALL_TILE)
	for y in range(MAP_H):
		_set_decor(0, y, WALL_TILE)
		_set_decor(MAP_W - 1, y, WALL_TILE)

	_set_decor(4, MAP_H - 1, Vector2i(-1, -1))
	_set_decor(5, MAP_H - 1, Vector2i(-1, -1))

	_set_decor(3, 4, TABLE_TILE)
	_set_decor(4, 4, TABLE_TILE)
	_set_decor(5, 4, TABLE_TILE)
	_set_decor(6, 4, TABLE_TILE)
	_set_decor(3, 5, CHAIR_TILE)
	_set_decor(6, 5, CHAIR_TILE)


func _set_decor(x: int, y: int, atlas: Vector2i) -> void:
	if atlas.x < 0 or atlas.y < 0:
		decor_layer.erase_cell(Vector2i(x, y))
		return
	decor_layer.set_cell(Vector2i(x, y), SOURCE_ID, atlas)
