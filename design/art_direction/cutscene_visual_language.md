# Whisper Crystals — Cutscene Visual Language

**Scope.** This document covers the look and compositional grammar of **pre-rendered cutscenes** — the painterly-3D flavour proved out on `dave_intro` in April 2026. Realtime gameplay, pixel sprites, and painted portrait cards are covered in `art_direction_guide.md`. This doc is the third art track, living between the pixel floor (Track A) and the painted portraits (Track B).

**Companion docs.**
- `docs/architecture/cutscenes/PRERENDERED_PIPELINE.md` — the authoring / engineering pipeline. Read this one for *how* to ship a shot.
- `design/art_direction/art_direction_guide.md` — the project-wide style bible. Read it for *why* cats look like cats.

---

## The third track

| Track | Where it shows up | Render target |
|---|---|---|
| **A — Pixel sprites** | Live gameplay, navigation, combat, world map, shop tiles | 64×64 native, exported 256×256 |
| **B — Painted portraits** | Dialogue headshots, shop NPCs, key-art splashes | 2D illustration (AI-generated + hand-touch) |
| **C — Painterly 3D cutscenes** | Story beats, intros, outros, reveals, key plot moments | Blender Eevee render → PNG sequence in Godot |

Track C is **Track B staged in 3D**: the same illustrated look, but the characters move, the camera cuts, a dialogue card appears. The viewer should feel like a painted portrait card came to life for 4–6 seconds.

---

## Visual definition

### The look in one sentence

*Thick warm-black ink outlines around painted characters rendered in 3/4 perspective, banded cel lighting with warm-key/cool-fill/warm-rim, flat mid-tone background, Baskerville dialogue card on a dark semi-transparent panel.*

### Reference pins

- **Disney Wish (2023)** — painterly characters rendered in 3D, strong ink outlines, flat backdrops when dialogue is the focus.
- **Spider-Man: Into the Spider-Verse** — stylised outlines, panel-comic sensibility in camera composition.
- **Borderlands** (cinematic intros) — ink-outline characters against flat colour fields.
- **Oxenfree / Kentucky Route Zero** — serif dialogue treatment that respects the artwork rather than competing with it.

### What it is NOT

- **Not realistic.** Shading is banded into 3 steps, not smooth. No specular. No ambient occlusion.
- **Not anime/cel.** Lines are warm brown-black (not pure black), palette is painted (not flat fills), shadows carry a cool-purple tint (not solid grey).
- **Not live 3D.** This look is too expensive to render at 60fps in Godot. Everything is baked to PNG sequences.

---

## Technical shorthand (one-page recipe)

| Element | Rule |
|---|---|
| **Render resolution** | 1920×1080 authored, 960×540 shipped (halved for memory) |
| **Frame rate** | 24 fps (film cadence) |
| **Shader** | `Diffuse → ShaderToRGB → ColorRamp (CONSTANT, 3 bands) × base texture`, plus Fresnel-masked warm rim, Emission output so banding isn't re-lit |
| **Outlines** | Solidify modifier, flipped normals, backface-culled unlit dark material. Silhouette only. |
| **Outline colour** | `#140D0A` (warm brown-black). Never pure black. |
| **Shadow tint** | `#5950'73` (cool purple). Never neutral grey. |
| **Rim tint** | `#FFD08C` (warm amber). Always warmer than the key. |
| **Key light** | 1500 W, colour `#FFF0D9` — hot warm from upper-front-right |
| **Fill light** | 250 W, colour `#C6DBFF` — cool subtle from opposite side |
| **Rim light** | 1000 W, colour `#FFD199` — warm from behind for silhouette bleed |
| **Background** | `#6B6661` — neutral warm mid-grey. Flat. No environment until approved per-cutscene. |

All of the above are knobs at the top of `cutscene_pipeline/blender/setup_scene.py`. If the look drifts across cutscenes, check those values first.

---

## Composition grammar

### Shot lengths

- **Short (≤2s)** — action or establishing. Side-on walk, establishing pan, beat of silence.
- **Medium (3–5s)** — one dialogue line. Static or slow dolly-in.
- **Long (6–8s)** — two short lines or one long line with reaction. Rare — break into two shots if you can.

