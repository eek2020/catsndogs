## StarMapLocalLayer — player-centered zoomed-in scan. Extracted from the
## former `star_map_screen.gd` monolith (Sprint 5a). All GameSession access
## is via the injected VM.
class_name StarMapLocalLayer
extends RefCounted

const MAP_PADDING: float = 20.0
const POI_BLIP_SIZE: float = 6.0
const LOCAL_WORLD_RANGE: float = 1200.0

const TYPE_COLORS := {
	"story": Color(1.0, 0.82, 0.25),
	"combat": Color(1.0, 0.2, 0.2),
	"rescue": Color(1.0, 0.62, 0.35),
	"trade": Color(0.52, 1.0, 0.35),
	"treasure": Color(0.75, 0.4, 1.0),
	"abandoned_ship": Color(0.75, 0.4, 1.0),
	"crystal_hoard": Color(0.75, 0.4, 1.0),
	"distress_signal": Color(1.0, 0.62, 0.35),
}

var _vm: StarMapViewModel


func _init(vm: StarMapViewModel) -> void:
	_vm = vm


## Draw the local (player-centered) layer.
## `ctx` carries: elapsed, current_region, nav_pois (Array).
func draw(canvas: Control, ctx: Dictionary) -> void:
	if not _vm.has_state() or not _vm.has_star_map():
		return

	var canvas_size: Vector2 = canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return

	var default_font: Font = ThemeDB.fallback_font
	var current_region: String = ctx.get("current_region", _vm.current_region())
	var player_world: Vector2 = _vm.player_position()
	var bounds: Vector2 = _vm.region_bounds(current_region)

	var half_range: float = LOCAL_WORLD_RANGE * 0.5
	var aspect: float = canvas_size.x / canvas_size.y
	var world_half_w: float = half_range * aspect
	var world_half_h: float = half_range
	var local_scale: float = canvas_size.y / LOCAL_WORLD_RANGE
	var world_left: float = player_world.x - world_half_w
	var world_top: float = player_world.y - world_half_h

	canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.02, 0.03, 0.07, 0.55))
	_draw_grid(canvas, canvas_size, player_world, world_left, world_top, world_half_w, world_half_h, local_scale)
	_draw_fog(canvas, current_region, player_world, world_left, world_top, world_half_w, world_half_h, local_scale)
	_draw_boundaries(canvas, canvas_size, player_world, world_left, world_top, world_half_w, world_half_h, bounds, local_scale)
	_draw_pois(canvas, current_region, world_left, world_top, local_scale, canvas_size, ctx.get("nav_pois", []), default_font, ctx.get("elapsed", 0.0))
	_draw_player(canvas, canvas_size, local_scale)
	_draw_chrome(canvas, canvas_size, current_region, player_world, default_font)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _draw_grid(
	canvas: Control,
	canvas_size: Vector2,
	player_world: Vector2,
	world_left: float,
	world_top: float,
	world_half_w: float,
	world_half_h: float,
	local_scale: float,
) -> void:
	var grid_spacing_world: float = 200.0
	var grid_color := Color(0.1, 0.15, 0.25, 0.15)
	var grid_start_x: float = floorf(world_left / grid_spacing_world) * grid_spacing_world
	var grid_start_y: float = floorf(world_top / grid_spacing_world) * grid_spacing_world
	var gx: float = grid_start_x
	while gx < player_world.x + world_half_w:
		var sx: float = (gx - world_left) * local_scale
		canvas.draw_line(Vector2(sx, 0), Vector2(sx, canvas_size.y), grid_color, 1.0)
		gx += grid_spacing_world
	var gy: float = grid_start_y
	while gy < player_world.y + world_half_h:
		var sy: float = (gy - world_top) * local_scale
		canvas.draw_line(Vector2(0, sy), Vector2(canvas_size.x, sy), grid_color, 1.0)
		gy += grid_spacing_world


