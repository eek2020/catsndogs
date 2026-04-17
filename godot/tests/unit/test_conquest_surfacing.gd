extends GutTest

## Regression coverage for Sprint 5c — faction conquest actions are now
## ticked by GameSession and surfaced to the UI via EventBus.
##
## Semantics enforced by this suite:
##   - Every resolved ConquestAction emits `EventBus.faction_conflict`
##     (aggressor_id, target_id, outcome) so the conquest log / HUD can react.
##   - Attack victories optionally shift `RealmControlSystem` influence in the
##     target's home realm, emitting `EventBus.realm_control_changed` when
##     that shift flips who controls the region.
##   - Passing `realm_control = null` to `resolve_actions` keeps the original
##     behaviour (backwards compatible — no crash, no influence shift).

var conquest: FactionConquestAI
var realm_control: RealmControlSystem
var state: GameStateData

var _faction_conflicts: Array = []
var _realm_changes: Array = []

const AGGRESSOR_ID: String = "test_aggressor"
const TARGET_ID: String = "test_target"
const REGION_ID: String = "target_homeworld"


func before_each() -> void:
	conquest = FactionConquestAI.new()
	realm_control = RealmControlSystem.new()
	state = GameStateData.new()
	_faction_conflicts.clear()
	_realm_changes.clear()

	var aggressor := Faction.new()
	aggressor.faction_id = AGGRESSOR_ID
	aggressor.faction_name = "Aggressor"
	aggressor.military_strength = 90
	aggressor.tactical_rating = 40
	aggressor.realm = "aggressor_home"
	state.faction_registry[AGGRESSOR_ID] = aggressor

	var target := Faction.new()
	target.faction_id = TARGET_ID
	target.faction_name = "Target"
	target.military_strength = 20
	target.internal_stability = 20
	target.crystal_reserves = 100
	target.realm = REGION_ID
	state.faction_registry[TARGET_ID] = target

	# Seed the target's realm so flips are observable.
	realm_control.add_influence(REGION_ID, TARGET_ID, 50.0)

	EventBus.faction_conflict.connect(_record_conflict)
	EventBus.realm_control_changed.connect(_record_realm_change)


func after_each() -> void:
	if EventBus.faction_conflict.is_connected(_record_conflict):
		EventBus.faction_conflict.disconnect(_record_conflict)
	if EventBus.realm_control_changed.is_connected(_record_realm_change):
		EventBus.realm_control_changed.disconnect(_record_realm_change)


func _record_conflict(aggressor_id: String, target_id: String, outcome: String) -> void:
	_faction_conflicts.append({
		"aggressor": aggressor_id,
		"target": target_id,
		"outcome": outcome,
	})


func _record_realm_change(region_id: String, old_controller: String, new_controller: String) -> void:
	_realm_changes.append({
		"region": region_id,
		"old": old_controller,
		"new": new_controller,
	})


func _queue_action(action_type: String) -> FactionConquestAI.ConquestAction:
	var action := FactionConquestAI.ConquestAction.new()
	action.action_id = "test_%s" % action_type
	action.aggressor_id = AGGRESSOR_ID
	action.target_id = TARGET_ID
	action.action_type = action_type
	action.strength = state.faction_registry[AGGRESSOR_ID].military_strength
	conquest.pending_actions.append(action)
	return action


# ---------------------------------------------------------------------------
# Every resolve path emits `faction_conflict`.
# ---------------------------------------------------------------------------

func test_resolve_attack_emits_faction_conflict() -> void:
	_queue_action("attack")
	conquest.resolve_actions(state, realm_control)
	assert_eq(_faction_conflicts.size(), 1)
	assert_eq(_faction_conflicts[0]["aggressor"], AGGRESSOR_ID)
	assert_eq(_faction_conflicts[0]["target"], TARGET_ID)
	# With our overpowered aggressor vs low-stability target, attack should win.
	assert_eq(_faction_conflicts[0]["outcome"], "victory")


func test_resolve_blockade_emits_faction_conflict() -> void:
	_queue_action("blockade")
	conquest.resolve_actions(state, realm_control)
	assert_eq(_faction_conflicts.size(), 1)
	assert_true(
		_faction_conflicts[0]["outcome"] in ["blockade_effective", "blockade_broken"],
		"Unexpected outcome: %s" % _faction_conflicts[0]["outcome"]
	)


func test_resolve_fortify_emits_faction_conflict() -> void:
	_queue_action("fortify")
	conquest.resolve_actions(state, realm_control)
	assert_eq(_faction_conflicts.size(), 1)
	assert_eq(_faction_conflicts[0]["outcome"], "fortified")


func test_resolve_diplomacy_emits_faction_conflict() -> void:
	_queue_action("diplomacy")
	# Relationship matrix stub so the outcome is deterministic.
	state.relationship_matrix[AGGRESSOR_ID] = {TARGET_ID: 0}
	state.relationship_matrix[TARGET_ID] = {AGGRESSOR_ID: 0}
	var aggressor: Faction = state.faction_registry[AGGRESSOR_ID]
	aggressor.political_influence = 50  # enough to succeed
	conquest.resolve_actions(state, realm_control)
	assert_eq(_faction_conflicts.size(), 1)
	assert_eq(_faction_conflicts[0]["outcome"], "improved_relations")


# ---------------------------------------------------------------------------
# Attack victory → realm control influence shift.
# ---------------------------------------------------------------------------

func test_attack_victory_adds_influence_to_aggressor_in_target_realm() -> void:
	_queue_action("attack")
	var before: float = realm_control.realm_states[REGION_ID].faction_influence.get(AGGRESSOR_ID, 0.0)
	conquest.resolve_actions(state, realm_control)
	var after: float = realm_control.realm_states[REGION_ID].faction_influence.get(AGGRESSOR_ID, 0.0)
	assert_gt(after, before, "Aggressor influence should grow on victory")


func test_attack_victory_flips_controller_emits_realm_control_changed() -> void:
	# Target's influence is high enough that a single victory's +loss doesn't
	# topple it — seed aggressor at 49 so 49 + loss > 50 flips control.
	realm_control.add_influence(REGION_ID, AGGRESSOR_ID, 49.0)
	_queue_action("attack")
	conquest.resolve_actions(state, realm_control)
	var rec := _realm_changes.filter(func(r): return r["region"] == REGION_ID)
	assert_gt(rec.size(), 0, "Expected realm_control_changed for %s" % REGION_ID)
	assert_eq(rec[0]["old"], TARGET_ID)
	assert_eq(rec[0]["new"], AGGRESSOR_ID)


func test_attack_without_realm_control_still_emits_faction_conflict() -> void:
	# Backwards compat: callers that predate 5c pass no second arg.
	_queue_action("attack")
	conquest.resolve_actions(state)
	assert_eq(_faction_conflicts.size(), 1)
	assert_eq(_realm_changes.size(), 0, "No realm_control arg → no influence shift")


# ---------------------------------------------------------------------------
# Multiple resolves emit one signal per action.
# ---------------------------------------------------------------------------

func test_multiple_actions_each_emit_their_own_signal() -> void:
	_queue_action("attack")
	_queue_action("fortify")
	_queue_action("blockade")
	conquest.resolve_actions(state, realm_control)
	assert_eq(_faction_conflicts.size(), 3)
