"""
render_shots.py — multi-shot cutscene render for Whisper Crystals style test
============================================================================
Builds a small two-shot cutscene to prove the pipeline:

  Shot 1 (~2s):  Dave walks in, side-on camera, mid-distance.
  Shot 2 (~4s):  Cut to stylised 3/4 medium close-up — Dave idles, a
                 dialogue card fades in with a line of text.

The dialogue card is drawn as a textual overlay in ffmpeg (drawtext filter)
rather than inside Blender — it's easier to iterate on font/position/timing
outside the render, and keeps the Blender scene camera-only.

Assumes `setup_scene.py` has already built the base scene (armature, meshes,
toon shader, outlines, lights). This script:
  - swaps the armature Action between the walk/idle FBXs
  - re-poses the camera per shot
  - renders each shot to its own PNG sequence
"""

from __future__ import annotations

import math
import os
from pathlib import Path

import bpy


REPO_ROOT = Path("/Users/erichook-marshall/Downloads/Code/git/catsndogs")
ANIM_DIR = REPO_ROOT / "design/charcters/dave/3d/animations"
# Intermediate render dir — per-shot PNG sequences land here before being
# composited in ffmpeg and promoted to godot/assets/cutscenes/<id>/frames/.
RENDERS_ROOT = REPO_ROOT / "cutscene_pipeline/renders"

FPS = 24


# --------------------------------------------------------------------------
# Shot definitions — edit here to retime / reframe.
# --------------------------------------------------------------------------

SHOTS = [
    {
        "name": "shot1_walk",
        "anim_fbx": ANIM_DIR / "dave_anim_walk.fbx",
        "duration_s": 2.0,
        # The walk Mixamo clip has ROOT MOTION: Dave travels ~1m in -Y
        # across 30 frames. So we hold a static side-on camera and let
        # him walk through the frame from right (+Y) to left (-Y).
        # Camera is offset in +X so we see his right side in 3/4.
        "camera_start": (2.6, -0.3, 0.95),
        "camera_end":   (2.6, -0.3, 0.95),   # static camera
        "camera_target": (0.0, -0.3, 0.55),  # aim at Dave's midpoint along his walk
        "lens_mm": 40.0,                     # wider to keep him in frame throughout
    },
    {
        "name": "shot2_idle_dialogue",
        "anim_fbx": ANIM_DIR / "dave_anim_idle.fbx",
        "duration_s": 4.75,   # extended past idle action length (4s) to give
                              # audio tail (3.32s starting at 0.2s into shot) room
                              # to finish — we loop the action via fcurve CYCLES
                              # modifier in _apply_action below.
        # Stylised 3/4 close — same language as v1 preview but tighter.
        "camera_start": (0.50, -1.05, 0.88),
        "camera_end":   (0.45, -0.95, 0.88),
        "camera_target": (0.0, 0.12, 0.80),
        "lens_mm": 55.0,
        # Audio-driven head wag. Envelope starts at shot-local frame AUDIO_OFFSET
        # (audio begins ~0.20s into shot 2 = ~5 frames in at 24fps).
        # Head-wag DISABLED — the head jittering while the mouth stayed static
        # read as "nodding along" rather than "speaking." Mouth animation is
        # handled in Godot via a 2D overlay sprite driven from an external
        # mouth-shape timeline (see build_mouth_timeline.py).
    },
]


# --------------------------------------------------------------------------

def _get_armature() -> bpy.types.Object:
    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            return o
    raise RuntimeError("No armature found — run setup_scene.py first")


def _get_camera() -> bpy.types.Object:
    return bpy.data.objects["CutsceneCam"]


def _get_cam_target() -> bpy.types.Object:
    return bpy.data.objects["CamTarget"]


def _load_action_from_fbx(fbx_path: Path) -> bpy.types.Action:
    """Import an FBX solely to harvest its Action, then bin the extra objects."""
    before_actions = set(bpy.data.actions)
    before_objs = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(fbx_path))
    new_actions = list(set(bpy.data.actions) - before_actions)
    new_objs = list(set(bpy.data.objects) - before_objs)

    # The Action we want will be attached to the newly-imported armature.
    action = None
    for o in new_objs:
        if o.type == "ARMATURE" and o.animation_data and o.animation_data.action:
            action = o.animation_data.action
            break
    if action is None and new_actions:
        action = new_actions[0]

    # Delete the disposable import objects (keep the Action datablock).
    for o in new_objs:
        try:
            bpy.data.objects.remove(o, do_unlink=True)
        except Exception:
            pass

    if action is None:
        raise RuntimeError(f"Could not extract Action from {fbx_path}")
    return action


def _apply_action(armature, action, cycle: bool = False) -> tuple[int, int]:
    if not armature.animation_data:
        armature.animation_data_create()
    armature.animation_data.action = action
    fr_start = int(action.frame_range[0])
    fr_end = int(action.frame_range[1])
    if cycle:
        # Add F-curve CYCLES modifier so the action loops indefinitely past its end.
        for layer in action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    for fc in cb.fcurves:
                        if not any(m.type == "CYCLES" for m in fc.modifiers):
                            fc.modifiers.new(type="CYCLES")
    return fr_start, fr_end


def _pose_camera(shot: dict, frame_start: int, frame_end: int) -> None:
    cam = _get_camera()
    tgt = _get_cam_target()
    cam.data.lens = shot["lens_mm"]
    tgt.location = shot["camera_target"]

    # Wipe any existing location keyframes.
    if cam.animation_data and cam.animation_data.action:
        # Detach so we don't accumulate keyframes across shots.
        cam.animation_data.action = None

    cam.location = shot["camera_start"]
    cam.keyframe_insert("location", frame=frame_start)
    cam.location = shot["camera_end"]
    cam.keyframe_insert("location", frame=frame_end)


