## Planet entity — explorable planetary surface.
class_name Planet
extends Resource

@export var planet_id: String = ""
@export var planet_name: String = ""
@export var planet_type: String = "charted"  # "charted", "uncharted"
@export var region_id: String = ""
@export var biome: String = "settlement"
@export var controlling_faction: String = ""
@export var danger_level: int = 1
@export var position_x: float = 0.0
@export var position_y: float = 0.0
@export var description: String = ""
@export var image: String = ""  # e.g. "planet_1" — filename without extension in assets/planets/
@export var merchants: Array = []  # Array of merchant dicts
@export var crew_available: Array = []
@export var treasures: Array = []  # Array of treasure dicts
@export var hostiles: Array = []  # Array of hostile dicts


static func from_dict(data: Dictionary) -> Planet:
	var p := Planet.new()
	p.planet_id = data.get("planet_id", "")
	p.planet_name = data.get("planet_name", "")
	p.planet_type = data.get("planet_type", "charted")
	p.region_id = data.get("region_id", "")
	p.biome = data.get("biome", "settlement")
	p.controlling_faction = data.get("controlling_faction", "")
	p.danger_level = data.get("danger_level", 1)
	p.position_x = data.get("position_x", 0.0)
	p.position_y = data.get("position_y", 0.0)
	p.description = data.get("description", "")
	p.image = data.get("image", "")
	p.merchants = data.get("merchants", [])
	p.crew_available = data.get("crew_available", [])
	p.treasures = data.get("treasures", [])
	p.hostiles = data.get("hostiles", [])
	return p


func to_dict() -> Dictionary:
	return {
		"planet_id": planet_id,
		"planet_name": planet_name,
		"planet_type": planet_type,
		"region_id": region_id,
		"biome": biome,
		"controlling_faction": controlling_faction,
		"danger_level": danger_level,
		"position_x": position_x,
		"position_y": position_y,
		"description": description,
		"image": image,
		"merchants": merchants.duplicate(true),
		"crew_available": crew_available.duplicate(true),
		"treasures": treasures.duplicate(true),
		"hostiles": hostiles.duplicate(true),
	}
