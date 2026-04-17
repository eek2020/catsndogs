## CombatTransition — turns an encounter + choice into a live combat overlay.
## Owned by dialogue_ui.gd. All GameSession reads flow through the injected
## DialogueViewModel, so tests can exercise enemy-faction derivation without
## the autoload.
class_name DialogueCombatTransition
extends RefCounted


const DEFAULT_ENEMY_FACTION: String = "canis_league"
const DEFAULT_TEMPLATE_ID: String = "league_cruiser"


var _vm  # DialogueViewModel — null-guarded on every access for test doubles.


func _init(vm) -> void:
	_vm = vm


## Start combat from a legacy single-step encounter choice.
## `choice.outcome.faction_changes` names the enemy faction.
func start_legacy_combat(
	encounter, choice, source_overlay: Control
) -> void:
	var enemy_faction: String = DEFAULT_ENEMY_FACTION
	for faction_id in choice.outcome.faction_changes.keys():
		enemy_faction = String(faction_id)
		break
	_do_transition(enemy_faction, source_overlay)


## Start combat from a multi-step dialogue step flagged `start_combat`.
## Derives the enemy faction from the encounter's `npc_ids` against the
## faction registry.
func start_encounter_combat(encounter, source_overlay: Control) -> void:
	var enemy_faction: String = _derive_faction_from_encounter(encounter)
	_do_transition(enemy_faction, source_overlay)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _derive_faction_from_encounter(encounter) -> String:
	if encounter == null or _vm == null:
		return DEFAULT_ENEMY_FACTION
	var registry: Dictionary = _vm.faction_registry()
	for npc_id in encounter.npc_ids:
		if npc_id.to_lower() == _vm.protagonist_id():
			continue
		for faction_id in registry:
			var faction: Faction = registry[faction_id]
			if faction.faction_id == npc_id \
					or faction.faction_name.to_lower().find(npc_id) >= 0:
				return faction_id
		break
	return DEFAULT_ENEMY_FACTION


func _do_transition(enemy_faction: String, source_overlay: Control) -> void:
	if _vm == null or not _vm.has_state():
		return
	var player_ship = _vm.player_ship()
	if player_ship == null:
		return
	var templates: Dictionary = _vm.ship_templates()
	var faction: Faction = _vm.faction(enemy_faction)
	var template_id: String = DEFAULT_TEMPLATE_ID
	if faction != null and not faction.ship_template_id.is_empty():
		template_id = faction.ship_template_id
	var enemy_template: Dictionary = templates.get(
		template_id, templates.get(DEFAULT_TEMPLATE_ID, {})
	)

	var enemy_name := "Enemy Ship"
	if faction != null:
		enemy_name = "%s Ship" % faction.faction_name

	var combat_player = CombatSystem.CombatShip.from_game_ship(player_ship, true)
	var enemy_ship = CombatSystem.CombatShip.from_template(
		enemy_template, enemy_name, enemy_faction
	)

	var main: Control = source_overlay.get_tree().current_scene
	if main.has_method("replace_overlay"):
		var combat_overlay: Control = main.replace_overlay(source_overlay, "combat")
		if combat_overlay and combat_overlay.has_method("setup"):
			combat_overlay.setup(combat_player, enemy_ship)
		return

	if not main.has_method("pop_overlay") or not main.has_method("push_overlay"):
		return

	main.pop_overlay()
	await source_overlay.get_tree().create_timer(0.16).timeout
	var combat_screen: Control = main.push_overlay("combat")
	if combat_screen and combat_screen.has_method("setup"):
		combat_screen.setup(combat_player, enemy_ship)
