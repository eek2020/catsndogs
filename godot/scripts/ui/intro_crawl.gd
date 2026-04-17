## Star Wars-style intro crawl — perspective-scrolling text that fades into the distance.
## Replaces the old cutscene typewriter for the new-game intro.
extends Control

@onready var star_field: Control = $StarField
@onready var title_label: Label = $TitleContainer/Title
@onready var subtitle_label: Label = $TitleContainer/Subtitle
@onready var crawl_viewport: SubViewportContainer = $CrawlViewport
@onready var crawl_sub: SubViewport = $CrawlViewport/SubViewport
@onready var crawl_text: RichTextLabel = $CrawlViewport/SubViewport/CrawlText
@onready var skip_label: Label = $SkipLabel
@onready var fade_top: ColorRect = $FadeTop

## Fallback scroll speed if song duration cannot be determined
const SCROLL_SPEED_FALLBACK: float = 28.0
## Extra speed when holding skip-forward
const FAST_SCROLL_MULTIPLIER: float = 2.5
## Duration of the title card fade-in / fade-out
const TITLE_FADE_IN: float = 1.8
const TITLE_HOLD: float = 2.5
const TITLE_FADE_OUT: float = 1.2
## Time before crawl text starts after title fades
const CRAWL_DELAY: float = 0.6
## Seconds before song ends to finish scrolling (allows fade-out)
const SONG_END_BUFFER: float = 2.0
## Music fade-out duration when crawl ends
const MUSIC_FADE_OUT: float = 2.0
## Starfield twinkle interval range
const STAR_TWINKLE_MIN: float = 0.4
const STAR_TWINKLE_MAX: float = 1.6

var _stars: Array[Dictionary] = []
var _phase: StringName = &"title_in"  # title_in, title_hold, title_out, crawl_delay, scrolling, done
var _phase_timer: float = 0.0
var _scroll_offset: float = 0.0
var _crawl_total_height: float = 0.0
var _fast_forward: bool = false
var _scroll_speed: float = 28.0
var _song_duration: float = 0.0

# Enriched intro paragraphs loaded from protagonist config
var _paragraphs: Array[String] = []


func _ready() -> void:
	# Load enriched intro from protagonist config
	var config: Dictionary = GameSession.get_protagonist_config()
	title_label.text = config.get("intro_title", "WHISPER CRYSTALS")
	subtitle_label.text = config.get("intro_subtitle", "")

	var raw_paragraphs: Array = config.get("intro_crawl", [])
	if raw_paragraphs.is_empty():
		# Fallback to old intro_lines
		raw_paragraphs = config.get("intro_lines", ["And so the journey begins."])
	for p in raw_paragraphs:
		_paragraphs.append(str(p))

	# Build the crawl BBCode text
	crawl_text.bbcode_enabled = true
	var bbcode: String = ""
	for i in _paragraphs.size():
		var para: String = _paragraphs[i]
		bbcode += "[center]%s[/center]\n\n" % para
	crawl_text.text = bbcode

	# Initial state — hide crawl, show title invisible
	crawl_viewport.modulate.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	skip_label.modulate.a = 0.4

	# Generate starfield
	_generate_stars(120)

	# Start music immediately so the title card plays over opening bars
	MusicManager.play_one_shot_theme("story_theme")
	_song_duration = _get_song_duration()

	# Start title fade-in
	_phase = &"title_in"
	_phase_timer = 0.0

	# We need to wait a frame so the crawl_text layout settles
	await get_tree().process_frame
	await get_tree().process_frame
	_crawl_total_height = crawl_text.get_content_height() + get_viewport_rect().size.y

	# Calculate scroll speed so text finishes in sync with the song
	_scroll_speed = _calculate_scroll_speed()


