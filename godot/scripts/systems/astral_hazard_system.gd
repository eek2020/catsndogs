## Astral hazard system — manages static and dynamic environmental hazards,
## crew mitigation checks, damage/status effects, and entropy-based spawning.
## See docs/plans/astral-hazards-feature-plan.md.
class_name AstralHazardSystem
extends RefCounted

var hazard_definitions: Dictionary = {}   # hazard_id -> definition dict
var static_hazards: Dictionary = {}       # region_id -> Array of placed hazard dicts
var active_dynamic: Dictionary = {}       # region_id -> Array of spawned hazard dicts
var status_effects: Array = []            # [{effect_id, remaining, hazard_id}]
var entropy_timer: float = 0.0            # seconds until next dynamic spawn
var collision_cooldown: float = 0.0       # seconds before another hazard can trigger

## Injected reference to StarMapSystem for bounds/fog queries (Issue #5).
## Set by GameSession after construction instead of reaching into the singleton.
var star_map_system: StarMapSystem = null

const ENTROPY_MIN: float = 900.0          # 15 minutes
const ENTROPY_MAX: float = 1200.0         # 20 minutes
const COLLISION_COOLDOWN: float = 120.0   # 2 minutes between hazard hits
const DYNAMIC_TIMEOUT: float = 600.0      # dynamic hazards despawn after 10 min


func _init() -> void:
	entropy_timer = randf_range(ENTROPY_MIN, ENTROPY_MAX)


func load_definitions(data: Dictionary) -> void:
	hazard_definitions.clear()
	for hazard in data.get("hazard_types", []):
		var hid: String = hazard.get("hazard_id", "")
		if not hid.is_empty():
			hazard_definitions[hid] = hazard


func load_static_hazards(data: Dictionary) -> void:
	static_hazards = data.get("static_hazards", {})
	for region_id in static_hazards:
		if not active_dynamic.has(region_id):
			active_dynamic[region_id] = []


func get_definition(hazard_id: String) -> Dictionary:
	return hazard_definitions.get(hazard_id, {})


## -----------------------------------------------------------------------
## Update tick — called each frame from navigation
## -----------------------------------------------------------------------

func update(region_id: String, dt: float, game_state: GameStateData) -> void:
	_tick_entropy(region_id, dt)
	_age_dynamic_hazards(region_id, dt)
	_tick_status_effects(dt, game_state)
	if collision_cooldown > 0.0:
		collision_cooldown -= dt


func _tick_entropy(region_id: String, dt: float) -> void:
	entropy_timer -= dt
	if entropy_timer <= 0.0:
		spawn_dynamic_hazard(region_id)
		entropy_timer = randf_range(ENTROPY_MIN, ENTROPY_MAX)


func _age_dynamic_hazards(region_id: String, dt: float) -> void:
	if not active_dynamic.has(region_id):
		return
	var retained: Array = []
	for hazard in active_dynamic[region_id]:
		hazard["age"] = hazard.get("age", 0.0) + dt
		if hazard["age"] < DYNAMIC_TIMEOUT:
			retained.append(hazard)
	active_dynamic[region_id] = retained


## -----------------------------------------------------------------------
## Dynamic hazard spawning
## -----------------------------------------------------------------------

func spawn_dynamic_hazard(region_id: String) -> void:
	var dynamic_defs: Array = []
	var total_weight: float = 0.0
	for hid in hazard_definitions:
		var defn: Dictionary = hazard_definitions[hid]
		if defn.get("category", "") == "dynamic":
			var w: float = defn.get("entropy_weight", 10)
			dynamic_defs.append({"hazard_id": hid, "weight": w})
			total_weight += w

	if dynamic_defs.is_empty() or total_weight <= 0.0:
		return

	# Weighted random selection (Issue #10 — uses shared utility)
	var chosen_entry: Variant = MathUtils.weighted_pick(
		dynamic_defs, func(e): return e["weight"]
	)
	if chosen_entry == null:
		return
	var chosen_id: String = chosen_entry["hazard_id"]

	var defn: Dictionary = hazard_definitions.get(chosen_id, {})
	if defn.is_empty():
		return

	# Random position within region bounds (with padding)
	var bounds: Vector2 = _get_region_bounds(region_id)
	var pad: float = 400.0
	var spawn_x: float = randf_range(pad, bounds.x - pad)
	var spawn_y: float = randf_range(pad, bounds.y - pad)

	if not active_dynamic.has(region_id):
		active_dynamic[region_id] = []

	active_dynamic[region_id].append({
		"hazard_id": chosen_id,
		"x": spawn_x,
		"y": spawn_y,
		"zone_radius": defn.get("zone_radius", 200),
		"age": 0.0,
		"label": defn.get("display_name", "Unknown Hazard"),
	})

	EventBus.hazard_entered.emit(chosen_id, "spawned")


