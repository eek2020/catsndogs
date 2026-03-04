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
