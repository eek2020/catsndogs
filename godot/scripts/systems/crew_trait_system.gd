## Crew trait system — loads crew trait definitions and calculates active bonuses.
## See docs/plans/crew-missions-feature-plan.md Phase 2.
class_name CrewTraitSystem
extends RefCounted

var _crew_definitions: Dictionary = {}  # crew_id -> definition dict


func _init(data_loader: DataLoader = null) -> void:
	if data_loader != null:
		load_definitions(data_loader)


func load_definitions(data_loader: DataLoader) -> void:
	var members: Array = data_loader.load_crew_members()
	for member in members:
		var cid: String = member.get("crew_id", "")
		if not cid.is_empty():
			_crew_definitions[cid] = member


func get_definition(crew_id: String) -> Dictionary:
	return _crew_definitions.get(crew_id, {})


func get_active_traits(ship: Ship) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in ship.crew:
		var defn: Dictionary = _crew_definitions.get(c.trait_id, {})
		if defn.is_empty():
			defn = _crew_definitions.get(c.crew_id, {})
		if defn.is_empty():
			continue
		var bonuses: Dictionary = defn.get("trait_bonuses", {})
		if not bonuses.is_empty():
			result.append({
				"crew_id": c.crew_id,
				"trait_id": defn.get("trait_id", ""),
				"trait_description": defn.get("trait_description", ""),
				"bonuses": bonuses,
			})
	return result


func get_bonus(ship: Ship, bonus_key: String) -> float:
	var total: float = 0.0
	for c in ship.crew:
		var defn: Dictionary = _crew_definitions.get(c.trait_id, {})
		if defn.is_empty():
			defn = _crew_definitions.get(c.crew_id, {})
		if defn.is_empty():
			continue
		var bonuses: Dictionary = defn.get("trait_bonuses", {})
		total += bonuses.get(bonus_key, 0.0)
	return total


func get_all_bonuses(ship: Ship) -> Dictionary:
	var totals: Dictionary = {}
	for c in ship.crew:
		var defn: Dictionary = _crew_definitions.get(c.trait_id, {})
		if defn.is_empty():
			defn = _crew_definitions.get(c.crew_id, {})
		if defn.is_empty():
			continue
		var bonuses: Dictionary = defn.get("trait_bonuses", {})
		for key in bonuses:
			totals[key] = totals.get(key, 0.0) + bonuses[key]
	return totals
