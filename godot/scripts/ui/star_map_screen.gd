## Celestial Codex — 3-layer map overlay (Galaxy / Region / Local).
extends Control

enum Layer { GALAXY, REGION, LOCAL }

@onready var close_btn: Button = $Panel/VBox/CloseBtn
@onready var title_label: Label = $Panel/VBox/Title
@onready var map_canvas: Control = $Panel/VBox/MapCanvas

var _layer: Layer = Layer.GALAXY
var _region_id: String = ""
var _bounds: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _selected_region: String = ""

const MAP_PADDING: float = 20.0
const POI_BLIP_SIZE: float = 6.0
const LEGEND_WIDTH: float = 140.0
const GALAXY_NODE_RADIUS: float = 28.0
const LOCAL_WORLD_RANGE: float = 1200.0

const TYPE_COLORS := {
	"story": Color(1.0, 0.82, 0.25),
	"combat": Color(1.0, 0.2, 0.2),
	"rescue": Color(1.0, 0.62, 0.35),
	"trade": Color(0.52, 1.0, 0.35),
	"exploration": Color(0.5, 1.0, 0.62),
	"treasure": Color(0.75, 0.4, 1.0),
	"abandoned_ship": Color(0.75, 0.4, 1.0),
	"crystal_hoard": Color(0.75, 0.4, 1.0),
	"distress_signal": Color(1.0, 0.62, 0.35),
}


func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	map_canvas.draw.connect(_on_map_canvas_draw)
	close_btn.grab_focus()
	_load_map_data()


func _process(dt: float) -> void:
	_elapsed += dt
	map_canvas.queue_redraw()


func _load_map_data() -> void:
	if GameSession.game_state == null:
		return
	_region_id = GameSession.game_state.current_region
	var sms: StarMapSystem = GameSession.star_map_system
	if sms == null:
		return
	_bounds = sms.get_bounds(_region_id)
	_selected_region = _region_id
	_update_title()


func _update_title() -> void:
	match _layer:
		Layer.GALAXY:
			title_label.text = "CELESTIAL CODEX"
		Layer.REGION:
			var region_name: String = _selected_region.replace("_", " ").capitalize()
			title_label.text = "CELESTIAL CODEX — %s" % region_name.to_upper()
		Layer.LOCAL:
			title_label.text = "CELESTIAL CODEX — LOCAL SCAN"


# ---------------------------------------------------------------------------
# Draw dispatcher
# ---------------------------------------------------------------------------

func _on_map_canvas_draw() -> void:
	if GameSession.game_state == null:
		return
	match _layer:
		Layer.GALAXY:
			_draw_galaxy_layer()
		Layer.REGION:
			_draw_region_layer()
		Layer.LOCAL:
			_draw_local_layer()


# ---------------------------------------------------------------------------
# Galaxy layer
# ---------------------------------------------------------------------------

