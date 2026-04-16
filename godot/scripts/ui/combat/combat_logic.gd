## CombatLogic — pure turn-resolution functions for combat_ui.gd.
##
## Each function mutates the passed-in CombatShip (`current_hull` only) and
## returns a result Dictionary describing the outcome. No UI references, no
## EventBus calls — the caller is responsible for emitting signals from
## `event_signals` and routing `log_messages` into the combat log.
##
## An optional `rng` argument lets tests inject deterministic dodge / flee
## rolls. It is duck-typed as "anything with a `randf() -> float` method"
## so tests can pass a lightweight stub without subclassing the native
## `RandomNumberGenerator` (whose methods cannot be overridden in script).
## Damage variance still goes through CombatSystem and uses the global RNG
## — tests that need precise damage values should assert bounded ranges.
class_name CombatLogic
extends RefCounted


# ---------------------------------------------------------------------------
# Attack resolution — player attacks enemy
# ---------------------------------------------------------------------------

## Returns a Dictionary with:
## - hit: bool                           — true if the attack landed
## - damage: int                         — damage dealt on hit (0 on miss)
## - target_dead: bool                   — enemy hull reached 0 this round
## - log_messages: Array[String]         — lines to append to the combat log
## - event_signals: Array[StringName]    — EventBus signals to emit
static func resolve_player_attack(
	player: CombatSystem.CombatShip,
	enemy: CombatSystem.CombatShip,
	rng = null,
) -> Dictionary:
	var dodge := CombatSystem.dodge_chance(enemy.speed)
	var roll: float = rng.randf() if rng != null else randf()
	var hit: bool = roll >= dodge
	var log_msgs: Array[String] = []
	var events: Array[StringName] = []
	var damage := 0

	if not hit:
		log_msgs.append("%s dodges!" % enemy.ship_name)
		events.append(&"combat_miss")
	else:
		damage = CombatSystem.calculate_damage(player.firepower, enemy.armour)
		enemy.current_hull = maxi(0, enemy.current_hull - damage)
		log_msgs.append("You deal %d damage to %s!" % [damage, enemy.ship_name])
		events.append(&"combat_hit")

	var target_dead := enemy.current_hull <= 0
	if target_dead:
		log_msgs.append("%s destroyed!" % enemy.ship_name)
		events.append(&"combat_victory")

	return {
		"hit": hit,
		"damage": damage,
		"target_dead": target_dead,
		"log_messages": log_msgs,
		"event_signals": events,
	}


# ---------------------------------------------------------------------------
# Attack resolution — enemy attacks player
# ---------------------------------------------------------------------------

## Same shape as resolve_player_attack, from the enemy's perspective.
## `target_dead` here means the player ship reached 0 hull.
static func resolve_enemy_attack(
	player: CombatSystem.CombatShip,
	enemy: CombatSystem.CombatShip,
	rng = null,
) -> Dictionary:
	var dodge := CombatSystem.dodge_chance(player.speed)
	var roll: float = rng.randf() if rng != null else randf()
	var hit: bool = roll >= dodge
	var log_msgs: Array[String] = []
	var events: Array[StringName] = []
	var damage := 0

	if not hit:
		log_msgs.append("You dodge!")
		events.append(&"combat_miss")
	else:
		damage = CombatSystem.calculate_damage(enemy.firepower, player.armour)
		player.current_hull = maxi(0, player.current_hull - damage)
		log_msgs.append("%s deals %d damage!" % [enemy.ship_name, damage])
		events.append(&"combat_hit")

	var player_dead := player.current_hull <= 0
	if player_dead:
		log_msgs.append("Your ship is destroyed!")
		events.append(&"combat_defeat")

	return {
		"hit": hit,
		"damage": damage,
		"target_dead": player_dead,
		"log_messages": log_msgs,
		"event_signals": events,
	}


# ---------------------------------------------------------------------------
# Flee resolution
# ---------------------------------------------------------------------------

## Returns a Dictionary with:
## - success: bool
## - log_messages: Array[String]
## - event_signals: Array[StringName]
## - new_attempts: int                   — incremented attempt counter
##
## Each attempt raises flee chance by +15% (capped at 95%) — preserved from
## the legacy combat_ui.gd _on_flee logic.
static func resolve_flee(
	player: CombatSystem.CombatShip,
	enemy: CombatSystem.CombatShip,
	attempts: int,
	rng = null,
) -> Dictionary:
	var base_chance := float(player.speed) / maxf(1.0, float(player.speed + enemy.speed))
	var flee_chance := minf(0.95, base_chance + attempts * 0.15)
	var roll: float = rng.randf() if rng != null else randf()
	var success: bool = roll < flee_chance
	var log_msgs: Array[String] = []
	var events: Array[StringName] = []

	if success:
		log_msgs.append("You escaped!")
		events.append(&"combat_flee")
	else:
		log_msgs.append("Failed to flee!")

	return {
		"success": success,
		"log_messages": log_msgs,
		"event_signals": events,
		"new_attempts": attempts + 1,
	}
