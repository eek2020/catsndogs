# Whisper Crystals — Godot Code Review

**Date:** 2026-04-16 (enhanced pass, refreshed post-Sprint 5a)
**Scope:** Full codebase walk — autoloads, systems, entities, UI, data, scenes, **and visual assets**.
**Supersedes:** the previous edition of this file (same path). See `docs/reviews/` for the earlier dated reviews that fed into `docs/MASTER_PLAN.md` §5.
**Companion plan:** [docs/NEXT_STEPS.md](../NEXT_STEPS.md) — prioritised action list reconciled with [docs/MASTER_PLAN.md](../MASTER_PLAN.md).

---

## 0. How this review differs from the last one

The previous edition identified sound structural issues but was written against a March codebase. Numbers below are re-measured after Sprints 1, 3a, 3b, 3c, and 5a have landed.

| Metric | Previous review | This review | Post-Sprint 5a |
| --- | --- | --- | --- |
| Total `GameSession.` references | 248 | 236 | **131** |
| `GameSession.` references inside `scripts/ui/` | ~80 | 206 | **106** |
| `navigation.gd` line count | ~800 | 1,723 | 1,717 (VM cut coupling, decomposition pending) |
| `combat_ui.gd` | 586 | 585 | **399** (+ 4 focused components under `scripts/ui/combat/`) |
| `star_map_screen.gd` | 1,093 | 1,092 | **375** (+ 3 layer components under `scripts/ui/star_map/`) |
| `dialogue_ui.gd` | 632 | 631 | 632 (pending Sprint 6) |
| `game_session.gd` | 432 | 437 | 506 (grew in 3c to own post-scene-change transition work) |
| `event_bus.gd` signal count | "50+" / MASTER_PLAN quoted 120+ | ≈ 50 declared | **70** (audited 2026-04-16; `npc_bark` added 3c) |
| Unit tests | 0 | 0 | **97 across 12 files** (GUT 9.6.0 vendored) |
| Four critical bugs (§5.2) | Open | Open | **All closed** 2026-04-16 (Sprint 1) |

**Headline shift:** UI coupling is no longer the dominant issue. Sprints 3a/3b/5a retired 100 of the 206 UI refs by routing three screens through dedicated ViewModels. What remains: `navigation.gd` still 1,717 lines (coupling gone, decomposition pending); `dialogue_ui.gd` still a monolith (Sprint 6); four dormant systems (morale, hazards, realm_control, faction_conquest) still unwired into gameplay (Sprint 5b / 5c).

**Post-review progress (2026-04-16):**

- **Sprint 1** — GUT installed; the four critical §5.2 bugs closed; 9 regression tests.
- **Sprint 3a** — `NavigationViewModel` + `navigation.gd` conversion (73→0 refs, 22 tests).
- **Sprint 3b** — `CombatViewModel` + `combat_ui.gd` decomposition (585→399 + `scripts/ui/combat/{layout,logic,animations,health_bar}.gd`; 4→0 refs; 31 tests).
- **Sprint 3c** — Four should-fix bugs closed: R-key collision (stale tracker), `scene_transition` tween-on-freed-node (moved post-change work into `GameSession.complete_scene_transition`), `_show_bark` recursion risk (dedicated `EventBus.npc_bark` signal), portrait texture cache (static memo keyed by `resource_path`+thresholds). 15 tests.
- **Sprint 5a** — `StarMapViewModel` + `star_map_screen.gd` decomposition (1,092→375 + `scripts/ui/star_map/{galaxy,region,local}_layer.gd`; 23→0 refs; 20 tests).

Pattern — `scripts/ui/view_models/<screen>_view_model.gd` + duck-typed `SessionDouble` for tests — is established and will be reused for `dialogue_ui.gd` (Sprint 6) and the remaining smaller screens.

---

## 1. Executive Summary

### Strengths

- **Deliberate architecture.** Four autoloads, systems as `RefCounted`, entities as `Resource`, UI as stateless views reading `game_state`. Everything data-driven. For a solo indie-scale Godot project this is unusually clean.
- **Production-breadth feature set.** 22 systems, 23 UI screens, 8 factions, 4 fully playable arcs, dual protagonist paths, karma/realm/conquest/hazard systems, 3-layer star map, 2D world layer with NPCs. The shipped surface area is large.
- **Test-before-review policy codified.** `MASTER_PLAN.md` §4 formalises runtime testing as part of review. This is the right policy; it now needs enforcement (GUT not yet installed).
- **Strong hero art.** Hand-painted ship portraits (e.g. `assets/ships/royal_galleon.png`, `wolf_ship.png`) and character portraits (`assets/characters/aristotle.png`, `dave.png`) are evocative, cohesive with the Spelljammer-adjacent tone, and genuinely beautiful.

