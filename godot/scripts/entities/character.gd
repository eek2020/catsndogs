## Character entity — Aristotle, Dave, Death, NPCs.
## Mirrors Python entities/character.py.
class_name Character
extends Resource

enum Species { CAT, DOG, CAT_NOBLE, WOLF, FAIRY, KNIGHT, GOBLIN, ALIEN }

enum BehaviourState {
	IDLE, OBSERVING, TRADING, HOSTILE, COVERT_ACTION,
	REVEALED, OPEN_CONFLICT, ALLIED, HIDDEN,
}

@export var character_id: String = ""
@export var character_name: String = ""
@export var species: Species = Species.CAT
@export var faction_id: String = ""
@export var title: String = ""
@export var cunning: int = 5
@export var leadership: int = 5
@export var negotiation: int = 5
@export var combat_skill: int = 5
@export var intimidation: int = 5
@export var stealth: int = 5
@export var behaviour_state: BehaviourState = BehaviourState.IDLE
@export var relationship_with_player: int = 0
@export var current_arc: String = "arc_1"
@export var is_player: bool = false
@export var true_allegiance: String = ""
@export var portrait_sprite: String = ""
@export var dialogue_tree_id: String = ""


static func from_dict(data: Dictionary) -> Character:
	var c := Character.new()
	c.character_id = data.get("character_id", "")
	c.character_name = data.get("name", "")
	var sp_str: String = str(data.get("species", "CAT")).to_upper()
	c.species = Species.get(sp_str, Species.CAT)
	c.faction_id = data.get("faction_id", "")
	c.title = data.get("title", "")
	var stats: Dictionary = data.get("stats", {})
	c.cunning = stats.get("cunning", 5)
	c.leadership = stats.get("leadership", 5)
	c.negotiation = stats.get("negotiation", 5)
	c.combat_skill = stats.get("combat_skill", 5)
	c.intimidation = stats.get("intimidation", 5)
	c.stealth = stats.get("stealth", 5)
	var bs_str: String = str(data.get("behaviour_state", "IDLE")).to_upper()
	c.behaviour_state = BehaviourState.get(bs_str, BehaviourState.IDLE)
	c.relationship_with_player = data.get("relationship_with_player", 0)
	c.current_arc = data.get("current_arc", "arc_1")
	c.is_player = data.get("is_player", false)
	c.true_allegiance = data.get("true_allegiance", "")
	c.portrait_sprite = data.get("portrait_sprite", "")
	c.dialogue_tree_id = data.get("dialogue_tree_id", "")
	return c


func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"name": character_name,
		"species": Species.keys()[species],
		"faction_id": faction_id,
		"title": title,
		"stats": {
			"cunning": cunning,
			"leadership": leadership,
			"negotiation": negotiation,
			"combat_skill": combat_skill,
			"intimidation": intimidation,
			"stealth": stealth,
		},
		"behaviour_state": BehaviourState.keys()[behaviour_state],
		"relationship_with_player": relationship_with_player,
		"current_arc": current_arc,
		"is_player": is_player,
		"true_allegiance": true_allegiance,
		"portrait_sprite": portrait_sprite,
		"dialogue_tree_id": dialogue_tree_id,
	}
