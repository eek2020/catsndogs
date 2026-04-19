"""
setup_scene.py — Whisper Crystals cutscene style test
======================================================
Reproducibly builds a Blender scene that renders Dave's idle animation in
the target painterly / toon-shaded look for the game's cutscenes.

Re-run this from a fresh Blender session (or `blender --python setup_scene.py`)
to rebuild the scene end-to-end. All key knobs live in CONFIG below.

Blender target: 5.1.x (Eevee). Reference: `design/charcters/dave/2d/dave_t_pose.png`.

UK English in comments.
"""

from __future__ import annotations

import math
import os
from pathlib import Path

import bpy  # noqa: F401  — provided by Blender runtime


# --------------------------------------------------------------------------
# CONFIG — tweak these between renders, then re-run the script.
# --------------------------------------------------------------------------

# Project-relative asset paths (resolved against this file's parent dir).
REPO_ROOT = Path("/Users/erichook-marshall/Downloads/Code/git/catsndogs")
DAVE_BASE_FBX = REPO_ROOT / "design/charcters/dave/3d/dave_t_pose_3d_baseline.fbx"
DAVE_IDLE_FBX = REPO_ROOT / "design/charcters/dave/3d/animations/dave_anim_idle.fbx"

OUTPUT_ROOT = REPO_ROOT / "cutscene_pipeline"
RENDER_DIR = OUTPUT_ROOT / "renders" / "preview"
BLEND_PATH = OUTPUT_ROOT / "blender" / "cutscene_scene.blend"

# Render settings.
RES_X, RES_Y = 1920, 1080
FPS = 24
# Scene duration in seconds — we'll clamp to the idle action's actual length.
MAX_DURATION_S = 5.0

# Camera: medium shot, slight 3/4 angle, subtle dolly-in.
# Dave's mesh reaches ~1m tall with head near z=1.0, shoulders ~0.75.
# Camera pulled in close enough that a waist-up composition fills the frame.
CAMERA_START = (0.55, -1.15, 0.85)   # 3/4 angle right, low-forward, roughly chest height
CAMERA_END = (0.48, -1.02, 0.85)     # gentle dolly toward subject
CAMERA_TARGET = (0.0, 0.1, 0.78)     # Dave's upper chest / shoulders
CAMERA_LENS_MM = 50.0                # slightly wider for a 3/4 shot without distortion

# Lighting — tuned for cel-shading, not realism.
KEY_LIGHT_POWER = 1500.0           # warm key from upper-front-right (hard cel lighting wants contrast)
KEY_LIGHT_COLOUR = (1.0, 0.94, 0.85)
FILL_LIGHT_POWER = 250.0           # cool fill from left
FILL_LIGHT_COLOUR = (0.78, 0.86, 1.0)
RIM_LIGHT_POWER = 1000.0           # warm rim from behind for silhouette bleed
RIM_LIGHT_COLOUR = (1.0, 0.82, 0.6)

# World / background.
WORLD_COLOUR = (0.42, 0.40, 0.38)  # neutral warm mid-grey

# Toon shader.
TOON_BANDS = 3                     # number of shading steps (2–3 recommended)
TOON_SHADOW_TINT = (0.35, 0.30, 0.45)  # cool purple tint in shadow band
TOON_RIM_STRENGTH = 0.35           # fake rim bleed at silhouette

# Outlines — classic Solidify backface trick (engine-agnostic, works on Eevee 5.x
# where Freestyle is silently unsupported). A Solidify modifier extrudes a thin
# shell along flipped normals; the shell uses an unlit dark material so only its
# back faces are visible against the camera, producing a uniform silhouette line.
OUTLINE_ENABLE = True
OUTLINE_THICKNESS_M = 0.006   # extrude distance (metres). ~0.5% of character height.
OUTLINE_COLOUR = (0.08, 0.05, 0.04)  # dark warm brown-black, not pure black