def _compute_wav_envelope(wav_path: str, fps: int) -> list[float]:
    """Per-frame RMS envelope [0,1] from a mono WAV."""
    import wave, struct
    with wave.open(wav_path, "rb") as wf:
        n_channels = wf.getnchannels()
        rate = wf.getframerate()
        n_samples = wf.getnframes()
        raw = wf.readframes(n_samples)
    samples = struct.unpack(f"<{n_samples * n_channels}h", raw)
    if n_channels == 2:
        samples = [(samples[i] + samples[i+1]) * 0.5 for i in range(0, len(samples), 2)]
    samples = [s / 32768.0 for s in samples]
    dur = n_samples / rate
    n_vf = int(dur * fps)
    samples_per_vf = rate / fps
    env = []
    for i in range(n_vf):
        a, b = int(i * samples_per_vf), int((i+1) * samples_per_vf)
        chunk = samples[a:b]
        rms = (sum(x*x for x in chunk) / len(chunk)) ** 0.5 if chunk else 0.0
        env.append(rms)
    peak = max(env) or 1.0
    return [e / peak for e in env]


def _smooth_envelope(envelope: list[float], window: int) -> list[float]:
    """Centred moving-average smoothing to flatten per-syllable spikes."""
    if window <= 1:
        return envelope
    out = []
    half = window // 2
    for i in range(len(envelope)):
        lo = max(0, i - half)
        hi = min(len(envelope), i + half + 1)
        out.append(sum(envelope[lo:hi]) / (hi - lo))
    return out


def _apply_head_wag(armature, envelope: list[float], offset_frames: int,
                    wag_deg: float, shake_deg: float,
                    frame_start: int, frame_end: int,
                    smooth_window: int = 1,
                    base_nod_deg: float = 0.0, base_nod_hz: float = 0.5,
                    fps: int = 24) -> None:
    """Keyframe head bone rotation as (smoothed audio envelope) + (slow baseline nod)."""
    import math
    if not armature.animation_data or not armature.animation_data.action:
        return
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="POSE")
    head_bone = armature.pose.bones.get("mixamorig:Head")
    if head_bone is None:
        print("[render_shots] WARNING: no Head bone — skipping head wag")
        bpy.ops.object.mode_set(mode="OBJECT")
        return
    head_bone.rotation_mode = "XYZ"

    env_smooth = _smooth_envelope(envelope, smooth_window)

    for i in range(frame_end - frame_start + 1):
        video_frame = frame_start + i
        env_idx = i - offset_frames
        amp = env_smooth[env_idx] if 0 <= env_idx < len(env_smooth) else 0.0

        # Baseline sinusoidal nod — always present while "speaking" window is active.
        # Gate it by audio presence so it's flat before/after the line.
        speaking = 1.0 if (env_idx >= 0 and env_idx < len(env_smooth)) else 0.0
        t_s = i / fps
        base_nod = math.sin(2 * math.pi * base_nod_hz * t_s) * base_nod_deg * speaking

        # Small audio-reactive tilt on top.
        audio_tilt = wag_deg * amp

        nod_x = -math.radians(base_nod + audio_tilt)
        wobble_y = math.radians(shake_deg * amp * math.sin(2 * math.pi * 1.5 * t_s))

        head_bone.rotation_euler = (nod_x, wobble_y, 0.0)
        head_bone.keyframe_insert(data_path="rotation_euler", frame=video_frame)

    bpy.ops.object.mode_set(mode="OBJECT")


def _render_shot(shot: dict) -> Path:
    armature = _get_armature()
    print(f"\n[render_shots] === {shot['name']} ===")
    action = _load_action_from_fbx(shot["anim_fbx"])
    # Cycle actions shorter than the requested shot length so they loop.
    requested_frames = int(FPS * shot["duration_s"])
    fr_a_start, fr_a_end = _apply_action(armature, action, cycle=True)

    frames_to_render = requested_frames
    fr_end = fr_a_start + frames_to_render - 1

    scene = bpy.context.scene
    scene.frame_start = fr_a_start
    scene.frame_end = fr_end
    scene.render.fps = FPS

    _pose_camera(shot, fr_a_start, fr_end)

    # Optional: drive the head bone with the dialogue envelope for this shot.
    if shot.get("audio_wav"):
        envelope = _compute_wav_envelope(shot["audio_wav"], FPS)
        _apply_head_wag(
            armature,
            envelope,
            offset_frames=shot.get("audio_offset_frames", 0),
            wag_deg=shot.get("head_wag_strength_deg", 6.0),
            shake_deg=shot.get("jaw_shake_strength_deg", 2.0),
            frame_start=fr_a_start,
            frame_end=fr_end,
            smooth_window=shot.get("head_smooth_window", 1),
            base_nod_deg=shot.get("head_base_nod_deg", 0.0),
            base_nod_hz=shot.get("head_base_nod_hz", 0.5),
            fps=FPS,
        )

    out_dir = RENDERS_ROOT / shot["name"]
    out_dir.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(out_dir) + "/frame_"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_percentage = 100

    print(f"[render_shots]  action={action.name} frames={fr_a_start}..{fr_end} -> {out_dir}")
    import time
    t0 = time.time()
    bpy.ops.render.render(animation=True)
    print(f"[render_shots]  done in {time.time()-t0:.1f}s")
    return out_dir


def main() -> None:
    for shot in SHOTS:
        _render_shot(shot)


if __name__ == "__main__":
    main()
