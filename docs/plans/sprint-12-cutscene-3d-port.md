# Sprint 12 — Cutscene 3D port (Phase A)

**Status:** proposed 2026-04-21, awaiting kickoff.
**Scope:** `godot/assets/cutscenes/no_tail_outpost.blend`, `godot/assets/cutscenes/no_tail_outpost.glb`, `godot/scenes/cutscenes/no_tail_cutscene.tscn`, `godot/data/cutscenes/camera_path.json`, `godot/data/cutscenes/no_tail_dialogue.json`.
**Supersedes:** Sprint 7 painted-backdrop approach (closed 2026-04-21; see `docs/NEXT_STEPS.md` Sprint 7 closure note and `memory/project_cutscene_state.md`).

## Context

Sprint 7 shipped engineering cleanup successfully (code reductions, auto-advance, walk animation triggering, `MaterialApplicator` deletion — all kept on `main`). The visual pivot (painted concept art as a backdrop `QuadMesh` behind 3D characters) was rejected by the user on 2026-04-21: *"looks like a play on a stage... so bad, so, so bad. full rebuild it is."*

User directives for the rebuild (2026-04-21):

1. **Port** the existing `no_tail_outpost.blend` geometry rather than rebuild from scratch. If the port fails to hit the visual bar, full rebuild is deferred to a follow-up.
2. **Stylized**, not PBR. Rationale: characters are hand-painted; PBR on geometry next to painted characters causes aesthetic dissonance. Stylized textures keep artistic coherence and author faster.
3. **Door** — rusted, burnt, shot-at metallic (not pink).
4. **Interior** — warm amber glow (not pink).
5. **Walls** — built up from materials that match the character painterly aesthetic.

## Starting state (already on `main`)

- `no_tail_outpost.blend` (commit `b6f8424`) has textured geometry — walls/wreckage/hills on plaster/mud/cobblestone tints. Renders correctly in Godot (no more vertex-color chain bug from earlier in Sprint 7).
- `no_tail_outpost.glb` (1.9 MB) hidden via `$World/NoTailOutpost.visible = false` in the `.tscn`.
- `cutscene_scene.gd` (77 lines), `cutscene_manager.gd` (walk + auto-advance + camera_sequence + choice types), `camera_controller.gd` (JSON-driven keys), `dialogue_ui.gd` (auto-advance) — all work, all stay.
- 6 Poly Haven CC0 textures shipped at `godot/assets/textures/fringe_haven/` (grass, cobblestone, mud, plaster, wood_planks, roof_tiles) and `godot/assets/cutscenes/textures/` (same set, extracted by Godot on glTF import). Reuse these.
- Painted backdrop `backdrop.png` (6.8 MB) + extracted Godot sidecars (~10 duplicate JPGs) remain in repo — deleted in Phase A.8.

## Approach

Port existing geometry. Rewrite only the materials that need changing (door, door-frame, new interior glow). Add a small interior room mesh behind the door. Replace the painted-backdrop quad with actual atmospherics (volumetric fog + warm skybox). Redo the camera path to use real 3D freedom (true reverse shots). Iterate at phase checkpoints with user review. If the A.5 checkpoint doesn't hit the bar, abort the port and switch to full rebuild.

## Phases

### A.1 — Diagnose port starting point (~30 min)

- Via `blender-mcp`: un-hide all objects in `no_tail_outpost.blend`, capture a screenshot from the concept-art-matching angle (wide, outpost mid-frame). Verify geometry still reads.
- In Godot: temporarily set `$World/NoTailOutpost.visible = true` and run headless; locate Door world position and Outpost Body bounding box.
- **Checkpoint:** report findings + propose concrete character positions relative to unhidden outpost. No code shipped yet.

### A.2 — Door + frame + interior-glow materials (Blender, ~45 min)

