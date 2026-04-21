## Navigation screen — main gameplay view with ship movement and HUD.
## Mirrors Python ui/navigation.py NavigationState.
extends Control

@onready var arc_label: Label = $HUD/TopBar/Row1/ArcLabel
@onready var region_label: Label = $HUD/TopBar/Row1/RegionLabel
@onready var crystals_label: Label = $HUD/TopBar/Row1/CrystalsLabel
@onready var salvage_label: Label = $HUD/TopBar/Row1/SalvageLabel
@onready var hull_bar: HullBar = $HUD/TopBar/Row1/HullBar
@onready var hull_label: Label = $HUD/TopBar/Row1/HullLabel
@onready var crew_label: Label = $HUD/TopBar/Row1/CrewLabel
@onready var morale_pip: MoralePip = $HUD/TopBar/Row1/MoralePip
@onready var karma_label: Label = $HUD/TopBar/Row1/KarmaLabel
@onready var objective_label: Label = $HUD/TopBar/ObjectiveLabel
@onready var flash_label: Label = $HUD/FlashLabel

var _vm: NavigationViewModel = null
var _flash_timer: float = 0.0
var _poi_refresh_timer: float = 0.0
var _elapsed: float = 0.0
var _planet_textures: Dictionary = {}  # Cache: image name -> Texture2D
var _starbase_textures: Dictionary = {}  # Cache: image name -> Texture2D

const POI_REFRESH_INTERVAL: float = 1.5
const SHIP_SPEED: float = 300.0
const SHIP_DRAW_SIZE := Vector2(72.0, 72.0)
const SHIP_COLLISION_RADIUS: float = 24.0
const POI_RADIUS: float = 38.0
const STAR_COUNT: int = 180
const STARFIELD_AREA: float = 4200.0

# Minimap
const MINIMAP_SIZE: int = 150
const MINIMAP_MARGIN: int = 16
const MINIMAP_WORLD_RANGE: float = 2400.0  # World units visible in minimap

const ENCOUNTER_TYPE_COLORS := {
	"combat": Color(1.0, 0.2, 0.2),
	"diplomatic": Color(0.45, 0.8, 1.0),
	"exploration": Color(0.5, 1.0, 0.62),
	"trade": Color(0.52, 1.0, 0.35),
	"event": Color(0.82, 0.55, 1.0),
	"distress_signal": Color(1.0, 0.62, 0.35),
	"rescue": Color(1.0, 0.62, 0.35),
	"story": Color(1.0, 0.82, 0.25),
	"hidden": Color(0.75, 0.4, 1.0),
	"treasure": Color(0.75, 0.4, 1.0),
	"abandoned_ship": Color(0.75, 0.4, 1.0),
	"crystal_hoard": Color(0.75, 0.4, 1.0),
}

# Biome preferences per encounter type. Empty / missing entries mean "any
# biome is fine" and placement falls through to uniform randomness.
# Biome IDs map to `addons/procedural_world_map/biome_constants.gd`.
const BIOME_PREFERENCES := {
	# Wrecks and crystal hoards make sense in asteroid fields / void.
	"treasure": [10, 0],              # cRock, cDeepWater
	"abandoned_ship": [10, 0, 1],     # cRock, cDeepWater, cShallowWater
	"crystal_hoard": [10, 12],        # cRock, cSnow (bright core)
	# Distress signals broadcast from empty void, away from dense clouds.
	"distress_signal": [0, 1],        # cDeepWater, cShallowWater
	"rescue": [0, 1],
	# Exploration encounters favour nebula pockets.
	"exploration": [6, 7, 8, 9],      # forests: nebula pockets
	# Hidden locations hide in dense clouds.
	"hidden": [6, 9, 12],             # cForest, cRainForest, cSnow core
}

const BIOME_SPAWN_CANDIDATES: int = 16

# Biomes where the nebula is dense enough to obscure the scanner. Matches
# the palette entries that read as "thick cloud" visually in SPACE_COLORS.
# Values are biome IDs from addons/procedural_world_map/biome_constants.gd.
const DENSE_NEBULA_BIOMES := [6, 9, 12]  # cForest, cRainForest, cSnow
const DENSE_NEBULA_SCAN_MULT: float = 0.6

var _in_dense_nebula: bool = false

# Fog of war
const FOG_COLOR := Color(0.02, 0.03, 0.05, 0.85)
const FOG_CHUNK_SIZE: int = 4  # Render fog in chunks of N cells for performance

# Boundary transition
const BOUNDARY_MARGIN: float = 100.0
const POI_BOUNDARY_PADDING: float = 150.0  # Keep POIs this far inside region bounds
var _boundary_prompt_region: String = ""
var _boundary_prompt_timer: float = 0.0

var _ship_texture: Texture2D = preload("res://assets/ships/ship_r_side.png")
var _ship_up_texture: Texture2D = preload("res://assets/ships/ship_up_side.png")
var _ship_rotate_texture: Texture2D = preload("res://assets/ships/ship_rotate.png")
var _active_pois: Array = []
var _stars: Array = []

# Ship orientation state
var _facing_right: bool = true
var _flip_progress: float = 1.0   # 0 = mid-flip (edge-on), 1 = fully facing
var _bank_angle: float = 0.0      # Current banking tilt in radians
var _vertical_blend: float = 0.0  # 0 = side sprite, 1 = top-down sprite
var _heading_angle: float = 0.0   # Smoothed heading for trail/minimap
var _is_moving: bool = false

# Star map POIs (story locations, hidden locations, random spawns)
var _story_pois: Array = []
var _hidden_pois: Array = []
var _spawn_pois: Array = []

# Astral hazard state
var _visible_hazards: Array = []
var _off_course_drift: Vector2 = Vector2.ZERO

# Star base docking
var _nearby_base_id: String = ""

# Planet landing
var _nearby_planet_id: String = ""
const FRINGE_HAVEN_PLANET_ID: String = "fringe_haven"
const FRINGE_HAVEN_SCENE_PATH: String = "res://scenes/world/fringe_haven_3d.tscn"

const FLIP_SPEED: float = 6.0
const BANK_MAX_ANGLE: float = 0.30       # ~17 degrees max banking tilt
const BANK_SPEED: float = 8.0
const VERTICAL_BLEND_SPEED: float = 5.0

# Engine trail particles: Array of {x, y, life, max_life}
var _trail: Array = []

# Procedural nebula backdrop
var _nebula_texture: ImageTexture = null
var _nebula_tint: Color = Color(0.6, 0.6, 0.8)
var _nebula_local_tint: Color = Color(1.0, 1.0, 1.0)  # biome modulator, eased toward target
const NEBULA_TINT_LERP_SPEED: float = 2.0


# Distress signals handled by SideMissionSystem.update_distress()

# First-run welcome
var _showed_welcome: bool = false
# Sprint 6c: three-step first-navigation tutorial. Each entry is the flash
# message shown after the cumulative `_elapsed` for that step. Once the final
# step has fired, `_tutorial_step` sits past the last index and nothing more
# shows. Only runs on a session that has never completed an encounter, so
# veterans and loaded saves skip it.
const TUTORIAL_STEPS: Array = [
	{"at": 0.0, "text": "WASD or left stick to move", "duration": 4.0},
	{"at": 5.0, "text": "Fly toward coloured markers to start an encounter", "duration": 5.0},
	{"at": 12.0, "text": "TAB (or RB on a gamepad) opens the galaxy map", "duration": 5.0},
]
var _tutorial_step: int = 0
var _tutorial_elapsed: float = 0.0

# Sprint 6c game feel: _hit_flash_timer > 0 draws a red full-screen overlay
# in `_draw`, decayed over HIT_FLASH_DURATION seconds. EventBus.hazard_damage
# bumps it.
const HIT_FLASH_DURATION: float = 0.35
var _hit_flash_timer: float = 0.0


## Test seam: callers may inject a view model before the scene enters the tree.
## Production path leaves `_vm` null and `_ready` builds one from the GameSession
## autoload.
func initialize(vm: NavigationViewModel) -> void:
	_vm = vm


func _ready() -> void:
	if _vm == null:
		_vm = NavigationViewModel.new(GameSession)
	_ship_texture = _remove_background_by_corners(_ship_texture)
	_ship_up_texture = _remove_background_by_corners(_ship_up_texture)
	_ship_rotate_texture = _remove_background_by_corners(_ship_rotate_texture)
	_build_starfield()
	_refresh_nebula()
	flash_label.text = ""
	_poi_refresh_timer = 0.0
	_refresh_pois()
	_update_hud()
	EventBus.arc_advanced.connect(_on_arc_advanced)
	# Sprint 5c — map-shaking events get a flash so the player sees conquest actually happening.
	EventBus.realm_control_changed.connect(_on_realm_control_changed)
	# Sprint 6c game feel — red hit flash when a hazard takes a bite out of the hull.
	EventBus.hazard_damage.connect(_on_hazard_damage)


static func _remove_background_by_corners(tex: Texture2D, tolerance: float = 0.13, feather: float = 0.05) -> Texture2D:
	"""Remove solid background colour detected from corner pixels."""
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
	for y in h:
		for x in w:
			var px: Color = image.get_pixel(x, y)
			var delta: float = maxf(absf(px.r - bg.r), maxf(absf(px.g - bg.g), absf(px.b - bg.b)))
			if delta <= tolerance:
				image.set_pixel(x, y, Color(px.r, px.g, px.b, 0.0))
			elif delta <= tolerance + feather:
				var alpha_scale: float = (delta - tolerance) / feather
				image.set_pixel(x, y, Color(px.r, px.g, px.b, px.a * alpha_scale))
	return ImageTexture.create_from_image(image)


func _build_starfield() -> void:
	_stars.clear()
	for i in STAR_COUNT:
		_stars.append({
			"x": randf_range(-STARFIELD_AREA * 0.5, STARFIELD_AREA * 0.5),
			"y": randf_range(-STARFIELD_AREA * 0.5, STARFIELD_AREA * 0.5),
			"depth": [0.2, 0.35, 0.55, 0.8, 1.0][randi() % 5],
		})


func _refresh_nebula() -> void:
	if not _vm.has_state():
		return
	var gs: GameStateData = _vm.state()
	var region_id: String = _vm.current_region()
	var cam_size := Vector2i(int(size.x), int(size.y))
	if cam_size.x <= 0 or cam_size.y <= 0:
		cam_size = Vector2i(1280, 720)
	var world_pos := Vector2(gs.position_x, gs.position_y)
	_nebula_texture = ProceduralMapManager.get_nav_texture(region_id, cam_size, world_pos)
	_nebula_tint = ProceduralMapManager.get_region_tint(region_id)
	var sample: Dictionary = ProceduralMapManager.sample_biome(region_id, gs.position_x, gs.position_y)
	var target_tint: Color = sample.get("biome_tint", Color(1.0, 1.0, 1.0))
	var dt: float = get_process_delta_time()
	var t: float = clampf(dt * NEBULA_TINT_LERP_SPEED, 0.0, 1.0)
	_nebula_local_tint = _nebula_local_tint.lerp(target_tint, t)


func _has_overlay() -> bool:
	var main: Control = get_tree().current_scene
	if main and main.has_method("has_active_overlay"):
		return main.has_active_overlay()
	return false


