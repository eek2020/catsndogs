## Faction entity — registry, relationships, abilities.
## Mirrors Python entities/faction.py.
class_name Faction
extends Resource

enum DiplomaticState { HOSTILE, WARY, NEUTRAL, FRIENDLY, ALLIED }

@export var faction_id: String = ""
@export var faction_name: String = ""
@export var species: String = ""
@export var alignment: String = ""
@export var government: String = ""
@export var realm: String = ""
@export var ideology: String = ""
@export var reputation_with_player: int = 0
@export var diplomatic_state: DiplomaticState = DiplomaticState.NEUTRAL
@export var ship_template_id: String = ""
@export var conquest_intent: int = 50
@export var traits: Array[String] = []
@export var abilities: Array = []  # Array of FactionAbility
@export var military_strength: int = 50
@export var crystal_reserves: int = 0
@export var crystal_production_rate: int = 0
@export var internal_stability: int = 100
@export var aggression_level: int = 0
@export var political_influence: int = 0
@export var tactical_rating: int = 0


func update_diplomatic_state() -> void:
	var score := reputation_with_player
	if score <= -51:
		diplomatic_state = DiplomaticState.HOSTILE
	elif score <= -1:
		diplomatic_state = DiplomaticState.WARY
	elif score <= 25:
		diplomatic_state = DiplomaticState.NEUTRAL
	elif score <= 75:
		diplomatic_state = DiplomaticState.FRIENDLY
	else:
		diplomatic_state = DiplomaticState.ALLIED


static func from_dict(data: Dictionary) -> Faction:
	var f := Faction.new()
	f.faction_id = data.get("faction_id", "")
	f.faction_name = data.get("name", "")
	f.species = data.get("species", "")
	f.alignment = data.get("alignment", "")
	f.government = data.get("government", "")
	f.realm = data.get("realm", "")
	f.ideology = data.get("ideology", "")
	f.reputation_with_player = data.get("reputation_with_player", data.get("starting_reputation", 0))
	f.ship_template_id = data.get("ship_template_id", "")
	f.conquest_intent = data.get("conquest_intent", 50)
	f.traits = Array(data.get("traits", []), TYPE_STRING, "", null)
	for a_data in data.get("abilities", []):
		f.abilities.append(FactionAbility.from_dict(a_data))
	f.military_strength = data.get("military_strength", 50)
	f.crystal_reserves = data.get("crystal_reserves", 0)
	f.crystal_production_rate = data.get("crystal_production_rate", 0)
	f.internal_stability = data.get("internal_stability", 100)
	f.aggression_level = data.get("aggression_level", 0)
	f.political_influence = data.get("political_influence", 0)
	f.tactical_rating = data.get("tactical_rating", 0)
	f.update_diplomatic_state()
	return f


func to_dict() -> Dictionary:
	var abilities_arr: Array = []
	for a in abilities:
		abilities_arr.append(a.to_dict())
	return {
		"faction_id": faction_id,
		"name": faction_name,
		"species": species,
		"alignment": alignment,
		"government": government,
		"realm": realm,
		"ideology": ideology,
		"reputation_with_player": reputation_with_player,
		"diplomatic_state": DiplomaticState.keys()[diplomatic_state],
		"ship_template_id": ship_template_id,
		"conquest_intent": conquest_intent,
		"traits": Array(traits),
		"abilities": abilities_arr,
		"military_strength": military_strength,
		"crystal_reserves": crystal_reserves,
		"crystal_production_rate": crystal_production_rate,
		"internal_stability": internal_stability,
		"aggression_level": aggression_level,
		"political_influence": political_influence,
		"tactical_rating": tactical_rating,
	}


## -----------------------------------------------------------------------
## FactionAbility inner resource
## -----------------------------------------------------------------------
class FactionAbility extends Resource:
	@export var ability_id: String = ""
	@export var ability_name: String = ""
	@export var ability_type: String = ""
	@export var description: String = ""
	@export var effect: Dictionary = {}

	static func from_dict(data: Dictionary) -> FactionAbility:
		var fa := FactionAbility.new()
		fa.ability_id = data.get("ability_id", "")
		fa.ability_name = data.get("name", "")
		fa.ability_type = data.get("type", "")
		fa.description = data.get("description", "")
		fa.effect = data.get("effect", {})
		return fa

	func to_dict() -> Dictionary:
		return {
			"ability_id": ability_id,
			"name": ability_name,
			"type": ability_type,
			"description": description,
			"effect": effect,
		}
