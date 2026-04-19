class_name PreRenderedCutscenePlayer
extends Node

## Plays a pre-rendered painterly cutscene as a PNG image sequence plus a
## WAV dialogue track. This is the companion to the realtime 3D cutscene
## flavour handled by CutsceneManager (scripts/systems/cutscene/) — use this
## when the shot wants the full stylised Blender render with bold outlines
## and painted colour, which is prohibitively expensive to do in-engine in
## real time.
##
## Feeds from a directory of sequentially-numbered PNGs (frame_0001.png …)
## plus an optional dialogue .wav, both pointed at by exported paths so the
## same scene can be reused for every pre-rendered cutscene.
##
## Authoring: see cutscene_pipeline/blender/render_shots.py for the Blender
## side and docs/architecture/cutscenes/PRERENDERED_PIPELINE.md for the
## full end-to-end workflow.

## Directory containing the frame_NNNN.png sequence.
@export_dir var frame_dir: String = "res://assets/cutscenes/dave_intro/frames"
## Optional WAV to play as dialogue audio. Leave empty for silent cutscenes.
@export_file("*.wav") var dialogue_wav: String = "res://assets/cutscenes/dave_intro/dialogue.wav"
## Frame rate the sequence was rendered at.
@export var fps: float = 24.0
## Play the cutscene on _ready. Turn off when driving via CutsceneManager.
@export var autoplay: bool = true
## Loop on finish. Useful for debug harnesses; cutscenes inside the game
## should emit `finished` and unload instead.
@export var loop: bool = false
## Seconds into the sequence at which dialogue audio is triggered.
## Tuned to land just before the dialogue card fades in (authored in the
## ffmpeg filter graph; see _filter_cutscene.txt in the pipeline).
@export var audio_start_seconds: float = 1.45

## Emitted when the sequence finishes (never when looping).
signal finished

@onready var _tex_rect: TextureRect = $CutsceneFrame
@onready var _audio: AudioStreamPlayer = $Audio

var _frames: Array[Texture2D] = []
var _time: float = 0.0
var _audio_triggered: bool = false
var _playing: bool = false


func _ready() -> void:
	_frames = _load_frames()
	if _frames.is_empty():
		push_error("PreRenderedCutscenePlayer: no PNG frames found in %s" % frame_dir)
		return
	_tex_rect.texture = _frames[0]

	if dialogue_wav != "" and ResourceLoader.exists(dialogue_wav):
		_audio.stream = load(dialogue_wav)

	if autoplay:
		play()


func play() -> void:
	_time = 0.0
	_audio_triggered = false
	_audio.stop()
	_playing = true


func stop() -> void:
	_playing = false
	_audio.stop()


func _process(delta: float) -> void:
	if not _playing or _frames.is_empty():
		return

	_time += delta
	var total_duration: float = _frames.size() / fps

	if _audio.stream != null and not _audio_triggered and _time >= audio_start_seconds:
		_audio.play()
		_audio_triggered = true

	if _time >= total_duration:
		if loop:
			_time = 0.0
			_audio_triggered = false
			_audio.stop()
		else:
			_playing = false
			_tex_rect.texture = _frames[-1]
			finished.emit()
			return

	var idx: int = clamp(int(_time * fps), 0, _frames.size() - 1)
	_tex_rect.texture = _frames[idx]


func _load_frames() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var dir := DirAccess.open(frame_dir)
	if dir == null:
		return out
	dir.list_dir_begin()
	var names: Array[String] = []
	while true:
		var fname := dir.get_next()
		if fname == "":
			break
		if fname.ends_with(".png"):
			names.append(fname)
	dir.list_dir_end()
	names.sort()
	for n in names:
		var tex: Texture2D = load("%s/%s" % [frame_dir, n])
		if tex:
			out.append(tex)
	return out