func _process(dt: float) -> void:
	if not _vm.has_state():
		return
	_elapsed += dt
	# Pause gameplay when overlays (dialogue, combat, etc.) are open
	if not _has_overlay():
		_handle_movement(dt)
		_update_trail(dt)
		_update_poi_timer(dt)
		_update_distress(dt)
		_update_star_map_spawns(dt)
		_update_astral_hazards(dt)
		_check_poi_collisions()
		_check_star_map_poi_collisions()
		_check_base_proximity()
		_check_planet_proximity()
		_check_boundary(_vm.state(), _vm.region_bounds(_vm.current_region()))
	else:
		_update_trail(dt)  # Let trail fade while paused
	_update_flash(dt)
	_update_hud()
	_show_welcome()
	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - dt)
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

		# Apply off-course drift from singularity status effect
		var ahs: AstralHazardSystem = _vm.astral_hazards()
		if ahs != null and ahs.has_active_effect("off_course"):
			_off_course_drift = _off_course_drift.rotated(randf_range(-0.3, 0.3) * dt * 10.0)
			if _off_course_drift.length() < 0.01:
				_off_course_drift = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 0.4
			direction = (direction + _off_course_drift * 0.5).normalized()
		else:
			_off_course_drift = Vector2.ZERO

		var region_id: String = _vm.current_region()
		var bounds: Vector2 = _vm.region_bounds(region_id)
		var new_pos: Vector2 = _vm.position() + direction * SHIP_SPEED * dt
		new_pos.x = clampf(new_pos.x, 0.0, bounds.x)
		new_pos.y = clampf(new_pos.y, 0.0, bounds.y)
		_vm.set_position(new_pos)

		# Reveal fog around ship (halved when fog_blind, further reduced in
		# dense nebula pockets — the scanner genuinely loses range in thick
		# clouds, which creates a reason to navigate *around* them).
		var reveal_radius: float = 300.0
		if ahs != null and ahs.has_active_effect("fog_blind"):
			reveal_radius = 150.0
		var scan_biome: Dictionary = ProceduralMapManager.sample_biome(
			region_id, new_pos.x, new_pos.y
		)
		var scan_biome_id: int = int(scan_biome.get("biome_id", -1))
		var now_dense: bool = scan_biome_id in DENSE_NEBULA_BIOMES
		if now_dense:
			reveal_radius *= DENSE_NEBULA_SCAN_MULT
		if now_dense != _in_dense_nebula:
			_in_dense_nebula = now_dense
			EventBus.exploration_event.emit({
				"type": "dense_nebula_entered" if now_dense else "dense_nebula_cleared",
				"region_id": region_id,
				"biome_id": scan_biome_id,
			})
		_vm.reveal_around(region_id, new_pos.x, new_pos.y, reveal_radius)

		# --- Horizontal flip detection ---
		if direction.x > 0.01 and not _facing_right:
			_facing_right = true
			_flip_progress = 0.0
		elif direction.x < -0.01 and _facing_right:
			_facing_right = false
			_flip_progress = 0.0

		# --- Banking tilt based on vertical movement ---
		var bank_target: float = direction.y * BANK_MAX_ANGLE
		# Invert bank when facing left so tilt feels natural
		if not _facing_right:
			bank_target = -bank_target
		_bank_angle += (bank_target - _bank_angle) * minf(1.0, dt * BANK_SPEED)

		# --- Vertical blend (side sprite <-> top-down sprite) ---
		var abs_x: float = absf(direction.x)
		var abs_y: float = absf(direction.y)
		var vert_dominance: float = abs_y / maxf(abs_x + abs_y, 0.001)
		# Only blend toward top-down when movement is mostly vertical
		var blend_target: float = clampf((vert_dominance - 0.55) / 0.35, 0.0, 1.0)
		_vertical_blend += (blend_target - _vertical_blend) * minf(1.0, dt * VERTICAL_BLEND_SPEED)

		# --- Smoothed heading angle (for trail + minimap) ---
		var target_angle: float = atan2(direction.y, direction.x)
		var diff: float = fposmod(target_angle - _heading_angle + PI, TAU) - PI
		_heading_angle += diff * minf(1.0, dt * 10.0)

		# Spawn engine trail particles
		if randf() < 0.6:
			var trail_pos: Vector2 = _vm.position()
			var ex: float = trail_pos.x - cos(_heading_angle) * 18.0
			var ey: float = trail_pos.y - sin(_heading_angle) * 18.0
			var life: float = randf_range(0.5, 1.2)
			_trail.append({
				"x": ex + randf_range(-3.0, 3.0),
				"y": ey + randf_range(-3.0, 3.0),
				"life": life,
				"max_life": life,
			})
	else:
		# Idle: decay bank angle, let flip finish
		_bank_angle += (0.0 - _bank_angle) * minf(1.0, dt * BANK_SPEED)

	# Always animate flip progress toward 1.0 (even when idle)
	if _flip_progress < 1.0:
		_flip_progress = minf(_flip_progress + dt * FLIP_SPEED, 1.0)


func _update_trail(dt: float) -> void:
	var new_trail: Array = []
	for p in _trail:
		p["life"] -= dt
		if p["life"] > 0:
			new_trail.append(p)
	_trail = new_trail


func _update_poi_timer(dt: float) -> void:
	_poi_refresh_timer += dt
	if _poi_refresh_timer >= POI_REFRESH_INTERVAL:
		_poi_refresh_timer = 0.0
		_refresh_pois()


func _update_distress(dt: float) -> void:
	if not _vm.has_state():
		return
	var encounter: Encounter = _vm.update_distress(dt)
	if encounter == null:
		return
	var gs: GameStateData = _vm.state()
	var angle := randf() * TAU
	var distance := randf_range(500.0, 900.0)
	var clamped: Vector2 = _clamp_to_bounds(
		gs.position_x + cos(angle) * distance,
		gs.position_y + sin(angle) * distance,
	)
	var color: Color = ENCOUNTER_TYPE_COLORS.get("distress_signal", Color(1.0, 0.62, 0.35))
	_active_pois.append({
		"encounter": encounter,
		"x": clamped.x,
		"y": clamped.y,
		"radius": POI_RADIUS,
		"color": color,
	})
	flash("DISTRESS SIGNAL: %s" % encounter.title, 3.0)


func _refresh_pois() -> void:
	if not _vm.has_state():
		return
	var available: Array = _vm.available_encounters()
	var available_ids := {}
	for encounter in available:
		available_ids[encounter.encounter_id] = true

	var retained: Array = []
	for poi in _active_pois:
		var enc = poi.get("encounter")
		if enc != null and (available_ids.has(enc.encounter_id) or enc.encounter_type == "distress_signal"):
			retained.append(poi)
	_active_pois = retained

	for encounter in available:
		if _has_poi_for_encounter(encounter.encounter_id):
			continue
		_spawn_poi(encounter)


func _has_poi_for_encounter(encounter_id: String) -> bool:
	for poi in _active_pois:
		var enc = poi.get("encounter")
		if enc != null and enc.encounter_id == encounter_id:
			return true
	return false


## Clamp a world position to stay within region bounds with padding.
func _clamp_to_bounds(pos_x: float, pos_y: float) -> Vector2:
	var bounds: Vector2 = _vm.region_bounds(_vm.current_region())
	return Vector2(
		clampf(pos_x, POI_BOUNDARY_PADDING, bounds.x - POI_BOUNDARY_PADDING),
		clampf(pos_y, POI_BOUNDARY_PADDING, bounds.y - POI_BOUNDARY_PADDING),
	)


func _spawn_poi(encounter: Encounter) -> void:
	var gs: GameStateData = _vm.state()
	if gs == null:
		return
	# Check if this encounter has a fixed position on the star map
	var fixed_pos: Dictionary = _get_fixed_position(encounter.encounter_id, gs.current_region)
	var color: Color = ENCOUNTER_TYPE_COLORS.get(encounter.encounter_type, Color(1.0, 0.82, 0.45))
	if not fixed_pos.is_empty():
		color = ENCOUNTER_TYPE_COLORS.get("story", Color(1.0, 0.82, 0.25))
		_active_pois.append({
			"encounter": encounter,
			"x": fixed_pos.get("x", 0.0),
			"y": fixed_pos.get("y", 0.0),
			"radius": POI_RADIUS,
			"color": color,
			"fixed": true,
			"label": fixed_pos.get("label", encounter.title),
		})
	else:
		var pos: Vector2 = _pick_biome_spawn(
			encounter.encounter_type,
			gs.position_x,
			gs.position_y,
			gs.current_region,
		)
		_active_pois.append({
			"encounter": encounter,
			"x": pos.x,
			"y": pos.y,
			"radius": POI_RADIUS,
			"color": color,
		})


## Pick a spawn position for a dynamic POI. If the encounter type has a
## biome preference, rejection-sample up to BIOME_SPAWN_CANDIDATES times
## and return the first candidate that lands in a preferred biome. If none
## match, fall back to the first candidate so spawns never fail.
func _pick_biome_spawn(
	encounter_type: String,
	center_x: float,
	center_y: float,
	region_id: String,
) -> Vector2:
	var prefs: Array = BIOME_PREFERENCES.get(encounter_type, [])
	var first: Vector2 = _random_spawn_candidate(center_x, center_y)
	if prefs.is_empty():
		return first
	if _sample_biome_id(region_id, first.x, first.y) in prefs:
		return first
	for _i in range(BIOME_SPAWN_CANDIDATES - 1):
		var candidate: Vector2 = _random_spawn_candidate(center_x, center_y)
		if _sample_biome_id(region_id, candidate.x, candidate.y) in prefs:
			return candidate
	return first


func _random_spawn_candidate(center_x: float, center_y: float) -> Vector2:
	var angle := randf() * TAU
	var distance := randf_range(420.0, 960.0)
	return _clamp_to_bounds(
		center_x + cos(angle) * distance,
		center_y + sin(angle) * distance,
	)


func _sample_biome_id(region_id: String, world_x: float, world_y: float) -> int:
	var sample: Dictionary = ProceduralMapManager.sample_biome(region_id, world_x, world_y)
	return int(sample.get("biome_id", -1))


func _get_fixed_position(encounter_id: String, region_id: String) -> Dictionary:
	var map_def: Dictionary = _vm.region_map(region_id)
	for loc in map_def.get("story_locations", []):
		if loc.get("encounter_id", "") == encounter_id:
			return loc
	return {}


func _check_poi_collisions() -> void:
	var gs: GameStateData = _vm.state()
	if gs == null:
		return
	for poi in _active_pois.duplicate():
		var dx: float = poi["x"] - gs.position_x
		var dy: float = poi["y"] - gs.position_y
		var collision_distance: float = poi["radius"] + SHIP_COLLISION_RADIUS
		if (dx * dx + dy * dy) <= collision_distance * collision_distance:
			_active_pois.erase(poi)
			_on_encounter(poi["encounter"])
			break


func _check_base_proximity() -> void:
	if not _vm.has_state() or not _vm.has_star_base_system():
		_nearby_base_id = ""
		return
	var pos: Vector2 = _vm.position()
	_nearby_base_id = _vm.check_dock_proximity(pos.x, pos.y)
	if not _nearby_base_id.is_empty():
		var base: StarBase = _vm.get_base(_nearby_base_id)
		if base == null:
			return
		var reason: String = _vm.get_dock_block_reason(_nearby_base_id)
		if reason.is_empty():
			flash("[E] Dock at %s" % base.base_name, 0.5)
		else:
			# Sprint 5c — surface the gate reason so the player knows why E won't dock them.
			flash("%s: %s" % [base.base_name, reason], 0.5)


