## Station screen — docked base service menu overlay.
##
## Displayed when the player docks at a star base. Shows available services
## (refuel, repair, trade, salvage drop-off, artifact market) and an undock button.
extends Control

@onready var title_label: Label = $Panel/VBox/Title
@onready var desc_label: RichTextLabel = $Panel/VBox/Desc
@onready var service_container: VBoxContainer = $Panel/VBox/ServiceContainer
@onready var artifact_container: VBoxContainer = $Panel/VBox/ArtifactContainer
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var undock_btn: Button = $Panel/VBox/UndockBtn

var _base_id: String = ""


func _ready() -> void:
	undock_btn.pressed.connect(_on_undock)

	var gs: GameStateData = GameSession.game_state
	if gs == null or gs.docked_base_id.is_empty():
		return
	_base_id = gs.docked_base_id
	var base: StarBase = GameSession.star_base_system.get_base(_base_id)
	if base == null:
		return

	title_label.text = base.base_name.to_upper()
	desc_label.bbcode_enabled = true
	desc_label.text = "[color=#c8d0dc]%s[/color]" % base.description

	_build_services(gs, base)
	_build_artifacts(gs)
	status_label.text = ""

	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	undock_btn.grab_focus()


func _build_services(gs: GameStateData, base: StarBase) -> void:
	var services: Array = GameSession.star_base_system.get_available_services(gs, _base_id)
	for service_id in services:
		var btn := Button.new()
		match service_id:
			"refuel":
				btn.text = "Refuel (5 salvage)"
				btn.pressed.connect(_on_refuel)
			"repair":
				var repair_needed: int = gs.player_ship.max_hull - gs.player_ship.current_hull if gs.player_ship else 0
				var cost: int = GameSession.economy_system.calculate_repair_cost(gs.player_ship, repair_needed) if repair_needed > 0 else 0
				btn.text = "Repair Hull (%d salvage)" % cost
				btn.pressed.connect(_on_repair)
				btn.disabled = (repair_needed <= 0)
			"trade":
				btn.text = "Open Trade"
				btn.pressed.connect(_on_trade.bind(base.controlling_faction))
			"salvage_dropoff":
				btn.text = "Drop Off Salvage"
				btn.pressed.connect(_on_salvage_dropoff)
			"artifact_market":
				btn.text = "Artifact Market"
				# Artifacts built separately below
				btn.visible = false
			_:
				btn.text = service_id.replace("_", " ").capitalize()
		service_container.add_child(btn)


func _build_artifacts(gs: GameStateData) -> void:
	var artifacts: Array = GameSession.star_base_system.get_available_artifacts(gs, _base_id)
	if artifacts.is_empty():
		return
	var header := Label.new()
	header.text = "ARTIFACTS"
	header.add_theme_color_override("font_color", Color(0.94, 0.75, 0.25))
	artifact_container.add_child(header)
	for artifact_data in artifacts:
		var btn := Button.new()
		var aid: String = artifact_data.get("artifact_id", "")
		var cost_c: int = artifact_data.get("cost_crystals", 0)
		var cost_s: int = artifact_data.get("cost_salvage", 0)
		btn.text = "%s (%dC / %dS)" % [artifact_data.get("name", aid), cost_c, cost_s]
		btn.tooltip_text = artifact_data.get("description", "")
		btn.pressed.connect(_on_buy_artifact.bind(aid))
		var can_afford: bool = gs.crystal_inventory >= cost_c and gs.salvage >= cost_s
		btn.disabled = not can_afford
		artifact_container.add_child(btn)


func _on_refuel() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null or gs.salvage < 5:
		status_label.text = "Not enough salvage!"
		return
	gs.salvage -= 5
	gs.crystal_inventory += 10
	EventBus.crystal_pickup.emit()
	status_label.text = "Refueled! +10 crystals"


func _on_repair() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null or gs.player_ship == null:
		return
	var repair_amount: int = gs.player_ship.max_hull - gs.player_ship.current_hull
	if repair_amount <= 0:
		status_label.text = "Hull already at full!"
		return
	if GameSession.economy_system.repair_ship(gs, repair_amount):
		status_label.text = "Hull fully repaired!"
		EventBus.ship_repaired.emit(gs.player_ship.current_hull, gs.player_ship.max_hull)
	else:
		status_label.text = "Not enough salvage for repairs!"


func _on_trade(faction_id: String) -> void:
	GameSession.open_trade_screen(faction_id)
	var main: Control = get_tree().current_scene
	if main.has_method("replace_overlay"):
		main.replace_overlay(self, "trade")


func _on_salvage_dropoff() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		return
	# Convert any excess crystal cargo to salvage
	if gs.crystal_inventory > 0:
		var reward: int = maxi(1, gs.crystal_inventory * 2)
		gs.salvage += reward
		gs.crystal_inventory = 0
		status_label.text = "Dropped off crystals! +%d salvage" % reward
		EventBus.salvage_pickup.emit()
	else:
		status_label.text = "No crystals to drop off."


func _on_buy_artifact(artifact_id: String) -> void:
	if GameSession.star_base_system.purchase_artifact(GameSession.game_state, _base_id, artifact_id):
		status_label.text = "Artifact acquired!"
		# Rebuild artifact buttons
		for child in artifact_container.get_children():
			child.queue_free()
		_build_artifacts(GameSession.game_state)
	else:
		status_label.text = "Cannot purchase artifact."


func _on_undock() -> void:
	GameSession.star_base_system.undock(GameSession.game_state)
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
