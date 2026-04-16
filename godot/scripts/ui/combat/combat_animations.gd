## CombatAnimations — Node child of combat_ui.gd that owns the laser tween
## and ship-shake timers. Extracted from combat_ui.gd to keep the screen
## orchestrator small. Added to the scene at runtime (not authored in
## combat_ui.tscn) so the scene stays backwards-compatible.
class_name CombatAnimations
extends Node

const LASER_PLAYER_COLOR := Color(0.392, 0.784, 1.0)
const LASER_ENEMY_COLOR := Color(1.0, 0.314, 0.196)

signal hit_landed(side: String)

var _laser_beam: Line2D = null
var _laser_glow: Line2D = null
var _player_ship: TextureRect = null
var _enemy_ship: TextureRect = null

var _player_shake_time: float = 0.0
var _enemy_shake_time: float = 0.0
var _player_base_pos := Vector2.ZERO
var _enemy_base_pos := Vector2.ZERO


## Wire up the scene nodes this helper manipulates. Must be called before
## fire_laser or tick.
func bind(
	laser_beam: Line2D,
	laser_glow: Line2D,
	player_ship: TextureRect,
	enemy_ship: TextureRect,
) -> void:
	_laser_beam = laser_beam
	_laser_glow = laser_glow
	_player_ship = player_ship
	_enemy_ship = enemy_ship
	if _laser_beam != null:
		_laser_beam.visible = false
	if _laser_glow != null:
		_laser_glow.visible = false


## Update the resting position of each ship sprite. combat_ui calls this
## from its layout pass so shake offsets are applied relative to the
## correct base position.
func set_base_positions(player_base: Vector2, enemy_base: Vector2) -> void:
	_player_base_pos = player_base
	_enemy_base_pos = enemy_base


## Kick off a shake timer on one side. Accepts "player" or "enemy".
func trigger_shake(side: String, duration: float = 0.3) -> void:
	if side == "player":
		_player_shake_time = duration
	elif side == "enemy":
		_enemy_shake_time = duration


## Animate a laser beam from `start` to `target`. Colour is chosen from
## `from` ("player" or "enemy"). On hit, triggers shake on the opposite
## side and emits `hit_landed` with the target side.
func fire_laser(from: String, start: Vector2, target: Vector2, hit: bool, duration: float = 0.3) -> void:
	if _laser_beam == null or _laser_glow == null:
		return
	var color := LASER_PLAYER_COLOR if from == "player" else LASER_ENEMY_COLOR
	_laser_beam.default_color = color
	_laser_glow.default_color = Color(color.r, color.g, color.b, 0.3)
	_laser_beam.clear_points()
	_laser_glow.clear_points()
	_laser_beam.add_point(start)
	_laser_beam.add_point(start)
	_laser_glow.add_point(start)
	_laser_glow.add_point(start)
	_laser_beam.visible = true
	_laser_glow.visible = true

	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			var tip := start.lerp(target, t)
			var tail_t := maxf(0.0, t - 0.4)
			var tail := start.lerp(target, tail_t)
			_laser_beam.set_point_position(0, tail)
			_laser_beam.set_point_position(1, tip)
			_laser_glow.set_point_position(0, tail)
			_laser_glow.set_point_position(1, tip),
		0.0, 1.0, duration
	)

	if hit:
		var target_side := "enemy" if from == "player" else "player"
		tween.tween_callback(func() -> void:
			trigger_shake(target_side)
			hit_landed.emit(target_side)
		)

	tween.tween_callback(func() -> void:
		_laser_beam.visible = false
		_laser_glow.visible = false
	)


## Advance shake timers and apply offsets to ship sprite positions. Call
## from combat_ui._process(delta).
func tick(dt: float) -> void:
	_player_shake_time = maxf(0.0, _player_shake_time - dt)
	_enemy_shake_time = maxf(0.0, _enemy_shake_time - dt)
	_apply_shake()


func _apply_shake() -> void:
	if _player_ship == null or _enemy_ship == null:
		return
	if _player_shake_time > 0.0:
		var shake := Vector2(
			sin(_player_shake_time * 40.0) * 8.0,
			cos(_player_shake_time * 30.0) * 4.0
		)
		_player_ship.position = _player_base_pos + shake
	else:
		_player_ship.position = _player_base_pos

	if _enemy_shake_time > 0.0:
		var shake := Vector2(
			sin(_enemy_shake_time * 40.0) * 8.0,
			cos(_enemy_shake_time * 30.0) * 4.0
		)
		_enemy_ship.position = _enemy_base_pos + shake
	else:
		_enemy_ship.position = _enemy_base_pos