func _land_on_planet() -> void:
	if _nearby_planet_id.is_empty():
		return
	if _vm.land_on_planet(_nearby_planet_id):
		if _nearby_planet_id == FRINGE_HAVEN_PLANET_ID:
			get_tree().call_deferred("change_scene_to_file", FRINGE_HAVEN_SCENE_PATH)
			return
		var main: Control = get_tree().current_scene
		if main.has_method("switch_scene"):
			main.switch_scene("planet")


func _check_planet_proximity() -> void:
	if not _vm.has_state() or not _vm.has_planet_system():
		_nearby_planet_id = ""
		return
	var pos: Vector2 = _vm.position()
	_nearby_planet_id = _vm.check_landing_proximity(pos.x, pos.y)
	if not _nearby_planet_id.is_empty() and _nearby_base_id.is_empty():
		var planet: Planet = _vm.get_planet(_nearby_planet_id)
		if planet != null:
			flash("[L] Land on %s" % planet.planet_name, 0.5)


func _on_encounter(encounter) -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("push_overlay"):
		var dialogue_overlay = main.push_overlay("dialogue")
		if dialogue_overlay and dialogue_overlay.has_method("setup"):
			dialogue_overlay.setup(encounter)


func _update_star_map_spawns(dt: float) -> void:
	if not _vm.has_state():
		return
	var region_id: String = _vm.current_region()
	_vm.update_spawns(region_id, dt)
	# Refresh the visible spawn list
	_spawn_pois = _vm.visible_spawns(region_id)
	# Refresh story and hidden POIs — filter story POIs to only show
	# encounters whose trigger conditions are currently met, so the player
	# doesn't see interactive-looking markers they can't activate yet.
	var all_story: Array = _vm.visible_story_pois(region_id)
	var available: Array = _vm.available_encounters()
	var available_ids := {}
	for enc in available:
		available_ids[enc.encounter_id] = true
	# Also skip story POIs that already have an _active_pois entry to avoid
	# drawing duplicate markers at the same position.
	var active_enc_ids := {}
	for apoi in _active_pois:
		var enc = apoi.get("encounter")
		if enc != null:
			active_enc_ids[enc.encounter_id] = true
	var filtered_story: Array = []
	for poi in all_story:
		var eid: String = poi.get("encounter_id", "")
		if available_ids.has(eid) and not active_enc_ids.has(eid):
			filtered_story.append(poi)
	_story_pois = filtered_story
	_hidden_pois = _vm.visible_hidden_pois(region_id)
	# Update boundary prompt timer
	if _boundary_prompt_timer > 0:
		_boundary_prompt_timer -= dt


func _update_astral_hazards(dt: float) -> void:
	var gs: GameStateData = _vm.state()
	if gs == null:
		return
	var ahs: AstralHazardSystem = _vm.astral_hazards()
	if ahs == null:
		return
	var region_id: String = gs.current_region
	ahs.update(region_id, dt, gs)
	_visible_hazards = ahs.get_visible_hazards(region_id)
	# Check ship-hazard collisions
	var hit: Dictionary = ahs.check_ship_collision(region_id, gs.position_x, gs.position_y)
	if not hit.is_empty():
		var result: Dictionary = ahs.resolve_hazard(hit, gs)
		var bark: String = result.get("bark", "")
		if result.get("mitigated", false):
			flash(bark, 4.0)
		else:
			var dmg: int = result.get("damage", 0)
			var effect: Dictionary = result.get("status_effect", {})
			var msg: String = bark
			if dmg > 0:
				msg += "  Hull -%d" % dmg
			if not effect.is_empty():
				var eid: String = effect.get("effect_id", "")
				msg += "  [%s]" % eid.replace("_", " ").to_upper()
			flash(msg, 5.0)
		_update_hud()


func _check_star_map_poi_collisions() -> void:
	var gs: GameStateData = _vm.state()
	if gs == null:
		return
	
	# Check story POI collisions
	for poi in _story_pois:
		var dx: float = poi.get("x", 0.0) - gs.position_x
		var dy: float = poi.get("y", 0.0) - gs.position_y
		if (dx * dx + dy * dy) <= (POI_RADIUS + SHIP_COLLISION_RADIUS) * (POI_RADIUS + SHIP_COLLISION_RADIUS):
			var encounter_id: String = poi.get("encounter_id", "")
			if encounter_id != "":
				# Find and trigger the story encounter
				var encounters: Array = _vm.available_encounters()
				for enc in encounters:
					if enc.encounter_id == encounter_id:
						_on_encounter(enc)
						_story_pois.erase(poi)
						return
	
	# Check hidden location collisions
	for poi in _hidden_pois:
		var dx: float = poi.get("x", 0.0) - gs.position_x
		var dy: float = poi.get("y", 0.0) - gs.position_y
		if (dx * dx + dy * dy) <= (POI_RADIUS + SHIP_COLLISION_RADIUS) * (POI_RADIUS + SHIP_COLLISION_RADIUS):
			var poi_id: String = poi.get("poi_id", "")
			var rewards: Dictionary = poi.get("rewards", {})
			var crystals: int = rewards.get("crystals", 0)
			var salvage_val: int = rewards.get("salvage", 0)
			if crystals > 0:
				gs.crystal_inventory += crystals
			if salvage_val > 0:
				gs.salvage += salvage_val
			flash("DISCOVERED: %s (+%dC +%dS)" % [poi.get("label", "Hidden Cache"), crystals, salvage_val], 4.0)
			EventBus.hidden_location_discovered.emit(poi_id)
			# Remove from the star map hidden locations so it won't respawn
			var map_def: Dictionary = _vm.region_map(gs.current_region)
			var hidden_locs: Array = map_def.get("hidden_locations", [])
			for i in hidden_locs.size():
				if hidden_locs[i].get("poi_id", "") == poi_id:
					hidden_locs.remove_at(i)
					break
			_hidden_pois.erase(poi)
			break
	# Check spawn POI collisions (combat/rescue/trade)
	for poi in _spawn_pois:
		var dx: float = poi.get("x", 0.0) - gs.position_x
		var dy: float = poi.get("y", 0.0) - gs.position_y
		if (dx * dx + dy * dy) <= (POI_RADIUS + SHIP_COLLISION_RADIUS) * (POI_RADIUS + SHIP_COLLISION_RADIUS):
			var spawn_type: String = poi.get("type", "combat")
			# Find a matching available encounter for this type
			var encounters: Array = _vm.available_encounters()
			for enc in encounters:
				if enc.encounter_type == spawn_type or (spawn_type == "rescue" and enc.encounter_type == "distress_signal"):
					_vm.remove_spawn(gs.current_region, poi.get("poi_id", ""))
					_spawn_pois.erase(poi)
					_on_encounter(enc)
					return
			# If no matching encounter, just remove the spawn
			_vm.remove_spawn(gs.current_region, poi.get("poi_id", ""))
			_spawn_pois.erase(poi)
			flash("CONTACT: %s — but nothing found" % poi.get("label", "Unknown"), 2.0)
			break


func _check_boundary(gs: GameStateData, bounds: Vector2) -> void:
	var at_edge: bool = false
	var target_region: String = ""

	# Check edges
	if gs.position_x <= BOUNDARY_MARGIN or gs.position_x >= bounds.x - BOUNDARY_MARGIN:
		at_edge = true
	if gs.position_y <= BOUNDARY_MARGIN or gs.position_y >= bounds.y - BOUNDARY_MARGIN:
		at_edge = true

	if not at_edge:
		_boundary_prompt_region = ""
		return

	# Find connected regions
	var connected: Array = _vm.connected_regions(gs.current_region)

	if connected.is_empty():
		return

	# Pick the connected region whose galaxy position best matches the exit direction
	var exit_dir := Vector2.ZERO
	if gs.position_x <= BOUNDARY_MARGIN:
		exit_dir.x -= 1.0
	elif gs.position_x >= bounds.x - BOUNDARY_MARGIN:
		exit_dir.x += 1.0
	if gs.position_y <= BOUNDARY_MARGIN:
		exit_dir.y -= 1.0
	elif gs.position_y >= bounds.y - BOUNDARY_MARGIN:
		exit_dir.y += 1.0

	var sms: StarMapSystem = _vm.star_map()
	if sms != null and not sms.galaxy_layout.is_empty() and exit_dir.length() > 0.0:
		var current_gpos: Vector2 = sms.get_galaxy_node_pos(gs.current_region)
		var best_dot: float = -2.0
		exit_dir = exit_dir.normalized()
		for cid in connected:
			var cand_gpos: Vector2 = sms.get_galaxy_node_pos(cid)
			var delta: Vector2 = (cand_gpos - current_gpos).normalized()
			var dot: float = delta.dot(exit_dir)
			if dot > best_dot:
				best_dot = dot
				target_region = cid
	if target_region.is_empty():
		target_region = connected[0]
	if target_region != _boundary_prompt_region:
		_boundary_prompt_region = target_region
		_boundary_prompt_timer = 5.0
		var region_name: String = target_region.replace("_", " ").capitalize()
		flash("SECTOR BOUNDARY — Press ENTER to jump to %s" % region_name, 5.0)


