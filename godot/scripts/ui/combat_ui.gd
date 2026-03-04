## Combat UI — turn-based combat with attack/flee.
## Mirrors Python ui/combat_ui.py CombatState.
extends Control

@onready var player_hull_label: Label = $VBox/PlayerHull
@onready var enemy_hull_label: Label = $VBox/EnemyHull
@onready var combat_log: RichTextLabel = $VBox/CombatLog
@onready var attack_btn: Button = $VBox/Actions/AttackBtn
@onready var flee_btn: Button = $VBox/Actions/FleeBtn

var player_ship: CombatSystem.CombatShip = null
var enemy_ship: CombatSystem.CombatShip = null
var log: CombatSystem.CombatLog = null
var _player_turn: bool = true


func _ready() -> void:
	log = CombatSystem.CombatLog.new()
	attack_btn.pressed.connect(_on_attack)
	flee_btn.pressed.connect(_on_flee)
	attack_btn.grab_focus()
	_refresh_ui()


func setup(p_player: CombatSystem.CombatShip, p_enemy: CombatSystem.CombatShip) -> void:
	player_ship = p_player
	enemy_ship = p_enemy
	_refresh_ui()


func _on_attack() -> void:
	if player_ship == null or enemy_ship == null:
		return
	# Player attacks
	var dodge := CombatSystem.dodge_chance(enemy_ship.speed)
	if randf() < dodge:
		log.add("%s dodged!" % enemy_ship.ship_name)
		EventBus.combat_miss.emit()
	else:
		var dmg := CombatSystem.calculate_damage(player_ship.firepower, enemy_ship.armour)
		enemy_ship.current_hull = maxi(0, enemy_ship.current_hull - dmg)
		log.add("You hit %s for %d damage." % [enemy_ship.ship_name, dmg])
		EventBus.combat_hit.emit()
	if enemy_ship.current_hull <= 0:
		log.add("Enemy destroyed!")
		EventBus.combat_victory.emit()
		_end_combat("victory")
		return
	# Enemy attacks
	dodge = CombatSystem.dodge_chance(player_ship.speed)
	if randf() < dodge:
		log.add("You dodged!")
		EventBus.combat_miss.emit()
	else:
		var dmg := CombatSystem.calculate_damage(enemy_ship.firepower, player_ship.armour)
		player_ship.current_hull = maxi(0, player_ship.current_hull - dmg)
		log.add("%s hit you for %d damage." % [enemy_ship.ship_name, dmg])
		EventBus.combat_hit.emit()
	if player_ship.current_hull <= 0:
		log.add("Your ship is destroyed!")
		EventBus.combat_defeat.emit()
		_end_combat("defeat")
		return
	_refresh_ui()


func _on_flee() -> void:
	var flee_chance := clampf(player_ship.speed * 0.08, 0.1, 0.8) if player_ship else 0.5
	if randf() < flee_chance:
		log.add("Escaped!")
		EventBus.combat_flee.emit()
		_end_combat("flee")
	else:
		log.add("Failed to flee!")
		# Enemy gets a free attack
		if enemy_ship and player_ship:
			var dmg := CombatSystem.calculate_damage(enemy_ship.firepower, player_ship.armour)
			player_ship.current_hull = maxi(0, player_ship.current_hull - dmg)
			log.add("%s hit you for %d." % [enemy_ship.ship_name, dmg])
			if player_ship.current_hull <= 0:
				EventBus.combat_defeat.emit()
				_end_combat("defeat")
				return
		_refresh_ui()


func _end_combat(result: String) -> void:
	attack_btn.disabled = true
	flee_btn.disabled = true
	_refresh_ui()
	# Return to previous screen after brief delay
	await get_tree().create_timer(1.5).timeout
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()


func _refresh_ui() -> void:
	if player_ship:
		player_hull_label.text = "Your Hull: %d/%d" % [player_ship.current_hull, player_ship.max_hull]
	if enemy_ship:
		enemy_hull_label.text = "Enemy Hull: %d/%d" % [enemy_ship.current_hull, enemy_ship.max_hull]
	if log:
		combat_log.text = "\n".join(log.entries)
