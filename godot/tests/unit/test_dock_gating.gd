extends GutTest

## Regression coverage for Sprint 5c — star-base docking gated by
## `RealmControlSystem.controlling_faction` on top of the pre-existing
## stronghold reputation gate.
##
## Semantics enforced by this suite:
##   - Strongholds: required_reputation still gates as before.
##   - Any base type: if the region's realm controller is NOT the base's
##     controlling_faction AND the controller despises the player
##     (rep < HOSTILE_DOCK_REPUTATION_THRESHOLD = -50), docking is blocked
##     with a "Blockaded by <faction>" reason.
##   - `realm_control == null` leaves behaviour identical to pre-5c
##     (backwards compatible).

var system: StarBaseSystem
var realm_control: RealmControlSystem
var state: GameStateData

const REGION_ID: String = "starting_realm"
const BASE_ID: String = "outpost_alpha"
const OWNER_ID: String = "friendly_corsairs"
const INVADER_ID: String = "hostile_raiders"


func before_each() -> void:
	system = StarBaseSystem.new()
	realm_control = RealmControlSystem.new()
	state = GameStateData.new()

	var owner_fac := Faction.new()
	owner_fac.faction_id = OWNER_ID
	owner_fac.faction_name = "Friendly Corsairs"
	owner_fac.realm = REGION_ID
	owner_fac.reputation_with_player = 0
	state.faction_registry[OWNER_ID] = owner_fac

	var invader := Faction.new()
	invader.faction_id = INVADER_ID
	invader.faction_name = "Hostile Raiders"
	invader.realm = REGION_ID
	invader.reputation_with_player = -100  # hostile
	state.faction_registry[INVADER_ID] = invader

	state.current_region = REGION_ID

	var base := StarBase.new()
	base.base_id = BASE_ID
	base.base_name = "Outpost Alpha"
	base.base_type = "open"
	base.region_id = REGION_ID
	base.controlling_faction = OWNER_ID
	system.load_bases([base.to_dict()])


# ---------------------------------------------------------------------------
# Backwards compatibility — no realm_control set
# ---------------------------------------------------------------------------

func test_open_base_allows_dock_when_realm_control_unset() -> void:
	# Pre-5c behaviour preserved when realm_control is null.
	assert_eq(system.realm_control, null)
	assert_true(system.can_dock(state, BASE_ID))
	assert_eq(system.get_dock_block_reason(state, BASE_ID), "")


# ---------------------------------------------------------------------------
# Stronghold reputation gate (pre-5c behaviour, still enforced)
# ---------------------------------------------------------------------------

func test_stronghold_blocks_dock_when_rep_below_required() -> void:
	var base: StarBase = system.get_base(BASE_ID)
	base.base_type = "stronghold"
	base.required_reputation = 50
	var owner_fac: Faction = state.faction_registry[OWNER_ID]
	owner_fac.reputation_with_player = 10
	assert_false(system.can_dock(state, BASE_ID))
	var reason := system.get_dock_block_reason(state, BASE_ID)
	assert_true(reason.find("Refused") >= 0, "Expected 'Refused' in: %s" % reason)


func test_stronghold_allows_dock_when_rep_meets_threshold() -> void:
	var base: StarBase = system.get_base(BASE_ID)
	base.base_type = "stronghold"
	base.required_reputation = 20
	var owner_fac: Faction = state.faction_registry[OWNER_ID]
	owner_fac.reputation_with_player = 50
	assert_true(system.can_dock(state, BASE_ID))


# ---------------------------------------------------------------------------
# Realm-control gate (new in 5c)
# ---------------------------------------------------------------------------

func test_realm_control_blocks_dock_when_hostile_controller() -> void:
	system.realm_control = realm_control
	# Invader has seized the region.
	realm_control.add_influence(REGION_ID, INVADER_ID, 100.0)
	assert_false(system.can_dock(state, BASE_ID))
	var reason := system.get_dock_block_reason(state, BASE_ID)
	assert_true(reason.find("Blockaded") >= 0, "Expected 'Blockaded' in: %s" % reason)
	assert_true(reason.find("Hostile Raiders") >= 0, "Expected faction name in: %s" % reason)


func test_realm_control_allows_dock_when_controller_matches_base_owner() -> void:
	system.realm_control = realm_control
	# Owner still dominates the region — no blockade.
	realm_control.add_influence(REGION_ID, OWNER_ID, 100.0)
	assert_true(system.can_dock(state, BASE_ID))


func test_realm_control_allows_dock_when_hostile_controller_barely_not_hostile() -> void:
	# Controller is different but their rep is above the hostile threshold.
	var invader: Faction = state.faction_registry[INVADER_ID]
	invader.reputation_with_player = -10  # unfriendly but not hostile
	system.realm_control = realm_control
	realm_control.add_influence(REGION_ID, INVADER_ID, 100.0)
	assert_true(system.can_dock(state, BASE_ID))


func test_realm_control_gate_ignored_when_region_unclaimed() -> void:
	system.realm_control = realm_control
	# No influence recorded for this region — controller is empty string.
	assert_eq(realm_control.get_region_controller(REGION_ID), "")
	assert_true(system.can_dock(state, BASE_ID))


func test_get_dock_block_reason_unknown_base_returns_message() -> void:
	var reason := system.get_dock_block_reason(state, "does_not_exist")
	assert_eq(reason, "Unknown base")


func test_can_dock_matches_get_dock_block_reason_emptiness() -> void:
	# Invariant: can_dock and get_dock_block_reason stay in sync.
	system.realm_control = realm_control
	realm_control.add_influence(REGION_ID, INVADER_ID, 100.0)
	assert_false(system.can_dock(state, BASE_ID))
	assert_false(system.get_dock_block_reason(state, BASE_ID).is_empty())