func _perform_region_transition() -> void:
	if _boundary_prompt_region.is_empty():
		return
	var target: String = _boundary_prompt_region
	_boundary_prompt_region = ""
	_boundary_prompt_timer = 0.0
	var success: bool = _vm.travel_to_region(target)
	if success:
		_active_pois.clear()
		_story_pois.clear()
		_hidden_pois.clear()
		_spawn_pois.clear()
		_build_starfield()
		_nebula_texture = null  # Force nebula regeneration for new region
		_refresh_nebula()
		_refresh_pois()
		flash("Entered %s" % target.replace("_", " ").capitalize(), 3.0)
	else:
		flash("Cannot travel to that region yet", 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if _has_overlay():
		return
	if event.is_action_pressed("pause"):
		var main: Control = get_tree().current_scene
		if main.has_method("push_overlay"):
			main.push_overlay("pause")
	elif event.is_action_pressed("interact"):
		# Dock at nearby star base if in range
		if not _nearby_base_id.is_empty() and _vm.has_star_base_system():
			if _vm.can_dock(_nearby_base_id):
				_vm.dock(_nearby_base_id)
				var main2: Control = get_tree().current_scene
				if main2.has_method("push_overlay"):
					main2.push_overlay("station")
				return
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
	elif event.is_action_pressed("repair"):
		var main: Control = get_tree().current_scene
		if main.has_method("push_overlay"):
			main.push_overlay("purchase")
	elif event.is_action_pressed("star_map"):
		var main: Control = get_tree().current_scene
		if main.has_method("push_overlay"):
			main.push_overlay("star_map")
	elif event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		if not _nearby_planet_id.is_empty() and _vm.has_planet_system():
			_land_on_planet()
		elif not _boundary_prompt_region.is_empty() and _boundary_prompt_timer > 0:
			_perform_region_transition()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_L:
		if not _nearby_planet_id.is_empty() and _vm.has_planet_system():
			_land_on_planet()


func _update_hud() -> void:
	var gs: GameStateData = _vm.state()
	if gs == null:
		return
	var arc_title: String = _vm.arc_title()
	var progress: Dictionary = _vm.arc_progress()
	var done_count: int = 0
	var total_count: int = progress.size()
	for flag_name in progress:
		if progress[flag_name]:
			done_count += 1
	if total_count > 0:
		arc_label.text = "%s (%d/%d)" % [arc_title.to_upper(), done_count, total_count]
	else:
		arc_label.text = arc_title.to_upper()
	region_label.text = gs.current_region.replace("_", " ").capitalize()
	crystals_label.text = "Crystals: %d" % gs.crystal_inventory
	salvage_label.text = "Salvage: %d" % gs.salvage
	# Sprint 5c part 2 — segmented hull bar + numeric readout.
	var current_hull: int = _vm.hull_current()
	var max_hull: int = _vm.hull_max()
	if hull_bar != null:
		hull_bar.set_hull(current_hull, max_hull)
	hull_label.text = "%d/%d" % [current_hull, max_hull]
	# Sprint 5c part 2 — crew count + morale pip.
	crew_label.text = "Crew %d/%d" % [_vm.crew_count(), _vm.crew_capacity()]
	if morale_pip != null and _vm.has_crew_morale():
		morale_pip.set_morale(_vm.crew_morale_average())
		morale_pip.tooltip_text = _vm.crew_morale_label()
	# Sprint 5c part 2 — persistent objective surface (CODE_REVIEW §4.6, §5.3).
	if objective_label != null:
		objective_label.text = _vm.arc_objective()
	# Karma HUD
	if karma_label != null and _vm.has_karma_system():
		var tier_label_text: String = _vm.karma_tier_label()
		var color_hex: String = _vm.karma_tier_color()
		karma_label.text = "Karma: %s (%d)" % [tier_label_text, gs.karma]
		karma_label.add_theme_color_override("font_color", Color(color_hex))


func _show_welcome() -> void:
	# Session-scoped tutorial: skip if the player has already completed an
	# encounter in this save (via arc_progress) OR if the final step has fired.
	if _showed_welcome:
		return
	if _tutorial_step >= TUTORIAL_STEPS.size():
		_showed_welcome = true
		return
	if _has_completed_any_objective():
		_showed_welcome = true
		return
	_tutorial_elapsed += get_process_delta_time()
	var step: Dictionary = TUTORIAL_STEPS[_tutorial_step]
	if _tutorial_elapsed >= float(step.get("at", 0.0)):
		flash(str(step.get("text", "")), float(step.get("duration", 3.0)))
		_tutorial_step += 1


func _has_completed_any_objective() -> bool:
	var progress: Dictionary = _vm.arc_progress()
	for flag_name in progress:
		if progress[flag_name]:
			return true
	return false


func _on_hazard_damage(_hazard_id: String, _amount: int) -> void:
	_hit_flash_timer = HIT_FLASH_DURATION


func flash(message: String, duration: float = 3.0) -> void:
	flash_label.text = message
	_flash_timer = duration


func _update_flash(dt: float) -> void:
	if _flash_timer > 0:
		_flash_timer -= dt
		if _flash_timer <= 0:
			flash_label.text = ""


func on_return_from_encounter() -> void:
	_poi_refresh_timer = 0.0
	_refresh_pois()
	_update_hud()


func _on_arc_advanced(old_arc: String, new_arc: String) -> void:
	# Push the arc summary overlay (stats + hyperspace jump)
	var main: Control = get_tree().current_scene
	if main.has_method("push_overlay"):
		var overlay = main.push_overlay("arc_summary")
		if overlay and overlay.has_method("setup"):
			overlay.setup(old_arc, new_arc)
	# Refresh POIs when transition completes
	if not EventBus.arc_transition_complete.is_connected(_on_arc_transition_complete):
		EventBus.arc_transition_complete.connect(_on_arc_transition_complete)


func _on_arc_transition_complete(_new_arc: String) -> void:
	_poi_refresh_timer = 0.0
	_refresh_pois()
	_update_hud()
	if EventBus.arc_transition_complete.is_connected(_on_arc_transition_complete):
		EventBus.arc_transition_complete.disconnect(_on_arc_transition_complete)


## Sprint 5c — conquest surfacing. When a region's controller flips (either
## because a faction's attack won the region or they lost it), the player sees
## a flash so the conquest tick is not invisible.
func _on_realm_control_changed(region_id: String, old_controller: String, new_controller: String) -> void:
	if not _vm.has_state():
		return
	var gs: GameStateData = _vm.state()
	var old_name: String = _faction_display_name(gs, old_controller)
	var new_name: String = _faction_display_name(gs, new_controller)
	var pretty_region: String = region_id.replace("_", " ").capitalize()
	if old_controller.is_empty():
		flash("%s claimed by %s" % [pretty_region, new_name], 3.5)
	elif new_controller.is_empty():
		flash("%s slipped from %s" % [pretty_region, old_name], 3.5)
	else:
		flash("%s: %s → %s" % [pretty_region, old_name, new_name], 3.5)


func _faction_display_name(gs: GameStateData, faction_id: String) -> String:
	if faction_id.is_empty():
		return "unclaimed space"
	var faction: Faction = gs.faction_registry.get(faction_id)
	return faction.faction_name if faction != null else faction_id


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var gs: GameStateData = _vm.state()
	if gs == null:
		return

	var center := size * 0.5
	_draw_starfield(center, gs)
	_draw_fog_of_war(center, gs)
	_draw_hazards(center, gs)
	_draw_trail(center, gs)
	_draw_boundary_indicator(gs)
	_draw_star_map_pois(center, gs)
	_draw_planets(center, gs)
	_draw_star_bases(center, gs)
	_draw_pois(center, gs)
	_draw_ship(center)
	_draw_minimap(gs)
	_draw_status_effects()
	_draw_controls_bar()
	if _hit_flash_timer > 0.0:
		# Ease the alpha out quadratically so the flash reads as a sharp hit
		# followed by a quick fade, not a steady red wash.
		var t: float = _hit_flash_timer / HIT_FLASH_DURATION
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.2, 0.2, 0.35 * t * t))


func _draw_nebula(_gs: GameStateData) -> void:
	_refresh_nebula()
	if _nebula_texture == null:
		return
	# Region tint modulated by the locally-sampled biome tint, so dense
	# pockets of different biomes fade in visibly as the ship drifts across
	# them. Region tint holds the *character* of the region, biome tint adds
	# the per-location *texture*.
	var tint_color := Color(
		_nebula_tint.r * _nebula_local_tint.r,
		_nebula_tint.g * _nebula_local_tint.g,
		_nebula_tint.b * _nebula_local_tint.b,
		0.45,
	)
	draw_texture_rect(_nebula_texture, Rect2(Vector2.ZERO, size), false, tint_color)


func _draw_starfield(center: Vector2, gs: GameStateData) -> void:
	for star in _stars:
		var depth: float = star["depth"]
		var sx := fposmod(star["x"] - (gs.position_x * depth), STARFIELD_AREA) - STARFIELD_AREA * 0.5
		var sy := fposmod(star["y"] - (gs.position_y * depth), STARFIELD_AREA) - STARFIELD_AREA * 0.5
		var screen_pos := center + Vector2(sx, sy)
		if screen_pos.x < -2 or screen_pos.y < -2 or screen_pos.x > size.x + 2 or screen_pos.y > size.y + 2:
			continue
		var brightness := 0.62 + (depth * 0.33)
		var color := Color(brightness, brightness, brightness + 0.05, 0.9)
		draw_circle(screen_pos, maxf(1.0, depth * 2.2), color)


func _draw_trail(center: Vector2, gs: GameStateData) -> void:
	for p in _trail:
		var sx: float = center.x + (p["x"] - gs.position_x)
		var sy: float = center.y + (p["y"] - gs.position_y)
		var frac: float = p["life"] / p["max_life"]
		var alpha: float = frac * 0.78
		var radius: float = 2.0 + frac * 4.0
		draw_circle(Vector2(sx, sy), radius, Color(0.4, 0.7, 1.0, alpha))


func _draw_fog_of_war(center: Vector2, gs: GameStateData) -> void:
	var sms: StarMapSystem = _vm.star_map()
	if sms == null:
		return
	var region_id: String = gs.current_region
	var map_def: Dictionary = sms.region_maps.get(region_id, {})
	if map_def.is_empty():
		return
	var cell_size: int = map_def.get("fog_grid_size", 64)
	var dims: Vector2i = sms.grid_dimensions.get(region_id, Vector2i.ZERO)
	if dims == Vector2i.ZERO:
		return
	var grid: PackedByteArray = sms.fog_grids.get(region_id, PackedByteArray())
	if grid.size() == 0:
		return

	# Calculate visible world area
	var half_w: float = size.x * 0.5
	var half_h: float = size.y * 0.5
	var world_left: float = gs.position_x - half_w
	var world_top: float = gs.position_y - half_h
	var world_right: float = gs.position_x + half_w
	var world_bottom: float = gs.position_y + half_h

	# Convert to grid coordinates (chunked for performance)
	var chunk: int = cell_size * FOG_CHUNK_SIZE
	var g_left: int = maxi(0, int(world_left / chunk))
	var g_top: int = maxi(0, int(world_top / chunk))
	var g_right: int = mini(ceili(float(dims.x) / FOG_CHUNK_SIZE), ceili(world_right / chunk) + 1)
	var g_bottom: int = mini(ceili(float(dims.y) / FOG_CHUNK_SIZE), ceili(world_bottom / chunk) + 1)

	# Work per-cell for soft cloud-like edges everywhere.
	# First pass: find the minimum distance (in cells) from each hidden cell to the
	# nearest revealed cell within the visible range. We expand the scan area by a
	# margin so edge cells near the screen border are handled correctly.
	var soft_radius: int = 3  # cells within this distance of a revealed cell get soft treatment
	var margin: int = soft_radius + 1
	var c_left: int = maxi(0, int(world_left / cell_size) - margin)
	var c_top: int = maxi(0, int(world_top / cell_size) - margin)
	var c_right: int = mini(dims.x, ceili(world_right / cell_size) + margin)
	var c_bottom: int = mini(dims.y, ceili(world_bottom / cell_size) + margin)

	# Build a small local map of which cells are revealed in the visible area
	var local_w: int = c_right - c_left
	var local_h: int = c_bottom - c_top
	var revealed_map: PackedByteArray = PackedByteArray()
	revealed_map.resize(local_w * local_h)
	revealed_map.fill(0)
	for ly in range(local_h):
		for lx in range(local_w):
			if sms.is_cell_revealed(region_id, c_left + lx, c_top + ly):
				revealed_map[ly * local_w + lx] = 1

	# For each hidden cell, compute distance to nearest revealed cell (up to soft_radius)
	for ly in range(local_h):
		for lx in range(local_w):
			if revealed_map[ly * local_w + lx] == 1:
				continue  # revealed cell, skip
			var cx: int = c_left + lx
			var cy: int = c_top + ly
			var wx: float = cx * cell_size
			var wy: float = cy * cell_size
			var sx: float = center.x + (wx - gs.position_x)
			var sy: float = center.y + (wy - gs.position_y)
			# Skip cells fully off screen (with margin for glow)
			if sx + cell_size * 2 < 0 or sy + cell_size * 2 < 0 or sx - cell_size > size.x or sy - cell_size > size.y:
				continue

			# Find minimum distance to a revealed cell
			var min_dist: int = soft_radius + 1
			for scan_dy in range(-soft_radius, soft_radius + 1):
				var sly: int = ly + scan_dy
				if sly < 0 or sly >= local_h:
					continue
				for scan_dx in range(-soft_radius, soft_radius + 1):
					var slx: int = lx + scan_dx
					if slx < 0 or slx >= local_w:
						continue
					if revealed_map[sly * local_w + slx] == 1:
						var d: int = absi(scan_dx) + absi(scan_dy)
						if d < min_dist:
							min_dist = d

			if min_dist > soft_radius:
				# Deep interior — draw as a solid rectangle
				draw_rect(Rect2(sx, sy, cell_size, cell_size), FOG_COLOR)
			else:
				# Near the fog boundary — wispy blobs. Deterministic per-cell
				# hashes jitter the position, radius, and alpha so the 8-neighbor
				# grid doesn't read as a ring of uniform bubbles.
				var h1: float = fposmod(sin(float(cx) * 12.9898 + float(cy) * 78.233) * 43758.5453, 1.0)
				var h2: float = fposmod(sin(float(cx) * 39.3468 + float(cy) * 11.135) * 43758.5453, 1.0)
				var h3: float = fposmod(sin(float(cx) * 93.9898 + float(cy) * 67.345) * 43758.5453, 1.0)
				var jitter: Vector2 = Vector2(h1 - 0.5, h2 - 0.5) * cell_size * 0.45
				var cell_pos := Vector2(sx + cell_size * 0.5, sy + cell_size * 0.5) + jitter
				# t: 0.0 at boundary, 1.0 deep in fog
				var t: float = float(min_dist) / float(soft_radius)
				var base_alpha: float = lerpf(FOG_COLOR.a * 0.15, FOG_COLOR.a, t * t)
				var size_var: float = lerpf(0.75, 1.35, h3)
				var r: float = cell_size * lerpf(0.55, 0.9, t) * size_var
				var alpha_var: float = lerpf(0.7, 1.1, h2)
				var core_a: float = clampf(base_alpha * alpha_var, 0.0, 1.0)
				draw_circle(
					cell_pos,
					r * 1.5,
					Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, core_a * 0.3),
				)
				draw_circle(
					cell_pos,
					r,
					Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, core_a),
				)