# Compositor.
PAPER_TEXTURE_STRENGTH = 0.08      # 0–1; 5–10% overlay
FILM_GRAIN_STRENGTH = 0.015        # ~1–2% noise
VIGNETTE_STRENGTH = 0.12           # 0–1


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def _clear_scene() -> None:
    """Wipe default scene objects so we start fresh."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    # Drop orphan data too.
    for block in (
        list(bpy.data.meshes)
        + list(bpy.data.materials)
        + list(bpy.data.lights)
        + list(bpy.data.cameras)
        + list(bpy.data.armatures)
        + list(bpy.data.actions)
        + list(bpy.data.images)
    ):
        try:
            block.user_clear()
            # Remove via the appropriate collection.
        except Exception:
            pass


def _import_fbx(path: Path) -> list:
    """Import an FBX, return the set of newly-added objects."""
    before = set(bpy.data.objects)
    # Blender 5.x: bundled FBX importer is via bpy.ops.wm.obj / fbx; fbx_io addon
    # is enabled by default. Embedded textures are extracted automatically.
    bpy.ops.import_scene.fbx(filepath=str(path))
    after = set(bpy.data.objects)
    return list(after - before)


def _find_armature(objs: list):
    for o in objs:
        if o.type == "ARMATURE":
            return o
    return None


def _find_meshes(objs: list) -> list:
    return [o for o in objs if o.type == "MESH"]


# --------------------------------------------------------------------------
# Scene build
# --------------------------------------------------------------------------

def build_scene() -> dict:
    """Build the full scene from scratch. Returns refs to key objects."""
    print("[setup] Clearing default scene")
    _clear_scene()

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = RES_X
    scene.render.resolution_y = RES_Y
    scene.render.fps = FPS
    scene.unit_settings.system = "METRIC"

    # World background — neutral warm grey for now.
    world = bpy.data.worlds.new("CutsceneWorld") if "CutsceneWorld" not in bpy.data.worlds else bpy.data.worlds["CutsceneWorld"]
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (*WORLD_COLOUR, 1.0)
        bg.inputs[1].default_value = 1.0

    # Import Dave base rig.
    print(f"[setup] Importing base FBX: {DAVE_BASE_FBX}")
    base_objs = _import_fbx(DAVE_BASE_FBX)
    base_armature = _find_armature(base_objs)
    base_meshes = _find_meshes(base_objs)
    print(f"[setup]  armature={base_armature.name if base_armature else None}, meshes={[m.name for m in base_meshes]}")

    # Import idle animation: we want the Action applied to base_armature.
    print(f"[setup] Importing idle animation FBX: {DAVE_IDLE_FBX}")
    anim_objs = _import_fbx(DAVE_IDLE_FBX)
    anim_armature = _find_armature(anim_objs)

    if base_armature and anim_armature and anim_armature.animation_data and anim_armature.animation_data.action:
        action = anim_armature.animation_data.action
        print(f"[setup]  transferring action '{action.name}' onto base armature")
        if not base_armature.animation_data:
            base_armature.animation_data_create()
        base_armature.animation_data.action = action
        # Delete the duplicate anim-import objects (armature + any placeholder mesh).
        for o in anim_objs:
            try:
                bpy.data.objects.remove(o, do_unlink=True)
            except Exception:
                pass

    # Clamp scene frame range to idle loop length.
    if base_armature and base_armature.animation_data and base_armature.animation_data.action:
        action = base_armature.animation_data.action
        fr_start, fr_end = int(action.frame_range[0]), int(action.frame_range[1])
    else:
        fr_start, fr_end = 1, int(FPS * MAX_DURATION_S)
    # Cap to MAX_DURATION_S to avoid multi-minute renders if the action is long.
    fr_end = min(fr_end, fr_start + int(FPS * MAX_DURATION_S) - 1)
    scene.frame_start = fr_start
    scene.frame_end = fr_end
    print(f"[setup] Frame range: {fr_start}..{fr_end} @ {FPS}fps")

    # Camera.
    cam_data = bpy.data.cameras.new("CutsceneCam")
    cam_data.lens = CAMERA_LENS_MM
    cam = bpy.data.objects.new("CutsceneCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = CAMERA_START
    # Aim with a Track To constraint against an empty at target.
    target = bpy.data.objects.new("CamTarget", None)
    target.location = CAMERA_TARGET
    scene.collection.objects.link(target)
    tt = cam.constraints.new("TRACK_TO")
    tt.target = target
    tt.track_axis = "TRACK_NEGATIVE_Z"
    tt.up_axis = "UP_Y"
    scene.camera = cam

    # Dolly keyframes.
    cam.keyframe_insert("location", frame=fr_start)
    cam.location = CAMERA_END
    cam.keyframe_insert("location", frame=fr_end)

    # 3-point lights.
    def add_light(name, loc, power, colour, light_type="AREA", size=2.0):
        ld = bpy.data.lights.new(name, type=light_type)
        ld.energy = power
        ld.color = colour
        if light_type == "AREA":
            ld.size = size
        ob = bpy.data.objects.new(name, ld)
        ob.location = loc
        scene.collection.objects.link(ob)
        # Point roughly at origin/chest.
        tt_l = ob.constraints.new("TRACK_TO")
        tgt = bpy.data.objects.new(f"{name}_tgt", None)
        tgt.location = (0, 0, 1.15)
        scene.collection.objects.link(tgt)
        tt_l.target = tgt
        tt_l.track_axis = "TRACK_NEGATIVE_Z"
        tt_l.up_axis = "UP_Y"
        return ob

    add_light("KeyLight", (2.5, -2.0, 3.0), KEY_LIGHT_POWER, KEY_LIGHT_COLOUR, size=2.5)
    add_light("FillLight", (-2.5, -1.0, 2.0), FILL_LIGHT_POWER, FILL_LIGHT_COLOUR, size=3.0)
    add_light("RimLight", (-0.5, 2.8, 2.8), RIM_LIGHT_POWER, RIM_LIGHT_COLOUR, size=2.0)

    # Apply toon shader to Dave meshes.
    for mesh_obj in base_meshes:
        for slot in mesh_obj.material_slots:
            if slot.material:
                _convert_to_toon(slot.material)

    # Outlines — Solidify backface shell (engine-agnostic).
    if OUTLINE_ENABLE:
        for mesh_obj in base_meshes:
            _apply_solidify_outline(mesh_obj)

    # Compositor.
    _setup_compositor(scene)

    # Output settings.
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(RENDER_DIR) + "/frame_"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False

    return {
        "armature": base_armature,
        "meshes": base_meshes,
        "camera": cam,
        "frame_start": fr_start,
        "frame_end": fr_end,
    }


# --------------------------------------------------------------------------
# Toon shader — minimal hand-rolled node group.
# Approach credit: standard Blender community pattern (Diffuse BSDF ->
# ShaderToRGB -> ColorRamp with constant interpolation to band, then multiply
# with base colour). Widely documented e.g. on Blender Stack Exchange.
# --------------------------------------------------------------------------

def _convert_to_toon(mat) -> None:
    """Rewrite a material's node tree to a banded toon shader that keeps base colour."""
    mat.use_nodes = True
    nt = mat.node_tree
    nodes = nt.nodes
    links = nt.links

    # Find base colour image (from FBX import) if any.
    base_image = None
    for n in nodes:
        if n.type == "TEX_IMAGE" and n.image:
            base_image = n.image
            break

    # Nuke existing nodes, rebuild.
    for n in list(nodes):
        nodes.remove(n)

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (800, 0)

    # Diffuse shader — drives the lighting term.
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    diffuse.location = (-400, 200)
    diffuse.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)

    shader_to_rgb = nodes.new("ShaderNodeShaderToRGB")
    shader_to_rgb.location = (-200, 200)
    links.new(diffuse.outputs["BSDF"], shader_to_rgb.inputs["Shader"])

    # Band the lighting via a ColorRamp with constant interpolation.
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.location = (0, 200)
    ramp.color_ramp.interpolation = "CONSTANT"
    # Clear default stops and rebuild with TOON_BANDS bands.
    cr = ramp.color_ramp
    while len(cr.elements) > 1:
        cr.elements.remove(cr.elements[-1])
    cr.elements[0].position = 0.0
    cr.elements[0].color = (*TOON_SHADOW_TINT, 1.0)
    # Intermediate bands between shadow tint (dark) and white (lit).
    for i in range(1, TOON_BANDS):
        t = i / TOON_BANDS
        el = cr.elements.new(t)
        # Interpolate linearly from shadow tint to white.
        col = tuple(TOON_SHADOW_TINT[k] + (1.0 - TOON_SHADOW_TINT[k]) * t for k in range(3))
        el.color = (*col, 1.0)
    links.new(shader_to_rgb.outputs["Color"], ramp.inputs["Fac"])

    # Base colour source: texture if available, otherwise a plain colour.
    if base_image:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = base_image
        tex.location = (-400, -100)
        base_out = tex.outputs["Color"]
    else:
        rgb = nodes.new("ShaderNodeRGB")
        rgb.location = (-400, -100)
        rgb.outputs["Color"].default_value = (0.78, 0.55, 0.35, 1.0)
        base_out = rgb.outputs["Color"]

    # Multiply lighting band × base colour.
    mul = nodes.new("ShaderNodeMixRGB")
    mul.location = (250, 50)
    mul.blend_type = "MULTIPLY"
    mul.inputs["Fac"].default_value = 1.0
    links.new(ramp.outputs["Color"], mul.inputs["Color1"])
    links.new(base_out, mul.inputs["Color2"])

    # Fake rim bleed — Fresnel masked additive warm tint.
    fres = nodes.new("ShaderNodeFresnel")
    fres.location = (0, -250)
    fres.inputs["IOR"].default_value = 1.45
    rim_col = nodes.new("ShaderNodeRGB")
    rim_col.location = (0, -400)
    rim_col.outputs["Color"].default_value = (1.0, 0.78, 0.55, 1.0)
    rim_mix = nodes.new("ShaderNodeMixRGB")
    rim_mix.location = (450, -100)
    rim_mix.blend_type = "ADD"
    rim_mix.inputs["Fac"].default_value = TOON_RIM_STRENGTH
    links.new(mul.outputs["Color"], rim_mix.inputs["Color1"])
    links.new(rim_col.outputs["Color"], rim_mix.inputs["Color2"])
    # Mask add by fresnel.
    rim_mask = nodes.new("ShaderNodeMath")
    rim_mask.location = (250, -250)
    rim_mask.operation = "MULTIPLY"
    rim_mask.inputs[1].default_value = TOON_RIM_STRENGTH
    links.new(fres.outputs["Fac"], rim_mask.inputs[0])
    links.new(rim_mask.outputs["Value"], rim_mix.inputs["Fac"])

    # Emission shader so we bypass further lighting (we've already baked it in).
    emit = nodes.new("ShaderNodeEmission")
    emit.location = (650, 0)
    links.new(rim_mix.outputs["Color"], emit.inputs["Color"])
    links.new(emit.outputs["Emission"], out.inputs["Surface"])