func _draw_galaxy_layer() -> void:
	var sms: StarMapSystem = GameSession.star_map_system
	var exploration: ExplorationSystem = GameSession.exploration
	if sms == null or exploration == null:
		return

	var canvas_size: Vector2 = map_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return

	var default_font: Font = ThemeDB.fallback_font

	# Background
	map_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.02, 0.03, 0.07, 0.6))

	# Vignette
	var center := canvas_size * 0.5
	var vr: float = minf(canvas_size.x, canvas_size.y) * 0.48
	for i in range(15):
		var r: float = vr + float(i) * 8.0
		var t: float = float(i) / 15.0
		map_canvas.draw_arc(center, r, 0.0, TAU, 64, Color(0.02, 0.03, 0.07, t * 0.5), 8.0)

	# Usable area with padding
	var pad: float = 60.0
	var area_origin := Vector2(pad, pad)
	var area_size := canvas_size - Vector2(pad * 2, pad * 2) - Vector2(LEGEND_WIDTH, 0)

	# Collect region data
	var nodes: Dictionary = sms.galaxy_layout.get("nodes", {})

	# Draw connection lines first (behind nodes)
	for region_id in nodes:
		var region: ExplorationSystem.Region = exploration.regions.get(region_id)
		if region == null:
			continue
		var pos_a: Vector2 = _galaxy_node_screen_pos(region_id, area_origin, area_size, nodes)
		for connected_id in region.connected_regions:
			# Avoid drawing each connection twice
			if connected_id < region_id:
				continue
			var pos_b: Vector2 = _galaxy_node_screen_pos(connected_id, area_origin, area_size, nodes)
			var both_discovered: bool = region.is_discovered
			var connected_region: ExplorationSystem.Region = exploration.regions.get(connected_id)
			if connected_region != null:
				both_discovered = both_discovered and connected_region.is_discovered
			if both_discovered:
				map_canvas.draw_line(pos_a, pos_b, Color(0.3, 0.5, 0.7, 0.4), 2.0)
			else:
				# Dashed line for connections involving undiscovered regions
				_draw_dashed_line(pos_a, pos_b, Color(0.15, 0.25, 0.35, 0.3), 1.5, 8.0, 6.0)

	# Draw nodes
	var gs: GameStateData = GameSession.game_state
	for region_id in nodes:
		var region: ExplorationSystem.Region = exploration.regions.get(region_id)
		var node_pos: Vector2 = _galaxy_node_screen_pos(region_id, area_origin, area_size, nodes)
		var node_color: Color = sms.get_galaxy_node_color(region_id)
		var is_current: bool = region_id == gs.current_region
		var is_selected: bool = region_id == _selected_region
		var discovered: bool = region != null and region.is_discovered
		var has_map: bool = sms.has_map(region_id)

		if discovered:
			# Fog percentage arc around the node
			var fog_pct: float = sms.get_region_fog_percentage(region_id)
			if fog_pct > 0.0:
				var arc_angle: float = TAU * fog_pct
				map_canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS + 5.0, -PI * 0.5, -PI * 0.5 + arc_angle, 48, node_color * Color(1, 1, 1, 0.35), 3.0)

			if has_map:
				# Full color filled circle
				map_canvas.draw_circle(node_pos, GALAXY_NODE_RADIUS, node_color * Color(1, 1, 1, 0.3))
				map_canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS, 0.0, TAU, 48, node_color, 2.0)
			else:
				# Dim outline only
				map_canvas.draw_circle(node_pos, GALAXY_NODE_RADIUS, node_color * Color(1, 1, 1, 0.1))
				map_canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS, 0.0, TAU, 48, node_color * Color(1, 1, 1, 0.5), 1.5)

			# Region name label
			var label_offset_y: int = nodes.get(region_id, {}).get("label_offset_y", -1)
			var label_y: float = node_pos.y + (GALAXY_NODE_RADIUS + 14.0) * label_offset_y
			var region_name: String = ""
			if region != null:
				region_name = region.region_name
			else:
				region_name = region_id.replace("_", " ").capitalize()
			if default_font:
				var text_w: float = default_font.get_string_size(region_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				map_canvas.draw_string(default_font, Vector2(node_pos.x - text_w * 0.5, label_y), region_name, HORIZONTAL_ALIGNMENT_LEFT, 200, 11, node_color)
				if not has_map:
					var uc_w: float = default_font.get_string_size("UNCHARTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
					var sub_y: float = label_y + 12.0 * label_offset_y
					map_canvas.draw_string(default_font, Vector2(node_pos.x - uc_w * 0.5, sub_y), "UNCHARTED", HORIZONTAL_ALIGNMENT_LEFT, 200, 9, node_color * Color(1, 1, 1, 0.5))
		else:
			# Undiscovered — dark silhouette
			map_canvas.draw_circle(node_pos, GALAXY_NODE_RADIUS, Color(0.08, 0.1, 0.15, 0.5))
			map_canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS, 0.0, TAU, 48, Color(0.2, 0.25, 0.3, 0.4), 1.5)
			if default_font:
				var q_w: float = default_font.get_string_size("???", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				map_canvas.draw_string(default_font, Vector2(node_pos.x - q_w * 0.5, node_pos.y + 4), "???", HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color(0.3, 0.35, 0.4, 0.6))

		# Current region indicator — pulsing cyan ring
		if is_current:
			var pulse: float = 1.0 + 0.15 * sin(_elapsed * 3.0)
			map_canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS * pulse + 3.0, 0.0, TAU, 48, Color(0.43, 0.84, 1.0, 0.6), 2.0)

		# Selection cursor — bright ring
		if is_selected:
			var sel_pulse: float = 1.0 + 0.08 * sin(_elapsed * 5.0)
			map_canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS * sel_pulse + 8.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.7), 2.0)

	# Danger level indicators inside nodes
	for region_id in nodes:
		var region: ExplorationSystem.Region = exploration.regions.get(region_id)
		if region == null or not region.is_discovered:
			continue
		var node_pos: Vector2 = _galaxy_node_screen_pos(region_id, area_origin, area_size, nodes)
		if default_font:
			var danger_str: String = ""
			for _i in range(region.danger_level):
				danger_str += "*"
			var dw: float = default_font.get_string_size(danger_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			map_canvas.draw_string(default_font, Vector2(node_pos.x - dw * 0.5, node_pos.y + 4), danger_str, HORIZONTAL_ALIGNMENT_LEFT, 100, 10, Color(1.0, 0.4, 0.3, 0.7))

	# Layer description subtitle
	if default_font:
		var subtitle: String = "Navigate the known galaxy. Select a region to view its sector map."
		var sub_w: float = default_font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		map_canvas.draw_string(default_font, Vector2(canvas_size.x * 0.5 - sub_w * 0.5, 18), subtitle, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x), 10, Color(0.5, 0.6, 0.7, 0.5))

	# Selected region info box
	if not _selected_region.is_empty() and default_font:
		_draw_galaxy_info_box(canvas_size, area_origin, pad)

	# Control hints — two-line with description
	if default_font:
		var hint_color := Color(0.5, 0.6, 0.7, 0.7)
		var hint_bg_color := Color(0.02, 0.03, 0.07, 0.5)
		map_canvas.draw_rect(Rect2(0, canvas_size.y - 36, canvas_size.x, 36), hint_bg_color)
		var hint1: String = "ARROWS select region, ENTER view sector, SPACE travel to region"
		var hint2: String = "TAB to close the Codex"
		map_canvas.draw_string(default_font, Vector2(pad, canvas_size.y - 22), hint1, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - pad * 2), 11, hint_color)
		map_canvas.draw_string(default_font, Vector2(pad, canvas_size.y - 8), hint2, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - pad * 2), 11, hint_color * Color(1, 1, 1, 0.7))

	# Galaxy legend
	_draw_galaxy_legend(area_origin, area_size, canvas_size)

	# Travel confirmation overlay
	_draw_travel_confirm(canvas_size)


func _galaxy_node_screen_pos(region_id: String, area_origin: Vector2, area_size: Vector2, nodes: Dictionary) -> Vector2:
	var node: Dictionary = nodes.get(region_id, {})
	var gx: float = node.get("gx", 0.5)
	var gy: float = node.get("gy", 0.5)
	return area_origin + Vector2(gx * area_size.x, gy * area_size.y)


func _draw_dashed_line(p_from: Vector2, p_to: Vector2, p_color: Color, p_width: float, dash_len: float, gap_len: float) -> void:
	var dir: Vector2 = (p_to - p_from)
	var total_len: float = dir.length()
	if total_len < 1.0:
		return
	dir = dir / total_len
	var pos: float = 0.0
	while pos < total_len:
		var seg_end: float = minf(pos + dash_len, total_len)
		map_canvas.draw_line(p_from + dir * pos, p_from + dir * seg_end, p_color, p_width)
		pos = seg_end + gap_len