func _draw_hazards(center: Vector2, gs: GameStateData) -> void:
	var ahs: AstralHazardSystem = _vm.astral_hazards()
	if ahs == null:
		return
	var default_font: Font = ThemeDB.fallback_font
	for hazard in _visible_hazards:
		var px: float = hazard.get("x", 0.0)
		var py: float = hazard.get("y", 0.0)
		var sx: float = center.x + (px - gs.position_x)
		var sy: float = center.y + (py - gs.position_y)
		var screen_pos := Vector2(sx, sy)
		var radius: float = hazard.get("zone_radius", 200.0)
		# Skip if fully off-screen (with generous margin for glow)
		if sx + radius < -100 or sy + radius < -100 or sx - radius > size.x + 100 or sy - radius > size.y + 100:
			continue
		var hazard_id: String = hazard.get("hazard_id", "")
		var defn: Dictionary = ahs.get_definition(hazard_id)
		var visual_type: String = defn.get("visual_type", "debris")
		var color_hex: String = defn.get("visual_color", "#FF5555")
		var base_color := Color(color_hex)
		var pulse: float = 1.0 + 0.15 * sin(_elapsed * 2.0 + px * 0.005)

		match visual_type:
			"light_burst":
				# Solar flare / supernova — pulsing radial glow
				for i in range(4, 0, -1):
					var ring_r: float = radius * (float(i) / 4.0) * pulse
					var alpha: float = 0.04 * (5 - i)
					draw_circle(screen_pos, ring_r, Color(base_color.r, base_color.g, base_color.b, alpha))
				# Radiating lines
				for j in 12:
					var angle: float = (TAU / 12.0) * j + _elapsed * 0.5
					var len_val: float = radius * 0.8 * pulse * randf_range(0.7, 1.0)
					var end_pos := screen_pos + Vector2(cos(angle), sin(angle)) * len_val
					draw_line(screen_pos, end_pos, Color(base_color.r, base_color.g, base_color.b, 0.12), 1.5)
				# Core
				draw_circle(screen_pos, 12.0 * pulse, Color(base_color.r, base_color.g, base_color.b, 0.5))
			"debris":
				# Asteroid field — scattered grey/brown circles
				var rng := RandomNumberGenerator.new()
				rng.seed = int(px * 1000 + py)
				for j in 18:
					var angle: float = rng.randf() * TAU
					var dist: float = rng.randf_range(20.0, radius * 0.9)
					var rock_r: float = rng.randf_range(3.0, 10.0)
					var jitter := Vector2(sin(_elapsed * 2.0 + j), cos(_elapsed * 1.5 + j)) * 3.0
					var rock_pos := screen_pos + Vector2(cos(angle), sin(angle)) * dist + jitter
					draw_circle(rock_pos, rock_r, Color(base_color.r, base_color.g, base_color.b, 0.35))
				# Warning ring
				draw_arc(screen_pos, radius * pulse, 0.0, TAU, 48, Color(base_color.r, base_color.g, base_color.b, 0.15), 2.0)
			"nebula":
				# Mana void — overlapping translucent purple circles
				var rng2 := RandomNumberGenerator.new()
				rng2.seed = int(px * 1000 + py)
				for j in 10:
					var angle: float = rng2.randf() * TAU
					var dist: float = rng2.randf_range(0.0, radius * 0.7)
					var cloud_r: float = rng2.randf_range(30.0, 80.0) * pulse
					var shimmer: float = 0.06 + 0.03 * sin(_elapsed * 3.0 + j * 0.7)
					var cloud_pos := screen_pos + Vector2(cos(angle), sin(angle)) * dist
					draw_circle(cloud_pos, cloud_r, Color(base_color.r, base_color.g, base_color.b, shimmer))
				draw_arc(screen_pos, radius, 0.0, TAU, 48, Color(base_color.r, base_color.g, base_color.b, 0.1), 1.5)
			"distortion":
				# Singularity — dark core with swirling rings
				draw_circle(screen_pos, radius * 0.3, Color(0.0, 0.0, 0.0, 0.6))
				for i in 5:
					var ring_r: float = radius * (0.3 + 0.15 * i) * pulse
					var ring_angle: float = _elapsed * (1.0 + i * 0.3)
					draw_arc(screen_pos, ring_r, ring_angle, ring_angle + TAU * 0.7, 36, Color(0.4, 0.3, 0.6, 0.12 - i * 0.02), 2.0)
				# Gravitational lens distortion lines
				for j in 8:
					var angle: float = (TAU / 8.0) * j + _elapsed * 0.8
					var start_pos := screen_pos + Vector2(cos(angle), sin(angle)) * radius * 0.4
					var end_pos := screen_pos + Vector2(cos(angle + 0.3), sin(angle + 0.3)) * radius * 0.9
					draw_line(start_pos, end_pos, Color(0.5, 0.4, 0.7, 0.08), 1.5)
			_:
				# Fallback — simple warning ring
				draw_arc(screen_pos, radius * pulse, 0.0, TAU, 48, Color(base_color.r, base_color.g, base_color.b, 0.2), 2.0)
				draw_circle(screen_pos, 8.0, Color(base_color.r, base_color.g, base_color.b, 0.4))

		# Warning ring border
		draw_arc(screen_pos, radius, 0.0, TAU, 48, Color(1.0, 0.3, 0.2, 0.08 + 0.04 * sin(_elapsed * 3.0)), 1.0)

		# Label
		if default_font:
			var label: String = hazard.get("label", defn.get("display_name", "HAZARD"))
			draw_string(default_font, screen_pos + Vector2(-30, -radius - 12), label, HORIZONTAL_ALIGNMENT_LEFT, 200, 11, Color(1.0, 0.5, 0.4, 0.7))


func _draw_star_map_pois(center: Vector2, gs: GameStateData) -> void:
	var default_font: Font = ThemeDB.fallback_font
	# Draw story POIs
	for poi in _story_pois:
		var px: float = poi.get("x", 0.0)
		var py: float = poi.get("y", 0.0)
		var sx: float = center.x + (px - gs.position_x)
		var sy: float = center.y + (py - gs.position_y)
		var screen_pos := Vector2(sx, sy)
		if screen_pos.x < -50 or screen_pos.y < -50 or screen_pos.x > size.x + 50 or screen_pos.y > size.y + 50:
			continue
		var color: Color = ENCOUNTER_TYPE_COLORS.get("story", Color(1.0, 0.82, 0.25))
		var pulse: float = 1.0 + 0.25 * sin(_elapsed * 2.5 + px * 0.01)
		# Star-shaped glow
		draw_circle(screen_pos, POI_RADIUS * 1.3 * pulse, color * Color(1, 1, 1, 0.08))
		draw_arc(screen_pos, POI_RADIUS * pulse, 0.0, TAU, 48, color, 2.5)
		draw_circle(screen_pos, 8.0 * pulse, color)
		# Diamond marker inside
		var d: float = 5.0
		var pts: PackedVector2Array = PackedVector2Array([
			screen_pos + Vector2(0, -d), screen_pos + Vector2(d, 0),
			screen_pos + Vector2(0, d), screen_pos + Vector2(-d, 0),
		])
		draw_colored_polygon(pts, Color(0.1, 0.08, 0.02))
		if default_font:
			draw_string(default_font, screen_pos + Vector2(-20, -POI_RADIUS - 18), "STORY", HORIZONTAL_ALIGNMENT_LEFT, 200, 11, color * Color(1, 1, 1, 0.8))
			draw_string(default_font, screen_pos + Vector2(-20, -POI_RADIUS - 4), poi.get("label", ""), HORIZONTAL_ALIGNMENT_LEFT, 260, 13, Color(0.95, 0.92, 0.8))

	# Draw hidden POIs (cartographer treasures)
	for poi in _hidden_pois:
		var px: float = poi.get("x", 0.0)
		var py: float = poi.get("y", 0.0)
		var sx: float = center.x + (px - gs.position_x)
		var sy: float = center.y + (py - gs.position_y)
		var screen_pos := Vector2(sx, sy)
		if screen_pos.x < -50 or screen_pos.y < -50 or screen_pos.x > size.x + 50 or screen_pos.y > size.y + 50:
			continue
		var poi_type: String = poi.get("type", "treasure")
		var color: Color = ENCOUNTER_TYPE_COLORS.get(poi_type, Color(0.75, 0.4, 1.0))
		var pulse: float = 1.0 + 0.15 * sin(_elapsed * 4.0 + px * 0.02)
		draw_circle(screen_pos, POI_RADIUS * 1.2 * pulse, color * Color(1, 1, 1, 0.06))
		draw_arc(screen_pos, POI_RADIUS * 0.8 * pulse, 0.0, TAU, 36, color, 1.5)
		draw_circle(screen_pos, 5.0, color)
		if default_font:
			draw_string(default_font, screen_pos + Vector2(-20, -POI_RADIUS - 8), poi.get("label", "Hidden"), HORIZONTAL_ALIGNMENT_LEFT, 260, 12, color)

	# Draw spawn POIs (combat, rescue, trade)
	for poi in _spawn_pois:
		var px: float = poi.get("x", 0.0)
		var py: float = poi.get("y", 0.0)
		var sx: float = center.x + (px - gs.position_x)
		var sy: float = center.y + (py - gs.position_y)
		var screen_pos := Vector2(sx, sy)
		if screen_pos.x < -50 or screen_pos.y < -50 or screen_pos.x > size.x + 50 or screen_pos.y > size.y + 50:
			continue
		var spawn_type: String = poi.get("type", "combat")
		var color: Color = ENCOUNTER_TYPE_COLORS.get(spawn_type, Color(1.0, 0.5, 0.5))
		var pulse: float = 1.0 + 0.2 * sin(_elapsed * 3.5 + px * 0.015)
		draw_circle(screen_pos, POI_RADIUS * 0.7 * pulse, color * Color(1, 1, 1, 0.1))
		draw_arc(screen_pos, POI_RADIUS * 0.6 * pulse, 0.0, TAU, 32, color, 1.5)
		draw_circle(screen_pos, 4.0, color)
		if spawn_type == "combat":
			draw_line(screen_pos + Vector2(-6, -6), screen_pos + Vector2(6, 6), color, 1.5)
			draw_line(screen_pos + Vector2(6, -6), screen_pos + Vector2(-6, 6), color, 1.5)
		if default_font:
			draw_string(default_font, screen_pos + Vector2(-20, -POI_RADIUS * 0.6 - 8), poi.get("label", "Contact"), HORIZONTAL_ALIGNMENT_LEFT, 200, 11, color * Color(1, 1, 1, 0.7))


