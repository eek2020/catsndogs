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
var crew_trait_system: CrewTraitSystem
var star_map_system: StarMapSystem
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
	crew_trait_system = CrewTraitSystem.new(data_loader)
	star_map_system = StarMapSystem.new()
	save_manager = SaveManager.new()

	# Wire EventBus signals
	EventBus.arc_advanced.connect(_on_arc_advanced)
	EventBus.game_ending_reached.connect(_on_game_ending_reached)
	EventBus.crew_member_recruited.connect(_on_crew_member_recruited)
	EventBus.combat_victory.connect(_on_combat_victory)
	EventBus.cartographer_rescued.connect(_on_cartographer_rescued)


# ------------------------------------------------------------------
# New game flow
# ------------------------------------------------------------------

func start_new_game(protagonist_id: String = "aristotle") -> void:
	game_state = create_new_game_state(protagonist_id)
	var suffix: String = get_protagonist_config().get("encounter_suffix", "")
	narrative.load_arcs()
	encounter_engine.load_encounters("arc1", suffix)
	side_mission_system.load_missions("arc1", suffix)
	side_mission_system.load_distress_signals()
	side_mission_system.load_crew_missions(protagonist_id, data_loader)
	_load_crew_encounters(protagonist_id)
	_load_cartographer_encounters()
	realm_control.initialize_realms(game_state)
	var region_data: Array = data_loader.load_regions()
	exploration.load_regions(region_data)
	_init_star_maps()
	if game_state:
		game_state.owned_maps = [game_state.current_region]
		star_map_system.owned_maps = game_state.owned_maps.duplicate()
		# Place ship at center of starting region
		var bounds: Vector2 = star_map_system.get_bounds(game_state.current_region)
		game_state.position_x = bounds.x * 0.5
		game_state.position_y = bounds.y * 0.5
		star_map_system.reveal_around(game_state.current_region, game_state.position_x, game_state.position_y, 300.0)
		MusicManager.on_arc_change(game_state.current_arc)
		MusicManager.on_state_change("navigation")


func create_new_game_state(protagonist_id: String = "aristotle") -> GameStateData:
	var state := GameStateData.new()
	state.protagonist_id = protagonist_id
	var protagonists: Dictionary = data_loader.load_protagonists()
	var config: Dictionary = protagonists.get(protagonist_id, protagonists.get("aristotle", {}))
	state.salvage = config.get("starting_salvage", 50)
	state.current_region = config.get("starting_region", "starting_realm")
	# Load factions
	state.faction_registry = data_loader.load_factions()
	state.relationship_matrix = data_loader.load_relationship_matrix()
	state.cascade_rules = data_loader.load_cascade_rules()
	# Load player ship from template
	var templates: Dictionary = data_loader.load_ship_templates()
	var tmpl_id: String = config.get("ship_template_id", "corsair_raider")
	var tmpl: Dictionary = templates.get(tmpl_id, {})
	if not tmpl.is_empty():
		state.player_ship = Ship.from_template(
			tmpl, config.get("ship_id", "flagship"), config.get("ship_name", "Ship")
		)
	else:
		state.player_ship = Ship.new()
		state.player_ship.ship_id = config.get("ship_id", "flagship")
		state.player_ship.ship_name = config.get("ship_name", "Ship")
		state.player_ship.faction_id = config.get("faction_id", "felid_corsairs")
		state.player_ship.ship_class = tmpl_id
		state.player_ship.current_hull = 100
		state.player_ship.max_hull = 100
	# Player character from config
	state.player_character = Character.from_dict(config)
	state.player_character.is_player = true
	# Rival NPC
	var rival_data: Dictionary = config.get("rival", {})
	if not rival_data.is_empty():
		var rival := Character.from_dict(rival_data)
		state.npc_registry[rival.character_id] = rival
	# Death is always an NPC
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
	# Story flags from protagonist config
	var flags: Dictionary = config.get("story_flags", {})
	state.story_flags = flags.duplicate()
	return state


func get_protagonist_config() -> Dictionary:
	var pid: String = game_state.protagonist_id if game_state else "aristotle"
	var protagonists: Dictionary = data_loader.load_protagonists()
	return protagonists.get(pid, {})


# ------------------------------------------------------------------
# Save / Load
# ------------------------------------------------------------------

func save_game(slot: int = 0) -> bool:
	if game_state == null:
		return false
	# Persist star map state before saving
	game_state.owned_maps = star_map_system.owned_maps.duplicate()
	game_state.star_map_data = star_map_system.to_dict()
	return save_manager.save_game(game_state, slot)