func _process(dt: float) -> void:
	_update_stars(dt)

	match _phase:
		&"title_in":
			_phase_timer += dt
			var t: float = clampf(_phase_timer / TITLE_FADE_IN, 0.0, 1.0)
			title_label.modulate.a = t
			subtitle_label.modulate.a = t * 0.7
			if t >= 1.0:
				_phase = &"title_hold"
				_phase_timer = 0.0
		&"title_hold":
			_phase_timer += dt
			if _phase_timer >= TITLE_HOLD:
				_phase = &"title_out"
				_phase_timer = 0.0
		&"title_out":
			_phase_timer += dt
			var t: float = clampf(_phase_timer / TITLE_FADE_OUT, 0.0, 1.0)
			title_label.modulate.a = 1.0 - t
			subtitle_label.modulate.a = (1.0 - t) * 0.7
			if t >= 1.0:
				_phase = &"crawl_delay"
				_phase_timer = 0.0
		&"crawl_delay":
			_phase_timer += dt
			if _phase_timer >= CRAWL_DELAY:
				_phase = &"scrolling"
				crawl_viewport.modulate.a = 1.0
				_scroll_offset = 0.0
		&"scrolling":
			var speed: float = _scroll_speed
			if _fast_forward:
				speed *= FAST_SCROLL_MULTIPLIER
			_scroll_offset += speed * dt
			# Move the crawl text upward
			crawl_text.position.y = get_viewport_rect().size.y - _scroll_offset
			# Finish when text has scrolled off OR the song has ended
			if _scroll_offset >= _crawl_total_height or not MusicManager._music_player.playing:
				_finish()
		&"done":
			pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skip") or event.is_action_pressed("pause"):
		_finish()
	# Space or Down to fast-forward
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_DOWN:
			_fast_forward = key_event.pressed


func _finish() -> void:
	if _phase == &"done":
		return
	_phase = &"done"
	_fade_out_music()
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("navigation")


func _fade_out_music() -> void:
	if MusicManager._music_player.playing:
		var tw := create_tween()
		tw.tween_property(MusicManager._music_player, "volume_db", -80.0, MUSIC_FADE_OUT)
		tw.tween_callback(_reset_music_after_crawl)
	else:
		_reset_music_after_crawl()


func _reset_music_after_crawl() -> void:
	MusicManager.stop()
	MusicManager._music_player.volume_db = MusicManager._music_volume_db


func _get_song_duration() -> float:
	var stream: AudioStream = MusicManager._music_player.stream
	if stream and stream.get_length() > 0.0:
		return stream.get_length()
	return 0.0


func _calculate_scroll_speed() -> float:
	if _song_duration <= 0.0 or _crawl_total_height <= 0.0:
		return SCROLL_SPEED_FALLBACK
	# Time consumed by title card before scrolling begins
	var title_time: float = TITLE_FADE_IN + TITLE_HOLD + TITLE_FADE_OUT + CRAWL_DELAY
	var scroll_time: float = _song_duration - title_time - SONG_END_BUFFER
	if scroll_time <= 5.0:
		return SCROLL_SPEED_FALLBACK
	return _crawl_total_height / scroll_time


# ------------------------------------------------------------------
# Starfield
# ------------------------------------------------------------------

func _generate_stars(count: int) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for i in count:
		var star := ColorRect.new()
		var s: float = randf_range(1.0, 3.0)
		star.custom_minimum_size = Vector2(s, s)
		star.size = Vector2(s, s)
		var brightness: float = randf_range(0.3, 1.0)
		star.color = Color(brightness, brightness, brightness * randf_range(0.85, 1.0), brightness)
		star.position = Vector2(randf() * viewport_size.x, randf() * viewport_size.y)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_field.add_child(star)
		_stars.append({
			"node": star,
			"base_alpha": brightness,
			"twinkle_timer": randf_range(0.0, STAR_TWINKLE_MAX),
			"twinkle_speed": randf_range(STAR_TWINKLE_MIN, STAR_TWINKLE_MAX),
		})


func _update_stars(dt: float) -> void:
	for star_data in _stars:
		star_data["twinkle_timer"] -= dt
		if star_data["twinkle_timer"] <= 0.0:
			star_data["twinkle_timer"] = star_data["twinkle_speed"]
			var node: ColorRect = star_data["node"]
			var base_a: float = star_data["base_alpha"]
			var target_a: float = randf_range(base_a * 0.3, base_a)
			var tween := create_tween()
			tween.tween_property(node, "color:a", target_a, star_data["twinkle_speed"] * 0.5)