func _draw_boundary_indicator(gs: GameStateData) -> void:
	var bounds: Vector2 = _vm.region_bounds(gs.current_region)
	var center := size * 0.5
	# The fuzzy edge width in world units that fades to dark
	var edge_depth: float = 250.0
	var num_strips: int = 12  # Number of gradient strips per edge

	# For each edge, calculate how far into the boundary fade zone the viewport extends
	# Left edge: world x = 0
	var left_world: float = gs.position_x - center.x
	# Right edge: world x = bounds.x
	var right_world: float = gs.position_x + center.x
	# Top edge: world y = 0
	var top_world: float = gs.position_y - center.y
	# Bottom edge: world y = bounds.y
	var bottom_world: float = gs.position_y + center.y

	var edge_base_color := Color(0.01, 0.02, 0.04)

	# Draw gradient strips for each visible boundary edge
	# Left boundary
	if left_world < edge_depth:
		var edge_screen_x: float = center.x - gs.position_x  # screen x where world x=0 is
		for i in num_strips:
			var frac: float = float(i) / num_strips
			var next_frac: float = float(i + 1) / num_strips
			var alpha: float = 1.0 - frac  # Full opacity at edge, fading inward
			alpha = alpha * alpha  # Quadratic falloff for smoother look
			var x0: float = edge_screen_x + frac * edge_depth
			var x1: float = edge_screen_x + next_frac * edge_depth
			if x1 < 0 or x0 > size.x:
				continue
			x0 = maxf(x0, 0.0)
			x1 = minf(x1, size.x)
			draw_rect(Rect2(x0, 0, x1 - x0, size.y), Color(edge_base_color.r, edge_base_color.g, edge_base_color.b, alpha * 0.85))
		# Solid fill beyond the edge
		if edge_screen_x > 0:
			draw_rect(Rect2(0, 0, edge_screen_x, size.y), Color(edge_base_color.r, edge_base_color.g, edge_base_color.b, 0.92))

	# Right boundary
	if right_world > bounds.x - edge_depth:
		var edge_screen_x: float = center.x + (bounds.x - gs.position_x)  # screen x where world x=bounds.x is
		for i in num_strips:
			var frac: float = float(i) / num_strips
			var next_frac: float = float(i + 1) / num_strips
			var alpha: float = 1.0 - frac
			alpha = alpha * alpha
			var x1: float = edge_screen_x - frac * edge_depth
			var x0: float = edge_screen_x - next_frac * edge_depth
			if x1 < 0 or x0 > size.x:
				continue
			x0 = maxf(x0, 0.0)
			x1 = minf(x1, size.x)
			draw_rect(Rect2(x0, 0, x1 - x0, size.y), Color(edge_base_color.r, edge_base_color.g, edge_base_color.b, alpha * 0.85))
		# Solid fill beyond the edge
		if edge_screen_x < size.x:
			draw_rect(Rect2(edge_screen_x, 0, size.x - edge_screen_x, size.y), Color(edge_base_color.r, edge_base_color.g, edge_base_color.b, 0.92))

	# Top boundary
	if top_world < edge_depth:
		var edge_screen_y: float = center.y - gs.position_y
		for i in num_strips:
			var frac: float = float(i) / num_strips
			var next_frac: float = float(i + 1) / num_strips
			var alpha: float = 1.0 - frac
			alpha = alpha * alpha
			var y0: float = edge_screen_y + frac * edge_depth
			var y1: float = edge_screen_y + next_frac * edge_depth
			if y1 < 0 or y0 > size.y:
				continue
			y0 = maxf(y0, 0.0)
			y1 = minf(y1, size.y)
			draw_rect(Rect2(0, y0, size.x, y1 - y0), Color(edge_base_color.r, edge_base_color.g, edge_base_color.b, alpha * 0.85))
		if edge_screen_y > 0:
			draw_rect(Rect2(0, 0, size.x, edge_screen_y), Color(edge_base_color.r, edge_base_color.g, edge_base_color.b, 0.92))

	# Bottom boundary
	if bottom_world > bounds.y - edge_depth:
		var edge_screen_y: float = center.y + (bounds.y - gs.position_y)
		for i in num_strips:
			var frac: float = float(i) / num_strips
			var next_frac: float = float(i + 1) / num_strips
			var alpha: float = 1.0 - frac
			alpha = alpha * alpha
			var y1: float = edge_screen_y - frac * edge_depth
			var y0: float = edge_screen_y - next_frac * edge_depth
			if y1 < 0 or y0 > size.y:
				continue
			y0 = maxf(y0, 0.0)
			y1 = minf(y1, size.y)
			draw_rect(Rect2(0, y0, size.x, y1 - y0), Color(edge_base_color.r, edge_base_color.g, edge_base_color.b, alpha * 0.85))
		if edge_screen_y < size.y:
			draw_rect(Rect2(0, edge_screen_y, size.x, size.y - edge_screen_y), Color(edge_base_color.r, edge_base_color.g, edge_base_color.b, 0.92))

	# Pulsing edge glow when near boundary transition
	if not _boundary_prompt_region.is_empty() and _boundary_prompt_timer > 0:
		var edge_color := Color(0.3, 0.6, 1.0, 0.4 + 0.2 * sin(_elapsed * 4.0))
		if gs.position_x <= BOUNDARY_MARGIN:
			draw_rect(Rect2(0, 0, 4, size.y), edge_color)
		elif gs.position_x >= bounds.x - BOUNDARY_MARGIN:
			draw_rect(Rect2(size.x - 4, 0, 4, size.y), edge_color)
		if gs.position_y <= BOUNDARY_MARGIN:
			draw_rect(Rect2(0, 0, size.x, 4), edge_color)
		elif gs.position_y >= bounds.y - BOUNDARY_MARGIN:
			draw_rect(Rect2(0, size.y - 4, size.x, 4), edge_color)


func _draw_pois(center: Vector2, gs: GameStateData) -> void:
	var default_font: Font = ThemeDB.fallback_font
	for poi in _active_pois:
		var sx: float = center.x + (poi["x"] - gs.position_x)
		var sy: float = center.y + (poi["y"] - gs.position_y)
		var screen_pos := Vector2(sx, sy)
		var poi_color: Color = poi.get("color", Color(1.0, 0.82, 0.45))

		# Pulsing glow effect
		var pulse: float = 1.0 + 0.2 * sin(_elapsed * 3.0 + poi["x"] * 0.01)
		var outer_r: float = poi["radius"] * 1.5 * pulse

		# Outer glow (translucent)
		draw_circle(screen_pos, outer_r, poi_color * Color(1, 1, 1, 0.1))
		# Ring
		draw_arc(screen_pos, poi["radius"] * pulse, 0.0, TAU, 48, poi_color, 2.0)
		# Inner core (pulsing)
		var core_r: float = 7.0 * (1.0 + 0.15 * sin(_elapsed * 5.0))
		draw_circle(screen_pos, core_r, poi_color)

		# Encounter type indicator for combat
		if poi["encounter"].encounter_type == "combat":
			# Draw crossed swords indicator
			var cx: float = sx
			var cy: float = sy
			draw_line(Vector2(cx - 8, cy - 8), Vector2(cx + 8, cy + 8), Color(1.0, 0.3, 0.3), 2.0)
			draw_line(Vector2(cx + 8, cy - 8), Vector2(cx - 8, cy + 8), Color(1.0, 0.3, 0.3), 2.0)

		# Title label
		if default_font != null:
			var encounter: Encounter = poi["encounter"]
			var type_tag: String = encounter.encounter_type.to_upper()
			# Type tag above
			draw_string(
				default_font,
				screen_pos + Vector2(-20, -poi["radius"] - 22),
				type_tag,
				HORIZONTAL_ALIGNMENT_LEFT,
				200,
				12,
				poi_color * Color(1, 1, 1, 0.7)
			)
			# Title below type
			draw_string(
				default_font,
				screen_pos + Vector2(-20, -poi["radius"] - 8),
				encounter.title,
				HORIZONTAL_ALIGNMENT_LEFT,
				260,
				14,
				Color(0.92, 0.95, 1.0)
			)


func _get_planet_texture(image_name: String) -> Texture2D:
	"""Load and cache a planet texture from assets/planets/."""
	if image_name.is_empty():
		return null
	if _planet_textures.has(image_name):
		return _planet_textures[image_name]
	var path := "res://assets/planets/%s.png" % image_name
	var tex: Texture2D = load(path) as Texture2D
	_planet_textures[image_name] = tex
	return tex


