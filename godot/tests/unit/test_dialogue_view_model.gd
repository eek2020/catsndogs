extends GutTest

## Regression coverage for DialogueViewModel (Sprint 6a, NEXT_STEPS.md §2).
## The VM is the only path dialogue_ui.gd and its helpers use to reach
## GameSession. We construct a SessionDouble with the same duck-typed shape
## and verify each wrapper reads / writes / delegates correctly.


class SessionDouble:
	extends RefCounted
	var game_state: GameStateData = null
	var encounter_engine: EncounterEngineDouble = null
	var crew_trait_system: CrewTraitDouble = null
	var data_loader: DataLoaderDouble = null

	var recruit_calls: Array[String] = []

	## Mirror GameSession's `_deferred_arc_check` hook. The VM's
	## `deferred_arc_check` wrapper routes to the session via Godot's native
	## `call_deferred`; on a RefCounted double the queued call fires during
	## idle processing. We can't override `call_deferred` (native Object
	## method), but we can verify the hook target exists and the VM does not
	## throw when the session has no game_state.
	func _deferred_arc_check() -> void:
		pass

	func recruit_crew_member(crew_id: String) -> void:
		recruit_calls.append(crew_id)


class EncounterEngineDouble:
	extends RefCounted
	var step_outcome_calls: Array = []
	var choice_outcome_calls: Array = []
	var complete_calls: Array = []
	var choice_outcome_return: String = "outcome-text"

	func apply_dialogue_step_outcome(gs, enc, choice) -> void:
		step_outcome_calls.append({"gs": gs, "enc": enc, "choice": choice})

	func apply_choice_outcome(gs, enc, index: int) -> String:
		choice_outcome_calls.append({"gs": gs, "enc": enc, "index": index})
		return choice_outcome_return

	func complete_encounter(gs, enc) -> void:
		complete_calls.append({"gs": gs, "enc": enc})


class CrewTraitDouble:
	extends RefCounted
	var definitions: Dictionary = {}

	func get_definition(crew_id: String) -> Dictionary:
		return definitions.get(crew_id, {})


class DataLoaderDouble:
	extends RefCounted
	var templates: Dictionary = {}
	var load_count: int = 0

	func load_ship_templates() -> Dictionary:
		load_count += 1
		return templates


func _make_empty_session() -> SessionDouble:
	var s := SessionDouble.new()
	s.encounter_engine = EncounterEngineDouble.new()
	s.crew_trait_system = CrewTraitDouble.new()
	s.data_loader = DataLoaderDouble.new()
	return s


func _make_session_with_state() -> SessionDouble:
	var s := _make_empty_session()
	var gs := GameStateData.new()
	gs.protagonist_id = "dave"
	gs.story_flags = {"crew_silky_recruited": true}
	s.game_state = gs
	return s


# ---------------------------------------------------------------------------
# has_state / state
# ---------------------------------------------------------------------------

func test_has_state_false_when_game_state_null() -> void:
	var vm := DialogueViewModel.new(_make_empty_session())
	assert_false(vm.has_state())


func test_has_state_true_when_game_state_set() -> void:
	var vm := DialogueViewModel.new(_make_session_with_state())
	assert_true(vm.has_state())


func test_has_state_false_when_session_null() -> void:
	var vm := DialogueViewModel.new(null)
	assert_false(vm.has_state())


# ---------------------------------------------------------------------------
# protagonist_id — default fallback, empty fallback, normal path
# ---------------------------------------------------------------------------

func test_protagonist_id_defaults_to_aristotle_when_no_state() -> void:
	var vm := DialogueViewModel.new(_make_empty_session())
	assert_eq(vm.protagonist_id(), "aristotle")


func test_protagonist_id_falls_back_to_aristotle_when_empty() -> void:
	var session := _make_session_with_state()
	session.game_state.protagonist_id = ""
	var vm := DialogueViewModel.new(session)
	assert_eq(vm.protagonist_id(), "aristotle")


func test_protagonist_id_returns_game_state_value() -> void:
	var vm := DialogueViewModel.new(_make_session_with_state())
	assert_eq(vm.protagonist_id(), "dave")


# ---------------------------------------------------------------------------
# story_flag
# ---------------------------------------------------------------------------

func test_story_flag_false_when_no_state() -> void:
	var vm := DialogueViewModel.new(_make_empty_session())
	assert_false(vm.story_flag("crew_silky_recruited"))


func test_story_flag_reads_from_game_state() -> void:
	var vm := DialogueViewModel.new(_make_session_with_state())
	assert_true(vm.story_flag("crew_silky_recruited"))
	assert_false(vm.story_flag("crew_dave_recruited"))


# ---------------------------------------------------------------------------
# Encounter engine wrappers
# ---------------------------------------------------------------------------

func test_apply_step_outcome_delegates_with_game_state() -> void:
	var session := _make_session_with_state()
	var vm := DialogueViewModel.new(session)
	var encounter: Encounter = Encounter.new()
	vm.apply_step_outcome(encounter, "choice-obj")
	assert_eq(session.encounter_engine.step_outcome_calls.size(), 1)
	var entry: Dictionary = session.encounter_engine.step_outcome_calls[0]
	assert_eq(entry["gs"], session.game_state)
	assert_eq(entry["enc"], encounter)
	assert_eq(entry["choice"], "choice-obj")