Never go over 8 seconds without a cut. The pipeline cost scales with length and the player's patience does too.

### Camera language

Three camera moves are considered "house style." Anything else needs a conversation.

1. **Static 3/4 medium close-up** — the default for dialogue. Subject's upper chest and head fill the frame, camera at chest height, 50–55mm lens, 3/4 angle from the speaker's right. Used in `shot2_idle_dialogue`.
2. **Static side-on mid-shot with subject root motion** — for walks and entrances. Camera sits still; the Mixamo root motion carries the subject through frame. Used in `shot1_walk`. 40–45mm lens.
3. **Slow dolly-in** — for emphasis. Start and end camera positions differ by 10–15 cm over the shot length. Never a zoom — always a physical move.

**Never** use handheld shake, whip-pans, or dutch angles. The dialogue card needs stable real estate.

### Staging rules

- **One subject per shot.** If two characters need to be on screen, they need two shots or a dedicated two-shot composition that's been designed in advance.
- **Subject faces into negative space.** Dialogue card appears in the opposite corner. If Dave faces camera-right, the card goes bottom-left.
- **Eyes in the upper third.** Character eye-line should land on the 1/3 horizontal gridline, not the vertical centre. Classic portrait framing.
- **Minimum 10% headroom.** Never crop the top of the head unless the composition demands it for a reason.

---

## Dialogue card style

**Font:** Baskerville (macOS: `/System/Library/Fonts/Supplemental/Baskerville.ttc`). Adventure-novel serif — slightly old-fashioned, lets the story feel crafted rather than action-y.

**Panel:**
- Width: 70% of viewport, centred horizontally.
- Y position: 68–72% down the frame.
- Colour: `#2A1F14` at 95% opacity (warm near-black).
- Border: 6px inset line of the same colour.
- Corners: straight, not rounded. Reads more "antique book" than "modern UI."

**Text:**
- Speaker name: 34pt, colour `#F0D9A8` (warm cream), centred on panel.
- Dialogue: 44pt, colour `#FAF3E0` (warm off-white), centred, italic emphasis allowed.
- Body copy uses em-dash (—) not ellipsis for pauses. Fits the tone.

**Timing:**
- Card begins fading in at dialogue-start **minus 0.3s** — appears before the voice starts speaking, not on top of.
- Fade-in duration: 0.4s.
- Card holds until the end of the shot — never fades out mid-shot.
- If two lines play back-to-back in one shot: swap text at the start of line 2 without re-fading the panel.

**Technical note:** the card is burned into the PNG sequence via the ffmpeg filter graph (`cutscene_pipeline/blender/_filter_cutscene.txt`). This means localising means re-rendering — a known v1 tradeoff, see `PRERENDERED_PIPELINE.md`.

---

## Audio

**Voice.** macOS `say -v Daniel -r 165` (British male) is the **placeholder** standard for prototyping. Every shipping cutscene needs real VO eventually. Tone briefs:

- **Aristotle (cat captain)** — smirking, wry. Think Cary Grant doing a pirate.
- **Dave (dog captain)** — calm, measured, dry humour. Think Gary Oldman restrained.
- **Death** — slow, theatrical, never rushed. Think Peter Serafinowicz. Reverb in post, not in the render.
- **Faction lieutenants** — crisp, professional, faction-accent (Canis = British military, Felid = Continental European, Lions = RP, Wolves = clipped Slavic).

**Mix.**
- Dialogue peaks at −6 dB.
- No music under dialogue cutscenes — let the line land. Music returns on fade-out to gameplay.
- Mono audio is fine at current fidelity; cutscenes play to dialogue-weighted speakers, not 5.1.

---

## Character treatment in Track C

### What transfers from Track B (painted portraits)

- The *palette*. Dave's painted portrait uses `#D2A978` for the tan fur and `#2D2D2D` for the dark panels — the 3D render should read in those values, not some new colour scheme. If Track B establishes it, Track C matches it.
- The *silhouette shape*. The 3/4 angle in cutscenes should echo the portrait's iconic angle — easy to identify at a glance.
- The *expression default*. Dave's portrait has a happy open-mouthed grin. The 3D model carries this as a static painted mouth. This is deliberate.

