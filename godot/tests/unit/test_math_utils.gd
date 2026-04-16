extends GutTest

func test_weighted_pick_empty_returns_null() -> void:
	assert_null(MathUtils.weighted_pick([], func(x): return 1.0))

func test_weighted_pick_all_zero_weight_returns_null() -> void:
	assert_null(MathUtils.weighted_pick([1, 2, 3], func(_x): return 0.0))

func test_weighted_pick_single_item_returns_it() -> void:
	assert_eq(MathUtils.weighted_pick(["only"], func(_x): return 1.0), "only")
