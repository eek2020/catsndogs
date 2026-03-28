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
		var angle = _direction.angle()
		var new_facing = _facing
		
		# 8-way angle mapping
		if angle > -PI/8 and angle <= PI/8: new_facing = "right"
		elif angle > PI/8 and angle <= 3*PI/8: new_facing = "dr"
		elif angle > 3*PI/8 and angle <= 5*PI/8: new_facing = "down"
		elif angle > 5*PI/8 and angle <= 7*PI/8: new_facing = "dl"
		elif angle > 7*PI/8 or angle <= -7*PI/8: new_facing = "left"
		elif angle > -7*PI/8 and angle <= -5*PI/8: new_facing = "ul"
		elif angle > -5*PI/8 and angle <= -3*PI/8: new_facing = "up"
		elif angle > -3*PI/8 and angle <= -PI/8: new_facing = "ur"
		
		var is_diag = new_facing in ["dr", "dl", "ur", "ul"]
		
		# Fallback to 4-way if diagonal animation doesn't exist
		if is_diag and sprite.sprite_frames and not sprite.sprite_frames.has_animation("walk_" + new_facing):
			if absf(_direction.x) >= absf(_direction.y):
				new_facing = "right" if _direction.x > 0 else "left"
			else:
				new_facing = "down" if _direction.y > 0 else "up"
					
		_facing = new_facing
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
