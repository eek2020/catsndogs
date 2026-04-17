## ProceduralMapManager — autoload that provides procedural map textures
## for navigation backgrounds, star map overlays, and planet surfaces.
##
## Uses the ProceduralWorldMap plugin with custom color palettes per context.
extends Node

const SessionFactory = preload("res://addons/procedural_world_map/session_factory.gd")
const FNLD = preload("res://addons/procedural_world_map/fastnoiselite_datasource.gd")
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

# Per-biome tint multiplier — layered on top of region tint so pockets of
# different biomes show local variation. Values hover around 1.0 so they
# nudge rather than replace the region's character.
const BIOME_TINTS: Dictionary = {
	BConsts.cDeepWater: Color(0.60, 0.65, 0.90),      # void — cooler, darker
	BConsts.cShallowWater: Color(0.75, 0.80, 1.05),   # near-void — cool blue
	BConsts.cSand: Color(1.15, 0.85, 1.00),           # warm wisp
	BConsts.cDesert: Color(1.30, 0.85, 0.70),         # warm dust lane
	BConsts.cGrass: Color(0.85, 1.00, 1.15),          # cool cloud
	BConsts.cSavanna: Color(1.10, 0.90, 1.05),        # purple haze
	BConsts.cForest: Color(0.80, 1.05, 1.05),         # teal
	BConsts.cSeasonalForest: Color(0.90, 0.85, 1.15), # indigo
	BConsts.cBorealForest: Color(0.80, 0.95, 1.05),   # steel
	BConsts.cRainForest: Color(0.85, 1.20, 0.90),     # green glow
	BConsts.cRock: Color(1.05, 1.00, 0.95),           # asteroid field — neutral warm
	BConsts.cTundra: Color(0.90, 0.95, 1.05),         # cold
	BConsts.cSnow: Color(1.15, 1.15, 1.20),           # bright core
}

# World-to-noise scaling. The original texture path baked this at "render
# size = camera/4"; keeping the same ratio means a 1280x720 screen samples
# a 320x180 patch of noise, so one world unit == 0.25 noise units.
const NAV_NOISE_SCALE: float = 0.25

# Regenerate the nav texture when the ship has drifted this far in world
# units since the last generation. Chosen so that regen happens roughly
# once per second at SHIP_SPEED = 300.
const NAV_REGEN_THRESHOLD: float = 256.0

const NAV_ZOOM: float = 2.5

# ---------------------------------------------------------------------------
# Cached state
# ---------------------------------------------------------------------------

# Nav datasources stay resident (one per region visited) so point-sampling
# via sample_biome() is O(1). Textures regenerate on movement threshold.
var _nav_datasources: Dictionary = {}  # region_id -> ProceduralWorldDatasource

var _nav_texture: ImageTexture = null
var _nav_texture_region: String = ""
var _nav_texture_size: Vector2i = Vector2i.ZERO
var _nav_texture_center_world: Vector2 = Vector2.ZERO
var _nav_texture_valid: bool = false

var _codex_texture: ImageTexture = null
var _codex_seed: int = -1


func _ready() -> void:
	pass


func _exit_tree() -> void:
	# Resident datasources live as children of this autoload, so Godot
	# frees them automatically. We just need to drain their area_info
	# caches — those are manually-allocated Nodes that the datasource
	# does not auto-free on its own teardown.
	for region_id in _nav_datasources.keys():
		var ds = _nav_datasources[region_id]
		if ds != null and is_instance_valid(ds):
			_reset_area_info_cache(ds)
	_nav_datasources.clear()


# ---------------------------------------------------------------------------
# Navigation nebula backdrop
# ---------------------------------------------------------------------------

## Generate or update the navigation background texture.
## Returns an ImageTexture sized to render_size (camera/4), sampled at
## world_pos. The texture regenerates when the region changes, the camera
## resizes, or the ship has drifted past NAV_REGEN_THRESHOLD since the last
## generation. Callers stretch the returned texture across the screen.
func get_nav_texture(
	region_id: String,
	camera_size: Vector2i,
	world_pos: Vector2 = Vector2.ZERO,
) -> ImageTexture:
	var ds: ProceduralWorldDatasource = _ensure_nav_datasource(region_id)
	var needs_regen := (
		not _nav_texture_valid
		or _nav_texture_region != region_id
		or _nav_texture_size != camera_size
		or (world_pos - _nav_texture_center_world).length() > NAV_REGEN_THRESHOLD
	)
	if not needs_regen:
		return _nav_texture

	@warning_ignore("integer_division")
	var render_size := Vector2i(maxi(camera_size.x / 4, 1), maxi(camera_size.y / 4, 1))
	# Center the sampled noise rect on the player's world position.
	var half_noise := Vector2(render_size) * 0.5
	ds.offset = world_pos * NAV_NOISE_SCALE - half_noise
	ds.zoom = NAV_ZOOM

	_nav_texture = ds.get_biome_image(render_size)
	_reset_area_info_cache(ds)
	_nav_texture_region = region_id
	_nav_texture_size = camera_size
	_nav_texture_center_world = world_pos
	_nav_texture_valid = true
	return _nav_texture


## Get the tint color for a region's nebula backdrop.
func get_region_tint(region_id: String) -> Color:
	return REGION_TINTS.get(region_id, Color(0.6, 0.6, 0.8))


