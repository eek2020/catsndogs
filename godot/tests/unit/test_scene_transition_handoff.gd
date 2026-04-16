extends GutTest

## Regression: Mar-27 §2.3 — scene_transition tween after scene change.
## `world/scene_transition.gd` used to keep awaiting `process_frame` on itself
## (an Area2D attached to the outgoing scene) after `change_scene_to_file`,
## meaning the coroutine tried to resume on a freed node. The fix moves the
## post-change half into `GameSession.complete_scene_transition`, which is
## a persistent autoload.
##
## These tests pin the structural contract:
##   1. GameSession exposes `complete_scene_transition`.
##   2. SceneTransition delegates to it instead of awaiting on self.
##   3. `complete_scene_transition` is tolerant of missing players / overlays
##      so it never crashes when called against an unusual scene shape.


const SCENE_TRANSITION_SOURCE := "res://scripts/world/scene_transition.gd"


func test_game_session_exposes_complete_scene_transition() -> void:
	assert_true(GameSession.has_method("complete_scene_transition"),
		"GameSession must own the post-scene-change handoff")


func test_scene_transition_source_delegates_to_game_session() -> void:
	# Guard the structural contract by inspecting the source — if a future
	# refactor reintroduces awaits-after-change_scene_to_file on self, this
	# test points the finger at the right place to look.
	var file := FileAccess.open(SCENE_TRANSITION_SOURCE, FileAccess.READ)
	assert_not_null(file, "scene_transition.gd must be readable at %s" % SCENE_TRANSITION_SOURCE)
	var source: String = file.get_as_text()
	file.close()
	assert_true(source.contains("GameSession.complete_scene_transition"),
		"scene_transition.gd must hand off to GameSession.complete_scene_transition")
	# The old pattern awaited process_frame twice on self after change_scene_to_file.
	var change_idx: int = source.find("change_scene_to_file")
	assert_true(change_idx >= 0, "scene_transition.gd must call change_scene_to_file")
	var tail: String = source.substr(change_idx)
	assert_false(tail.contains("await tree.process_frame"),
		"scene_transition.gd must not await process_frame on self after the scene swap")


func test_complete_scene_transition_tolerates_missing_player() -> void:
	# There is no player node in the test tree; the call must not crash and
	# must not touch return-position state.
	GameSession.clear_return_position()
	GameSession.complete_scene_transition(Vector2(10, 20), "right", 0.1)
	# Just reaching here without a crash is the assertion — GUT will log
	# errors if the call threw. Sanity-check return state is untouched.
	assert_false(GameSession.has_return_position())


func test_complete_scene_transition_tolerates_null_tree_scene() -> void:
	# If for some reason tree.current_scene is null (mid-swap), the fade-in
	# helper must early-return rather than dereference a null scene.
	GameSession._fade_in_transition_overlay(get_tree(), null, 0.25)
	GameSession._position_player_after_transition(null, Vector2.ZERO, "down")
	pass_test("complete_scene_transition helpers handle null targets without crashing")
