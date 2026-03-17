# Test Harness Patterns

Patterns for writing test verification scripts in Godot. Tests extend SceneTree and run headless to validate scene correctness.

## SceneTree Script Contract

Tests must `extend SceneTree` (not Node). Key details:
- `_initialize()` for setup (not `_ready()`)
- `_process(delta: float) -> bool` — return `false` to keep running
- Camera needs `_cam.current = true` to activate

## Console Assertions

Use `print("ASSERT PASS/FAIL: ...")` to verify behavioral properties that are hard to judge visually (exact positions, velocities, state changes). After capture, check stdout for any `ASSERT FAIL` lines — these must be fixed before the task is complete.

## Simulated Input

For tests needing player input, use a Timer to trigger actions:

```gdscript
    var timer := Timer.new()
    timer.wait_time = 1.0
    timer.one_shot = true
    timer.timeout.connect(func(): Input.action_press("move_forward"))
    root.add_child(timer)
    timer.start()
```

## Test Template

```gdscript
extends SceneTree

var _cam: Camera2D  # or Camera3D
var _frame := 0

func _initialize() -> void:
    # Load the scene under test
    var scene: PackedScene = load("res://scenes/main.tscn")
    var root_node = scene.instantiate()
    root.add_child(root_node)

    # Set up test camera
    _cam = Camera2D.new()
    _cam.make_current()
    root.add_child(_cam)

    # Set up simulated input if needed
    var timer := Timer.new()
    timer.wait_time = 1.0
    timer.one_shot = true
    timer.timeout.connect(func(): Input.action_press("move_right"))
    root.add_child(timer)
    timer.start()

func _process(delta: float) -> bool:
    _frame += 1

    # Verify assertions
    if _frame == 30:
        var player = root.get_node("Main/Player")
        if player.position.x > 0:
            print("ASSERT PASS: Player moved right")
        else:
            print("ASSERT FAIL: Player did not move right")

    return false  # Keep running
```

## Best Practices

- **Match test to goal** — a decoration task needs multiple camera angles; a movement task needs the camera to follow action over time
- **Don't call `quit()`** — the movie writer handles exit via `--quit-after`
- **Disable game cameras** — if the game has its own camera that re-asserts `current = true`, disable it every frame in `_process()`
- **Use `free()` not `queue_free()`** — when immediately replacing scenes, `queue_free()` blocks name reuse until frame end
