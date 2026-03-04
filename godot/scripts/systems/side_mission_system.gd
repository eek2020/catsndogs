## Side mission system — manages mission lifecycle, objective tracking, rewards.
## Mirrors Python systems/side_mission.py.
class_name SideMissionSystem
extends RefCounted

const DISTRESS_SPAWN_INTERVAL: float = 45.0
const MAX_ACTIVE_DISTRESS: int = 2

var data_loader: DataLoader
var _mission_templates: Array = []
var _distress_pool: Array = []
var _distress_timer: float = 0.0
var _active_distress_ids: Array[String] = []


func _init(p_data_loader: DataLoader) -> void:
	data_loader = p_data_loader


func load_missions(arc_id: String) -> void:
	_mission_templates = data_loader.load_side_missions(arc_id)


func load_distress_signals() -> void:
	_distress_pool = data_loader.load_distress_signals()


# ------------------------------------------------------------------
# Mission discovery & activation
# ------------------------------------------------------------------

func get_available_missions(game_state: GameStateData) -> Array:
	var available: Array = []
	for template in _mission_templates:
		if game_state.side_missions.has(template.mission_id):
			continue
		if _evaluate_conditions(template.trigger_conditions, game_state):
			available.append(template)
	available.sort_custom(func(a, b): return a.priority > b.priority)
	return available


func discover_mission(game_state: GameStateData, mission_id: String) -> SideMission:
	for template in _mission_templates:
		if template.mission_id == mission_id:
			var mission := SideMission.from_dict(template.to_dict())
			mission.status = "active"
			game_state.side_missions[mission.mission_id] = mission
			EventBus.mission_accepted.emit()
			return mission
	return null


func activate_mission(game_state: GameStateData, mission_id: String) -> bool:
	var mission: SideMission = game_state.side_missions.get(mission_id)
	if mission and mission.status == "available":
		mission.status = "active"
		return true
	return false


func fail_mission(game_state: GameStateData, mission_id: String) -> bool:
	var mission: SideMission = game_state.side_missions.get(mission_id)
	if mission and mission.status == "active":
		mission.status = "failed"
		EventBus.mission_failed.emit()
		return true
	return false


# ------------------------------------------------------------------
# Objective tracking
# ------------------------------------------------------------------

func check_objectives(game_state: GameStateData) -> Array[String]:
	var completed_missions: Array[String] = []
	for mid in game_state.side_missions:
		var mission: SideMission = game_state.side_missions[mid]
		if mission.status != "active":
			continue
		for obj in mission.objectives:
			if obj.completed:
				continue
			if obj.encounter_id != "" and obj.encounter_id in game_state.completed_encounters:
				obj.completed = true
		if mission.is_complete:
			mission.status = "completed"
			_apply_rewards(game_state, mission)
			completed_missions.append(mission.mission_id)
			EventBus.mission_completed.emit()
	return completed_missions


# ------------------------------------------------------------------
# Rewards
# ------------------------------------------------------------------

func _apply_rewards(game_state: GameStateData, mission: SideMission) -> void:
	for resource_key in mission.rewards:
		var amount: int = int(mission.rewards[resource_key])
		if resource_key == "crystals":
			game_state.crystal_inventory = maxi(0, game_state.crystal_inventory + amount)
		elif resource_key == "salvage":
			game_state.salvage = maxi(0, game_state.salvage + amount)
	for faction_id in mission.faction_rewards:
		var delta: int = int(mission.faction_rewards[faction_id])
		var faction: Faction = game_state.faction_registry.get(faction_id)
		if faction:
			faction.reputation_with_player = clampi(faction.reputation_with_player + delta, -100, 100)
			faction.update_diplomatic_state()
			EventBus.faction_score_changed.emit(faction_id, delta)


# ------------------------------------------------------------------
# Distress signals
# ------------------------------------------------------------------

func update_distress(dt: float, game_state: GameStateData) -> Encounter:
	if _distress_pool.is_empty():
		return null
	_active_distress_ids = _active_distress_ids.filter(
		func(eid): return eid not in game_state.completed_encounters
	)
	if _active_distress_ids.size() >= MAX_ACTIVE_DISTRESS:
		return null
	_distress_timer += dt
	if _distress_timer < DISTRESS_SPAWN_INTERVAL:
		return null
	_distress_timer = 0.0
	var candidates: Array = _distress_pool.filter(
		func(e): return e.encounter_id not in _active_distress_ids
	)
	if candidates.is_empty():
		return null
	var weights: Array = []
	var total: float = 0.0
	for e in candidates:
		var w: float = e.spawn_weight
		weights.append(w)
		total += w
	if total <= 0:
		return null
	var pick := randf() * total
	var cumulative: float = 0.0
	var chosen: Encounter = candidates[0]
	for i in range(candidates.size()):
		cumulative += weights[i]
		if pick <= cumulative:
			chosen = candidates[i]
			break
	_active_distress_ids.append(chosen.encounter_id)
	return chosen


# ------------------------------------------------------------------
# Query helpers
# ------------------------------------------------------------------

func get_active_missions(game_state: GameStateData) -> Array:
	var result: Array = []
	for m in game_state.side_missions.values():
		if m.status == "active":
			result.append(m)
	return result


func get_completed_missions(game_state: GameStateData) -> Array:
	var result: Array = []
	for m in game_state.side_missions.values():
		if m.status == "completed":
			result.append(m)
	return result


func get_mission_count(game_state: GameStateData) -> int:
	var count: int = 0
	for m in game_state.side_missions.values():
		if m.status == "active":
			count += 1
	return count


static func _evaluate_conditions(conditions: Dictionary, game_state: GameStateData) -> bool:
	for key in conditions:
		var expected = conditions[key]
		if key == "current_arc":
			if game_state.current_arc != expected:
				return false
		else:
			var actual = game_state.story_flags.get(key)
			if expected == "!null":
				if actual == null:
					return false
			else:
				if actual == null and expected is bool:
					actual = false
				if actual != expected:
					return false
	return true
