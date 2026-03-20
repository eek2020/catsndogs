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
var _poi_refresh_timer: float = 0.0
var _elapsed: float = 0.0

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
}

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

const FLIP_SPEED: float = 6.0
const BANK_MAX_ANGLE: float = 0.30       # ~17 degrees max banking tilt
const BANK_SPEED: float = 8.0
const VERTICAL_BLEND_SPEED: float = 5.0

# Engine trail particles: Array of {x, y, life, max_life}
var _trail: Array = []

# Distress signals handled by SideMissionSystem.update_distress()

# First-run welcome
var _showed_welcome: bool = false


func _ready() -> void:
	randomize()
	_ship_texture = _remove_background_by_corners(_ship_texture)
	_ship_up_texture = _remove_background_by_corners(_ship_up_texture)
	_ship_rotate_texture = _remove_background_by_corners(_ship_rotate_texture)
	_build_starfield()
	flash_label.text = ""
	_poi_refresh_timer = 0.0
	_refresh_pois()
	_update_hud()
	EventBus.arc_advanced.connect(_on_arc_advanced)


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
	for _i in STAR_COUNT:
		_stars.append({
			"x": randf_range(-STARFIELD_AREA * 0.5, STARFIELD_AREA * 0.5),
			"y": randf_range(-STARFIELD_AREA * 0.5, STARFIELD_AREA * 0.5),
			"depth": [0.2, 0.35, 0.55, 0.8, 1.0][randi() % 5],
		})


func _has_overlay() -> bool:
	var main: Control = get_tree().current_scene
	if main and "_overlay_stack" in main:
		var stack: Array = main._overlay_stack
		for overlay in stack:
			if is_instance_valid(overlay):
				return true
	return false


func _process(dt: float) -> void:
	if GameSession.game_state == null:
		return
	_elapsed += dt
	# Pause gameplay when overlays (dialogue, combat, etc.) are open
	if not _has_overlay():
		_handle_movement(dt)
		_update_trail(dt)
		_update_poi_timer(dt)
		_update_distress(dt)
		_check_poi_collisions()
	else:
		_update_trail(dt)  # Let trail fade while paused
	_update_flash(dt)
	_update_hud()
	_show_welcome()
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
		GameSession.game_state.position_x += direction.x * SHIP_SPEED * dt
		GameSession.game_state.position_y += direction.y * SHIP_SPEED * dt

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
			var gs: GameStateData = GameSession.game_state
			var ex: float = gs.position_x - cos(_heading_angle) * 18.0
			var ey: float = gs.position_y - sin(_heading_angle) * 18.0
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
	if GameSession.game_state == null:
		return
	var encounter: Encounter = GameSession.side_mission_system.update_distress(dt, GameSession.game_state)
	if encounter == null:
		return
	var gs: GameStateData = GameSession.game_state
	var angle := randf() * TAU
	var distance := randf_range(500.0, 900.0)
	var color: Color = ENCOUNTER_TYPE_COLORS.get("distress_signal", Color(1.0, 0.62, 0.35))
	_active_pois.append({
		"encounter": encounter,
		"x": gs.position_x + cos(angle) * distance,
		"y": gs.position_y + sin(angle) * distance,
		"radius": POI_RADIUS,
		"color": color,
	})
	flash("DISTRESS SIGNAL: %s" % encounter.title, 3.0)


func _refresh_pois() -> void:
	if GameSession.game_state == null:
		return
	var available: Array = GameSession.encounter_engine.get_available_encounters(GameSession.game_state)
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


func _spawn_poi(encounter: Encounter) -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return
	var angle := randf() * TAU
	var distance := randf_range(420.0, 960.0)
	var color: Color = ENCOUNTER_TYPE_COLORS.get(encounter.encounter_type, Color(1.0, 0.82, 0.45))
	_active_pois.append({
		"encounter": encounter,
		"x": gs.position_x + cos(angle) * distance,
		"y": gs.position_y + sin(angle) * distance,
		"radius": POI_RADIUS,
		"color": color,
	})


func _check_poi_collisions() -> void:
	var gs: GameStateData = GameSession.game_state
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


func _on_encounter(encounter) -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("push_overlay"):
		var dialogue_overlay = main.push_overlay("dialogue")
		if dialogue_overlay and dialogue_overlay.has_method("setup"):
			dialogue_overlay.setup(encounter)


