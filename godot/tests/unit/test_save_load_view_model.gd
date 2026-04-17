extends GutTest

## Coverage for SaveLoadViewModel (Sprint 6c task 1). Uses SessionDouble +
## SaveManagerDouble so the VM can be exercised without touching real disk.


class SaveManagerDouble:
	extends RefCounted
	var saves: Dictionary = {}  # slot -> info Dict
	var save_count: int = 0
	var delete_count: int = 0

	func get_save_info() -> Array:
		var result: Array = []
		result.resize(3)
		for slot in saves.keys():
			if slot is int and slot >= 0 and slot < 3:
				result[slot] = saves[slot]
		return result

	func delete_save(slot: int) -> bool:
		delete_count += 1
		if saves.has(slot):
			saves.erase(slot)
			return true
		return false


class SessionDouble:
	extends RefCounted
	var save_manager: SaveManagerDouble
	var game_state = null  # sentinel (non-null = "has state")
	var save_results: Dictionary = {}  # slot -> bool
	var load_results: Dictionary = {}
	var last_save_slot: int = -1
	var last_load_slot: int = -1

	func _init() -> void:
		save_manager = SaveManagerDouble.new()

	func save_game(slot: int) -> bool:
		last_save_slot = slot
		var ok: bool = save_results.get(slot, true)
		if ok:
			save_manager.saves[slot] = {
				"slot": slot,
				"character_name": "TestChar",
				"arc": "the_squeeze",
				"playtime": 125.0,
				"saved_at": 1_712_000_000.0,
			}
		return ok

	func load_game(slot: int) -> bool:
		last_load_slot = slot
		return load_results.get(slot, save_manager.saves.has(slot))


# ---------------------------------------------------------------------------

func test_slot_info_returns_three_slots() -> void:
	var session := SessionDouble.new()
	var vm := SaveLoadViewModel.new(session)
	var info: Array = vm.slot_info()
	assert_eq(info.size(), 3)
	for row in info:
		assert_null(row)


func test_slot_info_reflects_saved_slots() -> void:
	var session := SessionDouble.new()
	session.game_state = "sentinel"
	var vm := SaveLoadViewModel.new(session)
	vm.save_to_slot(1)
	var info: Array = vm.slot_info()
	assert_null(info[0])
	assert_not_null(info[1])
	assert_eq((info[1] as Dictionary).get("slot", -1), 1)
	assert_null(info[2])


func test_save_to_slot_delegates_and_returns_result() -> void:
	var session := SessionDouble.new()
	session.game_state = "sentinel"
	session.save_results[2] = true
	var vm := SaveLoadViewModel.new(session)
	assert_true(vm.save_to_slot(2))
	assert_eq(session.last_save_slot, 2)


func test_save_to_slot_returns_false_without_state() -> void:
	var session := SessionDouble.new()
	session.save_results[0] = false
	var vm := SaveLoadViewModel.new(session)
	assert_false(vm.save_to_slot(0))


func test_load_from_slot_delegates() -> void:
	var session := SessionDouble.new()
	session.game_state = "sentinel"
	session.save_manager.saves[1] = {"slot": 1, "character_name": "Dave"}
	var vm := SaveLoadViewModel.new(session)
	assert_true(vm.load_from_slot(1))
	assert_eq(session.last_load_slot, 1)


func test_delete_slot_delegates() -> void:
	var session := SessionDouble.new()
	session.game_state = "sentinel"
	var vm := SaveLoadViewModel.new(session)
	vm.save_to_slot(0)
	assert_true(vm.delete_slot(0))
	assert_eq(session.save_manager.delete_count, 1)
	assert_null(vm.slot_info()[0])


func test_delete_slot_returns_false_when_no_session() -> void:
	var vm := SaveLoadViewModel.new(null)
	assert_false(vm.delete_slot(0))


func test_has_state_tracks_game_state() -> void:
	var session := SessionDouble.new()
	var vm := SaveLoadViewModel.new(session)
	assert_false(vm.has_state())
	session.game_state = "sentinel"
	assert_true(vm.has_state())


func test_format_playtime_short() -> void:
	assert_eq(SaveLoadViewModel.format_playtime(65.0), "1:05")
	assert_eq(SaveLoadViewModel.format_playtime(0.0), "0:00")


func test_format_playtime_long() -> void:
	assert_eq(SaveLoadViewModel.format_playtime(3725.0), "1:02:05")


func test_describe_slot_handles_null() -> void:
	assert_eq(SaveLoadViewModel.describe_slot(null), "(empty)")


func test_describe_slot_formats_populated() -> void:
	var info: Dictionary = {
		"character_name": "Aristotle",
		"arc": "the_squeeze",
		"playtime": 125.0,
	}
	var text: String = SaveLoadViewModel.describe_slot(info)
	assert_true(text.contains("Aristotle"))
	assert_true(text.contains("The Squeeze"))
	assert_true(text.contains("2:05"))
