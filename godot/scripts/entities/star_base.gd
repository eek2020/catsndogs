## Star base entity — dockable space stations on the star map.
class_name StarBase
extends Resource

@export var base_id: String = ""
@export var base_name: String = ""
@export var base_type: String = "open"  # "open", "hidden", "stronghold"
@export var region_id: String = ""
@export var controlling_faction: String = ""
@export var position_x: float = 0.0
@export var position_y: float = 0.0
@export var description: String = ""
@export var image: String = ""  # filename without extension in assets/starbases/
@export var services: Array[String] = []
@export var artifacts: Array[String] = []
@export var required_reputation: int = 0
@export var discovery_flag: String = ""


static func from_dict(data: Dictionary) -> StarBase:
	var b := StarBase.new()
	b.base_id = data.get("base_id", "")
	b.base_name = data.get("base_name", "")
	b.base_type = data.get("base_type", "open")
	b.region_id = data.get("region_id", "")
	b.controlling_faction = data.get("controlling_faction", "")
	b.position_x = data.get("position_x", 0.0)
	b.position_y = data.get("position_y", 0.0)
	b.description = data.get("description", "")
	b.image = data.get("image", "")
	b.services = Array(data.get("services", []), TYPE_STRING, "", null)
	b.artifacts = Array(data.get("artifacts", []), TYPE_STRING, "", null)
	b.required_reputation = data.get("required_reputation", 0)
	b.discovery_flag = data.get("discovery_flag", "")
	return b


func to_dict() -> Dictionary:
	return {
		"base_id": base_id,
		"base_name": base_name,
		"base_type": base_type,
		"region_id": region_id,
		"controlling_faction": controlling_faction,
		"position_x": position_x,
		"position_y": position_y,
		"description": description,
		"image": image,
		"services": Array(services),
		"artifacts": Array(artifacts),
		"required_reputation": required_reputation,
		"discovery_flag": discovery_flag,
	}
