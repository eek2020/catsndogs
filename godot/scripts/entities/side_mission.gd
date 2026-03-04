## Side mission entity — optional quests with tracking and rewards.
## Mirrors Python entities/side_mission.py.
class_name SideMission
extends Resource

@export var mission_id: String = ""
@export var mission_type: String = ""  # "bounty", "escort", "retrieval", "distress_signal"
@export var title: String = ""
@export var description: String = ""
@export var region: String = ""
@export var status: String = "available"  # "available", "active", "completed", "failed"
@export var objectives: Array = []  # Array of MissionObjective
@export var rewards: Dictionary = {}
@export var faction_rewards: Dictionary = {}
@export var trigger_conditions: Dictionary = {}
@export var discovery_encounter_id: String = ""
@export var priority: int = 0


var is_complete: bool:
	get:
		if objectives.is_empty():
			return false
		for o in objectives:
			if not o.completed:
				return false
		return true


func to_dict() -> Dictionary:
	var obj_arr: Array = []
	for o in objectives:
		obj_arr.append(o.to_dict())
	return {
		"mission_id": mission_id,
		"mission_type": mission_type,
		"title": title,
		"description": description,
		"region": region,
		"status": status,
		"objectives": obj_arr,
		"rewards": rewards,
		"faction_rewards": faction_rewards,
		"trigger_conditions": trigger_conditions,
		"discovery_encounter_id": discovery_encounter_id,
		"priority": priority,
	}


static func from_dict(data: Dictionary) -> SideMission:
	var m := SideMission.new()
	m.mission_id = data.get("mission_id", "")
	m.mission_type = data.get("mission_type", "")
	m.title = data.get("title", "")
	m.description = data.get("description", "")
	m.region = data.get("region", "")
	m.status = data.get("status", "available")
	for o_data in data.get("objectives", []):
		m.objectives.append(MissionObjective.from_dict(o_data))
	m.rewards = data.get("rewards", {})
	m.faction_rewards = data.get("faction_rewards", {})
	m.trigger_conditions = data.get("trigger_conditions", {})
	m.discovery_encounter_id = data.get("discovery_encounter_id", "")
	m.priority = data.get("priority", 0)
	return m


## -----------------------------------------------------------------------
## MissionObjective inner resource
## -----------------------------------------------------------------------
class MissionObjective extends Resource:
	@export var objective_id: String = ""
	@export var description: String = ""
	@export var completed: bool = false
	@export var encounter_id: String = ""

	func to_dict() -> Dictionary:
		return {
			"objective_id": objective_id,
			"description": description,
			"completed": completed,
			"encounter_id": encounter_id,
		}

	static func from_dict(data: Dictionary) -> MissionObjective:
		var o := MissionObjective.new()
		o.objective_id = data.get("objective_id", "")
		o.description = data.get("description", "")
		o.completed = data.get("completed", false)
		o.encounter_id = data.get("encounter_id", "")
		return o
