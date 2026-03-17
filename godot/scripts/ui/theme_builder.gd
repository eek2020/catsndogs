## Theme builder — creates the unified dark space-pirate UI theme.
## Called once at startup; the returned Theme is applied to the root Control.
class_name ThemeBuilder
extends RefCounted

# ── Palette ──────────────────────────────────────────────────────
const BG_DEEP        := Color(0.04, 0.055, 0.10, 1.0)   # #0a0e1a
const PANEL_BG       := Color(0.08, 0.11, 0.18, 0.92)   # #141b2d
const PANEL_BORDER   := Color(0.16, 0.28, 0.35, 1.0)    # #2a4858
const TEXT_NORMAL     := Color(0.78, 0.84, 0.90, 1.0)    # #c8d6e5
const TEXT_TITLE      := Color(0.94, 0.75, 0.25, 1.0)    # #f0c040 gold
const TEXT_DIM        := Color(0.50, 0.55, 0.62, 1.0)    # #808a9e
const BTN_NORMAL_BG  := Color(0.10, 0.19, 0.25, 1.0)    # #1a3040
const BTN_HOVER_BG   := Color(0.16, 0.31, 0.38, 1.0)    # #2a5060
const BTN_PRESSED_BG := Color(0.25, 0.63, 0.75, 1.0)    # #40a0c0
const BTN_DISABLED_BG:= Color(0.20, 0.20, 0.24, 1.0)    # #333340
const ACCENT_RED      := Color(0.75, 0.25, 0.25, 1.0)   # #c04040
const ACCENT_GREEN    := Color(0.25, 0.75, 0.38, 1.0)   # #40c060
const ACCENT_CYAN     := Color(0.30, 0.80, 0.90, 1.0)   # #4dcce6

const FONT_SIZE_SMALL  := 14
const FONT_SIZE_NORMAL := 18
const FONT_SIZE_LARGE  := 24
const FONT_SIZE_TITLE  := 32
const CORNER_RADIUS    := 6
const BORDER_WIDTH     := 2


static func build() -> Theme:
	var theme := Theme.new()

	# ── Default font sizes ───────────────────────────────────
	theme.set_default_font_size(FONT_SIZE_NORMAL)

	# ── Label ────────────────────────────────────────────────
	theme.set_color("font_color", "Label", TEXT_NORMAL)
	theme.set_font_size("font_size", "Label", FONT_SIZE_NORMAL)

	# ── RichTextLabel ────────────────────────────────────────
	theme.set_color("default_color", "RichTextLabel", TEXT_NORMAL)
	theme.set_font_size("normal_font_size", "RichTextLabel", FONT_SIZE_NORMAL)

	# ── Button ───────────────────────────────────────────────
	theme.set_stylebox("normal",   "Button", _make_button_style(BTN_NORMAL_BG))
	theme.set_stylebox("hover",    "Button", _make_button_style(BTN_HOVER_BG))
	theme.set_stylebox("pressed",  "Button", _make_button_style(BTN_PRESSED_BG))
	theme.set_stylebox("disabled", "Button", _make_button_style(BTN_DISABLED_BG))
	theme.set_stylebox("focus",    "Button", _make_focus_style())
	theme.set_color("font_color",          "Button", TEXT_NORMAL)
	theme.set_color("font_hover_color",    "Button", Color.WHITE)
	theme.set_color("font_pressed_color",  "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	theme.set_font_size("font_size", "Button", FONT_SIZE_NORMAL)
	theme.set_constant("h_separation", "Button", 12)

	# ── PanelContainer / Panel ───────────────────────────────
	theme.set_stylebox("panel", "PanelContainer", _make_panel_style())
	theme.set_stylebox("panel", "Panel", _make_panel_style())

	# ── CheckButton ──────────────────────────────────────────
	theme.set_color("font_color",          "CheckButton", TEXT_NORMAL)
	theme.set_color("font_hover_color",    "CheckButton", Color.WHITE)
	theme.set_color("font_pressed_color",  "CheckButton", ACCENT_CYAN)
	theme.set_font_size("font_size", "CheckButton", FONT_SIZE_NORMAL)

	# ── HSlider ──────────────────────────────────────────────
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.12, 0.15, 0.22, 1.0)
	slider_bg.set_corner_radius_all(3)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_bg)
	var slider_grab := StyleBoxFlat.new()
	slider_grab.bg_color = ACCENT_CYAN
	slider_grab.set_corner_radius_all(8)
	theme.set_stylebox("grabber_area", "HSlider", slider_grab)

	# ── VBoxContainer / HBoxContainer ────────────────────────
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 10)

	return theme


static func _make_button_style(bg_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(BORDER_WIDTH)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func _make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(CORNER_RADIUS + 2)
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(BORDER_WIDTH)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 4
	return sb


static func _make_focus_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.border_color = ACCENT_CYAN
	sb.set_border_width_all(2)
	return sb
