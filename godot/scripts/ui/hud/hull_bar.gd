## HullBar — segmented hull-integrity bar for the navigation HUD.
##
## Sprint 5c part 2 / CODE_REVIEW §4.6: replace the plain "Hull: 100/100" label
## with a visual bar so players can read ship health at a glance.
class_name HullBar
extends Control

const SEGMENTS: int = 10
const SEG_GAP: int = 2
const FRAME := Color(0.549, 0.451, 0.294)
const BACKING := Color(0.118, 0.098, 0.078)
const FILL_HIGH := Color(0.235, 0.706, 0.275)
const FILL_MID := Color(0.94, 0.75, 0.25)
const FILL_LOW := Color(0.745, 0.196, 0.137)

@export var current: int = 100
@export var maximum: int = 100


func _ready() -> void:
	custom_minimum_size = Vector2(120, 16)
	queue_redraw()


## Update the fill ratio and trigger a redraw. Caller supplies raw values; the
## bar clamps internally so a negative current reads as zero.
func set_hull(p_current: int, p_max: int) -> void:
	current = p_current
	maximum = p_max
	queue_redraw()


## Ratio of hull remaining in [0.0, 1.0]. Public so tests and layout code can
## sanity-check the bar without poking at draw state.
func fill_ratio() -> float:
	if maximum <= 0:
		return 0.0
	return clampf(float(current) / float(maximum), 0.0, 1.0)


## Number of segments currently lit (0..SEGMENTS). Rounds up so a ship with
## 1 HP still shows a single lit cell — important for "you are alive" feedback.
func filled_segments() -> int:
	var ratio := fill_ratio()
	if ratio <= 0.0:
		return 0
	return clampi(int(ceil(ratio * SEGMENTS)), 1, SEGMENTS)


## Fill colour for the given ratio. Static so tests can assert the palette
## without instantiating the Control.
static func color_for_ratio(ratio: float) -> Color:
	if ratio <= 0.25:
		return FILL_LOW
	elif ratio <= 0.5:
		return FILL_MID
	return FILL_HIGH


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Brass frame + dark backing
	draw_rect(rect.grow(1), FRAME)
	draw_rect(rect, BACKING)

	var ratio := fill_ratio()
	var lit := filled_segments()
	if lit <= 0:
		draw_rect(rect, FRAME, false, 1.0)
		return

	var fill_color := color_for_ratio(ratio)
	var total_gap := float(SEG_GAP * (SEGMENTS - 1))
	var seg_w := (size.x - total_gap) / float(SEGMENTS)
	for i in lit:
		var seg_x := float(i) * (seg_w + float(SEG_GAP))
		draw_rect(Rect2(Vector2(seg_x, 0.0), Vector2(seg_w, size.y)), fill_color)
	draw_rect(rect, FRAME, false, 1.0)
