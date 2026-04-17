# 3D Character Pipeline — Whisper Crystals

Canonical reference for producing rigged, animation-ready `.glb` characters for the Whisper Crystals crew + NPC roster. Read this **before** starting work on a new crew member, boss, or faction NPC.

Owner: 3D art pipeline. Last validated end-to-end against `nine_lives_rigged.glb` on 2026-04-17.

## TL;DR

```text
Tripo3D GLB  (unrigged, broken-animation)
   │
   │  strip_and_prep_for_mixamo.py   (rigless clean GLB + FBX)
   ▼
<name>_clean.glb / .fbx
   │
   │  retarget_to_cc0_rig.py         (weld onto CC0 UAL armature + 45 anims)
   ▼
<name>_rigged.glb   ← ships to godot/assets/characters/crew/
   │
   │  validate_rigged_glb.gd         (headless Godot structural check)
   ▼
 PASS / FAIL report
```

**Preferred path** is the CC0 Universal Animation Library (UAL) direct retarget — no Adobe account, no manual marker-placement, repeatable per-character. The Mixamo path is preserved as a fallback for rigs that UAL cannot fit (non-humanoid, custom bone counts, etc.).

## Inputs and outputs

| Stage | Script | Input | Output |
| ----- | ------ | ----- | ------ |
| **1. Strip + prep** | `tools/blender-dev/strip_and_prep_for_mixamo.py` | Tripo3D GLB with broken auto-rig | `<name>_clean.glb`, `<name>_clean.fbx`, `<name>_clean.prep.json` |
| **2. Retarget** | `tools/blender-dev/retarget_to_cc0_rig.py` | `<name>_clean.glb` + `UAL1_Standard.glb` | `<name>_rigged.glb`, `<name>_rigged.retarget.json` |
| **3. Preview** | `tools/blender-dev/render_preview.py` | any `.glb`/`.fbx` | `<name>_{front,side,three_quarter}.png` |
| **4. Inspect** | `tools/blender-dev/inspect_glb.py` | any `.glb`/`.fbx` | `<name>.inspect.json` |
| **5. Validate** | `godot/tools/validate_rigged_glb.gd` | imported `<name>_rigged.glb` | `<name>_rigged.validate.json` + stdout PASS/FAIL |

All scripts are headless-safe (`--background` / `--headless`) and must be invokable without opening an app GUI.

## Where files live

```text
design/charcters/3d/                              ← source + intermediate artifacts (not shipped)
  cc0_source/Universal Animation Library[Standard]/Unreal-Godot/
    UAL1_Standard.glb                             ← 65-bone humanoid + 45 actions
  <name>_clean.glb / .fbx / .prep.json            ← post-strip intermediate
  preview/<name>_{front,side,3q}.png              ← pre-rig preview
  preview_rigged/<name>_rigged_{...}.png          ← post-rig preview
  preview_source/UAL1_Standard_{...}.png          ← reference source preview

godot/assets/characters/crew/                     ← shipped, imported by Godot
  <name>_rigged.glb                               ← the deliverable
  <name>_rigged.glb.import                        ← Godot import settings
  <name>_rigged.retarget.json                     ← retarget report
  <name>_rigged.validate.json                     ← validation report

tools/blender-dev/                                ← Python scripts (Blender 4.6+)
godot/tools/validate_rigged_glb.gd                ← SceneTree validator

logs/                                             ← runtime logs from pipeline runs
  strip_prep.log, retarget.log, preview_render.log, rigged_glb_validate.log
```

Note: `design/charcters/` is the historical spelling (typo kept stable to avoid invalidating every asset reference in code / `.import` UIDs).

## Environment

- **Blender:** `/Applications/Blender.app/Contents/MacOS/Blender` (tested on 5.1.1 — anything ≥ 4.2 should work).
- **Godot:** `/Applications/Godot.app/Contents/MacOS/Godot` (4.6.1 stable).
- **Source armature:** `design/charcters/3d/cc0_source/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb` (CC0, vendored, do not delete). 65 bones, 45 actions, T-pose rest pose.

No Python venv required — all scripts run under Blender's bundled Python via `--python`.

## Full workflow for a new character

