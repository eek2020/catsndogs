## Bryn's Oddities — shop interior face-on encounter.
##
## Entered from `fringe_haven_3d.gd` when the player interacts with Bryn. A
## face-on fixed camera frames the 3D Bryn rig in front of a painted 2D
## backdrop (`bryns_store_backdrop.png`); a lightweight in-scene dialogue
## panel gates access to the trade overlay. First visit (checked via
## `story_flags["bryn_shop_first_visit"]`) shows a longer intro line;
## repeat visits show a short greeting.
##
## On exit (LEAVE button or ESC), stashes a doorway spawn hint on GameSession
## and `change_scene_to_file`s back to `fringe_haven_3d.tscn`.
##
## **Node3D-rooted** (not Control) so the 3D rig renders in the main viewport
## directly — same pattern as `fringe_haven_3d.gd`. An earlier Control +
## SubViewportContainer version ran into a scaling quirk on skinned meshes
## that made Bryn render tiny or outside the viewport bounds. Dialogue UI
## lives on a CanvasLayer so it still composites above the 3D view.
##
## The interior was previously built from procedural walls + shelves + jars;
## replaced with a single painted backdrop plane to match the painted portrait
## style and avoid the cost of modelling ornate shop detail in low-poly. The
## camera sits at zero pitch so the flat plane reads as 2D paint.
extends Node3D

const CHARACTER_3D_SCENE: PackedScene = preload(
	"res://scenes/characters/character_3d.tscn"
)

const FIRST_VISIT_FLAG: String = "bryn_shop_first_visit"
const MERCHANT_FACTION_ID: String = "felid_corsairs"
# Player return spawn: just south of Bryn's shop doorway in fringe_haven_3d.
# Shop centre (6, 0, -5), depth 4m → doorway at z=-3, stepping south to
# z=-2 clears her 2.5m interact radius so the prompt doesn't immediately refire.
const FRINGE_HAVEN_RETURN_POS: Vector3 = Vector3(6.0, 0.0, -2.0)

const CAMERA_ORTHO_SIZE: float = 2.6
const CAMERA_PITCH_DEG: float = 0.0
const CAMERA_DISTANCE: float = 3.0

# Painted backdrop sits at the back-wall depth. Bryn lives in front of it at
# z = -0.4; the camera looks straight on with zero pitch so the 2D paint
# reads flat (any pitch reveals the plane).
const BACKDROP_TEXTURE: Texture2D = preload(
	"res://assets/backgrounds/bryns_store_backdrop.png"
)
const BACKDROP_POS: Vector3 = Vector3(0.0, 1.4, -1.2)
# Sized to match the painted aspect (~1.8:1) and overshoot the ortho view
# (height 2.6m) so no background colour peeks past the edges.
const BACKDROP_SIZE: Vector2 = Vector2(5.2, 2.9)
# Lantern painted into the backdrop, upper-right. Keep an OmniLight3D here so
# the warm rim light on Bryn matches where the paint says light is coming from.
const PAINTED_LANTERN_POS: Vector3 = Vector3(1.6, 2.1, -1.1)

# Bryn's rig is authored small (~0.75m tall in world units at default scale),
# which looks correct in the wider outdoor camera of `fringe_haven_3d` but
# reads as tiny against the painted backdrop's human-scale shelves. Scale
# her up locally so she sits shoulder-level with the bottom shelf.
const BRYN_SHOP_SCALE: float = 2.1

var _bryn: Character3D = null

# UI (CanvasLayer-hosted so it composites above the 3D viewport).
var _panel: PanelContainer = null
var _line_label: Label = null
var _trade_btn: Button = null
var _leave_btn: Button = null
var _hud_layer: CanvasLayer = null
var _trade_overlay: Control = null


func _ready() -> void:
	MusicManager.on_state_change("trade")

	_build_environment()
	_build_interior()
	_build_bryn()
	_build_camera()
	_build_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_leave()


# ── Environment ────────────────────────────────────────────────────────

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.15, 0.10, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.75, 0.55)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)

	# Key light aimed down-left from upper-right so Bryn catches rim light on the
	# same side as the painted lantern in the backdrop. Warm tone matches the
	# lamp's glow in the art.
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(30)) * Basis(Vector3.RIGHT, deg_to_rad(-35)),
		Vector3(0, 6, 0),
	)
	key.light_color = Color(1.0, 0.88, 0.65)
	key.light_energy = 1.1
	add_child(key)


# ── Interior: painted backdrop ────────────────────────────────────────
#
# The shop interior is a single painted image on a vertical plane behind
# Bryn. An OmniLight3D sits at the painted lantern's position so Bryn picks
# up warm rim light from the same direction the art depicts.

func _build_interior() -> void:
	var backdrop_mat := StandardMaterial3D.new()
	backdrop_mat.albedo_texture = BACKDROP_TEXTURE
	# Unshaded — the paint already carries baked lighting; shading would
	# wash the warm tones out under the scene's directional key light.
	backdrop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var backdrop := MeshInstance3D.new()
	backdrop.name = "Backdrop"
	var quad := QuadMesh.new()
	quad.size = BACKDROP_SIZE
	backdrop.mesh = quad
	backdrop.position = BACKDROP_POS
	backdrop.material_override = backdrop_mat
	add_child(backdrop)

	var lantern_light := OmniLight3D.new()
	lantern_light.name = "PaintedLanternLight"
	lantern_light.light_color = Color(1.0, 0.85, 0.55)
	lantern_light.light_energy = 1.8
	lantern_light.omni_range = 4.5
	lantern_light.position = PAINTED_LANTERN_POS
	add_child(lantern_light)


