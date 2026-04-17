## SaveLoadViewModel — narrow adapter between GameSession + SaveManager
## and the multi-slot save/load overlay. Same pattern as the other VMs:
## RefCounted, constructor takes a session double so the screen can be
## exercised in GUT without autoloads. Pattern from CODE_REVIEW.md §2.1.
class_name SaveLoadViewModel
extends RefCounted

const SLOT_COUNT: int = 3

var _session  # GameSession autoload, or a test double with the same shape


func _init(session) -> void:
	_session = session


## Returns an Array[SLOT_COUNT] of Dictionary rows (or null for empty slots).
## Each populated row has: slot (int), character_name (String), arc (String),
## playtime (float seconds), saved_at (unix seconds).
func slot_info() -> Array:
	if _session == null or _session.save_manager == null:
		var empty: Array = []
		empty.resize(SLOT_COUNT)
		return empty
	return _session.save_manager.get_save_info()


func save_to_slot(slot: int) -> bool:
	if _session == null:
		return false
	return _session.save_game(slot)


func load_from_slot(slot: int) -> bool:
	if _session == null:
		return false
	return _session.load_game(slot)


func delete_slot(slot: int) -> bool:
	if _session == null or _session.save_manager == null:
		return false
	return _session.save_manager.delete_save(slot)


func has_state() -> bool:
	return _session != null and _session.game_state != null


# ---------------------------------------------------------------------------
# Display helpers — free from GameSession so both UI and tests get them.
# ---------------------------------------------------------------------------

static func format_playtime(seconds: float) -> String:
	var total: int = int(seconds)
	var h: int = total / 3600
	var m: int = (total / 60) % 60
	var s: int = total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]


static func format_saved_at(unix_seconds: float) -> String:
	if unix_seconds <= 0.0:
		return ""
	var dict: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix_seconds))
	return "%04d-%02d-%02d %02d:%02d" % [
		dict.get("year", 0),
		dict.get("month", 0),
		dict.get("day", 0),
		dict.get("hour", 0),
		dict.get("minute", 0),
	]


static func describe_slot(info: Variant) -> String:
	if info == null:
		return "(empty)"
	var d: Dictionary = info
	var name: String = d.get("character_name", "Unknown")
	var arc: String = d.get("arc", "???").replace("_", " ").capitalize()
	var played: String = format_playtime(d.get("playtime", 0.0))
	return "%s — %s — %s" % [name, arc, played]