func _draw_fog(
	canvas: Control,
	region_id: String,
	player_world: Vector2,
	world_left: float,
	world_top: float,
	world_half_w: float,
	world_half_h: float,
	local_scale: float,
) -> void:
	var map_def: Dictionary = _vm.region_map(region_id)
	var cell_size: int = map_def.get("fog_grid_size", 64)
	var dims: Vector2i = _vm.grid_dimensions(region_id)
	if dims == Vector2i.ZERO:
		return

	var cell_screen_w: float = cell_size * local_scale
	var cx_min: int = maxi(0, int((player_world.x - world_half_w) / cell_size) - 1)
	var cx_max: int = mini(dims.x - 1, int((player_world.x + world_half_w) / cell_size) + 1)
	var cy_min: int = maxi(0, int((player_world.y - world_half_h) / cell_size) - 1)
	var cy_max: int = mini(dims.y - 1, int((player_world.y + world_half_h) / cell_size) + 1)

	for cy in range(cy_min, cy_max + 1):
		for cx in range(cx_min, cx_max + 1):
			if _vm.is_cell_revealed(region_id, cx, cy):
				continue
			var cwx: float = cx * cell_size + cell_size * 0.5
			var cwy: float = cy * cell_size + cell_size * 0.5
			var sx: float = (cwx - world_left) * local_scale
			var sy: float = (cwy - world_top) * local_scale

			var has_revealed_neighbor: bool = false
			for ndy in [-1, 0, 1]:
				for ndx in [-1, 0, 1]:
					if ndx == 0 and ndy == 0:
						continue
					if _vm.is_cell_revealed(region_id, cx + ndx, cy + ndy):
						has_revealed_neighbor = true
						break
				if has_revealed_neighbor:
					break

			var noise_r: float = 0.04 + 0.03 * sin(float(cx) * 0.7 + float(cy) * 1.3)
			var noise_g: float = 0.06 + 0.04 * sin(float(cx) * 1.1 + float(cy) * 0.9 + 2.0)
			var noise_b: float = 0.12 + 0.05 * sin(float(cx) * 0.5 + float(cy) * 1.7 + 4.0)

			if has_revealed_neighbor:
				canvas.draw_circle(Vector2(sx, sy), cell_screen_w * 0.7, Color(noise_r, noise_g, noise_b, 0.35))
			else:
				canvas.draw_rect(Rect2(sx - cell_screen_w * 0.5, sy - cell_screen_w * 0.5, cell_screen_w, cell_screen_w), Color(noise_r, noise_g, noise_b, 0.6))


func _draw_boundaries(
	canvas: Control,
	canvas_size: Vector2,
	player_world: Vector2,
	world_left: float,
	world_top: float,
	world_half_w: float,
	world_half_h: float,
	bounds: Vector2,
	local_scale: float,
) -> void:
	var boundary_color := Color(0.25, 0.45, 0.75, 0.3)
	if world_left < 0:
		var bx: float = (0.0 - world_left) * local_scale
		canvas.draw_line(Vector2(bx, 0), Vector2(bx, canvas_size.y), boundary_color, 2.0)
	if player_world.x + world_half_w > bounds.x:
		var bx: float = (bounds.x - world_left) * local_scale
		canvas.draw_line(Vector2(bx, 0), Vector2(bx, canvas_size.y), boundary_color, 2.0)
	if world_top < 0:
		var by: float = (0.0 - world_top) * local_scale
		canvas.draw_line(Vector2(0, by), Vector2(canvas_size.x, by), boundary_color, 2.0)
	if player_world.y + world_half_h > bounds.y:
		var by: float = (bounds.y - world_top) * local_scale
		canvas.draw_line(Vector2(0, by), Vector2(canvas_size.x, by), boundary_color, 2.0)


