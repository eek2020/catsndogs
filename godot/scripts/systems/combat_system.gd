## Combat system — pure logic: damage model, ship combat data, combat log.
## Mirrors Python systems/combat.py.
class_name CombatSystem
extends RefCounted


## Simplified ship representation for combat.
class CombatShip extends Resource:
	@export var ship_name: String = ""
	@export var faction_id: String = ""
	@export var speed: int = 5
	@export var armour: int = 5
	@export var firepower: int = 5
	@export var current_hull: int = 100
	@export var max_hull: int = 100
	@export var is_player: bool = false
	@export var ship_template_id: String = ""

	static func from_game_ship(ship: Ship, p_is_player: bool = false) -> CombatShip:
		var cs := CombatShip.new()
		cs.ship_name = ship.ship_name
		cs.faction_id = ship.faction_id
		cs.speed = ship.speed
		cs.armour = ship.armour
		cs.firepower = ship.firepower
		cs.current_hull = ship.current_hull
		cs.max_hull = ship.max_hull
		cs.is_player = p_is_player
		cs.ship_template_id = ship.ship_class
		return cs

	static func from_template(template: Dictionary, p_name: String, p_faction_id: String) -> CombatShip:
		var cs := CombatShip.new()
		var stats: Dictionary = template.get("base_stats", {})
		cs.ship_name = p_name
		cs.faction_id = p_faction_id
		cs.speed = stats.get("speed", 5)
		cs.armour = stats.get("armour", 5)
		cs.firepower = stats.get("firepower", 5)
		cs.current_hull = template.get("max_hull", 100)
		cs.max_hull = template.get("max_hull", 100)
		cs.ship_template_id = template.get("template_id", "")
		return cs


## Rolling combat log with max 8 entries.
class CombatLog extends RefCounted:
	var entries: Array[String] = []

	func add(text: String) -> void:
		entries.append(text)
		if entries.size() > 8:
			entries.pop_front()


## Damage = attacker_firepower - defender_armour, min 1, with +/-20% variance.
static func calculate_damage(attacker_fp: int, defender_armour: int) -> int:
	var base := maxi(1, attacker_fp - defender_armour)
	var variance := randf_range(0.8, 1.2)
	return maxi(1, int(base * variance))


## Dodge probability based on speed: speed 10 -> 40%, speed 1 -> 4%.
static func dodge_chance(defender_speed: int) -> float:
	return minf(0.45, defender_speed * 0.04)
