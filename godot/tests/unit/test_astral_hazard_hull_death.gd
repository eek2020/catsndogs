## Regression: Apr-05 #2 — hull death not emitted from hazard damage.
## AstralHazardSystem.apply_damage must emit combat_defeat on EventBus when
## hazard damage brings current_hull to 0, and must not double-emit if the
## ship is already dead.
extends GutTest

var hazards: AstralHazardSystem
var state: GameStateData

func before_each() -> void:
	hazards = AstralHazardSystem.new()
	state = GameStateData.new()
	state.player_ship = Ship.new()
	state.player_ship.current_hull = 10
	state.player_ship.max_hull = 100
	watch_signals(EventBus)

func test_apply_damage_emits_combat_defeat_on_hull_zero() -> void:
	hazards.apply_damage(state, 10)
	assert_eq(state.player_ship.current_hull, 0)
	assert_signal_emitted(EventBus, "combat_defeat")

func test_apply_damage_no_signal_when_ship_still_alive() -> void:
	hazards.apply_damage(state, 5)
	assert_eq(state.player_ship.current_hull, 5)
	assert_signal_not_emitted(EventBus, "combat_defeat")

func test_apply_damage_no_double_emit_when_already_dead() -> void:
	state.player_ship.current_hull = 0
	hazards.apply_damage(state, 5)
	assert_signal_not_emitted(EventBus, "combat_defeat")

func test_apply_damage_null_ship_no_crash() -> void:
	state.player_ship = null
	hazards.apply_damage(state, 10)
	assert_signal_not_emitted(EventBus, "combat_defeat")
