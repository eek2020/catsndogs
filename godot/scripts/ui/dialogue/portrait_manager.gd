## PortraitManager — loads character portrait textures, strips the near-white
## background so the parchment shows through, and tween-highlights the active
## speaker. Owned by dialogue_ui.gd; stateless between setups.
##
## The near-white removal is O(w·h) per portrait, so results are cached
## statically by `(resource_path, hard_threshold, soft_threshold)` — first
## call pays the cost, subsequent dialogues reuse the processed texture
## (Apr-05 #7 fix, preserved across the Sprint 6a decomposition).
class_name DialoguePortraitManager
extends RefCounted


## Character portrait paths keyed by npc_id.
const CHARACTER_PORTRAITS := {
	"aristotle": "res://assets/characters/aristotle/2d/head.png",
	"dave": "res://assets/characters/dave/2d/head.png",
	"death": "res://assets/characters/npc/death/2d/head.png",
	"fairy_cartographer": "res://assets/characters/npc/fairy_cartographer/2d/portrait.png",
	"nine_lives": "res://assets/characters/crew/nine_lives/2d/portrait.png",
	"no_tail": "res://assets/characters/crew/no_tail/2d/portrait.png",
	"silky": "res://assets/characters/crew/silky/2d/portrait.png",
	"blood_paw": "res://assets/characters/crew/blood_paw/2d/portrait.png",
	"charlie": "res://assets/characters/crew/charlie/2d/portrait.png",
	"bombardier": "res://assets/characters/crew/bombardier/2d/portrait.png",
	"luna": "res://assets/characters/crew/luna/2d/portrait.png",
	"thistle": "res://assets/characters/crew/thistle/2d/portrait.png",
}


static var _processed_portrait_cache: Dictionary = {}


var _scene: Node  # Host node — used for create_tween(); the dialogue UI.


func _init(scene: Node) -> void:
	_scene = scene


# ---------------------------------------------------------------------------
# Setup: two portraits (multi-step branching dialogue)
# ---------------------------------------------------------------------------

func setup_two_portraits(
	encounter,
	protagonist_id: String,
	left_rect: TextureRect,
	left_name: Label,
	left_container: VBoxContainer,
	right_rect: TextureRect,
	right_name: Label,
	right_container: VBoxContainer,
) -> void:
	_load_portrait(left_rect, left_name, left_container, protagonist_id)

	var npc_id := ""
	for nid in encounter.npc_ids:
		if nid.to_lower() != protagonist_id:
			npc_id = nid.to_lower()
			break
	if npc_id.is_empty():
		right_container.visible = false
	else:
		_load_portrait(right_rect, right_name, right_container, npc_id)


# ---------------------------------------------------------------------------
# Setup: legacy single-portrait encounter
# ---------------------------------------------------------------------------

func setup_legacy_portrait(
	encounter,
	left_rect: TextureRect,
	left_name: Label,
	left_container: VBoxContainer,
	right_container: VBoxContainer,
) -> void:
	right_container.visible = false

	if encounter == null:
		left_container.visible = false
		return
	var npc_id := ""
	if encounter.npc_ids.size() > 0:
		npc_id = encounter.npc_ids[0].to_lower()
	var portrait_path: String = CHARACTER_PORTRAITS.get(npc_id, "")
	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		left_container.visible = false
		return
	left_container.visible = true
	left_container.modulate.a = 0.0
	var texture: Texture2D = load(portrait_path)
	if texture != null:
		texture = remove_near_white_bg(texture)
		left_rect.texture = texture
	left_name.text = npc_id.capitalize()
	var tween := _scene.create_tween()
	tween.tween_property(left_container, "modulate:a", 1.0, 0.2)


# ---------------------------------------------------------------------------
# Highlight the active speaker — fades the off-speaker to 40 % modulate.
# ---------------------------------------------------------------------------

func highlight_speaker(
	speaker_id: String,
	protagonist_id: String,
	left_container: VBoxContainer,
	right_container: VBoxContainer,
) -> void:
	var left_active: bool = speaker_id.to_lower() == protagonist_id
	var left_target: float = 1.0 if left_active else 0.4
	var right_target: float = 0.4 if left_active else 1.0

	if left_container.visible:
		var tw := _scene.create_tween()
		tw.tween_property(left_container, "modulate:a", left_target, 0.15)
	if right_container.visible:
		var tw := _scene.create_tween()
		tw.tween_property(right_container, "modulate:a", right_target, 0.15)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _load_portrait(
	rect: TextureRect, name_lbl: Label, container: VBoxContainer, character_id: String
) -> void:
	var portrait_path: String = CHARACTER_PORTRAITS.get(character_id.to_lower(), "")
	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		container.visible = false
		return
	container.visible = true
	container.modulate.a = 0.4
	var texture: Texture2D = load(portrait_path)
	if texture != null:
		texture = remove_near_white_bg(texture)
		rect.texture = texture
	name_lbl.text = character_id.capitalize()


## Make bright neutral background pixels transparent, with soft feathering.
## Result is cached by source `resource_path` so we only pay the per-pixel
## walk once per portrait per run (Apr-05 #7).
static func remove_near_white_bg(
	tex: Texture2D, hard_threshold: float = 0.91, soft_threshold: float = 0.77
) -> Texture2D:
	if tex == null:
		return tex
	var cache_key: String = _portrait_cache_key(tex, hard_threshold, soft_threshold)
	if not cache_key.is_empty() and _processed_portrait_cache.has(cache_key):
		return _processed_portrait_cache[cache_key]
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
	var processed: Texture2D = ImageTexture.create_from_image(image)
	if not cache_key.is_empty():
		_processed_portrait_cache[cache_key] = processed
	return processed


static func _portrait_cache_key(
	tex: Texture2D, hard_threshold: float, soft_threshold: float
) -> String:
	if tex == null:
		return ""
	var path: String = tex.resource_path
	if path.is_empty():
		return ""
	return "%s|%f|%f" % [path, hard_threshold, soft_threshold]
