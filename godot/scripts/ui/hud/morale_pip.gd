## MoralePip — small coloured dot on the HUD that reflects crew mood.
##
## Sprint 5c part 2 / CODE_REVIEW §4.6: crew morale drives combat + trade
## (Sprint 5b), so the player needs a one-glance readout before a fight to know
## whether their damage multiplier is helping them or hurting them.
class_name MoralePip
extends Control

const MUTINY := Color(0.745, 0.196, 0.137)
const LOW := Color(0.86, 0.45, 0.2)
const STEADY := Color(0.94, 0.75, 0.25)
const CONTENT := Color(0.55, 0.78, 0.35)
const INSPIRED := Color(0.3, 0.9, 0.5)
const BG := Color(0.1, 0.08, 0.06)
const RING := Color(0.549, 0.451, 0.294)

@export var morale: int = 100


func _ready() -> void:
	custom_minimum_size = Vector2(14, 14)
	queue_redraw()


## Update the displayed morale and trigger a redraw.
func set_morale(p_morale: int) -> void:
	morale = p_morale
	queue_redraw()


## Fill colour mapped to the same thresholds CrewMoraleSystem uses for its
## combat/trade modifiers. Static so tests can assert the palette without
## needing a Control instance.
static func color_for_morale(value: int) -> Color:
	if value <= CrewMoraleSystem.MUTINY_THRESHOLD:
		return MUTINY
	elif value <= CrewMoraleSystem.LOW_THRESHOLD:
		return LOW
	elif value <= CrewMoraleSystem.NEUTRAL_THRESHOLD:
		return STEADY
	elif value <= CrewMoraleSystem.HIGH_THRESHOLD:
		return CONTENT
	return INSPIRED


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var center := size * 0.5
	draw_circle(center, radius, BG)
	draw_circle(center, radius - 1.5, color_for_morale(morale))
	draw_arc(center, radius, 0.0, TAU, 24, RING, 1.0)
