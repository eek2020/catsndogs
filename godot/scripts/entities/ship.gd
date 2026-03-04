## Ship entity — stats, crew, upgrades.
## Mirrors Python entities/ship.py.
class_name Ship
extends Resource


@export var ship_id: String = ""
@export var ship_name: String = ""
@export var faction_id: String = ""
@export var ship_class: String = ""
@export var speed: int = 5
@export var armour: int = 5
@export var firepower: int = 5
@export var crystal_capacity: int = 5
@export var crew_capacity: int = 5
@export var current_hull: int = 100
@export var max_hull: int = 100
@export var crew: Array = []          # Array of CrewMember
@export var upgrades: Array = []      # Array of ShipUpgrade
@export var crystal_cargo: int = 0
@export var sprite_id: String = ""


static func from_dict(data: Dictionary) -> Ship:
	var s := Ship.new()
	s.ship_id = data.get("ship_id", "")
	s.ship_name = data.get("name", "")
	s.faction_id = data.get("faction_id", "")
	s.ship_class = data.get("ship_class", "")
	var bs: Dictionary = data.get("base_stats", {})
	s.speed = bs.get("speed", 5)
	s.armour = bs.get("armour", 5)
	s.firepower = bs.get("firepower", 5)
	s.crystal_capacity = bs.get("crystal_capacity", 5)
	s.crew_capacity = bs.get("crew_capacity", 5)
	s.current_hull = data.get("current_hull", data.get("max_hull", 100))
	s.max_hull = data.get("max_hull", 100)
	s.crystal_cargo = data.get("crystal_cargo", 0)
	s.sprite_id = data.get("sprite_id", "")
	for c_data in data.get("crew", []):
		s.crew.append(CrewMember.from_dict(c_data))
	for u_data in data.get("upgrades", []):
		s.upgrades.append(ShipUpgrade.from_dict(u_data))
	return s


static func from_template(template: Dictionary, p_ship_id: String, p_name: String) -> Ship:
	var s := Ship.new()
	s.ship_id = p_ship_id
	s.ship_name = p_name
	s.faction_id = template.get("faction_id", "")
	s.ship_class = template.get("template_id", "")
	var bs: Dictionary = template.get("base_stats", {})
	s.speed = bs.get("speed", 5)
	s.armour = bs.get("armour", 5)
	s.firepower = bs.get("firepower", 5)
	s.crystal_capacity = bs.get("crystal_capacity", 5)
	s.crew_capacity = bs.get("crew_capacity", 5)
	s.current_hull = template.get("max_hull", 100)
	s.max_hull = template.get("max_hull", 100)
	s.sprite_id = template.get("sprite_id", "")
	return s


func to_dict() -> Dictionary:
	var crew_arr: Array = []
	for c in crew:
		crew_arr.append(c.to_dict())
	var upgrade_arr: Array = []
	for u in upgrades:
		upgrade_arr.append(u.to_dict())
	return {
		"ship_id": ship_id,
		"name": ship_name,
		"faction_id": faction_id,
		"ship_class": ship_class,
		"base_stats": {
			"speed": speed,
			"armour": armour,
			"firepower": firepower,
			"crystal_capacity": crystal_capacity,
			"crew_capacity": crew_capacity,
		},
		"current_hull": current_hull,
		"max_hull": max_hull,
		"crew": crew_arr,
		"upgrades": upgrade_arr,
		"crystal_cargo": crystal_cargo,
		"sprite_id": sprite_id,
	}


## -----------------------------------------------------------------------
## CrewMember inner resource
## -----------------------------------------------------------------------
class CrewMember extends Resource:
	@export var crew_id: String = ""
	@export var crew_name: String = ""
	@export var species: String = ""
	@export var role: String = ""
	@export var faction_origin: String = ""
	@export var skills: Array[String] = []
	@export var skill_level: int = 5
	@export var morale: int = 100
	@export var morale_modifier: int = 0
	@export var faction_trait_bonus: String = ""

	static func from_dict(data: Dictionary) -> CrewMember:
		var cm := CrewMember.new()
		cm.crew_id = data.get("crew_id", "")
		cm.crew_name = data.get("name", "")
		cm.species = data.get("species", "cat")
		cm.role = data.get("role", "")
		cm.faction_origin = data.get("faction_origin", "")
		cm.skills = Array(data.get("skills", []), TYPE_STRING, "", null)
		cm.skill_level = data.get("skill_level", 5)
		cm.morale = data.get("morale", 100)
		cm.morale_modifier = data.get("morale_modifier", 0)
		cm.faction_trait_bonus = data.get("faction_trait_bonus", "")
		return cm

	func to_dict() -> Dictionary:
		return {
			"crew_id": crew_id,
			"name": crew_name,
			"species": species,
			"role": role,
			"faction_origin": faction_origin,
			"skills": Array(skills),
			"skill_level": skill_level,
			"morale": morale,
			"morale_modifier": morale_modifier,
			"faction_trait_bonus": faction_trait_bonus,
		}


## -----------------------------------------------------------------------
## ShipUpgrade inner resource
## -----------------------------------------------------------------------
class ShipUpgrade extends Resource:
	@export var upgrade_id: String = ""
	@export var upgrade_name: String = ""
	@export var target_stat: String = ""
	@export var modifier: int = 0
	@export var cost_crystals: int = 0
	@export var cost_salvage: int = 0

	static func from_dict(data: Dictionary) -> ShipUpgrade:
		var su := ShipUpgrade.new()
		su.upgrade_id = data.get("upgrade_id", "")
		su.upgrade_name = data.get("name", "")
		su.target_stat = data.get("target_stat", "")
		su.modifier = data.get("modifier", 0)
		su.cost_crystals = data.get("cost_crystals", 0)
		su.cost_salvage = data.get("cost_salvage", 0)
		return su

	func to_dict() -> Dictionary:
		return {
			"upgrade_id": upgrade_id,
			"name": upgrade_name,
			"target_stat": target_stat,
			"modifier": modifier,
			"cost_crystals": cost_crystals,
			"cost_salvage": cost_salvage,
		}
