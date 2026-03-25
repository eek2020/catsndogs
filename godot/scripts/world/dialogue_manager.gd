## World dialogue manager — bridges NPC interactions to the existing dialogue UI.
## Listens for exploration_event signals with type "npc_dialogue" and triggers
## the dialogue UI with the appropriate encounter data.
extends Node

const DIALOGUE_DIR := "res://data/dialogue/"

var _dialogue_cache: Dictionary = {}


func _ready() -> void:
	EventBus.exploration_event.connect(_on_exploration_event)


func _on_exploration_event(event_data: Dictionary) -> void:
	var event_type: String = event_data.get("type", "")
	if event_type != "npc_dialogue":
		return

	var dialogue_id: String = event_data.get("dialogue_id", "")
	var npc_id: String = event_data.get("npc_id", "")
	var npc_name: String = event_data.get("npc_name", "")
	var faction_id: String = event_data.get("faction_id", "")

	if dialogue_id.is_empty():
		# No dialogue assigned — emit a generic bark
		_show_bark(npc_name, _get_generic_bark(faction_id))
		return

	var dialogue_data: Dictionary = _load_dialogue(dialogue_id)
	if dialogue_data.is_empty():
		_show_bark(npc_name, "...")
		return

	# Build an Encounter from the dialogue data and show it via dialogue UI
	_trigger_dialogue_encounter(dialogue_data, npc_id, npc_name)


func _load_dialogue(dialogue_id: String) -> Dictionary:
	if _dialogue_cache.has(dialogue_id):
		return _dialogue_cache[dialogue_id]

	var path: String = DIALOGUE_DIR + dialogue_id + ".json"
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return {}

	var data: Dictionary = json.data if json.data is Dictionary else {}
	_dialogue_cache[dialogue_id] = data
	return data


func _trigger_dialogue_encounter(dialogue_data: Dictionary, npc_id: String, npc_name: String) -> void:
	# Check if the main scene has a push_overlay method for showing dialogue
	var main: Node = get_tree().current_scene
	if main == null or not main.has_method("push_overlay"):
		return

	# Create a temporary Encounter from the dialogue data
	var enc := Encounter.new()
	enc.encounter_id = dialogue_data.get("encounter_id", npc_id + "_dialogue")
	enc.title = dialogue_data.get("title", npc_name)
	enc.description = dialogue_data.get("description", "")
	var resolved_npc: String = npc_id if dialogue_data.get("npc_id", "").is_empty() else dialogue_data.get("npc_id", "")
	if not resolved_npc.is_empty():
		enc.npc_ids = [resolved_npc]

	# Support dialogue_steps if present
	if dialogue_data.has("dialogue_steps"):
		enc.dialogue_steps = []
		for step_data in dialogue_data["dialogue_steps"]:
			var step := Encounter.DialogueStep.new()
			step.step_id = step_data.get("step_id", "")
			step.speaker = step_data.get("speaker", "")
			step.text = step_data.get("text", "")
			step.choices = []
			for choice_data in step_data.get("choices", []):
				var choice := Encounter.DialogueStepChoice.new()
				choice.text = choice_data.get("text", choice_data.get("label", ""))
				choice.next_step = choice_data.get("next_step", "")
				choice.choice_id = choice_data.get("choice_id", "")
				step.choices.append(choice)
			enc.dialogue_steps.append(step)

	# Choices fallback
	if enc.dialogue_steps.is_empty() and dialogue_data.has("choices"):
		enc.choices = []
		for choice_data in dialogue_data["choices"]:
			var choice := Encounter.EncounterChoice.new()
			choice.text = choice_data.get("text", choice_data.get("label", ""))
			choice.choice_id = choice_data.get("choice_id", "")
			enc.choices.append(choice)

	# Show via the existing dialogue overlay
	var dialogue_scene: PackedScene = load("res://scenes/ui/dialogue_ui.tscn")
	if dialogue_scene == null:
		return
	var dialogue_instance: Control = dialogue_scene.instantiate()
	dialogue_instance.setup(enc)
	main.push_overlay(dialogue_instance)


func _show_bark(npc_name: String, text: String) -> void:
	# Simple bark — just emit an event for any listening UI
	EventBus.exploration_event.emit({
		"type": "npc_bark",
		"npc_name": npc_name,
		"text": text,
	})


func _get_generic_bark(faction_id: String) -> String:
	# Faction-aware generic greetings
	if GameSession.game_state == null:
		return "Hello, traveller."

	var rep: int = 0
	var faction_reg: Dictionary = GameSession.game_state.faction_registry
	if faction_reg.has(faction_id):
		rep = faction_reg[faction_id].get("reputation", 0)

	if rep > 50:
		return "Welcome, friend! Good to see you."
	elif rep < -20:
		return "You're not welcome here. Move along."
	else:
		return "Hello, traveller. Safe skies."