func _draw_galaxy_legend(area_origin: Vector2, area_size: Vector2, canvas_size: Vector2) -> void:
	var default_font: Font = ThemeDB.fallback_font
	if default_font == null:
		return
	var lx: float = area_origin.x + area_size.x + 20.0
	var ly: float = area_origin.y + 20.0
	var line_h: float = 22.0

	map_canvas.draw_string(default_font, Vector2(lx, ly), "LEGEND", HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color(0.6, 0.75, 0.9))
	ly += line_h + 4

	# Current region
	map_canvas.draw_arc(Vector2(lx + 6, ly - 3), 5.0, 0.0, TAU, 16, Color(0.43, 0.84, 1.0, 0.6), 2.0)
	map_canvas.draw_string(default_font, Vector2(lx + 16, ly), "CURRENT", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.43, 0.84, 1.0))
	ly += line_h

	# Charted
	map_canvas.draw_circle(Vector2(lx + 6, ly - 3), 5.0, Color(0.6, 0.7, 0.3, 0.3))
	map_canvas.draw_arc(Vector2(lx + 6, ly - 3), 5.0, 0.0, TAU, 16, Color(0.6, 0.7, 0.3), 1.5)
	map_canvas.draw_string(default_font, Vector2(lx + 16, ly), "CHARTED", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.6, 0.7, 0.3))
	ly += line_h

	# Uncharted
	map_canvas.draw_arc(Vector2(lx + 6, ly - 3), 5.0, 0.0, TAU, 16, Color(0.5, 0.5, 0.5, 0.5), 1.5)
	map_canvas.draw_string(default_font, Vector2(lx + 16, ly), "UNCHARTED", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.5, 0.5, 0.5))
	ly += line_h

	# Unknown
	map_canvas.draw_circle(Vector2(lx + 6, ly - 3), 5.0, Color(0.08, 0.1, 0.15, 0.5))
	map_canvas.draw_string(default_font, Vector2(lx + 16, ly), "UNKNOWN", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.3, 0.35, 0.4, 0.6))
	ly += line_h + 8

	# Map and cartographer info
	var sms: StarMapSystem = GameSession.star_map_system
	if sms != null:
		var info_color := Color(0.5, 0.7, 0.85)
		var carto: bool = sms.cartographer_rescued
		map_canvas.draw_string(default_font, Vector2(lx, ly), "CARTO: %s" % ("YES" if carto else "NO"), HORIZONTAL_ALIGNMENT_LEFT, 120, 11, info_color)
		ly += line_h

		# Fog arc legend
		map_canvas.draw_arc(Vector2(lx + 6, ly - 3), 5.0, -PI * 0.5, PI * 0.5, 16, info_color * Color(1, 1, 1, 0.5), 2.0)
		map_canvas.draw_string(default_font, Vector2(lx + 16, ly), "FOG REVEAL", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, info_color)


func _draw_galaxy_info_box(canvas_size: Vector2, area_origin: Vector2, pad: float) -> void:
	var default_font: Font = ThemeDB.fallback_font
	if default_font == null:
		return
	var sms: StarMapSystem = GameSession.star_map_system
	var exploration: ExplorationSystem = GameSession.exploration
	if sms == null or exploration == null:
		return

	var region: ExplorationSystem.Region = exploration.regions.get(_selected_region)
	if region == null:
		return

	# Info box at the bottom-left above the control hints
	var box_x: float = pad
	var box_y: float = canvas_size.y - 120
	var box_w: float = 280.0
	var box_h: float = 78.0
	var box_color := Color(0.03, 0.05, 0.1, 0.7)
	var border_color := Color(0.2, 0.35, 0.5, 0.4)

	map_canvas.draw_rect(Rect2(box_x, box_y, box_w, box_h), box_color)
	map_canvas.draw_rect(Rect2(box_x, box_y, box_w, box_h), border_color, false, 1.0)

	var tx: float = box_x + 10
	var ty: float = box_y + 16
	var line_h: float = 16.0
	var label_color := Color(0.6, 0.75, 0.9)
	var value_color := Color(0.8, 0.85, 0.9)

	if not region.is_discovered:
		map_canvas.draw_string(default_font, Vector2(tx, ty), "UNKNOWN REGION", HORIZONTAL_ALIGNMENT_LEFT, 260, 12, Color(0.4, 0.45, 0.5))
		ty += line_h
		map_canvas.draw_string(default_font, Vector2(tx, ty), "Explore to reveal this sector", HORIZONTAL_ALIGNMENT_LEFT, 260, 10, Color(0.35, 0.4, 0.45))
		return

	# Region name
	map_canvas.draw_string(default_font, Vector2(tx, ty), region.region_name, HORIZONTAL_ALIGNMENT_LEFT, 260, 12, sms.get_galaxy_node_color(_selected_region))
	ty += line_h

	# Controlling faction
	var faction_name: String = region.controlling_faction.replace("_", " ").capitalize()
	map_canvas.draw_string(default_font, Vector2(tx, ty), "Faction: %s" % faction_name, HORIZONTAL_ALIGNMENT_LEFT, 260, 10, label_color)
	ty += line_h

	# Danger + map status
	var danger_str: String = "Danger: "
	for _i in range(region.danger_level):
		danger_str += "*"
	var map_status: String = "Charted" if sms.has_map(_selected_region) else "Uncharted"
	map_canvas.draw_string(default_font, Vector2(tx, ty), danger_str, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color(1.0, 0.4, 0.3, 0.8))
	map_canvas.draw_string(default_font, Vector2(tx + 130, ty), "Map: %s" % map_status, HORIZONTAL_ALIGNMENT_LEFT, 130, 10, value_color)
	ty += line_h

	# Fog reveal percentage
	var fog_pct: float = sms.get_region_fog_percentage(_selected_region)
	var fog_str: String = "Explored: %d%%" % int(fog_pct * 100)
	map_canvas.draw_string(default_font, Vector2(tx, ty), fog_str, HORIZONTAL_ALIGNMENT_LEFT, 130, 10, label_color)
	if _selected_region == GameSession.game_state.current_region:
		map_canvas.draw_string(default_font, Vector2(tx + 130, ty), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_LEFT, 130, 10, Color(0.43, 0.84, 1.0))


