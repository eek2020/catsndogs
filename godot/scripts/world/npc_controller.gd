## NPC controller — state machine with patrol pathfinding and dialogue triggers.
## Attaches to an NPC CharacterBody2D scene.
extends CharacterBody2D

enum State { IDLE, PATROL, TALK }

@export var npc_id: String = ""
@export var npc_name: String = "NPC"
@export var dialogue_id: String = ""
@export var faction_id: String = ""
@export var move_speed: float = 60.0
@export var patrol_points: Array[Vector2] = []
@export var idle_duration: float = 3.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var interact_zone: Area2D = $InteractZone

var _state: State = State.IDLE
var _idle_timer: float = 0.0
var _patrol_index: int = 0
var _player_in_zone: bool = false
var _facing: String = "down"


func _ready() -> void:
	if interact_zone:
		interact_zone.body_entered.connect(_on_body_entered)
		interact_zone.body_exited.connect(_on_body_exited)
	if nav_agent:
		nav_agent.velocity_computed.connect(_on_velocity_computed)
		nav_agent.max_speed = move_speed
	if patrol_points.is_empty():
		_state = State.IDLE
	else:
		_set_next_patrol_target()


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.TALK:
			_process_talk(delta)
	_update_animation()


func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_idle_timer -= delta
	if _idle_timer <= 0.0 and not patrol_points.is_empty():
		_state = State.PATROL
		_set_next_patrol_target()


func _process_patrol(_delta: float) -> void:
	if nav_agent == null or nav_agent.is_navigation_finished():
		_state = State.IDLE
		_idle_timer = idle_duration
		return
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - global_position).normalized()
	velocity = direction * move_speed
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = velocity
	else:
		move_and_slide()
	_update_facing(direction)


func _process_talk(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_zone = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_zone = false
		if _state == State.TALK:
			_state = State.IDLE
			_idle_timer = idle_duration


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_zone and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_start_dialogue()


func _start_dialogue() -> void:
	_state = State.TALK
	# Face the player
	var player: Node2D = _find_player()
	if player:
		var to_player: Vector2 = (player.global_position - global_position).normalized()
		_update_facing(to_player)
	EventBus.encounter_triggered.emit()
	EventBus.exploration_event.emit({
		"type": "npc_dialogue",
		"npc_id": npc_id,
		"npc_name": npc_name,
		"dialogue_id": dialogue_id,
		"faction_id": faction_id,
		"position": global_position,
	})


func _find_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0] as Node2D
	return null


func _set_next_patrol_target() -> void:
	if patrol_points.is_empty() or nav_agent == null:
		return
	nav_agent.target_position = patrol_points[_patrol_index]
	_patrol_index = (_patrol_index + 1) % patrol_points.size()


func _update_facing(direction: Vector2) -> void:
	if direction.length() < 0.1:
		return
	if absf(direction.x) > absf(direction.y):
		_facing = "right" if direction.x > 0 else "left"
	else:
		_facing = "down" if direction.y > 0 else "up"


func _update_animation() -> void:
	if not sprite:
		return
	var anim_name: String
	if velocity.length() > 5.0:
		anim_name = "walk_" + _facing
	else:
		anim_name = "idle_" + _facing
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
	elif sprite.sprite_frames and sprite.sprite_frames.has_animation("idle_down"):
		if sprite.animation != "idle_down":
			sprite.play("idle_down")
