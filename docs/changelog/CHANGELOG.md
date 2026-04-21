# Changelog

All notable changes to the Whisper Crystals project are documented here.

Format: Each entry includes the date, phase/task reference, and summary of changes.

---

## 2026-04-21 — Sprint 7 pivot: painted backdrop replaces 3D cutscene rendering

**Focus:** the post-`b6f8424` in-engine preview still read as washed-out grey — pink burn marks, flat-lit plaster, white-blown windows. Diagnosis was correct at the material level (vertex-color chains were broken), but the *goal* was wrong. The user showed concept art depicting a **painterly** look (sepia palette, volumetric smoke, hand-painted rocks, silhouetted outpost with glowing doorway). No amount of tuning low-poly box geometry with PBR textures gets to that aesthetic.

**Pivot:** stop trying to render the outpost in 3D. Use the concept art itself as a painted backdrop behind the cutscene camera — same pattern as `bryn_shop_interior` ([project_painted_backdrop_pattern.md](.)), just scaled up. 3D foreground collapses to whatever the script needs to animate (door opening, character movement, dialogue triggers).

**Changes** ([godot/scenes/cutscenes/no_tail_cutscene.tscn](godot/scenes/cutscenes/no_tail_cutscene.tscn) + one asset).

- **Concept art shipped.** `design/cutscenes/no_tail_outpost_design_1.png` (AI-gen, 3318×1280) copied into `godot/assets/cutscenes/no_tail_outpost/backdrop.png` so Godot imports it (uid `cx2tqtkuy0ydq`).
- **Backdrop node.** New `Backdrop` MeshInstance3D child of `CameraController/Camera3D` at local z=-50. `QuadMesh` size `(146, 56)` — at `fov=55°` vertical, z=-50 covers 52.1m vertical × ~93m horizontal viewport extent, so the quad is sized to over-fill with the image aspect (2.59:1) preserved. Material: `StandardMaterial3D` with `shading_mode=0 (UNSHADED)`, `albedo_texture=backdrop.png`, `disable_receive_shadows=true`, `texture_filter=3 (LINEAR_WITH_MIPMAPS)`, `extra_cull_margin=100.0`. Because the quad is a child of `Camera3D`, it follows camera rotation/translation and acts as an always-visible skybox at infinite apparent distance.
- **3D outpost hidden.** `$World/NoTailOutpost` gets `visible = false`. The entire `no_tail_outpost.glb` (181 objects, 4.6 MB, 58 materials) stops rendering. Script still traverses the subtree for the `Door` node so door-open animations keep running invisibly — harmless, and leaves the door in place for future fine-tuning.
- **Lighting re-palettised for sepia sunset.** Sun `light_color` 0.92/0.75 → 0.72/0.45 warm orange, energy 1.2 → 1.35. Fill light desaturated to warm amber `(0.55, 0.4, 0.28)` energy 0.3 (was cool blue). `Environment.ambient_light_color` `(0.25, 0.22, 0.2)` → `(0.45, 0.3, 0.22)`, energy 0.4 → 0.55. `fog_enabled=true` → `false` (the painting already carries atmospheric haze). Bloom dialled down slightly.

**Result at first iteration:** painted backdrop fills the view; dialogue UI renders over it. 3D character silhouettes / door animation remain parked until the backdrop is visually confirmed before per-shot tuning.

**What this does *not* solve yet.**

- Cutscene currently has no visible 3D foreground — `NoTail` is `visible=false` (pre-existing), `Aristotle` was never in the scene to begin with (pre-existing warning). Once the backdrop reads right, next iteration will add rim-lit character silhouettes in front of it.
- Camera animation still plays against a flat backdrop — no parallax for foreground vs. backdrop. Current `CameraController` keyframes may need tightening (no big translations) to preserve the "at infinity" illusion.
- Single painting means only one hero composition; close-up dialogue shots will need either (a) dialogue-gating of camera position (stay wide) or (b) darkening the backdrop for speaker-focused shots.

**Verification.**