func _draw_planets(center: Vector2, gs: GameStateData) -> void:
	if not _vm.has_planet_system():
		return
	var planets: Array = _vm.planets_in_region(gs.current_region)
	var default_font: Font = ThemeDB.fallback_font
	var planet_draw_radius: float = 28.0
	for planet in planets:
		var sx: float = center.x + (planet.position_x - gs.position_x)
		var sy: float = center.y + (planet.position_y - gs.position_y)
		var screen_pos := Vector2(sx, sy)
		if screen_pos.x < -60 or screen_pos.y < -60 or screen_pos.x > size.x + 60 or screen_pos.y > size.y + 60:
			continue
		# Biome tint colour (used for glow, ring, and label)
		var planet_color := Color(0.4, 0.7, 0.3)
		match planet.biome:
			"settlement":
				planet_color = Color(0.6, 0.5, 0.35)
			"industrial":
				planet_color = Color(0.5, 0.55, 0.65)
			"enchanted":
				planet_color = Color(0.3, 0.7, 0.5)
			"wilderness":
				planet_color = Color(0.5, 0.6, 0.3)
		var pulse: float = 1.0 + 0.08 * sin(_elapsed * 1.5 + planet.position_x * 0.01)
		# Outer glow
		draw_circle(screen_pos, (planet_draw_radius + 8.0) * pulse, planet_color * Color(1, 1, 1, 0.12))
		# Planet image or fallback circle
		var tex: Texture2D = _get_planet_texture(planet.image)
		if tex != null:
			var draw_size := Vector2(planet_draw_radius * 2.0, planet_draw_radius * 2.0)
			var rect := Rect2(screen_pos - draw_size * 0.5, draw_size)
			draw_texture_rect(tex, rect, false)
		else:
			# Fallback: coloured circle when no image assigned
			draw_circle(screen_pos, planet_draw_radius * 0.5, planet_color * Color(1, 1, 1, 0.6))
			draw_circle(screen_pos, planet_draw_radius * 0.35, planet_color)
		# Ring
		draw_arc(screen_pos, planet_draw_radius + 2.0, 0.0, TAU, 32, planet_color.lightened(0.3), 1.5)
		# Label
		if default_font != null:
			draw_string(
				default_font,
				screen_pos + Vector2(-30, -planet_draw_radius - 10),
				planet.planet_name,
				HORIZONTAL_ALIGNMENT_LEFT,
				200,
				11,
				planet_color.lightened(0.4)
			)
			# Landing prompt
			if planet.planet_id == _nearby_planet_id:
				draw_string(
					default_font,
					screen_pos + Vector2(-20, planet_draw_radius + 14),
					"[L] LAND",
					HORIZONTAL_ALIGNMENT_LEFT,
					100,
					11,
					Color(0.6, 1.0, 0.6)
				)


func _get_starbase_texture(image_name: String) -> Texture2D:
	"""Load and cache a starbase texture from assets/starbases/."""
	if image_name.is_empty():
		return null
	if _starbase_textures.has(image_name):
		return _starbase_textures[image_name]
	var path := "res://assets/starbases/%s.png" % image_name
	var tex: Texture2D = load(path) as Texture2D
	_starbase_textures[image_name] = tex
	return tex


func _draw_star_bases(center: Vector2, gs: GameStateData) -> void:
	if not _vm.has_star_base_system():
		return
	var bases: Array = _vm.visible_star_bases(gs.current_region)
	var default_font: Font = ThemeDB.fallback_font
	var base_draw_size: float = 48.0
	for base in bases:
		var sx: float = center.x + (base.position_x - gs.position_x)
		var sy: float = center.y + (base.position_y - gs.position_y)
		var screen_pos := Vector2(sx, sy)
		if screen_pos.x < -60 or screen_pos.y < -60:
			continue
		if screen_pos.x > size.x + 60 or screen_pos.y > size.y + 60:
			continue
		var base_color := Color(0.9, 0.75, 0.3)
		if base.base_type == "stronghold":
			base_color = Color(0.8, 0.3, 0.3)
		elif base.base_type == "hidden":
			base_color = Color(0.5, 0.7, 0.9)
		var pulse: float = 1.0 + 0.1 * sin(_elapsed * 2.0)
		# Outer glow
		draw_circle(
			screen_pos,
			(base_draw_size * 0.5 + 6.0) * pulse,
			base_color * Color(1, 1, 1, 0.1)
		)
		# Starbase image or fallback diamond
		var tex: Texture2D = _get_starbase_texture(base.image)
		if tex != null:
			var draw_sz := Vector2(base_draw_size, base_draw_size)
			var rect := Rect2(
				screen_pos - draw_sz * 0.5, draw_sz
			)
			draw_texture_rect(tex, rect, false)
		else:
			var r: float = 18.0
			var pr: float = r * pulse
			var diamond := PackedVector2Array([
				screen_pos + Vector2(0, -pr),
				screen_pos + Vector2(pr, 0),
				screen_pos + Vector2(0, pr),
				screen_pos + Vector2(-pr, 0),
			])
			draw_polygon(
				diamond, [base_color * Color(1, 1, 1, 0.25)]
			)
			draw_polyline(
				diamond + PackedVector2Array([diamond[0]]),
				base_color, 2.0
			)
			draw_circle(screen_pos, 4.0, base_color)
		# Label
		var half := base_draw_size * 0.5
		if default_font != null:
			draw_string(
				default_font,
				screen_pos + Vector2(-30, -half - 8),
				base.base_name,
				HORIZONTAL_ALIGNMENT_LEFT,
				200,
				12,
				base_color
			)
			# Dock prompt if in range
			if base.base_id == _nearby_base_id:
				draw_string(
					default_font,
					screen_pos + Vector2(-20, half + 16),
					"[E] DOCK",
					HORIZONTAL_ALIGNMENT_LEFT,
					100,
					11,
					Color(1.0, 1.0, 0.6)
				)


