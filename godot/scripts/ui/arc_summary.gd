## Arc Summary screen — shown between story arcs with stats + hyperspace jump.
extends Control

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/VBox/SubtitleLabel
@onready var stats_container: VBoxContainer = $Panel/VBox/StatsContainer
@onready var continue_button: Button = $Panel/VBox/ContinueButton
@onready var hyperspace_rect: ColorRect = $HyperspaceRect
@onready var background_rect: ColorRect = $Background

var _old_arc: String = ""
var _new_arc: String = ""
var _jump_started: bool = false

const STAT_COUNT_DURATION: float = 1.2
const JUMP_DURATION: float = 2.5


func setup(old_arc: String, new_arc: String) -> void:
	_old_arc = old_arc
	_new_arc = new_arc
	# Deferred so @onready vars are resolved first
	call_deferred("_build_screen")


func _ready() -> void:
	hyperspace_rect.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = false


func _build_screen() -> void:
	_populate_header()
	_populate_stats()

	# Pause current BGM and play the arc-end fanfare
	MusicManager.pause_music()
	await get_tree().create_timer(0.6).timeout
	MusicManager.play_one_shot_theme("theme_arc_end")

	# Animate stats in, then show button
	await _animate_stats()
	continue_button.visible = true
	continue_button.modulate.a = 0.0
	var btn_tween := create_tween()
	btn_tween.tween_property(continue_button, "modulate:a", 1.0, 0.3)
	continue_button.call_deferred("grab_focus")


func _populate_header() -> void:
	var old_title: String = GameSession.narrative.get_arc_title(_old_arc)
	var new_title: String = GameSession.narrative.get_arc_title(_new_arc)

	title_label.text = "%s — COMPLETE" % old_title.to_upper()

	# Get theme of new arc from definitions
	var new_theme := ""
	for arc in GameSession.narrative.arc_definitions:
		if arc["arc_id"] == _new_arc:
			new_theme = arc.get("theme", "")
			break
	if new_theme.is_empty():
		subtitle_label.text = "Now entering: %s" % new_title
	else:
		subtitle_label.text = "Now entering: %s\n%s" % [new_title, new_theme]


func _populate_stats() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return

	var encounters_done: int = gs.completed_encounters.size()
	var combat_wins: int = gs.combat_victories
	var crew_count: int = 0
	var crew_cap: int = 4
	if gs.player_ship:
		crew_count = gs.player_ship.crew.size()
		crew_cap = gs.player_ship.crew_capacity

	var missions_completed: int = 0
	for mid in gs.side_missions:
		var m: SideMission = gs.side_missions[mid]
		if m.status == "completed":
			missions_completed += 1

	var playtime_mins: int = int(gs.playtime_seconds / 60.0)

	var stats: Array[Dictionary] = [
		{"label": "ENCOUNTERS COMPLETED", "value": encounters_done},
		{"label": "COMBAT VICTORIES", "value": combat_wins},
		{"label": "CREW RECRUITED", "value": crew_count, "suffix": " / %d" % crew_cap},
		{"label": "MISSIONS COMPLETED", "value": missions_completed},
		{"label": "CRYSTALS", "value": gs.crystal_inventory},
		{"label": "SALVAGE", "value": gs.salvage},
		{"label": "HULL", "value": gs.player_ship.current_hull if gs.player_ship else 0, "suffix": " / %d" % (gs.player_ship.max_hull if gs.player_ship else 100)},
		{"label": "PLAYTIME", "value": playtime_mins, "suffix": " min"},
	]

	for stat in stats:
		var row := _create_stat_row(stat)
		stats_container.add_child(row)


func _create_stat_row(stat: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = stat["label"]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85))
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)

	var value_label := Label.new()
	value_label.text = "0" + stat.get("suffix", "")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.set_meta("_target_value", stat["value"])
	value_label.set_meta("_suffix", stat.get("suffix", ""))
	row.add_child(value_label)

	row.modulate.a = 0.0
	return row


func _animate_stats() -> void:
	var delay: float = 0.0
	for i in range(stats_container.get_child_count()):
		var row: HBoxContainer = stats_container.get_child(i)
		# Fade in the row
		var fade_tween := create_tween()
		fade_tween.tween_property(row, "modulate:a", 1.0, 0.2).set_delay(delay)

		# Count up the value
		var value_label: Label = row.get_child(1)
		var target: int = value_label.get_meta("_target_value")
		var suffix: String = value_label.get_meta("_suffix")
		_animate_count(value_label, target, suffix, delay + 0.1)

		delay += 0.15

	# Wait for all animations to finish
	await get_tree().create_timer(delay + STAT_COUNT_DURATION + 0.2).timeout


func _animate_count(label: Label, target: int, suffix: String, start_delay: float) -> void:
	var tween := create_tween()
	tween.tween_method(
		func(val: float) -> void:
			label.text = "%d%s" % [int(val), suffix],
		0.0,
		float(target),
		STAT_COUNT_DURATION
	).set_delay(start_delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _on_continue_pressed() -> void:
	if _jump_started:
		return
	_jump_started = true
	print("[ArcSummary] Continue pressed — fading out stats")

	# Fade out both the background and the stats panel so hyperspace is visible
	var panel: PanelContainer = $Panel
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	fade_tween.tween_property(background_rect, "modulate:a", 0.0, 0.4)
	await fade_tween.finished

	print("[ArcSummary] Starting hyperspace jump")
	# Start hyperspace jump — must await so the tween stays alive
	await _play_hyperspace_jump()


func _play_hyperspace_jump() -> void:
	hyperspace_rect.visible = true
	hyperspace_rect.z_index = 10  # Ensure it renders above everything
	var mat: ShaderMaterial = hyperspace_rect.material
	if mat == null:
		print("[ArcSummary] WARNING: HyperspaceRect has no ShaderMaterial — skipping animation")
		_finish_transition()
		return

	print("[ArcSummary] Hyperspace shader found — animating progress 0→1 over %.1fs" % JUMP_DURATION)
	mat.set_shader_parameter("progress", 0.0)
	var tween := create_tween()
	tween.tween_method(
		func(val: float) -> void:
			mat.set_shader_parameter("progress", val),
		0.0,
		1.0,
		JUMP_DURATION
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	await tween.finished
	print("[ArcSummary] Hyperspace animation complete")
	# Brief pause at black
	await get_tree().create_timer(0.5).timeout
	_finish_transition()


func _finish_transition() -> void:
	# Resume the original BGM (now on the new arc's theme)
	MusicManager.resume_music()
	EventBus.arc_transition_complete.emit(_new_arc)
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
