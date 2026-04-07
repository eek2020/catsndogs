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
	"intro_crawl": "story_theme",
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
	"combat_victory": "mission_completed",
	"combat_defeat": "warning",
	"combat_flee": "combat_flee",
	"crystal_pickup": "crystal_pickup",
	"salvage_pickup": "crystal_pickup",
	"encounter_triggered": "ui_select",
	"trade_buy": "ui_select",
	"trade_sell": "ui_select",
	"mission_accepted": "ui_select",
	"mission_completed": "mission_completed",
	"mission_failed": "warning",
	"ui_select": "ui_select",
	"ui_cancel": "ui_select",
	"ui_navigate": "ui_select",
	"save_game": "ui_select",
	"load_game": "ui_select",
}

var _current_theme: String = ""
var _current_arc: String = ""
var _music_enabled: bool = true
var _sfx_enabled: bool = true
var _music_volume_db: float = -20.0  # Default volume (dB)
var _sfx_volume_db: float = 0.0

# Saved playback positions so music can resume where it left off
var _saved_positions: Dictionary = {}  # theme_id -> playback_position_sec
var _saved_streams: Dictionary = {}    # theme_id -> AudioStream resource

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_sfx_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"   # Issue #15: separate bus for independent volume
	_music_player.volume_db = _music_volume_db
	_sfx_player.bus = "SFX"       # Issue #15: separate bus for independent volume
	_sfx_player.volume_db = _sfx_volume_db
	add_child(_music_player)
	add_child(_sfx_player)
	EventBus.volume_changed.connect(_on_volume_changed)
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
		var arc_theme: String = ARC_THEMES[_current_arc]
		if _theme_file_exists(arc_theme):
			theme = arc_theme
	_play_theme(theme)


func on_arc_change(arc_id: String) -> void:
	_current_arc = arc_id
	if _current_theme in ARC_THEMES.values() or _current_theme == "theme_navigation":
		var arc_theme: String = ARC_THEMES.get(arc_id, "theme_navigation")
		if not _theme_file_exists(arc_theme):
			arc_theme = "theme_navigation"
		_play_theme(arc_theme)


func stop() -> void:
	_saved_positions.clear()
	_saved_streams.clear()
	_music_player.stop()
	_current_theme = ""
	_paused = false


var _paused: bool = false
var _paused_position: float = 0.0
var _paused_stream: AudioStream = null
var _paused_theme: String = ""


func pause_music() -> void:
	if _paused or not _music_player.playing:
		return
	_paused_position = _music_player.get_playback_position()
	_paused_stream = _music_player.stream
	_paused_theme = _current_theme
	# Fade out quickly
	var tw := create_tween()
	tw.tween_property(_music_player, "volume_db", -80.0, 0.5)
	await tw.finished
	_music_player.stop()
	_paused = true


func resume_music() -> void:
	if not _paused or _paused_stream == null:
		_paused = false
		return
	_music_player.stream = _paused_stream
	_music_player.volume_db = -80.0
	_music_player.play(_paused_position)
	_current_theme = _paused_theme
	var tw := create_tween()
	tw.tween_property(_music_player, "volume_db", _music_volume_db, 0.8)
	_paused = false
	_paused_stream = null
	_paused_theme = ""


func play_one_shot_theme(theme_id: String) -> void:
	var path := "res://assets/audio/music/%s.ogg" % theme_id
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/music/%s.mp3" % theme_id
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = _music_volume_db
	_music_player.play()


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	if not enabled:
		stop()


func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled


func set_music_volume(volume_linear: float) -> void:
	## Set music volume from a 0.0–1.0 linear scale.
	_music_volume_db = linear_to_db(clampf(volume_linear, 0.0, 1.0))
	_music_player.volume_db = _music_volume_db


func set_sfx_volume(volume_linear: float) -> void:
	## Set SFX volume from a 0.0–1.0 linear scale.
	_sfx_volume_db = linear_to_db(clampf(volume_linear, 0.0, 1.0))
	_sfx_player.volume_db = _sfx_volume_db


func _on_volume_changed(volume: float) -> void:
	## Handle the EventBus volume_changed signal (controls music volume).
	set_music_volume(volume)


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

func _theme_file_exists(theme_id: String) -> bool:
	var path := "res://assets/audio/music/%s.ogg" % theme_id
	if ResourceLoader.exists(path):
		return true
	path = "res://assets/audio/music/%s.mp3" % theme_id
	return ResourceLoader.exists(path)


func _play_theme(theme_id: String) -> void:
	if theme_id == _current_theme:
		return
	if not _music_enabled:
		_current_theme = theme_id
		return
	# Resolve the stream to play before stopping anything
	var resume_pos: float = _saved_positions.get(theme_id, 0.0)
	var cached_stream: AudioStream = _saved_streams.get(theme_id, null)
	var new_stream: AudioStream = null
	if cached_stream:
		new_stream = cached_stream
	else:
		var path := "res://assets/audio/music/%s.ogg" % theme_id
		if not ResourceLoader.exists(path):
			path = "res://assets/audio/music/%s.mp3" % theme_id
		if ResourceLoader.exists(path):
			new_stream = load(path)
	if new_stream == null:
		# No file found — keep current music playing, don't update state.
		return
	# We have something to play — now save outgoing position and switch
	if not _current_theme.is_empty() and _music_player.playing:
		_saved_positions[_current_theme] = _music_player.get_playback_position()
		_saved_streams[_current_theme] = _music_player.stream
	_music_player.stop()
	_music_player.stream = new_stream
	_music_player.play(resume_pos)
	_current_theme = theme_id
