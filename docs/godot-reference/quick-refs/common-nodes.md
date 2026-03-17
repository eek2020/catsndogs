# Common Godot Node Types

Quick reference for the most frequently used node types in Godot 4.6.

## 2D Nodes

| Node | Use Case |
|------|----------|
| `Node2D` | Base for 2D scenes, containers |
| `Sprite2D` | Static 2D image display |
| `AnimatedSprite2D` | Frame-based 2D animation |
| `CharacterBody2D` | Player/NPC movement with `move_and_slide()` |
| `RigidBody2D` | Physics-driven objects (projectiles, debris) |
| `StaticBody2D` | Immovable collision (walls, floors) |
| `Area2D` | Detection zones (triggers, pickups, damage) |
| `CollisionShape2D` | Collision boundary (child of physics bodies) |
| `Camera2D` | 2D viewport camera |
| `TileMapLayer` | Tile-based levels |
| `Path2D` + `PathFollow2D` | Movement along curves (spawn paths, rails) |
| `Line2D` | Procedural line rendering |
| `Polygon2D` | Filled polygon rendering |
| `VisibleOnScreenNotifier2D` | Detect when off-screen (auto-cleanup) |
| `NavigationAgent2D` | AI pathfinding |
| `ParallaxBackground` + `ParallaxLayer` | Scrolling backgrounds |

## 3D Nodes

| Node | Use Case |
|------|----------|
| `Node3D` | Base for 3D scenes, containers |
| `MeshInstance3D` | 3D mesh display |
| `CharacterBody3D` | Player/NPC movement |
| `RigidBody3D` | Physics objects |
| `StaticBody3D` | Immovable collision |
| `Area3D` | Detection zones |
| `CollisionShape3D` | Collision boundary |
| `Camera3D` | 3D viewport camera |
| `DirectionalLight3D` | Sun/moon light |
| `OmniLight3D` | Point light (lamps, torches) |
| `SpotLight3D` | Focused cone light |
| `WorldEnvironment` | Sky, fog, tonemapping |
| `NavigationAgent3D` | AI pathfinding |
| `VehicleBody3D` + `VehicleWheel3D` | Vehicle physics |
| `CSGBox3D` / `CSGCylinder3D` | Rapid prototyping with collision |
| `MultiMeshInstance3D` | Efficient instancing of many identical meshes |

## UI Nodes (Control)

| Node | Use Case |
|------|----------|
| `Control` | Base UI node (anchors, margins) |
| `Label` | Text display |
| `RichTextLabel` | Formatted text with BBCode |
| `Button` | Clickable button |
| `TextureButton` | Image-based button |
| `TextEdit` / `LineEdit` | Text input |
| `ProgressBar` | Health bars, loading |
| `TextureRect` | Image display in UI |
| `Panel` | Background panel |
| `VBoxContainer` | Vertical layout |
| `HBoxContainer` | Horizontal layout |
| `GridContainer` | Grid layout |
| `MarginContainer` | Padding |
| `CenterContainer` | Centering |
| `ScrollContainer` | Scrollable area |
| `TabContainer` | Tabbed panels |
| `CanvasLayer` | UI rendering layer (above game) |

## Audio

| Node | Use Case |
|------|----------|
| `AudioStreamPlayer` | Non-positional audio (music, UI sounds) |
| `AudioStreamPlayer2D` | Positional 2D audio |
| `AudioStreamPlayer3D` | Positional 3D audio |

## Animation

| Node | Use Case |
|------|----------|
| `AnimationPlayer` | Keyframe animation of any property |
| `AnimationTree` | Blend trees, state machines |
| `Tween` (via `create_tween()`) | Procedural animation in code |

## Utility

| Node | Use Case |
|------|----------|
| `Timer` | Delayed/repeating callbacks |
| `RayCast2D` / `RayCast3D` | Line-of-sight, ground detection |
| `ShapeCast2D` / `ShapeCast3D` | Wider collision queries |
| `RemoteTransform2D/3D` | Mirror transform to another node |

## Collision Shape Types

| Shape | Best For |
|-------|----------|
| `RectangleShape2D` | Boxes, platforms, characters |
| `CircleShape2D` | Balls, pickups, detection zones |
| `CapsuleShape2D` | Characters (smooth sliding) |
| `BoxShape3D` | 3D boxes, platforms |
| `SphereShape3D` | 3D balls, detection zones |
| `CapsuleShape3D` | 3D characters, vehicles on trimesh |
| `ConvexPolygonShape2D/3D` | Custom shapes (keep vertex count low) |

**Avoid** `ConcavePolygonShape` and `create_trimesh_shape()` on imported models — causes extreme performance issues on high-poly meshes.
