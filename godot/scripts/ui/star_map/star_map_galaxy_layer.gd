## StarMapGalaxyLayer — renders the top-level galaxy layer of the Celestial
## Codex. Extracted from the former `star_map_screen.gd` monolith (Sprint 5a).
## All GameSession access happens through the injected StarMapViewModel.
class_name StarMapGalaxyLayer
extends RefCounted

const MAP_PADDING: float = 20.0
const GALAXY_NODE_RADIUS: float = 28.0
const LEGEND_WIDTH: float = 140.0

const TYPE_COLORS := {
	"story": Color(1.0, 0.82, 0.25),
	"combat": Color(1.0, 0.2, 0.2),
	"rescue": Color(1.0, 0.62, 0.35),
	"trade": Color(0.52, 1.0, 0.35),
	"exploration": Color(0.5, 1.0, 0.62),
	"treasure": Color(0.75, 0.4, 1.0),
}

var _vm: StarMapViewModel


func _init(vm: StarMapViewModel) -> void:
	_vm = vm


## Draw the galaxy layer onto `canvas`. `ctx` carries the mutable per-frame
## state owned by the orchestrator:
##   elapsed: float — seconds, used for pulsing selection rings
##   selected_region: String
##   backdrop: ImageTexture (may be null; orchestrator caches + updates)
##   travel_confirm_visible: bool
##   travel_target_region: String
func draw(canvas: Control, ctx: Dictionary) -> void:
	if not _vm.has_state() or not _vm.has_star_map() or not _vm.has_exploration():
		return

	var canvas_size: Vector2 = canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return

	var default_font: Font = ThemeDB.fallback_font
	var elapsed: float = ctx.get("elapsed", 0.0)
	var selected_region: String = ctx.get("selected_region", "")
	var backdrop: ImageTexture = ctx.get("backdrop")

	# Procedural backdrop
	if backdrop != null:
		canvas.draw_texture_rect(
			backdrop,
			Rect2(Vector2.ZERO, canvas_size),
			false,
			Color(0.6, 0.5, 0.8, 0.3),
		)
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.02, 0.03, 0.07, 0.4))

	# Vignette
	var center: Vector2 = canvas_size * 0.5
	var vr: float = minf(canvas_size.x, canvas_size.y) * 0.48
	for i in range(15):
		var r: float = vr + float(i) * 8.0
		var t: float = float(i) / 15.0
		canvas.draw_arc(center, r, 0.0, TAU, 64, Color(0.02, 0.03, 0.07, t * 0.5), 8.0)

	# Usable area with padding for legend on the right
	var pad: float = 60.0
	var area_origin := Vector2(pad, pad)
	var area_size: Vector2 = canvas_size - Vector2(pad * 2, pad * 2) - Vector2(LEGEND_WIDTH, 0)

	var nodes: Dictionary = _vm.galaxy_nodes()

	_draw_connection_lines(canvas, nodes, area_origin, area_size)
	_draw_nodes(canvas, nodes, area_origin, area_size, default_font, elapsed, selected_region)
	_draw_danger_pips(canvas, nodes, area_origin, area_size, default_font)
	_draw_subtitle(canvas, canvas_size, default_font)

	if not selected_region.is_empty() and default_font != null:
		_draw_info_box(canvas, canvas_size, pad, selected_region, default_font)

	_draw_hints(canvas, canvas_size, pad, default_font)
	_draw_legend(canvas, area_origin, area_size, default_font)

	if ctx.get("travel_confirm_visible", false):
		_draw_travel_confirm(canvas, canvas_size, ctx, default_font)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _draw_connection_lines(
	canvas: Control, nodes: Dictionary, area_origin: Vector2, area_size: Vector2
) -> void:
	for region_id in nodes:
		var region: ExplorationSystem.Region = _vm.region_info(region_id)
		if region == null:
			continue
		var pos_a: Vector2 = _node_screen_pos(region_id, area_origin, area_size, nodes)
		for connected_id in region.connected_regions:
			if connected_id < region_id:
				continue  # avoid drawing each connection twice
			var pos_b: Vector2 = _node_screen_pos(connected_id, area_origin, area_size, nodes)
			var connected_region: ExplorationSystem.Region = _vm.region_info(connected_id)
			var both_discovered: bool = region.is_discovered
			if connected_region != null:
				both_discovered = both_discovered and connected_region.is_discovered
			if both_discovered:
				canvas.draw_line(pos_a, pos_b, Color(0.3, 0.5, 0.7, 0.4), 2.0)
			else:
				_draw_dashed_line(canvas, pos_a, pos_b, Color(0.15, 0.25, 0.35, 0.3), 1.5, 8.0, 6.0)


