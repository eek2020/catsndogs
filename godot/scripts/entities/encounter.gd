## Encounter entity — triggers, choices, outcomes.
## Mirrors Python entities/encounter.py.
class_name Encounter
extends Resource

@export var encounter_id: String = ""
@export var encounter_type: String = ""  # "combat", "trade", "diplomatic", "exploration"
@export var title: String = ""
@export var description: String = ""
@export var arc_id: String = ""
@export var location: String = ""
@export var trigger_conditions: Dictionary = {}
@export var npc_ids: Array[String] = []
@export var choices: Array = []  # Array of EncounterChoice
@export var priority: int = 0
@export var repeatable: bool = false
@export var spawn_weight: float = 1.0
@export var mission_type: String = ""
@export var crew_member_id: String = ""
@export var dialogue_steps: Array = []  # Array of DialogueStep


## Returns true when this encounter uses multi-step dialogue.
func has_dialogue_steps() -> bool:
	return dialogue_steps.size() > 0


static func from_dict(data: Dictionary) -> Encounter:
	var e := Encounter.new()
	e.encounter_id = data.get("encounter_id", "")
	e.encounter_type = data.get("encounter_type", "")
	e.title = data.get("title", "")
	e.description = data.get("description", "")
	e.arc_id = data.get("arc_id", "")
	e.location = data.get("location", "")
	e.trigger_conditions = data.get("trigger_conditions", {})
	e.npc_ids = Array(data.get("npc_ids", []), TYPE_STRING, "", null)
	for c_data in data.get("choices", []):
		e.choices.append(EncounterChoice.from_dict(c_data))
	e.priority = data.get("priority", 0)
	e.repeatable = data.get("repeatable", false)
	e.spawn_weight = data.get("spawn_weight", 1.0)
	e.mission_type = data.get("mission_type", "")
	e.crew_member_id = data.get("crew_member_id", "")
	for s_data in data.get("dialogue_steps", []):
		e.dialogue_steps.append(DialogueStep.from_dict(s_data))
	return e


## -----------------------------------------------------------------------
## EncounterOutcome
## -----------------------------------------------------------------------
class EncounterOutcome extends Resource:
	@export var description: String = ""
	@export var faction_changes: Dictionary = {}
	@export var resource_changes: Dictionary = {}
	@export var story_flags_set: Array[String] = []
	@export var story_flags_cleared: Array[String] = []
	@export var trigger_encounter_id: String = ""

	static func from_dict(data: Dictionary) -> EncounterOutcome:
		var o := EncounterOutcome.new()
		o.description = data.get("description", "")
		o.faction_changes = data.get("faction_changes", {})
		o.resource_changes = data.get("resource_changes", {})
		o.story_flags_set = Array(data.get("story_flags_set", []), TYPE_STRING, "", null)
		o.story_flags_cleared = Array(data.get("story_flags_cleared", []), TYPE_STRING, "", null)
		o.trigger_encounter_id = data.get("trigger_encounter_id", "")
		return o


## -----------------------------------------------------------------------
## EncounterChoice
## -----------------------------------------------------------------------
class EncounterChoice extends Resource:
	@export var choice_id: String = ""
	@export var text: String = ""
	@export var conditions: Dictionary = {}
	@export var outcome: EncounterOutcome = null
	@export var outcome_weight: float = 0.0

	static func from_dict(data: Dictionary) -> EncounterChoice:
		var c := EncounterChoice.new()
		c.choice_id = data.get("choice_id", "")
		c.text = data.get("text", "")
		c.conditions = data.get("conditions", {})
		c.outcome = EncounterOutcome.from_dict(data.get("outcome", {}))
		c.outcome_weight = data.get("outcome_weight", 0.0)
		return c


## -----------------------------------------------------------------------
## DialogueStepChoice — a player choice within a dialogue step.
## -----------------------------------------------------------------------
class DialogueStepChoice extends Resource:
	@export var choice_id: String = ""
	@export var text: String = ""
	@export var next_step: String = ""  # step_id to jump to
	@export var conditions: Dictionary = {}
	@export var outcome: EncounterOutcome = null

	static func from_dict(data: Dictionary) -> DialogueStepChoice:
		var c := DialogueStepChoice.new()
		c.choice_id = data.get("choice_id", "")
		c.text = data.get("text", "")
		c.next_step = data.get("next_step", "")
		c.conditions = data.get("conditions", {})
		c.outcome = EncounterOutcome.from_dict(data.get("outcome", {}))
		return c


## -----------------------------------------------------------------------
## DialogueStep — one line in a multi-step conversation.
## -----------------------------------------------------------------------
class DialogueStep extends Resource:
	@export var step_id: String = ""       # branch label (optional)
	@export var speaker: String = ""       # character id for portrait lookup
	@export var text: String = ""          # dialogue line
	@export var choices: Array = []        # Array of DialogueStepChoice
	@export var end: bool = false          # true = final step, close dialogue
	@export var start_combat: bool = false # true = transition to combat

	static func from_dict(data: Dictionary) -> DialogueStep:
		var s := DialogueStep.new()
		s.step_id = data.get("step_id", "")
		s.speaker = data.get("speaker", "")
		s.text = data.get("text", "")
		for c_data in data.get("choices", []):
			s.choices.append(DialogueStepChoice.from_dict(c_data))
		s.end = data.get("end", false)
		s.start_combat = data.get("start_combat", false)
		return s
