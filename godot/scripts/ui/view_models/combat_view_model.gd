## CombatViewModel — narrow adapter between GameSession and combat_ui.gd.
## Same pattern as NavigationViewModel (CODE_REVIEW.md §2.1). combat_ui.gd
## reaches GameSession only through this VM so the screen can be exercised
## without the autoload (tests inject a session double).
class_name CombatViewModel
extends RefCounted

var _session  # GameSession autoload, or a test double with the same shape


func _init(session) -> void:
	_session = session


# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------

func has_state() -> bool:
	return _session.game_state != null


## Write the final combat hull value back onto the persistent player ship.
## No-op when there is no game state or player ship (e.g. standalone tests).
func sync_player_hull(hull: int) -> void:
	if _session.game_state == null:
		return
	if _session.game_state.player_ship == null:
		return
	_session.game_state.player_ship.current_hull = hull


## Award combat loot. Silent no-op when no game state is present so the
## orchestrator can call this unconditionally on victory.
func apply_victory_loot(crystals: int, salvage: int) -> void:
	if _session.game_state == null:
		return
	_session.game_state.crystal_inventory += crystals
	_session.game_state.salvage += salvage
