## ProceduralMapManager — autoload that provides procedural map textures
## for navigation backgrounds, star map overlays, and planet surfaces.
##
## Uses the ProceduralWorldMap plugin with custom color palettes per context.
extends Node

const SessionFactory = preload("res://addons/procedural_world_map/session_factory.gd")
const FastNoiseLiteDatasource = preload("res://addons/procedural_world_map/fastnoiselite_datasource.gd")
const BConsts = preload("res://addons/procedural_world_map/biome_constants.gd")

# ---------------------------------------------------------------------------
# Region seed mapping — deterministic seed per region for consistent visuals
# ---------------------------------------------------------------------------
const REGION_SEEDS: Dictionary = {
	"starting_realm": 42,
	"feline_courts": 137,
	"canine_order": 256,
	"fairy_realms": 389,
	"goblin_warrens": 512,
	"knight_kingdoms": 678,
	"deep_space": 800,
	"shattered_prides": 923,
	"iron_expanse": 1050,
	"twilight_bazaar": 1177,
	"warp_marches": 1300,
}

# ---------------------------------------------------------------------------
# Space nebula color palette — remaps biome IDs to deep-space hues
# Each region gets a tint multiplier to make them visually distinct
# ---------------------------------------------------------------------------
const SPACE_COLORS: Dictionary = {
	BConsts.cDeepWater: [2, 3, 12],        # near-black void
	BConsts.cShallowWater: [5, 8, 22],     # dark blue void
	BConsts.cSand: [18, 8, 28],            # dark magenta nebula wisp
	BConsts.cDesert: [25, 12, 15],          # warm dust
	BConsts.cGrass: [8, 15, 30],            # cool blue nebula
	BConsts.cSavanna: [20, 10, 25],         # purple haze
	BConsts.cForest: [6, 18, 22],           # teal nebula
	BConsts.cSeasonalForest: [12, 10, 28],  # indigo cloud
	BConsts.cBorealForest: [8, 12, 20],     # steel blue
	BConsts.cRainForest: [15, 25, 18],      # green nebula
	BConsts.cRock: [14, 14, 16],            # grey asteroid field
	BConsts.cTundra: [10, 12, 18],          # cold blue-grey
	BConsts.cSnow: [22, 22, 28],            # bright nebula core
}

# Galaxy-scale palette — brighter, more colorful for the codex overview
const GALAXY_COLORS: Dictionary = {
	BConsts.cDeepWater: [3, 4, 18],
	BConsts.cShallowWater: [8, 12, 35],
	BConsts.cSand: [35, 18, 45],
	BConsts.cDesert: [40, 22, 25],
	BConsts.cGrass: [12, 25, 50],
	BConsts.cSavanna: [35, 18, 42],
	BConsts.cForest: [10, 30, 38],
	BConsts.cSeasonalForest: [20, 16, 45],
	BConsts.cBorealForest: [12, 18, 32],
	BConsts.cRainForest: [22, 40, 28],
	BConsts.cRock: [22, 22, 25],
	BConsts.cTundra: [15, 18, 28],
	BConsts.cSnow: [35, 35, 45],
}

# Region-specific tint colors to make each region feel unique
const REGION_TINTS: Dictionary = {
	"starting_realm": Color(0.7, 0.6, 1.0),      # purple-blue fringe
	"feline_courts": Color(0.9, 0.65, 0.5),       # warm amber
	"canine_order": Color(0.5, 0.6, 0.9),         # steel blue
	"fairy_realms": Color(0.5, 0.9, 0.7),         # emerald green
	"goblin_warrens": Color(0.8, 0.6, 0.3),       # dingy orange
	"knight_kingdoms": Color(0.9, 0.8, 0.5),      # golden
	"deep_space": Color(0.4, 0.4, 0.7),           # deep indigo
	"shattered_prides": Color(0.9, 0.5, 0.4),     # red-orange
	"iron_expanse": Color(0.6, 0.65, 0.7),        # iron grey-blue
	"twilight_bazaar": Color(0.8, 0.5, 0.8),      # magenta
	"warp_marches": Color(0.6, 0.3, 0.9),         # violet warp
}

# ---------------------------------------------------------------------------
# Cached textures
# ---------------------------------------------------------------------------
var _nav_texture: ImageTexture = null
var _nav_region: String = ""
var _nav_offset: Vector2 = Vector2.ZERO
var _nav_size: Vector2i = Vector2i(640, 360)

var _codex_texture: ImageTexture = null
var _codex_seed: int = -1


func _ready() -> void:
	pass


# ---------------------------------------------------------------------------
# Navigation nebula backdrop
# ---------------------------------------------------------------------------

## Generate or update the navigation background texture.
## Returns an ImageTexture sized to camera_size, offset by world position.
## Uses low resolution for performance since it's a background layer.
func get_nav_texture(region_id: String, camera_size: Vector2i) -> ImageTexture:
	if _nav_texture != null and _nav_region == region_id and _nav_size == camera_size:
		return _nav_texture

	var seed_val: int = REGION_SEEDS.get(region_id, hash(region_id))
	var ds: ProceduralWorldDatasource = _create_datasource(seed_val, SPACE_COLORS)
	var render_size := Vector2i(camera_size.x / 4, camera_size.y / 4)  # Quarter res for perf

	ds.offset = Vector2.ZERO
	ds.zoom = 2.5

	_nav_texture = ds.get_biome_image(render_size)
	_nav_region = region_id
	_nav_size = camera_size
	_cleanup_datasource(ds)
	return _nav_texture


## Get the tint color for a region's nebula backdrop.
func get_region_tint(region_id: String) -> Color:
	return REGION_TINTS.get(region_id, Color(0.6, 0.6, 0.8))


# ---------------------------------------------------------------------------
# Celestial Codex (star map) backdrop
# ---------------------------------------------------------------------------

## Generate a galaxy-scale backdrop texture for the Celestial Codex.
## Uses a fixed galactic seed with brighter colors.
func get_codex_texture(seed_val: int, render_size: Vector2i, zoom: float = 5.0, offset: Vector2 = Vector2.ZERO) -> ImageTexture:
	if _codex_texture != null and _codex_seed == seed_val:
		return _codex_texture

	var ds: ProceduralWorldDatasource = _create_datasource(seed_val, GALAXY_COLORS)
	ds.offset = offset
	ds.zoom = zoom

	_codex_texture = ds.get_biome_image(render_size)
	_codex_seed = seed_val
	_cleanup_datasource(ds)
	return _codex_texture


## Force regenerate codex texture (e.g. when switching layers/regions).
func generate_codex_texture(seed_val: int, render_size: Vector2i, zoom: float, offset: Vector2) -> ImageTexture:
	_codex_seed = -1  # Invalidate cache
	return get_codex_texture(seed_val, render_size, zoom, offset)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _create_datasource(seed_val: int, color_map: Dictionary) -> ProceduralWorldDatasource:
	var ds: ProceduralWorldDatasource = SessionFactory.create_Fastnoiselite_datasource(seed_val)
	ds.custom_color_map = color_map
	return ds


func _cleanup_datasource(ds: ProceduralWorldDatasource) -> void:
	# Datasources extend Node but are never added to the tree.
	# Clean up the area_info_cache entries (also Nodes) then free.
	if "area_info_cache" in ds:
		for ai in ds.area_info_cache:
			if ai != null and is_instance_valid(ai):
				ai.free()
		ds.area_info_cache.clear()
	ds.free()