Concrete example: adding a new crew member called `silky`. Input asset is `godot/assets/characters/crew/silky_raw.glb` (Tripo3D output with broken auto-rig).

### Step 1 — Strip and prep the mesh

```bash
mkdir -p logs
/Applications/Blender.app/Contents/MacOS/Blender --background --python \
  tools/blender-dev/strip_and_prep_for_mixamo.py -- \
  godot/assets/characters/crew/silky_raw.glb \
  design/charcters/3d/silky_clean \
  2>&1 | tee logs/strip_prep.log
```

Produces `silky_clean.glb`, `silky_clean.fbx`, and `silky_clean.prep.json`. The clean mesh has: no actions, no NLA, no armature modifier, no vertex groups, no ARMATURE object, and is frozen in the original rig's rest pose.

**Sanity check the report:**

- `anim_purge.actions_removed` ≥ 1 (Tripo3D always bakes at least one action)
- `post_cleanup.remaining_actions == 0`
- `post_cleanup.remaining_armatures == 0`
- `post_cleanup.remaining_meshes` has one mesh with non-trivial `vertex_count`

### Step 2 — Render pre-rig preview (optional but recommended)

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python \
  tools/blender-dev/render_preview.py -- \
  design/charcters/3d/silky_clean.glb \
  design/charcters/3d/preview \
  1024 \
  2>&1 | tee logs/preview_render.log
```

Compare to `design/charcters/3d/preview_source/UAL1_Standard_front.png` — the mesh should be roughly humanoid, standing on origin, facing camera. If it isn't, the retarget won't align correctly.

### Step 3 — Retarget onto the CC0 UAL armature

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python \
  tools/blender-dev/retarget_to_cc0_rig.py -- \
  "design/charcters/3d/cc0_source/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb" \
  design/charcters/3d/silky_clean.glb \
  godot/assets/characters/crew/silky_rigged.glb \
  2>&1 | tee logs/retarget.log
```

Optional flag: `--rotate-z=<degrees>` if the clean mesh faces a direction other than +Y (test with step 2 first).

What the script does, in order:

1. Import UAL source (armature + Mannequin mesh + 45 actions).
2. **Force source armature to REST pose** (critical — without this the mesh is deformed by frame 1 of the default action, which breaks both bbox alignment and weight transfer).
3. Import target mesh (`silky_clean.glb`).
4. Align target: scale to match source Z-extent, ground-align feet, center X/Y, apply optional Z rotation.
5. Copy vertex-group names from source mesh to target mesh (empty groups).
6. Run Blender's Data Transfer modifier (`POLYINTERP_NEAREST`, `VGROUP_WEIGHTS`) to transfer skin weights from the UAL mannequin → target mesh.
7. Delete source mesh.
8. Parent target mesh to source armature + add `ARMATURE` modifier (top of stack).
9. Restore POSE mode so animations drive the export.
10. Push every action onto NLA tracks (one track per action) — required for Godot's glTF importer to see them as named clips.
11. Export single GLB.

**Sanity check `silky_rigged.retarget.json`:**

- `source_vertex_group_count == 65` (all UAL bones weighted)
- `target_vertex_groups_after == 65` (all transferred)
- `animation_count == 45`
- `alignment.scale_factor` is finite and > 0.1 (Tripo3D meshes usually come in at 1.0 height, so scale lands near 2.8)
- `alignment.src_height` is close to the UAL reference value of **2.8292 m** — if it prints ~2.0 m the REST-pose fix has regressed (`_force_rest_pose` is not running early enough)

### Step 4 — Render post-rig preview

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python \
  tools/blender-dev/render_preview.py -- \
  godot/assets/characters/crew/silky_rigged.glb \
  design/charcters/3d/preview_rigged \
  1024 \
  2>&1 | tee -a logs/preview_render.log
```

Expect: character standing upright in A-pose (arms down-and-slightly-out), hat / coat / tail following the pose. If arms are pointing forward the REST pose fix has regressed (Blender evaluated the mesh against frame 1 of the first action).

### Step 5 — Headless Godot validation

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
  --script res://tools/validate_rigged_glb.gd \
  -- res://assets/characters/crew/silky_rigged.glb \
  2>&1 | tee logs/rigged_glb_validate.log
```