### Critical concerns (status as of 2026-04-16 post-Sprint 5a)

1. **Visual inconsistency between hero art and world sprites.** This was not called out in prior reviews and is the single biggest felt-quality gap. See §6. Art Direction Guide has since committed to Track A floor + Track B aspirational (NEXT_STEPS Sprint 2); sprite pilot redraw still pending a human artist.
2. **UI coupling is being retired screen-by-screen.** Was 206 UI `GameSession.` refs; now **106** after three ViewModel landings. Remaining screens (dialogue_ui, ship_screen, mission_log, station, faction, purchase, trade, pause_menu, settings…) will each get their own VM over Sprints 6–7.
3. **`navigation.gd` remains 1,717 lines.** Coupling was cut via `NavigationViewModel` (Sprint 3a) but function bodies were not decomposed. Still owns input, physics, minimap, POI rendering, fog-of-war, particles, and hazard overlays. Decomposition into renderer child nodes (§2.2 below) is outstanding.
4. **Four March-review critical bugs — all closed** as of 2026-04-16 (Sprint 1). See MASTER_PLAN §5.1.
5. **Automated tests — GUT 9.6.0 vendored**, 97 tests across 12 files green. Every subsequent sprint ships with regression tests.
6. **Dormant systems still dormant.** Crew morale, astral hazards, realm control, and faction conquest all compute state but do not flow into the combat/trade/docking/navigation loops the player actually touches. Scheduled for Sprint 5b (morale + hazards) and 5c (dock gating + conquest surfacing). Until these land, player choice in the arc system is still largely performative.

### Non-critical but high-leverage

- Systems-built-but-not-wired gap persists: crew morale, astral hazards, realm control, faction conquest. Player cannot feel these systems today.
- Arc branching is nominal — paths converge. Player choice is performative.
- Combat is still a stat check (no abilities, no status effects, no archetypes).
- Onboarding, accessibility, controller support, and multi-slot saves remain on the backlog.
- Theme overrides leak hardcoded colors across `ship_screen`, `mission_log`, `combat_ui`, `dialogue_ui`.

---

## 2. Architecture & Code

### 2.1 UI-to-GameSession coupling — decomposition in progress

**Status:** 206 → **106** refs between review start and Sprint 5a. Three screens fully decoupled via ViewModel adapters; rest pending.

**Shipped pattern** (`scripts/ui/view_models/<screen>_view_model.gd`):

- `RefCounted` adapter holding a `_session` reference (the autoload in prod, a `SessionDouble` in tests).
- Null-guarded narrow wrappers over `game_state`/systems the screen actually uses.
- An optional `star_map()` / `exploration()` “escape hatch” for draw loops that need structured access.
- Injected via `initialize(vm)`; `_ready` falls back to constructing one from the `GameSession` autoload so `main.gd`'s existing scene-switch flow is unchanged.

**Converted so far:**

- `NavigationViewModel` — Sprint 3a. `navigation.gd` 73 → 0 refs. 22 tests.
- `CombatViewModel` — Sprint 3b. `combat_ui.gd` 4 → 0 refs. 8 tests.
- `StarMapViewModel` — Sprint 5a. `star_map_screen.gd` 23 → 0 refs. 20 tests.

**Remaining screens** (rough budget, `scripts/ui/`): `dialogue_ui.gd` (Sprint 6), `ship_screen.gd`, `mission_log.gd`, `station_screen.gd`, `faction_screen.gd`, `purchase_screen.gd`, `trade_screen.gd`, `pause_menu.gd`, `settings_screen.gd`, `planet_surface.gd`, `planet_screen.gd`, `arc_summary.gd`, `ending_screen.gd`, `character_select.gd`, `skill_allocation.gd`, `intro_crawl.gd`. These collectively own the 106 remaining refs; each VM conversion is ~1–2 sessions of work.

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

**Audited 2026-04-16:** `event_bus.gd` declares **70 signals** (not the 120+ quoted previously — MASTER_PLAN has been corrected). Still outstanding:

- `ui_select`, `ui_cancel`, `ui_navigate` are declared but never emitted. Candidate for deletion.
- Class-level `@warning_ignore("unused_signal")` is applied (line 10), but the editor linter reports the suppression is not being honoured at analysis time — the runtime compile is fine. Cosmetic; not a functional issue.
- Domain grouping is present via comment headers (`# --- Combat events ---` etc.); upgrade to `#region` markers for IDE foldability.
- Add the diagnostic channel (`diagnostic_emitted(source, severity, message)`) the previous review proposed — systems still return sentinel `0` / `-1` values on errors.

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

