## Music theme manager — maps game states to BGM tracks with fade transitions.
## Mirrors Python core/music_manager.py. Uses Godot AudioStreamPlayer natively.
extends Node

# Theme registry — maps game state keys to music track IDs.
const STATE_THEMES: Dictionary = {
	"menu": "theme_menu",
	"navigation": "theme_navigation",
	"combat": "theme_combat",
	"trade": "theme_trade",
	"dialogue": "theme_dialogue",
	"cutscene": "theme_cutscene",
	"ending": "theme_ending",
	"pause": "",
	"settings": "",
	"faction_screen": "",
	"ship_screen": "",
	"purchase": "",
	"mission_log": "",
}

# Arc-specific navigation themes override the default
const ARC_THEMES: Dictionary = {
	"arc_1": "theme_arc1",
	"arc_2": "theme_arc2",
	"arc_3": "theme_arc3",
	"arc_4": "theme_arc4",
}

# SFX event registry — maps event names to SFX file stems.
const SFX_EVENTS: Dictionary = {
	"combat_hit": "laser_hit",
	"combat_miss": "laser_fire",
	"combat_victory": "laser_hit",
	"combat_defeat": "laser_hit",
	"combat_flee": "menu_tick",
	"crystal_pickup": "menu_tick",
	"salvage_pickup": "menu_tick",
	"encounter_triggered": "menu_tick",
	"trade_buy": "menu_tick",
	"trade_sell": "menu_tick",
	"mission_accepted": "menu_tick",
	"mission_completed": "menu_tick",
	"mission_failed": "laser_hit",
	"ui_select": "menu_tick",
	"ui_cancel": "menu_tick",
	"ui_navigate": "menu_tick",
	"save_game": "menu_tick",
	"load_game": "menu_tick",
}

var _current_theme: String = ""
var _current_arc: String = ""
var _music_enabled: bool = true
var _sfx_enabled: bool = true

@onready var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	_music_player.bus = "Master"
	_sfx_player.bus = "Master"
	add_child(_music_player)
	add_child(_sfx_player)
	# Connect to EventBus signals for auto-SFX
	EventBus.combat_hit.connect(func(): play_sfx_for_event("combat_hit"))
	EventBus.combat_miss.connect(func(): play_sfx_for_event("combat_miss"))
	EventBus.combat_victory.connect(func(): play_sfx_for_event("combat_victory"))
	EventBus.combat_defeat.connect(func(): play_sfx_for_event("combat_defeat"))
	EventBus.combat_flee.connect(func(): play_sfx_for_event("combat_flee"))
	EventBus.crystal_pickup.connect(func(): play_sfx_for_event("crystal_pickup"))
	EventBus.salvage_pickup.connect(func(): play_sfx_for_event("salvage_pickup"))
	EventBus.encounter_triggered.connect(func(): play_sfx_for_event("encounter_triggered"))
	EventBus.trade_buy.connect(func(): play_sfx_for_event("trade_buy"))
	EventBus.trade_sell.connect(func(): play_sfx_for_event("trade_sell"))
	EventBus.mission_accepted.connect(func(): play_sfx_for_event("mission_accepted"))
	EventBus.mission_completed.connect(func(): play_sfx_for_event("mission_completed"))
	EventBus.mission_failed.connect(func(): play_sfx_for_event("mission_failed"))
	EventBus.save_game.connect(func(): play_sfx_for_event("save_game"))
	EventBus.load_game.connect(func(): play_sfx_for_event("load_game"))


# ------------------------------------------------------------------
# Music theme control
# ------------------------------------------------------------------

func on_state_change(state_key: String) -> void:
	var theme: String = STATE_THEMES.get(state_key, "")
	if theme.is_empty():
		return
	if state_key == "navigation" and ARC_THEMES.has(_current_arc):
		theme = ARC_THEMES[_current_arc]
	_play_theme(theme)


func on_arc_change(arc_id: String) -> void:
	_current_arc = arc_id
	if _current_theme in ARC_THEMES.values() or _current_theme == "theme_navigation":
		var arc_theme: String = ARC_THEMES.get(arc_id, "theme_navigation")
		_play_theme(arc_theme)


func stop() -> void:
	_music_player.stop()
	_current_theme = ""


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	if not enabled:
		stop()


func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled


var current_theme: String:
	get:
		return _current_theme


# ------------------------------------------------------------------
# SFX triggers
# ------------------------------------------------------------------

func play_sfx_for_event(event_name: String) -> void:
	if not _sfx_enabled:
		return
	var sfx_id: String = SFX_EVENTS.get(event_name, "")
	if sfx_id.is_empty():
		return
	play_sfx(sfx_id)


func play_sfx(sfx_id: String) -> void:
	if not _sfx_enabled:
		return
	var path := "res://assets/audio/sfx/%s.mp3" % sfx_id
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/sfx/%s.ogg" % sfx_id
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/sfx/%s.wav" % sfx_id
	if ResourceLoader.exists(path):
		_sfx_player.stream = load(path)
		_sfx_player.play()


# ------------------------------------------------------------------
# Internal
# ------------------------------------------------------------------

func _play_theme(theme_id: String) -> void:
	if theme_id == _current_theme:
		return
	if not _music_enabled:
		_current_theme = theme_id
		return
	_music_player.stop()
	var path := "res://assets/audio/music/%s.ogg" % theme_id
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/music/%s.mp3" % theme_id
	if ResourceLoader.exists(path):
		_music_player.stream = load(path)
		_music_player.play()
	_current_theme = theme_id