func _get_region_bounds(region_id: String) -> Vector2:
	if star_map_system != null:
		return star_map_system.get_bounds(region_id)
	return Vector2(6000, 6000)


## -----------------------------------------------------------------------
## Visibility — returns hazards in revealed fog for rendering
## -----------------------------------------------------------------------

func get_visible_hazards(region_id: String) -> Array:
	var result: Array = []
	var sms: StarMapSystem = star_map_system

	# Static hazards
	for hazard in static_hazards.get(region_id, []):
		var px: float = hazard.get("x", 0.0)
		var py: float = hazard.get("y", 0.0)
		if sms != null and sms.is_position_revealed(region_id, px, py):
			var merged: Dictionary = hazard.duplicate()
			merged["source"] = "static"
			result.append(merged)

	# Dynamic hazards (always visible once spawned — they're active events)
	for hazard in active_dynamic.get(region_id, []):
		var merged: Dictionary = hazard.duplicate()
		merged["source"] = "dynamic"
		result.append(merged)

	return result


## -----------------------------------------------------------------------
## Collision detection
## -----------------------------------------------------------------------

func check_ship_collision(region_id: String, ship_x: float, ship_y: float) -> Dictionary:
	if collision_cooldown > 0.0:
		return {}

	# Check static hazards
	for hazard in static_hazards.get(region_id, []):
		var hit: Dictionary = _test_collision(hazard, ship_x, ship_y)
		if not hit.is_empty():
			return hit

	# Check dynamic hazards
	for i in range(active_dynamic.get(region_id, []).size() - 1, -1, -1):
		var hazard: Dictionary = active_dynamic[region_id][i]
		var hit: Dictionary = _test_collision(hazard, ship_x, ship_y)
		if not hit.is_empty():
			# Remove dynamic hazard after collision
			active_dynamic[region_id].remove_at(i)
			return hit

	return {}


func _test_collision(hazard: Dictionary, ship_x: float, ship_y: float) -> Dictionary:
	var hx: float = hazard.get("x", 0.0)
	var hy: float = hazard.get("y", 0.0)
	var radius: float = hazard.get("zone_radius", 200.0)
	var dx: float = ship_x - hx
	var dy: float = ship_y - hy
	if (dx * dx + dy * dy) <= radius * radius:
		return hazard
	return {}


## -----------------------------------------------------------------------
## Hazard resolution — crew check, damage, status effects
## -----------------------------------------------------------------------

func resolve_hazard(hazard: Dictionary, game_state: GameStateData) -> Dictionary:
	collision_cooldown = COLLISION_COOLDOWN

	var hazard_id: String = hazard.get("hazard_id", "")
	var defn: Dictionary = hazard_definitions.get(hazard_id, {})
	if defn.is_empty():
		return {"mitigated": false, "damage": 0, "bark": "Unknown hazard encountered."}

	var trait_key: String = defn.get("mitigation_trait", "")
	var threshold: float = defn.get("mitigation_threshold", 0.10)

	# Check crew traits for mitigation
	var trait_total: float = 0.0
	var mitigator_id: String = ""
	if game_state.player_ship != null and GameSession.crew_trait_system != null:
		trait_total = GameSession.crew_trait_system.get_bonus(game_state.player_ship, trait_key)
		# Find which crew member provides the trait
		for c in game_state.player_ship.crew:
			var crew_defn: Dictionary = GameSession.crew_trait_system.get_definition(c.trait_id)
			if crew_defn.is_empty():
				crew_defn = GameSession.crew_trait_system.get_definition(c.crew_id)
			var bonuses: Dictionary = crew_defn.get("trait_bonuses", {})
			if bonuses.get(trait_key, 0.0) > 0.0:
				mitigator_id = c.crew_id
				break

	var mitigated: bool = trait_total >= threshold

	# Dialogue bark
	var protagonist_id: String = game_state.protagonist_id
	var barks: Dictionary = defn.get("dialogue_barks", {}).get(protagonist_id, {})
	var bark: String = ""
	if mitigated:
		bark = barks.get("mitigated", "%s mitigated!" % defn.get("display_name", "Hazard"))
	else:
		bark = barks.get("failed", "%s struck the ship!" % defn.get("display_name", "Hazard"))

	var damage: int = 0
	var effect_applied: Dictionary = {}

	if mitigated:
		EventBus.hazard_mitigated.emit(hazard_id, mitigator_id)
	else:
		# Calculate damage
		var min_pct: float = defn.get("damage_min_pct", 0.0)
		var max_pct: float = defn.get("damage_max_pct", 0.20)
		var pct: float = randf_range(min_pct, max_pct)

		# Check hull_weakness status effect (next hazard +50%)
		if has_active_effect("hull_weakness"):
			pct *= 1.5
			_remove_effect("hull_weakness")

		if game_state.player_ship != null:
			damage = maxi(1, int(game_state.player_ship.max_hull * pct))
			apply_damage(game_state, damage)

		EventBus.hazard_damage.emit(hazard_id, damage)

		# Apply status effect
		var status_def = defn.get("status_effect")
		if status_def != null and status_def is Dictionary and not status_def.is_empty():
			var effect_id: String = status_def.get("effect_id", "")
			var duration: float = status_def.get("duration_seconds", 30.0)
			if not effect_id.is_empty():
				apply_status_effect(effect_id, duration, hazard_id)
				effect_applied = {"effect_id": effect_id, "duration": duration}

	EventBus.hazard_entered.emit(hazard_id, defn.get("category", "dynamic"))

	return {
		"mitigated": mitigated,
		"damage": damage,
		"bark": bark,
		"hazard_id": hazard_id,
		"display_name": defn.get("display_name", ""),
		"mitigator_id": mitigator_id,
		"status_effect": effect_applied,
	}