func _draw_ship(center: Vector2) -> void:
	if _ship_texture == null and _ship_up_texture == null:
		draw_circle(center, SHIP_COLLISION_RADIUS, Color(0.72, 0.34, 0.9))
		return

	# Ease-out-quad: jumps away from the rotate midpoint quickly, settles slowly
	var eased_flip: float = 1.0 - (1.0 - _flip_progress) * (1.0 - _flip_progress)
	var draw_rect_area := Rect2(-(SHIP_DRAW_SIZE * 0.5), SHIP_DRAW_SIZE)

	# --- Side-view layer (blends with rotate sprite during flip) ---
	if _vertical_blend < 0.99:
		var base_alpha: float = (1.0 - _vertical_blend) * 0.95

		# Blend: rotate sprite (eased_flip=0) → side sprite (eased_flip=1)
		# Rotate sprite is fully visible below 0.4, fades out by 0.8
		var rotate_weight: float = clampf(1.0 - (eased_flip - 0.4) / 0.4, 0.0, 1.0)
		# Side sprite fades in from 0.3 to 0.7
		var side_weight: float = clampf((eased_flip - 0.3) / 0.4, 0.0, 1.0)

		# Draw rotate sprite (3/4 angle turning frame)
		if rotate_weight > 0.01 and _ship_rotate_texture != null:
			var rotate_alpha: float = base_alpha * rotate_weight
			# Mirror the rotate sprite based on facing direction
			var rot_scale_x: float = -1.0 if _facing_right else 1.0
			draw_set_transform(center, _bank_angle, Vector2(rot_scale_x, 1.0))
			draw_texture_rect(_ship_rotate_texture, draw_rect_area, false, Color(1, 1, 1, rotate_alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Draw side sprite (full profile)
		if side_weight > 0.01 and _ship_texture != null:
			var side_alpha: float = base_alpha * side_weight
			var side_scale_x: float = 1.0 if _facing_right else -1.0
			draw_set_transform(center, _bank_angle, Vector2(side_scale_x, 1.0))
			draw_texture_rect(_ship_texture, draw_rect_area, false, Color(1, 1, 1, side_alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- Top-down layer (for vertical movement) ---
	if _vertical_blend > 0.01 and _ship_up_texture != null:
		var top_alpha: float = _vertical_blend * 0.95
		var top_rotation: float = _heading_angle + PI * 0.5
		draw_set_transform(center, top_rotation, Vector2.ONE)
		draw_texture_rect(_ship_up_texture, draw_rect_area, false, Color(1, 1, 1, top_alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- Engine glow when moving ---
	if _is_moving:
		var glow_pulse: float = 1.0 + 0.5 * sin(_elapsed * 20.0)
		var side_offset := Vector2(-SHIP_DRAW_SIZE.x * 0.45 * (1.0 if _facing_right else -1.0), 0.0).rotated(_bank_angle)
		var heading_offset := Vector2(-cos(_heading_angle), -sin(_heading_angle)) * SHIP_DRAW_SIZE.x * 0.45
		var engine_offset: Vector2 = side_offset.lerp(heading_offset, _vertical_blend)
		var engine_pos := center + engine_offset
		draw_circle(engine_pos, 6.0 * glow_pulse, Color(0.4, 0.8, 1.0, 0.5))
		draw_circle(engine_pos, 3.0 * glow_pulse, Color(0.8, 0.95, 1.0, 0.8))


const MINIMAP_BIOME_GRID: int = 8
const MINIMAP_BASE_COLOR := Color(0.05, 0.07, 0.11, 0.8)


func _draw_minimap(gs: GameStateData) -> void:
	var map_x: float = size.x - MINIMAP_SIZE - MINIMAP_MARGIN
	var map_y: float = size.y - MINIMAP_SIZE - MINIMAP_MARGIN - 30  # Above controls bar
	var map_rect := Rect2(map_x, map_y, MINIMAP_SIZE, MINIMAP_SIZE)

	_draw_minimap_biome_background(map_rect, gs)
	# Border
	draw_rect(map_rect, Color(0.2, 0.4, 0.7, 0.8), false, 2.0)

	# Fog of war on minimap
	var sms: StarMapSystem = _vm.star_map()
	if sms != null:
		var region_id: String = gs.current_region
		var bounds: Vector2 = sms.get_bounds(region_id)
		var dims: Vector2i = sms.grid_dimensions.get(region_id, Vector2i.ZERO)
		var map_def: Dictionary = sms.region_maps.get(region_id, {})
		var cell_size: int = map_def.get("fog_grid_size", 64)
		if dims != Vector2i.ZERO and bounds.x > 0 and bounds.y > 0:
			var half_range: float = MINIMAP_WORLD_RANGE * 0.5
			# Draw fog chunks on minimap
			var mini_cell_w: float = (cell_size / MINIMAP_WORLD_RANGE) * MINIMAP_SIZE
			var mini_chunk: int = maxi(1, int(FOG_CHUNK_SIZE * 2))
			var world_left: float = gs.position_x - half_range
			var world_top: float = gs.position_y - half_range
			var g_left: int = maxi(0, int(world_left / (cell_size * mini_chunk)))
			var g_top: int = maxi(0, int(world_top / (cell_size * mini_chunk)))
			var g_right: int = mini(ceili(float(dims.x) / mini_chunk), ceili((gs.position_x + half_range) / (cell_size * mini_chunk)) + 1)
			var g_bottom: int = mini(ceili(float(dims.y) / mini_chunk), ceili((gs.position_y + half_range) / (cell_size * mini_chunk)) + 1)
			for gy in range(g_top, g_bottom):
				for gx in range(g_left, g_right):
					var all_hidden: bool = true
					for cy in range(gy * mini_chunk, mini((gy + 1) * mini_chunk, dims.y)):
						for cx in range(gx * mini_chunk, mini((gx + 1) * mini_chunk, dims.x)):
							if sms.is_cell_revealed(region_id, cx, cy):
								all_hidden = false
								break
						if not all_hidden:
							break
					if all_hidden:
						var wx: float = gx * cell_size * mini_chunk
						var wy: float = gy * cell_size * mini_chunk
						var rel_x: float = wx - gs.position_x
						var rel_y: float = wy - gs.position_y
						var nx: float = (rel_x / MINIMAP_WORLD_RANGE) + 0.5
						var ny: float = (rel_y / MINIMAP_WORLD_RANGE) + 0.5
						var chunk_w: float = (cell_size * mini_chunk / MINIMAP_WORLD_RANGE) * MINIMAP_SIZE
						var bx: float = map_x + nx * MINIMAP_SIZE
						var by: float = map_y + ny * MINIMAP_SIZE
						# Clip to minimap bounds
						var r := Rect2(bx, by, chunk_w, chunk_w).intersection(map_rect)
						if r.size.x > 0 and r.size.y > 0:
							draw_rect(r, Color(0.02, 0.03, 0.05, 0.7))

	# Grid lines
	for i in range(1, 4):
		var gx: float = map_x + i * (MINIMAP_SIZE / 4.0)
		var gy: float = map_y + i * (MINIMAP_SIZE / 4.0)
		draw_line(Vector2(gx, map_y), Vector2(gx, map_y + MINIMAP_SIZE), Color(0.12, 0.2, 0.3, 0.6), 1.0)
		draw_line(Vector2(map_x, gy), Vector2(map_x + MINIMAP_SIZE, gy), Color(0.12, 0.2, 0.3, 0.6), 1.0)

	var half_range: float = MINIMAP_WORLD_RANGE * 0.5

	# Encounter POI blips (relative to player position)
	for poi in _active_pois:
		var rel_x: float = poi["x"] - gs.position_x
		var rel_y: float = poi["y"] - gs.position_y
		if absf(rel_x) > half_range or absf(rel_y) > half_range:
			continue
		var nx: float = (rel_x / MINIMAP_WORLD_RANGE) + 0.5
		var ny: float = (rel_y / MINIMAP_WORLD_RANGE) + 0.5
		var bx: float = map_x + nx * MINIMAP_SIZE
		var by: float = map_y + ny * MINIMAP_SIZE
		if bx >= map_x and bx <= map_x + MINIMAP_SIZE and by >= map_y and by <= map_y + MINIMAP_SIZE:
			var poi_color: Color = poi.get("color", Color(1.0, 0.82, 0.45))
			draw_circle(Vector2(bx, by), 3.0, poi_color)

	# Story POI blips (gold)
	for poi in _story_pois:
		var rel_x: float = poi.get("x", 0.0) - gs.position_x
		var rel_y: float = poi.get("y", 0.0) - gs.position_y
		if absf(rel_x) > half_range or absf(rel_y) > half_range:
			continue
		var nx: float = (rel_x / MINIMAP_WORLD_RANGE) + 0.5
		var ny: float = (rel_y / MINIMAP_WORLD_RANGE) + 0.5
		var bx: float = map_x + nx * MINIMAP_SIZE
		var by: float = map_y + ny * MINIMAP_SIZE
		if bx >= map_x and bx <= map_x + MINIMAP_SIZE and by >= map_y and by <= map_y + MINIMAP_SIZE:
			draw_circle(Vector2(bx, by), 4.0, ENCOUNTER_TYPE_COLORS.get("story", Color(1.0, 0.82, 0.25)))

	# Hidden POI blips (purple)
	for poi in _hidden_pois:
		var rel_x: float = poi.get("x", 0.0) - gs.position_x
		var rel_y: float = poi.get("y", 0.0) - gs.position_y
		if absf(rel_x) > half_range or absf(rel_y) > half_range:
			continue
		var nx: float = (rel_x / MINIMAP_WORLD_RANGE) + 0.5
		var ny: float = (rel_y / MINIMAP_WORLD_RANGE) + 0.5
		var bx: float = map_x + nx * MINIMAP_SIZE
		var by: float = map_y + ny * MINIMAP_SIZE
		if bx >= map_x and bx <= map_x + MINIMAP_SIZE and by >= map_y and by <= map_y + MINIMAP_SIZE:
			draw_circle(Vector2(bx, by), 3.0, Color(0.75, 0.4, 1.0))

	# Spawn POI blips (colored by type)
	for poi in _spawn_pois:
		var rel_x: float = poi.get("x", 0.0) - gs.position_x
		var rel_y: float = poi.get("y", 0.0) - gs.position_y
		if absf(rel_x) > half_range or absf(rel_y) > half_range:
			continue
		var nx: float = (rel_x / MINIMAP_WORLD_RANGE) + 0.5
		var ny: float = (rel_y / MINIMAP_WORLD_RANGE) + 0.5
		var bx: float = map_x + nx * MINIMAP_SIZE
		var by: float = map_y + ny * MINIMAP_SIZE
		if bx >= map_x and bx <= map_x + MINIMAP_SIZE and by >= map_y and by <= map_y + MINIMAP_SIZE:
			var spawn_color: Color = ENCOUNTER_TYPE_COLORS.get(poi.get("type", "combat"), Color(1.0, 0.3, 0.3))
			draw_circle(Vector2(bx, by), 2.5, spawn_color)

	# Hazard blips (red/orange warning)
	for hazard in _visible_hazards:
		var rel_x: float = hazard.get("x", 0.0) - gs.position_x
		var rel_y: float = hazard.get("y", 0.0) - gs.position_y
		if absf(rel_x) > half_range or absf(rel_y) > half_range:
			continue
		var nx: float = (rel_x / MINIMAP_WORLD_RANGE) + 0.5
		var ny: float = (rel_y / MINIMAP_WORLD_RANGE) + 0.5
		var bx: float = map_x + nx * MINIMAP_SIZE
		var by: float = map_y + ny * MINIMAP_SIZE
		if bx >= map_x and bx <= map_x + MINIMAP_SIZE and by >= map_y and by <= map_y + MINIMAP_SIZE:
			var hazard_color := Color(1.0, 0.35, 0.2, 0.7 + 0.3 * sin(_elapsed * 4.0))
			draw_circle(Vector2(bx, by), 3.5, hazard_color)

	# Player blip (center)
	var player_pos := Vector2(map_x + MINIMAP_SIZE * 0.5, map_y + MINIMAP_SIZE * 0.5)
	draw_circle(player_pos, 3.0, Color(0.43, 0.84, 1.0))
	draw_arc(player_pos, 6.0, 0.0, TAU, 24, Color(0.43, 0.84, 1.0, 0.4), 1.0)

	# Direction indicator (small line showing heading)
	var dir_end := player_pos + Vector2(cos(_heading_angle), sin(_heading_angle)) * 10.0
	draw_line(player_pos, dir_end, Color(0.43, 0.84, 1.0, 0.7), 1.5)

	# Label
	var default_font: Font = ThemeDB.fallback_font
	if default_font:
		var region_name: String = gs.current_region.replace("_", " ").to_upper()
		draw_string(default_font, Vector2(map_x + 4, map_y + 14), region_name, HORIZONTAL_ALIGNMENT_LEFT, MINIMAP_SIZE - 8, 11, Color(0.4, 0.7, 0.86))


## Paint the minimap background as an MxM grid of biome-sampled cells so
## the minimap shows *where you are* in the region instead of flat dark.
## Cheap — MINIMAP_BIOME_GRID^2 samples per frame via the resident
## per-region datasource.
func _draw_minimap_biome_background(map_rect: Rect2, gs: GameStateData) -> void:
	var cell_px: float = map_rect.size.x / float(MINIMAP_BIOME_GRID)
	var cell_world: float = MINIMAP_WORLD_RANGE / float(MINIMAP_BIOME_GRID)
	var half_range: float = MINIMAP_WORLD_RANGE * 0.5
	var region_tint: Color = ProceduralMapManager.get_region_tint(gs.current_region)
	for gy in range(MINIMAP_BIOME_GRID):
		for gx in range(MINIMAP_BIOME_GRID):
			var wx: float = gs.position_x - half_range + (gx + 0.5) * cell_world
			var wy: float = gs.position_y - half_range + (gy + 0.5) * cell_world
			var sample: Dictionary = ProceduralMapManager.sample_biome(gs.current_region, wx, wy)
			var biome_tint: Color = sample.get("biome_tint", Color(1.0, 1.0, 1.0))
			# Multiply base colour by region tint and biome tint. Alpha stays
			# at base so the minimap doesn't wash out over the gameplay view.
			var cell_color := Color(
				MINIMAP_BASE_COLOR.r + region_tint.r * biome_tint.r * 0.08,
				MINIMAP_BASE_COLOR.g + region_tint.g * biome_tint.g * 0.08,
				MINIMAP_BASE_COLOR.b + region_tint.b * biome_tint.b * 0.08,
				MINIMAP_BASE_COLOR.a,
			)
			var cell_rect := Rect2(
				map_rect.position.x + gx * cell_px,
				map_rect.position.y + gy * cell_px,
				cell_px + 1.0,  # +1 to avoid hairline gaps from float rounding
				cell_px + 1.0,
			).intersection(map_rect)
			if cell_rect.size.x > 0 and cell_rect.size.y > 0:
				draw_rect(cell_rect, cell_color)


func _draw_status_effects() -> void:
	var ahs: AstralHazardSystem = _vm.astral_hazards()
	if ahs == null or ahs.status_effects.is_empty():
		return
	var default_font: Font = ThemeDB.fallback_font
	if default_font == null:
		return
	var effect_colors: Dictionary = {
		"fog_blind": Color(1.0, 0.85, 0.3),
		"crystal_drain": Color(0.8, 0.4, 1.0),
		"off_course": Color(0.4, 0.7, 1.0),
		"hull_weakness": Color(1.0, 0.3, 0.3),
	}
	var x_pos: float = 12.0
	var y_pos: float = 72.0
	for effect in ahs.status_effects:
		var eid: String = effect.get("effect_id", "")
		var remaining: float = effect.get("remaining", 0.0)
		var color: Color = effect_colors.get(eid, Color(1.0, 0.5, 0.5))
		var label: String = eid.replace("_", " ").to_upper()
		var timer_str: String = "%ds" % ceili(remaining)
		# Background pill
		draw_rect(Rect2(x_pos - 2, y_pos - 12, 140, 18), Color(0.05, 0.05, 0.1, 0.7))
		# Colored bar showing remaining time proportion
		var max_dur: float = 60.0
		match eid:
			"fog_blind": max_dur = 60.0
			"crystal_drain": max_dur = 30.0
			"off_course": max_dur = 15.0
			"hull_weakness": max_dur = 45.0
		var bar_frac: float = clampf(remaining / max_dur, 0.0, 1.0)
		draw_rect(Rect2(x_pos - 2, y_pos - 12, 140 * bar_frac, 18), Color(color.r, color.g, color.b, 0.15))
		# Icon dot
		draw_circle(Vector2(x_pos + 5, y_pos - 3), 4.0, color)
		# Label + timer
		draw_string(default_font, Vector2(x_pos + 14, y_pos), label, HORIZONTAL_ALIGNMENT_LEFT, 100, 11, color)
		draw_string(default_font, Vector2(x_pos + 110, y_pos), timer_str, HORIZONTAL_ALIGNMENT_LEFT, 40, 11, Color(0.8, 0.8, 0.8))
		y_pos += 22.0


func _draw_controls_bar() -> void:
	var bar_h: float = 28.0
	var bar_y: float = size.y - bar_h
	draw_rect(Rect2(0, bar_y, size.x, bar_h), Color(0.06, 0.05, 0.1, 0.65))
	draw_line(Vector2(0, bar_y), Vector2(size.x, bar_y), Color(0.27, 0.17, 0.43), 1.0)

	var default_font: Font = ThemeDB.fallback_font
	if default_font:
		var hint_text := "WASD: MOVE  |  TAB: MAP  |  E: FACTIONS  |  SPACE: SHIP  |  R: REPAIR  |  M: MISSIONS  |  ESC: PAUSE"
		draw_string(
			default_font,
			Vector2(size.x * 0.5 - 280, bar_y + 18),
			hint_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			600,
			14,
			Color(0.63, 0.63, 0.67)
		)