# ---------------------------------------------------------------------------
# Region layer — existing circular map view
# ---------------------------------------------------------------------------

func _draw_region_layer() -> void:
	var gs: GameStateData = GameSession.game_state
	var sms: StarMapSystem = GameSession.star_map_system
	if gs == null or sms == null:
		return

	var view_region: String = _selected_region if not _selected_region.is_empty() else _region_id
	var bounds: Vector2 = sms.get_bounds(view_region)

	var canvas_size: Vector2 = map_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return

	# Calculate circular map area
	var map_radius: float = (minf(canvas_size.x, canvas_size.y) - MAP_PADDING * 2) * 0.5
	var map_center := Vector2(canvas_size.x * 0.5, canvas_size.y * 0.5)

	# Scale game-world bounds to fit inside the circle (use 90% of diameter)
	var fit_diameter: float = map_radius * 1.8
	var scale_x: float = fit_diameter / maxf(bounds.x, 1.0)
	var scale_y: float = fit_diameter / maxf(bounds.y, 1.0)
	var map_scale: float = minf(scale_x, scale_y)
	var offset := map_center - (bounds * map_scale * 0.5)

	# --- Circular background ---
	map_canvas.draw_circle(map_center, map_radius, Color(0.02, 0.03, 0.07, 0.45))

	# Vignette
	var ring_count: int = 20
	var vignette_depth: float = map_radius * 0.35
	var ring_w: float = vignette_depth / float(ring_count)
	for i in range(ring_count):
		var r: float = map_radius - float(i) * ring_w
		var t: float = float(i) / float(ring_count)
		var alpha: float = lerpf(0.55, 0.0, t * t)
		map_canvas.draw_arc(map_center, r, 0.0, TAU, 64, Color(0.02, 0.03, 0.07, alpha), ring_w + 1.0)

	# Glowing circular border
	map_canvas.draw_arc(map_center, map_radius + 3.0, 0.0, TAU, 64, Color(0.15, 0.3, 0.6, 0.1), 4.0)
	map_canvas.draw_arc(map_center, map_radius, 0.0, TAU, 64, Color(0.25, 0.45, 0.75, 0.35), 1.5)

	# --- Circular grid ---
	var grid_rings: int = 4
	for i in range(1, grid_rings + 1):
		var gr: float = map_radius * float(i) / float(grid_rings)
		map_canvas.draw_arc(map_center, gr, 0.0, TAU, 64, Color(0.1, 0.2, 0.3, 0.15), 1.0)
	var radial_count: int = 8
	for i in range(radial_count):
		var angle: float = TAU * float(i) / float(radial_count)
		var end_pt: Vector2 = map_center + Vector2(cos(angle), sin(angle)) * map_radius
		map_canvas.draw_line(map_center, end_pt, Color(0.1, 0.2, 0.3, 0.12), 1.0)

	# --- Fog of war ---
	_draw_fog(view_region, sms, map_center, map_radius, map_scale, offset)

	var default_font: Font = ThemeDB.fallback_font

	# --- Story POIs ---
	var story_pois: Array = sms.get_visible_story_pois(view_region, gs)
	for poi in story_pois:
		var px: float = offset.x + poi.get("x", 0.0) * map_scale
		var py: float = offset.y + poi.get("y", 0.0) * map_scale
		var color: Color = TYPE_COLORS.get("story", Color(1.0, 0.82, 0.25))
		var pulse: float = 1.0 + 0.2 * sin(_elapsed * 2.5)
		map_canvas.draw_circle(Vector2(px, py), POI_BLIP_SIZE * pulse, color)
		map_canvas.draw_arc(Vector2(px, py), POI_BLIP_SIZE * 2.0 * pulse, 0.0, TAU, 24, color * Color(1, 1, 1, 0.4), 1.5)
		if default_font:
			map_canvas.draw_string(default_font, Vector2(px + 10, py + 4), poi.get("label", ""), HORIZONTAL_ALIGNMENT_LEFT, 200, 11, color)

	# Hidden POIs
	var hidden_pois: Array = sms.get_visible_hidden_pois(view_region)
	for poi in hidden_pois:
		var px: float = offset.x + poi.get("x", 0.0) * map_scale
		var py: float = offset.y + poi.get("y", 0.0) * map_scale
		var poi_type: String = poi.get("type", "treasure")
		var color: Color = TYPE_COLORS.get(poi_type, Color(0.75, 0.4, 1.0))
		map_canvas.draw_circle(Vector2(px, py), POI_BLIP_SIZE * 0.8, color)
		if default_font:
			map_canvas.draw_string(default_font, Vector2(px + 8, py + 4), poi.get("label", ""), HORIZONTAL_ALIGNMENT_LEFT, 200, 10, color)

	# Active spawns
	var spawn_pois: Array = sms.get_visible_spawns(view_region)
	for poi in spawn_pois:
		var px: float = offset.x + poi.get("x", 0.0) * map_scale
		var py: float = offset.y + poi.get("y", 0.0) * map_scale
		var spawn_type: String = poi.get("type", "combat")
		var color: Color = TYPE_COLORS.get(spawn_type, Color(1.0, 0.3, 0.3))
		map_canvas.draw_circle(Vector2(px, py), POI_BLIP_SIZE * 0.6, color)

	# Encounter POIs from navigation controller
	if view_region == _region_id:
		var nav: Control = _find_navigation_controller()
		if nav != null and "_active_pois" in nav:
			for poi in nav._active_pois:
				var px: float = offset.x + poi.get("x", 0.0) * map_scale
				var py: float = offset.y + poi.get("y", 0.0) * map_scale
				var poi_color: Color = poi.get("color", Color(1.0, 0.82, 0.45))
				map_canvas.draw_circle(Vector2(px, py), POI_BLIP_SIZE * 0.7, poi_color)

	# --- Player position (only in current region) ---
	if view_region == _region_id:
		var player_x: float = offset.x + gs.position_x * map_scale
		var player_y: float = offset.y + gs.position_y * map_scale
		map_canvas.draw_circle(Vector2(player_x, player_y), 5.0, Color(0.43, 0.84, 1.0))
		map_canvas.draw_arc(Vector2(player_x, player_y), 9.0, 0.0, TAU, 24, Color(0.43, 0.84, 1.0, 0.5), 1.5)
		if default_font:
			map_canvas.draw_string(default_font, Vector2(player_x + 10, player_y - 4), "YOU", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.43, 0.84, 1.0))

	# Spawn zones (outline)
	var map_def: Dictionary = sms.region_maps.get(view_region, {})
	for zone in map_def.get("spawn_zones", []):
		var zx: float = offset.x + zone.get("x", 0.0) * map_scale
		var zy: float = offset.y + zone.get("y", 0.0) * map_scale
		var zr: float = zone.get("radius", 500.0) * map_scale
		map_canvas.draw_arc(Vector2(zx, zy), zr, 0.0, TAU, 48, Color(0.2, 0.2, 0.3, 0.15), 1.0)

	# Legend
	_draw_region_legend(map_center, map_radius, view_region)

	# Breadcrumb, subtitle, and control hints
	if default_font:
		var breadcrumb: String = "GALAXY > %s" % _get_region_display_name(view_region).to_upper()
		map_canvas.draw_string(default_font, Vector2(MAP_PADDING, 16), breadcrumb, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x), 11, Color(0.5, 0.6, 0.7, 0.6))

		# Subtitle description
		var is_current: bool = view_region == _region_id
		var subtitle: String = "Sector map showing fog of war, points of interest, and your position." if is_current else "Viewing sector chart. This is not your current region."
		map_canvas.draw_string(default_font, Vector2(MAP_PADDING, 30), subtitle, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 10, Color(0.5, 0.6, 0.7, 0.45))

		# Control hints bar
		var hint_color := Color(0.5, 0.6, 0.7, 0.7)
		var hint_bg := Color(0.02, 0.03, 0.07, 0.5)
		map_canvas.draw_rect(Rect2(0, canvas_size.y - 36, canvas_size.x, 36), hint_bg)
		var hint1: String = "ESC to return to Galaxy view"
		if is_current:
			hint1 += "  |  ENTER for Local Scan (zoomed view around your ship)"
		var hint2: String = "TAB to close the Codex and return to navigation"
		map_canvas.draw_string(default_font, Vector2(MAP_PADDING, canvas_size.y - 22), hint1, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 11, hint_color)
		map_canvas.draw_string(default_font, Vector2(MAP_PADDING, canvas_size.y - 8), hint2, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 11, hint_color * Color(1, 1, 1, 0.7))


