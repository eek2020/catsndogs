## Centralised condition evaluator — single source of truth for checking
## trigger conditions against game state.
##
## Used by EncounterEngine, SideMissionSystem, and any future system that
## needs to gate content on story flags, stats, karma, or arc progression.
## Replaces duplicated _evaluate_conditions() methods (Code Review Issue #2).
class_name ConditionEvaluator
extends RefCounted


## Evaluate a dictionary of trigger conditions against the current game state.
## Returns true only if ALL conditions are satisfied.
##
## Supported condition keys:
##   "current_arc"  — must match game_state.current_arc
##   "highest_stat" — player's dominant stat must match the expected value
##   "min_<stat>"   — player stat must meet or exceed the threshold
##   "karma_tier"   — current karma tier must match
##   <any other>    — treated as a story_flags lookup
##     Special value "!null" means the flag must exist (non-null).
##     Bool flags default to false when absent.
static func evaluate(conditions: Dictionary, game_state: GameStateData) -> bool:
	for key in conditions:
		var expected = conditions[key]
		if key == "current_arc":
			if game_state.current_arc != expected:
				return false
		elif key == "highest_stat":
			if game_state.player_character == null:
				return false
			if StatEvaluator.get_highest_stat(game_state.player_character) != expected:
				return false
		elif key.begins_with("min_"):
			if game_state.player_character == null:
				return false
			var stat_name: String = key.substr(4)
			if not StatEvaluator.check_threshold(game_state.player_character, stat_name, int(expected)):
				return false
		elif key == "karma_tier":
			if GameSession.karma_system != null:
				if GameSession.karma_system.get_tier(game_state) != expected:
					return false
		else:
			var actual = game_state.story_flags.get(key)
			if expected is String and expected == "!null":
				if actual == null:
					return false
			else:
				if actual == null and expected is bool:
					actual = false
				if actual != expected:
					return false
	return true
