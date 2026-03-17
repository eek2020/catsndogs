## Save/Load Manager — handles persisting and restoring GameStateData to disk.
## Mirrors Python core/save_manager.py.
class_name SaveManager
extends RefCounted

const MAX_SAVE_SLOTS: int = 3
const SAVE_FILE_PREFIX: String = "save_slot_"
const SAVE_FILE_EXT: String = ".json"

var save_dir: String


func _init(p_save_dir: String = "") -> void:
	if p_save_dir.is_empty():
		save_dir = "user://saves"
	else:
		save_dir = p_save_dir


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)


func _slot_path(slot: int) -> String:
	return save_dir.path_join("%s%d%s" % [SAVE_FILE_PREFIX, slot, SAVE_FILE_EXT])


func save_game(game_state: GameStateData, slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		push_error("Invalid save slot: %d" % slot)
		return false
	_ensure_dir()
	game_state.save_slot = slot
	var data: Dictionary = game_state.to_dict()
	data["_meta"] = {
		"saved_at": Time.get_unix_time_from_system(),
		"character_name": game_state.player_character.character_name if game_state.player_character else "Unknown",
		"arc": game_state.current_arc,
		"playtime": game_state.playtime_seconds,
	}
	var json_string := JSON.stringify(data, "\t")
	var path := _slot_path(slot)
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save game to slot %d" % slot)
		return false
	file.store_string(json_string)
	file.close()
	# Atomic rename
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp_path, path)
	print("Game saved to slot %d: %s" % [slot, path])
	return true


func load_game(slot: int) -> GameStateData:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		push_error("Invalid save slot: %d" % slot)
		return null
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		print("No save file for slot %d" % slot)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to load save from slot %d" % slot)
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Failed to parse save slot %d: %s" % [slot, json.get_error_message()])
		return null
	var data: Dictionary = json.data
	data.erase("_meta")
	return GameStateData.from_dict(data)


func get_save_info() -> Array:
	var result: Array = []
	for slot in range(MAX_SAVE_SLOTS):
		var path := _slot_path(slot)
		if not FileAccess.file_exists(path):
			result.append(null)
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			result.append(null)
			continue
		var text := file.get_as_text()
		file.close()
		var json := JSON.new()
		var err := json.parse(text)
		if err != OK:
			result.append(null)
			continue
		var data: Dictionary = json.data
		var meta: Dictionary = data.get("_meta", {})
		result.append({
			"slot": slot,
			"character_name": meta.get("character_name", "Unknown"),
			"arc": meta.get("arc", "???"),
			"playtime": meta.get("playtime", 0.0),
			"saved_at": meta.get("saved_at", 0.0),
		})
	return result


func delete_save(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return false
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			push_error("Failed to delete save slot %d" % slot)
			return false
		print("Deleted save slot %d" % slot)
	return true
