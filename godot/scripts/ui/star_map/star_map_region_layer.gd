## StarMapRegionLayer — circular mid-zoom sector view with fog-of-war, POIs
## and player position. Extracted from the former `star_map_screen.gd`
## monolith (Sprint 5a). All GameSession access is via the injected VM.
class_name StarMapRegionLayer
extends RefCounted

const MAP_PADDING: float = 20.0
const POI_BLIP_SIZE: float = 6.0

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


## Draw the region (circular sector) layer.
## `ctx` carries: elapsed, selected_region, current_region, backdrop (ImageTexture),
## nav_pois (Array — optional, pulled from navigation controller by orchestrator).
func draw(canvas: Control, ctx: Dictionary) -> void:
	if not _vm.has_state() or not _vm.has_star_map():
		return

	var current_region: String = ctx.get("current_region", _vm.current_region())
	var selected_region: String = ctx.get("selected_region", "")
	var view_region: String = selected_region if not selected_region.is_empty() else current_region
	var bounds: Vector2 = _vm.region_bounds(view_region)

	var canvas_size: Vector2 = canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return

	var map_radius: float = (minf(canvas_size.x, canvas_size.y) - MAP_PADDING * 2) * 0.5
	var map_center := Vector2(canvas_size.x * 0.5, canvas_size.y * 0.5)

	var fit_diameter: float = map_radius * 1.8
	var scale_x: float = fit_diameter / maxf(bounds.x, 1.0)
	var scale_y: float = fit_diameter / maxf(bounds.y, 1.0)
	var map_scale: float = minf(scale_x, scale_y)
	var offset: Vector2 = map_center - (bounds * map_scale * 0.5)

	_draw_backdrop(canvas, ctx, map_center, map_radius, view_region)
	_draw_vignette(canvas, map_center, map_radius)
	_draw_grid(canvas, map_center, map_radius)
	_draw_fog(canvas, view_region, map_center, map_radius, map_scale, offset)

	var default_font: Font = ThemeDB.fallback_font
	var elapsed: float = ctx.get("elapsed", 0.0)
	_draw_pois(canvas, view_region, offset, map_scale, default_font, elapsed)

	if view_region == current_region:
		_draw_navigation_pois(canvas, ctx, offset, map_scale)
		_draw_player(canvas, offset, map_scale, default_font, map_center, map_radius)

	_draw_spawn_zones(canvas, view_region, offset, map_scale)
	_draw_legend(canvas, map_center, map_radius, view_region, default_font)
	_draw_chrome(canvas, canvas_size, view_region, current_region, default_font)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _draw_backdrop(
	canvas: Control,
	ctx: Dictionary,
	map_center: Vector2,
	map_radius: float,
	view_region: String,
) -> void:
	var backdrop: ImageTexture = ctx.get("backdrop")
	if backdrop != null:
		var region_tint: Color = ProceduralMapManager.get_region_tint(view_region)
		canvas.draw_texture_rect(
			backdrop,
			Rect2(
				map_center - Vector2(map_radius, map_radius),
				Vector2(map_radius * 2, map_radius * 2),
			),
			false,
			Color(region_tint.r, region_tint.g, region_tint.b, 0.25),
		)
	canvas.draw_circle(map_center, map_radius, Color(0.02, 0.03, 0.07, 0.35))


func _draw_vignette(canvas: Control, map_center: Vector2, map_radius: float) -> void:
	var ring_count: int = 20
	var vignette_depth: float = map_radius * 0.35
	var ring_w: float = vignette_depth / float(ring_count)
	for i in range(ring_count):
		var r: float = map_radius - float(i) * ring_w
		var t: float = float(i) / float(ring_count)
		var alpha: float = lerpf(0.55, 0.0, t * t)
		canvas.draw_arc(map_center, r, 0.0, TAU, 64, Color(0.02, 0.03, 0.07, alpha), ring_w + 1.0)

	canvas.draw_arc(map_center, map_radius + 3.0, 0.0, TAU, 64, Color(0.15, 0.3, 0.6, 0.1), 4.0)
	canvas.draw_arc(map_center, map_radius, 0.0, TAU, 64, Color(0.25, 0.45, 0.75, 0.35), 1.5)


