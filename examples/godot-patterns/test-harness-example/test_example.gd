extends SceneTree
## Example test harness — verifies a scene loads and basic behavior works.
## Run: timeout 30 godot --headless --write-movie screenshots/test/frame.png \
##      --fixed-fps 10 --quit-after 50 --script test/test_example.gd

var _cam: Camera2D
var _frame: int = 0

func _initialize() -> void:
	# Load the scene under test
	var scene: PackedScene = load("res://scenes/main.tscn")
	var root_node = scene.instantiate()
	root.add_child(root_node)

	# Set up test camera (overrides game camera if needed)
	_cam = Camera2D.new()
	_cam.name = "TestCamera"
	root.add_child(_cam)
	_cam.make_current()

	# Simulated input: press "move_right" after 1 second
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(func(): Input.action_press("move_right"))
	root.add_child(timer)
	timer.start()

	print("Test harness initialized")


func _process(delta: float) -> bool:
	_frame += 1

	# Ensure our test camera stays active (game cameras may re-assert)
	_cam.make_current()

	# Run assertions at specific frames
	if _frame == 30:
		var player = root.get_node_or_null("Main/Player")
		if player:
			if player.position.x > 0:
				print("ASSERT PASS: Player moved right after input")
			else:
				print("ASSERT FAIL: Player did not move right (pos.x = %s)" % player.position.x)
		else:
			print("ASSERT FAIL: Player node not found at Main/Player")

	return false  # Keep running — movie writer handles exit
