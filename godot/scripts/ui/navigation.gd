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

const POI_REFRESH_INTERVAL: float = 1.5
const SHIP_SPEED: float = 200.0
const SHIP_DRAW_SIZE := Vector2(72.0, 72.0)
const SHIP_COLLISION_RADIUS: float = 24.0
const POI_RADIUS: float = 38.0
const STAR_COUNT: int = 180
const STARFIELD_AREA: float = 4200.0

const ENCOUNTER_TYPE_COLORS := {
	"combat": Color(1.0, 0.2, 0.2),
	"diplomatic": Color(0.45, 0.8, 1.0),
	"exploration": Color(0.5, 1.0, 0.62),
	"trade": Color(0.52, 1.0, 0.35),
	"event": Color(0.82, 0.55, 1.0),
	"distress_signal": Color(1.0, 0.62, 0.35),
}

var _ship_texture: Texture2D = preload("res://assets/ships/ship_r_side.png")
var _active_pois: Array = []
var _stars: Array = []


func _ready() -> void:
	randomize()
	_prepare_ship_texture_alpha()
	_build_starfield()
	flash_label.text = ""
	_poi_refresh_timer = 0.0
	_refresh_pois()
	_update_hud()


func _prepare_ship_texture_alpha() -> void:
	if _ship_texture == null:
		return
	var image: Image = _ship_texture.get_image()
	if image == null:
		return
	image.convert(Image.FORMAT_RGBA8)
	var w: int = image.get_width()
	var h: int = image.get_height()
	for y in h:
		for x in w:
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.9 and c.r <= 0.08 and c.g <= 0.08 and c.b <= 0.08:
				image.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
	_ship_texture = ImageTexture.create_from_image(image)


func _build_starfield() -> void:
	_stars.clear()
	for _i in STAR_COUNT:
		_stars.append({
			"x": randf_range(-STARFIELD_AREA * 0.5, STARFIELD_AREA * 0.5),
			"y": randf_range(-STARFIELD_AREA * 0.5, STARFIELD_AREA * 0.5),
			"depth": [0.2, 0.35, 0.55, 0.8, 1.0][randi() % 5],
		})


func _process(dt: float) -> void:
	if GameSession.game_state == null:
		return
	_handle_movement(dt)
	_update_poi_timer(dt)
	_check_poi_collisions()
	_update_flash(dt)
	_update_hud()
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
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		GameSession.game_state.position_x += direction.x * SHIP_SPEED * dt
		GameSession.game_state.position_y += direction.y * SHIP_SPEED * dt


func _update_poi_timer(dt: float) -> void:
	_poi_refresh_timer += dt
	if _poi_refresh_timer >= POI_REFRESH_INTERVAL:
		_poi_refresh_timer = 0.0
		_refresh_pois()


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
		if enc != null and available_ids.has(enc.encounter_id):
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


func _update_hud() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return
	arc_label.text = gs.current_arc.to_upper()
	region_label.text = gs.current_region.replace("_", " ").capitalize()
	crystals_label.text = "Crystals: %d" % gs.crystal_inventory
	salvage_label.text = "Salvage: %d" % gs.salvage
	if gs.player_ship:
		hull_label.text = "Hull: %d/%d" % [gs.player_ship.current_hull, gs.player_ship.max_hull]


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


func _draw() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return

	var center := size * 0.5
	_draw_starfield(center, gs)

	if _ship_texture != null:
		draw_texture_rect(
			_ship_texture,
			Rect2(center - (SHIP_DRAW_SIZE * 0.5), SHIP_DRAW_SIZE),
			false,
			Color(1, 1, 1, 0.95)
		)
	else:
		draw_circle(center, SHIP_COLLISION_RADIUS, Color(0.72, 0.34, 0.9))

	var default_font: Font = ThemeDB.fallback_font
	for poi in _active_pois:
		var sx: float = center.x + (poi["x"] - gs.position_x)
		var sy: float = center.y + (poi["y"] - gs.position_y)
		var screen_pos := Vector2(sx, sy)
		var poi_color: Color = poi.get("color", Color(1.0, 0.82, 0.45))

		draw_circle(screen_pos, poi["radius"], poi_color * Color(1, 1, 1, 0.18))
		draw_arc(screen_pos, poi["radius"], 0.0, TAU, 48, poi_color, 2.0)
		draw_circle(screen_pos, 7.0, poi_color)

		if default_font != null:
			var encounter: Encounter = poi["encounter"]
			draw_string(
				default_font,
				screen_pos + Vector2(16, -10),
				encounter.title,
				HORIZONTAL_ALIGNMENT_LEFT,
				260,
				14,
				Color(0.92, 0.95, 1.0)
			)


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
