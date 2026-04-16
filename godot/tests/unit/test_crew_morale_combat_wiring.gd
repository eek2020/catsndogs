extends GutTest

## Regression coverage for Sprint 5b — crew morale wired into the combat
## damage pipeline.
##
## Three layers are exercised:
## 1. `CombatSystem.calculate_damage(morale_modifier)` — raw math. Averaged
##    over many samples because damage variance is [0.8, 1.2] via the global
##    RNG; the morale delta is designed to dominate that range.
## 2. `CombatLogic.resolve_player_attack(..., player_morale_modifier)` —
##    thread-through to the orchestrator-level resolver.
## 3. `CombatViewModel.combat_morale_modifier()` — null-guarded adapter the
##    UI reaches for each attack. Uses duck-typed session doubles so no
##    autoload is required.


# ---------------------------------------------------------------------------
# Helpers / doubles
# ---------------------------------------------------------------------------

const SAMPLES: int = 60


class MoraleDouble:
	extends RefCounted
	var value: float = 1.0
	func get_combat_modifier(_gs) -> float:
		return value


class SessionWithMorale:
	extends RefCounted
	var game_state: GameStateData = null
	# Untyped so the field can hold a MoraleDouble (unit tests) or a real
	# CrewMoraleSystem (integration test below).
	var crew_morale = MoraleDouble.new()


class SessionBare:
	extends RefCounted
	var game_state: GameStateData = null


class StubRng:
	extends RefCounted
	var next: float = 1.0
	func randf() -> float:
		return next


func _make_ship(firepower: int, armour: int, speed: int, hull: int = 100) -> CombatSystem.CombatShip:
	var cs := CombatSystem.CombatShip.new()
	cs.ship_name = "Test"
	cs.firepower = firepower
	cs.armour = armour
	cs.speed = speed
	cs.current_hull = hull
	cs.max_hull = hull
	return cs


func _mean_damage(morale: float) -> float:
	var total := 0
	for _i in SAMPLES:
		total += CombatSystem.calculate_damage(100, 0, 0.0, 0, 0.0, morale)
	return float(total) / SAMPLES


# ---------------------------------------------------------------------------
# CombatSystem.calculate_damage — morale scales effective firepower
# ---------------------------------------------------------------------------

func test_calculate_damage_high_morale_beats_low_morale() -> void:
	# INSPIRED (1.2×) should produce a meaningfully larger mean damage than
	# MUTINY (0.7×) at the same base firepower. Averaged over SAMPLES to
	# smooth the ±20% variance.
	var high := _mean_damage(1.2)
	var low := _mean_damage(0.7)
	assert_gt(high, low)


func test_calculate_damage_default_morale_is_neutral() -> void:
	# Omitting the morale param must behave identically to morale=1.0 in
	# aggregate — existing combat tests rely on this backwards compatibility.
	var explicit_total := 0
	var default_total := 0
	for _i in SAMPLES:
		explicit_total += CombatSystem.calculate_damage(100, 0, 0.0, 0, 0.0, 1.0)
		default_total += CombatSystem.calculate_damage(100, 0)
	# Means should both sit inside the expected [80, 120] variance window.
	var explicit_mean := float(explicit_total) / SAMPLES
	var default_mean := float(default_total) / SAMPLES
	assert_gt(explicit_mean, 70.0)
	assert_lt(explicit_mean, 130.0)
	assert_gt(default_mean, 70.0)
	assert_lt(default_mean, 130.0)


func test_calculate_damage_extreme_morale_ranges_do_not_overlap() -> void:
	# fp=100, armour=0, morale=2.0 → damage ∈ [160, 240]
	# fp=100, armour=0, morale=0.4 → damage ∈ [32, 48]
	# With ±20% variance the ranges never overlap, so any single sample pair
	# must satisfy high > low.
	for _i in 10:
		var high := CombatSystem.calculate_damage(100, 0, 0.0, 0, 0.0, 2.0)
		var low := CombatSystem.calculate_damage(100, 0, 0.0, 0, 0.0, 0.4)
		assert_gt(high, low)


# ---------------------------------------------------------------------------
# CombatLogic.resolve_player_attack — morale threads through
# ---------------------------------------------------------------------------

