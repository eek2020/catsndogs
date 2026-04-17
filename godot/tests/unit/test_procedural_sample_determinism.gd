## Guards the "same (region, x, y) => same biome" contract that the
## navigation nebula + POI biome placement depend on. If this test ever
## goes red, saved POI positions and scroll-cached textures become
## meaningless.
extends GutTest


func test_same_coordinate_returns_same_biome() -> void:
	var a: Dictionary = ProceduralMapManager.sample_biome("starting_realm", 1234.0, 567.0)
	var b: Dictionary = ProceduralMapManager.sample_biome("starting_realm", 1234.0, 567.0)
	assert_eq(a.get("biome_id"), b.get("biome_id"),
		"sample_biome must be deterministic for identical inputs")


func test_different_regions_disagree_at_same_coord() -> void:
	# Not a strict guarantee for every (x, y), but across 12 regions and
	# a handful of points we expect at least one disagreement — otherwise
	# the per-region seed isn't affecting the output.
	var sample_points := [
		Vector2(100.0, 100.0),
		Vector2(500.0, 250.0),
		Vector2(900.0, 1200.0),
		Vector2(1500.0, 800.0),
	]
	var disagreements: int = 0
	for p in sample_points:
		var in_starting: int = ProceduralMapManager.sample_biome(
			"starting_realm", p.x, p.y
		).get("biome_id", -1)
		var in_warp: int = ProceduralMapManager.sample_biome(
			"warp_marches", p.x, p.y
		).get("biome_id", -1)
		if in_starting != in_warp:
			disagreements += 1
	assert_gt(disagreements, 0,
		"per-region seed should produce at least one biome disagreement across sample points")


func test_unknown_region_does_not_crash() -> void:
	# Unknown region → hashed seed. Must still return a Dictionary with a biome_id.
	var sample: Dictionary = ProceduralMapManager.sample_biome("no_such_region", 0.0, 0.0)
	assert_true(sample.has("biome_id"))
	assert_true(sample.has("biome_tint"))


func test_biome_tint_is_present_and_reasonable() -> void:
	var sample: Dictionary = ProceduralMapManager.sample_biome("starting_realm", 0.0, 0.0)
	var tint: Color = sample.get("biome_tint", Color())
	# Biome tints are nudges around 1.0, so every channel should fall in a
	# sane visual band. Guards against someone dropping in a Color(10, -5, 0).
	assert_true(tint.r > 0.3 and tint.r < 2.0, "biome tint R out of sane range: %s" % tint.r)
	assert_true(tint.g > 0.3 and tint.g < 2.0, "biome tint G out of sane range: %s" % tint.g)
	assert_true(tint.b > 0.3 and tint.b < 2.0, "biome tint B out of sane range: %s" % tint.b)
