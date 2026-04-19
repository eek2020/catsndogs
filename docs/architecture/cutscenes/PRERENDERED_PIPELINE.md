# Pre-rendered cutscene pipeline

The painterly / ink-outlined look the game targets (see `design/art_direction/`) is prohibitively expensive to render live in Godot's Forward+ renderer. For dialogue-heavy or visually rich moments, we bake the shot in Blender and play it back in-engine as a **PNG sequence + WAV** using `PreRenderedCutscenePlayer`.

This sits next to the existing realtime 3D flavour (`CutsceneManager`, used by `no_tail_outpost`) — they share the registry at `godot/data/cutscenes/_registry.json` and are selected by the `type` field (`realtime_3d` vs `prerendered`).

## When to use which

| Flavour | Good for | Cost |
|---|---|---|
| `realtime_3d` | Interactive scenes: dialogue choices, the player looking around, camera that responds to player state. | Needs a .glb, camera keyframes, dialogue JSON. Look constrained by what Eevee-in-Godot-compatibility can render. |
| `prerendered` | Linear moments: intros, outros, reveals, key story beats. Anything where the full painted look matters more than interactivity. | No interactivity past "skip". Render cost lives in your laptop at authoring time, not the player's at runtime. |

## End-to-end workflow

**Goal:** new cutscene ID `my_cutscene` playable via `CutsceneManager.start_cutscene("my_cutscene")`.

### 1. Plan the shots

Open `cutscene_pipeline/blender/render_shots.py`. The `SHOTS` list at the top defines each shot — animation FBX, duration in seconds, camera start/end + target, lens, optional audio-driven hooks. Duplicate `shot1_walk` / `shot2_idle_dialogue` as templates. Shot frames are rendered independently and concatenated in ffmpeg.

Rules of thumb:

- **Durations** should match the audio you intend to lay under. Factor in a `~0.3s` pause for the dialogue card to fade in and a `~0.5s` tail after the last word.
- **Static cameras** are cheap and read well. Use the `camera_start == camera_end` trick for shots where the subject has root motion.
- **Cycle the Mixamo action** for shots longer than the clip — `_apply_action(cycle=True)` is already wired. See `shot2_idle_dialogue` for a 4.75s shot built from a 4s idle clip.

### 2. Generate dialogue audio

For prototyping:

```bash
say -v Daniel -r 165 -o /tmp/line.aiff "Your line here."
ffmpeg -y -i /tmp/line.aiff -ac 1 -ar 48000 godot/assets/cutscenes/<id>/dialogue.wav
```

For shipping: replace with VO from the real cast. The ffmpeg filter graph that draws the dialogue card on top is hand-edited in `cutscene_pipeline/blender/_filter_cutscene.txt` — update speaker name and text there.

### 3. Render in Blender

From Blender (or Blender MCP):

```python
# Build the base scene (Dave imported, toon shader, outlines, lights).
exec(open("cutscene_pipeline/blender/setup_scene.py").read())

# Render every shot in the SHOTS list at full resolution.
import sys
sys.path.insert(0, "cutscene_pipeline/blender")
import render_shots
render_shots.main()
```

Per-shot PNG sequences land under `cutscene_pipeline/renders/<shot_name>/`. Each run clears and re-renders — cheap since Eevee is fast (~1s per frame at 1920×1080).

**Known gotcha (Blender 5.x):**
- Freestyle is silently dropped on Eevee Next. We use a **Solidify backface-shell** for outlines instead (`setup_scene.py:_apply_solidify_outline`).
- The compositor was rewritten (`scene.compositing_node_group` replaces `scene.node_tree`; many classic nodes removed). `setup_scene.py:_setup_compositor` is a stub for v1. Polish passes (paper, grain, vignette) happen in ffmpeg for now.

### 4. Composite shots + dialogue card

Stage the per-shot PNGs into a contiguous sequence, then run the ffmpeg filter graph:

```bash
# Stage (from repo root)
STAGE=cutscene_pipeline/renders/_stage
mkdir -p "$STAGE" && rm -f "$STAGE"/*.png
i=1
for shot in cutscene_pipeline/renders/shot1_walk cutscene_pipeline/renders/shot2_idle_dialogue; do
  for f in "$shot"/frame_*.png; do
    printf -v dest "%s/frame_%04d.png" "$STAGE" $i
    ln -sf "$(pwd)/$f" "$dest"; i=$((i+1))
  done
done

# Composite + downscale to half-res for lower memory. Output goes straight into
# the Godot project. The filter script draws the dialogue card.
cat cutscene_pipeline/blender/_filter_cutscene.txt > /tmp/filt.txt
printf ",\nscale=960:540\n" >> /tmp/filt.txt
rm -f godot/assets/cutscenes/<id>/frames/frame_*.png
ffmpeg -y -framerate 24 -i "$STAGE/frame_%04d.png" \
  -filter_complex_script /tmp/filt.txt \
  godot/assets/cutscenes/<id>/frames/frame_%04d.png

# Also produce an archive mp4 with audio for review outside Godot.
ffmpeg -y -framerate 24 -i "$STAGE/frame_%04d.png" \
  -filter_complex_script cutscene_pipeline/blender/_filter_cutscene.txt \
  -c:v libx264 -pix_fmt yuv420p -crf 18 cutscene_pipeline/renders/_mute.mp4
ffmpeg -y -i cutscene_pipeline/renders/_mute.mp4 -i godot/assets/cutscenes/<id>/dialogue.wav \
  -filter_complex "[1:a]adelay=1450|1450[a]" -map 0:v -map "[a]" \
  -c:v copy -c:a aac godot/assets/cutscenes/<id>/cutscene.mp4
rm cutscene_pipeline/renders/_mute.mp4
```

