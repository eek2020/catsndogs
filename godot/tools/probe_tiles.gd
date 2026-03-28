@tool
extends SceneTree

func _init():
    var tileset = ResourceLoader.load("res://resources/world_tileset.tres")
    print("Tileset class:", tileset.get_class())
    quit()