# ── Bryn ──────────────────────────────────────────────────────────────

func _build_bryn() -> void:
	# Exact same pattern fringe_haven_3d uses in `_spawn_3d_npc`: StaticBody3D
	# wrapper at world position, Character3D as child at local origin. Tested
	# and proven to render Bryn at human size.
	var body := StaticBody3D.new()
	body.position = Vector3(0, 0, -0.4)
	body.rotation.y = 0.0
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	col.shape = capsule
	col.position.y = 0.8
	body.add_child(col)
	add_child(body)

	_bryn = CHARACTER_3D_SCENE.instantiate()
	_bryn.character_id = "trader_bryn"
	_bryn.autoplay = "idle"
	_bryn.model_scale = BRYN_SHOP_SCALE
	body.add_child(_bryn)
	_bryn.initialize()


# ── Camera ────────────────────────────────────────────────────────────

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAMERA_ORTHO_SIZE
	cam.current = true
	# Target roughly Bryn's chest, camera pulled straight back along +Z. Pitch
	# is held at zero so the painted backdrop reads as flat 2D — any pitch
	# would reveal the plane.
	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	var target := Vector3(0, 1.3, -0.4)
	var cam_pos := target + Vector3(0, sin(pitch) * CAMERA_DISTANCE, cos(pitch) * CAMERA_DISTANCE)
	cam.transform = Transform3D(Basis(), cam_pos).looking_at(target, Vector3.UP)
	add_child(cam)


# ── HUD ───────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUD"
	add_child(_hud_layer)

	# Compact bottom strip so the 3D scene + Bryn stay the focus. Left column
	# has the speaker name + greeting line; right column has the buttons
	# stacked so the strip can stay short.
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 24
	_panel.offset_right = -24
	_panel.offset_top = -130
	_panel.offset_bottom = -18
	_hud_layer.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_panel.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 6)
	row.add_child(text_col)

	var header := Label.new()
	header.text = "BRYN — Trader"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	text_col.add_child(header)

	_line_label = Label.new()
	_line_label.text = _greeting_line()
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line_label.add_theme_font_size_override("font_size", 13)
	_line_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	text_col.add_child(_line_label)

	var btn_col := VBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_theme_constant_override("separation", 6)
	row.add_child(btn_col)

	_trade_btn = Button.new()
	_trade_btn.text = "TRADE"
	_trade_btn.custom_minimum_size = Vector2(140, 34)
	_trade_btn.pressed.connect(_on_trade)
	btn_col.add_child(_trade_btn)

	_leave_btn = Button.new()
	_leave_btn.text = "LEAVE (ESC)"
	_leave_btn.custom_minimum_size = Vector2(140, 34)
	_leave_btn.pressed.connect(_on_leave)
	btn_col.add_child(_leave_btn)

	_trade_btn.call_deferred("grab_focus")


# First visit gets the introduction line; subsequent visits get a short one.
# Flag flips on first read so the intro never repeats in a single save.
func _greeting_line() -> String:
	var gs: GameStateData = GameSession.game_state if GameSession else null
	if gs == null:
		return "\"Oddities and curios. What can I do for you?\""
	if not gs.story_flags.get(FIRST_VISIT_FLAG, false):
		gs.story_flags[FIRST_VISIT_FLAG] = true
		return (
			"\"Well — a new face on the Haven. I'm Bryn. "
			+ "Crystals, salvage, the occasional thing I probably "
			+ "shouldn't have. Take a look — I won't bite.\""
		)
	return "\"Back again? Go on, have a rummage.\""


# ── Actions ───────────────────────────────────────────────────────────

# Trade screen is added as a child of this scene's CanvasLayer root so it
# sits above the 3D viewport and our dialogue panel. trade_screen.gd closes
# via `get_tree().current_scene.pop_overlay()`, so we expose that method
# locally to route the close back into showing the dialogue panel again.
func _on_trade() -> void:
	GameSession.open_trade_screen(MERCHANT_FACTION_ID)
	var scene: PackedScene = load("res://scenes/ui/trade_screen.tscn")
	if scene == null:
		return
	_trade_overlay = scene.instantiate()
	_hud_layer.add_child(_trade_overlay)
	if _panel:
		_panel.visible = false


func pop_overlay() -> void:
	if _trade_overlay and is_instance_valid(_trade_overlay):
		_trade_overlay.queue_free()
	_trade_overlay = null
	if _panel:
		_panel.visible = true
		if _leave_btn:
			_leave_btn.call_deferred("grab_focus")


func _on_leave() -> void:
	if GameSession:
		GameSession.pending_fringe_haven_spawn = FRINGE_HAVEN_RETURN_POS
	MusicManager.on_state_change("navigation")
	get_tree().call_deferred(
		"change_scene_to_file",
		"res://scenes/world/fringe_haven_3d.tscn",
	)