func _draw_nodes(
	canvas: Control,
	nodes: Dictionary,
	area_origin: Vector2,
	area_size: Vector2,
	default_font: Font,
	elapsed: float,
	selected_region: String,
) -> void:
	var current_region: String = _vm.current_region()
	for region_id in nodes:
		var region: ExplorationSystem.Region = _vm.region_info(region_id)
		var node_pos: Vector2 = _node_screen_pos(region_id, area_origin, area_size, nodes)
		var node_color: Color = _vm.galaxy_node_color(region_id)
		var is_current: bool = region_id == current_region
		var is_selected: bool = region_id == selected_region
		var discovered: bool = region != null and region.is_discovered
		var has_map: bool = _vm.has_map(region_id)

		if discovered:
			var fog_pct: float = _vm.region_fog_percentage(region_id)
			if fog_pct > 0.0:
				var arc_angle: float = TAU * fog_pct
				canvas.draw_arc(
					node_pos,
					GALAXY_NODE_RADIUS + 5.0,
					-PI * 0.5,
					-PI * 0.5 + arc_angle,
					48,
					node_color * Color(1, 1, 1, 0.35),
					3.0,
				)
			if has_map:
				canvas.draw_circle(node_pos, GALAXY_NODE_RADIUS, node_color * Color(1, 1, 1, 0.3))
				canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS, 0.0, TAU, 48, node_color, 2.0)
			else:
				canvas.draw_circle(node_pos, GALAXY_NODE_RADIUS, node_color * Color(1, 1, 1, 0.1))
				canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS, 0.0, TAU, 48, node_color * Color(1, 1, 1, 0.5), 1.5)

			if default_font != null:
				var label_offset_y: int = nodes.get(region_id, {}).get("label_offset_y", -1)
				var label_y: float = node_pos.y + (GALAXY_NODE_RADIUS + 14.0) * label_offset_y
				var region_name: String = region.region_name if region != null else region_id.replace("_", " ").capitalize()
				var text_w: float = default_font.get_string_size(region_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				canvas.draw_string(default_font, Vector2(node_pos.x - text_w * 0.5, label_y), region_name, HORIZONTAL_ALIGNMENT_LEFT, 200, 11, node_color)
				if not has_map:
					var uc_w: float = default_font.get_string_size("UNCHARTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
					var sub_y: float = label_y + 12.0 * label_offset_y
					canvas.draw_string(default_font, Vector2(node_pos.x - uc_w * 0.5, sub_y), "UNCHARTED", HORIZONTAL_ALIGNMENT_LEFT, 200, 9, node_color * Color(1, 1, 1, 0.5))
		else:
			canvas.draw_circle(node_pos, GALAXY_NODE_RADIUS, Color(0.08, 0.1, 0.15, 0.5))
			canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS, 0.0, TAU, 48, Color(0.2, 0.25, 0.3, 0.4), 1.5)
			if default_font != null:
				var q_w: float = default_font.get_string_size("???", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				canvas.draw_string(default_font, Vector2(node_pos.x - q_w * 0.5, node_pos.y + 4), "???", HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color(0.3, 0.35, 0.4, 0.6))

		if is_current:
			var pulse: float = 1.0 + 0.15 * sin(elapsed * 3.0)
			canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS * pulse + 3.0, 0.0, TAU, 48, Color(0.43, 0.84, 1.0, 0.6), 2.0)

		if is_selected:
			var sel_pulse: float = 1.0 + 0.08 * sin(elapsed * 5.0)
			canvas.draw_arc(node_pos, GALAXY_NODE_RADIUS * sel_pulse + 8.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.7), 2.0)


func _draw_danger_pips(
	canvas: Control,
	nodes: Dictionary,
	area_origin: Vector2,
	area_size: Vector2,
	default_font: Font,
) -> void:
	if default_font == null:
		return
	for region_id in nodes:
		var region: ExplorationSystem.Region = _vm.region_info(region_id)
		if region == null or not region.is_discovered:
			continue
		var node_pos: Vector2 = _node_screen_pos(region_id, area_origin, area_size, nodes)
		var danger_str: String = ""
		for _i in range(region.danger_level):
			danger_str += "*"
		var dw: float = default_font.get_string_size(danger_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		canvas.draw_string(default_font, Vector2(node_pos.x - dw * 0.5, node_pos.y + 4), danger_str, HORIZONTAL_ALIGNMENT_LEFT, 100, 10, Color(1.0, 0.4, 0.3, 0.7))


func _draw_subtitle(canvas: Control, canvas_size: Vector2, default_font: Font) -> void:
	if default_font == null:
		return
	var subtitle: String = "Navigate the known galaxy. Select a region to view its sector map."
	var sub_w: float = default_font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	canvas.draw_string(default_font, Vector2(canvas_size.x * 0.5 - sub_w * 0.5, 18), subtitle, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x), 10, Color(0.5, 0.6, 0.7, 0.5))