### 5. Register + scene

Add to `godot/data/cutscenes/_registry.json`:

```json
{
  "id": "my_cutscene",
  "type": "prerendered",
  "scene_path": "res://scenes/cutscenes/my_cutscene.tscn",
  "frames_dir": "res://assets/cutscenes/my_cutscene/frames",
  "dialogue_wav": "res://assets/cutscenes/my_cutscene/dialogue.wav",
  "fps": 24,
  "title": "...",
  "arc": "arc1",
  "tags": [],
  "notes": "..."
}
```

Create `godot/scenes/cutscenes/my_cutscene.tscn` that instances `res://scenes/cutscenes/prerendered_cutscene.tscn` and overrides the paths. See `dave_intro_cutscene.tscn` for the template — it's three lines:

```gdscript
[node name="MyCutscene" instance=ExtResource("1_base")]
frame_dir = "res://assets/cutscenes/my_cutscene/frames"
dialogue_wav = "res://assets/cutscenes/my_cutscene/dialogue.wav"
audio_start_seconds = 1.45
```

## Playing it in-game

`CutsceneManager` dispatches on the registry's `type` field (future wiring — currently `no_tail_outpost` is hardcoded in several call sites, see `docs/architecture/CODE_REVIEW.md §6A.6`). Until that lands, load the scene directly:

```gdscript
var scn := load("res://scenes/cutscenes/dave_intro_cutscene.tscn").instantiate()
add_child(scn)
scn.finished.connect(_on_cutscene_done)
```

## Art direction summary

- **Shader**: toon shading via `Diffuse → ShaderToRGB → ColorRamp (CONSTANT, 3 bands)` multiplied with the base texture, plus a Fresnel-masked warm rim-light additive, piped through an Emission so the banded lighting isn't re-lit.
- **Outlines**: Solidify modifier with flipped normals + backface-culled unlit dark material. Silhouette only (no interior creases) — good enough for the current characters.
- **World**: flat warm mid-grey background. Real shots will need environments once we have backdrop art.
- **Lighting**: strong warm key (1500W), subtle cool fill (250W), warm rim (1000W) for silhouette bleed. Cel shading wants contrast, not realism.

All knobs are at the top of `cutscene_pipeline/blender/setup_scene.py` under `# CONFIG`.

## Known limitations (v1 honest list)

1. **No mouth animation.** Characters have fragmented AI-generated UVs (no editable mouth region), no jaw bones, and no blendshapes. Painted-mouth-overlay was tried and abandoned — the painted tongue baked into the model pokes through any overlay. For now cutscenes rely on the "static painted mouth + dialogue card + audio" combo. The reference for a real solution is documented in `docs/next_steps.md` under Cutscene character rig upgrade, if/when it becomes critical.
2. **Compositor polish layer stubbed.** Paper overlay, film grain, vignette — all deferred to a v2 once we're happy with base look.
3. **No crease lines.** Solidify gives silhouette only. Internal creases (between shirt and fur, face features) would need Grease Pencil Line Art, which is a rig-per-character investment.
4. **Camera shake / dynamic composition.** Static-camera-per-shot only. Tweens mid-shot would work but haven't been needed yet.
5. **Memory cost.** The current `dave_intro` loads ~60 MB of PNG textures into RAM. Acceptable for one cutscene on desktop, will want streaming if we chain many. Swap to `AnimatedTexture` or a sprite atlas when this becomes a problem.

## Character pipeline constraint (important context)

Characters are generated by AI tools that produce fragmented UV atlases. Consequences:

- Face/mouth animation is **not possible** without retopology.
- Texture edits are **not possible** without painting in screen-space on renders.
- Blendshapes would need to be authored from scratch on a new topology.

Options when face animation matters:
1. Retopologise the hero characters' heads (Dave, Aristotle, one antagonist) — ~2 hours each.
2. Switch character generation tool to one with cleaner UVs (Meshy, Tripo) — affects all 11 characters.
3. Accept "static painted face + dialogue" for all cutscenes — the current answer.

See Sprint 7's `MASTER_PLAN` entry for the broader character pipeline discussion.
