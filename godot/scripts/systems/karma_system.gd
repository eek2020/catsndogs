## Karma system — global moral alignment tracking.
##
## Manages a sliding scale from -100 (Tyrant) to +100 (Paragon) alongside
## per-faction reputation. Player choices shift karma, which affects merchant
## prices, NPC behaviour, and world access.
class_name KarmaSystem
extends RefCounted

var _config: Dictionary = {}
var _tiers: Array = []
var _price_modifiers: Dictionary = {}
var _npc_offsets: Dictionary = {}
var _tier_colors: Dictionary = {}


func load_config(config_data: Dictionary) -> void:
	_config = config_data
	_tiers = config_data.get("tiers", [])
	_price_modifiers = config_data.get("price_modifiers", {})
	_npc_offsets = config_data.get("npc_disposition_offsets", {})
	_tier_colors = config_data.get("tier_colors", {})


## Change the player's karma score and emit signals.
func change_karma(game_state: GameStateData, delta: int, reason: String = "") -> void:
	if delta == 0:
		return
	var old_value: int = game_state.karma
	var old_tier: String = get_tier(game_state)
	game_state.karma = clampi(old_value + delta, -100, 100)
	game_state.karma_history.append({
		"delta": delta,
		"reason": reason,
		"old_value": old_value,
		"new_value": game_state.karma,
		"playtime": game_state.playtime_seconds,
	})
	EventBus.karma_changed.emit(old_value, game_state.karma, reason)
	var new_tier: String = get_tier(game_state)
	if old_tier != new_tier:
		EventBus.karma_tier_changed.emit(old_tier, new_tier)


## Return the current karma tier id (e.g. "neutral", "paragon").
func get_tier(game_state: GameStateData) -> String:
	var karma: int = game_state.karma
	for tier in _tiers:
		if karma >= tier.get("min", -100) and karma <= tier.get("max", 100):
			return tier.get("id", "neutral")
	return "neutral"


## Return the display label for the current tier.
func get_tier_label(game_state: GameStateData) -> String:
	var tier_id: String = get_tier(game_state)
	for tier in _tiers:
		if tier.get("id", "") == tier_id:
			return tier.get("label", tier_id.capitalize())
	return tier_id.capitalize()


## Return a price multiplier based on current karma tier.
## Values > 1.0 increase prices, < 1.0 decrease.
func get_price_modifier(game_state: GameStateData) -> float:
	var tier_id: String = get_tier(game_state)
	return _price_modifiers.get(tier_id, 1.0)


## Return an NPC disposition offset for the current karma tier.
## Positive values make NPCs more friendly, negative more hostile.
func get_npc_disposition_modifier(game_state: GameStateData) -> int:
	var tier_id: String = get_tier(game_state)
	return int(_npc_offsets.get(tier_id, 0))


## Return the hex colour string for the current karma tier.
func get_tier_color(game_state: GameStateData) -> String:
	var tier_id: String = get_tier(game_state)
	return _tier_colors.get(tier_id, "#aaaaaa")