func _draw_info_box(
	canvas: Control,
	canvas_size: Vector2,
	pad: float,
	selected_region: String,
	default_font: Font,
) -> void:
	var region: ExplorationSystem.Region = _vm.region_info(selected_region)
	if region == null:
		return

	var box_x: float = pad
	var box_y: float = canvas_size.y - 120
	var box_w: float = 280.0
	var box_h: float = 78.0
	canvas.draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0.03, 0.05, 0.1, 0.7))
	canvas.draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0.2, 0.35, 0.5, 0.4), false, 1.0)

	var tx: float = box_x + 10
	var ty: float = box_y + 16
	var line_h: float = 16.0
	var label_color := Color(0.6, 0.75, 0.9)
	var value_color := Color(0.8, 0.85, 0.9)

	if not region.is_discovered:
		canvas.draw_string(default_font, Vector2(tx, ty), "UNKNOWN REGION", HORIZONTAL_ALIGNMENT_LEFT, 260, 12, Color(0.4, 0.45, 0.5))
		ty += line_h
		canvas.draw_string(default_font, Vector2(tx, ty), "Explore to reveal this sector", HORIZONTAL_ALIGNMENT_LEFT, 260, 10, Color(0.35, 0.4, 0.45))
		return

	canvas.draw_string(default_font, Vector2(tx, ty), region.region_name, HORIZONTAL_ALIGNMENT_LEFT, 260, 12, _vm.galaxy_node_color(selected_region))
	ty += line_h

	var faction_name: String = region.controlling_faction.replace("_", " ").capitalize()
	canvas.draw_string(default_font, Vector2(tx, ty), "Faction: %s" % faction_name, HORIZONTAL_ALIGNMENT_LEFT, 260, 10, label_color)
	ty += line_h

	var danger_str: String = "Danger: "
	for _i in range(region.danger_level):
		danger_str += "*"
	var map_status: String = "Charted" if _vm.has_map(selected_region) else "Uncharted"
	canvas.draw_string(default_font, Vector2(tx, ty), danger_str, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color(1.0, 0.4, 0.3, 0.8))
	canvas.draw_string(default_font, Vector2(tx + 130, ty), "Map: %s" % map_status, HORIZONTAL_ALIGNMENT_LEFT, 130, 10, value_color)
	ty += line_h

	var fog_pct: float = _vm.region_fog_percentage(selected_region)
	var fog_str: String = "Explored: %d%%" % int(fog_pct * 100)
	canvas.draw_string(default_font, Vector2(tx, ty), fog_str, HORIZONTAL_ALIGNMENT_LEFT, 130, 10, label_color)
	if selected_region == _vm.current_region():
		canvas.draw_string(default_font, Vector2(tx + 130, ty), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_LEFT, 130, 10, Color(0.43, 0.84, 1.0))


func _draw_hints(canvas: Control, canvas_size: Vector2, pad: float, default_font: Font) -> void:
	if default_font == null:
		return
	var hint_color := Color(0.5, 0.6, 0.7, 0.7)
	var hint_bg_color := Color(0.02, 0.03, 0.07, 0.5)
	canvas.draw_rect(Rect2(0, canvas_size.y - 36, canvas_size.x, 36), hint_bg_color)
	var hint1: String = "ARROWS select region, ENTER view sector, SPACE travel to region"
	var hint2: String = "TAB to close the Codex"
	canvas.draw_string(default_font, Vector2(pad, canvas_size.y - 22), hint1, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - pad * 2), 11, hint_color)
	canvas.draw_string(default_font, Vector2(pad, canvas_size.y - 8), hint2, HORIZONTAL_ALIGNMENT_LEFT, int(canvas_size.x - pad * 2), 11, hint_color * Color(1, 1, 1, 0.7))