func _draw_fog(region_id: String, sms: StarMapSystem, map_center: Vector2, map_radius: float, map_scale: float, offset: Vector2) -> void:
	var map_def: Dictionary = sms.region_maps.get(region_id, {})
	var cell_size: int = map_def.get("fog_grid_size", 64)
	var dims: Vector2i = sms.grid_dimensions.get(region_id, Vector2i.ZERO)
	if dims == Vector2i.ZERO:
		return

	var soft_radius: int = 3
	var revealed_map: PackedByteArray = PackedByteArray()
	revealed_map.resize(dims.x * dims.y)
	revealed_map.fill(0)
	for cy in range(dims.y):
		for cx in range(dims.x):
			if sms.is_cell_revealed(region_id, cx, cy):
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
				map_canvas.draw_rect(Rect2(csx - sw * 0.5, csy - sw * 0.5, sw, sw), Color(noise_r, noise_g, noise_b, fog_alpha))
			else:
				var t: float = float(min_dist) / float(soft_radius)
				var base_alpha: float = lerpf(0.12, 0.55, t * t) * circle_edge_fade
				var r: float = cell_size * map_scale * lerpf(0.45, 0.75, t)
				map_canvas.draw_circle(cell_pos, r * 1.5, Color(noise_r, noise_g, noise_b, base_alpha * 0.3))
				map_canvas.draw_circle(cell_pos, r, Color(noise_r, noise_g, noise_b, base_alpha))


func _draw_region_legend(center: Vector2, radius: float, view_region: String) -> void:
	var default_font: Font = ThemeDB.fallback_font
	if default_font == null:
		return
	var lx: float = center.x + radius + 15.0
	var ly: float = center.y - radius * 0.6
	var line_h: float = 18.0
	var legend_items: Array = [
		["STORY", TYPE_COLORS.get("story", Color.YELLOW)],
		["COMBAT", TYPE_COLORS.get("combat", Color.RED)],
		["RESCUE", TYPE_COLORS.get("rescue", Color.ORANGE)],
		["TRADE", TYPE_COLORS.get("trade", Color.GREEN)],
		["HIDDEN", TYPE_COLORS.get("treasure", Color.PURPLE)],
		["YOU", Color(0.43, 0.84, 1.0)],
	]
	map_canvas.draw_string(default_font, Vector2(lx, ly), "LEGEND", HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color(0.6, 0.75, 0.9))
	ly += line_h
	for item in legend_items:
		map_canvas.draw_circle(Vector2(lx + 6, ly - 3), 4.0, item[1])
		map_canvas.draw_string(default_font, Vector2(lx + 16, ly), item[0], HORIZONTAL_ALIGNMENT_LEFT, 100, 11, item[1])
		ly += line_h

	ly += 10
	var sms: StarMapSystem = GameSession.star_map_system
	if sms != null:
		var has_map: bool = sms.has_map(view_region)
		var carto: bool = sms.cartographer_rescued
		var info_color := Color(0.5, 0.7, 0.85)
		map_canvas.draw_string(default_font, Vector2(lx, ly), "MAP: %s" % ("OWNED" if has_map else "UNCHARTED"), HORIZONTAL_ALIGNMENT_LEFT, 120, 11, info_color)
		ly += line_h
		map_canvas.draw_string(default_font, Vector2(lx, ly), "CARTO: %s" % ("YES" if carto else "NO"), HORIZONTAL_ALIGNMENT_LEFT, 120, 11, info_color)