## -----------------------------------------------------------------------
## Damage application
## -----------------------------------------------------------------------

func apply_damage(game_state: GameStateData, damage: int) -> void:
	if game_state.player_ship == null:
		return
	game_state.player_ship.current_hull = maxi(0, game_state.player_ship.current_hull - damage)


## -----------------------------------------------------------------------
## Status effects
## -----------------------------------------------------------------------

func apply_status_effect(effect_id: String, duration: float, hazard_id: String = "") -> void:
	# Don't stack same effect — refresh duration
	for effect in status_effects:
		if effect["effect_id"] == effect_id:
			effect["remaining"] = duration
			return
	status_effects.append({
		"effect_id": effect_id,
		"remaining": duration,
		"hazard_id": hazard_id,
	})
	EventBus.hazard_status_applied.emit(effect_id, duration)


func _tick_status_effects(dt: float, game_state: GameStateData) -> void:
	var retained: Array = []
	for effect in status_effects:
		effect["remaining"] -= dt

		# Crystal drain: lose 1 crystal per 10s
		if effect["effect_id"] == "crystal_drain":
			var elapsed: float = effect.get("_drain_accum", 0.0) + dt
			if elapsed >= 10.0:
				elapsed -= 10.0
				game_state.crystal_inventory = maxi(0, game_state.crystal_inventory - 1)
			effect["_drain_accum"] = elapsed

		if effect["remaining"] > 0:
			retained.append(effect)
		else:
			EventBus.hazard_status_expired.emit(effect["effect_id"])

	status_effects = retained


func has_active_effect(effect_id: String) -> bool:
	for effect in status_effects:
		if effect["effect_id"] == effect_id:
			return true
	return false


func get_effect_remaining(effect_id: String) -> float:
	for effect in status_effects:
		if effect["effect_id"] == effect_id:
			return effect.get("remaining", 0.0)
	return 0.0


func _remove_effect(effect_id: String) -> void:
	var retained: Array = []
	for effect in status_effects:
		if effect["effect_id"] != effect_id:
			retained.append(effect)
	status_effects = retained


## -----------------------------------------------------------------------
## Serialization
## -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	var dynamic_dict: Dictionary = {}
	for region_id in active_dynamic:
		var arr: Array = []
		for h in active_dynamic[region_id]:
			arr.append(h.duplicate())
		dynamic_dict[region_id] = arr

	var effects_arr: Array = []
	for e in status_effects:
		effects_arr.append(e.duplicate())

	return {
		"entropy_timer": entropy_timer,
		"collision_cooldown": collision_cooldown,
		"active_dynamic": dynamic_dict,
		"status_effects": effects_arr,
	}


func load_from_dict(data: Dictionary) -> void:
	entropy_timer = data.get("entropy_timer", randf_range(ENTROPY_MIN, ENTROPY_MAX))
	collision_cooldown = data.get("collision_cooldown", 0.0)

	var dynamic_dict: Dictionary = data.get("active_dynamic", {})
	for region_id in dynamic_dict:
		active_dynamic[region_id] = []
		for h in dynamic_dict[region_id]:
			active_dynamic[region_id].append(h)

	status_effects.clear()
	for e in data.get("status_effects", []):
		status_effects.append(e)