func _draw_legend(
	canvas: Control, area_origin: Vector2, area_size: Vector2, default_font: Font
) -> void:
	if default_font == null:
		return
	var lx: float = area_origin.x + area_size.x + 20.0
	var ly: float = area_origin.y + 20.0
	var line_h: float = 22.0

	canvas.draw_string(default_font, Vector2(lx, ly), "LEGEND", HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color(0.6, 0.75, 0.9))
	ly += line_h + 4

	# Current
	canvas.draw_arc(Vector2(lx + 6, ly - 3), 5.0, 0.0, TAU, 16, Color(0.43, 0.84, 1.0, 0.6), 2.0)
	canvas.draw_string(default_font, Vector2(lx + 16, ly), "CURRENT", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.43, 0.84, 1.0))
	ly += line_h

	# Charted
	canvas.draw_circle(Vector2(lx + 6, ly - 3), 5.0, Color(0.6, 0.7, 0.3, 0.3))
	canvas.draw_arc(Vector2(lx + 6, ly - 3), 5.0, 0.0, TAU, 16, Color(0.6, 0.7, 0.3), 1.5)
	canvas.draw_string(default_font, Vector2(lx + 16, ly), "CHARTED", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.6, 0.7, 0.3))
	ly += line_h

	# Uncharted
	canvas.draw_arc(Vector2(lx + 6, ly - 3), 5.0, 0.0, TAU, 16, Color(0.5, 0.5, 0.5, 0.5), 1.5)
	canvas.draw_string(default_font, Vector2(lx + 16, ly), "UNCHARTED", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.5, 0.5, 0.5))
	ly += line_h

	# Unknown
	canvas.draw_circle(Vector2(lx + 6, ly - 3), 5.0, Color(0.08, 0.1, 0.15, 0.5))
	canvas.draw_string(default_font, Vector2(lx + 16, ly), "UNKNOWN", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.3, 0.35, 0.4, 0.6))
	ly += line_h + 8

	var info_color := Color(0.5, 0.7, 0.85)
	var carto: bool = _vm.cartographer_rescued()
	canvas.draw_string(default_font, Vector2(lx, ly), "CARTO: %s" % ("YES" if carto else "NO"), HORIZONTAL_ALIGNMENT_LEFT, 120, 11, info_color)
	ly += line_h
	canvas.draw_arc(Vector2(lx + 6, ly - 3), 5.0, -PI * 0.5, PI * 0.5, 16, info_color * Color(1, 1, 1, 0.5), 2.0)
	canvas.draw_string(default_font, Vector2(lx + 16, ly), "FOG REVEAL", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, info_color)


func _draw_travel_confirm(
	canvas: Control, canvas_size: Vector2, ctx: Dictionary, default_font: Font
) -> void:
	if default_font == null:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0, 0, 0, 0.5))

	var box_w: float = 320.0
	var box_h: float = 100.0
	var box_x: float = (canvas_size.x - box_w) * 0.5
	var box_y: float = (canvas_size.y - box_h) * 0.5
	canvas.draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0.05, 0.07, 0.12, 0.95))
	canvas.draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0.3, 0.5, 0.7, 0.6), false, 2.0)

	var target_region: String = ctx.get("travel_target_region", "")
	var current_region: String = _vm.current_region()
	var region_name: String = _vm.region_display_name(target_region)
	var is_current: bool = target_region == current_region
	var prompt: String = ("Enter %s world view?" % region_name) if is_current else ("Travel to %s?" % region_name)

	var pw: float = default_font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	canvas.draw_string(default_font, Vector2(canvas_size.x * 0.5 - pw * 0.5, box_y + 30), prompt, HORIZONTAL_ALIGNMENT_LEFT, int(box_w), 13, Color(0.8, 0.85, 0.95))

	var hint: String = "ENTER to confirm  |  ESC to cancel"
	var hw: float = default_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	canvas.draw_string(default_font, Vector2(canvas_size.x * 0.5 - hw * 0.5, box_y + 65), hint, HORIZONTAL_ALIGNMENT_LEFT, int(box_w), 11, Color(0.5, 0.6, 0.7, 0.8))


func _node_screen_pos(
	region_id: String, area_origin: Vector2, area_size: Vector2, nodes: Dictionary
) -> Vector2:
	var node: Dictionary = nodes.get(region_id, {})
	var gx: float = node.get("gx", 0.5)
	var gy: float = node.get("gy", 0.5)
	return area_origin + Vector2(gx * area_size.x, gy * area_size.y)


static func _draw_dashed_line(
	canvas: Control,
	p_from: Vector2,
	p_to: Vector2,
	p_color: Color,
	p_width: float,
	dash_len: float,
	gap_len: float,
) -> void:
	var dir: Vector2 = p_to - p_from
	var total_len: float = dir.length()
	if total_len < 1.0:
		return
	dir = dir / total_len
	var pos: float = 0.0
	while pos < total_len:
		var seg_end: float = minf(pos + dash_len, total_len)
		canvas.draw_line(p_from + dir * pos, p_from + dir * seg_end, p_color, p_width)
		pos = seg_end + gap_len
