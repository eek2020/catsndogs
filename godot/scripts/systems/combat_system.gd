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
##
## Bonuses are passed explicitly so this function has no hidden dependencies
## on autoloads (Issue #5). Callers (e.g. combat_ui.gd) extract the values
## from GameSession before calling.
##
## [param crew_bonus]      — crew trait firepower bonus (0.0–1.0).
## [param combat_skill]    — player character combat_skill stat (0–10).
## [param crit_chance]     — crew trait critical-hit chance (0.0–1.0).
## [param morale_modifier] — crew morale multiplier on outgoing firepower
##   (0.7 at MUTINY, 1.0 neutral, 1.2 at INSPIRED). Callers pass
##   `GameSession.crew_morale.get_combat_modifier(game_state)` or 1.0.
static func calculate_damage(
	attacker_fp: int,
	defender_armour: int,
	crew_bonus: float = 0.0,
	combat_skill: int = 0,
	crit_chance: float = 0.0,
	morale_modifier: float = 1.0,
) -> int:
	var effective_fp: float = float(attacker_fp) * (1.0 + crew_bonus)
	effective_fp *= (1.0 + combat_skill * 0.02)
	effective_fp *= morale_modifier
	var base := maxi(1, int(effective_fp) - defender_armour)
	var variance := randf_range(Config.DAMAGE_VARIANCE_MIN, Config.DAMAGE_VARIANCE_MAX)
	var damage := maxi(1, int(base * variance))
	if crit_chance > 0.0 and randf() < crit_chance:
		damage = int(damage * Config.CRIT_MULTIPLIER)
	return damage


## Dodge probability based on speed: speed 10 → 40 %, speed 1 → 4 %.
##
## [param stealth_bonus] — character stealth contribution (0.0–0.1 typical).
static func dodge_chance(defender_speed: int, stealth_bonus: float = 0.0) -> float:
	var base_dodge: float = minf(Config.MAX_DODGE_CHANCE - 0.1, defender_speed * Config.DODGE_PER_SPEED)
	base_dodge = minf(Config.MAX_DODGE_CHANCE, base_dodge + stealth_bonus)
	return base_dodge