Exit code 0 = PASS, 1 = FAIL. The script loads the imported `PackedScene`, walks the tree, and asserts:

- At least one `Skeleton3D` with non-zero bone count (expect **65**).
- At least one `MeshInstance3D` with a valid `Skin` resource (so bones actually deform geometry).
- Every animation in `EXPECTED_ANIMS` (45 clips) is present, has length > 0, has at least one track, and has the correct `loop_mode`.
- `A_TPose`, `Idle`, `Walk`, `Sword_Attack`, `Death01` all call `play()` + `advance()` without runtime error.

The report is written to `godot/assets/characters/crew/silky_rigged.validate.json` with per-animation length / track count / loop mode.

### Step 6 — Commit

Everything in one logical commit:

```text
tools/blender-dev/*.py                                (if new or modified)
design/charcters/3d/cc0_source/                       (vendored once; skip on subsequent commits)
design/charcters/3d/silky_clean.glb / .fbx / .prep.json
design/charcters/3d/preview/silky_clean_*.png
design/charcters/3d/preview_rigged/silky_rigged_*.png
godot/assets/characters/crew/silky_rigged.glb
godot/assets/characters/crew/silky_rigged.glb.import
godot/assets/characters/crew/silky_rigged.retarget.json
godot/assets/characters/crew/silky_rigged.validate.json
logs/*.log
```

## The animation set (post-import)

All 45 UAL clips, as they appear in Godot's `AnimationPlayer` after glTF import (see §Gotchas — `_Loop` stripping):

| Loops (`loop_mode=1`) | One-shots (`loop_mode=0`) |
| --- | --- |
| `Idle`, `Idle_Talking`, `Idle_Torch` | `A_TPose`, `Death01`, `Interact` |
| `Walk`, `Walk_Formal`, `Jog_Fwd`, `Sprint` | `Jump_Land`, `Jump_Start`, `Fixing_Kneeling`, `PickUp_Table` |
| `Jump`, `Crouch_Idle`, `Crouch_Fwd` | `Roll`, `Roll_RM` |
| `Sitting_Idle`, `Sitting_Talking` | `Sitting_Enter`, `Sitting_Exit` |
| `Spell_Simple_Idle`, `Push`, `Driving`, `Dance` | `Spell_Simple_Enter`, `Spell_Simple_Exit`, `Spell_Simple_Shoot` |
| `Swim_Idle`, `Swim_Fwd`, `Pistol_Idle` | `Hit_Chest`, `Hit_Head` |
| | `Pistol_Aim_Down`, `Pistol_Aim_Neutral`, `Pistol_Aim_Up`, `Pistol_Reload`, `Pistol_Shoot` |
| | `Punch_Cross`, `Punch_Jab` |
| | `Sword_Attack`, `Sword_Attack_RM`, `Sword_Idle` |

Gameplay code calls e.g. `ap.play("Walk")` — **not** `Walk_Loop`.

## Using the rigged character in a Godot scene

Minimal usage pattern:

```gdscript
const SILKY_GLB := preload("res://assets/characters/crew/silky_rigged.glb")

func _spawn_silky() -> Node3D:
    var inst: Node3D = SILKY_GLB.instantiate()
    add_child(inst)

    var ap: AnimationPlayer = inst.get_node("AnimationPlayer") as AnimationPlayer
    ap.play("Idle")     # auto-loops; loop_mode was set at import time
    return inst
```

Bone names follow the UAL convention (e.g. `Hips`, `Spine`, `Head`, `LeftHand`, `RightHand`). If you need a weapon or prop attached to a bone, use a `BoneAttachment3D` under the `Skeleton3D`:

```gdscript
var ba := BoneAttachment3D.new()
ba.bone_name = "RightHand"
skeleton.add_child(ba)
ba.add_child(weapon_mesh)
```

## Gotchas and known quirks

### Godot strips `_Loop` suffix on import

Godot's glTF importer (`gltf/naming_version=2`, the default) automatically:

- Strips any trailing `_Loop` from animation names.
- Sets `loop_mode = LINEAR` on those clips.

