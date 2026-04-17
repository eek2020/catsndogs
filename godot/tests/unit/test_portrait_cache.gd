extends GutTest

## Regression: Apr-05 #7 — per-pixel portrait background removal was recomputed
## every time a dialogue opened. `DialoguePortraitManager.remove_near_white_bg`
## memoises the processed texture by the source resource path, so the O(w*h)
## work only runs once per portrait per process. The helper moved from
## `dialogue_ui.gd` to `scripts/ui/dialogue/portrait_manager.gd` in Sprint 6a.


const PortraitManagerScript := preload(
	"res://scripts/ui/dialogue/portrait_manager.gd"
)


func _make_test_texture(resource_path: String) -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))  # fully white — will be made transparent
	img.set_pixel(4, 4, Color(0.1, 0.2, 0.3, 1.0))
	var tex := ImageTexture.create_from_image(img)
	tex.resource_path = resource_path
	return tex


func before_each() -> void:
	PortraitManagerScript._processed_portrait_cache.clear()


func test_null_texture_returns_null() -> void:
	assert_null(PortraitManagerScript.remove_near_white_bg(null))


func test_synthetic_texture_without_resource_path_is_not_cached() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	var a: Texture2D = PortraitManagerScript.remove_near_white_bg(tex)
	var b: Texture2D = PortraitManagerScript.remove_near_white_bg(tex)
	assert_not_null(a)
	assert_not_null(b)
	assert_ne(a.get_instance_id(), b.get_instance_id())
	assert_eq(PortraitManagerScript._processed_portrait_cache.size(), 0)


func test_second_call_with_same_resource_path_returns_cached_instance() -> void:
	var tex := _make_test_texture("res://test/portrait_a.png")
	var first: Texture2D = PortraitManagerScript.remove_near_white_bg(tex)
	var second: Texture2D = PortraitManagerScript.remove_near_white_bg(tex)
	assert_not_null(first)
	assert_eq(first.get_instance_id(), second.get_instance_id(),
		"cached result must be the same ImageTexture instance")
	assert_eq(PortraitManagerScript._processed_portrait_cache.size(), 1)


func test_different_resource_paths_are_cached_separately() -> void:
	var a := _make_test_texture("res://test/portrait_a.png")
	var b := _make_test_texture("res://test/portrait_b.png")
	var pa: Texture2D = PortraitManagerScript.remove_near_white_bg(a)
	var pb: Texture2D = PortraitManagerScript.remove_near_white_bg(b)
	assert_ne(pa.get_instance_id(), pb.get_instance_id())
	assert_eq(PortraitManagerScript._processed_portrait_cache.size(), 2)


func test_different_thresholds_are_cached_separately() -> void:
	var tex := _make_test_texture("res://test/portrait_a.png")
	var default_result: Texture2D = PortraitManagerScript.remove_near_white_bg(tex)
	var custom_result: Texture2D = PortraitManagerScript.remove_near_white_bg(tex, 0.5, 0.2)
	assert_ne(default_result.get_instance_id(), custom_result.get_instance_id(),
		"different threshold tuples must produce separate cache entries")
	assert_eq(PortraitManagerScript._processed_portrait_cache.size(), 2)


func test_processed_texture_has_transparent_white_pixels() -> void:
	var tex := _make_test_texture("res://test/portrait_a.png")
	var processed: Texture2D = PortraitManagerScript.remove_near_white_bg(tex)
	var img: Image = processed.get_image()
	assert_eq(img.get_pixel(0, 0).a, 0.0)
	assert_eq(img.get_pixel(4, 4).a, 1.0)
