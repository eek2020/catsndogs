# GDScript Cheat Sheet

## Type Inference Rules

```gdscript
var x := 5              # OK — literal has concrete type
var x := abs(y)         # WRONG — polymorphic function returns Variant
var x: float = abs(y)   # OK — explicit type
var x = abs(y)          # OK — untyped (Variant)
var m := scene.instantiate()   # WRONG — returns Variant
var m = scene.instantiate()    # OK
var v := arr[i]         # WRONG — array access returns Variant
var v: Vector3 = arr[i] # OK
```

**Never use `:=` with:** `abs`, `sign`, `clamp`, `min`, `max`, `floor`, `ceil`, `round`, `lerp`, `smoothstep`, `move_toward`, `wrap`, `snappedf`, `randf_range`, `randi_range`, `instantiate()`, array/dict access.

## Lifecycle Order

`_init()` -> exported values -> `@onready` -> `_ready()` -> `_process()` / `_physics_process()`

## Common Patterns

```gdscript
# Timer
await get_tree().create_timer(1.0).timeout

# Deferred call (safe for physics callbacks)
set_deferred("disabled", true)
call_deferred("my_method")

# Scene change
get_tree().change_scene_to_file("res://level2.tscn")

# Instantiate
var scene: PackedScene = load("res://enemy.tscn")
var inst = scene.instantiate()  # use = not :=
add_child(inst)

# Groups
add_to_group("enemies")
get_tree().call_group("enemies", "take_damage", 10)

# Input
var dir: float = Input.get_axis("left", "right")
var vec: Vector2 = Input.get_vector("left", "right", "up", "down")
if Input.is_action_just_pressed("jump"): jump()
```

## Signal Quickref

```gdscript
signal my_signal(value: int)       # Define
my_signal.emit(42)                  # Emit
node.my_signal.connect(_handler)    # Connect
await node.my_signal                # Await
```

## Node References

```gdscript
@onready var sprite: Sprite2D = $Sprite2D     # Child node
@onready var unique: Node = %UniqueNode        # Scene-unique
get_node_or_null("Path")                       # Optional (returns null)
```

## Math (use explicit types!)

```gdscript
var speed: float = clamp(vel, 0.0, max_speed)
var health: int = min(current + heal, max_health)
var smooth: float = lerp(from, to, delta * 5.0)
var step: float = move_toward(current, target, rate * delta)
```

## Script Section Order

1. `extends` + `class_name`
2. Signals
3. `@onready` vars
4. `@export` vars
5. Private state
6. Lifecycle (`_ready`, `_process`, `_physics_process`)
7. Public methods
8. Private methods
9. Signal handlers (`_on_*`)
