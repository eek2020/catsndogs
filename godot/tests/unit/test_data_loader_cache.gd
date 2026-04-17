extends GutTest

## Regression: MASTER_PLAN §5.3 Apr-05 #4 (cache never invalidated) and #12
## (redundant loads for same file). DataLoader now:
##   - Returns deep-duplicated Dictionary/Array payloads so callers cannot mutate
##     the cache by mutating what they loaded.
##   - Exposes `clear_cache()` and `invalidate(path)` for session crossover.
## These tests seed a temporary data_root on `user://` so they do not depend on
## production JSON files.
##
## `_load_json` is the only method that reveals the cached-vs-fresh path; tests
## call it directly on purpose. `@warning_ignore` silences the private-access
## lint so CI stays clean.

@warning_ignore_start("unused_private_class_variable")

const DataLoaderScript := preload("res://scripts/core/data_loader.gd")

const _ROOT := "user://test_data_loader_cache"
const _REL := "sample.json"


func _write_sample(payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_ROOT)
	var f := FileAccess.open(_ROOT.path_join(_REL), FileAccess.WRITE)
	f.store_string(JSON.stringify(payload))
	f.close()


func _make_loader() -> DataLoader:
	return DataLoaderScript.new(_ROOT)


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(_ROOT)


func after_each() -> void:
	# Clean the scratch data each run so runs stay independent.
	var d := DirAccess.open(_ROOT)
	if d == null:
		return
	for file_name in d.get_files():
		d.remove(file_name)


func test_returned_dictionary_mutation_does_not_leak_into_cache() -> void:
	_write_sample({"foo": {"bar": 1}})
	var loader := _make_loader()
	var a: Dictionary = loader._load_json(_REL)
	a["foo"]["bar"] = 999
	a["new_key"] = "added"
	var b: Dictionary = loader._load_json(_REL)
	assert_eq(b["foo"]["bar"], 1, "nested value must not reflect caller mutation")
	assert_false(b.has("new_key"), "top-level key added by caller must not leak")


func test_returned_array_mutation_does_not_leak_into_cache() -> void:
	# JSON parses numeric literals as floats in GDScript's JSON, so we compare
	# against the parsed representation. The point of the test is isolation,
	# not parse fidelity.
	_write_sample({"list": [1, 2, 3]})
	var loader := _make_loader()
	var a: Dictionary = loader._load_json(_REL)
	(a["list"] as Array).append(999)
	var b: Dictionary = loader._load_json(_REL)
	assert_eq((b["list"] as Array).size(), 3)
	assert_false((b["list"] as Array).has(999))


func test_cache_hit_skips_disk_on_second_call() -> void:
	_write_sample({"value": 42})
	var loader := _make_loader()
	assert_false(loader.is_cached(_REL))
	var _first: Variant = loader._load_json(_REL)
	assert_true(loader.is_cached(_REL), "first load must populate the cache")
	# Delete the source file — a cache-hit must still succeed.
	DirAccess.open(_ROOT).remove(_REL)
	var second: Dictionary = loader._load_json(_REL)
	assert_eq(second["value"], 42,
		"second load must come from cache even when the file is gone")


func test_clear_cache_wipes_all_entries() -> void:
	_write_sample({"value": 42})
	var loader := _make_loader()
	loader._load_json(_REL)
	assert_true(loader.is_cached(_REL))
	loader.clear_cache()
	assert_false(loader.is_cached(_REL))


func test_invalidate_drops_only_the_named_entry() -> void:
	_write_sample({"a": 1})
	var loader := _make_loader()
	# Prime two entries. The second writes a different relative path.
	var other_rel := "other.json"
	var f := FileAccess.open(_ROOT.path_join(other_rel), FileAccess.WRITE)
	f.store_string(JSON.stringify({"b": 2}))
	f.close()
	loader._load_json(_REL)
	loader._load_json(other_rel)
	assert_true(loader.is_cached(_REL))
	assert_true(loader.is_cached(other_rel))
	loader.invalidate(_REL)
	assert_false(loader.is_cached(_REL), "targeted entry must be dropped")
	assert_true(loader.is_cached(other_rel), "other entries must survive")


func test_invalidate_unknown_path_is_noop() -> void:
	var loader := _make_loader()
	loader.invalidate("never_loaded.json")
	assert_false(loader.is_cached("never_loaded.json"))


func test_clear_cache_is_idempotent() -> void:
	var loader := _make_loader()
	loader.clear_cache()  # cache already empty — must not error
	_write_sample({"value": 42})
	loader._load_json(_REL)
	loader.clear_cache()
	loader.clear_cache()
	assert_false(loader.is_cached(_REL))


func test_duplicate_cached_returns_primitive_unchanged() -> void:
	assert_eq(DataLoaderScript._duplicate_cached(7), 7)
	assert_eq(DataLoaderScript._duplicate_cached("x"), "x")
