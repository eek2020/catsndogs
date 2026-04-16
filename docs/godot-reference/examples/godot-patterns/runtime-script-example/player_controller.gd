extends CharacterBody2D
## res://scripts/player_controller.gd: Example player controller with movement and signals.

# --- Signals ---
signal health_changed(new_value: int)
signal died

# --- Node references (resolved at _ready) ---
@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape

# --- Exported properties ---
@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var max_health: int = 100

# --- Private state ---
var _current_health: int = 100


func _ready() -> void:
	_current_health = max_health
	# Connect signals from child nodes here, NOT in scene builders
	# Example: $HurtBox.area_entered.connect(_on_hurt_entered)


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Horizontal movement
	var direction: float = Input.get_axis("move_left", "move_right")
	if abs(direction) > 0.1:
		velocity.x = direction * speed
	else:
		# CORRECT: explicit type with move_toward (polymorphic function)
		var decel: float = move_toward(velocity.x, 0, speed * delta * 5.0)
		velocity.x = decel

	move_and_slide()

	# Flip sprite based on direction
	if sprite and velocity.x != 0:
		sprite.flip_h = velocity.x < 0


# --- Public methods ---

func take_damage(amount: int) -> void:
	_current_health -= amount
	health_changed.emit(_current_health)
	if _current_health <= 0:
		_die()


func heal(amount: int) -> void:
	# CORRECT: explicit type with min (polymorphic function)
	var new_health: int = min(_current_health + amount, max_health)
	_current_health = new_health
	health_changed.emit(_current_health)


# --- Private methods ---

func _die() -> void:
	died.emit()
	queue_free()


# --- Signal handlers ---

func _on_hurt_entered(area: Area2D) -> void:
	take_damage(10)
