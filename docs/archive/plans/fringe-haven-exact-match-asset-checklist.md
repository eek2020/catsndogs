# Fringe Haven Exact-Match Asset Checklist

This checklist tracks what is needed to recreate the Fringe Haven reference with high visual fidelity in Godot using the current 32x32 atlas pipeline.

## Completed in Atlas

- Grass base and flower variants
- Dirt path base and stone/cobble path variants
- Water base and shoreline transitions
- Wood and stone bridges
- Tree canopy/trunk and hedge variants
- Stone wall variants (grey and brown)
- Roof color variants (red, grey, brown)
- Basic doors, windows, signs, lamps
- Tower roof/wall foundations

## Implemented in This Pass

- Tower kit tiles (roof caps, arched windows, battlements, tower door)
- Blacksmith kit tiles (forge mouth, anvil, forge chimney, smith sign)
- Storefront kit tiles (awning variants, display window, hanging shop sign)
- Road/curb kit tiles (straight edges, corners, T-junctions, center)

## Still Missing for True 1:1 Match

- Dedicated unique facades for each named building silhouette
- Custom statue/landmark tile set (if needed per map variant)
- Complete decorative border frame matching reference
- Full sign text rendering set for map labels
- NPC sprite style pass matching reference proportions

## Coordinate Guide (High-Impact Kits)

- Tower kit: atlas row `21`, cols `0-7`
- Blacksmith kit: atlas row `22`, cols `0-7`
- Storefront kit: atlas row `22`, cols `8-15`
- Road/curb kit: atlas row `23`, cols `0-7`

## Integration Notes

- Ensure `world_tileset.tres` includes atlas coords for rows `16-23`
- Keep `planet_surface.gd` tile constants aligned to updated atlas rows
- Use road/curb kit in `PathLayer` for town centers and plazas first
