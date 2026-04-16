# Whisper Crystals — Godot Code Review

**Date:** 2026-04-16 (enhanced pass)
**Scope:** Full codebase walk — autoloads, systems, entities, UI, data, scenes, **and visual assets**.
**Supersedes:** the previous edition of this file (same path). See `docs/reviews/` for the earlier dated reviews that fed into `docs/MASTER_PLAN.md` §5.
**Companion plan:** [docs/NEXT_STEPS.md](../NEXT_STEPS.md) — prioritised action list reconciled with [docs/MASTER_PLAN.md](../MASTER_PLAN.md).

---

## 0. How this review differs from the last one

The previous edition identified sound structural issues but was written against a March codebase. Key numbers have shifted. Re-measured today:

| Metric | Previous review | Measured 2026-04-16 | Delta |
| --- | --- | --- | --- |
| Total `GameSession.` references | 248 | **236** | -12 (minor, still very high) |
| `GameSession.` references inside `scripts/ui/` | ~80 | **206** | **+126 — UI coupling has grown, not shrunk** |
| `navigation.gd` line count | ~800 | **1,723** | **+923 — doubled since the review** |
| `combat_ui.gd` | 586 | 585 | ≈ stable |
| `star_map_screen.gd` | 1,093 | 1,092 | ≈ stable |
| `dialogue_ui.gd` | 632 | 631 | ≈ stable |
| `game_session.gd` | 432 | 437 | ≈ stable |
| `event_bus.gd` | 50+ signals | still ~50+ (120+ quoted in MASTER_PLAN) | needs audit |

**Headline:** the UI layer has become the dominant coupling surface. `navigation.gd` in particular has near-doubled and is now the single biggest script in the project. This reinforces the original recommendation to decompose it; the need is now critical rather than stylistic.

**Post-review progress (2026-04-16, Sprint 3a):** The view-model recommendation in §2.1 was implemented for the navigation screen. `rg "GameSession\." godot/scripts/ui/navigation.gd` now returns **0** (was 73); UI-wide total is **134** (was 206). The pattern — `scripts/ui/view_models/<screen>_view_model.gd`, duck-typed `SessionDouble` for tests — is intended to be reused for combat_ui (Sprint 3b), star_map_screen (Sprint 5), and dialogue_ui (Sprint 6). Line counts below (1,723 / 585 / 1,092 / 631) are otherwise unchanged; decomposition is the next step.

---

## 1. Executive Summary

### Strengths

- **Deliberate architecture.** Four autoloads, systems as `RefCounted`, entities as `Resource`, UI as stateless views reading `game_state`. Everything data-driven. For a solo indie-scale Godot project this is unusually clean.
- **Production-breadth feature set.** 22 systems, 23 UI screens, 8 factions, 4 fully playable arcs, dual protagonist paths, karma/realm/conquest/hazard systems, 3-layer star map, 2D world layer with NPCs. The shipped surface area is large.
- **Test-before-review policy codified.** `MASTER_PLAN.md` §4 formalises runtime testing as part of review. This is the right policy; it now needs enforcement (GUT not yet installed).
- **Strong hero art.** Hand-painted ship portraits (e.g. `assets/ships/royal_galleon.png`, `wolf_ship.png`) and character portraits (`assets/characters/aristotle.png`, `dave.png`) are evocative, cohesive with the Spelljammer-adjacent tone, and genuinely beautiful.

### Critical concerns (new or sharpened since the last review)

1. **Visual inconsistency between hero art and world sprites.** This was not called out in prior reviews and is the single biggest felt-quality gap. See §6.
2. **UI coupling has worsened.** 206 `GameSession.` references inside `scripts/ui/` — more than the entire rest of the codebase combined. Every new UI screen is being written as a direct god-object caller.
3. **`navigation.gd` has grown to 1,723 lines** while still owning input, physics, minimap, POI rendering, fog-of-war, particles, and hazard overlays. The MASTER_PLAN earmarks this for Sprint 2 UI decomposition; its growth rate means it needs to move earlier.
4. **Four critical bugs from March reviews remain open** (MASTER_PLAN §5.2): `trigger_encounter_id` never evaluated; hull death not emitted from hazard damage; null guard missing on `player_ship`; `dialogue_manager.push_overlay` API mismatch. These block shipping confidence.
5. **No automated tests.** The MASTER_PLAN quality policy requires them; none exist. Every refactor proposed below is riskier without them.

