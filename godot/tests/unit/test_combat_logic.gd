extends GutTest

## Regression coverage for CombatLogic (Sprint 3b). Exercises the three pure
## turn-resolution functions with an injected RandomNumberGenerator so hit /
## miss / flee outcomes are deterministic. Damage variance still comes from
## CombatSystem (global RNG) — these tests assert ranges, not exact values.


func _make_ship(p_name: String, firepower: int, armour: int, speed: int, hull: int = 100) -> CombatSystem.CombatShip:
	var cs := CombatSystem.CombatShip.new()
	cs.ship_name = p_name
	cs.firepower = firepower
	cs.armour = armour
	cs.speed = speed
	cs.current_hull = hull
	cs.max_hull = hull
	return cs


class StubRng:
	extends RefCounted
	var next: float = 0.0
	func randf() -> float:
		return next


# ---------------------------------------------------------------------------
# resolve_player_attack
# ---------------------------------------------------------------------------

func test_player_attack_hits_when_roll_above_dodge() -> void:
	var player := _make_ship("Dawn", 10, 0, 10)
	var enemy := _make_ship("Corsair", 5, 5, 0, 50)  # speed 0 → dodge 0
	var rng := StubRng.new()
	rng.next = 1.0  # always >= 0 dodge
	var result := CombatLogic.resolve_player_attack(player, enemy, rng)
	assert_true(result["hit"])
	assert_true(result["damage"] > 0)
	assert_true(enemy.current_hull < 50)
	assert_true(&"combat_hit" in result["event_signals"])


func test_player_attack_misses_when_roll_below_dodge() -> void:
	var player := _make_ship("Dawn", 10, 0, 10)
	var enemy := _make_ship("Corsair", 5, 5, 10, 50)  # high speed → dodge > 0
	var rng := StubRng.new()
	rng.next = 0.0  # always < any positive dodge
	var result := CombatLogic.resolve_player_attack(player, enemy, rng)
	assert_false(result["hit"])
	assert_eq(result["damage"], 0)
	assert_eq(enemy.current_hull, 50)
	assert_true(&"combat_miss" in result["event_signals"])


func test_player_attack_marks_target_dead_when_hull_zero() -> void:
	var player := _make_ship("Dawn", 100, 0, 10)
	var enemy := _make_ship("Corsair", 5, 0, 0, 1)  # 1 hp, guaranteed death
	var rng := StubRng.new()
	rng.next = 1.0
	var result := CombatLogic.resolve_player_attack(player, enemy, rng)
	assert_true(result["hit"])
	assert_true(result["target_dead"])
	assert_eq(enemy.current_hull, 0)
	assert_true(&"combat_victory" in result["event_signals"])


func test_player_attack_logs_dodge_message_on_miss() -> void:
	var player := _make_ship("Dawn", 10, 0, 10)
	var enemy := _make_ship("Corsair", 5, 5, 10, 50)
	var rng := StubRng.new()
	rng.next = 0.0
	var result := CombatLogic.resolve_player_attack(player, enemy, rng)
	var log_text: String = ", ".join(result["log_messages"])
	assert_true(log_text.contains("dodges"))


# ---------------------------------------------------------------------------
# resolve_enemy_attack
# ---------------------------------------------------------------------------

func test_enemy_attack_hits_and_damages_player() -> void:
	var player := _make_ship("Dawn", 10, 0, 0, 100)  # speed 0 → dodge 0
	var enemy := _make_ship("Corsair", 10, 0, 5)
	var rng := StubRng.new()
	rng.next = 1.0
	var result := CombatLogic.resolve_enemy_attack(player, enemy, rng)
	assert_true(result["hit"])
	assert_true(result["damage"] > 0)
	assert_true(player.current_hull < 100)


func test_enemy_attack_marks_player_dead_on_fatal_blow() -> void:
	var player := _make_ship("Dawn", 10, 0, 0, 1)
	var enemy := _make_ship("Corsair", 100, 0, 5)
	var rng := StubRng.new()
	rng.next = 1.0
	var result := CombatLogic.resolve_enemy_attack(player, enemy, rng)
	assert_true(result["target_dead"])
	assert_eq(player.current_hull, 0)
	assert_true(&"combat_defeat" in result["event_signals"])


func test_enemy_attack_miss_leaves_player_hull_intact() -> void:
	var player := _make_ship("Dawn", 10, 0, 10, 100)  # high dodge
	var enemy := _make_ship("Corsair", 10, 0, 5)
	var rng := StubRng.new()
	rng.next = 0.0
	var result := CombatLogic.resolve_enemy_attack(player, enemy, rng)
	assert_false(result["hit"])
	assert_eq(player.current_hull, 100)
	assert_true(&"combat_miss" in result["event_signals"])


# ---------------------------------------------------------------------------
# resolve_flee
# ---------------------------------------------------------------------------

func test_flee_succeeds_when_roll_below_chance() -> void:
	var player := _make_ship("Dawn", 5, 5, 10)
	var enemy := _make_ship("Corsair", 5, 5, 10)
	# base_chance = 10/20 = 0.5, attempts=0, flee_chance=0.5
	var rng := StubRng.new()
	rng.next = 0.1
	var result := CombatLogic.resolve_flee(player, enemy, 0, rng)
	assert_true(result["success"])
	assert_eq(result["new_attempts"], 1)
	assert_true(&"combat_flee" in result["event_signals"])


func test_flee_fails_when_roll_above_chance() -> void:
	var player := _make_ship("Dawn", 5, 5, 10)
	var enemy := _make_ship("Corsair", 5, 5, 10)
	var rng := StubRng.new()
	rng.next = 0.9  # > 0.5 threshold
	var result := CombatLogic.resolve_flee(player, enemy, 0, rng)
	assert_false(result["success"])
	assert_eq(result["new_attempts"], 1)
	var log_text: String = ", ".join(result["log_messages"])
	assert_true(log_text.contains("Failed"))


func test_flee_attempt_counter_increments() -> void:
	var player := _make_ship("Dawn", 5, 5, 10)
	var enemy := _make_ship("Corsair", 5, 5, 10)
	var rng := StubRng.new()
	rng.next = 0.99  # always fail first attempt
	var result := CombatLogic.resolve_flee(player, enemy, 2, rng)
	assert_eq(result["new_attempts"], 3)


func test_flee_chance_caps_at_95_percent() -> void:
	# A fast player vs slow enemy with many attempts should still have
	# flee_chance capped at 0.95, not 1.0.
	var player := _make_ship("Dawn", 5, 5, 10)
	var enemy := _make_ship("Corsair", 5, 5, 1)
	# base_chance = 10/11 ≈ 0.909, +5*0.15 = 1.659 → capped to 0.95
	var rng := StubRng.new()
	rng.next = 0.96  # above 0.95 cap → must fail
	var result := CombatLogic.resolve_flee(player, enemy, 5, rng)
	assert_false(result["success"])
