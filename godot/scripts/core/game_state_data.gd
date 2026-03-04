## Master game state — single source of truth for all runtime data.
## Mirrors Python core/game_state.py (GameStateData + PlayerDecision).
class_name GameStateData
extends Resource

# Meta
@export var version: String = "0.1.0"
@export var save_slot: int = 0
@export var playtime_seconds: float = 0.0

# Arc progression
@export var current_arc: String = "arc_1"

# Player
@export var player_character: Character = null
@export var player_ship: Ship = null
@export var fleet: Array = []  # Array of Ship

# World position
@export var current_region: String = "starting_realm"
@export var position_x: float = 0.0
@export var position_y: float = 0.0

# Resources
@export var crystal_inventory: int = 0
@export var crystal_quality: int = 1
@export var salvage: int = 0

# Factions
@export var faction_registry: Dictionary = {}
@export var relationship_matrix: Dictionary = {}
@export var cascade_rules: Array = []

# NPCs
@export var npc_registry: Dictionary = {}

# Economy
@export var crystal_deposits: Dictionary = {}
@export var supply_routes: Dictionary = {}
@export var crystal_market: CrystalDeposit.CrystalMarket = null
@export var trade_ledger: Array = []

# Story
@export var story_flags: Dictionary = {}
@export var player_decisions: Array = []  # Array of PlayerDecision
@export var completed_encounters: Array[String] = []

# Side missions
@export var side_missions: Dictionary = {}


func to_dict() -> Dictionary:
	var faction_dict: Dictionary = {}
	for fid in faction_registry:
		faction_dict[fid] = faction_registry[fid].to_dict()
	var npc_dict: Dictionary = {}
	for nid in npc_registry:
		npc_dict[nid] = npc_registry[nid].to_dict()
	var deposit_dict: Dictionary = {}
	for did in crystal_deposits:
		deposit_dict[did] = crystal_deposits[did].to_dict()
	var route_dict: Dictionary = {}
	for rid in supply_routes:
		route_dict[rid] = supply_routes[rid].to_dict()
	var decision_arr: Array = []
	for d in player_decisions:
		decision_arr.append(d.to_dict())
	var mission_dict: Dictionary = {}
	for mid in side_missions:
		mission_dict[mid] = side_missions[mid].to_dict()
	return {
		"version": version,
		"save_slot": save_slot,
		"playtime_seconds": playtime_seconds,
		"current_arc": current_arc,
		"player_character": player_character.to_dict() if player_character else {},
		"player_ship": player_ship.to_dict() if player_ship else {},
		"fleet": fleet.map(func(s): return s.to_dict()),
		"current_region": current_region,
		"position_x": position_x,
		"position_y": position_y,
		"crystal_inventory": crystal_inventory,
		"crystal_quality": crystal_quality,
		"salvage": salvage,
		"faction_registry": faction_dict,
		"relationship_matrix": relationship_matrix,
		"cascade_rules": cascade_rules,
		"npc_registry": npc_dict,
		"crystal_deposits": deposit_dict,
		"supply_routes": route_dict,
		"crystal_market": crystal_market.to_dict() if crystal_market else {},
		"trade_ledger": trade_ledger.duplicate(),
		"story_flags": story_flags.duplicate(),
		"player_decisions": decision_arr,
		"completed_encounters": Array(completed_encounters),
		"side_missions": mission_dict,
	}


static func from_dict(data: Dictionary) -> GameStateData:
	var state := GameStateData.new()
	state.version = data.get("version", "0.1.0")
	state.save_slot = data.get("save_slot", 0)
	state.playtime_seconds = data.get("playtime_seconds", 0.0)
	state.current_arc = data.get("current_arc", "arc_1")
	if data.has("player_character"):
		state.player_character = Character.from_dict(data["player_character"])
	if data.has("player_ship"):
		state.player_ship = Ship.from_dict(data["player_ship"])
	for s_data in data.get("fleet", []):
		state.fleet.append(Ship.from_dict(s_data))
	state.current_region = data.get("current_region", "starting_realm")
	state.position_x = data.get("position_x", 0.0)
	state.position_y = data.get("position_y", 0.0)
	state.crystal_inventory = data.get("crystal_inventory", 0)
	state.crystal_quality = data.get("crystal_quality", 1)
	state.salvage = data.get("salvage", 0)
	state.relationship_matrix = data.get("relationship_matrix", {})
	state.cascade_rules = data.get("cascade_rules", [])
	state.crystal_market = CrystalDeposit.CrystalMarket.from_dict(data.get("crystal_market", {}))
	state.trade_ledger = data.get("trade_ledger", [])
	state.story_flags = data.get("story_flags", {})
	for d_data in data.get("player_decisions", []):
		state.player_decisions.append(PlayerDecision.from_dict(d_data))
	state.completed_encounters = Array(data.get("completed_encounters", []), TYPE_STRING, "", null)
	# Restore registries
	for fid in data.get("faction_registry", {}):
		state.faction_registry[fid] = Faction.from_dict(data["faction_registry"][fid])
	for nid in data.get("npc_registry", {}):
		state.npc_registry[nid] = Character.from_dict(data["npc_registry"][nid])
	for did in data.get("crystal_deposits", {}):
		state.crystal_deposits[did] = CrystalDeposit.from_dict(data["crystal_deposits"][did])
	for rid in data.get("supply_routes", {}):
		state.supply_routes[rid] = CrystalDeposit.SupplyRoute.from_dict(data["supply_routes"][rid])
	for mid in data.get("side_missions", {}):
		state.side_missions[mid] = SideMission.from_dict(data["side_missions"][mid])
	return state


## -----------------------------------------------------------------------
## PlayerDecision inner resource
## -----------------------------------------------------------------------
class PlayerDecision extends Resource:
	@export var decision_id: String = ""
	@export var encounter_id: String = ""
	@export var choice_id: String = ""
	@export var arc_id: String = ""
	@export var timestamp: float = 0.0
	@export var outcome_weight: float = 0.0
	@export var consequences_applied: Dictionary = {}

	func to_dict() -> Dictionary:
		return {
			"decision_id": decision_id,
			"encounter_id": encounter_id,
			"choice_id": choice_id,
			"arc_id": arc_id,
			"timestamp": timestamp,
			"outcome_weight": outcome_weight,
			"consequences_applied": consequences_applied,
		}

	static func from_dict(data: Dictionary) -> PlayerDecision:
		var pd := PlayerDecision.new()
		pd.decision_id = data.get("decision_id", "")
		pd.encounter_id = data.get("encounter_id", "")
		pd.choice_id = data.get("choice_id", "")
		pd.arc_id = data.get("arc_id", "")
		pd.timestamp = data.get("timestamp", 0.0)
		pd.outcome_weight = data.get("outcome_weight", 0.0)
		pd.consequences_applied = data.get("consequences_applied", {})
		return pd