func load_game(slot: int = 0) -> bool:
	var loaded: GameStateData = save_manager.load_game(slot)
	if loaded == null:
		return false
	game_state = loaded
	var suffix: String = get_protagonist_config().get("encounter_suffix", "")
	narrative.load_arcs()
	encounter_engine.load_encounters(game_state.current_arc, suffix)
	side_mission_system.load_missions(game_state.current_arc, suffix)
	side_mission_system.load_distress_signals()
	side_mission_system.load_crew_missions(game_state.protagonist_id, data_loader)
	_load_crew_encounters(game_state.protagonist_id)
	_load_cartographer_encounters()
	realm_control.initialize_realms(game_state)
	_init_star_maps()
	# Restore star map state from save
	star_map_system.owned_maps = game_state.owned_maps.duplicate()
	star_map_system.cartographer_rescued = game_state.story_flags.get("fairy_cartographer_rescued", false)
	if not game_state.star_map_data.is_empty():
		star_map_system.load_from_dict(game_state.star_map_data)
	MusicManager.on_arc_change(game_state.current_arc)
	MusicManager.on_state_change("navigation")
	return true


# ------------------------------------------------------------------
# Arc / ending callbacks
# ------------------------------------------------------------------

func _deferred_arc_check() -> void:
	if game_state != null and narrative.check_arc_exit(game_state):
		narrative.advance_arc(game_state)


func _on_arc_advanced(_old_arc: String, new_arc: String) -> void:
	var suffix: String = get_protagonist_config().get("encounter_suffix", "")
	encounter_engine.load_encounters(new_arc, suffix)
	side_mission_system.load_missions(new_arc, suffix)
	MusicManager.on_arc_change(new_arc)


func _on_combat_victory() -> void:
	if game_state != null:
		game_state.combat_victories += 1


func _on_game_ending_reached() -> void:
	MusicManager.on_state_change("ending")


# ------------------------------------------------------------------
# Screen helpers (called by UI scenes)
# ------------------------------------------------------------------

func open_trade_screen(_faction_id: String) -> void:
	MusicManager.on_state_change("trade")


func quit_to_menu() -> void:
	game_state = null
	MusicManager.on_state_change("menu")


func quit_game() -> void:
	running = false
	get_tree().quit()


# ------------------------------------------------------------------
# Crew recruitment
# ------------------------------------------------------------------

func _load_crew_encounters(protagonist_id: String) -> void:
	var crew_members: Array = data_loader.load_crew_members()
	for member in crew_members:
		if member.get("protagonist_id", "") != protagonist_id:
			continue
		var crew_id: String = member.get("crew_id", "")
		var encounters: Array = data_loader.load_crew_encounters(crew_id)
		for enc in encounters:
			encounter_engine.encounter_table.append(enc)


func _on_crew_member_recruited(crew_id: String, _protagonist_id: String) -> void:
	if game_state == null:
		return
	var crew_members: Array = data_loader.load_crew_members()
	for member_data in crew_members:
		if member_data.get("crew_id", "") == crew_id:
			var cm := Ship.CrewMember.from_dict(member_data)
			cm.recruitment_status = "recruited"
			cm.morale = 100
			game_state.player_ship.crew.append(cm)
			break


func recruit_crew_member(crew_id: String) -> void:
	if game_state == null:
		return
	var protagonist_id: String = game_state.protagonist_id
	EventBus.crew_member_recruited.emit(crew_id, protagonist_id)


# ------------------------------------------------------------------
# Star map
# ------------------------------------------------------------------

func _init_star_maps() -> void:
	var region_map_data: Dictionary = data_loader.load_region_maps()
	star_map_system.load_region_maps(region_map_data)
	var galaxy_data: Dictionary = data_loader.load_galaxy_layout()
	star_map_system.load_galaxy_layout(galaxy_data)


func _load_cartographer_encounters() -> void:
	var encounters: Array = data_loader.load_cartographer_encounters()
	for enc in encounters:
		encounter_engine.encounter_table.append(enc)


func _on_cartographer_rescued() -> void:
	if game_state == null:
		return
	game_state.story_flags["fairy_cartographer_rescued"] = true


func purchase_map(region_id: String, cost_crystals: int, reveal_pct: float) -> bool:
	if game_state == null:
		return false
	if game_state.crystal_inventory < cost_crystals:
		return false
	if star_map_system.has_map(region_id):
		return false
	game_state.crystal_inventory -= cost_crystals
	star_map_system.purchase_map(region_id, reveal_pct)
	game_state.owned_maps = star_map_system.owned_maps.duplicate()
	return true


func travel_to_region(target_region: String) -> bool:
	if game_state == null:
		return false
	var success: bool = exploration.travel_to_region(game_state, target_region)
	if success:
		var entry_pos: Vector2 = star_map_system.get_entry_position(game_state.current_region, target_region)
		game_state.position_x = entry_pos.x
		game_state.position_y = entry_pos.y
		star_map_system.reveal_around(target_region, entry_pos.x, entry_pos.y, 300.0)
		EventBus.region_changed.emit(game_state.current_region, target_region)
	return success