func _draw_grid(canvas: Control, map_center: Vector2, map_radius: float) -> void:
	var grid_rings: int = 4
	for i in range(1, grid_rings + 1):
		var gr: float = map_radius * float(i) / float(grid_rings)
		canvas.draw_arc(map_center, gr, 0.0, TAU, 64, Color(0.1, 0.2, 0.3, 0.15), 1.0)
	var radial_count: int = 8
	for i in range(radial_count):
		var angle: float = TAU * float(i) / float(radial_count)
		var end_pt: Vector2 = map_center + Vector2(cos(angle), sin(angle)) * map_radius
		canvas.draw_line(map_center, end_pt, Color(0.1, 0.2, 0.3, 0.12), 1.0)


func _draw_fog(
	canvas: Control,
	region_id: String,
	map_center: Vector2,
	map_radius: float,
	map_scale: float,
	offset: Vector2,
) -> void:
	var map_def: Dictionary = _vm.region_map(region_id)
	var cell_size: int = map_def.get("fog_grid_size", 64)
	var dims: Vector2i = _vm.grid_dimensions(region_id)
	if dims == Vector2i.ZERO:
		return

	var soft_radius: int = 3
	var revealed_map: PackedByteArray = PackedByteArray()
	revealed_map.resize(dims.x * dims.y)
	revealed_map.fill(0)
	for cy in range(dims.y):
		for cx in range(dims.x):
			if _vm.is_cell_revealed(region_id, cx, cy):
				revealed_map[cy * dims.x + cx] = 1

	for cy in range(dims.y):
		for cx in range(dims.x):
			if revealed_map[cy * dims.x + cx] == 1:
				continue
			var cwx: float = cx * cell_size + cell_size * 0.5
			var cwy: float = cy * cell_size + cell_size * 0.5
			var csx: float = offset.x + cwx * map_scale
			var csy: float = offset.y + cwy * map_scale
			var cell_pos := Vector2(csx, csy)
			var cell_dist: float = cell_pos.distance_to(map_center)
			if cell_dist >= map_radius:
				continue
			var circle_edge_t: float = clampf(cell_dist / map_radius, 0.0, 1.0)
			var circle_edge_fade: float = lerpf(1.0, 0.0, circle_edge_t * circle_edge_t * circle_edge_t)

			var min_dist: int = soft_radius + 1
			for scan_dy in range(-soft_radius, soft_radius + 1):
				var scy: int = cy + scan_dy
				if scy < 0 or scy >= dims.y:
					continue
				for scan_dx in range(-soft_radius, soft_radius + 1):
					var scx: int = cx + scan_dx
					if scx < 0 or scx >= dims.x:
						continue
					if revealed_map[scy * dims.x + scx] == 1:
						var d: int = absi(scan_dx) + absi(scan_dy)
						if d < min_dist:
							min_dist = d

			var noise_r: float = 0.04 + 0.03 * sin(float(cx) * 0.7 + float(cy) * 1.3)
			var noise_g: float = 0.06 + 0.04 * sin(float(cx) * 1.1 + float(cy) * 0.9 + 2.0)
			var noise_b: float = 0.12 + 0.05 * sin(float(cx) * 0.5 + float(cy) * 1.7 + 4.0)

			if min_dist > soft_radius:
				var fog_alpha: float = 0.65 * circle_edge_fade
				var sw: float = cell_size * map_scale
				canvas.draw_rect(Rect2(csx - sw * 0.5, csy - sw * 0.5, sw, sw), Color(noise_r, noise_g, noise_b, fog_alpha))
			else:
				var t: float = float(min_dist) / float(soft_radius)
				var base_alpha: float = lerpf(0.12, 0.55, t * t) * circle_edge_fade
				var r: float = cell_size * map_scale * lerpf(0.45, 0.75, t)
				canvas.draw_circle(cell_pos, r * 1.5, Color(noise_r, noise_g, noise_b, base_alpha * 0.3))
				canvas.draw_circle(cell_pos, r, Color(noise_r, noise_g, noise_b, base_alpha))