func _draw_pois(
	canvas: Control,
	region_id: String,
	world_left: float,
	world_top: float,
	local_scale: float,
	canvas_size: Vector2,
	nav_pois: Array,
	default_font: Font,
	elapsed: float,
) -> void:
	var all_pois: Array = []

	for poi in _vm.visible_story_pois(region_id):
		var p: Dictionary = poi.duplicate()
		p["_color"] = TYPE_COLORS.get("story", Color.YELLOW)
		p["_size"] = POI_BLIP_SIZE * 1.5
		p["_pulse"] = true
		all_pois.append(p)

	for poi in _vm.visible_hidden_pois(region_id):
		var p: Dictionary = poi.duplicate()
		p["_color"] = TYPE_COLORS.get(poi.get("type", "treasure"), Color(0.75, 0.4, 1.0))
		p["_size"] = POI_BLIP_SIZE * 1.2
		p["_pulse"] = false
		all_pois.append(p)

	for poi in _vm.visible_spawns(region_id):
		var p: Dictionary = poi.duplicate()
		p["_color"] = TYPE_COLORS.get(poi.get("type", "combat"), Color(1.0, 0.3, 0.3))
		p["_size"] = POI_BLIP_SIZE
		p["_pulse"] = false
		all_pois.append(p)

	for poi in nav_pois:
		var p: Dictionary = poi.duplicate()
		p["_color"] = poi.get("color", Color(1.0, 0.82, 0.45))
		p["_size"] = POI_BLIP_SIZE
		p["_pulse"] = false
		all_pois.append(p)

	for poi in all_pois:
		var wx: float = poi.get("x", 0.0)
		var wy: float = poi.get("y", 0.0)
		var sx: float = (wx - world_left) * local_scale
		var sy: float = (wy - world_top) * local_scale
		if sx < -20 or sx > canvas_size.x + 20 or sy < -20 or sy > canvas_size.y + 20:
			continue
		var color: Color = poi.get("_color", Color.WHITE)
		var sz: float = poi.get("_size", POI_BLIP_SIZE)
		if poi.get("_pulse", false):
			sz *= 1.0 + 0.2 * sin(elapsed * 2.5)
		canvas.draw_circle(Vector2(sx, sy), sz, color)
		var label: String = poi.get("label", "")
		if not label.is_empty() and default_font:
			canvas.draw_string(default_font, Vector2(sx + sz + 4, sy + 4), label, HORIZONTAL_ALIGNMENT_LEFT, 200, 11, color)


func _draw_player(canvas: Control, canvas_size: Vector2, local_scale: float) -> void:
	var player_sx: float = canvas_size.x * 0.5
	var player_sy: float = canvas_size.y * 0.5
	canvas.draw_circle(Vector2(player_sx, player_sy), 6.0, Color(0.43, 0.84, 1.0))
	canvas.draw_arc(Vector2(player_sx, player_sy), 12.0, 0.0, TAU, 24, Color(0.43, 0.84, 1.0, 0.4), 1.5)
	var vision_screen_r: float = 200.0 * local_scale
	canvas.draw_arc(Vector2(player_sx, player_sy), vision_screen_r, 0.0, TAU, 48, Color(0.43, 0.84, 1.0, 0.12), 1.0)


func _draw_chrome(
	canvas: Control,
	canvas_size: Vector2,
	current_region: String,
	player_world: Vector2,
	default_font: Font,
) -> void:
	if default_font == null:
		return
	var breadcrumb: String = "GALAXY > %s > LOCAL" % _vm.region_display_name(current_region).to_upper()
	canvas.draw_string(default_font, Vector2(MAP_PADDING, 16), breadcrumb, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - 140), 11, Color(0.5, 0.6, 0.7, 0.6))

	var subtitle: String = "Zoomed scan centered on your ship. Nearby contacts and fog detail visible."
	canvas.draw_string(default_font, Vector2(MAP_PADDING, 30), subtitle, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 10, Color(0.5, 0.6, 0.7, 0.45))

	var coord_str: String = "Position: (%d, %d)" % [int(player_world.x), int(player_world.y)]
	canvas.draw_string(default_font, Vector2(canvas_size.x - 160, 16), coord_str, HORIZONTAL_ALIGNMENT_LEFT, 160, 11, Color(0.43, 0.84, 1.0, 0.5))

	var hint_color := Color(0.5, 0.6, 0.7, 0.7)
	var hint_bg := Color(0.02, 0.03, 0.07, 0.5)
	canvas.draw_rect(Rect2(0, canvas_size.y - 36, canvas_size.x, 36), hint_bg)
	canvas.draw_string(default_font, Vector2(MAP_PADDING, canvas_size.y - 22), "ESC to return to Region view  |  TAB to close the Codex", HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 11, hint_color)
	canvas.draw_string(default_font, Vector2(MAP_PADDING, canvas_size.y - 8), "The inner circle shows your ship's sensor range", HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 11, hint_color * Color(1, 1, 1, 0.7))