func test_apply_step_outcome_noop_without_state() -> void:
	var session := _make_empty_session()
	var vm := DialogueViewModel.new(session)
	vm.apply_step_outcome(Encounter.new(), "x")
	assert_eq(session.encounter_engine.step_outcome_calls.size(), 0)


func test_apply_choice_outcome_returns_engine_string() -> void:
	var session := _make_session_with_state()
	session.encounter_engine.choice_outcome_return = "You chose boldly."
	var vm := DialogueViewModel.new(session)
	var outcome := vm.apply_choice_outcome(Encounter.new(), 2)
	assert_eq(outcome, "You chose boldly.")
	assert_eq(session.encounter_engine.choice_outcome_calls[0]["index"], 2)


func test_apply_choice_outcome_empty_without_state() -> void:
	var vm := DialogueViewModel.new(_make_empty_session())
	assert_eq(vm.apply_choice_outcome(Encounter.new(), 0), "")


func test_complete_encounter_delegates_with_game_state() -> void:
	var session := _make_session_with_state()
	var vm := DialogueViewModel.new(session)
	var encounter: Encounter = Encounter.new()
	vm.complete_encounter(encounter)
	assert_eq(session.encounter_engine.complete_calls.size(), 1)
	assert_eq(session.encounter_engine.complete_calls[0]["enc"], encounter)


func test_complete_encounter_noop_without_state() -> void:
	var session := _make_empty_session()
	var vm := DialogueViewModel.new(session)
	vm.complete_encounter(Encounter.new())
	assert_eq(session.encounter_engine.complete_calls.size(), 0)


# ---------------------------------------------------------------------------
# Crew
# ---------------------------------------------------------------------------

func test_recruit_crew_calls_session() -> void:
	var session := _make_session_with_state()
	var vm := DialogueViewModel.new(session)
	vm.recruit_crew("silky")
	assert_eq(session.recruit_calls, ["silky"])


func test_recruit_crew_noop_when_session_null() -> void:
	var vm := DialogueViewModel.new(null)
	vm.recruit_crew("silky")  # must not throw
	pass_test("recruit_crew with null session did not throw")


func test_crew_definition_returns_empty_when_missing() -> void:
	var vm := DialogueViewModel.new(_make_session_with_state())
	assert_eq(vm.crew_definition("unknown"), {})


func test_crew_definition_returns_system_value() -> void:
	var session := _make_session_with_state()
	session.crew_trait_system.definitions = {"silky": {"name": "Silky", "role": "engineer"}}
	var vm := DialogueViewModel.new(session)
	var defn := vm.crew_definition("silky")
	assert_eq(defn.get("name"), "Silky")


func test_crew_definition_empty_when_system_null() -> void:
	var session := _make_session_with_state()
	session.crew_trait_system = null
	var vm := DialogueViewModel.new(session)
	assert_eq(vm.crew_definition("silky"), {})


# ---------------------------------------------------------------------------
# Combat transition wrappers
# ---------------------------------------------------------------------------

func test_ship_templates_returns_loader_value() -> void:
	var session := _make_session_with_state()
	session.data_loader.templates = {"league_cruiser": {"max_hull": 80}}
	var vm := DialogueViewModel.new(session)
	var templates := vm.ship_templates()
	assert_eq(templates.size(), 1)
	assert_eq(session.data_loader.load_count, 1)


func test_ship_templates_empty_when_loader_null() -> void:
	var session := _make_session_with_state()
	session.data_loader = null
	var vm := DialogueViewModel.new(session)
	assert_eq(vm.ship_templates(), {})


func test_faction_registry_empty_without_state() -> void:
	var vm := DialogueViewModel.new(_make_empty_session())
	assert_eq(vm.faction_registry(), {})


func test_faction_registry_returns_game_state_dict() -> void:
	var session := _make_session_with_state()
	var faction: Faction = Faction.new()
	faction.faction_id = "canis_league"
	session.game_state.faction_registry = {"canis_league": faction}
	var vm := DialogueViewModel.new(session)
	assert_eq(vm.faction_registry().size(), 1)
	assert_eq(vm.faction("canis_league"), faction)


func test_faction_null_without_state() -> void:
	var vm := DialogueViewModel.new(_make_empty_session())
	assert_null(vm.faction("canis_league"))


func test_player_ship_null_without_state() -> void:
	var vm := DialogueViewModel.new(_make_empty_session())
	assert_null(vm.player_ship())


func test_player_ship_returns_game_state_ship() -> void:
	var session := _make_session_with_state()
	var ship := Ship.new()
	session.game_state.player_ship = ship
	var vm := DialogueViewModel.new(session)
	assert_eq(vm.player_ship(), ship)


# ---------------------------------------------------------------------------
# Arc deferred call
# ---------------------------------------------------------------------------

func test_deferred_arc_check_does_not_throw_with_state() -> void:
	var session := _make_session_with_state()
	var vm := DialogueViewModel.new(session)
	vm.deferred_arc_check()  # schedules _deferred_arc_check via call_deferred
	pass_test("deferred_arc_check with live session returned")


func test_deferred_arc_check_noop_when_session_null() -> void:
	var vm := DialogueViewModel.new(null)
	vm.deferred_arc_check()  # must not throw
	pass_test("deferred_arc_check with null session did not throw")