# ---------------------------------------------------------------------------
# Local layer — zoomed-in player-centered view
# ---------------------------------------------------------------------------

func _draw_local_layer() -> void:
	var gs: GameStateData = GameSession.game_state
	var sms: StarMapSystem = GameSession.star_map_system
	if gs == null or sms == null:
		return

	var canvas_size: Vector2 = map_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return

	var default_font: Font = ThemeDB.fallback_font
	var player_world := Vector2(gs.position_x, gs.position_y)
	var bounds: Vector2 = sms.get_bounds(_region_id)

	# Map a world rect centered on the player to fill the canvas
	var half_range: float = LOCAL_WORLD_RANGE * 0.5
	var aspect: float = canvas_size.x / canvas_size.y
	var world_half_w: float = half_range * aspect
	var world_half_h: float = half_range

	# Background
	map_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.02, 0.03, 0.07, 0.55))

	# Subtle grid
	var grid_spacing_world: float = 200.0
	var local_scale: float = canvas_size.y / (LOCAL_WORLD_RANGE)
	var grid_color := Color(0.1, 0.15, 0.25, 0.15)
	var world_left: float = player_world.x - world_half_w
	var world_top: float = player_world.y - world_half_h
	var grid_start_x: float = floorf(world_left / grid_spacing_world) * grid_spacing_world
	var grid_start_y: float = floorf(world_top / grid_spacing_world) * grid_spacing_world
	var gx: float = grid_start_x
	while gx < player_world.x + world_half_w:
		var sx: float = (gx - world_left) * local_scale
		map_canvas.draw_line(Vector2(sx, 0), Vector2(sx, canvas_size.y), grid_color, 1.0)
		gx += grid_spacing_world
	var gy: float = grid_start_y
	while gy < player_world.y + world_half_h:
		var sy: float = (gy - world_top) * local_scale
		map_canvas.draw_line(Vector2(0, sy), Vector2(canvas_size.x, sy), grid_color, 1.0)
		gy += grid_spacing_world

	# Fog of war at local scale
	var map_def: Dictionary = sms.region_maps.get(_region_id, {})
	var cell_size: int = map_def.get("fog_grid_size", 64)
	var dims: Vector2i = sms.grid_dimensions.get(_region_id, Vector2i.ZERO)
	if dims != Vector2i.ZERO:
		var cell_screen_w: float = cell_size * local_scale
		# Only iterate cells that are within view
		var cx_min: int = maxi(0, int((player_world.x - world_half_w) / cell_size) - 1)
		var cx_max: int = mini(dims.x - 1, int((player_world.x + world_half_w) / cell_size) + 1)
		var cy_min: int = maxi(0, int((player_world.y - world_half_h) / cell_size) - 1)
		var cy_max: int = mini(dims.y - 1, int((player_world.y + world_half_h) / cell_size) + 1)

		for cy in range(cy_min, cy_max + 1):
			for cx in range(cx_min, cx_max + 1):
				if sms.is_cell_revealed(_region_id, cx, cy):
					continue
				var cwx: float = cx * cell_size + cell_size * 0.5
				var cwy: float = cy * cell_size + cell_size * 0.5
				var sx: float = (cwx - world_left) * local_scale
				var sy: float = (cwy - world_top) * local_scale
				# Check if any neighboring cell is revealed for soft edge
				var has_revealed_neighbor: bool = false
				for ndy in [-1, 0, 1]:
					for ndx in [-1, 0, 1]:
						if ndx == 0 and ndy == 0:
							continue
						if sms.is_cell_revealed(_region_id, cx + ndx, cy + ndy):
							has_revealed_neighbor = true
							break
					if has_revealed_neighbor:
						break

				var noise_r: float = 0.04 + 0.03 * sin(float(cx) * 0.7 + float(cy) * 1.3)
				var noise_g: float = 0.06 + 0.04 * sin(float(cx) * 1.1 + float(cy) * 0.9 + 2.0)
				var noise_b: float = 0.12 + 0.05 * sin(float(cx) * 0.5 + float(cy) * 1.7 + 4.0)

				if has_revealed_neighbor:
					map_canvas.draw_circle(Vector2(sx, sy), cell_screen_w * 0.7, Color(noise_r, noise_g, noise_b, 0.35))
				else:
					map_canvas.draw_rect(Rect2(sx - cell_screen_w * 0.5, sy - cell_screen_w * 0.5, cell_screen_w, cell_screen_w), Color(noise_r, noise_g, noise_b, 0.6))

	# Region boundary indicator
	var boundary_color := Color(0.25, 0.45, 0.75, 0.3)
	# Left boundary
	if world_left < 0:
		var bx: float = (0.0 - world_left) * local_scale
		map_canvas.draw_line(Vector2(bx, 0), Vector2(bx, canvas_size.y), boundary_color, 2.0)
	# Right boundary
	if player_world.x + world_half_w > bounds.x:
		var bx: float = (bounds.x - world_left) * local_scale
		map_canvas.draw_line(Vector2(bx, 0), Vector2(bx, canvas_size.y), boundary_color, 2.0)
	# Top boundary
	if world_top < 0:
		var by: float = (0.0 - world_top) * local_scale
		map_canvas.draw_line(Vector2(0, by), Vector2(canvas_size.x, by), boundary_color, 2.0)
	# Bottom boundary
	if player_world.y + world_half_h > bounds.y:
		var by: float = (bounds.y - world_top) * local_scale
		map_canvas.draw_line(Vector2(0, by), Vector2(canvas_size.x, by), boundary_color, 2.0)

	# POIs in local view
	var all_pois: Array = []

	# Story POIs
	for poi in sms.get_visible_story_pois(_region_id, gs):
		var p: Dictionary = poi.duplicate()
		p["_color"] = TYPE_COLORS.get("story", Color.YELLOW)
		p["_size"] = POI_BLIP_SIZE * 1.5
		p["_pulse"] = true
		all_pois.append(p)

	# Hidden POIs
	for poi in sms.get_visible_hidden_pois(_region_id):
		var p: Dictionary = poi.duplicate()
		p["_color"] = TYPE_COLORS.get(poi.get("type", "treasure"), Color(0.75, 0.4, 1.0))
		p["_size"] = POI_BLIP_SIZE * 1.2
		p["_pulse"] = false
		all_pois.append(p)

	# Spawn POIs
	for poi in sms.get_visible_spawns(_region_id):
		var p: Dictionary = poi.duplicate()
		p["_color"] = TYPE_COLORS.get(poi.get("type", "combat"), Color(1.0, 0.3, 0.3))
		p["_size"] = POI_BLIP_SIZE
		p["_pulse"] = false
		all_pois.append(p)

	# Navigation POIs
	var nav: Control = _find_navigation_controller()
	if nav != null and "_active_pois" in nav:
		for poi in nav._active_pois:
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
			sz *= 1.0 + 0.2 * sin(_elapsed * 2.5)
		map_canvas.draw_circle(Vector2(sx, sy), sz, color)
		# Labels in local view
		var label: String = poi.get("label", "")
		if not label.is_empty() and default_font:
			map_canvas.draw_string(default_font, Vector2(sx + sz + 4, sy + 4), label, HORIZONTAL_ALIGNMENT_LEFT, 200, 11, color)

	# Player ship — center of screen
	var player_sx: float = canvas_size.x * 0.5
	var player_sy: float = canvas_size.y * 0.5
	map_canvas.draw_circle(Vector2(player_sx, player_sy), 6.0, Color(0.43, 0.84, 1.0))
	map_canvas.draw_arc(Vector2(player_sx, player_sy), 12.0, 0.0, TAU, 24, Color(0.43, 0.84, 1.0, 0.4), 1.5)
	# Vision range circle
	var vision_screen_r: float = 200.0 * local_scale
	map_canvas.draw_arc(Vector2(player_sx, player_sy), vision_screen_r, 0.0, TAU, 48, Color(0.43, 0.84, 1.0, 0.12), 1.0)

	# Breadcrumb, subtitle, and hints
	if default_font:
		var breadcrumb: String = "GALAXY > %s > LOCAL" % _get_region_display_name(_region_id).to_upper()
		map_canvas.draw_string(default_font, Vector2(MAP_PADDING, 16), breadcrumb, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - 140), 11, Color(0.5, 0.6, 0.7, 0.6))

		# Subtitle
		var subtitle: String = "Zoomed scan centered on your ship. Nearby contacts and fog detail visible."
		map_canvas.draw_string(default_font, Vector2(MAP_PADDING, 30), subtitle, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 10, Color(0.5, 0.6, 0.7, 0.45))

		# Coordinate readout
		var coord_str: String = "Position: (%d, %d)" % [int(gs.position_x), int(gs.position_y)]
		map_canvas.draw_string(default_font, Vector2(canvas_size.x - 160, 16), coord_str, HORIZONTAL_ALIGNMENT_LEFT, 160, 11, Color(0.43, 0.84, 1.0, 0.5))

		# Control hints bar
		var hint_color := Color(0.5, 0.6, 0.7, 0.7)
		var hint_bg := Color(0.02, 0.03, 0.07, 0.5)
		map_canvas.draw_rect(Rect2(0, canvas_size.y - 36, canvas_size.x, 36), hint_bg)
		map_canvas.draw_string(default_font, Vector2(MAP_PADDING, canvas_size.y - 22), "ESC to return to Region view  |  TAB to close the Codex", HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 11, hint_color)
		map_canvas.draw_string(default_font, Vector2(MAP_PADDING, canvas_size.y - 8), "The inner circle shows your ship's sensor range", HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - MAP_PADDING * 2), 11, hint_color * Color(1, 1, 1, 0.7))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _find_navigation_controller() -> Control:
	var scene_container: Node = get_tree().current_scene.get_node_or_null("SceneContainer")
	if scene_container == null:
		return null
	for child in scene_container.get_children():
		if child is Control and child.has_method("_refresh_pois"):
			return child
	return null


