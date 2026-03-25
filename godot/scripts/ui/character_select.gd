## Character selection screen — choose Aristotle or Dave before starting a new game.
extends Control

@onready var title_label: Label = $VBox/Title
@onready var aristotle_panel: PanelContainer = $VBox/HBox/AristotlePanel
@onready var dave_panel: PanelContainer = $VBox/HBox/DavePanel
@onready var aristotle_portrait: TextureRect = $VBox/HBox/AristotlePanel/VBox/Portrait
@onready var aristotle_name: Label = $VBox/HBox/AristotlePanel/VBox/Name
@onready var aristotle_desc: RichTextLabel = $VBox/HBox/AristotlePanel/VBox/Desc
@onready var aristotle_stats: RichTextLabel = $VBox/HBox/AristotlePanel/VBox/Stats
@onready var aristotle_btn: Button = $VBox/HBox/AristotlePanel/VBox/SelectBtn
@onready var dave_portrait: TextureRect = $VBox/HBox/DavePanel/VBox/Portrait
@onready var dave_name: Label = $VBox/HBox/DavePanel/VBox/Name
@onready var dave_desc: RichTextLabel = $VBox/HBox/DavePanel/VBox/Desc
@onready var dave_stats: RichTextLabel = $VBox/HBox/DavePanel/VBox/Stats
@onready var dave_btn: Button = $VBox/HBox/DavePanel/VBox/SelectBtn
@onready var back_btn: Button = $VBox/BackBtn


func _ready() -> void:
	aristotle_btn.pressed.connect(_on_select.bind("aristotle"))
	dave_btn.pressed.connect(_on_select.bind("dave"))
	back_btn.pressed.connect(_on_back)

	var protagonists: Dictionary = GameSession.data_loader.load_protagonists()
	_populate_panel(
		protagonists.get("aristotle", {}),
		aristotle_portrait, aristotle_name, aristotle_desc, aristotle_stats
	)
	_populate_panel(
		protagonists.get("dave", {}),
		dave_portrait, dave_name, dave_desc, dave_stats
	)

	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	aristotle_btn.grab_focus()


func _populate_panel(
	config: Dictionary,
	portrait: TextureRect,
	name_label: Label,
	desc_label: RichTextLabel,
	stats_label: RichTextLabel,
) -> void:
	if config.is_empty():
		return
	# Portrait
	var portrait_path: String = config.get("portrait", "")
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		var tex: Texture2D = load(portrait_path)
		tex = _remove_near_white_bg(tex)
		portrait.texture = tex
	# Name and faction
	name_label.text = "%s — %s" % [config.get("name", ""), config.get("title", "")]
	# Description
	desc_label.bbcode_enabled = true
	desc_label.text = "[color=#c8d0dc]%s[/color]" % config.get("description", "")
	# Stats
	var stats: Dictionary = config.get("stats", {})
	stats_label.bbcode_enabled = true
	var stat_lines: Array[String] = []
	for key in ["cunning", "leadership", "negotiation", "combat_skill", "intimidation", "stealth"]:
		if stats.has(key):
			var display_name: String = key.replace("_", " ").capitalize()
			var val: int = stats[key]
			var bar: String = "[color=#dca245]%s[/color]" % ("|".repeat(val) if val > 0 else "-")
			stat_lines.append("%s: %s" % [display_name, bar])
	stats_label.text = "\n".join(stat_lines)


func _on_select(protagonist_id: String) -> void:
	GameSession.start_new_game(protagonist_id)
	EventBus.protagonist_selected.emit(protagonist_id)
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("skill_allocation")


func _on_back() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("menu")


static func _remove_near_white_bg(
	tex: Texture2D, hard_threshold: float = 0.91, soft_threshold: float = 0.77
) -> Texture2D:
	if tex == null:
		return tex
	var image: Image = tex.get_image()
	if image == null:
		return tex
	image.convert(Image.FORMAT_RGBA8)
	var w: int = image.get_width()
	var h: int = image.get_height()
	for y in h:
		for x in w:
			var c: Color = image.get_pixel(x, y)
			var whiteness: float = minf(c.r, minf(c.g, c.b))
			if whiteness >= hard_threshold:
				image.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
			elif whiteness >= soft_threshold:
				var span: float = maxf(0.001, hard_threshold - soft_threshold)
				var alpha_scale: float = (hard_threshold - whiteness) / span
				image.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * alpha_scale))
	return ImageTexture.create_from_image(image)
