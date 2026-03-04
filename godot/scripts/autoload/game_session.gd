## GameSession autoload — orchestrates game systems, state transitions, callbacks.
## Mirrors Python core/session.py. In Godot this is an autoload singleton.
extends Node

# Systems
var data_loader: DataLoader
var encounter_engine: EncounterEngine
var narrative: NarrativeSystem
var faction_system: FactionSystem
var economy_system: EconomySystem
var crew_morale: CrewMoraleSystem
var exploration: ExplorationSystem
var faction_conquest: FactionConquestAI
var realm_control: RealmControlSystem
var side_mission_system: SideMissionSystem
var save_manager: SaveManager

# Runtime state
var game_state: GameStateData = null
var running: bool = true


func _ready() -> void:
	data_loader = DataLoader.new()
	encounter_engine = EncounterEngine.new(data_loader)
	narrative = NarrativeSystem.new(data_loader)
	faction_system = FactionSystem.new()
	economy_system = EconomySystem.new(data_loader)
	crew_morale = CrewMoraleSystem.new()
	exploration = ExplorationSystem.new()
	faction_conquest = FactionConquestAI.new()
	realm_control = RealmControlSystem.new()
	side_mission_system = SideMissionSystem.new(data_loader)
	save_manager = SaveManager.new()

	# Wire EventBus signals
	EventBus.arc_advanced.connect(_on_arc_advanced)
	EventBus.game_ending_reached.connect(_on_game_ending_reached)


# ------------------------------------------------------------------
# New game flow
# ------------------------------------------------------------------

func start_new_game() -> void:
	game_state = create_new_game_state()
	narrative.load_arcs()
	encounter_engine.load_encounters("arc1")
	side_mission_system.load_missions("arc1")
	side_mission_system.load_distress_signals()
	realm_control.initialize_realms(game_state)
	# Load region data for exploration
	var region_data: Array = data_loader.load_regions()
	exploration.load_regions(region_data)
	if game_state:
		MusicManager.on_arc_change(game_state.current_arc)
		MusicManager.on_state_change("navigation")


func create_new_game_state() -> GameStateData:
	var state := GameStateData.new()
	state.salvage = 50
	# Load factions
	state.faction_registry = data_loader.load_factions()
	state.relationship_matrix = data_loader.load_relationship_matrix()
	state.cascade_rules = data_loader.load_cascade_rules()
	# Load player ship from template
	var templates: Dictionary = data_loader.load_ship_templates()
	var corsair_tmpl: Dictionary = templates.get("corsair_raider", {})
	if not corsair_tmpl.is_empty():
		state.player_ship = Ship.from_template(corsair_tmpl, "aristotle_flagship", "The Whisper")
	else:
		state.player_ship = Ship.new()
		state.player_ship.ship_id = "aristotle_flagship"
		state.player_ship.ship_name = "The Whisper"
		state.player_ship.faction_id = "felid_corsairs"
		state.player_ship.ship_class = "corsair_raider"
		state.player_ship.current_hull = 100
		state.player_ship.max_hull = 100
	# Player character defaults
	state.player_character = Character.new()
	state.player_character.character_id = "aristotle"
	state.player_character.character_name = "Aristotle"
	state.player_character.species = Character.Species.CAT
	state.player_character.faction_id = "felid_corsairs"
	state.player_character.title = "Captain"
	state.player_character.is_player = true
	# Core NPCs
	var dave := Character.new()
	dave.character_id = "dave"
	dave.character_name = "Dave"
	dave.species = Character.Species.DOG
	dave.faction_id = "canis_league"
	dave.title = "Commander"
	dave.behaviour_state = Character.BehaviourState.OBSERVING
	state.npc_registry["dave"] = dave
	var death := Character.new()
	death.character_id = "death"
	death.character_name = "Death"
	death.species = Character.Species.CAT
	death.faction_id = "felid_corsairs"
	death.title = "Captain"
	death.behaviour_state = Character.BehaviourState.HIDDEN
	state.npc_registry["death"] = death
	# Economy data
	state.crystal_deposits = data_loader.load_crystal_deposits()
	state.supply_routes = data_loader.load_supply_routes()
	state.crystal_market = data_loader.load_crystal_market()
	# Story flags for Arc 1
	state.story_flags = {
		"arc1_crystal_discovered": false,
		"arc1_dave_met": false,
		"arc1_death_glimpsed": false,
		"arc1_stance": null,
	}
	return state


# ------------------------------------------------------------------
# Save / Load
# ------------------------------------------------------------------

func save_game(slot: int = 0) -> bool:
	if game_state == null:
		return false
	return save_manager.save_game(game_state, slot)


func load_game(slot: int = 0) -> bool:
	var loaded: GameStateData = save_manager.load_game(slot)
	if loaded == null:
		return false
	game_state = loaded
	narrative.load_arcs()
	encounter_engine.load_encounters(game_state.current_arc)
	side_mission_system.load_missions(game_state.current_arc)
	side_mission_system.load_distress_signals()
	realm_control.initialize_realms(game_state)
	MusicManager.on_arc_change(game_state.current_arc)
	MusicManager.on_state_change("navigation")
	return true


# ------------------------------------------------------------------
# Arc / ending callbacks
# ------------------------------------------------------------------

func _on_arc_advanced(old_arc: String, new_arc: String) -> void:
	encounter_engine.load_encounters(new_arc)
	side_mission_system.load_missions(new_arc)
	MusicManager.on_arc_change(new_arc)


func _on_game_ending_reached() -> void:
	MusicManager.on_state_change("ending")


# ------------------------------------------------------------------
# Screen helpers (called by UI scenes)
# ------------------------------------------------------------------

func open_trade_screen(faction_id: String) -> void:
	MusicManager.on_state_change("trade")


func quit_to_menu() -> void:
	game_state = null
	MusicManager.on_state_change("menu")


func quit_game() -> void:
	running = false
	get_tree().quit()