func _get_region_display_name(region_id: String) -> String:
	var exploration: ExplorationSystem = GameSession.exploration
	if exploration != null:
		var region: ExplorationSystem.Region = exploration.regions.get(region_id)
		if region != null:
			return region.region_name
	return region_id.replace("_", " ").capitalize()


# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	match _layer:
		Layer.GALAXY:
			_handle_galaxy_input(event)
		Layer.REGION:
			_handle_region_input(event)
		Layer.LOCAL:
			_handle_local_input(event)


func _handle_galaxy_input(event: InputEvent) -> void:
	# Travel confirmation dialog intercepts input
	if _travel_confirm_visible:
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_confirm_travel()
		elif event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			_cancel_travel()
		return

	if event.is_action_pressed("star_map"):
		get_viewport().set_input_as_handled()
		_on_close()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_close()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_drill_to_region()
	elif event.is_action_pressed("fire"):
		# Space bar — request travel to selected region
		get_viewport().set_input_as_handled()
		_request_travel()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_move_galaxy_selection(Vector2.LEFT)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_move_galaxy_selection(Vector2.RIGHT)
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_move_galaxy_selection(Vector2.UP)
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_move_galaxy_selection(Vector2.DOWN)


func _handle_region_input(event: InputEvent) -> void:
	if event.is_action_pressed("star_map"):
		get_viewport().set_input_as_handled()
		_on_close()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_zoom_to_galaxy()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		# Only allow local scan of the current region
		if _selected_region == _region_id:
			_zoom_to_local()


