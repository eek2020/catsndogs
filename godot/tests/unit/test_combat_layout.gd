extends GutTest

## Regression coverage for CombatLayout.compute (Sprint 3b). The layout math
## is a pure function of viewport size + design resolution — these tests
## pin down invariants (symmetry, scale, non-negative rect sizes) without
## needing the scene tree.

const DESIGN_W := 1280.0
const DESIGN_H := 720.0


# ---------------------------------------------------------------------------
# Empty / guard
# ---------------------------------------------------------------------------

func test_compute_returns_empty_for_zero_viewport() -> void:
	assert_eq(CombatLayout.compute(Vector2.ZERO, DESIGN_W, DESIGN_H), {})


func test_compute_returns_empty_for_negative_viewport() -> void:
	assert_eq(CombatLayout.compute(Vector2(-1, 100), DESIGN_W, DESIGN_H), {})


func test_compute_returns_empty_for_zero_design() -> void:
	assert_eq(CombatLayout.compute(Vector2(1280, 720), 0.0, 720.0), {})


# ---------------------------------------------------------------------------
# Native resolution
# ---------------------------------------------------------------------------

func test_compute_at_native_resolution_has_unit_scale() -> void:
	var frame := CombatLayout.compute(Vector2(DESIGN_W, DESIGN_H), DESIGN_W, DESIGN_H)
	assert_eq(frame["bg_scale"], 1.0)
	assert_eq(frame["bg_offset"], Vector2.ZERO)


func test_player_and_enemy_pos_symmetric_at_native_resolution() -> void:
	var frame := CombatLayout.compute(Vector2(DESIGN_W, DESIGN_H), DESIGN_W, DESIGN_H)
	var player_pos: Vector2 = frame["player_pos"]
	var enemy_pos: Vector2 = frame["enemy_pos"]
	# Porthole centres at (253, 176) and (773, 176) — mirrored about x=513
	assert_eq(player_pos.y, enemy_pos.y)
	assert_eq((player_pos.x + enemy_pos.x) / 2.0, 513.0)


func test_bar_rects_have_matching_sizes() -> void:
	var frame := CombatLayout.compute(Vector2(DESIGN_W, DESIGN_H), DESIGN_W, DESIGN_H)
	var p_rect: Rect2 = frame["player_bar_rect"]
	var e_rect: Rect2 = frame["enemy_bar_rect"]
	assert_eq(p_rect.size, e_rect.size)
	assert_eq(p_rect.size.y, 20.0)  # BAR_H at unit scale


# ---------------------------------------------------------------------------
# Upscaled
# ---------------------------------------------------------------------------

func test_compute_at_2x_scales_positions_proportionally() -> void:
	var native := CombatLayout.compute(Vector2(DESIGN_W, DESIGN_H), DESIGN_W, DESIGN_H)
	var doubled := CombatLayout.compute(Vector2(DESIGN_W * 2.0, DESIGN_H * 2.0), DESIGN_W, DESIGN_H)
	assert_eq(doubled["bg_scale"], 2.0)
	# Player pos scales from (253, 176) → (506, 352)
	assert_eq(doubled["player_pos"], native["player_pos"] * 2.0)


func test_compute_covers_ultrawide_viewport() -> void:
	# Ultrawide (21:9 at 1280 width) — scale picks the greater axis ratio so
	# the background fully covers, which means a centred horizontal offset
	# for a square-ish vertical aspect is negative on one axis.
	var frame := CombatLayout.compute(Vector2(2560, 720), DESIGN_W, DESIGN_H)
	assert_eq(frame["bg_scale"], 2.0)  # 2560/1280 = 2 vs 720/720 = 1
	assert_true(frame.has("player_pos"))


func test_font_sizes_never_shrink_below_base() -> void:
	# Even when bg_scale < 1 (impossible with covered scaling but reassure),
	# name_font_size and hull_font_size should respect the base minimum.
	var frame := CombatLayout.compute(Vector2(DESIGN_W, DESIGN_H), DESIGN_W, DESIGN_H)
	assert_true(frame["name_font_size"] >= 20)
	assert_true(frame["hull_font_size"] >= 13)


# ---------------------------------------------------------------------------
# Rects / sizes are consistent
# ---------------------------------------------------------------------------

func test_ship_screen_size_matches_ship_rect_size() -> void:
	var frame := CombatLayout.compute(Vector2(DESIGN_W, DESIGN_H), DESIGN_W, DESIGN_H)
	var player_pos: Vector2 = frame["player_pos"]
	var ship_size: Vector2 = frame["ship_screen_size"]
	var player_ship_pos: Vector2 = frame["player_ship_pos"]
	# Ship sprite is positioned so its centre lands on the porthole centre.
	assert_eq(player_ship_pos, player_pos - ship_size / 2.0)


func test_log_rect_height_positive() -> void:
	var frame := CombatLayout.compute(Vector2(DESIGN_W, DESIGN_H), DESIGN_W, DESIGN_H)
	var log_size: Vector2 = frame["log_size"]
	assert_true(log_size.y > 0.0)
	assert_true(log_size.x > 0.0)


func test_actions_centred_on_viewport() -> void:
	var frame := CombatLayout.compute(Vector2(DESIGN_W, DESIGN_H), DESIGN_W, DESIGN_H)
	var actions_pos: Vector2 = frame["actions_pos"]
	var actions_size: Vector2 = frame["actions_size"]
	# Centre of actions container should be at viewport centre x.
	assert_eq(actions_pos.x + actions_size.x / 2.0, DESIGN_W / 2.0)
