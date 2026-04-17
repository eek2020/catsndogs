extends GutTest

## Regression: Sprint 5c part 2 — persistent objective surface (CODE_REVIEW §4.6
## / §5.3). NarrativeSystem.get_arc_objective prefers the arc's `objective_text`
## when provided, falls back to the arc `theme`, and returns "" when neither is
## present or the arc is unknown.


class _FakeDataLoader:
	extends RefCounted

	var arcs: Array = []

	func load_arc_definitions() -> Array:
		return arcs


func _make_system(arcs: Array) -> NarrativeSystem:
	var loader := _FakeDataLoader.new()
	loader.arcs = arcs
	var sys := NarrativeSystem.new(loader)
	sys.load_arcs()
	return sys


func _make_state(arc_id: String) -> GameStateData:
	var gs := GameStateData.new()
	gs.current_arc = arc_id
	return gs


func test_objective_text_takes_precedence_when_present() -> void:
	var sys := _make_system([{
		"arc_id": "arc_1",
		"theme": "Origin — building the empire",
		"objective_text": "Find the first crystal",
	}])
	assert_eq(sys.get_arc_objective(_make_state("arc_1")), "Find the first crystal")


func test_falls_back_to_theme_when_objective_missing() -> void:
	var sys := _make_system([{
		"arc_id": "arc_2",
		"theme": "Rising threats from the outer realms",
	}])
	assert_eq(sys.get_arc_objective(_make_state("arc_2")),
		"Rising threats from the outer realms")


func test_returns_empty_string_when_both_missing() -> void:
	var sys := _make_system([{"arc_id": "arc_3"}])
	assert_eq(sys.get_arc_objective(_make_state("arc_3")), "")


func test_returns_empty_string_when_arc_unknown() -> void:
	var sys := _make_system([{"arc_id": "arc_1", "theme": "hello"}])
	assert_eq(sys.get_arc_objective(_make_state("unknown_arc")), "")
