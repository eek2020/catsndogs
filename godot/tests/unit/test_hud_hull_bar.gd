extends GutTest

## Regression: Sprint 5c part 2 / CODE_REVIEW §4.6 — segmented hull bar replaces
## the plain "Hull X/Y" text on the navigation HUD. Tests cover the pure math
## that drives the draw loop (ratio, segments, colour palette) without needing
## to spin up the Control in a scene tree.


const HullBarScript := preload("res://scripts/ui/hud/hull_bar.gd")

var _bars: Array[HullBar] = []


func _make() -> HullBar:
	var bar: HullBar = HullBarScript.new()
	_bars.append(bar)
	return bar


func after_each() -> void:
	for bar in _bars:
		if is_instance_valid(bar):
			bar.free()
	_bars.clear()


func test_fill_ratio_full() -> void:
	var bar := _make()
	bar.set_hull(100, 100)
	assert_eq(bar.fill_ratio(), 1.0)


func test_fill_ratio_half() -> void:
	var bar := _make()
	bar.set_hull(50, 100)
	assert_eq(bar.fill_ratio(), 0.5)


func test_fill_ratio_zero_max_is_safe() -> void:
	var bar := _make()
	bar.set_hull(5, 0)
	assert_eq(bar.fill_ratio(), 0.0)


func test_fill_ratio_negative_current_clamps_to_zero() -> void:
	var bar := _make()
	bar.set_hull(-10, 100)
	assert_eq(bar.fill_ratio(), 0.0)


func test_fill_ratio_overflow_clamps_to_one() -> void:
	var bar := _make()
	bar.set_hull(250, 100)
	assert_eq(bar.fill_ratio(), 1.0)


func test_filled_segments_full_lights_all_ten() -> void:
	var bar := _make()
	bar.set_hull(100, 100)
	assert_eq(bar.filled_segments(), HullBarScript.SEGMENTS)


func test_filled_segments_empty_lights_none() -> void:
	var bar := _make()
	bar.set_hull(0, 100)
	assert_eq(bar.filled_segments(), 0)


func test_filled_segments_one_hp_still_shows_one_lit() -> void:
	# You-are-alive feedback: never round down to 0 while current > 0.
	var bar := _make()
	bar.set_hull(1, 100)
	assert_eq(bar.filled_segments(), 1)


func test_filled_segments_rounds_up() -> void:
	var bar := _make()
	bar.set_hull(45, 100)
	# 45% -> ceil(4.5) = 5 segments
	assert_eq(bar.filled_segments(), 5)


func test_color_for_ratio_low() -> void:
	assert_eq(HullBarScript.color_for_ratio(0.1), HullBarScript.FILL_LOW)
	assert_eq(HullBarScript.color_for_ratio(0.25), HullBarScript.FILL_LOW)


func test_color_for_ratio_mid() -> void:
	assert_eq(HullBarScript.color_for_ratio(0.4), HullBarScript.FILL_MID)
	assert_eq(HullBarScript.color_for_ratio(0.5), HullBarScript.FILL_MID)


func test_color_for_ratio_high() -> void:
	assert_eq(HullBarScript.color_for_ratio(0.75), HullBarScript.FILL_HIGH)
	assert_eq(HullBarScript.color_for_ratio(1.0), HullBarScript.FILL_HIGH)
