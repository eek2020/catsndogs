## CombatLayout — pure geometry helper for combat_ui.gd.
##
## Given a viewport size and the design resolution, computes every ship,
## label, and bar position the combat screen needs. No node references and
## no side effects, so the math is unit-testable without the scene tree.
##
## Returns an empty Dictionary for zero-sized inputs so the caller can bail
## early before touching node properties.
class_name CombatLayout
extends RefCounted

# Porthole glass centres (design coords)
const PORTHOLE_LEFT := Vector2(253, 176)
const PORTHOLE_RIGHT := Vector2(773, 176)

# Hull text: render from top edge of brass strip label row
const HULL_TEXT_Y := 268.0

# Health-bar slot centres (inside the brass strip below portholes)
const HEALTHBAR_LEFT := Vector2(253, 252)
const HEALTHBAR_RIGHT := Vector2(773, 252)
const BAR_W := 180.0
const BAR_H := 20.0

# Ship name title: label bottom aligned to this design Y
const TITLE_MIDBOTTOM_Y := 105.0

# Parchment combat-log region
const LOG_TOP := 298.0
const LOG_BOT := 343.0
const LOG_MARGIN_X := 75.0

# Action / compass area
const ACTION_Y := 460.0

# Ship display size (design resolution pixels)
const SHIP_SIZE := Vector2(120, 96)
const NAME_FONT_BASE := 20
const HULL_FONT_BASE := 13


## Compute the full layout frame. Keys:
## - bg_scale: float                               (KEEP_ASPECT_COVERED scale)
## - bg_offset: Vector2                            (top-left offset of covered bg)
## - player_pos / enemy_pos: Vector2               (porthole centres in screen space)
## - ship_screen_size: Vector2
## - player_ship_pos / enemy_ship_pos: Vector2     (top-left for ship TextureRects)
## - player_name_pos / enemy_name_pos: Vector2     (top-left)
## - name_label_size: Vector2
## - name_font_size: int
## - player_bar_rect / enemy_bar_rect: Rect2
## - player_hull_pos / enemy_hull_pos: Vector2
## - hull_label_size: Vector2
## - hull_font_size: int
## - log_pos / log_size: Vector2
## - actions_pos / actions_size: Vector2
## - result_pos / result_size: Vector2
## - continue_pos / continue_size: Vector2
static func compute(viewport_size: Vector2, design_w: float, design_h: float) -> Dictionary:
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return {}
	if design_w <= 0 or design_h <= 0:
		return {}

	var bg_scale: float = maxf(viewport_size.x / design_w, viewport_size.y / design_h)
	var bg_size := Vector2(design_w * bg_scale, design_h * bg_scale)
	var bg_offset := (viewport_size - bg_size) / 2.0

	var player_pos := bg_offset + PORTHOLE_LEFT * bg_scale
	var enemy_pos := bg_offset + PORTHOLE_RIGHT * bg_scale
	var ship_screen_size := Vector2(SHIP_SIZE.x * bg_scale, SHIP_SIZE.y * bg_scale)

	var title_bottom_y := bg_offset.y + TITLE_MIDBOTTOM_Y * bg_scale
	var name_label_w := 260.0 * bg_scale
	var name_label_h := 36.0 * bg_scale
	var name_font_size := maxi(NAME_FONT_BASE, int(round(NAME_FONT_BASE * bg_scale)))

	var bar_w := BAR_W * bg_scale
	var bar_h := maxf(8.0, BAR_H * bg_scale)
	var hb_left := bg_offset + HEALTHBAR_LEFT * bg_scale
	var hb_right := bg_offset + HEALTHBAR_RIGHT * bg_scale
	var player_bar_rect := Rect2(hb_left.x - bar_w / 2.0, hb_left.y - bar_h / 2.0, bar_w, bar_h)
	var enemy_bar_rect := Rect2(hb_right.x - bar_w / 2.0, hb_right.y - bar_h / 2.0, bar_w, bar_h)

	var hull_y := bg_offset.y + HULL_TEXT_Y * bg_scale
	var hull_label_w := BAR_W * bg_scale
	var hull_label_h := 24.0 * bg_scale
	var hull_font_size := maxi(HULL_FONT_BASE, int(round(HULL_FONT_BASE * bg_scale)))

	var log_top := bg_offset.y + LOG_TOP * bg_scale
	var log_bot := bg_offset.y + LOG_BOT * bg_scale
	var log_margin := bg_offset.x + LOG_MARGIN_X * bg_scale

	var action_y := bg_offset.y + ACTION_Y * bg_scale
	var action_w := 360.0 * bg_scale

	return {
		"bg_scale": bg_scale,
		"bg_offset": bg_offset,
		"player_pos": player_pos,
		"enemy_pos": enemy_pos,
		"ship_screen_size": ship_screen_size,
		"player_ship_pos": player_pos - ship_screen_size / 2.0,
		"enemy_ship_pos": enemy_pos - ship_screen_size / 2.0,
		"player_name_pos": Vector2(player_pos.x - name_label_w / 2.0, title_bottom_y - name_label_h),
		"enemy_name_pos": Vector2(enemy_pos.x - name_label_w / 2.0, title_bottom_y - name_label_h),
		"name_label_size": Vector2(name_label_w, name_label_h),
		"name_font_size": name_font_size,
		"player_bar_rect": player_bar_rect,
		"enemy_bar_rect": enemy_bar_rect,
		"player_hull_pos": Vector2(player_pos.x - hull_label_w / 2.0, hull_y),
		"enemy_hull_pos": Vector2(enemy_pos.x - hull_label_w / 2.0, hull_y),
		"hull_label_size": Vector2(hull_label_w, hull_label_h),
		"hull_font_size": hull_font_size,
		"log_pos": Vector2(log_margin, log_top),
		"log_size": Vector2(viewport_size.x - log_margin * 2.0, log_bot - log_top),
		"actions_pos": Vector2(viewport_size.x / 2.0 - action_w / 2.0, action_y),
		"actions_size": Vector2(action_w, 50),
		"result_pos": Vector2(viewport_size.x / 2.0 - 200, action_y - 10),
		"result_size": Vector2(400, 50),
		"continue_pos": Vector2(viewport_size.x / 2.0 - 200, action_y + 45),
		"continue_size": Vector2(400, 30),
	}