# --------------------------------------------------------------------------
# Solidify backface outline — standard cel-outline trick.
#
# Credit: widely-documented technique (e.g. Blender Secrets / Dillon Goo Studios
# cel-shading tutorials). The shell material is unlit dark colour with Backface
# Culling OFF; we flip the Solidify shell's normals so from the camera's
# perspective only the far side of the shell is visible, forming an outline.
# --------------------------------------------------------------------------

def _apply_solidify_outline(mesh_obj) -> None:
    """Add an outline material slot + Solidify modifier to produce cel outlines."""
    # Outline material — unlit dark warm-black.
    mat_name = "ToonOutlineMat"
    outline_mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
    outline_mat.use_nodes = True
    nt = outline_mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*OUTLINE_COLOUR, 1.0)
    emit.inputs["Strength"].default_value = 1.0
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    # Backface culling MUST be on for the flipped-normals trick to work:
    # the shell faces nearest the camera have their normals pointing away (after
    # flipping) and get culled, leaving only the far-side shell visible — which
    # is Z-occluded by the original mesh except at the silhouette rim.
    try:
        outline_mat.use_backface_culling = True
        # Eevee Next also has a surface_render_method / shadow settings; defaults fine.
    except Exception:
        pass

    # Append outline material as a new slot and remember its index.
    if mat_name not in [s.name for s in mesh_obj.material_slots]:
        mesh_obj.data.materials.append(outline_mat)
    outline_slot_idx = [s.name for s in mesh_obj.material_slots].index(mat_name)

    # Solidify modifier — thin shell, flipped normals, pin to outline material slot.
    mod_name = "ToonOutline"
    mod = mesh_obj.modifiers.get(mod_name)
    if mod is None:
        mod = mesh_obj.modifiers.new(mod_name, type="SOLIDIFY")
    mod.thickness = OUTLINE_THICKNESS_M
    mod.offset = 1.0
    mod.use_flip_normals = True
    mod.use_rim = False
    mod.material_offset = outline_slot_idx   # shell uses the outline slot
    mod.material_offset_rim = outline_slot_idx
    # Keep the modifier after the armature deform so outlines follow animation.
    # Armature modifier is normally at index 0 on FBX imports; Solidify should come after.
    try:
        # Move Solidify to the end of the stack.
        while mesh_obj.modifiers[-1].name != mod_name:
            bpy.context.view_layer.objects.active = mesh_obj
            bpy.ops.object.modifier_move_down(modifier=mod_name)
    except Exception:
        pass


# --------------------------------------------------------------------------
# Compositor — paper overlay, grain, vignette, subtle grade.
# --------------------------------------------------------------------------

def _setup_compositor(scene) -> None:
    """
    Compositor pass — INTENTIONALLY STUBBED for v1.

    Blender 5.x shipped a rewritten compositor (different node tree location:
    `scene.compositing_node_group`; many classic nodes renamed/removed —
    no more CompositorNodeMixRGB, CompositorNodeMix, CompositorNodeComposite,
    CompositorNodeTexture; ColorBalance props became input sockets).

    The paper / grain / vignette polish layer is best re-added once we're
    happy with the base look — for this proof-of-concept the toon shader +
    Freestyle lines + warm world background already carry the aesthetic.

    Re-enable by wiring `CompositorNodeColorBalance`, `CompositorNodeGlare`,
    `CompositorNodeEllipseMask` -> `CompositorNodeBlur` via the new 5.x API.
    """
    return


# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------

def main() -> None:
    info = build_scene()
    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    print(f"[setup] Saved: {BLEND_PATH}")
    print(f"[setup] Frames {info['frame_start']}..{info['frame_end']} ready for render")


if __name__ == "__main__":
    main()
