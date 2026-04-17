extends GutTest

## Regression: Sprint 5c part 2 / CODE_REVIEW §4.6 — crew morale pip on the
## navigation HUD. The pip colour must track CrewMoraleSystem's tier thresholds
## so the player reads the same tier the combat/trade multipliers actually use.


const MoralePipScript := preload("res://scripts/ui/hud/morale_pip.gd")


func test_color_for_morale_mutiny() -> void:
	assert_eq(MoralePipScript.color_for_morale(0), MoralePipScript.MUTINY)
	assert_eq(MoralePipScript.color_for_morale(CrewMoraleSystem.MUTINY_THRESHOLD),
		MoralePipScript.MUTINY)


func test_color_for_morale_low() -> void:
	assert_eq(MoralePipScript.color_for_morale(30), MoralePipScript.LOW)
	assert_eq(MoralePipScript.color_for_morale(CrewMoraleSystem.LOW_THRESHOLD),
		MoralePipScript.LOW)


func test_color_for_morale_steady() -> void:
	assert_eq(MoralePipScript.color_for_morale(55), MoralePipScript.STEADY)
	assert_eq(MoralePipScript.color_for_morale(CrewMoraleSystem.NEUTRAL_THRESHOLD),
		MoralePipScript.STEADY)


func test_color_for_morale_content() -> void:
	assert_eq(MoralePipScript.color_for_morale(75), MoralePipScript.CONTENT)
	assert_eq(MoralePipScript.color_for_morale(CrewMoraleSystem.HIGH_THRESHOLD),
		MoralePipScript.CONTENT)


func test_color_for_morale_inspired() -> void:
	assert_eq(MoralePipScript.color_for_morale(95), MoralePipScript.INSPIRED)
	assert_eq(MoralePipScript.color_for_morale(100), MoralePipScript.INSPIRED)


func test_set_morale_stores_value() -> void:
	var pip: MoralePip = MoralePipScript.new()
	pip.set_morale(42)
	assert_eq(pip.morale, 42)
	pip.free()
