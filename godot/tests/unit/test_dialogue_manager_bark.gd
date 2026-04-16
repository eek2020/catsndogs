extends GutTest

## Regression: Mar-27 §2.5 — `_show_bark` recursion risk.
## `_show_bark` used to emit `EventBus.exploration_event` with `type: "npc_bark"`,
## and `dialogue_manager._on_exploration_event` is connected to that same
## signal. A future branch adding npc_bark handling there would have caused
## infinite recursion. The fix: emit on a dedicated `EventBus.npc_bark`
## signal so re-entry is structurally impossible.


const DialogueManagerScript := preload("res://scripts/world/dialogue_manager.gd")


var _dm: Node


func before_each() -> void:
	_dm = DialogueManagerScript.new()
	add_child_autofree(_dm)
	watch_signals(EventBus)


func test_event_bus_exposes_npc_bark_signal() -> void:
	assert_true(EventBus.has_signal("npc_bark"), "EventBus must define npc_bark signal")


func test_show_bark_emits_npc_bark_not_exploration_event() -> void:
	_dm._show_bark("Silky", "Hello, traveller.")
	assert_signal_emitted(EventBus, "npc_bark")
	assert_signal_emitted_with_parameters(EventBus, "npc_bark", ["Silky", "Hello, traveller."])
	assert_signal_not_emitted(EventBus, "exploration_event")


func test_show_bark_does_not_trigger_dialogue_event_handler() -> void:
	# Prove the structural guard: barking must not re-enter the exploration
	# event handler that _show_bark is itself called from.
	_dm._show_bark("Guard", "Move along.")
	# npc_bark fires; exploration_event stays silent, so _on_exploration_event
	# can never observe a bark and therefore can never recurse into _show_bark.
	assert_signal_emitted(EventBus, "npc_bark")
	assert_signal_not_emitted(EventBus, "exploration_event")