Re-author in `no_tail_outpost.blend` using the Phase 3 texture pattern (plain BSDF + texture + optional MixRGB tint — **not** the Apr-17 vertex-color chain that doesn't export through glTF).

- **`mat_Door` — rusted/burnt/shot-at metallic.**
  - Base: plaster texture tinted charcoal `(0.14, 0.12, 0.10)`, roughness 0.55, metallic 0.55.
  - Rust overlay: voronoi noise → color ramp (dark → orange-brown `(0.45, 0.22, 0.10)`), MixRGB additive ~35% over base.
  - Scorch marks: second voronoi at lower frequency → sharp ramp → near-black patches, MixRGB multiply ~60%. Emissive orange `(0.8, 0.3, 0.1)` strength 0.4 at hottest edges.
  - Bullet scars: noise → small highlight specks, emissive warm-white `(1.0, 0.85, 0.6)` strength 0.3 where hit edges catch light.
- **`mat_Door_FrameLeft/Right/Top` — weathered dark metal.** Same charcoal base, lighter rust overlay, no scorch. Distinguishes frame from door.
- **`mat_Door_WarningLight` — retain** (already red-emissive strength 4; matches aesthetic).
- **New `mat_Interior_Amber` — warm emissive hallway end.** Emission `(1.0, 0.70, 0.35)` strength 2.5, base color same tone, shading `UNSHADED`. Applied to a plane behind the door in A.3.

### A.3 — Add interior room geometry (Blender, ~30 min)

Behind the door, recessed ~3 m × 2 m × 3 m hallway:

- BoxMesh walls (plaster-tinted warmer, roof + floor darker).
- Back-wall emissive amber plane with `mat_Interior_Amber`.
- Subtle bulkhead ribs (3–4 extruded edges) for silhouette interest when NoTail is backlit.
- Door already on its pivot from Sprint 7 Phase 2 texture pass.

### A.4 — Scene wiring (`no_tail_cutscene.tscn`, ~20 min)

- Set `$World/NoTailOutpost.visible = true`.
- Remove `Backdrop` MeshInstance3D + `BackdropMat_1` + `BackdropMesh_1` subresources + `8_backdrop` ExtResource.
- Reposition `Aristotle` + `NoTail` to align with the outpost's actual door world-position (from A.1). Expected: Aristotle in front of door, NoTail just inside the new interior room, `visible = false` until `door_opens` beat.
- Keep `Aristotle` rotation at 180° yaw (face -Z / toward door); `NoTail` at identity (face +Z / toward Aristotle).

### A.5 — Materials polish on walls / wreckage (Blender, ~30 min) — **USER CHECKPOINT**

Retune existing Phase 3 materials on `Outpost_Body/Annex/Buttress/Vent/UpperStrip` + wreckage:

- Walls: "built-up" = plaster base + subtle wood-plank tint accent on UpperStrip + darker stone at base (bottom 0.5 m via color ramp on Z height) + visible seam lines at panel boundaries. Warm-ochre palette, no cool tones.
- Roof: existing roof_tiles material stays; maybe dial down saturation slightly.
- Wreckage: existing burnt-metal plaster material; bump metallic 0.3 → 0.5 and roughen 0.9 → 0.85 for visible hull sheen where sun hits.

**Checkpoint:** Godot screenshot from establishing camera. User review.
If mood matches concept art (warm sepia, painterly, battle-scarred) → proceed.
If not → **abort the port, switch to full rebuild** (out of scope for this plan).

### A.6 — Camera choreography redo (`camera_path.json`, ~30 min)

7 keys. Painted-backdrop constraint is gone — true reverse shots now work. Exact positions depend on A.1 door world-coord, drafted post-A.1.

1. `CAM_01_Establishing` — wide showing outpost + wreckage + Aristotle landing.
2. `CAM_02_GlideBehind` — 3/4 behind Aristotle as he walks forward.
3. `CAM_03_OverShoulderDoor` — tight over his shoulder, door dominates.
4. `CAM_04_ReverseReaction` — **true reverse** on Aristotle reacting to the grind, warning-light glow on his face.
5. `CAM_05_DoorOpenProfile` — profile angle as door lifts, interior amber spills silhouetting NoTail.
6. `CAM_06_NoTailEmerges` — NoTail walks forward from interior; amber recedes behind her.
7. `CAM_07_TwoShot` / `CAM_08_Reverse` — dialogue shot-reverse-shot pair.

Walk targets in `no_tail_dialogue.json` updated to match new character world positions.

### A.7 — Atmospherics + lighting (`.tscn`, ~30 min)

- `WorldEnvironment` — volumetric fog density 0.012, warm tint `(0.55, 0.35, 0.22)`, aerial perspective enabled. Replace the procedural sky with a warm horizon gradient.
- Sun `DirectionalLight3D` — warm orange `(1.0, 0.6, 0.35)`, energy 2.5, low-right angle (~15° elevation). Shadows on, `directional_shadow_max_distance = 60`, PCSS blur. `light_volumetric_fog_energy = 1.5` for god-ray effect.
- Fill `DirectionalLight3D` — cool purple `(0.4, 0.42, 0.55)`, energy 0.35, camera-side.
- Interior `OmniLight3D` inside hallway — warm amber `(1.0, 0.72, 0.42)`, range 5 m, energy 2.0. Bounces amber onto door frame and NoTail when she's inside.
- 3 × `GPUParticles3D` smoke columns at wreckage positions (re-use `fringe_haven_3d.gd:_make_campfire_3d` recipe — amount 60, upward velocity, dark palette, longer lifetime).
- Dust-motes `GPUParticles3D` — small bright flecks at camera height.

### A.8 — Retire painted-backdrop scaffolding + verify (~15 min)

- Delete `godot/assets/cutscenes/no_tail_outpost/backdrop.png` + `.import`.
- Delete extracted Godot sidecars: `godot/assets/cutscenes/no_tail_outpost_{cobblestone,grass,mud,plaster,roof_tiles}_diff_1k.jpg*` and `godot/assets/cutscenes/textures/*.jpg*`. ~6 MB reclaimed. Keep `design/cutscenes/no_tail_outpost_design_1.png` as reference.
- Full GUT headless sweep (expect 256/256).
- `no_tail_cutscene.tscn` headless smoke-load; expect clean exit.
- Playthrough screenshot to `docs/qa/cutscenes/sprint_12_a_port.png`.
- CHANGELOG entry + memory update.

## Critical files

- `godot/assets/cutscenes/no_tail_outpost.blend` — material rewrites (A.2, A.5), interior geometry (A.3)
- `godot/assets/cutscenes/no_tail_outpost.glb` — re-exported after .blend changes
- `godot/scenes/cutscenes/no_tail_cutscene.tscn` — unhide GLB, remove backdrop, reposition characters, retune lighting + env (A.4, A.7)
- `godot/data/cutscenes/camera_path.json` — 7+ new camera keys (A.6)
- `godot/data/cutscenes/no_tail_dialogue.json` — updated walk targets (A.6)
- `docs/changelog/CHANGELOG.md` — Phase A entry (A.8)

## Reused utilities

- `CutsceneManager._run_walk` — `play_anim("walk"/"idle")` + `look_at` orientation logic landed `a1678c4`; reused as-is.
- `dialogue_ui.show_line` — `auto_advance_seconds` param reused for narration beats.
- `fringe_haven_3d.gd:_make_campfire_3d` — GPUParticles3D recipe; port to smoke-column variant for A.7 (dark palette, taller lifetime, wind drift).
- Sprint 7 Phase 3 material pattern (plain BSDF + texture + MixRGB) — reused for all new materials. **Do not** use the Apr-17 vertex-color shader chain.

## Verification plan

1. **After A.5 (materials checkpoint):** run `/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 60 res://scenes/cutscenes/no_tail_cutscene.tscn`. Capture screenshot via `mcp__godot__run_project`. Compare side-by-side with concept art. User review; green-light or iterate.
2. **After A.7 (full scene ready):** same command, `--quit-after 1200` to play through several beats. Verify zero errors, no new warnings.
3. **After A.8 (final):** GUT headless `256/256 green`. Run the cutscene end-to-end clicking through choices. Capture screenshot.
4. **Acceptance:** user verdict "yes, that's what I wanted" → commit, close Sprint 12 Phase A. "Still not right" → full rebuild (Sprint 12 Phase B — not scoped here).

## Estimate

~3 hours focused work + checkpoints. First checkpoint (A.5) within ~2 hours to allow early abort.

## Risks

- **Port might not carry the concept art's mood** even with retuned materials. A.5 is the escape hatch.
- **Door's "rusted, burnt, shot-at" look is procedural** — no dedicated rust CC0 texture available in repo. Voronoi-noise approach is stylized-friendly but may need hand-tuning. Plan B: download one new 1K rust CC0 texture from Poly Haven.
- **Interior amber spill must reach Aristotle's face during `CAM_04_ReverseReaction`.** `OmniLight3D` range may need tuning or a second point light at door threshold.
- **Volumetric fog + god-rays + particles + PCSS shadows** may blow frame budget. Monitor fps; drop PCSS or reduce particle counts if needed.
