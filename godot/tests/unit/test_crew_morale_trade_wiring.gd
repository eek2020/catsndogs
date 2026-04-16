extends GutTest

## Regression coverage for Sprint 5b — crew morale wired into the trade
## pricing pipeline (EconomySystem.get_buy_price / get_sell_price /
## buy_crystals / sell_crystals).
##
## Semantics enforced by this suite:
##   - Low morale (modifier > 1.0) makes the player worse off on BOTH
##     buying and selling (pay more, sell for less).
##   - High morale (modifier < 1.0) makes the player better off on both
##     sides (pay less, sell for more).
##   - The default `morale_modifier = 1.0` must be a perfect no-op so
##     existing callers that predate Sprint 5b stay green.

var econ: EconomySystem
var state: GameStateData

const FACTION_ID: String = "test_faction"
const STARTING_SALVAGE: int = 100000
const STARTING_CRYSTALS: int = 500
const FACTION_RESERVES: int = 1000


func before_each() -> void:
	econ = EconomySystem.new()
	state = GameStateData.new()

	var ship := Ship.new()
	ship.crystal_capacity = 200  # Ship capacity = 200 × 10 = 2000 units
	state.player_ship = ship

	state.crystal_inventory = STARTING_CRYSTALS
	state.salvage = STARTING_SALVAGE

	var faction := Faction.new()
	faction.faction_id = FACTION_ID
	faction.crystal_reserves = FACTION_RESERVES
	faction.reputation_with_player = 0  # neutral reputation
	state.faction_registry[FACTION_ID] = faction

	state.crystal_market = CrystalDeposit.CrystalMarket.new()
	state.crystal_market.base_price = 100


# ---------------------------------------------------------------------------
# get_buy_price — low morale raises price, high morale lowers it
# ---------------------------------------------------------------------------

func test_buy_price_low_morale_higher_than_neutral() -> void:
	# MUTINY crew trade modifier = 1.1 → buy price up
	var neutral := econ.get_buy_price(state, FACTION_ID, 10)
	var low_morale := econ.get_buy_price(state, FACTION_ID, 10, 1.0, 1.1)
	assert_gt(low_morale, neutral)


func test_buy_price_high_morale_lower_than_neutral() -> void:
	# INSPIRED crew trade modifier = 0.9 → buy price down
	var neutral := econ.get_buy_price(state, FACTION_ID, 10)
	var high_morale := econ.get_buy_price(state, FACTION_ID, 10, 1.0, 0.9)
	assert_lt(high_morale, neutral)


func test_buy_price_default_param_is_neutral() -> void:
	# Backwards compatibility: omitting morale matches explicit 1.0.
	var implicit := econ.get_buy_price(state, FACTION_ID, 10)
	var explicit := econ.get_buy_price(state, FACTION_ID, 10, 1.0, 1.0)
	assert_eq(implicit, explicit)


func test_buy_price_karma_and_morale_compose() -> void:
	# Both modifiers should multiply — 1.1 karma × 1.1 morale = 1.21 total.
	var neutral := econ.get_buy_price(state, FACTION_ID, 100)
	var karma_only := econ.get_buy_price(state, FACTION_ID, 100, 1.1, 1.0)
	var both := econ.get_buy_price(state, FACTION_ID, 100, 1.1, 1.1)
	assert_gt(karma_only, neutral)
	assert_gt(both, karma_only)


# ---------------------------------------------------------------------------
# get_sell_price — low morale LOWERS sell revenue, high morale RAISES it
# ---------------------------------------------------------------------------

func test_sell_price_high_morale_higher_than_neutral() -> void:
	# INSPIRED crew negotiates better deals — more revenue.
	var neutral := econ.get_sell_price(state, FACTION_ID, 10)
	var high_morale := econ.get_sell_price(state, FACTION_ID, 10, 0.9)
	assert_gt(high_morale, neutral)


func test_sell_price_low_morale_lower_than_neutral() -> void:
	# MUTINY crew negotiates poorly — less revenue.
	var neutral := econ.get_sell_price(state, FACTION_ID, 10)
	var low_morale := econ.get_sell_price(state, FACTION_ID, 10, 1.1)
	assert_lt(low_morale, neutral)


func test_sell_price_default_param_is_neutral() -> void:
	var implicit := econ.get_sell_price(state, FACTION_ID, 10)
	var explicit := econ.get_sell_price(state, FACTION_ID, 10, 1.0)
	assert_eq(implicit, explicit)


# ---------------------------------------------------------------------------
# buy_crystals charges the morale-adjusted cost
# ---------------------------------------------------------------------------

func test_buy_crystals_charges_more_at_low_morale() -> void:
	var salvage_before_low: int = state.salvage
	econ.buy_crystals(state, FACTION_ID, 10, 1.1)
	var spent_low := salvage_before_low - state.salvage

	# Reset the relevant state — salvage, inventory, faction reserves — and
	# repeat the transaction at neutral morale.
	before_each()
	var salvage_before_neutral: int = state.salvage
	econ.buy_crystals(state, FACTION_ID, 10, 1.0)
	var spent_neutral := salvage_before_neutral - state.salvage

	assert_gt(spent_low, spent_neutral)


func test_buy_crystals_default_param_unchanged_behaviour() -> void:
	var salvage_before_default: int = state.salvage
	econ.buy_crystals(state, FACTION_ID, 10)
	var spent_default := salvage_before_default - state.salvage

	before_each()
	var salvage_before_explicit: int = state.salvage
	econ.buy_crystals(state, FACTION_ID, 10, 1.0)
	var spent_explicit := salvage_before_explicit - state.salvage

	assert_eq(spent_default, spent_explicit)


# ---------------------------------------------------------------------------
# sell_crystals grants the morale-adjusted revenue
# ---------------------------------------------------------------------------

func test_sell_crystals_grants_less_at_low_morale() -> void:
	var salvage_before_low: int = state.salvage
	econ.sell_crystals(state, FACTION_ID, 10, 1.1)
	var earned_low := state.salvage - salvage_before_low

	before_each()
	var salvage_before_neutral: int = state.salvage
	econ.sell_crystals(state, FACTION_ID, 10, 1.0)
	var earned_neutral := state.salvage - salvage_before_neutral

	assert_lt(earned_low, earned_neutral)


func test_sell_crystals_grants_more_at_high_morale() -> void:
	var salvage_before_high: int = state.salvage
	econ.sell_crystals(state, FACTION_ID, 10, 0.9)
	var earned_high := state.salvage - salvage_before_high

	before_each()
	var salvage_before_neutral: int = state.salvage
	econ.sell_crystals(state, FACTION_ID, 10, 1.0)
	var earned_neutral := state.salvage - salvage_before_neutral

	assert_gt(earned_high, earned_neutral)


# ---------------------------------------------------------------------------
# Sanity: transactions still succeed at non-neutral morale
# ---------------------------------------------------------------------------

func test_buy_crystals_succeeds_at_low_morale() -> void:
	var before_inventory: int = state.crystal_inventory
	var ok := econ.buy_crystals(state, FACTION_ID, 10, 1.1)
	assert_true(ok)
	assert_eq(state.crystal_inventory, before_inventory + 10)


func test_sell_crystals_succeeds_at_low_morale() -> void:
	var before_inventory: int = state.crystal_inventory
	var ok := econ.sell_crystals(state, FACTION_ID, 10, 1.1)
	assert_true(ok)
	assert_eq(state.crystal_inventory, before_inventory - 10)
