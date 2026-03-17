# Scene-Script Coordination

Rules for coordinating scene builders and runtime scripts. Getting this wrong causes missing nodes, broken references, and signal failures.

## The Five Rules

1. **Generate scenes first** — scenes define the node hierarchy that scripts reference via `@onready`
2. **Name nodes predictably** — scripts use `@onready var x: Type = $NodeName`, so the scene builder MUST set `.name` on every node to match
3. **Attach scripts in scene builder** — use `node.set_script(load("res://scripts/foo.gd"))`
4. **Connect signals in scripts, not scenes** — signal connections go in the script's `_ready()`, NOT in the scene builder (scripts aren't instantiated at build-time)
5. **Match extends to node type** — the script's `extends CharacterBody3D` must match the node it's attached to in the scene

## Example

Scene builder creates the node:
```gdscript
# In scene builder (_initialize):
var player := CharacterBody3D.new()
player.name = "Player"                          # Script uses @onready $Player
var hitbox := Area3D.new()
hitbox.name = "Hitbox"                           # Script uses @onready $Hitbox
player.add_child(hitbox)
player.set_script(load("res://scripts/player_controller.gd"))
```

Runtime script references those nodes:
```gdscript
# In player_controller.gd:
extends CharacterBody3D                          # Matches node type
@onready var hitbox: Area3D = $Hitbox            # Matches .name from scene

func _ready() -> void:
    hitbox.body_entered.connect(_on_hitbox_body_entered)  # Signal connected here, not in scene
```

## Build Order

Scenes that instantiate other scenes must be built AFTER their dependencies. Build leaf scenes (no child scenes) first, then parents:

```bash
timeout 60 godot --headless --script scenes/build_player.gd   # leaf — no children
timeout 60 godot --headless --script scenes/build_main.gd     # parent — loads player.tscn
```
