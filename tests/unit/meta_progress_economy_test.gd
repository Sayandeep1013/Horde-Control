extends GdUnitTestSuite

## MetaProgress economy tests (Meta layer core, build brief item 6):
## adjacency/visibility, buy/refuse/max, respec refund, Core wallet cap.
## docs/18 section 4.1: "A node can be bought once EVERY node in its
## prerequisite_ids is owned"; is_visible() reveals a node once it is owned
## or any one prerequisite is owned. Every test redirects MetaProgress to a
## throwaway directory first (hard constraint).

var _dir: String


func before_test() -> void:
	_dir = "user://__meta_test_economy_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")


func _grant_cores(amount: int) -> void:
	# The only production route to Cores is settle_run() -- used here as a
	# plain test fixture, matching the real economy loop rather than poking
	# a private field.
	var sim_minutes: float = float(amount) * 60.0 # 1 Core/minute at 0 waves/0 kills/no victory is the simplest exact-amount fixture
	MetaProgress.settle_run({
		"run_id": "grant_%d_%d" % [amount, randi()],
		"sim_time_seconds": sim_minutes, "waves_cleared": 0, "kills": 0,
		"victory": false, "abandoned": false,
	})


# --- Visibility / adjacency (docs/18 section 4.1) ----------------------------

func test_root_is_always_visible() -> void:
	assert_bool(MetaProgress.is_visible("root")).is_true()


func test_a_tier_1_node_is_visible_because_root_is_always_owned() -> void:
	assert_bool(MetaProgress.is_visible("vitality")).append_failure_message("every tier-1 node names 'root' as its prerequisite, and the root is always owned").is_true()


func test_a_tier_2_node_is_hidden_until_its_tier_1_parent_is_owned() -> void:
	assert_bool(MetaProgress.is_visible("sharpened_arrows")).append_failure_message("sharpened_arrows' only prerequisite (vitality) is not yet owned").is_false()
	_grant_cores(5)
	assert_bool(MetaProgress.buy("vitality")).is_true()
	assert_bool(MetaProgress.is_visible("sharpened_arrows")).append_failure_message("owning vitality (sharpened_arrows' prerequisite) should reveal it").is_true()


## FALSIFICATION (named in the report): temporarily changing is_visible()'s
## "any prerequisite owned" check to "the node itself owned" (removing the
## prerequisite loop) made this test fail (sharpened_arrows stayed hidden
## after vitality was bought). Reverted after confirming the failure.
func test_a_tier_3_convergence_node_needs_both_tier_2_prerequisites_to_be_buyable() -> void:
	_grant_cores(200)
	assert_bool(MetaProgress.buy("vitality")).is_true()
	assert_bool(MetaProgress.buy("sharpened_arrows")).is_true()
	assert_bool(MetaProgress.can_buy("long_reach")).append_failure_message("long_reach needs BOTH sharpened_arrows and quick_draw owned, not just one").is_false()
	assert_bool(MetaProgress.buy("swift_boots")).is_true()
	assert_bool(MetaProgress.buy("quick_draw")).is_true()
	assert_bool(MetaProgress.can_buy("long_reach")).append_failure_message("both prerequisites are now owned; long_reach should be buyable").is_true()


# --- Buy / refuse / max -------------------------------------------------------

func test_buy_refuses_when_cores_are_insufficient() -> void:
	assert_int(MetaProgress.get_cores()).is_equal(0)
	assert_bool(MetaProgress.can_buy("vitality")).is_false()
	assert_bool(MetaProgress.buy("vitality")).append_failure_message("buy() must refuse and change nothing when Cores are insufficient").is_false()
	assert_int(MetaProgress.get_rank("vitality")).is_equal(0)


func test_buy_succeeds_and_debits_exactly_the_priced_amount() -> void:
	_grant_cores(100)
	var price: int = MetaProgress.price_of_next_rank("vitality")
	var cores_before: int = MetaProgress.get_cores()
	assert_bool(MetaProgress.buy("vitality")).is_true()
	assert_int(MetaProgress.get_rank("vitality")).is_equal(1)
	assert_int(MetaProgress.get_cores()).is_equal(cores_before - price)


func test_buy_refuses_past_max_rank() -> void:
	_grant_cores(200)
	for i in 3:
		assert_bool(MetaProgress.buy("vitality")).is_true() # Vitality's authored max_rank is 3
	assert_int(MetaProgress.get_rank("vitality")).is_equal(3)
	assert_bool(MetaProgress.can_buy("vitality")).append_failure_message("a maxed node must refuse a further purchase").is_false()
	assert_bool(MetaProgress.buy("vitality")).is_false()
	assert_int(MetaProgress.get_rank("vitality")).is_equal(3)


func test_buy_refuses_an_unknown_node_id() -> void:
	_grant_cores(100)
	assert_bool(MetaProgress.buy("not_a_real_node")).is_false()


func test_buy_refuses_the_root() -> void:
	_grant_cores(100)
	assert_bool(MetaProgress.can_buy("root")).append_failure_message("the root is always owned and free -- it must never be purchasable").is_false()
	assert_bool(MetaProgress.buy("root")).is_false()


# --- Respec (decision D111: free and full) -----------------------------------

func test_respec_refunds_every_core_ever_spent_and_clears_ranks() -> void:
	_grant_cores(200)
	MetaProgress.buy("vitality")
	MetaProgress.buy("vitality") # rank 2
	MetaProgress.buy("swift_boots")
	var cores_after_buys: int = MetaProgress.get_cores()
	var expected_refund: int = SkillNodeDefinition.price_for_rank(1, 1) + SkillNodeDefinition.price_for_rank(1, 2) + SkillNodeDefinition.price_for_rank(1, 1)

	var refunded: int = MetaProgress.respec()

	assert_int(refunded).append_failure_message("respec() must refund the FULL Core cost of every rank ever bought").is_equal(expected_refund)
	assert_int(MetaProgress.get_cores()).is_equal(cores_after_buys + expected_refund)
	assert_int(MetaProgress.get_rank("vitality")).is_equal(0)
	assert_int(MetaProgress.get_rank("swift_boots")).is_equal(0)


func test_respec_with_nothing_owned_is_a_harmless_no_op() -> void:
	assert_int(MetaProgress.respec()).is_equal(0)


# --- Core wallet cap (Register > "Meta: Skill Tree costs": "clamped at 999,999") --

func test_core_wallet_is_clamped_at_the_register_cap() -> void:
	MetaProgress.settle_run({
		"run_id": "overflow_run", "sim_time_seconds": 2000000.0 * 60.0, # far more than the 999,999 cap in raw minutes
		"waves_cleared": 0, "kills": 0, "victory": false, "abandoned": false,
	})
	assert_int(MetaProgress.get_cores()).append_failure_message("a settlement requesting more Cores than the cap allows must clamp, not overflow").is_equal(999999)
