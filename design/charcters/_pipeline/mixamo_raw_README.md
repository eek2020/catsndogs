# Mixamo raw download staging

Drop animation FBX downloads from [mixamo.com](https://www.mixamo.com) here,
grouped by character. One FBX per animation. Keep filenames short and
matching the gameplay animation name we want to surface in Godot — the merge
script uses the filename stem as the action name.

## Directory layout

```
mixamo_raw/
  aristotle/
    Idle.fbx
    Walk.fbx
    Run.fbx
    Jump.fbx
    Sprint.fbx
    ...
  nine_lives/
    Idle.fbx
    ...
```

## Mixamo download settings

For the **primary** file (the T-pose or first animation):
- **Format:** FBX Binary (.fbx), 7.4 or 7.5
- **Skin:** With Skin (we need the mesh once)
- **Frames per Second:** 30
- **Keyframe Reduction:** none

For **additional** animations (after you have one file with skin):
- **Format:** FBX Binary
- **Skin:** **Without Skin** (saves size, we only want the action)
- Same 30 FPS, no keyframe reduction

The auto-rigged T-pose itself (already at
`design/charcters/3d/aristotle_t_pose_3d.fbx`) can serve as the primary.

## Minimum animation set the game currently expects

From `@scripts/characters/animation_preview_controller.gd` the rotation set
used for 3D previews is:

- `Idle`
- `Walk`
- `Run`
- `Jump`
- `Sprint`

Additional useful ones (optional, not yet wired to gameplay): `Fall`,
`Death`, `Sword_Attack`, `Punch`, `Pistol_Shoot`, `Interact`, `Sitting_Idle`.

## Producing the merged rigged GLB

Example for Aristotle, using the existing T-pose as primary:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python \
  tools/blender-dev/merge_mixamo_animations.py -- \
  godot/assets/characters/crew/aristotle_rigged.glb \
  design/charcters/3d/aristotle_t_pose_3d.fbx A_TPose \
  design/charcters/3d/mixamo_raw/aristotle/Idle.fbx Idle \
  design/charcters/3d/mixamo_raw/aristotle/Walk.fbx Walk \
  design/charcters/3d/mixamo_raw/aristotle/Run.fbx Run \
  design/charcters/3d/mixamo_raw/aristotle/Jump.fbx Jump \
  design/charcters/3d/mixamo_raw/aristotle/Sprint.fbx Sprint
```

Same pattern for Nine Lives once you have the auto-rigged T-pose FBX back
from Mixamo.

## Note on bone names

Mixamo exports bones as `mixamorig:Hips`, `mixamorig:Spine`, etc. Godot's
glTF importer handles the prefix fine but the names in the AnimationPlayer
will carry it. The merge script does not strip the prefix — that's the
exporter's job and we leave it intact so tools like `retarget_bone_map` can
still find the bones if we want to retarget later.
