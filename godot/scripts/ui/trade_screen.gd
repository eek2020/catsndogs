## Trade screen — buy/sell crystals with a faction.
## Mirrors Python ui/trade_screen.py TradeScreenState.
extends Control

@onready var info_label: Label = $Panel/VBox/InfoLabel
@onready var buy_btn: Button = $Panel/VBox/BuyBtn
@onready var sell_btn: Button = $Panel/VBox/SellBtn
@onready var close_btn: Button = $Panel/VBox/CloseBtn

var faction_id: String = ""


func _ready() -> void:
	buy_btn.pressed.connect(_on_buy)
	sell_btn.pressed.connect(_on_sell)
	close_btn.pressed.connect(_on_close)
	close_btn.grab_focus()
	_refresh()


func setup(p_faction_id: String) -> void:
	faction_id = p_faction_id
	_refresh()


func _on_buy() -> void:
	if GameSession.game_state == null:
		return
	GameSession.economy_system.buy_crystals(GameSession.game_state, faction_id, 5)
	_refresh()


func _on_sell() -> void:
	if GameSession.game_state == null:
		return
	GameSession.economy_system.sell_crystals(GameSession.game_state, faction_id, 5)
	_refresh()


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()


func _refresh() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return
	info_label.text = "Crystals: %d | Salvage: %d" % [gs.crystal_inventory, gs.salvage]