### Non-critical but high-leverage

- Systems-built-but-not-wired gap persists: crew morale, astral hazards, realm control, faction conquest. Player cannot feel these systems today.
- Arc branching is nominal — paths converge. Player choice is performative.
- Combat is still a stat check (no abilities, no status effects, no archetypes).
- Onboarding, accessibility, controller support, and multi-slot saves remain on the backlog.
- Theme overrides leak hardcoded colors across `ship_screen`, `mission_log`, `combat_ui`, `dialogue_ui`.

---

## 2. Architecture & Code

### 2.1 UI-to-GameSession coupling is now the dominant issue

206 direct references inside `scripts/ui/`. This is more than the rest of the codebase combined. Recommended sequence:

1. **Inventory the UI reads.** `rg "GameSession\.(game_state|[a-z_]+_system)" godot/scripts/ui -o --no-filename | sort -u` produces the canonical list of entry points the UI actually uses.
2. **Create per-screen view-model adapters** (`NavigationViewModel`, `CombatViewModel`, `StarMapViewModel`) that expose only the fields/methods that screen needs. UI screens call the view model; the view model is the only thing that touches `GameSession`.
3. **Pass the view model via `initialize()`** when the screen is pushed, rather than reading the autoload at `_ready()`. This makes screens individually testable under GUT.
4. **Do not attempt a big-bang extraction.** Convert one screen per sprint (navigation → combat → star_map → dialogue → ship_screen), keeping the rest unchanged. This is the pattern MASTER_PLAN Phases 2–4 already anticipate — the view-model layer is the missing glue.

### 2.2 Decompose `navigation.gd` (1,723 lines)

Proposed split (same shape as the previous review, with updated line ranges):

- `NavigationController` — input + ship physics + region transitions (~400 lines)
- `NavigationHUD` — top-bar labels, flash label, objective binding (~200 lines)
- `MinimapRenderer` (Node2D child) — minimap drawing, POI pips, fog overlay (~300 lines)
- `POIRenderer` (Node2D child) — POI textures, hover state, encounter-type colours (~300 lines)
- `StarfieldRenderer` (Node2D child) — parallax starfield + particle trails (~200 lines)
- `HazardOverlay` (Node2D child) — astral-hazard visuals + effect application (~200 lines)

Each piece is a child node of the main scene, all driven by signals from the controller. This matches the existing "composition over inheritance via scene tree nodes" convention.

### 2.3 Tame `GameSession` ownership

Split `game_session.gd` (437 lines) into two files:

- `GameSession` (persistent state + save/load + playtime tracking)
- `SystemsHost` (owns the 22 `RefCounted` systems, exposed via typed getters)

Today the 22 systems are addressed as `GameSession.<system>_system`. A thin `Services` autoload or namespaced getter (`Services.combat`, `Services.economy`) shortens call-sites and gives a single place to swap implementations in tests.

### 2.4 Audit `event_bus.gd`

MASTER_PLAN quotes "120+ signals"; the file has ~50 declared signal statements but uses multi-signal lines. Either way:

- Identify signals **declared but never emitted** (confirmed earlier: `ui_select`, `ui_cancel`, `ui_navigate`).
- Group by domain with `#region` markers for navigability.
- Add the diagnostic channel (`diagnostic_emitted(source, severity, message)`) the previous review proposed. This is particularly valuable now because systems still return sentinel values (0/-1) on errors.

### 2.5 Centralise constants

`scripts/core/config.gd` already exists and was extended in the April 7 remediation. Continue pulling magic numbers out of:

- `navigation.gd` (SHIP_SPEED, POI_RADIUS, MINIMAP_*, STARFIELD_AREA — all at file-top)
- `dialogue_ui.gd` (typewriter CPS, open delay, combat hold)
- `combat_ui.gd` (colour palette, loot magic numbers)

The convention should be: if a constant is tuned by design intent, it lives in `Config`. If it is tuned by the scene (e.g. node reference positions), keep it local.

### 2.6 Minor code-quality items (carry-forward)

