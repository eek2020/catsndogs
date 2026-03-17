## Crew morale system — tracks crew satisfaction and its effects on gameplay.
## Mirrors Python systems/crew_morale.py.
class_name CrewMoraleSystem
extends RefCounted

const MUTINY_THRESHOLD: int = 20
const LOW_THRESHOLD: int = 40
const NEUTRAL_THRESHOLD: int = 60
const HIGH_THRESHOLD: int = 80


static func morale_label(value: int) -> String:
	if value <= MUTINY_THRESHOLD:
		return "MUTINY"
	elif value <= LOW_THRESHOLD:
		return "DISGRUNTLED"
	elif value <= NEUTRAL_THRESHOLD:
		return "STEADY"
	elif value <= HIGH_THRESHOLD:
		return "CONTENT"
	else:
		return "INSPIRED"


func get_average_morale(game_state: GameStateData) -> int:
	var crew: Array = game_state.player_ship.crew
	if crew.is_empty():
		return 100
	var total: int = 0
	for c in crew:
		total += c.morale
	return total / crew.size()


func get_morale_status(game_state: GameStateData) -> String:
	return morale_label(get_average_morale(game_state))


func get_crew_by_morale(game_state: GameStateData) -> Array:
	var result: Array = []
	for c in game_state.player_ship.crew:
		result.append([c.crew_name, c.morale, morale_label(c.morale)])
	result.sort_custom(func(a, b): return a[1] < b[1])
	return result


func change_crew_morale(
	game_state: GameStateData,
	delta: int,
	crew_id: String = "",
) -> void:
	var crew: Array = game_state.player_ship.crew
	for member in crew:
		if crew_id != "" and member.crew_id != crew_id:
			continue
		var old_morale: int = member.morale
		var effective_delta := int(delta * (1.0 + member.morale_modifier / 10.0))
		member.morale = clampi(member.morale + effective_delta, 0, 100)
		if old_morale > MUTINY_THRESHOLD and member.morale <= MUTINY_THRESHOLD:
			print("Crew mutiny risk: %s (morale %d)" % [member.crew_name, member.morale])


func get_combat_modifier(game_state: GameStateData) -> float:
	var avg := get_average_morale(game_state)
	if avg <= MUTINY_THRESHOLD:
		return 0.7
	elif avg <= LOW_THRESHOLD:
		return 0.85
	elif avg <= NEUTRAL_THRESHOLD:
		return 1.0
	elif avg <= HIGH_THRESHOLD:
		return 1.1
	else:
		return 1.2


func get_trade_modifier(game_state: GameStateData) -> float:
	var avg := get_average_morale(game_state)
	if avg <= MUTINY_THRESHOLD:
		return 1.1
	elif avg <= LOW_THRESHOLD:
		return 1.05
	elif avg <= NEUTRAL_THRESHOLD:
		return 1.0
	elif avg <= HIGH_THRESHOLD:
		return 0.95
	else:
		return 0.9


func on_combat_victory(game_state: GameStateData) -> void:
	change_crew_morale(game_state, 10)


func on_combat_defeat(game_state: GameStateData) -> void:
	change_crew_morale(game_state, -15)


func on_trade_completed(game_state: GameStateData, profit: int) -> void:
	if profit > 0:
		change_crew_morale(game_state, 5)
	elif profit < 0:
		change_crew_morale(game_state, -3)


func on_idle_tick(game_state: GameStateData) -> void:
	change_crew_morale(game_state, -1)


func check_faction_loyalty(game_state: GameStateData) -> Array[String]:
	var conflicts: Array[String] = []
	for member in game_state.player_ship.crew:
		var faction: Faction = game_state.faction_registry.get(member.faction_origin)
		if faction and faction.reputation_with_player <= -50:
			conflicts.append(member.crew_id)
	return conflicts


func apply_faction_loyalty_effects(game_state: GameStateData) -> void:
	for member in game_state.player_ship.crew:
		var faction: Faction = game_state.faction_registry.get(member.faction_origin)
		if faction and faction.reputation_with_player <= -50:
			change_crew_morale(game_state, -5, member.crew_id)
