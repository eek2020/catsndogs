## Guards the Sprint 8 claim that biome-weighted POI placement biases
## toward preferred biomes. Operates on the biome field directly rather
## than navigation.gd's UI-side rejection sampler — the UI wraps the same
## `ProceduralMapManager.sample_biome` call this test exercises, so a
## failure here means the UI wrapper has nothing to lean on.
extends GutTest


const REGION := "starting_realm"


func _sample_id(x: float, y: float) -> int:
	return int(ProceduralMapManager.sample_biome(REGION, x, y).get("biome_id", -1))


## Pure-function mirror of navigation.gd._pick_biome_spawn, with the
## random candidate generator injected so the test can seed it.
func _pick_biased(preferred: Array, candidates: Array) -> int:
	var first_id: int = _sample_id(candidates[0].x, candidates[0].y)
	if first_id in preferred:
		return first_id
	for i in range(1, candidates.size()):
		var bid: int = _sample_id(candidates[i].x, candidates[i].y)
		if bid in preferred:
			return bid
	return first_id


func _random_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf() * 4000.0, rng.randf() * 4000.0)


func test_region_covers_multiple_biomes() -> void:
	# Bias only works if the region actually contains varied biomes. If
	# this ever fails, the noise seed has collapsed and the whole biome
	# nuance feature is moot.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9876
	var distinct := {}
	for _i in range(200):
		var p: Vector2 = _random_point(rng)
		distinct[_sample_id(p.x, p.y)] = true
	assert_gte(distinct.size(), 3,
		"region '%s' should cover at least 3 biomes; got %d" % [REGION, distinct.size()])


func test_biased_picker_beats_uniform_for_preferred_biome() -> void:
	var preferred: Array = [10]  # cRock — tight target
	var trials: int = 150
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var unbiased_hits: int = 0
	var biased_hits: int = 0
	for _i in range(trials):
		var single: Vector2 = _random_point(rng)
		if _sample_id(single.x, single.y) in preferred:
			unbiased_hits += 1
		var candidates := []
		for _j in range(16):
			candidates.append(_random_point(rng))
		var picked: int = _pick_biased(preferred, candidates)
		if picked in preferred:
			biased_hits += 1
	# If neither unbiased nor biased ever hit the preferred biome, the
	# region lacks rocky pockets and the weighting can't help — skip the
	# strict comparison rather than false-fail.
	if unbiased_hits == 0 and biased_hits == 0:
		pending("region %s has no cRock biomes — biased comparison is moot" % REGION)
		return
	assert_gt(biased_hits, unbiased_hits,
		"biased rejection sampling should out-hit uniform (biased=%d, unbiased=%d)" % [biased_hits, unbiased_hits])


func test_empty_preference_returns_first_candidate() -> void:
	# Empty preference list ⇒ any biome is fine ⇒ picker returns the first
	# candidate untouched. Guards the navigation.gd fall-through path.
	var candidates := [Vector2(100.0, 100.0), Vector2(500.0, 500.0)]
	var result: int = _pick_biased([], candidates)
	var expected: int = _sample_id(100.0, 100.0)
	assert_eq(result, expected,
		"empty preference list should accept the first candidate as-is")


func test_unreachable_preference_falls_back_to_first() -> void:
	# Preference for a biome ID that doesn't exist (-1) ⇒ no candidate
	# matches ⇒ picker returns the first. Guards against infinite loops
	# and spawn failures when a JSON preference gets typoed.
	var candidates := [Vector2(200.0, 200.0), Vector2(800.0, 400.0)]
	var result: int = _pick_biased([-1], candidates)
	var expected: int = _sample_id(200.0, 200.0)
	assert_eq(result, expected,
		"unreachable preference should fall back to first candidate, not loop")