- GUT headless: 256/256 green, 3.74s.
- Cutscene headless smoke-load clean; only unchanged pre-existing `Could not find 'Aristotle'` warning.
- Visual test deferred to user (mcp__godot__run_project doesn't return a viewport screenshot in this env).

---

## 2026-04-21 — Sprint 7 follow-up: texture pass on cutscene scene

**Focus:** after the step 1+2 commit (`b732088`), in-engine preview revealed the scene rendered washed-out white (ground, hills, outpost hull all flat). Root cause diagnosed via `blender-mcp`: **every stylized-flat material used a vertex-color × color-ramp × mix-RGB shader chain that does not round-trip through glTF export.** The glTF exporter's "uses vertex color?" heuristic didn't recognize the chain, so Godot received materials with plain `(0.8, 0.8, 0.8)` BSDF base color and no texture. This has been a latent issue since the Apr-17 stylized-flat pass — the Blender viewport showed warm tones but Godot has been rendering flat grey all along.

**Fix:** replace every vertex-color chain with a proper texture-based tree using the 6 Poly Haven CC0 textures shipped in Sprint 10 step 16 (grass, cobblestone, mud, plaster, wood_planks, roof_tiles). Textures packed into `no_tail_outpost.blend` so the GLB export embeds them directly.

**Materials rewritten (23 total, across `godot/assets/cutscenes/no_tail_outpost.blend`):**

- **Terrain (4).** `mat_Ground` → grass at 8× uv, warm-tan tint `(0.55, 0.42, 0.28)`. `mat_Hill` → grass at 6×, deeper rust `(0.42, 0.28, 0.22)`. `mat_Rock` → cobblestone at 5× with warm sandstone tint. `mat_LandingPad` → mud at 4× with packed-dirt tint.
- **Outpost hull (9).** Plaster tex + per-panel tint matching the Apr-17 palette — Body / Annex / Buttress all desaturated teal-grey (`0.50 / 0.55 / 0.56` → `0.42 / 0.48 / 0.50`), Vent darker, UpperStrip rust accent. Outpost_Roof + Outpost_AnnexRoof → roof_tiles tex with dark-brown tint. Antenna → near-black matte metal. AntennaTip → warm emissive `(0.9, 0.5, 0.2)` strength 2.
- **Wreckage (10).** Scout + Gunship hull/wing/nose/tail/debris/wreck use plaster tex with burnt-metal tints `(0.18-0.32)` + metallic 0.3-0.6. `_Smoke` materials → near-black alpha-blended `(0.08, 0.07, 0.06)` 0.75 alpha. `_Burn` sub-meshes keep the plaster tex with dark charring tint.
- **Door + frames (4).** Rebuilt as plain BSDF (dropping the vestigial VC chain that was overriding our BSDF inputs from the first step-1+2 pass). Same colour values as before — Door warm-brown, frames dark matte.
- **Whisper Crystal ship (5).** `mat_Whisper_Hull` → pearlescent plaster. Cockpit → dark smoky-blue plain BSDF (metallic 0.85 / rough 0.1). Nacelle → metallic blue plaster. Gear → dark metal plaster. Glow → cyan emissive `(0.3, 0.9, 1.0)` strength 4.

**Housekeeping:** purged 50 orphan datablocks (the leftover `mat_Aristotle_*` / `mat_NoTail_*` materials from step-1+2 placeholder deletion, plus other internal dupes).

**Re-exported GLB:** 1.89 MB → **4.60 MB** (6 × 1K Poly Haven textures now embedded).

**Verification.**

- Post-pass sweep: `0 materials with vertex-color chains and >0 users`. Every material that ships geometry now has a proper texture-or-plain-BSDF tree that glTF understands.
- GUT headless: **256/256 green**, 3.94s.
- `no_tail_cutscene.tscn` headless smoke-load clean; only unchanged pre-existing `Could not find 'Aristotle'` warning.

**Known limitations.** Planar-UV mapping on geometry without proper unwraps may show tiling seams. Most cutscene geometry is shot from far enough away this reads fine; close-up shots of the outpost body may need a triplanar pass in a later iteration. No attempt yet at parity with the blender viewport's stepped-toon pointiness look — we traded stylized-flat for photogrammetric textures, matching Fringe Haven's aesthetic.

---

## 2026-04-21 — Sprint 7 steps 1+2: cutscene Blender-ification

**Focus:** delete the runtime model-patching layer that `no_tail_cutscene.tscn` leaned on. All the workarounds that existed because the source `.blend` shipped without proper materials / burn marks / placeholder-character deletion are now moved *into* the `.blend`.

**.blend changes** ([godot/assets/cutscenes/no_tail_outpost.blend](godot/assets/cutscenes/no_tail_outpost.blend), edited via `blender-mcp`).

- **Door + frame materials** — `mat_Door` set to warm-brown `(0.32, 0.20, 0.11)` roughness 0.85 metallic 0.15; `mat_Door_FrameLeft/Right/Top` set to dark matte `(0.14, 0.13, 0.12)` roughness 0.95 metallic 0.1. Matches the runtime override values exactly so deleting `cutscene_scene._ready` overrides is a visual no-op. Dropped the vestigial 0.25 generic emission on all four frame materials (they shouldn't glow).
- **Door_WarningLight material** — left unchanged. Already red emissive `(1.0, 0.25, 0.15)` strength 4, which matches the runtime `_force_red_light_fixture` recipe.
- **Placeholder character meshes** — deleted all 28 `Aristotle_*` / `NoTail_*` stand-in meshes (arm/leg/head/torso/ear/etc. + rifle + tail stump). Runtime `_hide_placeholder_characters` used to hide these after load; now they're not in the export at all.
- **Door burn-mark planes** — added 5 `BurnMark_{Left,Right,Top,Bottom,Ground}` meshes parented to `Door` with emissive voronoi-textured material (`mat_Door_BurnMark`). Same offsets + sizes + albedo + emission values as the runtime `_apply_burn_marks` recipe. Used `surface_render_method = "BLENDED"` (Blender 5.x) for alpha.
- **Re-exported** `no_tail_outpost.glb`: 2.37 MB → 1.89 MB (placeholder geometry removal).

**GDScript deletions** ([godot/scripts/systems/cutscene/cutscene_scene.gd](godot/scripts/systems/cutscene/cutscene_scene.gd), [material_applicator.gd](godot/scripts/systems/cutscene/)).

- `cutscene_scene.gd`: **286 → 77 lines** (target ≤100 per Sprint 7 exit criteria). Deleted `_apply_burn_marks`, `_hide_placeholder_characters`, `_force_red_light_fixture`, `_print_tree`, the runtime Door + Door_Frame material overrides, and the `MaterialApplicator.new().apply()` call. What remains is pure wiring: find `Door`/`Aristotle`/`NoTail`, connect `CutsceneManager` / `CameraController` / `DialogueUI` / camera, forward `cutscene_finished` to `EventBus.cutscene_completed`.
- **Deleted `material_applicator.gd` (434 lines) + its `.uid`** — runtime painter that existed solely to compensate for the untextured GLB. Zero callers remain. The keyword-match rules (rock/ground/hill/wall/door/roof/antenna) are now dead-code-by-Blender-authoring.

**Net:** ~640 lines of GDScript deleted, one script file gone, one GLB shrank 20%, `.blend` carries real materials instead of runtime-painted ones.

**Verification.**

- Full GUT headless suite: `256/256 green, 27 scripts, 3972 asserts, 3.8s`. No regressions.
- `no_tail_cutscene.tscn` headless smoke-load clean: no missing-script errors, no missing-node crashes. Only warning is the pre-existing `Could not find 'Aristotle' node in the scene.` (unchanged from HEAD — the scene expects the parent to inject `$World/Aristotle`).

**Still deferred to later Sprint 7 steps.** Camera animation bake (AnimationPlayer track in `.blend` replacing `CameraController` JSON-keyed tweens), character GLB optimisation (34 MB → ≤4 MB via texture rebake — needs human artist), unify `CutsceneDialogueUI` with `dialogue_ui.gd`.

---

## 2026-04-21 — Fringe Haven campfire v2: particles, faceted rocks, textured char

**Focus:** the first campfire polish pass still read as "painted props on grass" in-screenshot — solid-cube rocks, traffic-cone flame silhouette, flat brown char disc. Second pass replaces all three without new assets. The big unlock is `GPUParticles3D` for the flame: same node count, no custom shader, genuine flicker.

- **Rocks** ([fringe_haven_3d.gd:_make_campfire_3d](godot/scripts/world/fringe_haven_3d.gd)). Swapped `BoxMesh` → `SphereMesh` with `radial_segments = 5, rings = 3` so each rock renders as a low-poly faceted lump (angular carved-stone silhouette instead of a cube). Non-uniform scale per rock (sx/sy/sz on 0.22 / 0.13 / 0.22 with ±0.03–0.05m jitter), tilt up to ±0.2rad on X/Z, reused plaster texture via triplanar at `uv1_scale = 3.0` (tight tiling reads as rock grain). Tint range shifted warmer (0.32–0.48 vs. 0.28–0.42).
- **Flame** — `GPUParticles3D` replaces the two emissive cones.
  - **Core cone** (small, 0.22m radius, 0.35m height) retained as the hot base of the fire and still registered in `_campfire_flames` so the existing `_process` scale-pulse keeps the base breathing.
  - **Particles:** `amount = 60`, `lifetime = 1.1s`, `preprocess = 0.5` so the fire is already burning on scene load. Process material: sphere emission at 0.15m radius, upward direction with 18° spread, initial velocity 0.9–1.4 m/s, slight upward gravity (+0.4). Scale curve 1.0→0.75→0.0 shrinks tongues as they rise. Colour ramp: hot orange at base → yellow-white at 35-70% life → fade to alpha 0 at end. Draw mesh is a billboarded `QuadMesh` (0.35×0.45m) with `vertex_color_use_as_albedo` so the colour ramp drives each particle's tint, unshaded + emission energy 2.2 so tongues glow without sun dependence. Explicit `visibility_aabb` so particles render when the campfire sits at the edge of frustum.
- **Charred disc** — dropped the flat brown cylinder in favour of the mud texture darkened to burn-mark tone (`albedo_color = (0.22, 0.17, 0.13)`, `albedo_texture = CC0_MUD_PATH`, `uv1_scale = (1.5, 1.5, 1.0)`). Reads as scorched earth with real surface variation.
- **Retained.** OmniLight3D flicker, log grain, stone ring layout, seeded RNG for stable rendering.
- **Launch check.** `mcp__godot__run_project` on `fringe_haven_3d.tscn` clean. Particle system initialised without shader errors. No new runtime errors; pre-existing `_build_player:829` transform warning unchanged.

**Files touched:** `godot/scripts/world/fringe_haven_3d.gd` only.

---

## 2026-04-21 — Fringe Haven chest + campfire polish

**Focus:** after the step 16 exterior material pass, the treasure chest and two campfires still read as programmer primitives ("painted box with a bauble", "donut of stones with a cone"). Pass over both without introducing new art dependencies — reuse the wood-plank and plaster textures shipped in step 16, lean on procedural variation + tweens + lighting for the lift.

- **Chest** ([fringe_haven_3d.gd:_build_chest](godot/scripts/world/fringe_haven_3d.gd)).
  - Base + lid gained `albedo_texture = CC0_WOOD_PATH` + triplanar (1.6× uv) with distinct warm-brown tints (base 0.55 / 0.35 / 0.2, lid 0.68 / 0.46 / 0.26) so the two pieces read as separate carved planks instead of one painted cuboid.
  - 4 brass corner rivets (0.09m `BoxMesh`, 0.7 metallic, 0.35 roughness) on the top corners of the base — reuses the gold-band palette to unify the metalwork. Chest silhouette now parses from across the square, not just up close.
  - New warm `OmniLight3D` (color 1.0 / 0.85 / 0.45, energy 1.2, range 3.5m) on uncollected chests so they signal "go here" from 10m away. Field tracked in `_chest_light` (declared alongside `_chest_lid` / `_chest_sparkle`).
  - `_update_chest_sparkle` now also breathes the chest light energy (`1.0 + 0.25·sin(accum·2.4)`), synced to the sparkle bauble pulse so the glow reads as one radiance source.
  - Lid-open animation: new `_animate_chest_opening()` tweens `rotation.x` (−55°) and `position` (0, 0.65, −0.1) over 0.4s via cubic ease-out, plus a parallel 0.6s fade on `_chest_light.light_energy` before hiding it. `_apply_chest_opened_visuals` retained as the snap-version for scene reloads where the chest was already opened in a prior session.
- **Campfires** ([fringe_haven_3d.gd:_make_campfire_3d](godot/scripts/world/fringe_haven_3d.gd)). Rewrote the whole function.
  - **Stone ring.** Torus removed. Replaced with 7 hand-placed scattered stone chunks (~0.22×0.15×0.22m `BoxMesh` each, radial at 0.48m with ±0.06m jitter). Each chunk rotates freely on Y and tilts up to ±0.12rad on X/Z. Albedo tinted in a narrow band (grey 0.28–0.42) so stones feel like one weathered pile, not a painted set. Seeded on `hash(pos)` so the same campfire is stable across scene reloads.
  - **Charred ground disc.** Dark scorched `CylinderMesh` (radius 0.75m, height 0.01m, albedo 0.12 / 0.09 / 0.07) sits at y=0.016 — over the grass, under the path strips (y=0.010 N-S / 0.012 E-W). Reads as "this fire has been here a while".
  - **Log grain.** `log_mat.albedo_texture = CC0_WOOD_PATH` at `uv1_scale = (4, 1)` so the wood grain runs along the cylinder length (default cylinder UV wraps once around). Warm brown tint (0.55 / 0.38 / 0.22) kept for consistency with the chest lid.
  - **Layered flame.** Outer cone unchanged (registered in `_campfire_flames` for the existing scale-pulse). Added an inner cone child (0.18m bottom radius vs. 0.35m, 0.5m height, yellow-white 1.0 / 0.9 / 0.55, emission energy 3.5 vs. outer 2.5, `TRANSPARENCY_ALPHA` at 0.9 so the two cones blend rather than showing a hard seam). Inner inherits the outer's scale pulse automatically via parent/child relationship.
- **Launch check.** `mcp__godot__run_project` on `fringe_haven_3d.tscn` booted cleanly; no new errors (only the pre-existing `_build_player:829` transform warning from prior work). All textures re-used from step 16's `assets/textures/fringe_haven/` — no new asset imports.

**Files touched:** `godot/scripts/world/fringe_haven_3d.gd` only.

---

## 2026-04-21 — Sprint 10 step 16: Fringe Haven exterior material pass

**Focus:** the outdoor ground, paths, and buildings at Fringe Haven were reading crunchy next to the painted Bryn shop interior (step 11c). Ground/paths tiled 16×16 pixel art on large planes; buildings were flat-colour `BoxMesh` with no texture. Swap in CC0 seamless textures while keeping the flat-shaded `StandardMaterial3D` approach — no PBR, no normal/roughness maps, no geometry changes.

- **Assets.** 6 CC0 Poly Haven 1K JPGs shipped to `godot/assets/textures/fringe_haven/` (~3 MB total): `grass_diff_1k.jpg` (Aerial Grass Rock), `cobblestone_diff_1k.jpg` (Cobblestone Floor 08), `mud_diff_1k.jpg` (Brown Mud 02), `plaster_diff_1k.jpg` (Plastered Wall), `wood_planks_diff_1k.jpg` (Wood Planks Grey), `roof_tiles_diff_1k.jpg` (Roof Tiles 14). Attribution listed in a new `CREDITS.txt` alongside them.
- **`_build_ground` swap.** Old code extracted a 16×16 region from `overworld_tileset_16x16.png` via `_tile_texture(coord)` and tiled at 0.5m per tile with `TEXTURE_FILTER_NEAREST`. New code loads the seamless grass JPG directly, tiles at `GROUND_TEXTURE_METRES = 4.0m` per repeat (~15 repeats across the 60m plane), filters `LINEAR_WITH_MIPMAPS`.
- **`_add_path_strip` signature change.** Parameter renamed from `tile: Vector2i` to `texture_path: String` and now loads the seamless texture directly. Stone crossroads use cobblestone; NW/SE dirt branches use mud. 2.5m per repeat (`PATH_TEXTURE_METRES`). Y-offset + draw-order fix from step 4 (N-S at y=0.010, E-W at y=0.012) preserved — intersection still has one winner.
- **Building walls + roofs textured.** `_make_building` walls gained `albedo_texture = CC0_PLASTER_PATH` + `uv1_triplanar = true` + 2m per repeat. The existing `albedo_color = (0.87, 0.75, 0.55)` stays as a warm-plaster tint multiplied against the texture. Roofs gained `albedo_texture = CC0_ROOF_PATH` + triplanar at 1.6m per repeat, with the per-building `roof_color` (reds / greens / blues / ochres) surviving as a tint — so the palette variety between buildings is preserved while surface detail lands. Doors gained wood-plank texture (albedo tint warmed from 0.32 brown → 0.58 brown so the texture reads). `_make_shop_building` walls + awning follow the same pattern.
- **Triplanar rationale.** `BoxMesh` has per-face UVs that wrap each face independently, so a single `uv1_scale` gives visibly different tiling densities on walls vs. top vs. sides. Triplanar projection gives consistent world-space tiling across all six faces (and across differently-sized buildings) without needing per-building UV tuning. Cost: extra texture samples per fragment — negligible at this scene scale (6–7 buildings, ortho camera).
- **Retained.** Pixel-art tileset (`overworld_tileset_16x16.png`) still used by tree/campfire billboards via `_tile_texture`/`_sub_texture` — those read better as crisp pixel-art sprites than seamless textures. Water patch unchanged (still a flat blue plane — proper water texture/animation deferred to a later pass).
- **Launch check.** `mcp__godot__run_project` on `fringe_haven_3d.tscn` booted cleanly; all 6 textures auto-generated `.import` sidecars on first load; no new errors. Pre-existing `_build_player` transform warning is unrelated to textures.
- **Docs.** `NEXT_STEPS.md` Sprint 10 step 16 marked **Done 2026-04-21** with full scope summary.

**Files touched:** `godot/scripts/world/fringe_haven_3d.gd`, `godot/assets/textures/fringe_haven/*` (new), `docs/NEXT_STEPS.md`.

---

## 2026-04-21 — felid_cruiser 3D ship asset: smoke test + preview swap

**Focus:** new faction-authored 3D ship model (`design/ships/3d/felid_cruiser.fbx`, 35 MB) replaces the generic placeholder in the 2.5D ship preview scene. First game-specific 3D ship asset.

- **Asset mirrored** to `godot/assets/ships/3d/felid_cruiser.fbx` (+ auto-extracted embedded texture `felid_cruiser_0.png`).
- **`scripts/ships/ship_3d_preview.gd` swap.** `SHIP_GLB` constant now points at the new FBX. Two FBX-export quirks handled in-code:
  - **Scale mismatch.** Model AABB is ~1.2 cm (Blender export unit confusion — likely authored in mm). New `SHIP_TARGET_SIZE = 3.0m` auto-normalises longest-axis to 3m on spawn, so the ortho camera frames it regardless of source units.
  - **Pivot offset.** FBX origin sits at Blender world zero, not geometry centre. After scaling, re-centre so AABB centroid sits at pivot origin.
- **`tools/validate_ship_preview.gd` retuned.** Old 12k-tri hard-fail guard was written around the decimated `ship_3d_gameready.glb`. Raised to a **600k-tri warn** (no hard-fail) with rationale comment: at the 512² SubViewport target, sub-pixel tris cost effectively nothing on desktop — decimation only becomes relevant if we composite 3+ ships per frame or a perf regression shows up in combat.
- **Perf read:** 495,898 tris / 311,580 verts / 1 mesh / 1 material. Single draw call. Clean topology, embedded texture came through in one pass. At 512² with one ship visible, cost is negligible on an M3/M4. Build size (~35 MB per ship) is the real constraint if we author 8 unique faction ships — decimation becomes a build-time concern before a runtime one.
- **Visual smoke test.** Launched the preview window; both front and side angles (screenshots captured during review) show the pirate-galleon silhouette reading cleanly with cannons, sails, flags, and lit stern windows at the pixel-art target surface. Texture/embedded material pass-through correct.
- **Validator run:** `PASS (tri budget OK)`. Not wired into GUT since it requires a windowed render pipeline.

**Decision:** ship as-is. Do not decimate yet. Revisit when 3+ faction ships exist or when build size crosses 100 MB. Preview scene stays as-is until live-wiring (faction-conditional ship rendering in navigation + combat) is picked up as a future task.

---

## 2026-04-21 — Sprint 10 step 13: planet_surface_3d smoke test

**Focus:** close out the last outstanding concern from step 10 — whether `planet_surface_3d.tscn` would hit the Control + SubViewportContainer invisibility bug that step 11b found for Bryn's shop. Covered both visually and with a regression test so the answer survives future changes.

- **Visual verification.** In-game screenshot confirmed the player rig (purple-hatted musketeer) and two `felid_corsair_guard` merchants render correctly on a landed procedural planet. The step-11b bug manifests specifically at close ortho scales (ortho_size 2.6, distance 3m); `planet_surface_3d` runs at ortho_size 6 / distance 18m where the SubViewportContainer pattern works without rewrite.
- **New GUT regression test.** `tests/unit/test_planet_surface_3d.gd` (4 tests, 15 asserts):
  1. *Scene instantiates with 3D world* — `SubViewportContainer → SubViewport → World (Node3D)` tree assembled after `_ready`. First place the step-11b invisibility bug would resurface.
  2. *Merchants mount as Character3D rigs* — at least one `Character3D` spawns under the world (procedural merchant placement is seed-deterministic, and Fringe Haven always seeds ≥1).
  3. *Treasure round-trip* — `collect_treasure` writes reward into `planet_inventory`, `is_treasure_cleared` flips, second collect is a no-op.
  4. *Depart flushes inventory* — `planet_system.depart(gs)` clears `current_planet_id`, empties `planet_inventory`, and merges crystals + salvage into ship inventory.
- **Code-level audit of interaction/trade paths (what the test can't cover — runtime input):**
  - `_open_merchant` → `GameSession.open_trade_screen(faction_id)` + `main_node.push_overlay("trade")`. `planet_surface_3d` is routed via `main.gd`'s `SCENES["planet"]` + `switch_scene("planet")`, so `current_scene == main.gd` and `push_overlay` works (unlike the step-11b Bryn outdoor flow which entered via `change_scene_to_file` and had no overlay stack).
  - `_collect_treasure` UI glue: lid tilts, sparkle hides, zone erases, HUD loot label refreshes. Data path covered by test #3.
- **Incidental fix — protagonists.json JSON-parse bug.** Running the smoke test surfaced `Invalid \escape` at line 120 of `data/characters/protagonists.json` (`I\'m still here` — apostrophes don't need escaping in JSON). In-game this fails silently: `data_loader.load_protagonists()` catches the parse error via `push_error` and returns `{}`, so `GameSession.create_new_game_state` falls back to `.get(key, default)` values for every protagonist field — meaning Aristotle/Dave were booting with default salvage/region/ship/rival/story-flags rather than their authored configs. Fixed by removing the backslash. Unlocks the `load_protagonists` data path in the smoke test and for real gameplay.
- **Test suite.** 256/256 green (was 252/252; +4 new).
- **Decision.** SubViewport + Control pattern is empirically fine at this camera range; no port to Node3D root needed. Step 13 marked done. Future 3D scenes with close-up ortho cameras should still follow the Node3D + CanvasLayer pattern from Bryn's shop (step 11b).

---

## 2026-04-21 — Sprint 10 step 11c: Bryn shop — painted backdrop swap

**Focus:** the procedural shop interior (walls + shelves + jars built from boxes and cylinders) was reading as low-poly greybox; swapped it for a painted 2D backdrop behind the 3D Bryn rig to match the painted portrait style.

- **Painted backdrop.** `design/background/bryns_store_idea.png` (ornate steampunk shop wall with astrolabe, crystals, potions, sextants) copied into `godot/assets/backgrounds/bryns_store_backdrop.png`. Rendered on a vertical `QuadMesh` (5.2m × 2.9m) behind Bryn at z=-1.2, unshaded so the baked paint lighting stays punchy.
- **Procedural geometry removed.** Deleted back wall + side walls + floor plane + two shelves + ten jar/crate meshes + the 3D hanging lamp mesh. `_make_box` and `_add_jar` helpers gone. Interior build reduced from ~90 lines to ~25.
- **Lighting matched to the paint.** Key `DirectionalLight3D` swung to upper-right (yaw +30°, pitch -35°) with a warmer tint (0.88, 0.65 G/B) so Bryn's highlights come from the same direction as the painted lantern. `OmniLight3D` kept at the painted lantern's position (1.6, 2.1, -1.1) for close-range rim light on Bryn.
- **Camera pitch zeroed.** `CAMERA_PITCH_DEG` 6° → 0°. Any pitch on a flat backdrop reveals that it's a plane; straight-on keeps the 2.5D illusion.
- **Bryn scaled 2.1×.** First render showed Bryn at ~0.75m — authored small because `trader_bryn`'s Mixamo-baseline FBX lands tiny in world units, which reads fine in the wider outdoor camera of `fringe_haven_3d` but made her look shrunken next to the painting's human-scale shelves. `BRYN_SHOP_SCALE = 2.1` applied locally via `Character3D.model_scale` before `initialize()` so she sits shoulder-level with the bottom shelf. Rig scale unchanged elsewhere.
- **Rationale.** Modelling this ornate a wall in low-poly would be days of work and clash with the stepped-toon aesthetic elsewhere. Painted backdrop is strictly better for a non-interactive shop room, and aligns with the portrait style already in-game.

**Known limitations:**

- Shop is effectively a 2.5D vignette — camera and Bryn don't translate. Acceptable since the shop has no interactive objects.
- Backdrop assumes 1280×720 display; if the orthographic size ever widens the 5.2×2.9 plane may need resizing to preserve aspect.

---

## 2026-04-21 — Sprint 10 step 11b: Bryn shop — Node3D rewrite + layout polish

**Focus:** the step 11 shop interior shipped with a hidden blocker — Bryn didn't render. End-of-session rewrite + layout polish so the shop reads cleanly.

- **Control + SubViewport pattern rejected.** The original step-11 shop used a `Control` root with a `SubViewportContainer` hosting the 3D (same trick as `planet_surface_3d.tscn`). On this scene's close-up ortho camera, Bryn's Character3D rig consistently rendered invisible — debug print showed the mesh loaded at `global_position=(0, 0, -0.4)` with expected AABB, but the skinned mesh never appeared in frame. Setting `own_world_3d = true` on the SubViewport got her partially visible but at the wrong scale. Tried various scale/yaw/camera tweaks — all dead ends. **Rewrote the scene as Node3D root** matching the pattern from `fringe_haven_3d.gd`, with dialogue panel moved onto a CanvasLayer. Rig renders correctly.
- **Scene + script refactor.** `bryn_shop_interior.tscn` root is now `Node3D`, `bryn_shop_interior.gd` now `extends Node3D`. Removed `SubViewportContainer` / `SubViewport` plumbing. HUD root is a `CanvasLayer` directly parented to the scene. Trade overlay still instantiated as a direct child of the CanvasLayer so `pop_overlay()` routes it back to the dialogue panel on close.
- **Counter occlusion fix.** With the close ortho camera (distance 3m, ortho_size 2.6), the waist-high counter sitting between camera and Bryn occluded her entire silhouette. Removed the counter + foreground wares entirely — the back-wall shelves alone carry the "trader behind the counter" read.
- **Shelf layout polish.** Lowered shelves (waist + shoulder level) so they frame Bryn's upper body rather than riding above her head. Shrunk jars/bottles/crates ~60% so they read as shop stock rather than cathedral columns. Removed the warm floor-spot cylinder behind Bryn (she pops against the back wall fine without it).
- **Compact dialogue strip.** Dialogue panel is now a 112px bottom strip (was ~180px). Two-column layout: speaker name + greeting text on the left, buttons stacked on the right. Font sizes dropped to 16 (header) / 13 (body) so the 3D scene + Bryn stay the focus.
- **Camera pulled in.** Distance 3m, ortho_size 2.6, pitch 6° — tighter close-up of Bryn from the waist up so she fills the frame rather than sitting as a small figure.

**Incidental fix (step 10 carry-over):** Interact+trade from Bryn in the *outdoor* `fringe_haven_3d` scene had never actually opened a trade panel — `_open_merchant` called `current_scene.push_overlay("trade")`, but `current_scene` on a scene entered via `change_scene_to_file` is the outpost itself, which has no overlay stack. The new flow swaps `fringe_haven_3d._open_merchant` to `change_scene_to_file("bryn_shop_interior.tscn")`, which always works.

**Known issues deferred to next session:**
- **DualSense / Bluetooth gamepad input doesn't work.** `project.godot`'s input map has no joypad events bound — every `interact`/`sprint`/movement action is keyboard-only. Needs an audit + joypad_button/axis additions for the full action set.
- **`planet_surface_3d.tscn` never smoke-tested.** It uses the same Control + SubViewportContainer pattern that failed for bryn_shop. May have the same rig-invisible bug once a character3D lands on a procedural planet. Next session: either verify it works or port it to Node3D root like bryn_shop.
- **Shop interior has no walls visible from the close camera.** The side/back walls are outside the frame now that the camera pulled in. Shop still reads as an interior because of the warm backdrop, but if the ortho size ever widens the walls need reconsidering.

---

## 2026-04-21 — Sprint 10 step 11: Bryn shop face-on dialogue + trade

**Focus:** turn interacting with Bryn into a mini-encounter instead of an overlay pop. New dedicated interior scene with a face-on camera, short dialogue, and trade gated behind a button — template for future named-vendor hubs.

- **New scene.** `godot/scenes/world/bryn_shop_interior.tscn` + `godot/scripts/world/bryn_shop_interior.gd`. Control-rooted (same SubViewportContainer trick as `planet_surface_3d.tscn`) hosting a 3D close-up of Bryn behind her counter with shelves/wares/warm lamp. Fixed ortho camera at pitch 15° / ortho_size 3.4 / distance 5.
- **Dialogue panel.** Lightweight CanvasLayer-adjacent PanelContainer (not the encounter-based `DialogueUI` — that would be overkill for a greeting). Shows Bryn's name, a line of greeting, and two buttons: `TRADE` and `LEAVE (ESC)`.
- **First-visit intro.** `story_flags["bryn_shop_first_visit"]` gates a longer introduction line (Bryn introduces herself) vs. a short repeat-visit greeting. Flag is set on first read so the intro never fires twice.
- **Trade flow.** `TRADE` instantiates `trade_screen.tscn` as a direct child of the shop scene (bypasses `main.gd`'s overlay stack, which isn't on the tree during any `change_scene_to_file`-entered scene). The shop exposes a local `pop_overlay()` method so `trade_screen.gd`'s close handler routes back into the dialogue panel instead of no-opping. Dialogue panel hides while trade is open, restores on close.
- **Enter + leave.** `fringe_haven_3d.gd` `_open_merchant` now calls `change_scene_to_file("res://scenes/world/bryn_shop_interior.tscn")` (matches how fringe_haven is reached from navigation). On LEAVE/ESC the shop stashes `GameSession.pending_fringe_haven_spawn = Vector3(6, 0, -2)` and `change_scene_to_file`s back — `fringe_haven_3d._build_player()` reads+clears the stash so the player re-enters standing outside Bryn's doorway instead of at the crossroads.
- **GameSession seam.** New `pending_fringe_haven_spawn: Vector3` field on `GameSession` — the minimal shared state needed so two independently-loaded scenes can agree on where to respawn the player. Defaulting to `Vector3.ZERO` means "use default spawn".
- **Bug fix along the way.** Bryn's trade overlay *in the outdoor scene* has never actually worked since fringe_haven_3d landed — `_open_merchant` called `current_scene.push_overlay("trade")` but fringe_haven_3d doesn't have that method (main.gd was nuked by `change_scene_to_file` from navigation). The new shop-interior flow is the first working trade path for Bryn.

**Deferred:**
- Portrait art for Bryn in the dialogue panel (right now the face-on 3D rig *is* the portrait). Could layer a painted portrait in the panel later.
- Multi-line typewriter reveal on the greeting — currently just a static Label. Not worth adding until the dialogue branches.
- Applying the same template to other named vendors (Blacksmith, Tavern). Pattern is in place; each one just needs its own interior scene + greeting copy.

---

## 2026-04-21 — Sprint 10 step 10: Procedural `planet_surface` 3D port

**Focus:** retire the 2D `planet_surface.tscn` flow for every non-Fringe-Haven planet. The player now lands on a procedural 3D outpost that shares the visual language + movement feel of Fringe Haven 3D, but reads live planet data (merchants + treasures) and routes depart through the real `planet_system.depart(gs)` pipeline.

- **New scene.** `godot/scenes/world/planet_surface_3d.tscn` (Control root) + `godot/scripts/world/planet_surface_3d.gd`. Control-rooted rather than Node3D because `main.gd`'s `SceneContainer` expects every registry value to resolve to a Control — interior uses a `SubViewportContainer` + `SubViewport` wrapping the 3D world.
- **Main registry swap.** `main.gd` `SCENES["planet"]` now points at `res://scenes/world/planet_surface_3d.tscn`. The old 2D scene + controller (`scenes/ui/planet_surface.tscn`, `scripts/ui/planet_surface.gd`) are kept untouched as design reference for the tile-layout vocabulary; nothing runtime references them any more.
- **Procedural layout seeded on `planet_id`.** `hash(planet_id)` seeds three RNGs (buildings, trees, merchant/treasure placement) so each planet has a distinct but consistent silhouette. 4–8 buildings placed outside a 3.5m crossroads keepout, 16–26 trees ringed around the outer radius, NPCs/treasures clustered inside the play area with ≥2.2m spacing.
- **Player + camera.** Same pattern as `fringe_haven_3d.gd` — CharacterBody3D wrapping a `Character3D` rig for the active protagonist, ortho camera at pitch 55° / yaw 0° / ortho_size 6 / distance 18, camera-relative WASD, Shift to sprint.
- **Merchants.** Read from `_planet.merchants`. Each rendered as a `felid_corsair_guard` Character3D rig (the one full pipeline we know is wired) with a billboarded name label; interacting opens `GameSession.open_trade_screen(merchant.faction_id)` + `main.push_overlay("trade")`. Merchant metadata is cached by interact-zone id so the dispatcher can route the correct faction without string lookups.
- **Treasures.** Read from `_planet.treasures`. Each rendered as the Fringe-Haven chest primitive (base + tilt-on-open lid + golden band + emissive sparkle). `GameSession.planet_system.is_treasure_cleared` sets initial opened/closed state (so chests persist across scene re-entry); on collect, `planet_system.collect_treasure` returns `{name, reward_crystals, reward_salvage}`, lid rotates -55°, sparkle hides, zone drops, flash + loot counter update.
- **Depart.** ESC (and the legacy `pause` binding) calls `planet_system.depart(gs)` to flush `planet_inventory` into the ship, then `switch_scene("navigation")`. Distinct from Fringe Haven 3D which deliberately skips `depart()` because it's a hand-authored hub not reached via `planet_system.land_on`.
- **HUD.** Centred planet name, top-right loot counter (`Loot: %dC %dS` from `gs.planet_inventory`), fixed depart/run hint, proximity-gated `[E] Interact` hint, centred flash.
- **Oakhaven left alone.** The 2D `oakhaven_outpost.tscn` was never routed through any runtime code path — it's design reference only. The procedural 3D port now covers every planet landing the game reaches.

**Deferred:**
- Per-faction merchant rigs (right now every procedural merchant visually reads as a felid corsair guard, whatever their faction). Blocked on Mixamo anims for the other faction NPCs.
- Named-location hubs (like Fringe Haven) for Oakhaven and other story-critical planets — those will use hand-authored 3D scenes rather than this procedural one, following the Fringe Haven pattern.
- Terrain biomes per planet (the current grass is flat neutral). Cheap win once we add a `planet.biome` → material lookup.

---

## 2026-04-21 — Sprint 10 step 9: Bryn's shop 3D interior

**Focus:** turn Bryn's Oddities from an empty walls-and-counter shell into a stocked interior the player walks into.

- **Side-wall shelves.** Two plank rows each on the left and right interior walls (y=0.9m and 1.5m), stocked with procedural jars (green ceramic) and bottles (red glass) plus a few wooden crates. Asymmetric stocking on the two sides so it doesn't read as mirrored.
- **Counter wares.** Three jars + a small crate sit on the counter top (y=1.0m), framing Bryn.
- **Stock-room overflow.** Three floor crates tucked in the back corners under the shelves — implies the shop is active.
- **Stool behind counter.** Cylinder seat on a thin leg at (-1.8, 0.58, back-0.4). Suggests "Bryn's post" without her actually sitting on it.
- **Doorway rug.** Red plane (1.6×1.2m) just inside the 1.2m doorway at y=0.025 — colour-pops the threshold and signals "you're inside now" as the player crosses through.
- **Second ceiling lamp.** Added above the doorway (matching the counter lamp but energy 1.2 / range 4.5m) so the entry area isn't dimmer than the back of the shop.

All props are visual-only — the player still only collides with walls + counter (already in place from step 6). Open-top storefront is preserved so the 3/4 camera reads everything without needing roof transparency tricks.

---

## 2026-04-21 — Sprint 10 step 7: Fringe Haven 3D registry swap + Bryn Mixamo anims

**Focus:** flip the Fringe Haven landing path from the old 2D outpost to the new 3D scene, and light up Bryn's Mixamo animations now that the files landed.

- **Registry swap (minimal).** `navigation.gd:FRINGE_HAVEN_SCENE_PATH` and `star_map_screen.gd:WORLD_SCENE_MAP["starting_realm"]` now point at `res://scenes/world/fringe_haven_3d.tscn`. The old `fringe_haven_outpost.tscn` is kept unchanged as a design reference for future 3D planet builds (Oakhaven + procedural `planet_surface` still ahead). Tavern ExitDoor's stale `target_scene_path` is parked — the 3D outpost has no tavern warp (shop doorway is open, no scene transition), so nothing loads `tavern.tscn` from the 3D flow.
- **Bryn animations shipped.** `trader_bryn_anim_{idle,walk,run,jump,laugh}.fbx` added to `godot/assets/characters/npc/trader_bryn/3d/animations/` (copied from design assets). Fixed a stray double-underscore on the walk FBX (`_anim__walk` → `_anim_walk`) so `Character3D` can find it via the standard `<char>_anim_<name>.fbx` lookup. Bryn will now idle/walk/laugh in-scene instead of T-posing.
- **Test hygiene.** Added `"sprint"` to `InputRebindViewModel.REBINDABLE_ACTIONS` so the `test_rebindable_actions_list_covers_all_project_actions` coverage test matches `project.godot` (was red after Sprint 10 step 6 added the action). GUT: 252/252 green.

**Deferred:**
- 3D interior for Bryn's shop (the current `_make_shop_building` is an exterior shell; entering it is still an illusion — the player walks up to a counter visible through the open doorway). Will slot in once Oakhaven's 3D port lands and we know what we want the interior loop to feel like.
- Oakhaven + procedural `planet_surface` 3D ports (same pattern as this swap).
- Eventual cleanup of unreferenced 2D outpost scripts once all planets are 3D — scenes stay as design reference.

---

## 2026-04-20 — Sprint 10 step 6: trader Bryn + shop interior + camera/movement polish

**Focus of the session:** wire the new `trader_bryn` FBX rig into Fringe Haven as a vendor you can walk up to inside her shop, fix the broken interact triggers, add a sprint control, and align movement with the screen axes.

- **New NPC: Bryn.** `trader_bryn` registered in `Character3D.CHARACTER_BASES` (`scripts/characters/character_3d.gd:34`). FBX baseline + `.import` sidecar live at `godot/assets/characters/npc/trader_bryn/3d/`. No Mixamo animations yet — rig displays T-pose idle; drop `trader_bryn_anim_<name>.fbx` files into `3d/animations/` to light up idle/walk/run/jump/laugh.
- **Shop interior (`_make_shop_building`).** New helper next to `_make_building` in `fringe_haven_3d.gd`. Replaces Bryn's Oddities' single solid box with four wall segments framing a 1.2m front doorway. Interior gets: wooden plank floor, shopkeeper counter (BoxMesh + collider) against the back wall, warm emissive lamp + OmniLight overhead, and an awning strip replacing the pitched roof so the 3/4 camera can read the vendor through an open top. Building bumped to 5.5 × 4.0 × 2.2h after playtest showed the 4.0 × 3.0 version clipping the camera into Bryn.
- **Bryn placement + vendor spot.** Stands at (6, 0, -5.4) facing +Z, in front of the counter. Warm emissive cylinder at her feet (radius 0.55, unshaded) serves as both a readability cue and a fallback in case the rig's albedo loads weirdly.
- **Interaction fix (distance poll).** Area3D + `body_entered` was unreliable on the procedural scene (neither chest nor Bryn prompts fired). Replaced with a per-physics-tick XZ-distance poll: `_attach_interact_zone` now registers entries in `_interact_points: Dictionary` and returns a stable id; `_poll_interact_zones()` rebuilds `_active_zones` each tick by comparing player XZ to each point. Chest `_collect_chest` drops its own id from `_interact_points` so the prompt clears. `INTERACT_RADIUS` bumped 2.0 → 2.5m so the shop prompt fires as you step through the doorway.
- **Sprint control.** New `sprint` input action in `project.godot` (Shift / gamepad L3). `fringe_haven_3d.gd` picks `SPRINT_SPEED=4.5` when held vs. `MOVE_SPEED=1.8` otherwise; anim state picks `run` when sprinting and falls back to `walk` if the rig has no run clip. HUD hint updated to `"DEPART — ESC     RUN — SHIFT"`.
- **Walk speed calibrated.** Reduced `MOVE_SPEED` 4.0 → 1.8 m/s so the Mixamo walk cycle matches foot travel (no more skating). Sprint covers the old travel speed.
- **Camera yaw aligned.** `CAMERA_YAW_DEG` 30 → 0 so W = screen-up, D = screen-right. Paths and buildings now render axis-aligned. No world-geometry rotation needed.

---

## 2026-04-20 — Sprint 10 step 5: Fringe Haven 3D interactions

**Step 5 of the Fringe Haven 3D build.** Port the hub's interaction loop (merchant, treasure, depart) onto the new 3D scene, plus a small HUD layer so the player can see what's intractable without leaving the scene.

- **Area3D interaction zones.** Instead of a per-frame distance loop (the pattern the 2D `planet_surface.gd` uses), each interactable spawns a sphere `Area3D` (radius 2.0m, centred at y=0.8 so it overlaps the player capsule's midsection). `body_entered`/`body_exited` maintain `_active_zones: Dictionary` keyed by the area's instance id; `_try_interact()` picks the first entry when the `interact` action fires. Clean inversion of the "scan every frame" approach and gives us free support for multiple concurrent zones without coupling them.
- **Merchant — Bryn.** Third NPC in `_build_npcs()` is tagged `InteractKind.MERCHANT` (new enum on the controller). On interact: `GameSession.open_trade_screen("felid_corsairs")` + `main.push_overlay("trade")`, matching the `station_screen.gd`/`planet_surface.gd` flow exactly. Label updated to "BRYN — trade" so the prompt is discoverable before you walk up.
- **Treasure chest.** Procedural 3D chest at (-14, 0, 7) — `BoxMesh` base + tilted lid + golden-band detail + an unshaded emissive sparkle sphere that pulses via `_update_chest_sparkle()` (sine on both scale and y). `StaticBody3D` + `BoxShape3D` (0.95 × 0.75 × 0.65) collider wraps the base+lid bounds so the player can't walk through it (the Area3D trigger is `monitoring=true, monitorable=false` and doesn't block — the physical collider is separate). First interact: `+25 crystal_inventory`, `+10 salvage`, sets `story_flags["fringe_haven_chest_opened"]`, tilts the lid 55° back and hides the sparkle. Re-entering the scene with the flag set builds the chest in the opened state with no Area3D.
- **HUD layer.** New `CanvasLayer` with three labels:
  - `"DEPART — ESC"` pinned top-left (fixed hint, always visible).
  - `"[E] Interact"` pinned below it, visibility gated on `_active_zones.is_empty()`.
  - Centred flash line for action feedback (`_flash(msg, duration)` with alpha fade in the last second).
- **Depart wiring.** `_on_depart()` now calls `MusicManager.on_state_change("navigation")` + `main.switch_scene("navigation")`, matching the production flow. Deliberately does **not** call `GameSession.planet_system.depart()` — Fringe Haven is a hand-authored hub entered via `navigation.gd`'s direct scene swap, not through `planet_system.land_on()`, so `planet_inventory` belongs to whatever procedural planet the player landed on last. Depart quits only when run standalone via F6.
- **`interact` input action.** Already wired in `project.godot` (line 79); no project-settings change needed.
- **Tests.** 252/252 GUT green. Editor import clean.

**Files touched:** `godot/scripts/world/fringe_haven_3d.gd` (+~260 lines: constants, state, `_build_chest`, `_build_hud`, `_attach_interact_zone`, `_try_interact`, `_open_merchant`, `_collect_chest`, `_update_hud`, `_update_chest_sparkle`, `_flash`).

---

## 2026-04-20 — Sprint 10 step 4: props + NPC rigs + z-fight fixes

**Step 4 of the Fringe Haven 3D build.** Set-dressing, NPC population, and a pass of z-fighting fixes that only became visible once real geometry sat next to each other.

- **Trees.** 14 billboarded `Sprite3D` trees around the town perimeter, pulled from `serene_village_32x32.png` via a new `_sub_texture(path, region)` + `_make_billboard(tex, pos, world_height)` helper pair. Five variants (four 2×3-tile species + one 2×2). Aspect preserved from texture pixel size; `ALPHA_CUT_DISCARD` + `SHADED = false` so they pop cleanly against the 3D terrain.
- **Campfires (procedural 3D, not sprites).** First pass used the animated 4-frame pixel strip but it clashed against the painterly-3D player and buildings. Replaced with a small procedural 3D fire per campfire: dark stone `TorusMesh` ring, three crossed brown `CylinderMesh` logs, an unshaded emissive orange flame cone, and a warm `OmniLight3D`. `_process` drives a two-sine flicker on both light energy (1.5 ± 0.55) and flame scale, with per-fire phase offsets so they don't strobe in lockstep.
- **NPCs on the real rig pipeline.** Fringe Haven is canonically controlled by `felid_corsairs` (per `planet_registry.json`), so guards should be cats. New 12th character `felid_corsair_guard` added to `CHARACTER_BASES` (assets at `godot/assets/characters/npc/felid_corsair_guard/3d/...` — first NPC to use the `npc/<id>` base, adjacent to `crew/<id>`). `_spawn_3d_npc(char_id, pos, label, yaw)` wraps each rig in a `StaticBody3D` + capsule (0.35r × 1.6h) so the player bumps into them instead of clipping through, with a billboarded `Label3D` name tag above. Two guards at the crossroads + a third NPC labelled "BRYN" outside Bryn's Oddities as a merchant placeholder.
- **Z-fight pass.**
  - *Path crossroads.* The E-W and N-S stone strips sat at the same y=0.01, so the centre tile flipped winner per frame. `_add_path_strip` now takes a `y_offset` param; N-S drawn at 0.010, E-W on top at 0.012.
  - *Building roofs.* The rotated-box roof's lowest corner was grazing the wall's top face. Formula now computes the actual lowest tilted corner (`h/2·cos(30°) + d/2·sin(30°)`) and adds a 0.15m margin instead of the earlier coarse lift.
  - *Adjacent doghouse roofs.* Four doghouses spaced 2.2m apart each had roofs 2.3m wide (with overhang), so neighbours intersected along the seam. Spacing widened to 2.6m for a clean 0.3m gap.

**Guards are from `design/charcters/npcs/felid_corsair_guard/`** — user-provided FBX baseline + 5 Mixamo clips. Copied into `godot/assets/characters/npc/felid_corsair_guard/` via the existing uniform character layout; no validator or GUT character-registry updates yet (optional next pass).

**Small cleanup:** `CHARACTER_3D_SCENE: PackedScene` const at the top of `fringe_haven_3d.gd` replaces three duplicated `preload()` calls.

GUT 252/252 green before and after.

## 2026-04-20 — Sprint 10 pivot: full 3D world (Option A) + root-motion fix

**Option B (3D-hero-in-2D-tilemap) parked permanently.** Three integration attempts failed because `SpriteCharacter3D` (SubViewportContainer as Control child of a Node2D under a Camera2D) does not inherit canvas transforms cleanly — the rendered box drifted off the player and scaled out of sync with the tilemap. Prototype code stays in-repo for UI/portrait use cases where the outer parent is a Control.

**Option A — Full 3D world (active).** New scene [godot/scenes/world/fringe_haven_3d.tscn](godot/scenes/world/fringe_haven_3d.tscn) and script [godot/scripts/world/fringe_haven_3d.gd](godot/scripts/world/fringe_haven_3d.gd). Runs under F6 during development; will swap into the scene registry once steps 4–6 land.

Shipped:

- **Step 1 — minimal scene.** WorldEnvironment (sky BG), DirectionalLight3D sun, 60m grass plane, CharacterBody3D player wrapping the existing `character_3d.tscn` rig. Ortho Camera3D at 55° pitch / 30° yaw / distance 18 / ortho_size 6, tracked via a camera-rig Node3D snapped to the player every physics frame. Camera-relative WASD: `forward = (-sin(yaw), 0, -cos(yaw))`, `right = (cos(yaw), 0, -sin(yaw))`, `input.y = up−down`. Character yaw = `atan2(v.x, v.z)`. `play_anim` only fires on state change so the clip doesn't re-seed every tick.
- **Step 2 — textured ground + paths.** `_tile_texture(col, row)` extracts a 16×16 region from `overworld_tileset_16x16.png` at startup and uses it as a tiling albedo on a PlaneMesh. Tileset coords were picked from actual pixel data (not eyeballed from the atlas — first pass landed on roof/transition tiles). Grass (10,4), dirt (0,3), cobble (7,7). Stone crossroads through origin, two dirt branches (NW + SE), blue water patch in the NW corner. `TEXTURE_FILTER_NEAREST` preserves the pixel-art look.
- **Step 3 — buildings.** `_make_building(pos, size, height, roof_color, label?)` helper builds: BoxMesh walls + StaticBody3D collider, rotated-box roof with overhang, plank door on the +Z face, optional billboarded `Label3D` with outline. Seven buildings (Tipsy Tankard, Bryn's Oddities, Blacksmith, two houses, four doghouses) placed in the four quadrants around the crossroads.

**Root-motion strip (applies to every Character3D scene).** `character_3d.gd:_strip_root_xz_motion` zeros X and Z on every `TYPE_POSITION_3D` key in every animation (Y preserved so vertical bounce still works). Mixamo walk/run clips translate the hip bone forward during the cycle — without this strip the mesh snaps back to origin every loop ("2 steps forward then skip"). World position is driven by the CharacterBody3D, not by bone translation.

Pending: step 4 (tree/campfire/NPC billboards), step 5 (interactions: merchant Area3D → trade overlay, treasure collect, depart), step 6 (scene-registry swap + port to Oakhaven and `planet_surface`).

No GUT changes — full suite 252/252 green before and after.

## 2026-04-19 — Pre-rendered cutscene pipeline (Sprint 12 style-test promoted)

Style-test sandbox (`cutscene_test/`) retired. The working pipeline has been split into authoring tools (`cutscene_pipeline/`) and shipped assets (`godot/assets/cutscenes/dave_intro/`), with a new Godot scene type (`prerendered_cutscene.tscn`) that complements the existing realtime 3D flavour (`no_tail_cutscene.tscn`).

**New pipeline — prerendered painterly cutscenes:**

- `cutscene_pipeline/blender/setup_scene.py` — reproducibly builds a Blender scene with Dave (or any character), toon-shaded (banded `ShaderToRGB` + ColorRamp) with Solidify backface outlines. All knobs at top of file.
- `cutscene_pipeline/blender/render_shots.py` — multi-shot sequencer: each entry in `SHOTS` specifies an animation FBX + camera move + duration. Cycles the Mixamo action via F-curve modifier when shot length exceeds clip length.
- `cutscene_pipeline/blender/_filter_cutscene.txt` — ffmpeg filter graph for the dialogue card (Baskerville serif on warm-black panel with alpha fade-in).

**New Godot pieces:**

- `godot/scripts/cutscenes/prerendered_cutscene_player.gd` — `PreRenderedCutscenePlayer` class. Loads a directory of PNG frames + an optional WAV, plays at configurable FPS, emits `finished` on completion or loops if toggled. Avoids Godot's stuttery Theora decoder by doing frame-indexed `TextureRect` swaps in `_process`.
- `godot/scenes/cutscenes/prerendered_cutscene.tscn` — reusable base scene with the player node + CutsceneFrame TextureRect + Audio player.
- `godot/scenes/cutscenes/dave_intro_cutscene.tscn` — first concrete instance, pointing at `assets/cutscenes/dave_intro/`.
- `godot/data/cutscenes/_registry.json` — bumped to schema v2, added `type` field (`realtime_3d` | `prerendered`). `dave_intro` registered with `arc1`, tagged `intro`/`style_test`.

**Documentation:**

- `docs/architecture/cutscenes/PRERENDERED_PIPELINE.md` — end-to-end authoring walkthrough (plan shots → generate audio → render in Blender → composite in ffmpeg → register → play). Also documents Blender 5.x gotchas (Freestyle silently unsupported on Eevee Next; compositor moved to `scene.compositing_node_group`; many classic nodes removed).

**Known limitations baked into the v1 pipeline (documented in the pipeline doc):**

- No mouth animation. AI-generated character UV atlases are fragmented (no editable mouth region), no jaw bones, no blendshapes. Painted-mouth-overlay approach was tried and abandoned — painted tongue baked into the model showed through overlays. Current stance: static painted face + dialogue card + audio is the shipping answer.
- Compositor polish layer (paper, grain, vignette) is stubbed — deferred to v2 until base look is locked.
- Outlines are silhouette-only (no interior creases). Grease Pencil Line Art would add them but is a per-character rig investment.

**Dave intro asset summary:** 144 frames @ 24fps @ 960×540 (~60 MB PNG sequence), 3.3s TTS audio (`say -v Daniel`), dialogue card with line *"Well now — a sight you do not see every solar cycle."* Shot 1: side-on walk (30 frames, root motion through frame). Shot 2: stylised 3/4 close-up idle (114 frames, cycled 96-frame action).

---

## 2026-04-19 — Character pipeline rebuild: 11 characters wired, uniform layout, 5 anims each

Yesterday's tidy-up deleted the rigged character assets and broke the live character pipeline (Aristotle's `rigged.glb`, Nine Lives' old baseline, all old `Walking.fbx`/`Idle.fbx` Mixamo FBXs, `validate_rigged_glb.gd`, `inspect_*` tools). Today rebuilds the pipeline against a fresh, uniform per-character layout and brings the full named cast (10 protagonists + crew, plus Death) into Godot.

**New on-disk shape (uniform across all characters):**

```text
design/charcters/<base>/
  2d/<char>_t_pose.png
  3d/<char>_t_pose_3d_baseline.fbx        # Mixamo "T-Pose" download (with skin)
  3d/animations/<char>_anim_idle.fbx      # Mixamo "Without Skin" anim FBXs
  3d/animations/<char>_anim_{walk,run,jump,laugh}.fbx
```

`<base>` is `aristotle`, `dave`, `death`, or `crew/<id>` for the 8 crew. Mirror at `godot/assets/characters/<base>/...`.

**Refactor — `Character3D`:**

- New `CHARACTER_BASES` dictionary covers all 11 characters; `paths_for()` derives mesh + anims + filename prefix from a single base path. Adding a character now means adding one row.
- `DEFAULT_ANIMS` → `["idle", "walk", "run", "jump", "laugh"]` (snake_case, drops `Sprint`, adds `Laugh`).
- New `anim_prefix` field resolves Mixamo files as `<anim_dir>/<char>_anim_<name>.fbx`.
- `autoplay` default lowercased to `"idle"`.

**Wired into preview / cutscene / tests:**

- `animation_preview_controller.gd`: cycles all 11 characters; keys 1–7 directly select the first 7.
- `planet_3d_prototype.gd`: anim names updated (`Sprint`→`run`, `Walking`→`walk`).
- `no_tail_cutscene.tscn`: NoTail node now instances `character_3d.tscn` (rigged + animated) instead of the deleted `source.glb`.
- `tests/unit/test_character_3d.gd` + `tools/validate_character_3d.gd` cover all 11.

**Validation:** all 11 characters resolve a Skeleton3D, build a 5-anim library, and play all 5 with **0 unmatched bone tracks**. GUT 252/252 green.

**Mixamo gotcha learned the hard way:** the T-pose baseline FBX must be downloaded with default "With Skin" — animation FBXs use "Without Skin". Easy to mix up; the validator catches it via "no Skeleton3D found on mesh".

**Bone counts (informational):** 41-bone rig (Aristotle, Dave, Luna, Thistle); 33-bone rig (Nine Lives, No Tail, Blood Paw, Silky, Death, Charlie, Bombardier). Per-character bone match is what matters; cross-character retarget is not used.

**Naming alignment:** `bombadier` → `bombardier` everywhere (matches `crew_members.json`). Folder + filenames + code references all renamed.

**Removed legacy:**

- `tools/validate_rigged_glb.gd` (CC0-UAL validator for deleted `rigged.glb`)
- `tools/inspect_3d_assets.gd`, `inspect_anim_tracks.gd`, `inspect_mesh_scale.gd`, `inspect_transforms.gd` — diagnostic scripts for the deleted CC0 pipeline; superseded by `validate_character_3d.gd`
- All `rigged.*`, `*_texture_20250901.png`, `nine_lives_t_pose_3d.fbx`, `source.glb`, `source_texture_*.png` orphans in `godot/assets/characters/...`
- `design/charcters/_pipeline/cc0_source/` and `_unused/` left untouched (archived).

**Tests:** GUT 252/252 green.

---

## 2026-04-17 — Sprint 10 kickoff: preview-scene ESC exit, anim_preview 3/4 hero framing, sprint 4/7 parked

User-directed focus shift to planet-surface basics. Sprint 4 (sprite rollout) parked pending human artist — placeholder 32×32 sheets stay in-game and the rollout moves to backlog. Sprint 7 (3D cutscene rework) parked to prioritise the planet path.

**Fixed — 3D preview scenes:**

- `animation_preview_controller.gd`: ESC now quits; default orbit yaw π/5 (3/4 hero) instead of pure side-on; camera elevation 0.7 → 1.6, target_y 0.45 → 0.55, radius 2.6 → 2.8. Removes the "floor cutting through character" look reported by the user — ground plane now reads as a pad under the character instead of a horizon line crossing the body.
- `planet_3d_prototype.gd`: ESC now quits. HUD hint updated.
- HUD strings in both scenes now advertise ESC.

**Docs:** `docs/NEXT_STEPS.md` adds Sprint 10 (planet-surface basics), marks Sprint 4 + Sprint 7 PARKED, appends parked sprite rollout to backlog.

**Tests:** GUT 252/252 green.

---

## 2026-04-17 — 3D character + ship pipeline: Mixamo animations, decimated ship, planet-surface 3D prototype

Brought the newly-added Mixamo character FBX files (Aristotle + Nine Lives, 5 animations each) and the raw 3D ship model into a reusable, game-ready pipeline. Validated end-to-end via headless Godot + GUT before wiring.

**Why this shape:** the animation FBXs are mesh-less Mixamo exports (41-bone Aristotle, 33-bone Nine Lives) each containing a single `mixamo_com` animation. Rather than hand-merge them in Blender per addition, Character3D builds an AnimationLibrary at runtime so new motions drop in as `<Name>.fbx` files.

**New — character pipeline:**

- `scripts/characters/character_3d.gd` (+ `scenes/characters/character_3d.tscn`) — reusable rigged character. Loads a T-pose mesh and aggregates per-animation FBXs into a single `AnimationLibrary` keyed by filename (Idle/Walking/Running/Sprint/Jumping). Public `initialize()` makes it headless-testable.
- `scripts/characters/sprite_character_3d.gd` — 2D-compatible wrapper: Node2D → SubViewportContainer(128²) → orthographic Camera3D → Character3D. Drops into Sprite2D slots on tilemap-based screens with matching `play_anim()` / `face_direction()` / `position` interface.
- `scripts/characters/planet_3d_prototype.gd` (+ `scenes/characters/planet_3d_prototype.tscn`) — WASD demo scene validating the 3D-on-2D composition before touching live `planet_surface.gd`. `[1]/[2]` switches character, Shift sprints, Space jumps.
- `scripts/characters/animation_preview_controller.gd` + `scenes/characters/animation_preview.tscn` — rebuilt on top of Character3D; cycles both characters through all five animations.

**Fix — track retargeting for mixed rig paths:**

Mixamo animation FBXs author track paths as `Skeleton3D:<bone>` (skeleton at scene root), but Aristotle's CC0-UAL-derived `rigged.glb` nests its skeleton at `Armature/Skeleton3D`. Without rewriting, every animation silently no-opped on Aristotle while flooding the log with `couldn't resolve track` warnings. `Character3D._retarget_tracks` now rewrites each track's NodePath to the real skeleton-relative path of the loaded mesh. Nine Lives (skeleton at root) was already compatible.

**New — ship pipeline:**

- `tools/blender-dev/decimate_for_game.py` — headless Blender tool: imports FBX/GLB, triangulates, applies Decimate to a target poly count, downscales bundled textures, exports GLB. Runs in a background Blender instance so the user's live session isn't disturbed.
- `godot/assets/ships/ship_3d_gameready.glb` — 8 000 tris / 1024² texture / **2.17 MB** (from **499 602 tris / 4096² / 37.7 MB** raw FBX). Ready to instance in gameplay.
- `scripts/ships/ship_3d_preview.gd` + `scenes/ships/ship_3d_preview.tscn` — 2.5D smoke-test scene: SubViewport(512²) with orthographic camera renders the decimated ship with a slow yaw. Proves the perf envelope before wiring into navigation/combat.

**Tests:**

- `tests/unit/test_character_3d.gd` — 5 tests: paths known, library aggregates all expected animations, every track bone exists on the skeleton, every track node-path matches the actual skeleton location (the regression guard for the Aristotle mismatch), unknown character IDs warn without crashing.
- `tools/validate_character_3d.gd`, `tools/validate_ship_preview.gd`, `tools/validate_planet_3d_prototype.gd`, `tools/inspect_3d_assets.gd`, `tools/inspect_anim_tracks.gd` — headless diagnostic scripts.
- Full GUT suite **252/252** green (was 251; +1 new retarget-path assertion).

**Follow-up fixes (same day, after first playtest):**

- *Per-character mesh rotation.* First playtest showed Aristotle rendering top-down/prone. Transform-tree inspection ([tools/inspect_transforms.gd](godot/tools/inspect_transforms.gd)) revealed his `rigged.glb` had an inner `Armature` with `rot_deg=(90°,0°,0°)` and `scale=0.01` — cm-based FBX authoring artifact from the CC0-UAL pipeline legacy. `Character3D` now accepts `mesh_rotation_deg` (per-character default in `paths_for`): Aristotle gets `Vector3(-90,0,0)` to cancel, Nine Lives stays at `Vector3.ZERO` (clean Mixamo rig already).
- *Autofit camera in SpriteCharacter3D.* Characters are ~0.95 m tall (cats/dogs), not a human 1.8 m. Default `ortho_size` of 2.2 m left them as pixels on screen. `autofit` mode now reads the mesh AABB and picks `ortho_size = max_extent * 1.15` with 3/4 hero framing (`right = 0.75×ortho`, `up = 0.30×ortho`, `back = max(2.5, 2×ortho)`). Defaults raised: `render_size 128→256`, `display_size 32²→128²`.
- *Animation preview usability.* Ground plane (6×6 m) + grid bars at 1 m intervals, so upright-on-floor is visually verifiable. Manual orbit (`A`/`D` tumble, `O` toggles auto-orbit), yaw read-out in HUD. Eliminates the "is it top-down or is the character prone" ambiguity.
- *Planet prototype spawn.* Uses `preload()` instead of `SpriteCharacter3D.new()` so `--script` validators outside the class-registration boundary can spawn it cleanly.

**Godot MCP installation:** `@coding-solo/godot-mcp@0.1.1` installed globally (`/opt/homebrew/bin/godot-mcp`), registered in `~/.claude.json` → `mcpServers.godot` with `GODOT_PATH=/Applications/Godot.app/Contents/MacOS/Godot`. Exposes editor launch, project run, console/debug capture, and basic scene ops (add node, load sprite, save). Deeper operations (AnimationTree, scene-graph surgery) continue through the `tools/validate_*.gd` / `tools/inspect_*.gd` headless-GDScript pattern. `youichi-uda/godot-mcp-pro` (paid, 162 tools) noted but not chosen. **Restart Claude Code before first use** — MCP servers are connected at session start.

---

## 2026-04-17 — Sprint 7 (partial): stylized-flat terrain + outpost building in `.blend`

Resolves the terrain-material decision parked earlier the same day. Picked **Option A (stylized flat)** — PBR packs are photogrammetry-realistic and clash with the painted 2D portraits/ships; hand-painted textures would match but need an artist. Stylized flat is the one path that coheres with the existing visual language without new art. Reworked live in Blender via `blender-mcp`.

**Changes — `godot/assets/cutscenes/no_tail_outpost.blend`:**

- **Terrain materials (`mat_Ground`, `mat_Hill`, `mat_Rock`)** rebuilt as flat warm-palette BSDF × vertex color × **stepped (CONSTANT-interpolation) Pointiness ramp** → 3-band toon shading. Fresnel-driven amber rim emission (strength 0.25). Rock shadow floor lifted (0.75/0.62/0.48) so small rock meshes don't crush to black. All metallic zeroed.
- **Hill geometry decimated** — Collapse modifier (ratio 0.18) applied across all 8 `Hill_*` meshes, 320 → ~58 polys each, flat-shaded. Smooth domes → faceted boulders (Sable/Short-Hike silhouette).
- **Outpost building (~15 materials)** rebuilt with same stylized-flat recipe, role-specific palettes: `Body`/`Annex`/`Buttress`/`Vent` desaturated teal-grey, `UpperStrip` warm rust accent, `Roof`/`AnnexRoof` darker grey-brown, `Antenna`/`AntennaTip` near-black, `Door` + frames dark warm metal. All metallic zeroed (was 0.4–0.8 — fought the toon look).
- **Emissives:** `mat_Outpost_Window` → warm amber (1.00, 0.72, 0.38) @ strength 3.0 — outpost now reads "inhabited". `mat_Door_WarningLight` → danger red (1.00, 0.25, 0.15) @ strength 4.0 — matches the crashed-gunship story beat.
- **Brightness lift.** First pass values rendered near-black in the low-ambient Godot cutscene; lifted all building shadow floors ~1.8× (e.g. body shadow 0.22/0.26/0.28 → 0.42/0.48/0.52) and raised terrain shadow floors.
- **Geometry fix — right buttress gap.** `Outpost_Buttress` left edge at x=6.25 vs `Outpost_Body` right edge at x=6.00 left a 0.25m gap visible through to sky. Translated Buttress -0.25 X to close the seam.

**Not changed (deliberate):**

- `godot/scripts/systems/cutscene/material_applicator.gd` kept as-is. Its `rock`/`ground`/`hill`/`wall`/`door`/`roof`/`antenna` keyword rules are now dead-code-by-convention (the `.blend` carries real materials) but `cutscene_scene.gd` still calls `MaterialApplicator.apply()` as a fallback for unmatched meshes (burn marks, etc.). Full removal is the "Delete MaterialApplicator (370 lines)" Sprint 7 row and should land with the interior-room / character-GLB optimisation rows.
- `cutscene_scene.gd`, `camera_controller.gd`, `camera_path.json`, dialogue, character placement — untouched.

**Why superseded:** the prior "tactical pass" entry (archived below) shipped runtime keyword rules with noise+triplanar+normals but still read flat because low-poly faceted GLB geometry in a dark scene can't be rescued by procedural detail alone. The .blend rework fixes the root cause.

---

## 2026-04-17 — Sprint 7 (partial): MaterialApplicator Rocks/Ground/Hills — tactical pass, parked

Tactical extension of the runtime `MaterialApplicator` to cover previously-untextured terrain surfaces (`Rock_00`–`Rock_11`, `Ground`, `Hill_00`–`Hill_07`). Landed; result still reads as flat-shaded low-poly geometry, not convincingly "rocky". **Parked for a later pass** (likely Sprint 7 Blender rework or a dedicated stylized-low-poly pass).

**Changes (`godot/scripts/systems/cutscene/material_applicator.gd`):**

- Added `rock` / `boulder` / `stone` keyword rule → cool grey matte stone (`Color(0.38, 0.36, 0.34)`, rough 0.88).
- Added `hill` / `mound` / `ridge` keyword rule → darker dusty stone.
- Re-tuned `ground` rule — warmer regolith (`Color(0.34, 0.26, 0.17)`), higher noise/normal density.
- Name-matching now walks **up the parent chain** (up to 3 ancestors) so meshes named `geometry_N` by Godot's GLB importer still match against their parent `Node3D` wrapper names (`Rock_00`, `Ground`, etc.). Without this, ~every GLB mesh fell through to the AABB fallback classifier.
- Enabled `uv1_triplanar = true` on all built materials — GLB has no UV unwraps, so without triplanar the noise `albedo_texture` silently rendered nothing and you saw flat albedo color only.
- Wired up the previously-ignored `normal_strength` config field — each rule that asks for it now gets a second `NoiseTexture2D` with `as_normal_map = true` applied to `mat.normal_texture`.
- Noise texture itself retuned — 64×64 @ `frequency = 0.015` was near-uniform (features ~67 px wide on a 64 px texture); now 256×256 @ `frequency = 0.06` with 4 fractal octaves.

**Why parked:** Even with visible procedural noise + triplanar + normals, low-poly faceted rocks in a dark scene still read as "grey faceted shapes". Three paths forward, unpicked:

1. Commit to stylized flat shading — per-rock vertex color variation, rim light, AO on facet edges. Coheres with the low-poly outpost + gunships.
2. Real PBR rock texture via Polyhaven (`mcp__blender__search_polyhaven_assets` → `download_polyhaven_asset`), applied to `mat_Rock` in `.blend`. More realistic, may clash with low-poly style.
3. Keep pushing procedural — higher gradient contrast, add emission edges, bigger normal map.

Door / frame / warning-light material overrides in `cutscene_scene.gd` untouched. Character placement, cutscene logic, dialogue, camera all untouched.

---

## 2026-04-17 — Sprint 7 (partial): No Tail cutscene door + interior rebuilt in Blender

NEXT_STEPS Sprint 7, door-focused slice. The four visible door defects reported in the latest playtest (misplaced shadows, floating interior floor, door frame clipping the outpost roof, door too small for Nine Lives) all trace back to runtime geometry patching in `cutscene_scene.gd`. Fixed by moving the geometry into `no_tail_outpost.blend` and deleting the runtime builders.

**Blender rebuild (`godot/assets/cutscenes/no_tail_outpost.blend`):**

- Door raised from 3.0 m → 3.4 m internal opening height — Nine Lives is 3.08 m tall at scale 3 (measured via GLB import), so the old 3.0 m opening was 8 cm too short. Frame pieces raised in lockstep (FrameLeft/Right now 3.6 m; FrameTop now at z ∈ [3.4, 3.6]; WarningLight moved to z = 3.80, clear of UpperStrip at 3.8). Width unchanged (2.5 m × 2.1 m Nine → 40 cm margin).
- Door, FrameLeft, FrameRight, FrameTop origins moved to each mesh's base (z = 0) so the imported node's `position.y` is at ground level — this is the direct fix for the interior floor that was floating 1.42 m in the doorway (old origin at mesh centre, runtime code computed `door_pos.y − 0.08`).
- Boolean `DIFFERENCE` applied to `Outpost_Body` with a 2.6 × 1.2 × 3.5 m cutter, so the front wall actually has a doorway hole — deletes the need for `_hide_back_wall`'s AABB heuristic.
- Interior room modelled in-scene: `Interior_Floor`, `Interior_BackWall`, `Interior_LeftWall`, `Interior_RightWall`, `Interior_Ceiling`, plus `Interior_Crate1`/`Crate2`, `Interior_Barrel`, `Interior_Shelf`, `Interior_ShelfItem`, `Interior_Light` (point, warm). Five named materials (`mat_Interior_Floor/Wall/Ceiling/Crate/ShelfItem`) mirror the runtime colours.
- Door + frame + warning light reparented to the `world` empty (were orphaned). `no_tail_outpost.glb` re-exported.

**Runtime code (deletes, not adds):**

- `cutscene_manager.gd::_open_door` — door now slides **down** 3.4 m into the floor instead of up 3.2 m through the roof. `DOOR_OPEN_TRAVEL` const matches the mesh height baked into the .blend so the door tucks fully under ground when open. Fixes "parts of the door frame appear to extend beyond the building height" — that was the door itself punching through `Outpost_Roof` (z = 5.0–5.4) because it started at z = 1.5 and travelled up 3.2 m.
- `cutscene_scene.gd` — `_build_interior` (155 lines of BoxMesh + prop assembly) and `_hide_back_wall` / `_hide_back_wall_recursive` (35 lines of AABB heuristic) deleted outright. Their calls in `_ready` were also removed. Net: `cutscene_scene.gd` is **503 → 318 lines** (−185, -37%). `MaterialApplicator`, `_apply_burn_marks`, `_hide_placeholder_characters`, `_force_red_light_fixture` stay until the remaining Sprint 7 items (textures, baked scorch marks, placeholder deletion in the .blend) land.

**Lighting tune (`no_tail_cutscene.tscn`):**

- `Sun` directional light transform corrected — the old basis had rays travelling with a **positive** Y component (physically impossible for sunlight; shadows fell in nonsensical directions). New transform is pitch −55° + yaw −30°, so rays travel `(+0.287, −0.819, −0.497)` — properly downward.
- `light_energy` 1.5 → 1.2, `shadow_blur = 2.0`, `directional_shadow_max_distance = 60.0`, `directional_shadow_blend_splits = true` — softer edges, no wasted shadow map on off-scene geometry.

**Tests:** Full suite **246/246 green** (unchanged). GDScript compiles, nothing in the deleted functions was referenced by tests.

**Before → after dimensions:**

| Metric | Before | After |
| --- | --- | --- |
| Door internal height | 3.00 m | 3.40 m |
| Nine Lives clearance (scale 3) | −0.08 m (pokes through) | +0.32 m |
| Door open direction | up 3.2 m (into roof) | down 3.4 m (into ground) |
| Interior floor Y | 1.42 m (floating) | 0.06 m (on ground) |
| Outpost front wall at door | solid | boolean-cut opening |
| `cutscene_scene.gd` LOC | 503 | 318 |

Safety backup at `/tmp/no_tail_outpost.blend.presprint7_bak`. Remaining Sprint 7 items (texture unwraps, MaterialApplicator deletion, placeholder geometry in .blend, particles + flicker) still open in NEXT_STEPS §Sprint 7.

---

## 2026-04-17 — Star map connectivity polish

NEXT_STEPS §5 pick-list item 1 — closes the "travel confirm dialog appears for any discovered region but silently fails on non-connected targets" gap left by the round-2 playtest sweep.

- `StarMapViewModel` gains `region_connections`, `is_connected_from_current`, and `route_first_hop(from, to)` (BFS next-hop through discovered + accessible regions, "" when unreachable).
- `star_map_screen._request_travel` sets `_travel_blocked = true` + `_travel_route_hint = <next-hop>` when the selected region is discovered but not directly connected. ENTER on a blocked panel cancels instead of calling `travel_to_region`, so the dialog can't misrepresent success.
- `star_map_galaxy_layer._draw_travel_confirm` renders a distinct amber prompt (`No direct route to <region>`) and footer (`Route via <hop>  |  ESC to close` or `No known path  |  ESC to close`) when blocked.
- +5 VM tests (`test_is_connected_from_current_true_for_neighbor`, `_false_for_non_neighbor`, `test_route_first_hop_returns_next_step`, `_empty_when_unreachable`, `_skips_undiscovered_intermediate`). Full suite **246/246 green** (was 241).

---

## 2026-04-17 — Sprint 6a: DialogueViewModel + dialogue_ui.gd decomposition

NEXT_STEPS Sprint 6, first slice. REFACTORING_PLAN Phase 4 (Issue #20) adapted to add the ViewModel layer that the 3a/3b/5a decompositions established. `dialogue_ui.gd` no longer reaches into `GameSession` directly — every read / write / delegate goes through `DialogueViewModel`, and portrait + combat-transition logic move into dedicated `RefCounted` helpers under `scripts/ui/dialogue/`.

**DialogueViewModel (new, 124 lines):**

- `godot/scripts/ui/view_models/dialogue_view_model.gd` — `class_name DialogueViewModel extends RefCounted`. Absorbs all 19 `GameSession.*` call sites the old `dialogue_ui.gd` had, exposing them as a narrow, null-guarded API: `has_state`, `state`, `protagonist_id` (with `"aristotle"` fallback), `story_flag`, `apply_step_outcome`, `apply_choice_outcome`, `complete_encounter`, `recruit_crew`, `crew_definition`, `ship_templates`, `faction`, `faction_registry`, `player_ship`, `deferred_arc_check`. Every method tolerates a null `_session.game_state` so the UI can still render during early-game transitions without crashing.

**PortraitManager (new, 184 lines):**

- `godot/scripts/ui/dialogue/portrait_manager.gd` — `class_name DialoguePortraitManager extends RefCounted`. Owns the `CHARACTER_PORTRAITS` table, `setup_two_portraits` / `setup_legacy_portrait` / `highlight_speaker`, and the static `remove_near_white_bg` cache (Apr-05 #7 fix preserved). Takes the dialogue UI as its tween host so fade animations stay attached to the visible scene.

**CombatTransition (new, 98 lines):**

- `godot/scripts/ui/dialogue/combat_transition.gd` — `class_name DialogueCombatTransition extends RefCounted`. Handles both legacy (`choice.outcome.faction_changes`) and step-triggered (`encounter.npc_ids` ↔ faction registry) enemy-faction derivation, template lookup, enemy-ship construction via `CombatSystem.CombatShip`, and overlay replacement through `main.replace_overlay` / `push_overlay`. All GameSession access routes through the injected VM.

**Slimmed orchestrator (dialogue_ui.gd, 660 → 469 lines):**

- Keeps scene-tree node refs, typewriter reveal (`_process`, `_set_description`), reading-pause (`_reading_pause`, `_space_advance`), choice-button construction, description collapse/restore, and parchment text styling — these are all tightly coupled to the scene tree and async flow, so moving them into RefCounted handlers would have been more ceremony than value.
- Adds `initialize(vm)` for test injection, with `_ready` fallback to `DialogueViewModel.new(GameSession)` so production callers (`navigation.gd:590` and `dialogue_manager.gd:104`) don't change.
- Dispatches to `_portraits.setup_two_portraits` or `_portraits.setup_legacy_portrait` in `_build_ui`; `_complete_and_start_combat` / legacy combat path now call `_combat.start_encounter_combat` / `_combat.start_legacy_combat`; crew confirmation + step outcome + arc check all go through the VM.
- External contract unchanged — `setup(encounter)` still accepts an `Encounter` and drives the same flow.

**Tracker drift noted and closed:**

- REFACTORING_PLAN §4 flagged a `"""..."""` Python docstring at line 506 as "remaining cleanup". `rg '"""' godot/scripts/ui/dialogue_ui.gd` returns zero matches — already cleaned up in an earlier commit. Plan row retired.
- REFACTORING_PLAN §4 said the file was 632 lines; actual was 660 before this slice. Drift absorbed.

**Pre-existing bug uncovered + fixed:**

- `test_narrative_arc_objective.gd` (landed with Sprint 5c part 2) failed to parse because `_FakeDataLoader extends RefCounted` didn't satisfy `NarrativeSystem._init(p_data_loader: DataLoader)`'s typed param. The file was being silently ignored by the GUT collector, so the "175/175" and "183/183" claims in the Sprint 5c part 2 / Sprint 8 changelog entries were really 179 and 183 out of (expected) 183 and 187 — 4 tests were never running. Fixed by switching `_FakeDataLoader` to `extends DataLoader` + `super("res://data")` in `_init`. All 4 tests now run and pass.

**Coupling / size metrics:**

- `rg "GameSession\." godot/scripts/ui/dialogue_ui.gd` returns **0** (was 19).
- `rg "GameSession\." godot/scripts/ui | wc -l` drops from 106 to **87** (−19).
- `dialogue_ui.gd`: **660 → 469** lines (−191, −29 %). Above the 250-line target but the residual is the scene-tree-bound typewriter/flow logic that wouldn't factor cleanly.

**New test coverage (+28 tests):**

- `godot/tests/unit/test_dialogue_view_model.gd` — 24 tests covering `has_state` (3 paths), `protagonist_id` default / empty-fallback / read-through (3), `story_flag` (2), encounter-engine wrappers (6, each with null-state noop), crew (5), ship templates + faction + player ship (6), deferred arc check (2). Uses a `SessionDouble` + `EncounterEngineDouble` + `CrewTraitDouble` + `DataLoaderDouble` so tests exercise the VM without the autoload.
- `godot/tests/unit/test_portrait_cache.gd` — migrated to target the new `DialoguePortraitManager` script path. Same 6 tests, same assertions.
- `godot/tests/unit/test_narrative_arc_objective.gd` — unblocked (4 tests now run).

**Tests:** Full GUT suite **215/215 passing** (was 183/183 reported before the narrative-arc fix; +32 real delta = +24 new VM + 4 re-enabled narrative + 4 re-enabled portrait-cache after path migration). Zero orphans.

**Sprint 6 status:**

- 6a (DialogueViewModel + dialogue_ui.gd decomposition) — **done**.
- 6b (input rebind panel + controller support + ESC pause/skip fix) — **done** 2026-04-17. All three tasks landed.
- 6c (multi-slot saves + tutorial encounter + game feel polish) — pending.

---

## 2026-04-17 — Sprint 6c: multi-slot saves + tutorial welcome + game feel

Closes the 6-series. Sprint 6 exit criterion ("new player can start the game, rebind a key, plug in a controller, save to slot 2, and reach the first encounter prompt without reading documentation") is now reachable end-to-end.

**Task 1 — multi-slot save/load UI.** `SaveManager` has supported 3 slots + metadata since inception (`MAX_SAVE_SLOTS = 3`, `get_save_info()`), but the UI hardcoded slot 0. New pieces:

- `godot/scripts/ui/view_models/save_load_view_model.gd` — `class_name SaveLoadViewModel extends RefCounted`. Wraps `GameSession` + `SaveManager` through a duck-typed session arg. Reads: `slot_info()` returns an Array[3] of `{slot, character_name, arc, playtime, saved_at}` dicts (or null). Writes: `save_to_slot`, `load_from_slot`, `delete_slot`. Static display helpers (`format_playtime`, `format_saved_at`, `describe_slot`) so the same strings work in the UI and in tests.
- `godot/scripts/ui/save_load_menu.gd` + `godot/scenes/ui/save_load_menu.tscn` — overlay with one row per slot. Rows built programmatically from `SaveLoadViewModel.SLOT_COUNT`. `setup(mode)` is called by the pause menu before push to set SAVE vs LOAD; the title label swaps, the Save/Load button is enabled/disabled accordingly (Save requires an in-progress session; Load requires a populated slot), Delete is independent. After a successful load, `main.switch_scene("navigation")` fires so the new session takes effect without a full reboot.
- `godot/scripts/ui/pause_menu.gd` — `_on_save` and `_on_load` now push the `save_load` overlay with `setup(0)` / `setup(1)` (the enum values for `Mode.SAVE` / `Mode.LOAD`) instead of calling `GameSession.save_game(0)` / `GameSession.load_game(0)` directly.
- `godot/scripts/ui/main.gd` — `SCENES["save_load"]` registered.
- 12 new tests in `godot/tests/unit/test_save_load_view_model.gd` covering empty-slot enumeration, save delegation, load delegation, delete delegation, has-state gating, playtime formatting (minutes + hours), and the `describe_slot` formatter. Doubles: `SaveManagerDouble` (dict-backed) + `SessionDouble`.

**Task 2 — tutorial welcome.** `_show_welcome` in `navigation.gd` was a single flash fired once per session ("Fly toward the markers to begin encounters"). Replaced with a 3-step timed sequence driven by a `TUTORIAL_STEPS: Array` constant — each entry has `{at, text, duration}`. Steps fire in `_process` based on cumulative `_tutorial_elapsed`; the sequence short-circuits (sets `_showed_welcome = true`) as soon as any arc-progress flag is set, so loaded/experienced saves don't re-see it. Current sequence:

| After | Message | Duration |
| --- | --- | --- |
| 0 s | `WASD or left stick to move` | 4 s |
| 5 s | `Fly toward coloured markers to start an encounter` | 5 s |
| 12 s | `TAB (or RB on a gamepad) opens the galaxy map` | 5 s |

The flash system is pre-existing (`flash(message, duration)` + `_update_flash`); the sequence is just a driver on top of it.

**Task 3 — game feel.** Three low-risk polish pieces.

- **Audio ducking** — `MusicManager.play_sfx` now dips BGM by −8 dB (50 ms in, 350 ms out via `Tween`) every time an SFX fires, so hit/pickup/UI SFX land audibly over the score. Guarded against the fade-paused state (no dip if the music player isn't playing or `_paused == true`). Prior ducking tweens are killed on every trigger so rapid-fire SFX don't stack fades and leave the track stuck at −8 dB.
- **Hit flash (nav)** — `navigation.gd` subscribes to `EventBus.hazard_damage(hazard_id, damage)` and bumps `_hit_flash_timer = 0.35 s`. `_process` decays the timer; `_draw` appends a red `draw_rect` with alpha `0.35 * t²` (where `t = timer / duration`) at the end of the frame so it sits on top of starfield/fog/ship/HUD. Quadratic falloff reads as a sharp hit rather than a steady wash.
- **Camera shake** — already wired. `CombatAnimations.trigger_shake("player"/"enemy")` at `scripts/ui/combat/combat_animations.gd:51` is called on combat hits from `combat_ui.gd:244` + inside `CombatAnimations._on_laser_arrived`. Nav shake was deferred — the `_draw` call tree is large and applying a global offset would touch every sub-drawer; not worth the diff vs the hit flash, which reads clearly in the same frame as the damage.

**Tests:** full suite 229 → **241 passing / 241 total** (+12 new for SaveLoadViewModel). Tutorial and game-feel are scene-wiring / integer-math / tween timing, which GUT can't exercise meaningfully without a live input-and-audio harness — flagged for manual QA in the checklist below.

**Manual test checklist:**

- New game → pause (ESC) → Save Game → "Slot 1 — Aristotle — The squeeze — 0:05" appears → Save → status "Saved to slot 1." → Back. Re-open Save Game → slot populated. Load → session re-enters navigation with same state.
- Quit to menu → new game → on first nav entry, see the 3-step tutorial sequence fire at 0 s / 5 s / 12 s.
- Load the save above → tutorial does NOT fire again (arc progress has a completed objective).
- In nav, wait for a hazard hit (ion storm / gravity well) → red flash overlays briefly → BGM ducks under the SFX.

---

## 2026-04-17 — Playtest bug sweep round 2: star map travel, stale realm, planet exit

Three follow-ups from the second playtest pass.

**Star map travel was undiscoverable + mis-routed (bugs A + B).** Galaxy layer's `_handle_galaxy_input` mapped ENTER → `_drill_to_region` (zoom into sector view) and SPACE → `_request_travel` (travel there), which matched the hint text but not the mental model — users pressed ENTER on a region expecting to go there. Compounding that, `_confirm_travel` called `get_tree().change_scene_to_file(WORLD_SCENE_MAP.get(region, "res://scenes/world/world.tscn"))`, which bypassed `main.switch_scene` and left the region HUD showing the previous realm's name until the next full reload.

Fixes:

- `star_map_screen.gd:224` — ENTER on a *different* connected region now triggers travel; ENTER on the *current* region keeps the existing drill-to-sector behavior. SPACE still triggers travel unconditionally. Also accepts the project's `confirm` action in addition to `ui_accept`, matching the pattern the boundary-jump fix established earlier in this sprint.
- `star_map_screen.gd:_confirm_travel` — replaced `change_scene_to_file(world_scene_path)` with `main.switch_scene("navigation")`. Nav re-inits with the new `game_state.current_region`, so the HUD's region label, arc progress, POIs, and starfield all reflect the destination realm. The `WORLD_SCENE_MAP` dict is left in place for a future "special hub scenes" feature but no longer wired to travel.
- `star_map_galaxy_layer.gd:_draw_hints` — hint text updated to `"ARROWS select | ENTER travel (or view sector if already there) | SPACE travel"` so the new ENTER semantics are discoverable.

Known limitation not fixed here: `_request_travel` shows a confirm dialog for any discovered region, not only directly connected ones. If the user tries to travel to a discovered-but-not-connected region, `_vm.travel_to_region` returns false and the scene-switch is skipped silently. The user notices this as "nothing happened." Connectivity-aware gating is a separate polish.

**Planet exit still didn't work after the label fix (bug C).** Relabelling ControlsLabel from "TAB depart" to "ESC depart" was correct but insufficient. Two likely causes on the user's machine:

1. `_unhandled_input` fires only when no Control has consumed the event. Once the player clicks the DepartBtn once, it holds focus; a subsequent ESC press can be swallowed by the focus system before `_unhandled_input` runs.
2. SubViewportContainer sits under the DepartBtn and captures mouse input when the button is small / in the corner.

Fixes:

- `planet_surface.gd:_ready` — DepartBtn now calls `grab_focus()` (deferred) on scene enter, gets a bumped `custom_minimum_size` (160×48 vs the scene-file 120×40), and relabels to `"DEPART (ESC)"` with a warmer font color so the keyboard shortcut is visible on the button itself.
- `planet_surface.gd:_input` (renamed from `_unhandled_input`) — both ESC→depart and E→interact now run in `_input`, which fires *before* UI focus consumption. After handling, the event is marked handled so it doesn't double-fire elsewhere.

**Tests:** 229/229 green (no new tests — all three are scene-wiring / UX changes that unit tests can't meaningfully cover without a live input harness).

**Manual test checklist for the next playtest:**

- New game → TAB to open star map → arrow-key to a connected region → ENTER → confirm dialog → ENTER → nav reloads in the new realm and the HUD region label matches.
- In a non-starting realm, TAB → select starting realm → if directly connected, ENTER works; if not, user needs to hop through an intermediate (documented behavior — future polish).
- Land on a planet → DEPART button is obviously visible in bottom-right and shows "DEPART (ESC)" → pressing ESC OR clicking the button returns to nav.

---

## 2026-04-17 — Nav fog of war reads as wisps instead of bubbles

Follow-up to the post-ship playtest. The nav fog drew soft circles at each hidden-cell centre on a fixed grid with uniform size and alpha per `min_dist` bucket, so the boundary between revealed and unrevealed space read as a ring of evenly-spaced blobs (the 8-neighbour grid around the player's revealed area was especially visible).

**Change in `navigation.gd:_draw_fog_of_war`:** boundary cells now jitter the blob's centre by ±45 % of a cell via a deterministic hash of `(cx, cy)`, and independent hashes pick per-cell radius (0.75–1.35×) and alpha (0.7–1.1×) multipliers. Same 2 `draw_circle` calls per cell — no perf cost — but the output breaks the grid and reads as organic fog. The solid-interior branch (`min_dist > soft_radius`) is unchanged; bulk fog stays flat and cheap.

Deep interiors still use `draw_rect`, so the central opaque mass is unaffected. Only the transition band gets the new treatment, which is where the tiling was visible.

Not touched: `star_map_local_layer.gd` and `star_map_region_layer.gd` both have similar circle-per-cell fog; leaving those alone since the user's complaint was specifically the nav view. Mirrored jitter can copy-paste if/when those views get the same feedback.

---

## 2026-04-17 — Sprint 6b post-ship playtest bug sweep

Five issues from the first hands-on playtest of the 6b build.

**Nav jitter + cloudy overlay (bugs 1 + 4).** `_draw_nebula` called `_refresh_nebula()` every frame, which regenerated a procedural `ImageTexture` via `ProceduralMapManager.get_nav_texture(...)` on each redraw — the scene calls `queue_redraw()` every frame, so the cost was paid unconditionally. Removed the `_draw_nebula(gs)` entry from `_draw()` in `scripts/ui/navigation.gd:962`. Starfield + fog + POIs + ship still draw; the shifting cloud layer is gone and the per-frame texture regen is no longer an ongoing cost. Kept `_refresh_nebula` / `_nebula_*` fields in place rather than ripping them out — they still run cheaply on region change and can be re-enabled once the art direction settles. Fixes both symptoms with one edit.

**Planet exit hint lied (bug 2).** `planet_surface.tscn` ControlsLabel read `"ARROWS move | E interact | TAB depart"`, but the actual depart handler at `planet_surface.gd:310-311` listens for the `pause` action (ESC) and there is no `star_map`/TAB handler on the planet surface. Users pressing TAB correctly got nothing. Updated the label to `"WASD / Arrows move | E interact | ESC or DEPART button to leave"` — the DEPART button (bottom-right, bound at `planet_surface.gd:175`) always worked; the hint was the regression.

**"YOU" marker drawn outside the sector map (bug 3).** In `star_map/star_map_region_layer.gd`, the sector is rendered as a circle of radius `map_radius`, but the world bounds are rectangular and scaled to `fit_diameter = map_radius * 1.8` — so corners of the world map to screen positions up to `map_radius * ~1.27` from center, outside the visible disc. `_draw_player` plotted raw world→screen without clamping. Added a circular clamp that pulls the marker onto the inner edge (12 px margin) when the player is near a corner of the region, so "YOU" now always renders inside the drawn circle. `_draw_player` signature gained `map_center` + `map_radius` args; single call site at line 64 updated.

**ENTER at sector boundary did nothing (bug 5).** Two independent issues stacked:

- The boundary handler at `navigation.gd:832` checked `ui_accept` only. `ui_accept` is a Godot built-in that defaults to ENTER/SPACE, but SPACE is already the project's `fire` action and gets consumed earlier in the elif chain — and the flash prompt explicitly says "Press ENTER", which is the project's named `confirm` action. Changed to `is_action_pressed("confirm") or is_action_pressed("ui_accept")`.
- `_check_boundary` was only called inside `if _is_moving:` in `_handle_movement`. The boundary-prompt timer starts at 5s and decrements every frame; if a player drifts to the edge, stops, and reads the prompt, the timer counts down and the prompt becomes inert while the flash text is still on screen. `_check_boundary` no longer runs inside `_handle_movement`; it now runs from `_process` each frame (guarded by the overlay check). When the player is at the edge, the region stays set; when they move away, it clears. The prompt now stays active for the full flash duration regardless of movement state.

**Tests:** full suite 229/229 still green (no new tests added — the three code-side fixes are either geometry clamps against a canvas-size-dependent constant, an input-action rename, or a call-site move; the existing nav + star-map coverage exercises them). Nav jitter and the clamp are visual regressions best caught by the user's next playtest rather than a unit test.

**Manual test checklist:**

- New game → navigate with WASD → background is stars only, no cloud shimmer, movement is smooth.
- Drift to sector edge → "SECTOR BOUNDARY — Press ENTER" flash appears → stop moving → ENTER still jumps.
- Open star map with TAB → region view shows "YOU" marker inside the circle even if the ship is at a world corner.
- Land on a planet → read hint at bottom center → press ESC or click DEPART → return to navigation.

---

## 2026-04-17 — Sprint 6b task 3: input rebind panel

Sprint 6b, third and final slice. The player can now remap any of 14 actions (keyboard + joypad) from the in-game settings menu; bindings persist across runs and load automatically on startup. All `InputMap` access routes through a new `InputRebindViewModel`, extending the VM pattern from Sprints 3a/3b/5a/6a to one more screen.

**InputRebindViewModel (new, ~200 lines):**

- `godot/scripts/ui/view_models/input_rebind_view_model.gd` — `class_name InputRebindViewModel extends RefCounted`. Wraps `InputMap` through a duck-typed `_api` arg (default: inline `_DefaultApi` RefCounted proxy calling the engine singleton; tests pass a dict-backed `FakeInputApi`). Constructor snapshots current bindings into `_defaults` so `reset_to_defaults()` has something to restore.
- Reads: `primary_keyboard_event(action)` returns the first `InputEventKey` or null; `primary_joypad_event(action)` returns the first `InputEventJoypadButton` or `InputEventJoypadMotion`.
- Writes: `set_keyboard_binding` and `set_joypad_binding` replace the first event of the matching kind in place, preserving the other kind's binding; append when none of that kind exists yet.
- Persistence: `save(path)` serializes each action's event list to plain dicts (`{type: "key"|"joy_button"|"joy_motion", ...}`) and writes a `ConfigFile` to `user://input_bindings.cfg`; `load(path)` applies the saved events via `action_erase_events` + `action_add_event`. Hand-rolled dict serialization avoids engine-resource encoding quirks and keeps the test doubles simple.
- UX helpers: `describe_event` produces human-readable labels — `"W"`, `"A"`, `"Start"`, `"L-Stick Up"`, `"D-pad Right"`, etc.
- Constant `REBINDABLE_ACTIONS` — the 14 actions users can rebind, in display order. A test (`test_rebindable_actions_list_covers_all_project_actions`) walks `InputMap.get_actions()` and fails CI if any new action is added to `project.godot` without being added here.

**Controls rebind overlay (new, ~130 lines + scene):**

- `godot/scripts/ui/controls_rebind.gd` + `godot/scenes/ui/controls_rebind.tscn` — overlay with a 14-row list (built programmatically from `REBINDABLE_ACTIONS`); each row has an action label, keyboard button, and joypad button. Clicking a button begins capture: the status label prompts the user, other rows disable, and `_unhandled_input` waits for the next matching event (keyboard for keyboard cells; joypad button OR axis deflection ≥0.7 for joypad cells). ESC cancels capture without replacing the binding. Back saves via `vm.save()` before popping the overlay; Reset restores defaults in-memory (user still needs to press Back to persist).
- Joypad motion captures are normalized to ±1.0 so a partial stick deflection doesn't save as (say) `axis_value = 0.72`.

**Wiring:**

- `godot/scripts/ui/main.gd` — `SCENES["controls_rebind"]` registered. `_ready` now calls `_apply_saved_input_bindings()` before `switch_scene("splash")`; the helper constructs an `InputRebindViewModel` (which snapshots the project defaults) and calls `load()`. Missing file is a silent no-op, so first-run users keep the project defaults.
- `godot/scripts/ui/settings_screen.gd` + `settings_screen.tscn` — new "Controls…" button between the volume slider and Close; pressing it pushes the `controls_rebind` overlay.

**Tests (12 new, in `test_input_rebind_view_model.gd`):**

- `test_primary_keyboard_event_returns_first_key` / `null_when_none`
- `test_primary_joypad_event_returns_button` / `returns_motion_when_only_axis`
- `test_set_keyboard_binding_replaces_existing_key` / `appends_when_none_exists`
- `test_set_joypad_binding_replaces_existing_button`
- `test_reset_to_defaults_restores_snapshot`
- `test_save_and_load_round_trip` — writes a temp file under `user://`, reconstructs the VM on a fresh `FakeInputApi`, asserts the custom binding survives.
- `test_load_returns_error_when_file_missing`
- `test_describe_event_handles_all_kinds`
- `test_rebindable_actions_list_covers_all_project_actions` — the drift guard described above.

Full suite now 229/229 green (+12 from 217).

**What's manual-test-only:**

- The click-to-capture flow inside the scene itself (GUT can't simulate mouse/keyboard events reliably against a live Control). The VM layer is fully covered; the scene is just row construction + event dispatch, which is small enough to eyeball during QA.

**Tracker updates:**

- `docs/NEXT_STEPS.md` Sprint 6b table — task 3 row marked Done; sprint header now "done 2026-04-17".
- `docs/changelog/CHANGELOG.md` Sprint 6 status line — 6b now reads "done".

---

## 2026-04-17 — Sprint 6b task 2: controller support

Sprint 6b, second slice. Every player-facing action now has an additive joypad binding alongside its existing keyboard event, so the game is playable on an Xbox/PS/generic gamepad without any code changes — every existing `event.is_action_pressed(...)` call site picks up the new events automatically.

**`godot/project.godot` additions:**

| Action | Joypad event |
| --- | --- |
| `move_up` | D-pad up (button 11) + left stick Y = −1.0 (axis 1) |
| `move_down` | D-pad down (12) + left stick Y = +1.0 |
| `move_left` | D-pad left (13) + left stick X = −1.0 (axis 0) |
| `move_right` | D-pad right (14) + left stick X = +1.0 |
| `confirm` | A / Cross (0) |
| `cancel` | B / Circle (1) |
| `fire` | X / Square (2) |
| `interact` | Y / Triangle (3) |
| `pause` | Start (6) — also skips cutscene/intro via task-1 handler fallback |
| `menu_select` | Back / Share (4) |
| `mission_log` | LB / L1 (9) |
| `star_map` | RB / R1 (10) |

Keyboard defaults and deadzones (0.5) unchanged. `skip` stays keyboard-only (X key) — cutscene/intro_crawl handlers already accept `pause`, so Start on the gamepad skips those scenes. `repair` also stays keyboard-only (T) since it's surfaced via buttons inside ship/station screens and rarely wanted via d-pad shortcut.

**Test:** `test_essential_actions_have_joypad_bindings` (new, in `test_input_map_collisions.gd`) asserts that each of the 12 essential actions has at least one `InputEventJoypadButton` or `InputEventJoypadMotion` event — would fail if the joypad block gets stripped out by a future project-settings revert. Full suite 217/217 green (+1 new test).

**Not tested end-to-end:** no physical gamepad plugged in during this slice. Manual test plan for when one is: plug in controller → start new game → left stick moves Aristotle in nav → A opens faction overlay (existing `interact` action) → B closes overlays → Start opens pause menu → Start during a cutscene skips it.

**Tracker updates:**

- `docs/NEXT_STEPS.md` Sprint 6b table — task 2 row marked Done with the full binding table summary.

---

## 2026-04-17 — Sprint 6b task 1: ESC pause/skip collision resolved

Sprint 6b, first slice. MASTER_PLAN §5.3 row (CR-2026-04-16) closed. `pause` and `skip` had both been bound to `KEY_ESCAPE` (4194305) since Sprint 3c surfaced the collision — tolerated via a whitelist entry in `test_input_map_collisions.gd` because the two actions live in disjoint screens. With the rebind panel coming in 6b, a shared default key would make the rebind UI ambiguous, so the collision is now separated at the action-map level while user-facing behavior is preserved.

**Changes:**

- `godot/project.godot` — `skip` action's only keycode changed from `4194305` (ESC) → `88` (X). `pause` still binds ESC only.
- `godot/scripts/ui/cutscene.gd:98` — `_unhandled_input` now accepts `skip OR pause`, so pressing ESC during a 3D cutscene still routes to `_finish()` and returns to navigation.
- `godot/scripts/ui/intro_crawl.gd:138` — same treatment: `skip OR pause` both end the crawl and jump to navigation. Existing `SPACE`/`DOWN` fast-forward keycode handling is untouched.
- `godot/tests/unit/test_input_map_collisions.gd` — `KNOWN_CONTEXT_SEPARATED_COLLISIONS` emptied (the sole `["pause","skip"]` entry is no longer needed). New `test_pause_and_skip_have_distinct_keycodes` mirrors the existing `menu_select`/`repair` specific-regression pattern and would fail if either action ever shares a keycode again.

**Why X (88) for skip:**

- ESC and BACKSPACE are `pause` and `cancel`. ENTER is `confirm`. SPACE is `fire`. TAB is `star_map`. Every semantically natural "skip" key was already claimed.
- `skip` is only consumed by full-screen takeover scenes (`cutscene`, `intro_crawl`), so the literal default key rarely matters — users reaching for ESC/ENTER still skip via the `pause` fallback added above.
- X is keyboard-convenient and stays open for rebind in task 3.

**What still works:**

- ESC during cutscene → skip (via `pause` handler).
- ESC during intro crawl → skip (via `pause` handler).
- ESC during navigation / combat → pause menu (unchanged).
- X during cutscene / intro crawl → skip (new default).
- Rebind-UI groundwork: every user action now owns a unique default keycode, so task 3 can list one key per action without asterisks.

**Tests:** full suite 215/215 passing (was 214/215 during the ENTER-conflict intermediate state — the broad collision guard caught the slip). The two that cover this work:

- `test_no_unexpected_user_action_keycode_collisions` — would fail if any pair of user actions shares a keycode.
- `test_pause_and_skip_have_distinct_keycodes` — direct regression for this ticket.

**Tracker updates:**

- `docs/MASTER_PLAN.md` §5.3 — CR-2026-04-16 row marked Done 2026-04-17 with fix summary.
- `docs/NEXT_STEPS.md` Sprint 6b table — task 3 marked Done; sprint header moved to "in progress".

---

## 2026-04-17 — Sprint 8 (full scope): biome-driven placement, minimap tint, scanner modulation

NEXT_STEPS Sprint 8 steps 4–6, following this morning's one-day cut (steps 1–3 + determinism test). The biome field that the nebula now samples at every point also drives gameplay: where POIs spawn, how far the scanner sees, and how the minimap reads.

**POI biome weighting — `godot/scripts/ui/navigation.gd`:**

- New `BIOME_PREFERENCES` table maps encounter types to preferred biome IDs: `treasure → [cRock, cDeepWater]`, `abandoned_ship → [cRock, cDeepWater, cShallowWater]`, `crystal_hoard → [cRock, cSnow]`, `distress_signal`/`rescue → [cDeepWater, cShallowWater]`, `exploration → [cForest, cSeasonalForest, cBorealForest, cRainForest]`, `hidden → [cForest, cRainForest, cSnow]`. Missing entries are treated as "any biome fine" and fall through to uniform placement — no gameplay regression for `combat`, `trade`, `event`, `diplomatic`.
- New `_pick_biome_spawn(encounter_type, cx, cy, region_id)` rejection-samples up to `BIOME_SPAWN_CANDIDATES = 16` random `(angle, distance)` pairs, returning the first whose sampled biome is in the preferred list. Falls back to the first candidate if none match, so spawns never fail. `_spawn_poi` wires this into the non-fixed-position path; fixed-position story POIs are untouched.
- Helpers `_random_spawn_candidate` and `_sample_biome_id` pull the candidate generation and biome lookup into separately testable units (though the regression test exercises `ProceduralMapManager.sample_biome` directly — the UI wrapper is a thin layer).

**Scanner modulation — `godot/scripts/ui/navigation.gd`:**

- New constants `DENSE_NEBULA_BIOMES = [cForest, cRainForest, cSnow]` and `DENSE_NEBULA_SCAN_MULT = 0.6`. When the ship passes into one of those biomes, the fog-of-war reveal radius (normally 300, already halved to 150 under `fog_blind`) multiplies by 0.6 — scanner range genuinely contracts in thick cloud, so there's a reason to navigate around dense pockets instead of through them.
- New `_in_dense_nebula` flag tracks the entry/exit boundary. On each crossing, `EventBus.exploration_event` fires with `{type: "dense_nebula_entered" | "dense_nebula_cleared", region_id, biome_id}` so narrative or mission systems can react downstream (nothing listens yet — surface is opened, not wired).

**Minimap biome tint — `godot/scripts/ui/navigation.gd`:**

- `_draw_minimap` now calls `_draw_minimap_biome_background(map_rect, gs)` instead of a flat fill. The helper samples an `8 × 8 = 64` grid of biome cells centred on the ship (covering `MINIMAP_WORLD_RANGE = 2400` world units), composing each cell as `base_color + region_tint * biome_tint * 0.08`. Alpha stays at the minimap base so the tinting doesn't wash out gameplay behind it. Constants `MINIMAP_BIOME_GRID` and `MINIMAP_BASE_COLOR` sit next to `_draw_minimap` so tuning is local.

**New regression test (+4 tests):**

- `godot/tests/unit/test_poi_biome_placement.gd` — mirrors `_pick_biome_spawn`'s rejection-sampling logic as a pure test helper, then: (1) verifies `starting_realm` covers ≥ 3 distinct biomes (biome nuance requires biome variety — if this ever fails the noise seed has collapsed), (2) compares biased vs. uniform hit rates over 150 trials for `[cRock]` (biased must out-hit uniform — with a `pending()` escape if the region happens to lack any rocky pockets, avoiding a false-fail on seed changes), (3) empty preference → returns first candidate, (4) unreachable preference (`[-1]`) → falls back to first candidate without looping. Uses a seeded `RandomNumberGenerator` so runs are deterministic.

**Tests:** Full GUT suite **183/183 passing** (was 179 after the morning's one-day cut; +4 today). Zero orphans, zero exit errors.

**Sprint 8 status:** all six scope items (nebula sampling, parallax/local tint, determinism test, POI biome weighting, scanner modulation, minimap tint) now shipped. Second parallax nebula layer from the original scope was descoped during implementation — single layer reads well enough with biome modulation that adding a second layer felt like polish, not nuance.

---

## 2026-04-17 — Sprint 8 (one-day cut): navigation nebula becomes location-aware

NEXT_STEPS Sprint 8 steps 1–3 + determinism test — the minimum cut that fixes the "hyper-speeding leaves you in the same place" complaint. Biome-driven POI placement and scanner modulation (Sprint 8 steps 4–6) remain backlog. Today the nebula becomes a *field sampled at the player's world position* instead of one cached texture stretched over the camera.

**Core change — `godot/scripts/autoload/procedural_map_manager.gd`:**

- `get_nav_texture(region_id, camera_size, world_pos)` — new `world_pos` parameter (defaults to zero for callers that don't care). The sampled noise rect now centres on the ship's world position, regenerating on region change, camera resize, or when the ship has drifted more than `NAV_REGEN_THRESHOLD = 256.0` world units since the last generation (~1 regen/sec at `SHIP_SPEED = 300`).
- `sample_biome(region_id, world_x, world_y) -> Dictionary` — new public API. Point-samples the same 4 noise generators the texture uses (main-elev, elev, heat, moisture), runs the classifier mirrored from `fastnoiselite_datasource.get_biome_buffer`, and returns `{biome_id, biome_tint}`. Deterministic for a fixed `(region, x, y)`.
- Per-region datasources are now resident (kept in `_nav_datasources`) and reparented under the autoload so Godot frees them on teardown. `_reset_area_info_cache` drains the inner `area_info_cache` Nodes between generations without freeing the datasource itself.
- New `BIOME_TINTS` table — nudges around 1.0 (e.g. `cDesert → (1.30, 0.85, 0.70)` for warm dust, `cDeepWater → (0.60, 0.65, 0.90)` for cool void). Layered *multiplicatively* on the region tint so pockets show local variation without overriding regional character.
- `NAV_NOISE_SCALE = 0.25` — one world unit ↔ 0.25 noise pixels, preserving the `camera/4` render ratio the original path used. The texture now samples the exact world region the screen covers.

**Wire-up — `godot/scripts/ui/navigation.gd`:**

- `_refresh_nebula` now passes `Vector2(gs.position_x, gs.position_y)` to `get_nav_texture` and additionally calls `sample_biome` at the ship's world position, easing `_nebula_local_tint` toward the returned biome tint at `NEBULA_TINT_LERP_SPEED = 2.0` (half-lerp in ~0.35 s). Result: flying from a void pocket into a dust lane fades the tint over a heartbeat instead of snapping.
- `_draw_nebula` composes `tint_color = _nebula_tint * _nebula_local_tint` (RGB, alpha fixed at `0.45`). Region character holds; biome character modulates.

**New test file (+4 tests):**

- `godot/tests/unit/test_procedural_sample_determinism.gd` — 4 tests: identical `(region, x, y)` returns identical biome (the load-bearing invariant saved POI positions depend on); different region seeds disagree on at least one sampled coordinate (proves the seed matters); unknown region falls back to `hash(region_id)` without crashing; biome tint values fall in a sane `[0.3, 2.0]` band per channel.

**Tests:** Full GUT suite **179/179 passing** (was 175/175 at end of Sprint 5c; +4 today). Zero orphans, zero exit errors.

**Out of scope (still backlog per NEXT_STEPS §Sprint 8):** biome-weighted POI placement, scanner-range modulation in dense nebula, minimap biome tinting, second parallax nebula layer. The one-day cut ships just enough to make "where you are" visually legible; evaluate in-game feel before continuing to steps 4–6.

---

## 2026-04-16 — Sprint 5c (part 2): DataLoader cache hardening + HUD polish

NEXT_STEPS Sprint 5c, second of two commits. Closes the final engineering+HUD polish rows before the sprint is done: DataLoader cache is now mutation-safe and session-crossover-safe (MASTER_PLAN §5.3 Apr-05 #4, #12), and the navigation HUD gains a segmented hull bar, a persistent objective line, and a crew-morale pip (CODE_REVIEW §4.6, §5.3).

**DataLoader cache (Apr-05 #4, #12):**

- `godot/scripts/core/data_loader.gd` — `_load_json` now returns a deep-duplicated Dictionary/Array on every cache hit via a new `_duplicate_cached` helper, so mutations inside a caller can no longer leak back into the cache (the Apr-05 #4 failure mode). Cache entries themselves still hold the authoritative reference. New public `clear_cache()` wipes every cached payload; new `invalidate(relative_path)` drops a single entry; new `is_cached(path)` is a debug helper that tests use to assert cache state.
- `godot/scripts/autoload/game_session.gd` — `start_new_game` and `load_game` now call `data_loader.clear_cache()` before re-initialising systems, so stale data from a prior playthrough cannot contaminate the new one.
- Apr-05 #12 ("redundant DataLoader calls for same file") is closed by #4's fix — the cache already dedupes disk I/O for shared files (`faction_registry.json`, `economy_data.json`, `ship_templates.json`), and deep-copy isolation removes the mutation-amplification concern the original review flagged. Consolidating method signatures would have required caller churn across `GameSession`; the deep-copy fix subsumes the safety benefit.

**HUD polish (CODE_REVIEW §4.6 / §5.3):**

- `godot/scripts/ui/hud/hull_bar.gd` (new, ~80 lines) — `HullBar` Control subclass. Segmented bar with 10 cells, colour-graded (green > 50 %, amber 25-50 %, red ≤ 25 %). Exposes `set_hull(current, max)` and pure helpers (`fill_ratio`, `filled_segments`, static `color_for_ratio`) so tests exercise the draw math without a scene tree. Rounds-up on `filled_segments` so 1 HP still shows one lit cell (you-are-alive feedback).
- `godot/scripts/ui/hud/morale_pip.gd` (new, ~45 lines) — `MoralePip` Control subclass. Small ring with a fill colour driven by the same thresholds `CrewMoraleSystem` uses for combat/trade modifiers, so the player reads the same tier the multipliers actually use. Static `color_for_morale(value)` keeps tests scene-free.
- `godot/scripts/systems/narrative_system.gd` — new `get_arc_objective(game_state)` returns the arc's `objective_text` when present, falls back to the arc `theme` (the field every arc already carries), or `""` when both are missing. No JSON changes required; arcs can adopt `objective_text` incrementally.
- `godot/scripts/ui/view_models/navigation_view_model.gd` — new accessors: `arc_objective`, `hull_current`, `hull_max`, `crew_count`, `crew_capacity`, `has_crew_morale`, `crew_morale_average`, `crew_morale_label`. All tolerate a null `player_ship` / `crew_morale` and return safe defaults.
- `godot/scenes/ui/navigation.tscn` — `TopBar` restructured from a single `HBoxContainer` to a `VBoxContainer` with two rows: `Row1` carries the existing labels plus the new `HullBar` + micro `HullLabel` + `CrewLabel` + `MoralePip`; a second `ObjectiveLabel` sits below in a muted 14-pt tone for the persistent objective surface. `FlashLabel` anchor pushed down so it clears the taller top bar.
- `godot/scripts/ui/navigation.gd` — `@onready` refs repointed to `HUD/TopBar/Row1/...`; `_update_hud()` drives the bar via `set_hull`, the pip via `set_morale` (with a tooltip showing the morale label), writes `"%d/%d"` into the micro hull label, updates the crew count, and surfaces the objective text.

**Coupling budget:** No new `GameSession.` refs in `scripts/ui/` — the VM absorbs every new read.

**New test files (+37 tests):**

- `godot/tests/unit/test_data_loader_cache.gd` — 9 tests: Dictionary + Array mutation isolation, cache-hit-skips-disk (verified by deleting the file after priming), `clear_cache`, `invalidate` (targeted + unknown-path + idempotent), primitive pass-through.
- `godot/tests/unit/test_narrative_arc_objective.gd` — 4 tests: `objective_text` precedence, `theme` fallback, empty when both missing, empty when arc unknown.
- `godot/tests/unit/test_hud_hull_bar.gd` — 12 tests: ratio math (full/half/zero-max/negative/overflow), segment count (full/empty/1 HP rounds-up/45% rounds up to 5), colour thresholds low/mid/high.
- `godot/tests/unit/test_hud_morale_pip.gd` — 6 tests: colour for each `CrewMoraleSystem` tier + `set_morale` persists.
- `godot/tests/unit/test_navigation_view_model.gd` — extended with `arc_objective`, hull accessors (with + without ship), crew accessors, and the morale-pip path (incl. null `crew_morale` fallback). +11 tests.

**Tests:** Full GUT suite **175/175 passing** (was 138/138 at the end of Sprint 5c part 1; +37 from the new coverage). No orphans, no unexpected errors.

**MASTER_PLAN §5.3 rows closed this commit:**

- Apr-05 #4 — DataLoader cache never invalidated. **Done.**
- Apr-05 #12 — Redundant DataLoader calls for same file. **Done** (subsumed by #4's deep-copy fix).

**CODE_REVIEW findings closed this commit:**

- §4.6 — HUD clarity (objective surface, segmented hull bar, morale pip). **Done.**
- §5.3 — Persistent objective surface. **Done.**
- §2.6 — "DataLoader cache has no invalidation" carry-forward. **Done.**

**Exit criteria met:** Sprint 5c fully closed. NEXT_STEPS §5 "pick next from" list drops to three items (Sprint 7, Sprint 2 sprite pilot, Sprint 6).

---

## 2026-04-16 — Sprint 5c (part 1): dock gating + conquest surfacing

NEXT_STEPS Sprint 5c, first of two commits. Closes the final two rows of the CODE_REVIEW §3 "dormant systems" inventory by wiring `RealmControlSystem` into the docking gate and giving `FactionConquestAI` a heartbeat + observable signal emissions. Dormant-systems count 2 → 0.

**Dock gating:**

- `godot/scripts/systems/star_base_system.gd` — new optional `realm_control: RealmControlSystem` field; new `HOSTILE_DOCK_REPUTATION_THRESHOLD = -50`. `can_dock` delegates to a new `get_dock_block_reason(game_state, base_id)` that returns "" when docking is allowed and a human-readable reason otherwise. Stronghold reputation gate preserved; additional realm-control gate refuses docks at *any* base type when the region's controller is a faction that isn't the base's owner and whose rep with the player is below the threshold. Backwards compatible when `realm_control` is unset (original behaviour).
- `godot/scripts/autoload/game_session.gd` — injects `star_base_system.realm_control = realm_control` during autoload init so the gate fires in the live game.
- `godot/scripts/ui/view_models/navigation_view_model.gd` — new `get_dock_block_reason(base_id)` adapter.
- `godot/scripts/ui/navigation.gd` — `_check_base_proximity` now flashes the block reason (e.g. `Outpost Alpha: Blockaded by Hostile Raiders`) instead of silently dropping the dock prompt when the gate refuses.

**Conquest surfacing:**

- `godot/scripts/autoload/game_session.gd` — `_process` now ticks `faction_conquest` every `CONQUEST_TICK_INTERVAL = 60.0s`. Each tick calls `plan_faction_actions(game_state)` and `resolve_actions(game_state, realm_control)`. Guarded on both `faction_conquest` and `realm_control` being non-null so unit tests that instantiate GameStateData without the autoload stay isolated.
- `godot/scripts/systems/faction_conquest_system.gd` — `resolve_actions` now takes an optional `realm_control` and emits `EventBus.faction_conflict(aggressor_id, target_id, outcome)` for every resolved ConquestAction. `_resolve_attack` victories feed `realm_control.apply_conflict_result()` (scaled by the loss inflicted) so territorial influence actually moves; when that shift flips the region's controller, `EventBus.realm_control_changed(region_id, old, new)` fires. Backwards compatible — old callers passing no second arg keep working.
- `godot/scripts/ui/navigation.gd` — subscribes to `EventBus.realm_control_changed` in `_ready` and flashes a map-shaking toast (e.g. `Feline Courts: Aggressor → Target`) so the conquest tick is not invisible.

**Dormant-systems count:**

- Before Sprint 5c (part 1): 2 dormant (realm control, faction conquest).
- After Sprint 5c (part 1): **0 dormant.** All four CODE_REVIEW §3 systems now drive observable gameplay.

**New test files:**

- `godot/tests/unit/test_dock_gating.gd` — 9 tests covering pre-5c stronghold rep gate preservation, new realm-control gate behaviour at various rep thresholds, controller == owner bypass, unclaimed-region bypass, unknown-base error, and the `can_dock` ↔ `get_dock_block_reason` invariant.
- `godot/tests/unit/test_conquest_surfacing.gd` — 8 tests covering `faction_conflict` emission on every resolve path (attack/blockade/diplomacy/fortify), attack-victory influence shift, controller-flip triggering `realm_control_changed`, and the no-`realm_control`-arg backwards-compat path.

**Tests:** Full GUT suite **138/138 passing** (was 121/121 at the end of Sprint 5b; +17 from the two new files).

**CODE_REVIEW findings closed this commit:**

- §3 — "wire dormant systems" for realm control. **Done.**
- §3 — "wire dormant systems" for faction conquest. **Done.**

Remaining Sprint 5c work (DataLoader cache invalidation + HUD polish) lands in the companion commit.

---

## 2026-04-16 — Sprint 7 prep: engineering scaffolding (parallel to Sprint 5b)

NEXT_STEPS Sprint 7 engineering-only prep. Non-breaking scaffolding that doesn't require the `.blend` rework — closes four of the CODE_REVIEW §6A findings without touching the runtime geometry hacks (those stay TODO-marked until a Blender-first .blend arrives).

**New files:**

- `godot/data/cutscenes/_registry.json` — cutscene registry with schema `{id, scene_path, dialogue_path, camera_animation_name, camera_path_json, title, arc, tags, notes}`. `no_tail_outpost` is the first entry. Adding a new cutscene becomes a data-only operation once the registry-driven bootstrap lands (still pending the .blend rework).

**Modified files:**

- `godot/scripts/autoload/event_bus.gd` — added `signal cutscene_completed(cutscene_id: String, karma_delta: int, recruited: Array)`. Replaces the `"In a real game, transition back to the main scene here."` print stub in cutscene_scene.gd.
- `godot/scripts/systems/cutscene/cutscene_scene.gd` — `_on_cutscene_finished` now emits `EventBus.cutscene_completed` with the CutsceneManager's accumulated karma delta + recruited ids. Added `@export var cutscene_id: String = "no_tail_outpost"` default matching the registry entry. Six TODO(S7) headers added to the runtime geometry hacks (`_hide_back_wall`, `_build_interior`, `_apply_burn_marks`, `_hide_placeholder_characters`, `_force_red_light_fixture`, and the `MaterialApplicator.apply()` call site), each back-referencing the CODE_REVIEW step that explains why it belongs in the .blend. Makes the eventual deletion mechanical.
- `godot/scripts/systems/cutscene/cutscene_manager.gd` — `_fade_in_character` rewritten to use per-surface duplicated override materials (`set_surface_override_material(s, dup)` during tween, `set_surface_override_material(s, null)` on completion). Shared material resources are no longer mutated — transparency state can't leak across mesh instances that share a material, which was the CODE_REVIEW §6A.3 finding.
- `godot/scripts/systems/cutscene/camera_controller.gd` — 4-space indentation → tabs via `python3` pass. 106 lines converted. Project convention restored (CODE_REVIEW §6A.2 closed).

**CODE_REVIEW §6A findings closed:**

- §6A.2 — camera_controller indentation. **Done.**
- §6A.3 — `_fade_in_character` shared-material mutation. **Done.**
- §6A.3 — return flow stub. **Signal emit done** (SceneManager listener still pending a real consumer).
- §6A.6 step 10 — cutscene registry. **Done** (with extended schema).

**Still blocked on human artist / Blender rework:** Everything in CODE_REVIEW §6A.1 (runtime geometry anti-pattern) and §6A.6 steps 1–4 (rebuild .blend, bake AnimationPlayer camera, rewrite cutscene_scene.gd ≤ 100 lines, delete MaterialApplicator). The TODO(S7) markers in `cutscene_scene.gd` are the inventory for mechanical deletion.

**Tests:** Full GUT suite still **121/121 passing** — these are engineering-only, non-runtime-regressing changes (EventBus signal addition + cutscene `_on_cutscene_finished` wiring + per-surface override fade + indentation conversion + documentation markers).

---

## 2026-04-16 — Sprint 5b: Wire dormant systems (crew morale + astral hazards)

NEXT_STEPS Sprint 5b. Wired crew morale into combat damage and trade pricing — the first two of four "dormant" systems flagged in CODE_REVIEW §3 now drive player-visible behaviour. Discovery during audit: astral hazards were already wired (stale tracker), retired from the plan rather than re-implemented.

**Crew morale wiring:**

- `godot/scripts/systems/combat_system.gd` — `CombatSystem.calculate_damage(attacker_fp, defender_armour, crew_bonus, combat_skill, crit_chance, morale_modifier = 1.0)`. New 6th parameter scales `effective_fp` multiplicatively after the crew-trait + combat-skill bonuses, before armour subtraction. Default 1.0 keeps the existing 62-test combat suite untouched.
- `godot/scripts/ui/combat/combat_logic.gd` — `resolve_player_attack(..., player_morale_modifier = 1.0)` threads the modifier into `calculate_damage`. Enemy attacks unchanged — no enemy morale model.
- `godot/scripts/ui/view_models/combat_view_model.gd` — new `combat_morale_modifier()` adapter. Null-guarded three ways: missing `game_state`, missing `crew_morale` field on the session, and null system reference. Returns 1.0 in all unsafe cases so UI-only tests (no autoload) keep passing.
- `godot/scripts/ui/combat_ui.gd` — `_on_attack` calls `_vm.combat_morale_modifier()` and passes it through to `resolve_player_attack`.
- `godot/scripts/systems/economy_system.gd` — `get_buy_price`, `get_sell_price`, `buy_crystals`, `sell_crystals` all take `morale_modifier: float = 1.0`. Buy side applies it directly (low morale = higher price). Sell side inverts via `sell_morale = 2.0 - m` so INSPIRED morale raises sell revenue and MUTINY lowers it — keeps the "low morale hurts the player on BOTH sides" invariant the morale system intends.
- `godot/scripts/ui/trade_screen.gd` — `_on_buy` / `_on_sell` call a new `_get_trade_morale_modifier()` helper that fetches from `GameSession.crew_morale.get_trade_modifier(game_state)`. Falls back to 1.0 if the morale system is unavailable (early boot, tests).

**Astral hazards — stale tracker retired:**

Grep during the 5b audit revealed `navigation.gd:213` has called `_update_astral_hazards(dt)` every frame since the hazard feature shipped (entropy timer + dynamic spawn, collision detection, status HUD, off-course drift — all already alive). The NEXT_STEPS + MASTER_PLAN + CODE_REVIEW rows that listed "apply astral hazards during navigation tick" as pending were never accurate. Retired the rows with a back-reference to this audit. Third stale-tracker retirement this cycle (following R-key collision and the two morale null-guard rows in Sprint 1).

**Dormant-systems count:**

- Before Sprint 5b: 4 dormant (crew morale, astral hazards, realm control, faction conquest).
- After Sprint 5b: 2 dormant (realm control, faction conquest) — both scheduled for Sprint 5c.

**New test files:**

- `godot/tests/unit/test_crew_morale_combat_wiring.gd` — 12 tests across three layers: raw `CombatSystem.calculate_damage` math (morale scales damage, extreme 2.0 vs 0.4 ranges don't overlap, default param neutral), `CombatLogic.resolve_player_attack` thread-through (averaged over 60 samples to smooth ±20% variance), `CombatViewModel.combat_morale_modifier()` null-guards + real-system integration (constructs a `SessionDouble` with a real `CrewMoraleSystem` and verifies MUTINY→0.7 / INSPIRED→1.2 thresholds).
- `godot/tests/unit/test_crew_morale_trade_wiring.gd` — 12 tests covering `get_buy_price` (low morale raises, high morale lowers, karma×morale compose multiplicatively, default is neutral), `get_sell_price` (directionality inverted as designed), `buy_crystals` / `sell_crystals` charge-and-credit round-trips at low vs neutral morale, and sanity checks that transactions still succeed at non-neutral morale.

**Metrics:**

- `rg "GameSession\." godot/scripts/ui | wc -l` → **106** (unchanged — morale is threaded via VM in combat, via `GameSession.crew_morale` helper in `trade_screen.gd` which keeps the existing GameSession refs).
- Full GUT suite: **121/121 passing** (was 97/97; +24 tests across 2 new files).
- Dormant systems: 4 → **2**.

**Command:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

**Findings / learnings surfaced:**

- Typed fields in test doubles silently reject foreign types (e.g. assigning a real `CrewMoraleSystem` to a `var crew_morale: MoraleDouble` field no-ops). Untype the field when the double must hold either stub or real system. Captured in `docs/GODOT_NOTES.md`.
- "Wire X into Y" tracker items should be grepped against the candidate call-site before implementation — stale tracker pattern has now surfaced in Sprints 1 (two of the four critical bugs), 3c (R-key), and 5b (astral hazards). Also captured in `GODOT_NOTES.md` as a standing rule.

Sprint 5c (dock gating via realm_control + reputation, faction conquest surfacing as distress spawns / blockades, DataLoader cache invalidation per MASTER_PLAN §5.3 Apr-05 #4 + #12, HUD polish with segmented hull bar + objective + morale pip) is the finish line for the dormant-systems work. Sprint 7 (3D cutscene Blender-first modernisation) is parallelisable with 5c and has its engineering-prep scaffolding landing in the companion commit alongside this one.

---

## 2026-04-16 — Doc alignment sweep (post-Sprint 5a)

Full tidy pass across every canonical plan / reference doc to reconcile numbers, statuses, and cross-references with what actually shipped in Sprints 1, 3a, 3b, 3c, and 5a. No code changes.

**Docs updated:**

- `docs/MASTER_PLAN.md` — §2 metrics refreshed against measured ground truth (81 GDScript files, 70 signals, 83 JSON files, 97 tests across 12 files, 106 UI + 131 total `GameSession.` refs); §3 architecture summary now states the ViewModel pattern; §5.4 #19 (star_map_screen) and #22 (test suite) closed; autoload table signal count corrected 120+ → 70.
- `docs/architecture/CODE_REVIEW.md` — §0 re-measurement table extended with a "Post-Sprint 5a" column and a per-sprint progress bullet list; §1 critical-concerns list marked closed where closed; §2.1 rewritten to document the shipped VM pattern + remaining-screens list; §2.4 EventBus audit reports actual signal count (70); §5.2 input-collision status refreshed (R-key fixed; pause/skip on ESC logged); §7 Quick Wins split into Done / Outstanding with original tracker numbers preserved; §8 verification baselines bumped to 131 / 106 / 97-tests.
- `docs/REFACTORING_PLAN.md` — status header + phase-summary table at top; Phases 1, 2, 3 each annotated DONE with shipped artifact paths; Sprint Schedule mapped to NEXT_STEPS slicing; Success Criteria checkboxes ticked where they hold today.
- `docs/NEXT_STEPS.md` — §1 Track E prose reflects progress; §5 "What to do today" replaced stale bootstrap items with the current four options (5b / 5c / 7 / artist pilot).
- `docs/STRUCTURE.md` — date refreshed to 2026-04-16; EventBus signal count 120+ → 70; `npc_bark` signal row added; new `scripts/ui/{view_models,combat,star_map}/` subdirectories documented at the head of UI Screens.
- `docs/GODOT_NOTES.md` — autoload count fixed three → four (ProceduralMapManager was missing); added seven engine learnings surfaced by Sprints 3c and 5a (coroutines on freed nodes, dedicated signals for recursion safety, static caches on non-RefCounted classes, InputMap introspection, VM pattern, integer-division warning, RefCounted set_meta inheritance).
- `docs/PLAN.md` — clarified as template-only; pointed at NEXT_STEPS as the live sprint list.
- `CLAUDE.md` — added the ViewModel rule to Architecture Rules so next agents find the convention at onboarding.

**Standing instruction captured** in my persistent memory (`63c52d1b-dca4-44a1-b3b4-5911f86acaee`): every substantive code change now triggers an automatic tidy-and-align pass across these same docs before declaring work done. Scope, invariants, and output shape are listed in the memory.

**Verification:** full GUT suite still **97/97 green** (docs-only changes).

---

## 2026-04-16 — Sprint 5a: StarMapViewModel + star_map_screen.gd decomposition

NEXT_STEPS Sprint 5a. Decomposed the third and last of the original three UI god-scripts (`star_map_screen.gd`, 1,092 lines) and introduced `StarMapViewModel` as the sole path from the screen and its layer components to `GameSession`. Follows the pattern established by `NavigationViewModel` (Sprint 3a) and `CombatViewModel` (Sprint 3b).

**New files:**

- `godot/scripts/ui/view_models/star_map_view_model.gd` — 184-line `RefCounted` adapter. Exposes `has_state`, `current_region`, `player_position`, the `star_map`/`exploration` escape hatches, narrow wrappers (`region_bounds`, `galaxy_nodes`, `galaxy_node_pos`, `galaxy_node_color`, `region_fog_percentage`, `has_map`, `cartographer_rescued`, `region_map`, `grid_dimensions`, `is_cell_revealed`), POI accessors (`visible_story_pois`, `visible_hidden_pois`, `visible_spawns`), exploration lookups (`region_info`, `region_is_discovered`, `region_display_name`), and actions (`travel_to_region`, `set_world_entry_region`). Every accessor is null-guarded so it can be called before `_init_systems` has run.
- `godot/scripts/ui/star_map/star_map_galaxy_layer.gd` — 367 lines. Draws the top-level galaxy graph (nodes, connections, fog arcs, danger pips, legend, info box, travel-confirm dialog).
- `godot/scripts/ui/star_map/star_map_region_layer.gd` — 320 lines. Draws the circular sector view (procedural backdrop, vignette, grid, fog-of-war, POIs, player, spawn zones, legend, chrome).
- `godot/scripts/ui/star_map/star_map_local_layer.gd` — 258 lines. Draws the player-centered zoomed scan (grid, fog, region boundaries, POIs including nav-controller contacts, player vision ring, chrome).
- `godot/tests/unit/test_star_map_view_model.gd` — 20 tests using `SessionDouble` + RefCounted `StarMapDouble` / `ExplorationDouble`. Covers game state, star-map wrappers, POI delegation (including game-state pass-through to `get_visible_story_pois`), exploration lookups, travel action, and world-entry meta write.

**Decomposed / rewritten:**

- `godot/scripts/ui/star_map_screen.gd` — **1,092 → 375 lines**. Now an orchestrator only: per-layer backdrop caching, layer transitions (`_drill_to_region`, `_zoom_to_galaxy/local/region`), galaxy selection navigation, input routing, travel confirm flow, and per-frame context-dict assembly for each layer. Injected VM via `initialize(vm)` (mirrors `navigation.gd` / `combat_ui.gd`), with a `_ready` fallback that constructs a VM from the `GameSession` autoload so the existing `main.gd` scene-switch flow stays untouched.

**Metrics:**

- `wc -l godot/scripts/ui/star_map_screen.gd` → **375** (was 1,092, -66%).
- `rg "GameSession\." godot/scripts/ui/star_map_screen.gd` → **0** (was 23).
- `rg "GameSession\." godot/scripts/ui/star_map/` → **0** across all three layer files (they only touch the VM).
- `rg "GameSession\." godot/scripts/ui | wc -l` → **106** (was 129; NEXT_STEPS Sprint 3 exit target ≤140 comfortably held; Sprint 5 exit target ≤110 met).

**Tests:** 20 new in `test_star_map_view_model.gd`. Full suite: **97/97 passing** (was 77/77).

Sprint 5b (wire dormant systems: crew morale → combat / trade; astral hazards during navigation tick) and Sprint 5c (dock gating, conquest surfacing, DataLoader cache fixes, HUD polish) are next.

---

## 2026-04-16 — Sprint 3c: Should-fix bugs closed

NEXT_STEPS Sprint 3c. Closed the four medium-priority bugs carried from the Mar-27 and Apr-05 reviews. Each fix ships with targeted regression coverage.

**Bug fixes:**

- **Mar-27 §2.4 — R-key collision (`menu_select` vs `repair`)**: stale tracker entry. `repair` was already rebound R→T in Sprint 1 (see 2026-04-16 Sprint 1 entry below). Added `godot/tests/unit/test_input_map_collisions.gd` as a broad regression guard that walks every user-defined action and rejects any two sharing a keycode. Context-separated intentional overlaps (currently just `pause`/`skip` on ESC) are whitelisted with a MASTER_PLAN §5.3 back-reference.
- **Mar-27 §2.3 — `scene_transition.gd` tween after scene change**: the old `_do_transition` kept awaiting `tree.process_frame` on the Area2D after calling `change_scene_to_file`, i.e. on a node the scene swap was about to free. Moved the post-change half (position player + fade-in) into `GameSession.complete_scene_transition(spawn_position, spawn_facing, fade_duration)` — a persistent autoload whose coroutine survives any scene swap. `scene_transition.gd` now simply delegates after initiating the change. The tree-owned tween that performs the fade-in is created by GameSession, so there is no path left where a tween's owner becomes freed mid-animation.
- **Mar-27 §2.5 — `_show_bark` recursion risk**: `_show_bark` used to emit `EventBus.exploration_event` with `type: "npc_bark"`, and `dialogue_manager._on_exploration_event` is connected to the same signal — one future branch that decided to handle barks there would have caused unbounded recursion. Added a dedicated `EventBus.npc_bark(npc_name, text)` signal and migrated the emit. Re-entry is now structurally impossible.
- **Apr-05 #7 — Per-pixel portrait processing every dialogue open**: `DialogueUI._remove_near_white_bg` walks every pixel of the portrait texture. Added `DialogueUI._processed_portrait_cache` — a static `Dictionary` keyed by `source resource_path + hard_threshold + soft_threshold` — so the O(w·h) work runs once per portrait per process. Textures without a `resource_path` (e.g. synthetic textures in tests) still recompute on each call to avoid caching transient inputs.

**New files:**

- `godot/scripts/autoload/game_session.gd` — `complete_scene_transition(spawn_position, spawn_facing, fade_duration)` + `_position_player_after_transition` + `_fade_in_transition_overlay` helpers.
- `godot/tests/unit/test_input_map_collisions.gd` — 2 tests, broad collision guard + `menu_select`/`repair` specific regression.
- `godot/tests/unit/test_dialogue_manager_bark.gd` — 3 tests; proves `_show_bark` emits `EventBus.npc_bark` and never `exploration_event`.
- `godot/tests/unit/test_portrait_cache.gd` — 6 tests; covers null input, missing `resource_path` (no cache), cache hit by same path, separation by different paths and thresholds, and correctness of the alpha masking.
- `godot/tests/unit/test_scene_transition_handoff.gd` — 4 tests; verifies `GameSession.complete_scene_transition` exists, `scene_transition.gd` delegates to it (source-level structural check — no `await tree.process_frame` after `change_scene_to_file`), and the helpers tolerate missing player / null target scene without crashing.

**Modified files:**

- `godot/scripts/autoload/event_bus.gd` — added `signal npc_bark(npc_name: String, text: String)`.
- `godot/scripts/world/dialogue_manager.gd` — `_show_bark` now emits the dedicated signal.
- `godot/scripts/world/scene_transition.gd` — simpler; removed `_position_player_in_new_scene`; hands off to `GameSession.complete_scene_transition` after the swap.
- `godot/scripts/ui/dialogue_ui.gd` — added `_processed_portrait_cache` + `_portrait_cache_key`; `_remove_near_white_bg` consults the cache before walking pixels.

**Findings surfaced during 3c:**

- `pause` and `skip` both bind to `KEY_ESCAPE` (4194305). They're context-separated (pause in navigation/combat, skip in intro_crawl/cutscene) so they're whitelisted in the new collision test for now. Logged in MASTER_PLAN §5.3 for the Sprint 6 input-rebind panel work.

**Metrics:**

- Full GUT suite: **77/77 passing** (was 62/62; +15 tests across 4 new files).
- Command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` (pre-existing splash boot resource leak warnings at exit are unchanged — tracked memory).

Sprint 3 (a/b/c) is now fully closed. Next up per NEXT_STEPS: Sprint 4 (art roll-out, pending artist) in parallel with Sprint 5 (star map decomposition + system wiring).

---

## 2026-04-16 — Sprint 3b: CombatViewModel + combat_ui.gd decomposition

NEXT_STEPS Sprint 3b. Decomposed `combat_ui.gd` (the second-largest UI script, 585 lines) into five focused components per `REFACTORING_PLAN.md` Phase 2, and introduced `CombatViewModel` as the sole path from the screen to `GameSession`.

**New files:**

- `godot/scripts/ui/view_models/combat_view_model.gd` — narrow `RefCounted` adapter around `GameSession`. Exposes `sync_player_hull(hull)` and `apply_victory_loot(crystals, salvage)` with null-guards so the screen's `_finish` path is callable without a live session.
- `godot/scripts/ui/combat/combat_layout.gd` — static `compute(viewport_size, design_w, design_h) -> Dictionary` that returns every ship / label / bar position. Pure math, no node refs, fully unit-testable.
- `godot/scripts/ui/combat/combat_logic.gd` — static `resolve_player_attack`, `resolve_enemy_attack`, `resolve_flee`. Returns result dicts (`hit`, `damage`, `target_dead`, `log_messages`, `event_signals`, `new_attempts`) — no UI / EventBus coupling. An optional duck-typed `rng` argument lets tests pin dodge / flee rolls deterministically.
- `godot/scripts/ui/combat/combat_animations.gd` — `Node` child added by `combat_ui` at runtime. Owns the laser `Line2D` references, the laser tween, and the per-ship shake timers. Emits `hit_landed(side)`.
- `godot/scripts/ui/combat/health_bar.gd` — static `draw(canvas, rect, current, max)` reusable steampunk brass-frame health bar renderer.

**combat_ui.gd changes:**

- Added `initialize(vm)` hook mirroring `navigation.gd`; `_ready` falls back to constructing a VM from the `GameSession` autoload.
- `_layout` delegates all geometry to `CombatLayout.compute` and applies the returned frame to nodes.
- `_on_attack`, `_on_flee`, `_enemy_attack` resolve via `CombatLogic.*` and apply log messages + EventBus signals through a single `_apply_log_and_events` helper.
- Laser + shake dispatched through a `CombatAnimations` child node.
- Health bar `_draw` handler delegates to `CombatHealthBar.draw`.
- `_finish` uses the VM for hull sync and loot application.
- Scene path unchanged (`res://scripts/ui/combat_ui.gd`); `combat_ui.tscn` needs no edit.

**Metrics:**

- `wc -l godot/scripts/ui/combat_ui.gd` → **399** (was 585, -32%).
- `rg "GameSession\." godot/scripts/ui/combat_ui.gd` → **0** (was 4).
- `rg "GameSession\." godot/scripts/ui` total → **129** (was 134; Sprint 3 exit target ≤140 comfortably held).

**Tests:** Three new files, 31 new tests:

- `test_combat_view_model.gd` — 8 tests for `has_state`, `sync_player_hull` (happy + two null no-op paths), `apply_victory_loot` (add + null no-op + zero-amount).
- `test_combat_layout.gd` — 12 tests covering zero-sized guard, unit-scale native resolution, porthole symmetry, 2× scaling, ultrawide cover, bar rect parity, font floors, ship-rect consistency, log height, action centring.
- `test_combat_logic.gd` — 11 tests covering hit / miss / fatal branches of player and enemy attacks, flee success / failure / attempt-counter increment / 0.95 cap. Uses a lightweight `StubRng: RefCounted` stub for deterministic dodge / flee rolls (GDScript cannot override the native `RandomNumberGenerator.randf`).

Full suite: **62/62 passing**.

Sprint 3c (should-fix bugs: R-key, scene_transition tween, `_show_bark` recursion, portrait cache) is next and independent.

---

## 2026-04-16 — Sprint 3a: NavigationViewModel + navigation.gd conversion

NEXT_STEPS Sprint 3a. Introduced the view-model layer prescribed by CODE_REVIEW.md §2.1 and converted `navigation.gd` (the largest UI script, 1723 lines) to consume it.

**New file:** `godot/scripts/ui/view_models/navigation_view_model.gd` — a narrow `RefCounted` adapter that wraps GameSession. Exposes ~30 methods for state reads, system-call forwarding, and actions. Two escape hatches (`star_map()` and `astral_hazards()`) return the underlying systems for the deep draw-loop access paths where wrapping each method would triple the VM size.

**navigation.gd changes:**

- Added `initialize(vm)` hook so tests can inject a VM; `_ready` falls back to constructing one from the `GameSession` autoload in production.
- Every `GameSession.` access replaced with `_vm.` call. Direct state writes to `position_x/y` consolidated into a single `_vm.set_position()` call in `_handle_movement`.
- `_check_boundary` no longer reaches into `GameSession.exploration` — uses `_vm.connected_regions(region)` instead.

**Metrics:**

- `rg "GameSession\." godot/scripts/ui/navigation.gd` → **0** (was 73).
- `rg "GameSession\." godot/scripts/ui` total → **134** (was 206; Sprint 3 exit target was ≤140, already met).

**Tests:** `godot/tests/unit/test_navigation_view_model.gd` — 22 tests covering state reads, state writes, star-map delegation, encounter/mission/narrative/karma pass-through, exploration edge cases, and action forwarding. Uses a `SessionDouble` + per-system test doubles instead of the real autoload so the VM can be exercised in isolation. Full suite: 31/31 passing.

Sprint 3b (CombatViewModel + `combat_ui.gd` decomposition) is next. Sprint 3c (should-fix bugs: R-key, scene_transition tween, `_show_bark` recursion, portrait cache) is independent and can interleave.

---

## 2026-04-16 — Sprint 2 (partial): Art direction commitment

NEXT_STEPS Sprint 2, engineering-tractable portion. Removed the "to be decided" line from `design/art_direction/art_direction_guide.md` and committed to the two-track approach: **Track A** (native 64×64 / exported 256×256 sprites, 12–16 colour palette, shaded) as the floor for all characters, **Track B** (painterly portrait cards) as an aspirational layer for the named cast only. Added a "Reference Pins" section listing Stardew Valley, Death's Door, Moonlighter, Eastward, and Sea of Stars as calibration benchmarks.

Sprint 2 remaining: Aristotle spritesheet pilot redraw + in-game parity screenshot (human art work).

---

## 2026-04-16 — Sprint 1: GUT + Critical Bug Triage

NEXT_STEPS Sprint 1. Installed the GUT test framework and closed the four critical bugs in MASTER_PLAN §5.2 — two required fixes, two were already fixed in current code and the tracker was stale.

**Fixes:**

- **Apr-05 #1** `trigger_encounter_id` never evaluated → removed the dead field from `Encounter.EncounterOutcome` (both the `@export` and the `from_dict` key). No JSON data referenced it. Chain triggers are a "add when needed" feature, not something to implement speculatively.
- **Apr-05 #2** hull death not emitted from hazard damage → `AstralHazardSystem.apply_damage` now emits `EventBus.combat_defeat` when hazard damage brings `current_hull` from > 0 to 0. Guarded against double-emit if called while already dead.
- **Mar-27 §2.1** morale `player_ship` null guard → already present in current code (all five cited methods guarded); tracker is stale.
- **Mar-27 §2.2** `dialogue_manager.push_overlay` API → already fixed; line 104 passes the `"dialogue"` scene-key string as `main.push_overlay(scene_key: String)` expects.

**Test framework:**

- Installed GUT 9.6.0 (vendored at `godot/addons/gut/`, plugin enabled in `project.godot`). Vendored rather than submoduled to match the existing `procedural_world_map` addon convention.
- Added `godot/tests/unit/` with three test files: `test_math_utils.gd` (sanity), `test_encounter_outcome.gd` (regression for #1), `test_astral_hazard_hull_death.gd` (regression for #2 + null-ship guard).
- Headless run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` → 9/9 passing, 0.465s.

---

## 2026-04-16 — Repo Tidy + Enhanced Code Review + NEXT_STEPS Plan

Enhanced code review pass; added sprite modernisation plan and 3D cutscene review; reconciled planning docs; tidied repo root.

**Docs added / changed:**

- `docs/architecture/CODE_REVIEW.md` — full rewrite. Updated metrics (navigation.gd 1723 lines, 206 UI→GameSession refs, 236 total). Added §6 "Visual Cohesion" (painted portraits vs 32×32 sprites). Added §6A "3D Cutscene Review" (No Tail Outpost — ~500 lines of runtime model-patching that belongs in Blender). Added §9 MASTER_PLAN reconciliation.
- `docs/NEXT_STEPS.md` — new. Two-track sprint plan (engineering + art) reconciled with MASTER_PLAN.md §7. Sprint 7 dedicated to Blender-first cutscene modernisation.
- `docs/README.md` — new. Documentation index.
- `docs/MASTER_PLAN.md` — doc-index paths qualified (`STRUCTURE.md` → `docs/STRUCTURE.md`, etc.); added entries for NEXT_STEPS, CODE_REVIEW, GODOT_NOTES.
- `docs/GODOT_DEV_GUIDE.md` — workflow table updated (STRUCTURE.md + MEMORY.md location bug fixed); examples path corrected.
- `README.md` — STRUCTURE.md link fixed; added NEXT_STEPS and CODE_REVIEW entries.

**Repo tidy:**

- Deleted `other_data/` (1.3 GB Pioneer-lineage source, unused).
- Deleted `backup_assets/` (20 MB stale music).
- Deleted `logs/runtime.log` (one-off debug).
- Deleted `.DS_Store` files (gitignored; were never tracked).
- Moved `examples/godot-patterns/` → `docs/godot-reference/examples/godot-patterns/`; removed empty `examples/` dir.
- Moved `docs/sprite_sheet_notes.md` → `design/art_direction/sprite_sheet_notes.md`.
- Renamed `docs/MEMORY.md` → `docs/GODOT_NOTES.md` (Godot engineering notes, not an auto-memory duplicate).
- Deleted orphaned `tools/import_assets.sh` and `tools/rollback_import.sh` (referenced now-deleted `other_data/` and `backup_assets/`; the one-time import had already been completed and assets are in `godot/assets/`).
- Updated `.claude/PROJECT_INDEX.md` to remove stale `other_data/` / `backup_assets/` / `examples/` entries and point to the new plan docs.
- Repo size: ~5.0 GB → ~3.7 GB.

**Notes:**

- Auto-memory entries added: visual-style mismatch, coupling baseline + plan hierarchy, 3D cutscene state.
- No code changes in this pass — review + plan + tidy only.

---

## 2026-04-07 — Star Base Texture Rendering

Added star base texture support mirroring the planet texture work.

**Changed:**

- `scripts/entities/star_base.gd` — added `image` field to StarBase entity
- `scripts/ui/navigation.gd` — replaced procedural diamond rendering with `draw_texture_rect()` using cached starbase textures; added `_get_starbase_texture()` helper; kept diamond fallback for bases without images
- `data/star_bases/star_bases.json` — added `image` field to all 6 existing bases; added Knight's Bastion (knight_kingdoms) as 7th star base

**Assets:**

- 7 starbase texture PNGs in `assets/starbases/` (starbase_1.png–starbase_7.png)

---

## 2026-04-07 — Planet Texture Rendering

Replaced procedural circle-drawn planets on the star map with actual PNG texture assets.

**Changed:**

- `scripts/entities/planet.gd` — added `image` field to Planet entity for texture references
- `scripts/ui/navigation.gd` — replaced `draw_circle()` planet rendering with `draw_texture_rect()` using cached planet textures; added `_get_planet_texture()` helper with lazy-loading cache
- `data/planets/planet_registry.json` — added `image` field to all 3 existing planets; added 10 new planet entries for all remaining galaxy regions (feline_courts, canine_order, knight_kingdoms, twilight_bazaar, iron_expanse, warp_marches, bone_yard, shattered_prides, deep_space, cradle_of_whispers)

**Assets:**

- 13 planet texture PNGs now in `assets/planets/` (planet_1.png–planet_13.png), one per galaxy region

---

## 2026-04-05 — Documentation Audit, Reconciliation & Restructuring

Comprehensive documentation review against the live codebase with full restructuring.

**Archived (moved to `docs/archive/`):**

- Python-era TRDs (TRD-001, TRD-002, TRD-003) moved to `docs/archive/architecture/` with archival headers
- Superseded feature proposals (planets, reputation, skill allocation, star bases) moved to `docs/archive/features/` with implementation status annotations
- Old MASTER_PLAN (2026-03-20) moved to `docs/archive/plans/`
- Completed feature plans (2D world layer, astral hazards, crew missions, Fringe Haven checklist) moved to `docs/archive/plans/`

**Created:**

- `docs/MASTER_PLAN.md` — new authoritative project plan consolidating all active requirements, open issues (from April code review), technical debt, and roadmap

**Updated:**

- `STRUCTURE.md` — full rewrite reflecting all 4 autoloads, 22 systems, 23 UI screens, 8 entities, world scenes, 120+ EventBus signals, shaders, addon
- `CLAUDE.md` — updated to 4 autoloads, dual protagonist description, corrected docs/ description
- `README.md` — corrected status claims, added April code review reference, updated documentation links
- `AGENT_BRIEFING.md` — added status note about dual protagonist and 10-arc expansion scope
- `docs/GAME_SUMMARY.md` — added implementation status note distinguishing Arcs 1-4 (complete) from Arcs 5-10 (data exists, untested), updated technical summary
- `docs/GODOT_DEV_GUIDE.md` — updated workflow document references to point to new MASTER_PLAN location
- `story/characters/character_profiles.md` — fixed Aristotle and Dave stats to match `data/characters/protagonists.json` (source of truth), noted Dave as dual protagonist
- `docs/architecture/decisions/ADR-001` — annotated as historical (Python prototype phase)
- `docs/plans/astral-hazards-feature-plan.md` — marked COMPLETE with delivery summary

**Discrepancy resolution:**

- Aristotle's stats in character_profiles.md (old: Leadership 7, Negotiation 6, Combat 6, Intimidation 4, Stealth 3) corrected to match protagonists.json (Leadership 6, Negotiation 4, Combat 5, Intimidation 6, Stealth 7)
- Dave's stats similarly corrected (old: Cunning 5, Negotiation 5, Intimidation 7; new: Cunning 4, Negotiation 6, Intimidation 5)

---

## 2026-03-27 — Code Review Fixes (P0 + P1)

**Bug Fix / Refactor:** Applied fixes from full codebase code review, addressing critical bugs, performance issues, and code quality.

### P0 — Critical Fixes

- **Fixed** `dialogue_manager.gd` passing a Control instance to `push_overlay()` instead of a scene key string — was a runtime crash
- **Fixed** R key input collision — `repair` action rebound from R (keycode 82) to T (keycode 84) to avoid conflict with `menu_select`
- **Added** null guards for `player_ship` in all `CrewMoraleSystem` methods — prevents crashes during early init or corrupted saves
- **Fixed** `dialogue_manager.gd` using `.get("reputation")` on Faction object — now correctly reads `.reputation_with_player`

### P1 — Pre-Alpha Fixes

- **Refactored** `EncounterEngine` — extracted shared `_apply_outcome()` helper to eliminate duplicated outcome logic between `apply_choice_outcome()` and `apply_dialogue_step_outcome()`
- **Added** bounds check on `choice_index` in `apply_choice_outcome()` to prevent out-of-range crash
- **Added** save data version migration framework in `SaveManager._migrate_save_data()`
- **Fixed** scene transition tween lifetime — fade-in after scene change now uses `tree.create_tween()` instead of `create_tween()` to avoid operating on a freed node
- **Added** playtime tracking — `GameSession._process()` now increments `game_state.playtime_seconds`
- **Fixed** atomic save race condition — removed explicit delete-before-rename; previous save now backed up as `.bak`
- **Replaced** `print()` calls with `print_debug()` in `save_manager.gd` and `crew_morale_system.gd`

### Additional Improvements

- **Fixed** `star_map_screen.gd` calling `queue_redraw()` every frame — now throttled to every 0.5s
- **Removed** unnecessary `move_and_slide()` calls with zero velocity in NPC idle/talk states
- **Added** `has_active_overlay()` public method to `main.gd` — `navigation.gd` now uses it instead of accessing private `_overlay_stack`
- **Removed** unnecessary `randomize()` call in `navigation.gd` (Godot 4 auto-randomizes)

---

## 2026-03-26 — Map Layout, Building, Tree, and Bridge Overhaul

**Enhancement:** Fixed building layering, tree consistency, and bridge construction. Added landing island as player spawn point.

### Changes

- **Fixed** building `roof_rows` — Bryn's Oddities and Blacksmith now use `roof_rows=2` so full roof renders on top layer instead of being split with walls
- **Fixed** Blacksmith atlas position from unconfirmed `(5,30)` to confirmed `(0,30)` (GREEN Large)
- **Removed** Tower annex building that used unconfirmed atlas position `(10,30)` causing garbage tiles
- **Fixed** trees — removed teal/green mixing that caused visual clash; all trees now use consistent green `TREE_CANOPY` variants
- **Redesigned** water layout — upper bay, narrow channel, lower bay with a grass landing island (rows 11-16, cols 0-3)
- **Rebuilt** bridge — proper plank bridge with fence railings spanning the channel from landing island to mainland
- **Moved** player spawn to landing island `(2, 13)` — player arrives at outpost via bridge
- **Updated** water colliders to match new layout with bridge walkway excluded
- **Moved** hidden chests from former water area to landing island

---

## 2026-03-26 — Fix Water Tile Artifacts with Animated Water

**Bug Fix:** Replaced broken water tiles (which were referencing random prop/decoration tiles from the Serene Village atlas) with the proper `water_waves_32x32.png` animation strip as a dedicated tileset source.

### 2026-03-26 Changes

- **Added** `water_waves_32x32.png` as Source 2 in `world_tileset.tres` with 14-frame animation at 6 FPS (random start mode for natural variation)
- **Rewrote** `_paint_water()` in `fringe_haven_outpost.gd` — uses animated water tile for all water cells with edge detection for grass-water transition tiles from world_atlas row 18
- **Removed** incorrect `WATER` / `WATER_DEEP` constants that pointed to prop tiles (e.g. `Vector2i(12, 1)`, `Vector2i(3, 4)`) causing orange/brown artifacts
- **Added** shore edge tile constants (`SHORE_*`, `EDGE_*`) from world_atlas rows 9 and 18 for proper water-land transitions

---

## 2026-03-26 — Fringe Haven Tileset Upgrade (Serene Village)

**Enhancement:** Integrated Serene Village 32x32 asset pack as the primary tileset for Fringe Haven Outpost, replacing the flat placeholder tiles with rich pixel art buildings, terrain, and vegetation.

### Fringe Haven Tileset Upgrade Changes

- **Added** `godot/assets/tiles/fringe_haven/` — consolidated assets folder with Serene Village 32x32 atlas, Overworld tileset reference, and animated elements (campfire, water, door)
- **Archived** original asset packs to `design/archive/`
- **Updated** `world_tileset.tres` — dual-source tileset: Source 0 = legacy world_atlas (backward compat), Source 1 = Serene Village atlas (855 tiles)
- **Rewrote** `fringe_haven_outpost.gd` — complete procedural map generation using Serene Village building sprites (red/green/blue roofed buildings), 2-tile tall trees with canopy/trunk pairs, mixed water depths, dirt/plank roads, and proper roof/decor layer separation
- **Preserved** tavern.gd and planet_surface.gd compatibility via Source 0 legacy atlas

---

## 2026-03-26 — Rename Oakhaven to Fringe Haven

**Refactor:** Renamed the "Oakhaven Outpost" world scene to "Fringe Haven Outpost" to match the planet name from the planet registry. All file names, node names, scene paths, labels, and cross-references updated.

### Rename Oakhaven to Fringe Haven Changes

- **Renamed** `oakhaven_outpost.tscn` → `fringe_haven_outpost.tscn`, root node `OakhavenOutpost` → `FringeHavenOutpost`
- **Renamed** `oakhaven_outpost.gd` → `fringe_haven_outpost.gd`, updated in-game label to "FRINGE HAVEN OUTPOST"
- **Renamed** `build_oakhaven.gd` → `build_fringe_haven.gd`, updated success message
- **Renamed** `oakhaven-exact-match-asset-checklist.md` → `fringe-haven-exact-match-asset-checklist.md`
- **Updated** `navigation.gd` — `FRINGE_HAVEN_SCENE_PATH` now points to renamed scene
- **Updated** `star_map_screen.gd` — `WORLD_SCENE_MAP` starting_realm path updated
- **Updated** `tavern.tscn` — exit door `target_scene_path` updated
- **Updated** `tileset_generator_v2.py` — comment headers updated

---

## 2026-03-26 — Fix: Sprite disappearing during diagonal movement

**Bug Fix:** Player sprite would intermittently disappear while moving diagonally. The diagonal-to-cardinal animation fallback failed when `_facing` was already a diagonal direction, leaving the animation name unresolved and falling back to idle.

### Fix: Sprite disappearing during diagonal movement Changes

- **Fixed** `player_controller.gd` — simplified diagonal fallback to always pick the dominant axis (X or Y) for cardinal direction, removing the dependency on the previous `_facing` state that caused the bug

---

## 2026-03-25 — Fix: Sprite Sheets and Animation System

**Bug Fix:** Complete overhaul of character sprite rendering. Sprite sheets had dark opaque backgrounds, irregular grids with labels/gaps, and wrong frame coordinates causing broken animations (scattered body parts, black rectangles).

### Fix: Sprite Sheets and Animation System Changes

- **Processed** all 14 sprite sheets — removed dark backgrounds (transparent), extracted clean uniform 8×N grids of 128×128 frames (no labels, no gaps)
- **Regenerated** all 15 `godot/resources/*_spriteframes.tres` files — correct atlas regions for clean grid, proper row assignments (walk=rows 0-3, idle=rows 16-19), all 4 directional idles
- **Created** `whiskers_spriteframes.tres` and `whiskers_spritesheet.png` — placeholder using merchant sprite for Whiskers the Trader
- **Fixed** `planet_surface.gd` — updated SPRITE_COLS (4→8), frame size (293×144→128×128), dynamic vframes from texture height, removed runtime background removal
- **Fixed** `planet_screen.gd` — same sprite constant corrections

---

## 2026-03-26 — Feature: Tile-Based Planet Surface Overhaul

**Feature:** Replaced the draw-based planet_screen with a proper TileMap-based planet surface. Generates procedural town layouts with buildings, paths, trees, water features, fences, and scattered decor. New detailed pixel-art 32×32 tile atlas with 256 tiles across 16 terrain/object categories.

### Tile-Based Planet Surface Overhaul Changes

- **Created** `tools/godot-dev/tiles/tileset_generator_v2.py` — Detailed pixel-art tile atlas generator producing 512×512 atlas (16×16 grid) with textured grass, dirt paths, cobblestone, water with shores, tree canopies/trunks, building walls/roofs, doors, windows, signs, chests, barrels, crates, fences, bridges, stairs, and marker tiles
- **Created** `godot/scripts/ui/planet_surface.gd` — New planet surface controller extending Control with SubViewport-based tilemap rendering, procedural town layout generation, 8-direction player movement with collision, merchant/treasure entity placement, interaction system, and camera following
- **Created** `godot/scenes/ui/planet_surface.tscn` — Planet surface scene with Control root, SubViewportContainer+SubViewport hosting 4-layer TileMapLayers (Ground, Path, Decor, Roof), Entities node, and HUD overlay (title, loot, flash, depart button, controls hint)

### Tile-Based Planet Surface Overhaul Modified Files

- **Modified** `godot/assets/tiles/world_atlas.png` — Regenerated with detailed pixel-art tiles (was colored squares with labels)
- **Modified** `godot/resources/world_tileset.tres` — Updated terrain sets for new atlas layout (Grass, Dirt, Stone, Water, Wall, Roof, Wood, Fence)
- **Modified** `godot/scripts/ui/main.gd` — Planet scene key now points to `planet_surface.tscn`

### How It Works

- **Map Generation:** Each planet gets a deterministic tilemap layout seeded from `hash(planet_id)`. Layout includes grass ground, dirt crossroads with stone plaza, 4-8 randomly placed buildings with walls/roofs/doors/windows, edge and scattered trees, a water pond, fences, and decorative objects (barrels, crates, lamps, signs).
- **Player:** 8-direction movement with spritesheet animation, background-removed sprite, collision against walls/trees/water/hedges.
- **Entities:** Merchants shown as blue circle indicators with labels, treasures as chest tiles with golden indicators. Proximity-based interact prompts.
- **Camera:** Smooth-follow camera at 2× zoom centered on player.

---

## 2026-03-26 — Feature: Procedural Map Generator Integration

**Feature:** Integrated the ProceduralWorldMap plugin (FastNoiseLite-based) across navigation space view and Celestial Codex star map (planet surface uses tile-based approach instead). Each region gets a unique seed-based procedural backdrop with custom color palettes.

### Procedural Map Generator Integration Changes

- **Created** `godot/scripts/autoload/procedural_map_manager.gd` — ProceduralMapManager autoload singleton providing cached procedural textures for navigation (space nebulae), star map (galaxy/region backdrops), and planet surfaces (terrain maps). Includes region seed mapping, three distinct color palettes (space, galaxy, planet), region-specific tint colors, biome-aware planet terrain colors, and datasource lifecycle management.

### Procedural Map Generator Integration Modified Files

- **Modified** `godot/project.godot` — Enabled ProceduralWorldMap editor plugin; registered ProceduralMapManager as autoload singleton
- **Modified** `godot/scripts/ui/navigation.gd` — Added procedural nebula backdrop behind starfield; nebula pans with ship movement (quantized to 80-unit steps); regenerates on region transition; region-specific tint coloring
- **Modified** `godot/scripts/ui/star_map_screen.gd` — Added procedural galaxy backdrop to Galaxy layer with purple-tinted nebula clouds; added region-specific procedural backdrop to Region layer circular map view
- **Modified** `godot/scripts/ui/planet_screen.gd` — Replaced flat-color ground with procedural terrain texture; biome-aware color palette (settlement/industrial/enchanted/wilderness); subtle ambient tint overlay; semi-transparent grid lines over terrain

### Procedural Map Generator Integration How It Works

- **Navigation:** Quarter-resolution nebula texture rendered behind starfield, tinted per-region (e.g. purple-blue for The Fringe, warm amber for Feline Courts). Updates as ship moves across the map.
- **Celestial Codex:** Galaxy layer gets a fixed-seed galactic nebula backdrop; Region layer gets a per-region procedural texture behind the circular sector map.
- **Planet Surface:** Each planet gets a unique procedural terrain based on `hash(planet_id)` with biome-specific color shifting (e.g. enchanted planets get purple/teal tones).
- **Performance:** All textures generated at reduced resolution and cached. Navigation backdrop updates only every 80 world-units of movement.

---

## 2026-03-25 — Feature: Wire New Character Spritesheets

**Feature:** Added SpriteFrames resources for 12 new character spritesheets and updated the NPC controller to auto-load sprites by `npc_id` convention.

### Wire New Character Spritesheets Changes

- **Created** `godot/resources/blood_paw_spriteframes.tres` — Crew member Blood Paw
- **Created** `godot/resources/death_spriteframes.tres` — Rival captain Death
- **Created** `godot/resources/fairy_cartographer_spriteframes.tres` — Fairy Cartographer NPC
- **Created** `godot/resources/landlord_spriteframes.tres` — Landlord NPC
- **Created** `godot/resources/merchant_spriteframes.tres` — Merchant NPC
- **Created** `godot/resources/nine_lives_spriteframes.tres` — Crew member Nine Lives
- **Created** `godot/resources/no_tail_spriteframes.tres` — Crew member No Tail
- **Created** `godot/resources/npc_bard_spriteframes.tres` — Bard NPC
- **Created** `godot/resources/npc_guard_spriteframes.tres` — Guard NPC
- **Created** `godot/resources/npc_sailor_spriteframes.tres` — Sailor NPC
- **Created** `godot/resources/npc_urchin_spriteframes.tres` — Urchin NPC
- **Created** `godot/resources/silky_spriteframes.tres` — Crew member Silky

### Wire New Character Spritesheets Modified Files

- **Modified** `godot/scripts/world/npc_controller.gd` — Added `_load_sprite_frames()` to auto-load `res://resources/{npc_id}_spriteframes.tres` at ready time

---

## 2026-03-25 — Feature: Star Wars-Style Intro Crawl

**Feature:** Replaced the old typewriter cutscene intro with a Star Wars-style bottom-to-top scrolling text crawl. The text scrolls upward over a twinkling starfield, preceded by a fade-in title card. Enriched intro story text draws from full game lore — factions, crew members, rival threats, and the Whisper Crystals premise. Both Aristotle and Dave paths have unique, protagonist-specific crawl text (~15 paragraphs each).

### Star Wars-Style Intro Crawl Changes

- **Created** `godot/scripts/ui/intro_crawl.gd` — Star Wars-style crawl controller with phases (title fade-in/hold/fade-out → crawl scroll), twinkling procedural starfield, fast-forward (SPACE/DOWN) and skip (ESC) controls
- **Created** `godot/scenes/ui/intro_crawl.tscn` — Scene with starfield background, title container, SubViewportContainer for crawl text rendering, fade overlays, skip hint label

### Star Wars-Style Intro Crawl Modified Files

- **Modified** `godot/data/characters/protagonists.json` — Added `intro_crawl` arrays with 15-16 enriched story paragraphs per protagonist, covering factions, crew, threats, and setting
- **Modified** `godot/scripts/ui/main.gd` — Registered `intro_crawl` scene in SCENES dictionary
- **Modified** `godot/scripts/ui/skill_allocation.gd` — Changed post-confirm flow from `cutscene` → `intro_crawl`

---

## 2026-03-25 — Feature: 2D World Gameplay Layer

**Feature:** Added a full 2D world layer on top of the existing UI-screen-based game systems. Includes tilemap-based world scenes, a playable CharacterBody2D player, NPC state machines with pathfinding and dialogue triggers, scene transitions with fade effects, and an example interior (tavern). The Celestial Codex star map now supports travel-to-world-scene flow.

### Phase 1: Tileset Atlas Generator

- **Created** `tools/godot-dev/tiles/tileset_generator.py` — Pillow-based script generating a 288×256 atlas PNG with 32×32px tiles
- **Created** `tools/godot-dev/tiles/requirements.txt` — Pillow dependency
- **Output** `godot/assets/tiles/world_atlas.png` — 9×8 grid atlas with 6 terrain types (Grass, Dirt, Stone, Wall, Water, Roof) in 3×3 autotile layout, plus 18 decor/furniture tiles

### Phase 2: TileSet & TileMap World Scene

- **Created** `godot/resources/world_tileset.tres` — TileSet resource with 32×32 tile size, physics layer for collision, 6 terrain sets for autotiling
- **Created** `godot/scenes/world/world.tscn` — Main world scene with Node2D root (y_sort), GroundLayer/DecorLayer/RoofLayer TileMapLayer nodes, NavigationRegion2D, and Entities container

### Phase 3: Player Controller

- **Created** `godot/scripts/world/player_controller.gd` — 8-direction movement via existing input map (WASD/arrows), `move_and_slide()` physics, animation state machine (idle/walk × 4 directions), interact action emits EventBus signal
- **Created** `godot/scenes/world/player.tscn` — CharacterBody2D with AnimatedSprite2D, RectangleShape2D collision, Camera2D with smoothing

### Phase 4: NPC System

- **Created** `godot/scripts/world/npc_controller.gd` — State machine (IDLE/PATROL/TALK), NavigationAgent2D pathfinding, Area2D interaction zone, faction-aware dialogue triggering via EventBus
- **Created** `godot/scenes/world/npc.tscn` — CharacterBody2D with AnimatedSprite2D, collision, NavigationAgent2D, CircleShape2D interact zone (radius 40)
- **Created** `godot/scripts/world/dialogue_manager.gd` — Bridges NPC interactions to existing dialogue UI; loads dialogue JSON, builds Encounter objects, supports dialogue_steps branching; faction-reputation-aware generic barks

### Phase 5: Scene Transitions & Interiors

- **Created** `godot/scripts/world/scene_transition.gd` — Area2D-based door detection, fade-out/fade-in transitions via TransitionOverlay, stores return position in GameSession
- **Created** `godot/scenes/world/tavern.tscn` — Example interior with TileMapLayers, NavigationRegion2D, Innkeeper NPC, Patron NPC, exit door with scene_transition back to world

### Phase 6: Overworld Map Enhancement

- **Modified** `godot/scripts/ui/star_map_screen.gd` — Added travel-to-world-scene flow: SPACE key requests travel, confirmation dialog with ENTER/ESC, `WORLD_SCENE_MAP` lookup, deferred scene change; updated galaxy layer control hints

### Integration

- **Modified** `godot/scripts/autoload/game_session.gd` — Added `_return_scene_path`, `_return_position`, `_return_facing` tracking variables; `store_return_position()`, `get_return_position()`, `has_return_position()`, `clear_return_position()` helper methods
- **Modified** `godot/scripts/autoload/event_bus.gd` — Added 5 world layer signals: `world_scene_entered`, `world_scene_exited`, `npc_interaction_started`, `npc_interaction_ended`, `door_transition`

---

## 2026-03-25 — Art: Aristotle spritesheet on planet screen

**Enhancement:** Replaced placeholder circle with animated spritesheets for both Aristotle and Dave in the top-down planet exploration mode. The sprite renders 8-direction walk cycles and falls back to idle frames when stationary. The correct spritesheet loads automatically based on the selected protagonist.

### Art: Aristotle spritesheet on planet screen Changes

- Copied `aristotle_spritesheet.png` and `dave_spritesheet.png` to `assets/sprites/`
- `planet_screen.gd` — loads spritesheet based on `protagonist_id`, tracks facing octant, cycles walk/idle animation rows, draws correct frame via `draw_texture_rect_region()`

---

## 2026-03-23 — Feature: Planetary Exploration (Top-Down Mode)

**Feature:** Top-down exploration mode for planetary surfaces with merchants, treasures, and NPC interaction.

### Planetary Exploration (Top-Down Mode) Changes

- `Planet` entity (`scripts/entities/planet.gd`) — planet data model with biome, merchants, treasures, hostiles
- `PlanetSystem` (`scripts/systems/planet_system.gd`) — manages planet loading, landing/departure, treasure collection, state persistence
- Planet screen (`scripts/ui/planet_screen.gd`) — top-down exploration with 4-way movement, merchant trading, treasure hunting
- 3 charted planets: Fringe Haven (settlement), Goblin Market World (industrial), Moonpetal Glade (enchanted)
- 4 biome types defined in `data/planets/biomes.json`

### Planetary Explration Integration

- Navigation screen renders planet markers with biome-coloured circles and `[L] LAND` proximity prompt
- `[L]` key or `[Enter]` lands on nearby planets, transitioning to the planet screen
- Depart button returns to navigation with collected loot merged into main inventory
- Planet state persists: cleared treasures and visit history survive save/load
- `EventBus` emits `planet_landed`, `planet_departed`, `planet_treasure_found`, `planet_merchant_interacted`
- `GameStateData` tracks `current_planet_id`, `planet_states`, `planet_inventory` (save/load compatible)

---

## 2026-03-23 — Feature: Star Bases (Dockable Space Stations)

**Feature:** Dockable space stations on the star map with services, artifacts, and three base variants.

### Star Bases (Dockable Space Stations) Changes

- `StarBase` entity (`scripts/entities/star_base.gd`) — base data model with type, faction, services, artifacts
- `StarBaseSystem` (`scripts/systems/star_base_system.gd`) — manages base loading, visibility, docking, artifact purchases, proximity detection
- Station screen UI (`scripts/ui/station_screen.gd`) — overlay menu for docked services (refuel, repair, trade, salvage drop-off, artifact market)
- 6 star bases across regions: Fringe Outpost, Corsair Haven, Iron Dock, Twilight Exchange, Scrapheap Station (hidden), Wolf Citadel (stronghold)
- 5 exclusive artifacts: Aeolian Tuning Fork, Bottled Solar Flare, Chrono-Compass, Midas's Grapnel, Fairy Dust Scrubber

### Star Bases Integration

- Navigation screen renders diamond-shaped base markers with proximity dock prompt
- `[E]` key docks at nearby bases (overrides faction screen when in range)
- Three base variants: Open (always dockable), Hidden (requires discovery flag), Stronghold (requires faction reputation)
- Artifact passive bonuses tracked via `get_artifact_bonuses()` for use by other systems
- `EventBus` emits `base_docked`, `base_undocked`, `artifact_acquired` signals
- `GameStateData` tracks `docked_base_id`, `discovered_bases`, `acquired_artifacts`, `base_state_overrides` (save/load compatible)

---

## 2026-03-23 — Feature: Skill Point Allocation ("Harmonic Attunement")

**Feature:** New game start skill redistribution screen and stat evaluation system.

### Skill Point Allocation ("Harmonic Attunement") Changes

- `StatEvaluator` (`scripts/systems/stat_evaluator.gd`) — utility for checking skill thresholds, finding highest stat, percentage calculations
- Skill allocation screen (`scripts/ui/skill_allocation.gd`) — redistribute starting points across 6 stats with +/- controls
- Presets: Default, Warrior, Diplomat, Shadow
- Resonance Shards (`data/items/resonance_shards.json`) — in-game items that expand the skill point pool

### Skill Point Allocation Integration

- Character select now routes through skill allocation before cutscene
- `EncounterEngine` supports `min_<stat>`, `highest_stat`, and `karma_tier` trigger conditions
- `CombatSystem` factors `combat_skill` into damage (+2% per point) and `stealth` into dodge (+1% per point)
- `GameStateData` tracks `bonus_skill_points` and `resonance_shards_found` (save/load compatible)
- `EventBus` emits `stats_changed` and `resonance_shard_found` signals

---

## 2026-03-23 — Feature: Karma System (Global Reputation Meter)

**Feature:** Added a global karma system that tracks moral alignment on a -100 to +100 scale, separate from per-faction reputation.

### Karma System (Global Reputation Meter) Changes

- `KarmaSystem` (`scripts/systems/karma_system.gd`) — core logic for karma tracking, tier calculation, price/NPC modifiers
- Five karma tiers: Tyrant, Ruthless, Neutral, Virtuous, Paragon
- Karma-based merchant price modifiers (Tyrant: +40%, Paragon: -20%)
- NPC disposition offsets per tier
- JSON-driven configuration (`data/karma/karma_config.json`, `data/karma/karma_triggers.json`)

### Karma System Integration

- `EncounterOutcome` now supports `karma_delta` field for encounter choices
- `EncounterEngine` applies karma changes when processing choice and dialogue outcomes
- `EconomySystem` applies karma price modifier to buy prices
- `GameStateData` tracks `karma` score and `karma_history` (save/load compatible)
- `EventBus` emits `karma_changed` and `karma_tier_changed` signals
- Navigation HUD displays karma tier and score with colour coding

---

## 2026-03-21 — Major Content Expansion: Maps, Arcs, Characters

**Feature:** Massive content expansion adding 6 new maps, 6 new story arcs, 22 special characters, and a hidden map with a secret 4th ending.

### Maps (7 → 13 regions)

- **The Shattered Prides** — Dedicated Lion sovereign territory with palace ruins, political intrigue
- **The Iron Expanse** — Dedicated Wolf military frontier with fortresses and weapons testing
- **The Twilight Bazaar** — Neutral free port hub for cross-faction encounters and special characters
- **The Warp Marches** — Unstable alien frontier with reality distortions and high-risk exploration
- **The Bone Yard** — Ancient starship graveyard with massive salvage rewards and lore
- **The Cradle of Whispers** — Hidden map (10 complex unlock requirements), origin of all Whisper Crystals, secret 4th ending

### Story Arcs (4 → 10 arcs)

- Current Arc 4 "The Reckoning" repositioned as Arc 10 (finale)
- **Arc 4 "The Undercurrent"** — Crystal instability, Lion fracture, Death erratic
- **Arc 5 "The Iron Tide"** — Wolf total war campaign, Dave loyalty crisis
- **Arc 6 "The Fracture"** — Bone Yard discovery, Lion civil war, ancient signal
- **Arc 7 "The Communion"** — Warp Marches, crystal consciousness contact
- **Arc 8 "The Gathering Storm"** — Final alliances, Cradle portal
- **Arc 9 "The Cradle"** — Hidden optional arc inside Cradle of Whispers
- **Ending D "Reunite"** — Hidden 4th ending for balanced players who find the Cradle

### Special Characters (22 new)

- 12 faction-aligned: Lord Mane, Iron Fang, Glimmer, Cogsworth, Ser Galvain, Tidewalker, Lady Penumbra, Rustclaw, The Void Singer, Brother Hemlock, Snarl, Admiral Brass
- 10 independent: The Oracle, The Keeper, Jinx, The Debt Collector, Patch, Flux, Sister Meridian, Wraith, Grizzle, Echo
- Mix of significant (determines faction outcomes) and flavor (world-building richness)

### Expanded Galaxy Map Changes

- `data/story/arc_definitions.json` — Expanded from 4 to 10 arcs, added ending_d_reunite threshold
- `data/maps/galaxy_layout.json` — Added 6 new region nodes
- `data/maps/region_maps.json` — Added 6 new region definitions with POIs, spawn zones, hidden locations
- `data/maps/purchasable_maps.json` — Added 5 new purchasable star charts
- `scripts/core/data_loader.gd` — Added `load_cradle_encounters()` and `load_special_character_encounters()`

### Expanded Galaxy Map Files Added

- `data/encounters/arc4_encounters.json` through `arc9_encounters.json` — Aristotle path encounters
- `data/encounters/arc4_encounters_dave.json` through `arc9_encounters_dave.json` — Dave path encounters
- `data/encounters/arc10_encounters.json` + `arc10_encounters_dave.json` — Renamed from old arc4
- `data/encounters/special_characters.json` — 22 special character encounters
- `data/side_missions/arc4_side_missions.json` through `arc9_side_missions.json` — Aristotle side missions
- `data/side_missions/arc4_side_missions_dave.json` through `arc9_side_missions_dave.json` — Dave side missions
- `data/side_missions/arc10_side_missions.json` + `arc10_side_missions_dave.json` — Renamed from old arc4
- `data/side_missions/distress_signals.json` — Added 5 new region-specific distress signals

---

## 2026-03-21 — Celestial Codex: 3-Layer Map System

**Feature:** Replaced the single-region star map with the "Celestial Codex" — a three-layer map overlay accessible via TAB.

- **Galaxy Layer** — shows all 7 regions as connected nodes with discovery state, fog reveal progress arcs, and danger level indicators. Arrow keys navigate between nodes, ENTER drills into a region.
- **Region Layer** — the existing circular map view with fog of war, POIs, player position, and breadcrumb navigation. ESC returns to galaxy, ENTER drills to local scan.
- **Local Layer** — zoomed-in player-centered view with detailed fog, labeled POIs, vision range circle, region boundary indicators, and coordinate readout.
- **Directional boundary transitions** — flying off a region edge now picks the neighbor whose galaxy position matches the exit direction (no longer always picks the first connected region).
- **Directional entry positions** — entering a region places the player on the edge closest to where they came from.

### Celestial Codex: 3-Layer Map System Changes

- `data/maps/galaxy_layout.json` — New: galaxy node positions and colors for all 7 regions
- `scripts/core/data_loader.gd` — Added `load_galaxy_layout()` method
- `scripts/systems/star_map_system.gd` — Added galaxy layout storage, `get_galaxy_node_pos()`, `get_galaxy_node_color()`, `get_region_fog_percentage()`, and directional `get_entry_position()`
- `scripts/autoload/game_session.gd` — Wired galaxy layout loading in `_init_star_maps()`
- `scripts/ui/star_map_screen.gd` — Major rewrite: 3-layer renderer with galaxy/region/local draw methods, layer transitions, galaxy node navigation, per-layer input handling
- `scripts/ui/navigation.gd` — Directional boundary neighbor selection using galaxy layout positions
- `scripts/autoload/event_bus.gd` — Added `codex_layer_changed` signal
- `scenes/ui/star_map_screen.tscn` — Updated title to "CELESTIAL CODEX"

---

## 2026-03-20 — Fix Arc 1 ending prematurely after "Eyes in the Dark"

**Bug Fix:** Completing the "Eyes in the Dark" encounter immediately triggered the arc 1 exit, skipping "The Captain's Doctrine" stance choice. Added `arc1_stance` to arc 1 exit conditions so the player must make their doctrine decision before advancing to arc 2.

### Arc 1 Ending Fix Changes

- `data/story/arc_definitions.json` — Added `arc1_stance: true` to arc 1 exit conditions and arc 2 entry conditions

---

## 2026-03-20 — Fix dialogue title shifting outside parchment with 3+ choices

**Bug Fix:** When encounters displayed more than 2 choice options, the title label shifted outside the parchment background. The panel and dialogue background had a fixed 280px height that couldn't accommodate the extra buttons. The panel now dynamically resizes upward to fit its content when choices are added, and resets when choices are cleared between dialogue steps.

### Dialogue Title Shifting Fix Changes

- `scripts/ui/dialogue_ui.gd` — Added `_resize_panel_to_fit()` to grow panel/background height based on content; called after building choices in both legacy and dialogue-step paths; reset height on choice clear

---

## 2026-03-20 — Dialogue Background for All Interactions + Soft Fog Edges

**Enhancement:** The dialogue background texture is now shown for all encounter types, not just multi-step dialogue encounters. Legacy single-choice encounters now also display the parchment background with matching text styling.

**Enhancement:** Fog of war edges in both the navigation view and star map screen are now rendered with soft, cloud-like edges instead of sharp rectangles. Boundary cells use overlapping circles with alpha gradients based on proximity to revealed areas, creating a natural nebula/cloud aesthetic.

### Dialogue Background and Fog Enhancement Changes

- `scripts/ui/dialogue_ui.gd` — Always show dialogue background and parchment styling for all encounter types
- `scripts/ui/navigation.gd` — Soft circle-based fog rendering at revealed/hidden boundaries
- `scripts/ui/star_map_screen.gd` — Per-cell soft circle fog with neighbor-based alpha at boundaries

---

## 2026-03-20 — Star Map Fog, Cartographer Balance, and Distress Signal Fix

**Enhancement:** Replaced solid black fog of war on the star map with a translucent nebula-style fog. Unrevealed cells now render with subtle colour variation and partial transparency, while boundary cells between revealed and hidden areas get a softer fade for a more atmospheric look.

**Balance:** The fairy cartographer encounter now requires completing the Crystal Discovery encounter first (`arc1_crystal_discovered` flag) and is placed at a fixed location in the far corner of The Fringe (5400, 5600), making Pip much harder to find early on.

**Enhancement:** Rescuing the cartographer now reveals fog only around the hidden locations Pip has charted (radius 400 around each hidden location across all regions), rather than making everything visible. Players must still explore or purchase maps to uncover the rest.

**Bug Fix:** Removed the fairy cartographer reference from the repeatable `distress_escape_pod` encounter. The rescue outcome now features a retired merchant navigator instead, eliminating the conflict with the dedicated one-time cartographer encounter.

### Star Map Fog, Cartographer Balance, and Distress Signal Fix Changes

- `scripts/ui/star_map_screen.gd` — Fog of war rendering: nebula colours, edge-cell blending, translucent density
- `scripts/systems/star_map_system.gd` — `on_cartographer_rescued()` reveals fog around hidden locations only
- `data/encounters/fairy_cartographer.json` — Added `arc1_crystal_discovered` trigger condition
- `data/maps/region_maps.json` — Added fixed story location for cartographer in starting_realm
- `data/side_missions/distress_signals.json` — Changed escape pod rescue outcome from fairy cartographer to merchant navigator

---

## 2026-03-20 — Fix POIs Spawning Outside Region Bounds + Boundary Edge Effect

**Bug Fix:** Story encounters, distress signals, combat spawns, and other POIs could spawn outside the navigable region boundary, making them unreachable. All POI spawn points (random encounters, distress signals, and star map spawn zones) are now clamped to stay within region bounds with a 150-unit padding.

**Enhancement:** Added a fuzzy gradient edge effect at region boundaries. As the player approaches the edge of the map, a smooth quadratic dark gradient fades in, with a solid dark overlay beyond the boundary. This clearly communicates inaccessible areas. The existing pulsing blue glow for region transitions is preserved on top.

### POI Spawning and Boundary Edge Effect Changes

- `scripts/ui/navigation.gd` — Added `_clamp_to_bounds()` helper, clamped POI positions in `_spawn_poi()` and `_update_distress()`, replaced thin boundary line with multi-strip gradient fade effect
- `scripts/systems/star_map_system.gd` — Clamped random spawn zone POI positions to region bounds

---

## 2026-03-20 — Dialogue Overlay Visibility

**Enhancement:** Added a semi-transparent dark backdrop behind dialogue encounters so the dialogue panel clearly stands out from the gameplay scene underneath. The backdrop fades in smoothly when the dialogue opens.

---

## 2026-03-19 — Arc Transition: Stats Summary + Hyperspace Jump

**Feature:** When a story arc completes, a full-screen stats summary and hyperspace jump animation play before entering the next sector.

1. **Arc Summary Screen** — Overlay showing completed arc title, next arc title + theme teaser, and 8 animated count-up stats: encounters completed, combat victories, crew recruited, missions completed, crystals, salvage, hull status, and playtime.

2. **Hyperspace Jump Shader** — Custom canvas_item shader with radial star streaks, blue-white tunnel intensification, flash-to-white, and fade-to-black. Driven by a single `progress` uniform (0→1) over ~2.5 seconds.

3. **Combat Victory Counter** — Added `combat_victories` field to `GameStateData` with full save/load persistence, incremented on each `combat_victory` signal.

4. **Flow:** Arc exit conditions met → `arc_advanced` signal → navigation pushes `arc_summary` overlay → player reads stats → presses "JUMP TO NEXT SECTOR" → stats fade out → hyperspace shader plays → `arc_transition_complete` signal → POIs refresh for new arc.

### Arc Transition Enhancement Files

- `scripts/ui/arc_summary.gd` — Stats screen + hyperspace jump controller
- `scenes/ui/arc_summary.tscn` — Scene layout with panel, stats container, continue button, hyperspace ColorRect
- `shaders/hyperspace_jump.gdshader` — Radial streak warp shader with 3-phase animation

### Modified Files

- `scripts/core/game_state_data.gd` — Added `combat_victories` field + persistence in `to_dict()`/`from_dict()`
- `scripts/autoload/game_session.gd` — Connected `combat_victory` signal, added `_on_combat_victory()` handler
- `scripts/autoload/event_bus.gd` — Added `arc_transition_complete(new_arc)` signal
- `scripts/ui/main.gd` — Registered `arc_summary` in SCENES dictionary
- `scripts/ui/navigation.gd` — Replaced flash message with `push_overlay("arc_summary")`, added `_on_arc_transition_complete()` to refresh POIs after jump

---

## 2026-03-19 — Crew recruitment encounters converted to dialogue_steps

**Feature:** All 8 crew member recruitment encounters now use two-sided branching dialogue.

1. **Cat crew encounters** - Nine Lives, No Tail, Silky, and Blood Paw recruitment conversations converted to dialogue_steps with Aristotle. Each crew member has distinct personality: Nine Lives (cocky), No Tail (gruff), Silky (enigmatic), Blood Paw (dedicated healer).

2. **Dog crew encounters** - Charlie, Bombardier, Luna, and Thistle recruitment conversations converted to dialogue_steps with Dave. Each crew member has distinct personality: Charlie (enthusiastic), Bombardier (sarcastic), Luna (calculating), Thistle (principled).

3. **Arc 1-2 story encounters** — Key Dave/Aristotle confrontations converted: arc1 face-to-face meeting and arc2 route seizure standoff.

4. **Arc 3 story encounters** — Dave/Aristotle parley (both perspectives), Death reveal on Aristotle's bridge, Death's offer to Dave in the Forgotten Realm.

5. **Arc 4 story encounters** — Dave's assault on crystal fields (Dave/Aristotle comms exchange before combat), Death's Vault bid (Aristotle/Death confrontation), Death's mid-battle betrayal (Dave/Death), and the climactic Dave/Aristotle showdown with three branching endings (surrender terms, shared governance, destruction).

6. **Portrait support** — Added 8 crew member portraits to CHARACTER_PORTRAITS registry including Nine Lives portrait.

### Crew Recruitment Dialogue Conversion Changes

- `scripts/ui/dialogue_ui.gd` — Added crew member portrait paths
- `data/encounters/crew_nine_lives.json` — Converted to dialogue_steps
- `data/encounters/crew_no_tail.json` — Converted to dialogue_steps
- `data/encounters/crew_silky.json` — Converted to dialogue_steps
- `data/encounters/crew_blood_paw.json` — Converted to dialogue_steps
- `data/encounters/crew_charlie.json` — Converted to dialogue_steps
- `data/encounters/crew_bombardier.json` — Converted to dialogue_steps
- `data/encounters/crew_luna.json` — Converted to dialogue_steps
- `data/encounters/crew_thistle.json` — Converted to dialogue_steps
- `data/encounters/arc1_encounters_dave.json` — Dave/Aristotle meeting converted
- `data/encounters/arc2_encounters.json` — Route seizure confrontation converted
- `data/encounters/arc3_encounters.json` — Dave parley + Death reveal converted
- `data/encounters/arc3_encounters_dave.json` — Aristotle parley + Death offer converted
- `data/encounters/arc4_encounters.json` — Dave assault + Death bid converted
- `data/encounters/arc4_encounters_dave.json` — Death betrayal + Aristotle showdown converted

---

## 2026-03-19 — Two-sided branching dialogue system

**Feature:** Encounters can now have multi-step, two-sided conversations with branching outcomes.

1. **Dialogue steps format** — Encounters support an optional `dialogue_steps` array in JSON. Each step has a `speaker`, `text`, and optional `choices` with `next_step` branching. Steps can end peacefully (`"end": true`) or escalate to combat (`"start_combat": true`).

2. **Two-portrait UI** — Dialogue screen now shows Aristotle on the left and the NPC on the right. The active speaker's portrait is highlighted at full opacity while the other dims to 0.4 alpha.

3. **Step state machine** — The dialogue UI walks through steps sequentially, pausing for player choices and auto-advancing non-choice lines. Choices apply mid-dialogue outcomes (flags, resources, factions) and jump to branch targets via `step_id`.

4. **Backwards compatible** — Encounters without `dialogue_steps` use the original single-step flow unchanged.

5. **Proof-of-concept** — `enc_arc1_dave_trade` converted to a branching two-sided conversation with three paths: friendly trade, negotiation, and hostile escalation to combat.

### Two-sided Branching Dialogue System Changes

- `scripts/entities/encounter.gd` — added `DialogueStep`, `DialogueStepChoice` inner classes, `dialogue_steps` field
- `scripts/systems/encounter_engine.gd` — added `apply_dialogue_step_outcome()`, `complete_encounter()`
- `scripts/autoload/event_bus.gd` — added `dialogue_step_advanced` signal
- `scenes/ui/dialogue_ui.tscn` — restructured to left/right portrait layout
- `scripts/ui/dialogue_ui.gd` — added step state machine, two-portrait handling, speaker highlighting, branching flow
- `data/encounters/arc1_encounters.json` — converted Dave trade encounter to branching dialogue

---

## 2026-03-19 — Add ship purchasing and Pirate Destroyer to shipyard

**Feature:** Players can now buy new ships in the shipyard alongside repairs and upgrades.

1. **Pirate Destroyer template** — Added to `ship_templates.json` with `purchasable: true`, costing 80 crystals + 60 salvage. Stats: Spd 4, Arm 8, Fp 9, Hull 160, Cargo 5, Crew 8. Uses `ship_destroyer_r_side.png` sprite.

2. **Ship purchase logic** — Added `purchase_ship()` to `economy_system.gd`. Validates affordability, prevents re-buying current ship class, transfers crew and cargo to the new vessel, emits `EventBus.ship_purchased`.

3. **Data loader** — Added `load_purchasable_ships()` to `data_loader.gd` filtering templates with `purchasable == true`.

4. **Shipyard UI** — Left panel now shows current ship sprite preview and ship name/class. Right panel split into "Ships For Sale" (with thumbnails, stat summary, cost, buy button) and "Ship Upgrades". Buying a ship swaps your vessel and refreshes the entire UI.

### Ship Purchase Feature Changes

- `data/ships/ship_templates.json` — added Pirate Destroyer template with purchase cost fields
- `scripts/core/data_loader.gd` — added `load_purchasable_ships()`
- `scripts/systems/economy_system.gd` — added `purchase_ship()`
- `scripts/ui/purchase_screen.gd` — added ship preview, ship purchasing UI, ship list builder
- `scenes/ui/purchase_screen.tscn` — added ShipPreview, ShipNameLabel, ShipList nodes; restructured right panel

---

## 2026-03-19 — Implement ship upgrade shop in the shipyard screen

**Problem:** The shipyard (R key) only offered hull repair. Ship upgrades were fully defined in data (7 upgrades in `ship_templates.json`) and the `Ship.ShipUpgrade` entity class existed, but there was no way to browse, buy, or apply upgrades during gameplay. This made combat increasingly unwinnable as enemies scaled up.

**Solution:** Built the full upgrade purchase pipeline:

1. **Economy logic** — Added `purchase_upgrade()` and `_apply_stat_modifier()` to `economy_system.gd`. Handles cost deduction (crystals + salvage), stat application (including side effects like Siege Cannons: +2 firepower / -1 speed), duplicate prevention, and emits `EventBus.upgrade_purchased`.

2. **Shipyard UI overhaul** — Rebuilt `purchase_screen.gd` to show current ship stats, repair with dynamic cost display, and a scrollable list of all 7 upgrades. Each row shows the upgrade name, stat effect, cost (crystals + salvage), affordability colour coding, and a Buy button. Installed upgrades show as green "INSTALLED" labels.

3. **Scene layout** — Expanded `purchase_screen.tscn` panel to fit ship stats line, repair button, upgrades header, scrollable upgrade list, and close button.

### Ship Upgrade Shop Implementation Changes

- `scripts/systems/economy_system.gd` — added `purchase_upgrade()` and `_apply_stat_modifier()` functions
- `scripts/ui/purchase_screen.gd` — full rewrite with upgrade list UI, dynamic repair cost, ship stats display
- `scenes/ui/purchase_screen.tscn` — expanded layout with `ShipStatsLabel`, `ScrollContainer`/`UpgradeList`, `UpgradesHeader`

---

## 2026-03-19 — Fix story arc progression, add repair access and arc progress HUD

**Problem:** Story arcs never advanced because `NarrativeSystem.check_arc_exit()` and `advance_arc()` were defined but never called after encounters. This meant the game stayed stuck in Arc 1 forever, making battles increasingly pointless. Additionally, the repair/purchase screen existed but had no keybind to access it, so players couldn't repair their ship during gameplay.

**Solution:** Three changes to make gameplay progression work:

1. **Wired arc progression** — After each encounter outcome is applied in `encounter_engine.gd`, the game now checks if the current arc's exit conditions are satisfied and automatically advances to the next arc. This loads new encounters, side missions, and updates music.

2. **Added repair screen access (R key)** — Added a `repair` input action bound to R and wired it in `navigation.gd` so players can open the purchase/repair screen at any time. Updated the controls bar hint text.

3. **Added arc progress feedback** — The HUD arc label now shows progress as "ARC TITLE (2/3)" indicating how many exit conditions have been met. When an arc advances, a 6-second flash notification announces the new arc.

### Story Arc Progression, Repair Access, and Arc Progress HUD Changes

- `scripts/systems/encounter_engine.gd` — added `check_arc_exit()` + `advance_arc()` call after `apply_choice_outcome()`
- `scripts/ui/navigation.gd` — connected `arc_advanced` signal, added `_on_arc_advanced()` flash + POI refresh, added R key handler for purchase overlay, updated HUD to show arc progress count, updated controls bar hint
- `project.godot` — added `repair` input action mapped to R key

---

## 2026-03-19 — Improved ship orientation during navigation

**Problem:** The player ship used a single side-view sprite rotated 360 degrees, which looked unnatural at vertical angles.

**Solution:** Replaced free rotation with a banking + smooth flip + directional sprite blending system:

- 3-sprite flip transition: cross-fades through a 3/4 angle turning sprite (`ship_rotate.png`) during horizontal direction changes, blending from rotate sprite to side sprite with overlapping alpha curves
- Ease-out-quad curve on flip progress so the rotate midpoint transitions quickly
- Slight banking tilt (up to ~17 degrees) when moving vertically for momentum feel
- Cross-fades between side-view sprite (`ship_r_side.png`) and top-down sprite (`ship_up_side.png`) based on vertical movement dominance
- Engine glow and trail particles adapt to the new orientation system

### Improved Ship Orientation During Navigation Changes

- `scripts/ui/navigation.gd` — replaced `_ship_angle` rotation system with `_facing_right` flip, `_bank_angle` tilt, `_vertical_blend` dual-sprite blending, and `_heading_angle` for trail/minimap; added `_draw_ship_perspective()` helper that renders the ship as a UV-mapped trapezoid for pseudo-3D turning; loaded and processed `ship_up_side.png` as second directional sprite; updated engine glow to blend between side-rear and heading-based offsets

---

## 2026-03-19 — Fix ESC-to-skip cutscene, navigation & combat music

**Bug 1:** ESC key did not skip the intro cutscene. The `skip` input action was mapped to keycode `4194306` (Tab) instead of `4194305` (Escape).

**Bug 2:** Navigation music never played. `on_state_change("navigation")` always resolved to the arc-specific theme (`"theme_arc1"`) which doesn't exist, instead of falling back to `"theme_navigation"`. Additionally, `_play_theme()` set `_current_theme` even when no file was found, poisoning subsequent calls.

**Bug 3:** Combat music never played. Combat starts via `replace_overlay()` which was missing the `MusicManager.on_state_change()` call that `push_overlay()` and `switch_scene()` both have.

### ESC-to-Skip Cutscene, Navigation & Combat Music Fix Changes

- `project.godot` — fixed `skip` input action keycode from `4194306` (Tab) to `4194305` (Escape)
- `scripts/autoload/music_manager.gd` — added `_theme_file_exists()` helper; `on_state_change()` and `on_arc_change()` now fall back to default themes when arc-specific files don't exist; `_play_theme()` now resolves the new stream before stopping the current track — if no file exists, current music keeps playing instead of going silent; lowered default music volume from -10 dB to -20 dB
- `scripts/ui/main.gd` — `replace_overlay()` now calls `MusicManager.on_state_change(scene_key)` and sets overlay meta key

---

## 2026-03-19 — Music volume control & playback continuity

**Features:**

- Volume control: settings slider now controls music volume (0–100% linear scale, mapped to dB)
- Music continuity: when switching themes (e.g., navigation → combat → navigation), tracks resume where they left off instead of restarting from the beginning
- Navigation music support: place `theme_navigation.ogg/.mp3` in `assets/audio/music/` and it plays during flight

### Music Volume Control & Playback Continuity Changes

- `scripts/autoload/music_manager.gd` — added `set_music_volume()`, `set_sfx_volume()`, playback position save/restore in `_play_theme()`, default volume at -10 dB, wired `EventBus.volume_changed`
- `scripts/ui/settings_screen.gd` — slider initializes from current volume, toggles reflect current state, calls `MusicManager.set_music_volume()` directly

---

## 2026-03-19 — Fix overlay music (combat, trade, etc.)

**Bug:** `push_overlay()` in `main.gd` did not call `MusicManager.on_state_change()`, so combat music (and any other overlay-based screen music) never played.

### Overlay Music Fix Changes

- `scripts/ui/main.gd` — `push_overlay()` now triggers `MusicManager.on_state_change(scene_key)` and saves the prior scene key; `pop_overlay()` restores the previous music when all overlays are cleared.

---

## 2026-03-18 — Crew Missions Feature

**Task:** Add crew recruitment missions — 4 named crew members per protagonist with story-driven recruitment and trait bonuses

### New Files

- `data/characters/crew_members.json` — 8 crew member definitions (4 per protagonist) with roles, traits, backstories
- `data/side_missions/crew_missions_aristotle.json` — 4 crew recruitment missions for Aristotle
- `data/side_missions/crew_missions_dave.json` — 4 crew recruitment missions for Dave
- `data/encounters/crew_nine_lives.json` — Nine Lives recruitment encounters (2 encounters)
- `data/encounters/crew_no_tail.json` — No Tail recruitment encounters (3 encounters)
- `data/encounters/crew_silky.json` — Silky recruitment encounters (2 encounters)
- `data/encounters/crew_blood_paw.json` — Blood Paw recruitment encounters (3 encounters)
- `data/encounters/crew_charlie.json` — Charlie recruitment encounters (2 encounters)
- `data/encounters/crew_bombardier.json` — Bombardier recruitment encounters (3 encounters)
- `data/encounters/crew_luna.json` — Luna recruitment encounters (2 encounters)
- `data/encounters/crew_thistle.json` — Thistle recruitment encounters (3 encounters)
- `scripts/systems/crew_trait_system.gd` — CrewTraitSystem: loads crew definitions, calculates active trait bonuses per ship
- `assets/characters/crew/.gdkeep` — Placeholder directory for crew portrait art

### Crew Missions Modified Files

- `scripts/entities/ship.gd` — Extended `CrewMember` with `trait_id`, `portrait`, `backstory`, `recruitment_status` fields + serialization
- `scripts/entities/side_mission.gd` — Added `crew_member_id` field + serialization
- `scripts/entities/encounter.gd` — Added `mission_type`, `crew_member_id` fields + deserialization
- `scripts/core/data_loader.gd` — Added `load_crew_members()`, `load_crew_missions()`, `load_crew_encounters()`
- `scripts/systems/side_mission_system.gd` — Added `load_crew_missions()` to append crew missions to templates
- `scripts/systems/combat_system.gd` — Applied `firepower_bonus` and `critical_hit_chance` crew trait bonuses to damage calculation
- `scripts/systems/crew_morale_system.gd` — Applied `morale_recovery` crew trait bonus to positive morale changes
- `scripts/systems/economy_system.gd` — Applied `hull_repair_rate` crew trait bonus to reduce repair costs
- `scripts/systems/encounter_engine.gd` — Applied `exploration_discovery_rate` and `ambush_detection` bonuses to encounter priority sorting
- `scripts/autoload/event_bus.gd` — Added `crew_member_recruited(crew_id, protagonist_id)` signal
- `scripts/autoload/game_session.gd` — Added `CrewTraitSystem` initialization, crew mission/encounter loading, recruitment listener, `recruit_crew_member()` helper
- `scripts/ui/dialogue_ui.gd` — Added crew recruitment detection (`_check_crew_recruitment`) and confirmation display (`_show_crew_recruitment_confirmation`)
- `scripts/ui/ship_screen.gd` — Enhanced crew roster with role labels, trait descriptions, morale colours, and empty role slots
- `scripts/ui/mission_log.gd` — Added "CREW MISSIONS" group header with crew/main/side sorting
- `scripts/ui/navigation.gd` — Added crew count indicator to HUD (`Crew: X/Y`)

### Updated Documentation

- `docs/plans/MASTER_PLAN.md` — Marked Crew Missions Feature as COMPLETE (2026-03-18) with full implementation summary

---

## 2026-03-17 — Character Selection Feature (ISSUE-001)

**Task:** Add dual-protagonist support — choose Aristotle or Dave at game start
**Model:** Opus 4.6

### Character Selection Feature Changes

- **GameStateData:** Added `protagonist_id` field with backward-compatible save/load
- **DataLoader:** Added `load_protagonists()`, suffix parameter on `load_encounters()` and `load_side_missions()` with fallback to shared files
- **GameSession:** Refactored `start_new_game(protagonist_id)` and `create_new_game_state()` to be data-driven from `protagonists.json` config
- **Character Select UI:** New scene (`character_select.tscn`) and controller (`character_select.gd`) with two-panel layout, portraits, stats, and select buttons
- **Menu:** "New Game" now routes to character selection screen
- **Cutscene:** Intro text loaded from protagonist config instead of hardcoded Aristotle lines
- **Faction systems:** Replaced hardcoded `"felid_corsairs"` references with dynamic `player_character.faction_id` in `faction_system.gd` and `faction_conquest_system.gd`
- **EventBus:** Added `protagonist_selected` signal
- **Ending screen:** Added protagonist-specific flavor text for Dave
- **Data files:** Created `protagonists.json`, Dave arc 1-4 encounters, Dave dialogue files, Dave side missions

---

## 2026-03-17 — Godogen Asset & Workflow Integration

**Task:** Integrate godogen Godot 4 development resources into Whisper Crystals
**Model:** Opus 4.6

### Phase 1: Documentation Structure

- Created `docs/godot-reference/` with 7 core reference documents:
  - `gdscript-reference.md` — Complete GDScript syntax, types, operators, patterns
  - `quirks-and-gotchas.md` — 18 known engine issues and runtime pitfalls
  - `best-practices.md` — Coding standards for Godot development
  - `scene-generation-patterns.md` — Scene builder patterns and ownership chains
  - `script-generation-patterns.md` — Runtime script templates
  - `scene-script-coordination.md` — Rules for scene/script interaction
  - `test-harness-patterns.md` — Testing approaches for Godot scenes
  - `screenshot-capture.md` — Screenshot and video capture workflow
- Copied 862 Godot API reference files to `docs/godot-reference/api/`
- Created workflow templates: `PLAN.md`, `ASSETS.md`, `MEMORY.md` at project root

### Phase 2: Local Tools

- Set up `tools/godot-dev/` with 4 tool categories:
  - `sprites/` — spritesheet_template.py, spritesheet_slice.py
  - `assets/` — rembg_matting.py (background removal with alpha matting)
  - `docs/` — godot_api_converter.py, class_list.py, ensure_doc_api.sh
  - `capture/` — gpu_detect.sh, screenshot.sh (with macOS support)

### Phase 3: Development Methodology

- Created `docs/development-methodology/` with 3 guides:
  - `task-decomposition.md` — Feature classification and task planning
  - `architecture-planning.md` — Scene hierarchy and script design
  - `iteration-strategy.md` — Progress-based stopping criteria
- Created `docs/qa/visual-qa-checklist.md` — Manual QA checklists from VQA prompts

### Phase 4: Testing Infrastructure

- Created `examples/godot-patterns/test-harness-example/` with working test template

### Phase 5: Project-Specific Adaptations

- Created `docs/GODOT_DEV_GUIDE.md` — Central reference linking all godogen assets
- Created quick reference cards in `docs/godot-reference/quick-refs/`:
  - `gdscript-cheat-sheet.md` — Type inference rules, common patterns
  - `common-nodes.md` — Node types by category with use cases
- Created working examples in `examples/godot-patterns/`:
  - `scene-builder-example/` — 2D scene builder with ownership chain
  - `runtime-script-example/` — Player controller with proper type annotations
  - `test-harness-example/` — Test with simulated input and assertions

### Excluded (API-Dependent)

- asset_gen.py (Gemini API), tripo3d.py (Tripo3D API), visual_qa.py (Gemini Vision)
- All SKILL.md files (Claude Code skill invocation system)

---

## 2026-03-03 — PLAN-003 (3.2, 3.4) Ship Sprite Integration

**Tasks:** Register new ship art, faction ship sprites in navigation, combat ship sprites
**Model:** Opus 4.6

### New Art Assets

- `design/ships/wolf_ship.png` — Wolf Clans strike craft
- `design/ships/fairy_ship.png` — Fairy Court vessel
- `design/ships/knight_ship.png` — Knight Order warship
- `design/ships/goblin_scrapper.png` — Goblin Syndicate scrapship

### Ship Sprite Integration Modified Files

- `engine/sprite_manager.py` — Registered 4 new ship sprites (wolf, fairy, knight, goblin) in
  SHIP_SPRITES registry. Only `alien_craft` remains as a placeholder.
- `__main__.py` — Creates SpriteManager and passes to GameSession.
- `core/session.py` — Accepts `sprite_manager` parameter, stores it, passes to CombatState.
- `ui/navigation.py` — Faction ship sprites rendered at combat POIs (with bobbing animation and
  cutlass sub-icon). Faction inferred from encounter data via `_infer_faction()`. Player ship
  loading refactored to use SpriteManager. Location-to-faction and faction-to-template mappings.
- `ui/combat_ui.py` — Ship sprites replace vector shapes when available. Player sprite (facing
  right) and enemy sprite (flipped left). Vector fallback preserved. Lazy-loaded via
  `_ensure_sprites_loaded()`.
- `systems/combat.py` — Added `ship_template_id` field to `CombatShip` dataclass. Populated
  in both `from_game_ship()` and `from_template()` factory methods.
- `tests/test_sprite_manager.py` — Updated tests: new assets have paths, only `alien_craft`
  is empty. Test count: 26.

### Test Results

- 281 tests, 100% pass rate
- EAL compliance verified (zero pygame imports in core/systems/entities)

---

## 2026-03-03 — Phase 4 (4.1, 4.1b, 4.3) + PLAN-003 (3.1)

**Tasks:** Music System, SFX System, Ending Summary Screen, Sprite Asset Manager
**Model:** Opus 4.6

### Music and Sprite System Integration New Files

- `core/music_manager.py` — MusicManager with per-state theme mapping, arc-specific navigation
  themes, SFX event registry, enable/disable controls. Engine-agnostic (uses AudioInterface ABC).
- `engine/sprite_manager.py` — SpriteManager with centralised sprite loading, caching, scaling,
  faction-keyed ship/portrait/character registries, faction colour palettes. Lazy-load with
  graceful fallback to None (callers use vector shapes).
- `tests/test_music_manager.py` — 18 tests covering theme registry, state transitions, arc themes,
  overlay behaviour, SFX triggers, enable/disable, no-audio fallback.
- `tests/test_sprite_manager.py` — 25 tests covering registry completeness, lookup/caching,
  flip/scale, faction colour lookup, preload, cache clearing.
- `tests/test_ending_screen.py` — 18 tests covering ending calculation, summary builder
  (stats, factions, decisions, missions), input handling (scroll, confirm), text wrapping.
- `assets/audio/music/.gitkeep` — Directory for BGM track files
- `assets/audio/sfx/.gitkeep` — Directory for SFX files

### Music and Sprite System Integration Modified Files

- `core/session.py` — Replaced raw audio event subscriptions with MusicManager. Added
  `music.on_state_change()` at all key transitions (menu, cutscene, navigation, dialogue,
  combat, trade, ending). Wired SFX events through music manager. Arc advancement updates
  navigation theme via `music.on_arc_change()`.
- `ui/ending_screen.py` — Full rewrite: scrollable decision summary with voyage statistics
  (duration, crystals, salvage, encounters, decisions, ship status), faction standings with
  reputation tags (Allied/Friendly/Neutral/Hostile/At War), side mission summary, decision
  history grouped by arc with positive/negative indicators. Arrow key scrolling. Fixed
  `.reputation` → `.reputation_with_player` bug.

### Music and Sprite System Integration Bug Fixes

- Fixed `EndingState._calculate_ending()` using non-existent `.reputation` attribute on
  Faction entities (should be `.reputation_with_player`). Same fix in `_build_summary()`.

### Music and Sprite System Integration Test Results

- All 280 tests pass (210 previous + 70 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-02 — PLAN-002: Side Missions & Distress Signals

**Task:** Entertainment Enhancements — Side Missions + Distress Signals (13 tasks)
**Model:** Opus 4.6

### Side Missions and Distress Signals Integration New Files

- `systems/side_mission.py` — SideMissionSystem with mission lifecycle, objective tracking, reward
  application, and distress signal spawning (timer-based, weighted random)
- `data/side_missions/arc1_side_missions.json` — 4 side missions for Arc 1 (bounty, retrieval, escort, salvage)
- `data/side_missions/distress_signals.json` — 5 distress signal encounters with 3 choices each
  (help/exploit/ignore), repeatable, weighted spawn
- `ui/mission_log.py` — MissionLogState overlay (two-panel: mission list + detail with objectives/rewards)
- `tests/test_side_missions.py` — 24 tests covering entity serialization, data loading, system lifecycle,
  rewards, events, and GameStateData round-trip

### Side Missions and Distress Signals Integration Modified Files

- `core/interfaces.py` — Added `MISSION_LOG` to `Action` enum
- `core/state_machine.py` — Added `MISSION_LOG` to `GameStateType` enum
- `core/data_loader.py` — Added `load_side_missions(arc_id)`, `load_distress_signals()`
- `core/game_state.py` — Added `side_missions: dict[str, SideMission]` field + to_dict/from_dict
- `core/session.py` — Wired SideMissionSystem, M key hotkey, `_open_mission_log()`,
  load on new game/load/arc transition
- `entities/encounter.py` — Added `spawn_weight: float` field
- `engine/input_handler.py` — Mapped `pygame.K_m` to `Action.MISSION_LOG`
- `ui/navigation.py` — Distress POI spawning, mission objective checking, distress_signal colour
- `ui/hud.py` — Active mission count indicator (amber text in top bar)

### Side Missions and Distress Signals Integration Updated Documentation

- `docs/MASTER_PLAN.md` — Marked PLAN-002 complete, added PLAN-003 (Sprite Character & Visual Identity),
  updated metrics (210 tests, 10 systems, 14 UI states, 20 data files)

### Side Missions and Distress Signals Integration Test Results

- All 210 tests pass (186 previous + 24 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-02 — Documentation Audit & Restructure

**Task:** Documentation consolidation and master plan creation
**Scope:** Full /docs reorganisation — no source code changes

### Documentation Structure

- Created `docs/MASTER_PLAN.md` — unified single source of truth for all planning and status
- Created `docs/architecture/` — moved all TRDs (TRD-001, TRD-002, TRD-003) here from `docs/trd/`
- Created `docs/architecture/decisions/` — moved ADR_TEMPLATE and ADR-001 here from `docs/decisions/`
- Created `docs/process/` — moved `CONTRIBUTING.md` here; updated all plan references to `MASTER_PLAN.md`
- Created `docs/archive/prds/` — archived PRD-001, PRD-002, PRD-003 with completion summaries
- Created `docs/archive/plans/` — archived PLAN-001 (superseded) and PLAN-002 (absorbed into MASTER_PLAN.md)
- Created `docs/archive/briefs/` — moved `suggestions.md` here

### Reviews

- Moved `CODE_REVIEW_2026-03-02.md` → `docs/reviews/REVIEW-002_code_review_2026-03-02.md`
- Moved `IMPLEMENTATION_PLAN_2026-03-02.md` → `docs/reviews/REVIEW-002_remediation_plan_2026-03-02.md`
- Updated `docs/reviews/REVIEW_LOG.md` with REVIEW-002 entry

### Removed

- `docs/trd/` — empty after TRD migration to `docs/architecture/`
- `docs/prd/` — empty after PRD archival
- `docs/decisions/` — empty after ADR migration to `docs/architecture/decisions/`
- `docs/plans/` — superseded by `docs/MASTER_PLAN.md`
- `docs/suggestions.md` — moved to `docs/archive/briefs/`

### Documentation Audit & Restructure Updated

- `README.md` — updated project structure, docs links point to new locations, added game status
- `docs/process/CONTRIBUTING.md` — updated all plan references to `MASTER_PLAN.md` and new path structure
- `docs/reviews/REVIEW_LOG.md` — added REVIEW-002 entry

---

## 2026-03-01 — Phase 2: Game Systems

**Tasks:** 2.1, 2.2, 2.3, 2.4, 2.5, 2.6 (PLAN-001)
**Model:** Opus 4.6

### Task 2.1 — Economy System

- Created `systems/economy.py` — crystal extraction, supply routes, market pricing, buy/sell trade
- Added `to_dict()` / `from_dict()` to `CrystalDeposit`, `SupplyRoute`, `CrystalMarket` entities
- Added economy fields to `GameStateData` (crystal_deposits, supply_routes, crystal_market, trade_ledger)
- Updated `GameStateData` serialization for full economy round-trip
- Created `data/economy/economy_data.json` — 6 crystal deposits, 5 supply routes, market config, trade goods
- Added `load_crystal_deposits()`, `load_supply_routes()`, `load_crystal_market()` to `DataLoader`
- Wired `EconomySystem` into `GameSession`
- Created `tests/test_economy.py` — 38 tests covering extraction, discovery, routes, trade, faction economics, serialization

### Task 2.2 — Trade UI

- Created `ui/trade_screen.py` — `TradeScreenState` overlay with buy/sell modes, quantity selection, price display
- Faction-aware pricing with reputation modifiers and trade margin (75% sell/buy ratio)
- Cargo capacity checks, faction reserve limits, trade ledger summary
- Added `open_trade_screen()` to `GameSession` for encounter/dialogue integration

### Task 2.3 — Exploration System

- Created `systems/exploration.py` — `ExplorationSystem` with `Region` and `PointOfInterest` dataclasses
- Region discovery, accessibility, and travel with connected-region validation
- POI discovery via scanning (probability-based), visitation with reward application
- Procedural exploration events with weighted random selection based on region danger
- Full serialization via `get_state_dict()` / `load_state_dict()`
- Created `data/economy/regions.json` — 7 regions with connections, 5 POIs with rewards
- Added `load_regions()`, `load_points_of_interest()` to `DataLoader`
- Created `tests/test_exploration.py` — 16 tests covering regions, travel, POIs, events, serialization

### Task 2.4 — Crew Morale System

- Created `systems/crew_morale.py` — `CrewMoraleSystem` tracking individual and average crew morale
- Morale thresholds: MUTINY (≤20), DISGRUNTLED (≤40), STEADY (≤60), CONTENT (≤80), INSPIRED (>80)
- Combat modifier (0.7x–1.2x) and trade modifier (0.9x–1.1x) based on morale
- Event-driven morale effects: combat victory/defeat, trade outcomes, idle decay
- Faction loyalty checks: crew from hostile factions suffer morale penalties
- Mutiny risk events published when morale drops below threshold
- Created `tests/test_crew_morale.py` — 16 tests covering queries, changes, combat modifiers, loyalty

### Task 2.5 — Faction Conquest AI

- Created `systems/faction_conquest.py` — `FactionConquestAI` with AI-driven faction-vs-faction warfare
- `ConquestAction` dataclass for attack, blockade, diplomacy, and fortify actions
- AI target selection weighted by negative relationships; action type by personality traits
- Resolution: attacks compare military + tactical vs military + stability; blockades reduce reserves
- Diplomacy improves inter-faction relations; fortify boosts military and stability
- Power rankings, threat queries, conflict history tracking
- Created `tests/test_faction_conquest.py` — 8 tests covering planning, all action types, rankings, serialization

### Task 2.6 — Realm Control

- Created `systems/realm_control.py` — `RealmControlSystem` with `RealmState` tracking per-region influence
- Influence-based control: faction with highest influence controls region
- Contested detection when second-place faction has >70% of leader's influence
- Natural drift: home realm influence grows, foreign influence decays
- Conflict result application: winner gains influence, loser loses
- Danger modifiers for contested regions
- Full serialization via `get_state_dict()` / `load_state_dict()`
- Created tests in `test_faction_conquest.py` — 9 tests covering initialization, influence, control changes, territories

### Realm Control Test Results

- All 151 tests pass (99 previous + 52 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-01 — Phase 1: Core Infrastructure

**Tasks:** 1.1, 1.2, 1.3, 1.4 (PLAN-001)
**Model:** Opus 4.6

### Task 1.1 — Save/Load Manager

- Created `core/save_manager.py` — engine-agnostic save/load system with JSON persistence
- Supports 3 save slots with metadata (character name, arc, playtime, timestamp)
- Atomic writes via temp file + `os.replace()` to prevent corruption
- Created `tests/test_save_manager.py` — 12 tests covering round-trip, corruption, slots, deletion

### Task 1.2 — Wire Save/Load into UI

- Updated `core/session.py` — integrated SaveManager, settings, pause menu, and quit-to-menu flow
- Updated `ui/menu.py` — dynamic "Load Game" options based on available save slots
- Pause menu intercepts `Action.PAUSE` from navigation in `GameSession.tick()`
- Load game from menu or pause restores state and relaunches navigation

### Task 1.3 — Pause Menu

- Created `ui/pause_menu.py` — overlay state with Resume / Save / Load / Settings / Quit to Menu
- Quick save to current slot with visual feedback flash
- Follows overlay pattern (semi-transparent background, `machine.pop()` to resume)

### Task 1.4 — Settings Screen

- Created `ui/settings_screen.py` — overlay with music/SFX volume sliders and difficulty toggle
- Settings persisted to `~/.whisper_crystals/settings.json`
- `load_settings()` / `save_settings()` helpers with defaults merging
- Created `tests/test_settings.py` — 5 tests covering round-trip, defaults, corruption, directory creation

### Save/Load, Pause Menu, and Settings Screen Test Results

- All 61 tests pass (44 previous + 17 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-01 — Phase 0: Structural Refactor

**Tasks:** 0.1, 0.2, 0.3, 0.4, 0.5 (PLAN-001)
**Model:** Opus 4.6

### Task 0.1 — Extract GameSession from `__main__.py`

- Created `core/session.py` — engine-agnostic `GameSession` class with all callbacks, state transitions, and system orchestration
- Created `core/config.py` — game constants (screen size, FPS, splash duration)
- Created `engine/startup.py` — pygame-specific splash screen and loading frame rendering
- Created `engine/image_utils.py` — centralised pygame image loading and transformation
- Reduced `__main__.py` from 488 lines to 87 lines (pygame init, engine setup, thin main loop)

### Task 0.2 — Separate CombatState UI from combat logic

- Created `ui/combat_ui.py` — CombatState (GameState subclass) with all rendering and interaction
- Stripped `systems/combat.py` to pure logic only: CombatShip, CombatLog, calculate_damage, dodge_chance
- `systems/combat.py` now has zero imports from `core.interfaces` or `core.state_machine`

### Task 0.3 — Fix Engine Abstraction Layer violations

- Added `draw_image()`, `get_image_size()`, `measure_text()` to `RenderInterface` in `core/interfaces.py`
- Implemented all three in `engine/renderer.py` (PygameRenderer)
- Removed `import pygame` from `ui/menu.py`, `ui/navigation.py`, `ui/dialogue_ui.py`, `ui/cutscene.py`
- All UI files now use `RenderInterface` methods exclusively (draw_image, get_image_size, measure_text)
- **Verification:** zero pygame imports in `core/`, `systems/`, `entities/`, `ui/`

### Task 0.4 — Add missing GameStateTypes, remove dead code

- Added `FACTION_SCREEN`, `SHIP_SCREEN`, `SETTINGS` to `GameStateType` enum
- Updated `ui/faction_screen.py` to use `GameStateType.FACTION_SCREEN`
- Updated `ui/ship_screen.py` to use `GameStateType.SHIP_SCREEN`
- Deleted unused `core/game_loop.py`

### Task 0.5 — GameStateData serialization

- Added `to_dict()` / `from_dict()` to `PlayerDecision` and `GameStateData`
- Fixed `Faction.from_dict()` to accept both `reputation_with_player` and `starting_reputation` keys
- Created `tests/test_game_state_serialization.py` — 5 tests covering fresh/modified round-trip, JSON serialization, faction and NPC registry persistence

### Save/Load, Pause Menu, and Settings Screen Test

- All 44 tests pass (27 original + 17 new/modified)
- All tests run headless without pygame display context

---

## 2026-03-01 — Step 1: Project Management Structure

**Task:** Step 1 (PLAN-001)
**Model:** Opus 4.6 (planning), Haiku (execution)

### Project Management Structure Added

- `CLAUDE.md` — Project-level AI agent instructions with architecture rules and conventions
- `docs/CONTRIBUTING.md` — Task workflow guide for AI agents and developers
- `docs/plans/PLAN-001_Implementation_Master_Plan.md` — Full implementation plan (31 tasks across 6 phases)
- `docs/plans/PLAN-001_Task_Tracker.md` — Checkbox-based progress tracker for all tasks
- `docs/reviews/REVIEW_TEMPLATE.md` — Code review template with EAL compliance checklist
- `docs/reviews/REVIEW_LOG.md` — Master review log
- `docs/issues/ISSUE_TEMPLATE.md` — Issue reporting template
- `docs/issues/ISSUE_LOG.md` — Master issue index
- `docs/decisions/ADR_TEMPLATE.md` — Architecture Decision Record template
- `docs/decisions/ADR-001_Project_Structure_Refactor.md` — First ADR documenting the refactor rationale
- `docs/changelog/CHANGELOG.md` — This file

### Project Management Structure Directory Structure

- Created archive directories for: plans, reviews, issues, decisions, PRDs, TRDs, design, story
- Created issue tracking directories: open, in-progress, closed