func _handle_local_input(event: InputEvent) -> void:
	if event.is_action_pressed("star_map"):
		get_viewport().set_input_as_handled()
		_on_close()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_zoom_to_region()


# ---------------------------------------------------------------------------
# Layer transitions
# ---------------------------------------------------------------------------

func _drill_to_region() -> void:
	if _selected_region.is_empty():
		return
	# Only allow drilling into discovered regions
	var exploration: ExplorationSystem = GameSession.exploration
	if exploration != null:
		var region: ExplorationSystem.Region = exploration.regions.get(_selected_region)
		if region != null and not region.is_discovered:
			return
	_layer = Layer.REGION
	_update_title()
	EventBus.codex_layer_changed.emit("region")


func _zoom_to_galaxy() -> void:
	_layer = Layer.GALAXY
	_update_title()
	EventBus.codex_layer_changed.emit("galaxy")


func _zoom_to_local() -> void:
	_layer = Layer.LOCAL
	_update_title()
	EventBus.codex_layer_changed.emit("local")


func _zoom_to_region() -> void:
	_layer = Layer.REGION
	_selected_region = _region_id
	_update_title()
	EventBus.codex_layer_changed.emit("region")


# ---------------------------------------------------------------------------
# Galaxy navigation
# ---------------------------------------------------------------------------

func _move_galaxy_selection(direction: Vector2) -> void:
	var sms: StarMapSystem = GameSession.star_map_system
	var exploration: ExplorationSystem = GameSession.exploration
	if sms == null or exploration == null:
		return

	var nodes: Dictionary = sms.galaxy_layout.get("nodes", {})
	if nodes.is_empty():
		return

	var current_pos: Vector2 = sms.get_galaxy_node_pos(_selected_region)

	# Find the best candidate in the pressed direction among ALL nodes (not just connected)
	var best_id: String = ""
	var best_score: float = -1.0
	for region_id in nodes:
		if region_id == _selected_region:
			continue
		var candidate_pos: Vector2 = sms.get_galaxy_node_pos(region_id)
		var delta: Vector2 = candidate_pos - current_pos
		if delta.length() < 0.01:
			continue
		# Dot product with desired direction — higher is more aligned
		var dot: float = delta.normalized().dot(direction)
		if dot <= 0.1:
			continue  # Must be broadly in the right direction
		# Score: favor alignment, penalize distance
		var score: float = dot / delta.length()
		if score > best_score:
			best_score = score
			best_id = region_id

	if not best_id.is_empty():
		_selected_region = best_id


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()


# ---------------------------------------------------------------------------
# Travel to world scene
# ---------------------------------------------------------------------------

var _travel_confirm_visible: bool = false
var _travel_target_region: String = ""

const WORLD_SCENE_MAP := {
	"starting_realm": "res://scenes/world/world.tscn",
	"tavern": "res://scenes/world/tavern.tscn",
}


func _request_travel() -> void:
	if _selected_region.is_empty():
		return
	if _selected_region == _region_id:
		# Already here — offer to enter world view
		_travel_target_region = _selected_region
		_travel_confirm_visible = true
		return
	# Check if travel is possible
	var exploration: ExplorationSystem = GameSession.exploration
	if exploration == null:
		return
	var region: ExplorationSystem.Region = exploration.regions.get(_selected_region)
	if region == null or not region.is_discovered:
		return
	_travel_target_region = _selected_region
	_travel_confirm_visible = true


func _confirm_travel() -> void:
	_travel_confirm_visible = false
	if _travel_target_region.is_empty():
		return

	# Try to travel if it's a different region
	if _travel_target_region != _region_id:
		var success: bool = GameSession.travel_to_region(_travel_target_region)
		if not success:
			return
		_region_id = _travel_target_region

	# Load the world scene for this region
	var scene_path: String = WORLD_SCENE_MAP.get(_travel_target_region, "res://scenes/world/world.tscn")
	GameSession.set_meta("world_entry_region", _travel_target_region)
	_on_close()
	# Deferred scene change to avoid issues during overlay pop
	get_tree().call_deferred("change_scene_to_file", scene_path)


func _cancel_travel() -> void:
	_travel_confirm_visible = false
	_travel_target_region = ""


func _draw_travel_confirm(canvas_size: Vector2) -> void:
	if not _travel_confirm_visible:
		return
	var default_font: Font = ThemeDB.fallback_font
	if default_font == null:
		return

	# Dim overlay
	map_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0, 0, 0, 0.5))

	# Confirm box
	var box_w: float = 320.0
	var box_h: float = 100.0
	var box_x: float = (canvas_size.x - box_w) * 0.5
	var box_y: float = (canvas_size.y - box_h) * 0.5
	map_canvas.draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0.05, 0.07, 0.12, 0.95))
	map_canvas.draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0.3, 0.5, 0.7, 0.6), false, 2.0)

	var region_name: String = _get_region_display_name(_travel_target_region)
	var is_current: bool = _travel_target_region == _region_id
	var prompt: String
	if is_current:
		prompt = "Enter %s world view?" % region_name
	else:
		prompt = "Travel to %s?" % region_name

	var pw: float = default_font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	map_canvas.draw_string(default_font, Vector2(canvas_size.x * 0.5 - pw * 0.5, box_y + 30), prompt, HORIZONTAL_ALIGNMENT_LEFT, int(box_w), 13, Color(0.8, 0.85, 0.95))

	var hint: String = "ENTER to confirm  |  ESC to cancel"
	var hw: float = default_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	map_canvas.draw_string(default_font, Vector2(canvas_size.x * 0.5 - hw * 0.5, box_y + 65), hint, HORIZONTAL_ALIGNMENT_LEFT, int(box_w), 11, Color(0.5, 0.6, 0.7, 0.8))