So the retarget script pushes `Walk_Loop` / `Idle_Loop` / `Sprint_Loop` to NLA, but Godot surfaces them as `Walk` / `Idle` / `Sprint`. **Gameplay code must reference the stripped names.** `validate_rigged_glb.gd` already knows this — its `EXPECTED_ANIMS` uses the post-strip names. See also `docs/GODOT_NOTES.md` §Godot glTF `_Loop` suffix stripping.

### REST pose vs. POSE pose — the fix that unblocked the pipeline

When `retarget_to_cc0_rig.py` imports the UAL source, the armature comes in with its first action assigned and Blender's depsgraph evaluates the mesh at frame 1 → the mannequin appears with arms forward. Any operation that reads the *evaluated* mesh (`obj.bound_box`, weight proximity lookup, mesh geometry sampling) then reads deformed geometry:

- Z-extent reads ~2.0 m instead of 2.8292 m → target mesh scaled too small.
- `POLYINTERP_NEAREST` data transfer picks wrong source polys for each target vertex → skin weights land on the wrong bones → the rigged mesh either T-poses, crumples, or tears at transitions.

Fix (already shipped in the script):

1. `_force_rest_pose(src_arm)` sets `armature.data.pose_position = "REST"` AND clears any assigned action, then runs `bpy.context.view_layer.update()` to flush the depsgraph.
2. Called **before** any bbox read or data transfer.
3. `_restore_pose_mode(src_arm)` flips back to POSE mode before the NLA push + GLB export, so animations drive the armature on export.

Regression symptom: preview renders show arms forward or body warped, and `retarget.json` reports `src_height` near 2.0 instead of 2.8.

### `design/charcters/` spelling

Yes, it's missing an `a`. No, don't rename it — every `.import` UID, asset path, and JSON reference already points at the misspelled directory, and Godot re-imports any renamed asset (invalidating the UIDs) on next open. Leave it.

### Mixamo is still available as fallback

If UAL's 65-bone humanoid cannot rig a given mesh (non-humanoid crew, winged factions, oversized heads), use the Mixamo path documented in `tools/blender-dev/README.md` §Fallback path — Mixamo. That path uses `strip_and_prep_for_mixamo.py` → upload to mixamo.com → download FBX animations → `merge_mixamo_animations.py`. UAL is preferred because it is fully offline and reproducible.

### Tail / fingers / other bones UAL doesn't know about

UAL has no tail chain and no per-finger bones. For cat / fox crew, the mesh's tail ends up rigidly skinned to the nearest spine bone (rigid tail, no wag). If per-bone tail animation is required, options are:

- Add a tail bone chain in Blender post-retarget (before NLA push), paint weights manually, author a tail `Action`, push it to NLA alongside UAL's 45 clips, re-export.
- Keep the rigid tail and accept it for v1 crew.

Per-finger fidelity is not achievable with UAL — hands are one-bone. Accept closed-fist fidelity for all UAL-rigged characters.

## Character roster status

Tracker for which characters have been through this pipeline. Update on every run.

| Character | `_raw.glb` source | `_clean` | `_rigged` | Validated | Notes |
| --------- | ----------------- | -------- | --------- | --------- | ----- |
| Nine Lives | `godot/assets/characters/crew/nine_live_walking.glb` | ✅ 2026-04-17 | ✅ 2026-04-17 (44 MB, 65 bones, 45 anims) | ✅ PASS 2026-04-17 | Rigid tail (UAL limitation); rest-pose fix required |
| Aristotle | `design/charcters/3d/aristotle_3d.glb` | — | — | — | Pending |
| Dave | `design/charcters/3d/dave_3d.glb` | — | — | — | Pending |
| No Tail | `design/charcters/3d/no_tail_3d.glb` | — | — | — | Pending; rigless tail should be a non-issue |

## Related references

- `tools/blender-dev/README.md` — per-script reference + Mixamo fallback path.
- `docs/GODOT_NOTES.md` — engine-level quirks including glTF `_Loop` stripping.
- `docs/GODOT_DEV_GUIDE.md` — broader tool index.
- `docs/STRUCTURE.md` — how character / crew systems wire into the game.
- CC0 UAL license: `design/charcters/3d/cc0_source/Universal Animation Library[Standard]/License.txt`.
