## Player controller — 8-direction movement with animated sprite and camera follow.
## Attaches to the Player CharacterBody2D scene.
extends CharacterBody2D

@export var move_speed: float = 160.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var _direction: Vector2 = Vector2.ZERO
var _facing: String = "down"


func _ready() -> void:
	if camera:
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.0


func _physics_process(_delta: float) -> void:
	_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = _direction * move_speed
	move_and_slide()
	_update_animation()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		EventBus.exploration_event.emit({
			"type": "interact",
			"position": global_position,
			"facing": _facing,
		})


func _update_animation() -> void:
	if not sprite:
		return

	if _direction.length() > 0.1:
		# Determine facing from movement
		if absf(_direction.x) > absf(_direction.y):
			_facing = "right" if _direction.x > 0 else "left"
		else:
			_facing = "down" if _direction.y > 0 else "up"
		_play_anim("walk_" + _facing)
	else:
		_play_anim("idle_" + _facing)


func _play_anim(anim_name: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
	elif sprite.sprite_frames and sprite.sprite_frames.has_animation("idle_down"):
		if sprite.animation != "idle_down":
			sprite.play("idle_down")