### What Track C adds

- **Motion.** Idle, walk, laugh, jump — all from the 5 Mixamo anims per character.
- **Camera language** per shot.
- **Lighting beat.** The warm-cool-rim setup means characters read like they're lit for a movie, not existing in flat illustration-land.

### What Track C cannot do (and why)

See `docs/architecture/cutscenes/PRERENDERED_PIPELINE.md` §Character pipeline constraint for full context. Short version:

- **No face animation.** UVs are fragmented, no jaw bone, no blendshapes. Mouth is always the painted expression. Accept it.
- **No interior crease lines.** Solidify gives silhouette only. No drawn-in wrinkles, folds in clothing, or facial features — only what the base texture already carries.
- **No environment interaction** — yet. Characters sit on the flat warm-grey. Environments require per-cutscene 3D set construction; they'll come with specific named cutscenes and aren't a shared asset yet.

---

## When a cutscene is "on-model"

A cutscene is approved when all five are true:

1. **Character is recognisable** from their Track B portrait at a still-frame check.
2. **Outlines are present and uniform** — no broken silhouettes, no places where the shell shows through.
3. **Shading bands are visible** on the character — not a smooth gradient, not entirely flat, but clearly 3 steps of tone.
4. **Dialogue card reads cleanly** at 1080p — no text-over-face, no clipping at panel edges.
5. **Tone matches the reference pins** — this is the subjective one. If it feels like a fighting-game intro, it's wrong. If it feels like a page from a painted graphic novel, it's right.

A cutscene that fails any of these goes back. A cutscene that fails #5 gets a second opinion.

---

## Adding new characters to Track C

When a character gets their first cutscene appearance:

1. Confirm their Mixamo baseline FBX (`design/charcters/<base>/3d/<char>_t_pose_3d_baseline.fbx`) loads in the pipeline without warnings.
2. Confirm their Track B portrait exists at `design/charcters/<base>/2d/<char>_t_pose.png` — this is the visual anchor.
3. Run a **single-frame calibration**: render one static 3/4 medium close-up with the standard lighting. Compare side-by-side with the Track B portrait. If the shading bands don't sit in the same tonal regions as the portrait, *adjust the per-character lighting in the shot config*, not the shader.
4. Only then proceed to authoring shots.

The point of step 3 is to fail fast on characters whose 3D texture doesn't survive the toon shader. We caught this early with Dave; it may bite on characters with more subtle painted detail.

---

## Decisions deferred to v2

Documented so future-us doesn't re-litigate:

- **Compositor polish** (paper texture, film grain, vignette). Stubbed. Blender 5.x compositor was rewritten and the old node graph no longer works. Either rebuild with surviving nodes or keep polish in ffmpeg. Decision: when a specific cutscene needs the extra texture, revisit then.
- **Mouth animation.** Not possible with current character pipeline. Retopology + jaw rig is the path if a specific hero moment demands it. Decision: skip unless a named cutscene can't carry without it.
- **Background environments.** Per-cutscene bespoke work for now. If more than three cutscenes want the same location (e.g. `aristotle_quarters`), promote it to a shared .blend in `cutscene_pipeline/`.
- **Localisation of dialogue cards.** Currently burned into the frames. If localisation becomes a shipping requirement, move the card from ffmpeg-burn into a Godot RichTextLabel overlay; player then renders text at runtime from a localised strings table. This is a ~1 day retrofit.
- **Music under cutscenes.** Currently off. If the tone of a scene needs underscore, author it, mix it under the dialogue, and document the pattern here.

---

## Where this doc lives in the review cycle

- Updated by: whoever ships a new cutscene that sets or breaks a convention.
- Reviewed by: the person approving the cutscene.
- Pair with: a still frame or short gif in `design/art_direction/` showing "this is what good looks like."

The first such anchor is `dave_intro` — pull a still from `godot/assets/cutscenes/dave_intro/frames/frame_0050.png` and add it to this doc when we next touch it.
