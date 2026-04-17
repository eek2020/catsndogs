## DialogueViewModel — narrow adapter between GameSession and dialogue_ui.gd.
## The dialogue screen and its helpers (PortraitManager, CombatTransition) call
## this VM; the VM is the only code path that touches GameSession. Tests
## construct a VM with a session double to exercise the UI without the autoload.
## Pattern from CODE_REVIEW.md §2.1.
class_name DialogueViewModel
extends RefCounted


const DEFAULT_PROTAGONIST_ID: String = "aristotle"


var _session  # GameSession autoload, or a test double with the same shape


func _init(session) -> void:
	_session = session


# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------

func has_state() -> bool:
	return _session != null and _session.game_state != null


func state() -> GameStateData:
	return _session.game_state


func protagonist_id() -> String:
	if not has_state():
		return DEFAULT_PROTAGONIST_ID
	var pid: String = _session.game_state.protagonist_id
	if pid.is_empty():
		return DEFAULT_PROTAGONIST_ID
	return pid


func story_flag(flag_name: String) -> bool:
	if not has_state():
		return false
	return _session.game_state.story_flags.get(flag_name, false)


# ---------------------------------------------------------------------------
# Encounter engine
# ---------------------------------------------------------------------------

func apply_step_outcome(encounter, choice) -> void:
	if not has_state():
		return
	_session.encounter_engine.apply_dialogue_step_outcome(
		_session.game_state, encounter, choice
	)


func apply_choice_outcome(encounter, choice_index: int) -> String:
	if not has_state():
		return ""
	return _session.encounter_engine.apply_choice_outcome(
		_session.game_state, encounter, choice_index
	)


func complete_encounter(encounter) -> void:
	if not has_state():
		return
	_session.encounter_engine.complete_encounter(_session.game_state, encounter)


# ---------------------------------------------------------------------------
# Crew
# ---------------------------------------------------------------------------

func recruit_crew(crew_id: String) -> void:
	if _session == null:
		return
	_session.recruit_crew_member(crew_id)


func crew_definition(crew_id: String) -> Dictionary:
	if _session == null or _session.crew_trait_system == null:
		return {}
	return _session.crew_trait_system.get_definition(crew_id)


# ---------------------------------------------------------------------------
# Combat transition
# ---------------------------------------------------------------------------

func ship_templates() -> Dictionary:
	if _session == null or _session.data_loader == null:
		return {}
	return _session.data_loader.load_ship_templates()


func faction(faction_id: String):
	if not has_state():
		return null
	return _session.game_state.faction_registry.get(faction_id)


func faction_registry() -> Dictionary:
	if not has_state():
		return {}
	return _session.game_state.faction_registry


func player_ship():
	if not has_state():
		return null
	return _session.game_state.player_ship


# ---------------------------------------------------------------------------
# Arc
# ---------------------------------------------------------------------------

func deferred_arc_check() -> void:
	if _session == null:
		return
	_session.call_deferred("_deferred_arc_check")