- `DataLoader` cache has no invalidation (MASTER_PLAN §5.3 Apr-05 #4).
- Theme overrides in content screens — ship_screen, mission_log, combat_ui, dialogue_ui still inline colours. Move to named StyleBox resources in `theme_builder`.
- `ProceduralMapManager` could drop out of autoloads once navigation is decomposed — only one consumer.

---

## 3. Gameplay Enhancement

Unchanged in direction from the previous review; still the highest-leverage area. Abbreviated here because [docs/NEXT_STEPS.md](../NEXT_STEPS.md) sequences these with art and refactor work.

- **Make choice branch the arc.** Replace the AND'd exit conditions in `arc_definitions.json` with OR-of-requirement-sets; tag encounters with `requires_flag` for path-gating; persist per-faction stance.
- **Give combat tactical decisions.** 2–3 abilities per crew role, reuse the existing status-effect shape from `astral_hazard_system.gd`, add `ai_profile` to ship templates.
- **Wire the dormant systems.** Crew morale → combat damage + trade prices; astral hazards → applied in navigation tick; realm control → gates docking; conquest actions → visible world changes.
- **Reward pressure gradient.** Upgrade tiers (T1 10 / T2 40 / T3 120), consumables, crew hire cost + upkeep.
- **Side missions with teeth.** Time-limited missions, arc-cascade missions, mission chains.
- **Procedural map as gameplay.** Distress events that read faction state, dynamic spawn difficulty, region ownership colouring.

---

## 4. Player Experience

### 4.1 Onboarding

- First-run tutorial encounter that introduces WASD → pickups → combat → dialogue one step at a time.
- Contextual tooltips on crew traits and faction standings.
- Persistent controls overlay bound to `F1` / `?`.

### 4.2 Accessibility

- Input rebinding in `settings_screen.gd` (audio-only today).
- Controller support — additive `JoyButton/JoyAxis` events alongside every key in `project.godot`.
- Text-size scaling, reduced-motion mode (skip typewriter + intro crawl twinkles), subtitle toggles.

### 4.3 Save & settings

- Multiple save slots — `pause_menu.gd` hardcodes slot 0.
- Autosave at arc transitions with a "Saved" toast.
- Video settings — fullscreen/windowed, resolution, vsync, gamma.

### 4.4 Dialogue UX

- Dialogue log (`H`), skip-seen-text (Ctrl), visible focus indicator on choice buttons, `Escape` closes dialogue.

### 4.5 Game feel

- Camera shake on hit, 1-frame white tint on damage, chromatic flash on crit.
- Audio ducking when dialogue opens (-40% music) instead of silencing.

### 4.6 HUD clarity

- Current objective read from `NarrativeSystem.current_arc.objective_text` on the top bar.
- Segmented hull bar in place of the hull number; cargo fill bar; crew-morale pip.

---

## 5. Game Flow Consistency

### 5.1 Unify transitions

`main.gd` already does 0.3s fade well. Apply to dialogue open/close (shorten the 1.5s delay to 0.4s), combat→dialogue outcome (2.0s → 0.8s), and intro crawl (6.1s pre-crawl → 3–4s with input-to-skip).

### 5.2 Input conventions

- Space currently binds to both `fire` and `skip` in `project.godot` — remap `skip` to Enter.
- `Escape` should reliably back out of every overlay.
- R key collides between `menu_select` and `repair` (carried forward from Mar-27 §2.4).

### 5.3 Persistent objective surface

Current objective should be one glance away in every arc-participating scene, not gated behind `M` for mission_log.

### 5.4 Theme adherence

Replace hardcoded colour overrides in content screens with named StyleBox theme variants (`parchment`, `combat`, `role_tag`, etc.).

### 5.5 Unified feedback vocabulary

Pick one grammar and apply everywhere:

- **Success** — short cyan flash + positive SFX.
- **Conflict** — red flash + combat SFX.
- **Info** — gold/amber subtle glow + UI chirp.

---

## 6. Visual Cohesion — THE BIGGEST FELT-QUALITY GAP (new section)

This section was not in the previous review. It is the single largest perceived-quality issue in the build and should be treated as peer to the UI-refactor work.

### 6.1 What I see today

- **Hero portraits** (`assets/characters/aristotle.png`, `dave.png`, `death_head.png`): hand-painted / AI-illustrated, rich palette, atmospheric lighting, expressive anatomy. Modern indie-game standard.
- **Ship silhouettes** (`assets/ships/wolf_ship.png`, `royal_galleon.png`, `knight_ship.png`, etc.): similarly detailed painted illustrations with gilded trim, ornate figureheads, visible weathering. Beautiful.
- **World/gameplay sprites** (`assets/sprites/*.png`, 15 sheets): 32×32 native, ~3–4 colour swatches per sprite, no shading, no anti-aliasing, no sub-pixel detail. Readable, functional, but visually **"late-80s / early-90s portable"** — NES / Game Boy Color level.

The gap between (hand-painted portrait) ↔ (blocky 32×32 sprite) is what reads as "Atari 2600" to the eye. The sprites themselves are not bad pixel art; they are simply several eras behind the rest of the art.

### 6.2 The Art Direction Guide is ambiguous

`design/art_direction/art_direction_guide.md` line 8 still reads *"2D pixel art or clean vector sprites (to be decided in prototype phase)"*. The project has moved well past prototype — this decision needs to land. MASTER_PLAN §7 Sprint 5 already lists "Art direction resolution" as High priority.

### 6.3 Three viable modernisation tracks

Pick **one floor + one aspirational** to keep scope sane.

**Track A — Upscale pixel floor (recommended as the baseline).**
Move native resolution from 32×32 to 64×64 (render at 256×256). Target ~12–16 colours per sprite with proper shading, selective anti-aliasing on curves, light rim-light to separate silhouette from background. Reference bar: Stardew Valley NPCs, Death's Door creatures, Moonlighter townsfolk. Preserves the existing animation rig (29 rows × frame counts) and SpriteFrames setup — no engine-side change.

**Track B — Painterly hand-drawn characters (aspirational).**
Abandon pixel art for hero characters; match the portrait/ship illustration style. Use this for the **4–6 player-selectable captains and 2–4 key NPCs** (Aristotle, Dave, Death, Fairy Cartographer, main faction leaders). Keep Track A for the cast at large.

**Track C — Hybrid silhouette + painted detail (lowest risk).**
Keep the existing 32×32 sheets as rigs; export higher-resolution "portrait card" overlays that appear during dialogue, shops, and cutscenes. This lets the painterly portraits already in `assets/characters/` do more work without redrawing any world sprites. Cheapest first step.

### 6.4 Recommended sequence

1. **Week 1 — Decide.** Update `design/art_direction/art_direction_guide.md`: declare the floor (Track A) and the aspirational bar (Track B for named characters). Delete the "to be decided" line.
2. **Week 2 — Pilot.** Redraw Aristotle's spritesheet to the new 64×64 standard (Track A) as the reference piece. Validate in-game. If the existing 32×32 rigs are happy being upscaled in the SpriteFrames config, test that as a no-redraw interim.
3. **Weeks 3–4 — Roll out.** Redraw Dave and the 4 Aristotle-side crew members to match. Keep generic NPC sheets (bard/guard/sailor/urchin) at current resolution until the named cast is consistent.
4. **Week 5 onward — Track B cards.** Commission the named-character painterly portraits (Track B) for dialogue/cutscene use. Aristotle and Dave already have these; extend to Death, Fairy Cartographer, Silky, Whiskers, Nine Lives, Blood Paw, No Tail.
5. **Ship art audit.** Ship sprites are already strong — spot-check for consistent silhouette weight and shared lighting direction (currently varies — `wolf_ship` is left-lit; `royal_galleon` is front-lit). Not urgent; address during audio/visual polish pass.

### 6.5 Acceptance criteria

- `assets/sprites/aristotle_spritesheet.png` redrawn at 64×64 native, 256×256 exported, ≥12 colours, readable at minimap scale.
- Side-by-side portrait vs. world-sprite shows the same character, the same palette, the same silhouette logic.
- Art Direction Guide declares a single canonical style with reference pins.

---

## 6A. 3D Cutscene — "No Tail Outpost" review (new section)

The project ships one 3D cutscene: `godot/scenes/cutscenes/no_tail_cutscene.tscn`, driving `godot/assets/cutscenes/no_tail_outpost.glb` plus the character GLBs. It plays but is held together by a large runtime workaround layer. Blender is available, which means most of this work can move out of GDScript and into the source .blend file.

### 6A.1 Core anti-pattern: fixing the model in code

`godot/scripts/systems/cutscene/cutscene_scene.gd` is 423 lines. Roughly 85% of it exists to compensate for deficiencies in the exported GLB:

| Runtime workaround | What it does | Should be in Blender |
| --- | --- | --- |
| `_hide_back_wall` (L87–112) | AABB-heuristic search for a wall panel behind the door, hides it | Simply **not model the wall** at the doorway in Blender |
| `_build_interior` (L119–273) | Builds floor, back wall, left/right walls, ceiling, interior light, crates, barrel, shelf **from primitives at runtime** | Model the interior room in the same .blend file |
| `_apply_burn_marks` (L279–337) | Places 5 `QuadMesh` nodes with `NoiseTexture2D` + gradient color-ramp around the door | Paint burn marks into the door-frame texture; or use decal meshes with a proper texture |
| `_hide_placeholder_characters` (L342–351) | Hides mesh nodes whose name begins with `Aristotle_` / `NoTail_` — the outpost GLB has placeholder character geometry baked in | **Remove placeholders from the GLB entirely before export** |
| `_force_red_light_fixture` (L358–386) | Proximity-matches a small mesh near the DoorRim light position, force-applies red emissive material | Assign an emissive material in Blender; name the slot meaningfully |
| `MaterialApplicator.apply()` (370 lines) | Walks the tree, applies `StandardMaterial3D` by keyword match on node names + AABB heuristics — because the GLB has no textures | Assign materials in Blender with proper names and UV unwraps |

Net effect: the cutscene today is brittle — it depends on a specific interior-space layout, specific mesh-name prefixes, and specific distances between nodes. Any rework of the .blend file risks breaking all of these heuristics silently.

### 6A.2 Camera system

`godot/scripts/systems/cutscene/camera_controller.gd` tweens position + FOV + look-at between keys defined in `godot/data/cutscenes/camera_path.json` (6 keys). Concerns:

- **Linear tween between keys, not paths.** No curves, no bank/roll, no acceleration control per shot. Hardcoded `TRANS_SINE + EASE_IN_OUT`.
- **`camera.look_at()` called every frame via `tween_method`.** This works but prevents smooth orientation interpolation and breaks on edge cases (look-at target coincident with position).
- **No lens effects.** No FOV-pump on reveals, no DoF pulls, no vignette shift on tension beats.
- **Indentation.** `camera_controller.gd` uses **4-space indent**; project convention is tabs. April 7 remediation fixed this in three files but missed this one.

The right answer: **author the camera as a Camera3D in Blender with keyframed animation, export to the same GLB, drive via `AnimationPlayer` in Godot**. The JSON-keyed tween system can stay as a fallback for generic cutscenes, but the hero shots should be Blender-authored.

### 6A.3 Other code issues

- **`_fade_in_character` mutates shared materials.** `cutscene_manager.gd:248–290` sets `transparency = TRANSPARENCY_ALPHA` and `albedo_color.a` on each surface's **active material**, tweens alpha, then sets it back. If two MeshInstances share a material (common after GLB import), the mutation leaks across instances. Use `set_surface_override_material` with a per-instance clone, or use a fade shader.
- **Return flow is a stub.** `cutscene_scene.gd:414–416` — `_on_cutscene_finished` prints `"In a real game, transition back to the main scene here."` and returns. The cutscene does not re-enter `main.gd`'s SceneManager. This is unimplemented plumbing, not a bug per se, but blocks shipping.
- **Hardcoded dialogue/camera paths.** `CutsceneManager` loads `res://data/cutscenes/no_tail_dialogue.json` by default and `CameraController` loads `res://data/cutscenes/camera_path.json` — both `@export_file` paths, but there is no cutscene registry, so adding a second cutscene means handcrafting a new .tscn with copy-paste node wiring.
- **`CutsceneDialogueUI` duplicates `scripts/ui/dialogue_ui.gd`.** Previously flagged (Apr-07 #14 rename). The two dialogue UIs share no code — parallel implementations of typewriter, speaker labels, choice buttons.

### 6A.4 Character model weight

`godot/assets/characters/aristotle_3d.glb` is **34 MB**; the companion texture `aristotle_3d_texture_20250901.png` is **19 MB**. `no_tail_3d.glb` + texture are similarly sized. The **outpost GLB itself is only 256 KB** — the character GLBs dominate the load time. MASTER_PLAN §6 flags 3D asset sizes as Medium priority; reinforced here.

Specific actions (all Blender-doable):

- Bake textures at 1024×1024 instead of 2048×2048 (or 2K with BC7/KTX2 compression).
- Decimate or LOD the mesh — inspect polycount; for a cutscene-only character, ~15–25k tris is plenty.
- Drop unused vertex colour / UV2 channels if present.
- Re-export with mesh compression enabled in the Godot `.import` settings.

### 6A.5 Lighting + look

The scene currently lights with:

- `Sun` DirectionalLight3D (energy 1.5, warm).
- `Fill` DirectionalLight3D (energy 0.4, cool blue).
- `DoorRim` OmniLight3D (energy 2.0, warm).
- Runtime-added interior OmniLight3D inside `_build_interior`.
- WorldEnvironment with ProceduralSky, ambient 0.4, glow 0.05, fog 0.0005 density.

This reads OK but the scene is a **scorched outpost after a League attack** — the mood should be heavier. Easy wins:

- **Increase fog density** during the wide shot, drop it on close-up reveals (animatable via WorldEnvironment).
- **Add volumetric / god-ray suggestion** via fog + key-light contrast, or a post-process volumetric shader.
- **Ember / dust particle system** near the door frame (hint at recent damage).
- **Flicker on the DoorRim light** — warning pulse while the door is closed; steady when it opens.
- **Bake indirect lighting** (SDFGI or LightmapGI) so the interior doesn't rely on a single dim OmniLight.

### 6A.6 Recommended fix sequence (Blender-first)

Ordered by leverage. Each item deletes multiple lines of `cutscene_scene.gd` runtime code.

1. **Rebuild `no_tail_outpost.blend`** with:
   - Proper **material slots** with meaningful names (`outpost_wall_metal`, `door_blast_plate`, `door_light_red`, `ground_scorched`, `floor_interior`, etc.).
   - UV unwraps on everything that takes a texture.
   - **Interior room modeled in-scene** (floor, walls, ceiling, crates, shelf, barrel) — no more runtime `_build_interior`.
   - **Burn marks painted into texture maps** on the door frame + ground. Tilable noise in the Blender shader editor + bake to texture.
   - **Door as a single named mesh child** of an Empty parent — the Empty is what we animate (not the mesh), so pivot and hierarchy stay stable.
   - **No placeholder character geometry** in the export.
   - **Camera animation** authored on a Camera3D node with 6 keyframes matching the current JSON, baked into an `AnimationPlayer` track.
   - Optionally: **DoorRim emissive fixture** as a named mesh with the red emissive material already assigned.

2. **Rewrite `cutscene_scene.gd`** once the rebuilt GLB is in. Expected result: script drops from ~420 lines to ~80, containing only wiring (dialogue UI, camera controller, event callbacks) — no geometry manipulation.

3. **Delete `MaterialApplicator`** entirely (370 lines). With materials baked in Blender, the runtime painter has no job.

4. **Replace `CameraController` with AnimationPlayer driver.**
   - Keep `camera_path.json` as a fallback for generic cutscenes.
   - For hero shots, load the baked camera animation from the GLB; the manager calls `AnimationPlayer.play("cam_sequence_01")`.
   - Optional: keep position/FOV keys in JSON but load AnimationPlayer-compatible tracks.

5. **Fix the fade-in.** Swap material-mutation for either a shader with a `fade` uniform or an AnimationPlayer track on each character's mesh visibility / modulate.

6. **Wire the return flow.** `_on_cutscene_finished` should emit on EventBus (e.g. `cutscene_completed(cutscene_id, karma_delta, recruited)`) and `SceneManager.pop_overlay()` or `change_scene` to the next gameplay node.

7. **Fix indentation.** `camera_controller.gd` to tabs.

8. **Unify dialogue UIs.** Merge `CutsceneDialogueUI` back into `scripts/ui/dialogue_ui.gd` (or vice versa), using one typewriter + choice implementation.

9. **Optimise character GLBs.** Re-export with 1024 textures + mesh compression. Target: < 4 MB per character GLB.

10. **Add a cutscene registry.** `data/cutscenes/_registry.json` listing `{id, scene_path, dialogue_path, camera_animation_name}` so adding a cutscene is data-only. Matches MASTER_PLAN Sprint 6.

### 6A.7 Acceptance criteria

- `cutscene_scene.gd` ≤ 100 lines.
- `MaterialApplicator` deleted.
- `no_tail_outpost.glb` contains its own interior, lit materials, and a Camera3D with keyframed animation.
- Character GLBs ≤ 4 MB each.
- Return flow re-enters `main.gd` SceneManager without a stub print.
- All cutscene files use tabs.
- One new test cutscene (even 30 seconds) can be added by duplicating `data/cutscenes/_registry.json` entry + a new .blend/.glb — no new wiring scene required.

---

## 7. Quick Wins (updated)

Small changes, high impact — each is a few hours' work and unblocked.

1. **Fix the 4 remaining critical bugs from MASTER_PLAN §5.2.** Non-optional.
2. **Install GUT and add one test** (`test_condition_evaluator.gd`). Unblocks every refactor that follows.
3. **Remove unused EventBus signals** (`ui_select`, `ui_cancel`, `ui_navigate`).
4. **Segmented hull bar** in navigation HUD in place of the hull number.
5. **Wire crew morale to combat damage** — 10 lines in `combat_system.gd`.
6. **Shorten dialogue open delay** 1.5s → 0.4s and combat hold 2.0s → 0.8s.
7. **`Escape` closes dialogue** — single `_unhandled_input` handler.
8. **Camera shake** on combat hits.
9. **Controller input** — add `JoyButton 0/1/2/3` alongside keys in `project.godot`.
10. **Input rebind panel** in settings_screen.
11. **Multiple save slots** in `pause_menu.gd`.
12. **Diagnostic EventBus signal** — replace silent `return 0` / `return -1` paths.
13. **Resolve R-key collision** (`menu_select` vs `repair`) in `project.godot`.
14. **Update Art Direction Guide** to remove the "to be decided" line and commit to the floor-style (Track A).

---

## 8. Verification

Run these before signing off any refactor that follows from this review:

- **Coupling baseline.** `rg "GameSession\." godot/scripts | wc -l` → was 236 at review time. `rg "GameSession\." godot/scripts/ui | wc -l` → was 206 at review time, **134** after Sprint 3a. Track per-sprint; target trend is monotonic downward as each screen gets a VM.
- **Script-size baseline.** `wc -l godot/scripts/ui/navigation.gd` → 1,717 (2026-04-16; VM conversion shifted a handful of lines but did not decompose). Any sprint that claims to reduce this must actually cut function bodies into child scenes per §2.2.
- **Dormant-system audit.** Enable EventBus logging and walk a 20-minute session. Expect zero `crew_morale_*`, `astral_hazard_*`, `realm_control_*`, `faction_conquest_*` emissions. That is the dormancy baseline before gameplay-wiring sprints.
- **Critical-bug regression.** Each of the four §5.2 bugs should have a GUT regression test committed with its fix.
- **Visual parity walk.** New-game → navigation → dialogue → combat. Capture screenshots. Place them next to `assets/characters/aristotle.png` and `assets/ships/royal_galleon.png` — they should feel like the same game.

Critical files to read before acting on any recommendation:

- `godot/scripts/autoload/game_session.gd`
- `godot/scripts/autoload/event_bus.gd`
- `godot/scripts/systems/combat_system.gd`
- `godot/scripts/systems/encounter_engine.gd`
- `godot/scripts/ui/main.gd`
- `godot/scripts/ui/navigation.gd`
- `godot/scripts/ui/dialogue_ui.gd`
- `godot/data/story/arc_definitions.json`
- `design/art_direction/art_direction_guide.md` ← now part of this review's scope.

---

## 9. Reconciliation with MASTER_PLAN.md

`docs/MASTER_PLAN.md` is the authoritative roadmap. This review is consistent with it, with two additions:

1. **Sprite modernisation** (§6 above) was already listed as `MASTER_PLAN` Sprint 5 ("Art direction resolution") but at lower priority than the critical-bug / test-framework work. This review **upgrades sprite modernisation to run in parallel with** Sprint 2–3 engineering work — because it's an art-pipeline task that doesn't block the refactor and is currently the most visible quality gap.
2. **UI coupling** is tracked in `MASTER_PLAN` §5.3 as "GameSession coupling (remaining systems)". The measured delta (+126 UI refs since the previous review) means this should no longer be deferred behind the four UI-decomposition sprints; a view-model layer should land alongside Sprint 2's combat_ui work.

No contradictions with MASTER_PLAN. See [docs/NEXT_STEPS.md](../NEXT_STEPS.md) for the sequenced action list that folds this review back into the MASTER_PLAN sprint structure.

---

## Final Note

The foundation remains genuinely strong. The work ahead is **two parallel tracks**: (a) an engineering track that lands tests, decomposes the god-scripts, wires dormant systems, and gives player choice real teeth; and (b) an art-direction track that closes the pixel-vs-painted gap and commits to a single visual language. Neither track blocks the other. Both should run now.