func _draw_pois(
	canvas: Control,
	view_region: String,
	offset: Vector2,
	map_scale: float,
	default_font: Font,
	elapsed: float,
) -> void:
	for poi in _vm.visible_story_pois(view_region):
		var px: float = offset.x + poi.get("x", 0.0) * map_scale
		var py: float = offset.y + poi.get("y", 0.0) * map_scale
		var color: Color = TYPE_COLORS.get("story", Color(1.0, 0.82, 0.25))
		var pulse: float = 1.0 + 0.2 * sin(elapsed * 2.5)
		canvas.draw_circle(Vector2(px, py), POI_BLIP_SIZE * pulse, color)
		canvas.draw_arc(Vector2(px, py), POI_BLIP_SIZE * 2.0 * pulse, 0.0, TAU, 24, color * Color(1, 1, 1, 0.4), 1.5)
		if default_font:
			canvas.draw_string(default_font, Vector2(px + 10, py + 4), poi.get("label", ""), HORIZONTAL_ALIGNMENT_LEFT, 200, 11, color)

	for poi in _vm.visible_hidden_pois(view_region):
		var px: float = offset.x + poi.get("x", 0.0) * map_scale
		var py: float = offset.y + poi.get("y", 0.0) * map_scale
		var poi_type: String = poi.get("type", "treasure")
		var color: Color = TYPE_COLORS.get(poi_type, Color(0.75, 0.4, 1.0))
		canvas.draw_circle(Vector2(px, py), POI_BLIP_SIZE * 0.8, color)
		if default_font:
			canvas.draw_string(default_font, Vector2(px + 8, py + 4), poi.get("label", ""), HORIZONTAL_ALIGNMENT_LEFT, 200, 10, color)

	for poi in _vm.visible_spawns(view_region):
		var px: float = offset.x + poi.get("x", 0.0) * map_scale
		var py: float = offset.y + poi.get("y", 0.0) * map_scale
		var spawn_type: String = poi.get("type", "combat")
		var color: Color = TYPE_COLORS.get(spawn_type, Color(1.0, 0.3, 0.3))
		canvas.draw_circle(Vector2(px, py), POI_BLIP_SIZE * 0.6, color)


func _draw_navigation_pois(
	canvas: Control, ctx: Dictionary, offset: Vector2, map_scale: float
) -> void:
	var nav_pois: Array = ctx.get("nav_pois", [])
	for poi in nav_pois:
		var px: float = offset.x + poi.get("x", 0.0) * map_scale
		var py: float = offset.y + poi.get("y", 0.0) * map_scale
		var poi_color: Color = poi.get("color", Color(1.0, 0.82, 0.45))
		canvas.draw_circle(Vector2(px, py), POI_BLIP_SIZE * 0.7, poi_color)


func _draw_player(
	canvas: Control,
	offset: Vector2,
	map_scale: float,
	default_font: Font,
	map_center: Vector2,
	map_radius: float,
) -> void:
	var player_pos: Vector2 = _vm.player_position()
	var player_screen := Vector2(
		offset.x + player_pos.x * map_scale,
		offset.y + player_pos.y * map_scale,
	)
	# The world bounds are rectangular but the sector is rendered as a circle,
	# so a player at a corner of the world maps outside the visible circle.
	# Clamp the marker to the inner edge so "YOU" never floats in the vignette.
	var delta: Vector2 = player_screen - map_center
	var max_r: float = maxf(map_radius - 12.0, 0.0)
	if delta.length() > max_r:
		player_screen = map_center + delta.normalized() * max_r
	canvas.draw_circle(player_screen, 5.0, Color(0.43, 0.84, 1.0))
	canvas.draw_arc(player_screen, 9.0, 0.0, TAU, 24, Color(0.43, 0.84, 1.0, 0.5), 1.5)
	if default_font:
		canvas.draw_string(
			default_font,
			player_screen + Vector2(10, -4),
			"YOU",
			HORIZONTAL_ALIGNMENT_LEFT,
			100,
			11,
			Color(0.43, 0.84, 1.0),
		)


