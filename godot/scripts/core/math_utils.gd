## Shared math utilities — reusable helpers for randomisation, selection, etc.
##
## Centralises patterns that were duplicated across multiple systems
## (Code Review Issue #10).
class_name MathUtils
extends RefCounted


## Perform a weighted random selection from an array of items.
##
## [param items] — the candidate array to pick from.
## [param weight_fn] — a Callable that receives one item and returns its
##   weight as a float. Items with weight <= 0 are effectively skipped.
## Returns the selected item, or null if the array is empty or total weight is zero.
##
## Example:
##   var pick = MathUtils.weighted_pick(enemies, func(e): return e.spawn_weight)
static func weighted_pick(items: Array, weight_fn: Callable) -> Variant:
	var total: float = 0.0
	for item in items:
		total += weight_fn.call(item)
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	var acc: float = 0.0
	for item in items:
		acc += weight_fn.call(item)
		if roll <= acc:
			return item
	return items[-1]
