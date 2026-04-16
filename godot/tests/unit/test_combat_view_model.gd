extends GutTest

## Regression coverage for CombatViewModel (Sprint 3b, NEXT_STEPS.md §2).
## The VM is the only path combat_ui.gd uses to reach GameSession. We
## construct a SessionDouble with the same duck-typed shape and verify the
## VM reads / writes / no-ops through it correctly.


class SessionDouble:
	extends RefCounted
	var game_state: GameStateData = null


func _make_session_with_state() -> SessionDouble:
	var session := SessionDouble.new()
	var gs := GameStateData.new()
	var ship := Ship.new()
	ship.current_hull = 50
	ship.max_hull = 100
	gs.player_ship = ship
	gs.crystal_inventory = 10
	gs.salvage = 20
	session.game_state = gs
	return session


# ---------------------------------------------------------------------------
# has_state
# ---------------------------------------------------------------------------

func test_has_state_false_when_game_state_null() -> void:
	var session := SessionDouble.new()
	var vm := CombatViewModel.new(session)
	assert_false(vm.has_state())


func test_has_state_true_when_game_state_set() -> void:
	var session := _make_session_with_state()
	var vm := CombatViewModel.new(session)
	assert_true(vm.has_state())


# ---------------------------------------------------------------------------
# sync_player_hull
# ---------------------------------------------------------------------------

func test_sync_player_hull_writes_to_player_ship() -> void:
	var session := _make_session_with_state()
	var vm := CombatViewModel.new(session)
	vm.sync_player_hull(37)
	assert_eq(session.game_state.player_ship.current_hull, 37)


func test_sync_player_hull_noop_when_game_state_null() -> void:
	var session := SessionDouble.new()
	var vm := CombatViewModel.new(session)
	vm.sync_player_hull(42)  # must not throw
	assert_null(session.game_state)


func test_sync_player_hull_noop_when_player_ship_null() -> void:
	var session := SessionDouble.new()
	session.game_state = GameStateData.new()
	var vm := CombatViewModel.new(session)
	vm.sync_player_hull(42)  # must not throw
	assert_null(session.game_state.player_ship)


# ---------------------------------------------------------------------------
# apply_victory_loot
# ---------------------------------------------------------------------------

func test_apply_victory_loot_adds_to_inventory() -> void:
	var session := _make_session_with_state()
	var vm := CombatViewModel.new(session)
	vm.apply_victory_loot(5, 7)
	assert_eq(session.game_state.crystal_inventory, 15)
	assert_eq(session.game_state.salvage, 27)


func test_apply_victory_loot_noop_when_game_state_null() -> void:
	var session := SessionDouble.new()
	var vm := CombatViewModel.new(session)
	vm.apply_victory_loot(5, 7)  # must not throw
	assert_null(session.game_state)


func test_apply_victory_loot_handles_zero_amounts() -> void:
	var session := _make_session_with_state()
	var vm := CombatViewModel.new(session)
	vm.apply_victory_loot(0, 0)
	assert_eq(session.game_state.crystal_inventory, 10)
	assert_eq(session.game_state.salvage, 20)
