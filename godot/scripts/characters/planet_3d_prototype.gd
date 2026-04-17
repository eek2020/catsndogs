## Standalone prototype — renders a SpriteCharacter3D on a blank 2D world to
## validate that the 3D-in-2D composition looks right before touching the live
## planet_surface.gd. WASD/arrows move, the character plays Walk/Run/Idle based
## on speed, and facing follows velocity.
##
## Intentionally sparse — no tilemap, no NPCs, no interactions. Once the look
## is signed off this pattern transplants into planet_surface.gd by swapping
## `_player_sprite: Sprite2D` for a `SpriteCharacter3D` instance.
extends Control

const PLAYER_SPEED: float = 120.0
const SPRINT_SPEED: float = 220.0

var hud: Label = null
var world: Node2D = null
var camera: Camera2D = null

var _character: SpriteCharacter3D = null
var _player_pos: Vector2 = Vector2(640, 360)
var _velocity: Vector2 = Vector2.ZERO
var _current_char: String = "aristotle"


func _ready() -> void:
	initialize()


## Idempotent public init — same pattern as Character3D / SpriteCharacter3D so
## headless validators outside the normal _ready cycle can drive it directly.
func initialize() -> void:
	if _character != null:
		return
	hud = $HUD/Label
	world = $World
	camera = $World/Camera
	_spawn(_current_char)


func _process(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	var sprint := Input.is_key_pressed(KEY_SHIFT)
	var speed := SPRINT_SPEED if sprint else PLAYER_SPEED
	_velocity = input.normalized() * speed if input.length() > 0.1 else Vector2.ZERO
	_player_pos += _velocity * delta

	if _character:
		_character.position = _player_pos
		if _velocity.length() > 1.0:
			# 2D world y is down — 3D yaw around Y is from +X going CCW. Map:
			var yaw := atan2(-_velocity.x, -_velocity.y)
			_character.face_direction(yaw)
			_character.play_anim("Sprint" if sprint else "Walking")
		else:
			_character.play_anim("Idle")

	camera.position = _player_pos
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_spawn("aristotle")
			KEY_2:
				_spawn("nine_lives")
			KEY_SPACE:
				if _character:
					_character.play_anim("Jumping")


func _spawn(char_id: String) -> void:
	if _character and _character.character_id == char_id:
		return
	if _character:
		_character.queue_free()
	_current_char = char_id
	# Preload the script so this scene works under --script validators where
	# class_name registration may not yet be settled.
	var sprite_script: GDScript = preload("res://scripts/characters/sprite_character_3d.gd")
	_character = sprite_script.new()
	_character.character_id = char_id
	_character.display_size = Vector2(192, 192)
	_character.render_size = 256
	_character.autofit = true
	_character.position = _player_pos
	world.add_child(_character)
	_character.initialize()


func _refresh_hud() -> void:
	if hud == null:
		return
	hud.text = "%s · %s · pos=%s\n[1/2] switch · Shift=sprint · Space=jump" % [
		_current_char,
		(_character.current_anim() if _character else "-"),
		_player_pos.round()
	]
