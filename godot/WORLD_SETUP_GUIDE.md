# World Scene Setup Guide
## Steps Requiring the Godot Editor

The following tasks have been completed by file editing and are ready in your project:
- ✅ `player.tscn` — AnimatedSprite2D wired to `aristotle_spriteframes.tres` (idle_down autoplay)
- ✅ `world.tscn` — Player instanced at (320,320), Aristotle NPC with square patrol route, Dave NPC with square patrol route, TavernEntrance door at (320,160)
- ✅ `tavern.tscn` — ExitDoor spawn_position corrected to drop player at (320,192) in world
- ✅ `resources/aristotle_spriteframes.tres` — walk_down/up/left/right (8 fps, 4 frames each) + idle_down/left (4 fps)
- ✅ `resources/dave_spriteframes.tres` — same animation set using dave_spritesheet.png

---

## 1. Paint Tiles on TileMapLayers (world.tscn and tavern.tscn)

**Open world.tscn:**
1. In the FileSystem dock, double-click `scenes/world/world.tscn`
2. In the Scene dock, select the `GroundLayer` node
3. The TileMap toolbar appears at the bottom of the viewport — click the **Paint** tool (pencil icon)
4. In the **TileSet** panel (bottom right), the `world_atlas.png` tiles will appear — the atlas has 6 terrain types: Grass, Dirt, Stone, Wall, Water, Roof
5. Hold **Shift** and click-drag to paint large areas of ground tiles
6. Switch to `DecorLayer` for decorative objects (trees, crates, furniture)
7. Switch to `RoofLayer` for building roofs (use the Roof terrain)

**Tip — use Terrain painting for auto-tiling:**
- In the TileMap tool, switch from "Tiles" tab to "Terrains" tab
- Select a terrain (e.g. Grass) and paint — it will auto-connect edges

**Repeat for tavern.tscn** (`scenes/world/tavern.tscn`) — paint interior floor tiles on GroundLayer, furniture on DecorLayer, ceiling on RoofLayer.

---

## 2. Bake NavigationRegion2D Navmesh (world.tscn and tavern.tscn)

The navmesh tells NPCs where they can walk. It must be baked after tiles are painted.

1. With `world.tscn` open, select the `NavigationRegion` node in the Scene dock
2. In the Inspector, under **NavigationPolygon**, click the dropdown and choose **New NavigationPolygon** if it's empty
3. At the top of the viewport, click **Bake NavigationPolygon** (the toolbar button that appears when NavigationRegion2D is selected)
4. Godot will auto-generate walkable polygons based on tile collision shapes — walls and obstacles are excluded automatically
5. Save the scene (`Ctrl+S`)
6. Repeat for `tavern.tscn`

**If NPCs still don't pathfind:** Make sure `NavigationServer2D` is enabled — check Project → Project Settings → Navigation → 2D.

---

## 3. Add a Transition Fade Overlay (optional but recommended)

`scene_transition.gd` looks for a `ColorRect` named `TransitionOverlay` as a direct child of each scene root. Without it, scene transitions work but skip the fade effect.

To add it to `world.tscn`:
1. Select the root `World` node
2. Add child: **CanvasLayer** — name it `HUD`
3. Inside HUD, add child: **ColorRect** — name it `TransitionOverlay`
4. In Inspector: set **Color** to `Color(0, 0, 0, 0)`, set **Layout Mode** to **Anchors**, set anchors preset to **Full Rect**
5. Set the node path — **update `scene_transition.gd`** line 73 to:
   ```gdscript
   return main.get_node_or_null("HUD/TransitionOverlay") as ColorRect
   ```
6. Repeat for `tavern.tscn`

---

## 4. Set Dave's SpriteFrames on NPCs (optional)

The NPC instances in world.tscn use the base `npc.tscn` which has no sprite_frames set by default. To add Dave's animations to the Dave NPC:

1. Open `world.tscn`, select the `Dave` node in the Scene dock
2. In the Inspector, expand the `AnimatedSprite2D` section (click the arrow next to the child node)
3. Set **Sprite Frames** → pick `dave_spriteframes.tres`
4. For `Aristotle` NPC, set it to `aristotle_spriteframes.tres`

Alternatively, open `npc.tscn` and set a default SpriteFrames there if all NPCs share one look.

---

## 5. Position Summary

| Node | Scene | Position | Notes |
|------|-------|----------|-------|
| Player | world.tscn | (320, 320) | Starting spawn |
| Aristotle NPC | world.tscn | (192, 192) | Square patrol: (192,192)→(288,192)→(288,288)→(192,288) |
| Dave NPC | world.tscn | (448, 256) | Square patrol: (448,256)→(544,256)→(544,320)→(448,320) |
| TavernEntrance | world.tscn | (320, 160) | 32×16 trigger — walks into tavern |
| Player | tavern.tscn | (160, 224) | Spawns here when entering tavern |
| ExitDoor | tavern.tscn | (160, 256) | Returns to world at (320, 192) |

---

## Spritesheet Reference

Both spritesheets share this layout (confirmed by pixel analysis):
- **Frame size:** 128×120 px per frame
- **Frames per animation:** 4 (columns at x = 132, 262, 392, 522)
- **Animation block height:** 130 px (10 px label + 120 px sprite)
- **Animation row y-positions** (block_y = 82 + index × 130):

| Index | Animation | block_y |
|-------|-----------|---------|
| 0 | walk_down | 82 |
| 1 | walk_up | 212 |
| 2 | walk_left | 342 |
| 3 | walk_right | 472 |
| 4 | walk_dl | 602 |
| 5 | walk_dr | 732 |
| 6 | walk_ul | 862 |
| 7 | walk_ur | 992 |
| 8 | run_down | 1122 |
| 13 | idle_down | 1772 |
| 14 | idle_left | 1902 |
