## CombatHealthBar — static draw helper for the steampunk health bar.
##
## Extracted from combat_ui.gd so the drawing logic can be reused (e.g. in a
## ship screen or station UI) without duplicating the brass frame + segment
## line rendering.
class_name CombatHealthBar
extends RefCounted

const HEALTH_GREEN := Color(0.235, 0.706, 0.275)
const HEALTH_RED := Color(0.745, 0.196, 0.137)
const HEALTH_BG := Color(0.118, 0.098, 0.078)
const HEALTH_FRAME := Color(0.549, 0.451, 0.294)
const SEG_LINE := Color(0.078, 0.071, 0.055)


## Draw a single health bar at the given rect on the given CanvasItem. The
## caller is expected to invoke this from a `draw` handler — it issues
## `draw_rect` / `draw_line` calls directly.
static func draw(canvas: CanvasItem, rect: Rect2, current: int, maximum: int) -> void:
	if rect.size.x <= 0:
		return
	var pct := float(current) / maxf(1.0, float(maximum))
	var fill_color := HEALTH_GREEN if pct > 0.5 else HEALTH_RED

	# Brass frame background
	var frame_rect := rect.grow(2)
	canvas.draw_rect(frame_rect, HEALTH_FRAME)
	# Dark backing
	canvas.draw_rect(rect, HEALTH_BG)

	# Health fill
	var fill_w := maxf(0, rect.size.x * pct)
	if fill_w > 0:
		canvas.draw_rect(
			Rect2(rect.position, Vector2(fill_w, rect.size.y)), fill_color
		)

	# Segment lines
	var seg_step := maxf(20, rect.size.x / 8.0)
	var seg_x := rect.position.x + seg_step
	while seg_x < rect.position.x + rect.size.x:
		canvas.draw_line(
			Vector2(seg_x, rect.position.y),
			Vector2(seg_x, rect.position.y + rect.size.y),
			SEG_LINE, 1.0
		)
		seg_x += seg_step

	# Frame outline
	canvas.draw_rect(frame_rect, HEALTH_FRAME, false, 2.0)
