## Stat evaluator — utility for checking character skill thresholds.
##
## Used by encounter conditions, combat, and dialogue gating to determine
## whether a character meets skill requirements.
class_name StatEvaluator
extends RefCounted

## Stat names in display order.
const STAT_NAMES: Array[String] = [
	"cunning", "leadership", "negotiation",
	"combat_skill", "intimidation", "stealth",
]


## Check whether a character's stat meets or exceeds a minimum value.
static func check_threshold(character: Character, stat_name: String, min_value: int) -> bool:
	var value: int = _get_stat(character, stat_name)
	return value >= min_value


## Return the name of the character's highest stat. Ties broken by order.
static func get_highest_stat(character: Character) -> String:
	var best_name: String = "cunning"
	var best_value: int = -1
	for stat_name in STAT_NAMES:
		var value: int = _get_stat(character, stat_name)
		if value > best_value:
			best_value = value
			best_name = stat_name
	return best_name


## Return the percentage (0.0–1.0) a single stat contributes to the total pool.
static func get_stat_percentage(character: Character, stat_name: String) -> float:
	var total: int = get_total_points(character)
	if total <= 0:
		return 0.0
	return float(_get_stat(character, stat_name)) / float(total)


## Return the sum of all six stats.
static func get_total_points(character: Character) -> int:
	var total: int = 0
	for stat_name in STAT_NAMES:
		total += _get_stat(character, stat_name)
	return total


## Check a dictionary of requirements against a character's stats.
## Keys: "min_<stat>" for minimum thresholds, "highest_stat" for dominant stat.
static func meets_skill_check(character: Character, requirements: Dictionary) -> bool:
	for key in requirements:
		if key == "highest_stat":
			if get_highest_stat(character) != requirements[key]:
				return false
		elif key.begins_with("min_"):
			var stat_name: String = key.substr(4)
			if not check_threshold(character, stat_name, int(requirements[key])):
				return false
	return true


## Read a named stat from a Character resource.
static func _get_stat(character: Character, stat_name: String) -> int:
	match stat_name:
		"cunning":
			return character.cunning
		"leadership":
			return character.leadership
		"negotiation":
			return character.negotiation
		"combat_skill":
			return character.combat_skill
		"intimidation":
			return character.intimidation
		"stealth":
			return character.stealth
	return 0


## Write a named stat on a Character resource.
static func set_stat(character: Character, stat_name: String, value: int) -> void:
	match stat_name:
		"cunning":
			character.cunning = value
		"leadership":
			character.leadership = value
		"negotiation":
			character.negotiation = value
		"combat_skill":
			character.combat_skill = value
		"intimidation":
			character.intimidation = value
		"stealth":
			character.stealth = value