func _unhandled_input(event: InputEvent) -> void:
	if _has_overlay():
		return
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
	elif event.is_action_pressed("repair"):
		var main: Control = get_tree().current_scene
		if main.has_method("push_overlay"):
			main.push_overlay("purchase")


func _update_hud() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return
	var arc_title: String = GameSession.narrative.get_arc_title(gs.current_arc)
	var progress: Dictionary = GameSession.narrative.get_arc_progress(gs)
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
	if gs.player_ship:
		hull_label.text = "Hull: %d/%d  Crew: %d/%d" % [
			gs.player_ship.current_hull, gs.player_ship.max_hull,
			gs.player_ship.crew.size(), gs.player_ship.crew_capacity,
		]


func _show_welcome() -> void:
	if _showed_welcome:
		return
	_showed_welcome = true
	flash("Fly toward the markers to begin encounters", 5.0)


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


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return

	var center := size * 0.5
	_draw_starfield(center, gs)
	_draw_trail(center, gs)
	_draw_pois(center, gs)
	_draw_ship(center)
	_draw_minimap(gs)
	_draw_controls_bar()


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


func _draw_minimap(gs: GameStateData) -> void:
	var map_x: float = size.x - MINIMAP_SIZE - MINIMAP_MARGIN
	var map_y: float = size.y - MINIMAP_SIZE - MINIMAP_MARGIN - 30  # Above controls bar
	var map_rect := Rect2(map_x, map_y, MINIMAP_SIZE, MINIMAP_SIZE)

	# Background
	draw_rect(map_rect, Color(0.05, 0.07, 0.11, 0.8))
	# Border
	draw_rect(map_rect, Color(0.2, 0.4, 0.7, 0.8), false, 2.0)

	# Grid lines
	for i in range(1, 4):
		var gx: float = map_x + i * (MINIMAP_SIZE / 4.0)
		var gy: float = map_y + i * (MINIMAP_SIZE / 4.0)
		draw_line(Vector2(gx, map_y), Vector2(gx, map_y + MINIMAP_SIZE), Color(0.12, 0.2, 0.3, 0.6), 1.0)
		draw_line(Vector2(map_x, gy), Vector2(map_x + MINIMAP_SIZE, gy), Color(0.12, 0.2, 0.3, 0.6), 1.0)

	# POI blips (relative to player position)
	var half_range: float = MINIMAP_WORLD_RANGE * 0.5
	for poi in _active_pois:
		var rel_x: float = poi["x"] - gs.position_x
		var rel_y: float = poi["y"] - gs.position_y
		# Skip if outside minimap range
		if absf(rel_x) > half_range or absf(rel_y) > half_range:
			continue
		var nx: float = (rel_x / MINIMAP_WORLD_RANGE) + 0.5
		var ny: float = (rel_y / MINIMAP_WORLD_RANGE) + 0.5
		var bx: float = map_x + nx * MINIMAP_SIZE
		var by: float = map_y + ny * MINIMAP_SIZE
		var poi_color: Color = poi.get("color", Color(1.0, 0.82, 0.45))
		draw_circle(Vector2(bx, by), 3.0, poi_color)

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
		draw_string(default_font, Vector2(map_x + 4, map_y + 14), "SECTOR MAP", HORIZONTAL_ALIGNMENT_LEFT, 200, 12, Color(0.4, 0.7, 0.86))


func _draw_controls_bar() -> void:
	var bar_h: float = 28.0
	var bar_y: float = size.y - bar_h
	draw_rect(Rect2(0, bar_y, size.x, bar_h), Color(0.06, 0.05, 0.1, 0.65))
	draw_line(Vector2(0, bar_y), Vector2(size.x, bar_y), Color(0.27, 0.17, 0.43), 1.0)

	var default_font: Font = ThemeDB.fallback_font
	if default_font:
		var hint_text := "WASD: MOVE  |  E: FACTIONS  |  SPACE: SHIP  |  R: REPAIR  |  M: MISSIONS  |  ESC: PAUSE"
		draw_string(
			default_font,
			Vector2(size.x * 0.5 - 280, bar_y + 18),
			hint_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			600,
			14,
			Color(0.63, 0.63, 0.67)
		)