- **R-key collision between `menu_select` and `repair` — resolved.** `repair` rebound to T in Sprint 1; Sprint 3c added `tests/unit/test_input_map_collisions.gd` as a broad regression guard.
- **`pause` and `skip` both bound to `KEY_ESCAPE`** (surfaced by the Sprint 3c regression test). Currently tolerated via a context-separated whitelist (`pause` lives in navigation/combat, `skip` in intro_crawl/cutscene). Revisit when the rebind panel lands in Sprint 6.
- **`Escape` should reliably back out of every overlay** — still partially true; `star_map_screen` does it right, other overlays audit-pending.
- **Space bar — no longer shared between `fire` and `skip`.** Current bindings: `fire` = SPACE, `skip` = ESC. The previous review flagged this; it was quietly fixed when `skip` moved to ESC.

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

## 7. Quick Wins (updated 2026-04-16 post-Sprint 5a)

Progress on the original list, plus remaining small-but-high-impact items.

**Done (original tracker numbers preserved in parentheses):**

- (#1) ~~**Fix the 4 remaining critical bugs from MASTER_PLAN §5.2.**~~ Sprint 1 (2026-04-16).
- (#2) ~~**Install GUT and add one test** (`test_condition_evaluator.gd`).~~ Sprint 1. Now 97 tests across 12 files.
- (#13) ~~**Resolve R-key collision** (`menu_select` vs `repair`) in `project.godot`.~~ Stale tracker — already fixed in Sprint 1; Sprint 3c added broad collision regression test.
- (#14) ~~**Update Art Direction Guide** to remove the "to be decided" line and commit to the floor-style (Track A).~~ NEXT_STEPS Sprint 2 (art guide + reference pins done; sprite pilot redraw still pending artist).

**Still outstanding:**

- (#3) **Remove unused EventBus signals** (`ui_select`, `ui_cancel`, `ui_navigate`).
- (#4) **Segmented hull bar** in navigation HUD in place of the hull number (NEXT_STEPS Sprint 5c).
- (#5) **Wire crew morale to combat damage** — ~10 lines in `combat_system.gd` (NEXT_STEPS Sprint 5b).
- (#6) **Shorten dialogue open delay** 1.5s → 0.4s and combat hold 2.0s → 0.8s.
- (#7) **`Escape` closes dialogue** — single `_unhandled_input` handler.
- (#8) **Camera shake** on combat hits.
- (#9) **Controller input** — add `JoyButton 0/1/2/3` alongside keys in `project.godot` (NEXT_STEPS Sprint 6).
- (#10) **Input rebind panel** in settings_screen (NEXT_STEPS Sprint 6).
- (#11) **Multiple save slots** in `pause_menu.gd` (NEXT_STEPS Sprint 6).
- (#12) **Diagnostic EventBus signal** — replace silent `return 0` / `return -1` paths.

---

## 8. Verification

Baseline numbers used by every sprint-exit check.

- **Coupling baseline.** Total `GameSession.` refs was 236 at review time, now **131**. UI-only was 206, now **106**. Per-sprint target: monotonic downward as each screen gets a VM. Measure via `grep -r 'GameSession\.' godot/scripts --include='*.gd' | wc -l` (project has no `rg`).
- **Script-size baseline.** `wc -l godot/scripts/ui/navigation.gd` → 1,717 still. `combat_ui.gd` 585 → 399 (Sprint 3b). `star_map_screen.gd` 1,092 → 375 (Sprint 5a). `dialogue_ui.gd` 632 still (Sprint 6 target). Any sprint that claims to reduce a file must actually cut function bodies into companion modules per §2.2 / Refactoring Plan.
- **Dormant-system audit.** Enable EventBus logging and walk a 20-minute session. Today: zero `crew_morale_*`, `astral_hazard_*`, `realm_control_*`, `faction_conquest_*` emissions flow into gameplay effects. That is the dormancy baseline before Sprint 5b/5c wiring lands.
- **Critical-bug regression.** All four §5.2 bugs have GUT regression tests committed with their fixes (Sprint 1).
- **Test suite.** `/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` → should print `97/97 passing`. Any merge that drops the count needs justification in the commit message.
- **Visual parity walk.** New-game → navigation → dialogue → combat. Capture screenshots. Place them next to `assets/characters/aristotle.png` and `assets/ships/royal_galleon.png` — they should feel like the same game. (Pending sprite pilot.)

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