func _draw_spawn_zones(
	canvas: Control, view_region: String, offset: Vector2, map_scale: float
) -> void:
	var map_def: Dictionary = _vm.region_map(view_region)
	for zone in map_def.get("spawn_zones", []):
		var zx: float = offset.x + zone.get("x", 0.0) * map_scale
		var zy: float = offset.y + zone.get("y", 0.0) * map_scale
		var zr: float = zone.get("radius", 500.0) * map_scale
		canvas.draw_arc(Vector2(zx, zy), zr, 0.0, TAU, 48, Color(0.2, 0.2, 0.3, 0.15), 1.0)


func _draw_legend(
	canvas: Control,
	center: Vector2,
	radius: float,
	view_region: String,
	default_font: Font,
) -> void:
	if default_font == null:
		return
	var lx: float = center.x + radius + 15.0
	var ly: float = center.y - radius * 0.6
	var line_h: float = 18.0
	var items: Array = [
		["STORY", TYPE_COLORS.get("story", Color.YELLOW)],
		["COMBAT", TYPE_COLORS.get("combat", Color.RED)],
		["RESCUE", TYPE_COLORS.get("rescue", Color.ORANGE)],
		["TRADE", TYPE_COLORS.get("trade", Color.GREEN)],
		["HIDDEN", TYPE_COLORS.get("treasure", Color.PURPLE)],
		["YOU", Color(0.43, 0.84, 1.0)],
	]
	canvas.draw_string(default_font, Vector2(lx, ly), "LEGEND", HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color(0.6, 0.75, 0.9))
	ly += line_h
	for item in items:
		canvas.draw_circle(Vector2(lx + 6, ly - 3), 4.0, item[1])
		canvas.draw_string(default_font, Vector2(lx + 16, ly), item[0], HORIZONTAL_ALIGNMENT_LEFT, 100, 11, item[1])
		ly += line_h

	ly += 10
	var has_map: bool = _vm.has_map(view_region)
	var carto: bool = _vm.cartographer_rescued()
	var info_color := Color(0.5, 0.7, 0.85)
	canvas.draw_string(default_font, Vector2(lx, ly), "MAP: %s" % ("OWNED" if has_map else "UNCHARTED"), HORIZONTAL_ALIGNMENT_LEFT, 120, 11, info_color)
	ly += line_h
	canvas.draw_string(default_font, Vector2(lx, ly), "CARTO: %s" % ("YES" if carto else "NO"), HORIZONTAL_ALIGNMENT_LEFT, 120, 11, info_color)


func _draw_chrome(
	canvas: Control,
	canvas_size: Vector2,
	view_region: String,
	current_region: String,
	default_font: Font,
) -> void:
	if default_font == null:
		return
	var breadcrumb: String = "GALAXY > %s" % _vm.region_display_name(view_region).to_upper()
	canvas.draw_string(default_font, Vector2(MAP_PADDING, 16), breadcrumb, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x), 11, Color(0.5, 0.6, 0.7, 0.6))

	var is_current: bool = view_region == current_region
	var subtitle: String = "Sector map showing fog of war, points of interest, and your position." if is_current else "Viewing sector chart. This is not your current region."
	canvas.draw_string(default_font, Vector2(MAP_PADDING, 30), subtitle, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 10, Color(0.5, 0.6, 0.7, 0.45))

	var hint_color := Color(0.5, 0.6, 0.7, 0.7)
	var hint_bg := Color(0.02, 0.03, 0.07, 0.5)
	canvas.draw_rect(Rect2(0, canvas_size.y - 36, canvas_size.x, 36), hint_bg)
	var hint1: String = "ESC to return to Galaxy view"
	if is_current:
		hint1 += "  |  ENTER for Local Scan (zoomed view around your ship)"
	var hint2: String = "TAB to close the Codex and return to navigation"
	canvas.draw_string(default_font, Vector2(MAP_PADDING, canvas_size.y - 22), hint1, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 11, hint_color)
	canvas.draw_string(default_font, Vector2(MAP_PADDING, canvas_size.y - 8), hint2, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 11, hint_color * Color(1, 1, 1, 0.7))