func test_resolve_player_attack_morale_raises_mean_damage() -> void:
	var rng := StubRng.new()
	rng.next = 1.0  # roll always passes any dodge threshold
	var hi_total := 0
	var lo_total := 0
	for _i in SAMPLES:
		var p_hi := _make_ship(100, 0, 10)
		var e_hi := _make_ship(5, 0, 0, 100000)
		var r_hi: Dictionary = CombatLogic.resolve_player_attack(p_hi, e_hi, rng, 1.2)
		hi_total += int(r_hi["damage"])
		var p_lo := _make_ship(100, 0, 10)
		var e_lo := _make_ship(5, 0, 0, 100000)
		var r_lo: Dictionary = CombatLogic.resolve_player_attack(p_lo, e_lo, rng, 0.7)
		lo_total += int(r_lo["damage"])
	assert_gt(hi_total, lo_total)


func test_resolve_player_attack_default_morale_is_one() -> void:
	# Explicit 1.0 and omitted morale must produce statistically equivalent
	# damage totals (sampled) — asserts default param binding.
	var rng := StubRng.new()
	rng.next = 1.0
	var default_total := 0
	var explicit_total := 0
	for _i in SAMPLES:
		var p1 := _make_ship(100, 0, 10)
		var e1 := _make_ship(5, 0, 0, 100000)
		var r1: Dictionary = CombatLogic.resolve_player_attack(p1, e1, rng)
		default_total += int(r1["damage"])
		var p2 := _make_ship(100, 0, 10)
		var e2 := _make_ship(5, 0, 0, 100000)
		var r2: Dictionary = CombatLogic.resolve_player_attack(p2, e2, rng, 1.0)
		explicit_total += int(r2["damage"])
	# Both means should fall in the expected ±20% variance window around 100.
	var default_mean := float(default_total) / SAMPLES
	var explicit_mean := float(explicit_total) / SAMPLES
	assert_gt(default_mean, 70.0)
	assert_lt(default_mean, 130.0)
	assert_gt(explicit_mean, 70.0)
	assert_lt(explicit_mean, 130.0)


# ---------------------------------------------------------------------------
# CombatViewModel.combat_morale_modifier — null-guarded adapter
# ---------------------------------------------------------------------------

func test_vm_morale_returns_one_when_game_state_null() -> void:
	var session := SessionWithMorale.new()
	var vm := CombatViewModel.new(session)
	assert_eq(vm.combat_morale_modifier(), 1.0)


func test_vm_morale_returns_one_when_crew_morale_field_missing() -> void:
	var session := SessionBare.new()
	session.game_state = GameStateData.new()
	var vm := CombatViewModel.new(session)
	assert_eq(vm.combat_morale_modifier(), 1.0)


func test_vm_morale_returns_one_when_crew_morale_null() -> void:
	var session := SessionWithMorale.new()
	session.game_state = GameStateData.new()
	session.crew_morale = null
	var vm := CombatViewModel.new(session)
	assert_eq(vm.combat_morale_modifier(), 1.0)


func test_vm_morale_returns_crew_system_value() -> void:
	var session := SessionWithMorale.new()
	session.game_state = GameStateData.new()
	session.crew_morale.value = 1.2
	var vm := CombatViewModel.new(session)
	assert_eq(vm.combat_morale_modifier(), 1.2)


func test_vm_morale_returns_mutiny_penalty() -> void:
	var session := SessionWithMorale.new()
	session.game_state = GameStateData.new()
	session.crew_morale.value = 0.7
	var vm := CombatViewModel.new(session)
	assert_eq(vm.combat_morale_modifier(), 0.7)


# ---------------------------------------------------------------------------
# End-to-end — VM + real CrewMoraleSystem + live crew morale values
# ---------------------------------------------------------------------------

func test_vm_with_real_morale_system_maps_crew_to_combat_modifier() -> void:
	# Construct a SessionDouble wrapping a real CrewMoraleSystem and verify
	# the modifier reflects the crew's actual average morale.
	var session := SessionWithMorale.new()
	session.game_state = GameStateData.new()
	var ship := Ship.new()
	# Two crew at morale 10 → average 10 → MUTINY (≤20) → 0.7
	var c1 := Ship.CrewMember.new(); c1.morale = 10
	var c2 := Ship.CrewMember.new(); c2.morale = 10
	ship.crew = [c1, c2]
	session.game_state.player_ship = ship
	# Swap the double for a real CrewMoraleSystem.
	session.crew_morale = CrewMoraleSystem.new()
	var vm := CombatViewModel.new(session)
	assert_eq(vm.combat_morale_modifier(), 0.7)

	# Raise morale to INSPIRED territory (>80) → 1.2
	c1.morale = 95
	c2.morale = 95
	assert_eq(vm.combat_morale_modifier(), 1.2)
