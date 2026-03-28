@tool
extends SceneTree

func _init():
    var scn = ResourceLoader.load("res://scenes/ui/planet_surface.tscn")
    if not scn:
        print("Failed to load scene")
        quit()
        return
        
    var root = scn.instantiate()
    var vp = root.get_node("ViewportContainer/SubViewport/World")
    var ground = vp.get_node("GroundLayer")
    var path = vp.get_node("PathLayer")
    var decor = vp.get_node("DecorLayer")
    var roof = vp.get_node("RoofLayer")
    
    ground.clear()
    path.clear()
    decor.clear()
    roof.clear()
    
    var grass_cells = []
    for x in range(-25, 25):
        for y in range(-20, 20):
            grass_cells.append(Vector2i(x,y))
    ground.set_cells_terrain_connect(grass_cells, 0, 0)
    
    var river_cells = []
    for y in range(-20, 20):
        river_cells.append(Vector2i(-15, y))
        river_cells.append(Vector2i(-14, y))
        river_cells.append(Vector2i(-13, y))
        river_cells.append(Vector2i(-12, y))
    decor.set_cells_terrain_connect(river_cells, 0, 3)
    
    var path_cells = []
    for x in range(-15, -11):
        path_cells.append(Vector2i(x, 0))
        path_cells.append(Vector2i(x, 1))
    for x in range(-11, 20):
        path_cells.append(Vector2i(x, 0))
        path_cells.append(Vector2i(x, 1))
    for y in range(-15, 15):
        path_cells.append(Vector2i(0, y))
        path_cells.append(Vector2i(1, y))
        path_cells.append(Vector2i(10, y))
        path_cells.append(Vector2i(11, y))
    path.set_cells_terrain_connect(path_cells, 0, 2)
    
    var tavern_cells = []
    for x in range(-8, -2):
        for y in range(-6, -1):
            tavern_cells.append(Vector2i(x, y))
    decor.set_cells_terrain_connect(tavern_cells, 0, 4)
    var tavern_roof = []
    for x in range(-9, -1):
        for y in range(-7, 0):
            tavern_roof.append(Vector2i(x,y))
    roof.set_cells_terrain_connect(tavern_roof, 0, 5)
    
    var smith_cells = []
    for x in range(13, 19):
        for y in range(-5, -1):
            smith_cells.append(Vector2i(x, y))
    decor.set_cells_terrain_connect(smith_cells, 0, 4)
    var smith_roof = []
    for x in range(12, 20):
        for y in range(-6, 0):
            smith_roof.append(Vector2i(x, y))
    roof.set_cells_terrain_connect(smith_roof, 0, 5)

    var odd_cells = []
    for x in range(3, 9):
        for y in range(-6, -1):
            odd_cells.append(Vector2i(x,y))
    decor.set_cells_terrain_connect(odd_cells, 0, 4)
    var odd_roof = []
    for x in range(2, 10):
        for y in range(-7, 0):
            odd_roof.append(Vector2i(x,y))
    roof.set_cells_terrain_connect(odd_roof, 0, 5)

    var packed = PackedScene.new()
    packed.pack(root)
    var err = ResourceSaver.save(packed, "res://scenes/ui/planet_surface.tscn")
    if err == OK:
        print("Fringe Haven scene built successfully!")
    else:
        print("Failed to save scene")
    quit()
