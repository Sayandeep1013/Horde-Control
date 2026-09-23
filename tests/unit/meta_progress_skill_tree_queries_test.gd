extends GdUnitTestSuite

## Tests for the three minimal read-only queries the Hub/Skill Tree screen
## session added to MetaProgress: `prerequisites_met()` (distinguishes
## "revealed but a prerequisite still missing" from "prerequisites met but
## unaffordable" -- docs/18 section 4.1), `get_respec_refund_preview()`
## (docs/18 section 4.5's "shows the refund amount" before the hold
## completes), and `get_lifetime_cores()` (the Records panel's own "lifetime
## Cores earned" -- docs/18 section 5). None of the three mutate anything;
## every test still redirects MetaProgress to a throwaway directory first
## (hard constraint).

var _dir: String


func before_test() -> void:
	_dir = "user://__meta_test_queries_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")


func _grant_cores(amount: int) -> void:
	MetaProgress.settle_run({
		"run_id": "grant_%d_%d" % [amount, randi()],
		"sim_time_seconds": float(amount) * 60.0, "waves_cleared": 0, "kills": 0,
		"victory": false, "abandoned": false,
	})


# --- prerequisites_met() -------------------------------------------------------

func test_prerequisites_met_is_true_for_the_root() -> void:
	assert_bool(MetaProgress.prerequisites_met("root")).is_true()


func test_prerequisites_met_is_true_for_a_tier_1_node_since_the_root_is_always_owned() -> void:
	assert_bool(MetaProgress.prerequisites_met("vitality")).is_true()


func test_prerequisites_met_is_false_for_a_convergence_node_missing_one_sibling() -> void:
	_grant_cores(200)
	MetaProgress.buy("vitality")
	MetaProgress.buy("sharpened_arrows")
	assert_bool(MetaProgress.prerequisites_met("long_reach")).append_failure_message("long_reach needs BOTH sharpened_arrows and quick_draw; only one is owned").is_false()
	MetaProgress.buy("swift_boots")
	MetaProgress.buy("quick_draw")
	assert_bool(MetaProgress.prerequisites_met("long_reach")).is_true()


func test_prerequisites_met_distinguishes_locked_from_merely_unaffordable() -> void:
	# sharpened_arrows: prerequisite (vitality) unmet AND unaffordable (0 Cores) --
	# prerequisites_met() must report the PREREQUISITE state, independent of cores.
	assert_bool(MetaProgress.prerequisites_met("sharpened_arrows")).is_false()
	_grant_cores(5)
	MetaProgress.buy("vitality") # reveals sharpened_arrows and satisfies its one prerequisite
	assert_bool(MetaProgress.prerequisites_met("sharpened_arrows")).append_failure_message("sharpened_arrows' only prerequisite is now owned -- it must report met even with 0 Cores left").is_true()
	assert_bool(MetaProgress.can_buy("sharpened_arrows")).append_failure_message("0 Cores left after buying vitality -- can_buy() must still refuse").is_false()


func test_prerequisites_met_is_true_for_an_unknown_id() -> void:
	assert_bool(MetaProgress.prerequisites_met("not_a_real_node")).is_true()


# --- get_respec_refund_preview() -----------------------------------------------

func test_respec_refund_preview_is_zero_with_nothing_owned() -> void:
	assert_int(MetaProgress.get_respec_refund_preview()).is_equal(0)


func test_respec_refund_preview_matches_respec_own_refund_exactly() -> void:
	_grant_cores(200)
	MetaProgress.buy("vitality")
	MetaProgress.buy("vitality")
	MetaProgress.buy("swift_boots")
	var expected: int = SkillNodeDefinition.price_for_rank(1, 1) + SkillNodeDefinition.price_for_rank(1, 2) + SkillNodeDefinition.price_for_rank(1, 1)
	assert_int(MetaProgress.get_respec_refund_preview()).is_equal(expected)

	var actual_refund: int = MetaProgress.respec()
	assert_int(actual_refund).append_failure_message("the preview must match respec()'s own real refund exactly").is_equal(expected)


func test_respec_refund_preview_never_mutates_state() -> void:
	_grant_cores(50)
	MetaProgress.buy("vitality")
	var cores_before: int = MetaProgress.get_cores()
	var rank_before: int = MetaProgress.get_rank("vitality")
	MetaProgress.get_respec_refund_preview()
	MetaProgress.get_respec_refund_preview()
	assert_int(MetaProgress.get_cores()).is_equal(cores_before)
	assert_int(MetaProgress.get_rank("vitality")).is_equal(rank_before)


# --- get_lifetime_cores() -------------------------------------------------------

func test_lifetime_cores_starts_at_zero() -> void:
	assert_int(MetaProgress.get_lifetime_cores()).is_equal(0)


func test_lifetime_cores_accumulates_across_settlements_and_survives_spending() -> void:
	_grant_cores(20)
	_grant_cores(30)
	assert_int(MetaProgress.get_lifetime_cores()).is_equal(50)
	MetaProgress.buy("vitality") # spending the wallet must not reduce the lifetime total
	assert_int(MetaProgress.get_lifetime_cores()).is_equal(50)


# --- Frozen loadout: bonuses never change mid-run (docs/18 section 6) ----------

## docs/18 section 6 edge case: "Meta bonuses mid-run: Never. Loadout is
## computed once at run start and frozen for the run." `build_run_loadout()`
## is called exactly once, at run start (`PrototypeIntegration._ready()`);
## nothing re-reads `MetaProgress` afterward to refresh an already-built
## `MetaLoadout`. This proves the ARCHITECTURE actually holds that
## guarantee: a `MetaLoadout` returned before a purchase is a plain snapshot
## whose fields never move, however much `MetaProgress`'s own live ranks
## change afterward -- there is no live binding, callable, or getter
## anywhere on `MetaLoadout` that could re-read `MetaProgress` on a later
## access (see that file's own header: "a plain, immutable-by-convention
## data holder").
##
## FALSIFICATION (named in the report): temporarily replacing `MetaLoadout.
## player_max_health_bonus`'s plain `float` field with a computed getter
## that re-read `MetaProgress.get_rank("vitality")` live (simulating the bug
## this test guards against) made the final assertion fail (0.20 instead of
## the frozen 0.10). Reverted after confirming the failure.
func test_a_loadout_already_built_is_never_recomputed_by_a_later_tree_change() -> void:
	_grant_cores(200)
	assert_bool(MetaProgress.buy("vitality")).is_true() # rank 1 of 3, +10% each

	var loadout: MetaLoadout = MetaProgress.build_run_loadout()
	assert_float(loadout.player_max_health_bonus).is_equal_approx(0.10, 0.001)

	# Buying MORE ranks after the loadout is already in a run's hands must
	# never retroactively change it -- this is what "buying ... during a run
	# is impossible" (docs/18 section 6) protects against structurally: the
	# Skill Tree screen exists only in the Hub, never during a run, but this
	# proves the SNAPSHOT itself is also inert even if something else were
	# to call MetaProgress mid-run.
	assert_bool(MetaProgress.buy("vitality")).is_true() # rank 2, +20% total
	MetaProgress.respec() # even a full reset must not reach back into the already-built snapshot

	assert_float(loadout.player_max_health_bonus).append_failure_message("a MetaLoadout already handed to a run must be frozen -- it must never reflect a LATER MetaProgress change").is_equal_approx(0.10, 0.001)
