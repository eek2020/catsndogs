## Regression: Apr-05 #1 — trigger_encounter_id field removed.
## EncounterOutcome.from_dict must ignore legacy trigger_encounter_id keys in
## data without crashing and must not expose the field on the resulting object.
extends GutTest

func test_from_dict_rejects_trigger_encounter_id_field() -> void:
	var outcome := Encounter.EncounterOutcome.from_dict({
		"description": "test",
		"trigger_encounter_id": "legacy_field_should_be_ignored",
		"karma_delta": 5,
	})
	assert_eq(outcome.description, "test")
	assert_eq(outcome.karma_delta, 5)
	assert_false("trigger_encounter_id" in outcome, "dead field must not be restored")

func test_from_dict_minimal() -> void:
	var outcome := Encounter.EncounterOutcome.from_dict({})
	assert_eq(outcome.description, "")
	assert_eq(outcome.karma_delta, 0)