## Sample the biome field at a world-space position. Deterministic given a
## region seed: the same (region_id, world_x, world_y) always returns the
## same biome. Keeps the per-region datasource resident so repeated calls
## are cheap.
##
## Returns: { biome_id: int, biome_tint: Color }
func sample_biome(region_id: String, world_x: float, world_y: float) -> Dictionary:
	var ds: ProceduralWorldDatasource = _ensure_nav_datasource(region_id)
	# Point-sample: use the generators' absolute noise coords, bypassing
	# the datasource's `offset` field so concurrent texture generation
	# doesn't perturb gameplay samples.
	var nx: float = world_x * NAV_NOISE_SCALE
	var ny: float = world_y * NAV_NOISE_SCALE
	var gens: Array = ds.noise_generators
	# NB: FastNoiseLite applies its own `offset` Vector3 on top of our
	# inputs. We absorb that by subtracting the current offset so the
	# call is position-pure.
	var off: Vector3 = gens[0].offset
	var sx: float = nx - off.x
	var sy: float = ny - off.y
	var main_height: int = _noise_byte(gens[FNLD.noise_idx_main_elevation].get_noise_2d(sx, sy))
	var height: int = _noise_byte(gens[FNLD.noise_idx_elevation].get_noise_2d(sx, sy))
	var heat: int = _noise_byte(gens[FNLD.noise_idx_heat].get_noise_2d(sx, sy))
	var moisture: int = _noise_byte(gens[FNLD.noise_idx_moisture].get_noise_2d(sx, sy))
	var biome_id: int = _classify_biome(main_height, height, heat, moisture)
	return {
		"biome_id": biome_id,
		"biome_tint": BIOME_TINTS.get(biome_id, Color(1.0, 1.0, 1.0)),
	}


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


func _ensure_nav_datasource(region_id: String) -> ProceduralWorldDatasource:
	if _nav_datasources.has(region_id):
		return _nav_datasources[region_id]
	var seed_val: int = REGION_SEEDS.get(region_id, hash(region_id))
	var ds: ProceduralWorldDatasource = _create_datasource(seed_val, SPACE_COLORS)
	ds.zoom = NAV_ZOOM
	# Reparent into the scene tree so Godot frees the Node on autoload
	# teardown — otherwise GUT flags it as an orphan every test.
	ds.name = "nav_ds_%s" % region_id
	add_child(ds)
	_nav_datasources[region_id] = ds
	return ds


## Free only the area_info cache on a resident datasource. The datasource
## itself is kept alive so the noise generators stay configured.
func _reset_area_info_cache(ds: ProceduralWorldDatasource) -> void:
	if "area_info_cache" in ds:
		for ai in ds.area_info_cache:
			if ai != null and is_instance_valid(ai):
				ai.free()
		ds.area_info_cache.clear()


func _cleanup_datasource(ds: ProceduralWorldDatasource) -> void:
	# Datasources extend Node but are never added to the tree.
	# Clean up the area_info_cache entries (also Nodes) then free.
	if "area_info_cache" in ds:
		for ai in ds.area_info_cache:
			if ai != null and is_instance_valid(ai):
				ai.free()
		ds.area_info_cache.clear()
	ds.free()


## Map a [-1, 1] noise sample to a [0, 255] byte. Mirrors what
## FastNoiseLite.get_image() writes into the PackedByteArray the existing
## classifier reads, so point samples match image samples byte-for-byte
## (modulo FP rounding).
func _noise_byte(v: float) -> int:
	return clampi(int(round((v * 0.5 + 0.5) * 255.0)), 0, 255)


## Biome classifier — mirrors
## FastNoiseLiteDatasource.get_biome_buffer() so texture pixels and
## point-sampled biomes agree on which biome each (x, y) belongs to.
func _classify_biome(_main_height: int, height: int, heat: int, moisture: int) -> int:
	var biome_idx: int
	if height < BConsts.altSand:
		if height < BConsts.altDeepWater:
			biome_idx = BConsts.cDeepWater
		elif height < BConsts.altShallowWater:
			biome_idx = BConsts.cShallowWater
		else:
			if heat < BConsts.COLDER:
				biome_idx = BConsts.cTundra
			elif heat < BConsts.WARMER:
				biome_idx = BConsts.cGrass
			else:
				if moisture < BConsts.DRYER:
					biome_idx = BConsts.cDesert
				elif moisture < BConsts.WET:
					biome_idx = BConsts.cSavanna
				else:
					biome_idx = BConsts.cGrass
	elif height < BConsts.altForest:
		if heat < BConsts.COLDEST:
			biome_idx = BConsts.cSnow
		elif heat < BConsts.COLDER:
			biome_idx = BConsts.cTundra
		elif heat < BConsts.COLD:
			if moisture < BConsts.DRYER:
				biome_idx = BConsts.cGrass
			elif moisture < BConsts.DRY:
				biome_idx = BConsts.cForest
			else:
				biome_idx = BConsts.cBorealForest
		elif heat < BConsts.WARMER:
			if moisture < BConsts.DRYER:
				biome_idx = BConsts.cGrass
			elif moisture < BConsts.WET:
				biome_idx = BConsts.cForest
			elif moisture < BConsts.WETTER:
				biome_idx = BConsts.cSeasonalForest
			else:
				biome_idx = BConsts.cRainForest
		else:
			if moisture < BConsts.DRYER:
				biome_idx = BConsts.cDesert
			elif moisture < BConsts.WET:
				biome_idx = BConsts.cSavanna
			else:
				biome_idx = BConsts.cRainForest
	elif height < BConsts.altRock:
		biome_idx = BConsts.cRock
	else:
		biome_idx = BConsts.cSnow
	return biome_idx
