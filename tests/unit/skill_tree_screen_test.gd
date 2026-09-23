extends GdUnitTestSuite

## Skill Tree screen tests (Hub/Skill Tree screen session; docs/18_Permanent_
## Skill_Tree.md section 4 in full). Drives `SkillTreeScreen` through its
## test-input double (`set_test_input_mode_for_test` / `set_action_pressed_
## for_test` / `press_action_once_for_test` + `tick_for_test()`), mirroring
## this project's established convention for input-timing suites
## (tests/unit/draft_input_lockout_test.gd's own header). Every test
## redirects MetaProgress to a throwaway directory first (hard constraint),
## matching tests/unit/meta_progress_economy_test.gd's own `_grant_cores()`
## fixture (settle_run() is the only production route to Cores).

const STEP: float = 1.0 / 60.0
const HOLD: float = 1.0 # SkillTreeScreen.HOLD_CONFIRM_SECONDS

var _dir: String
var _screen: SkillTreeScreen


func before_test() -> void:
	_dir = "user://__skill_tree_screen_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	_screen = auto_free(SkillTreeScreen.new())
	add_child(_screen)
	_screen.set_test_input_mode_for_test(true)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")


func _grant_cores(amount: int) -> void:
	var sim_minutes: float = float(amount) * 60.0 # 1 Core/minute at 0 waves/0 kills/no victory
	MetaProgress.settle_run({
		"run_id": "grant_%d_%d" % [amount, randi()],
		"sim_time_seconds": sim_minutes, "waves_cleared": 0, "kills": 0,
		"victory": false, "abandoned": false,
	})


func _tick_seconds(seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.0:
		var d: float = minf(STEP, remaining)
		_screen.tick_for_test(d)
		remaining -= d


# --- Purchase via hold, and no purchase on a short tap ------------------------

func test_holding_confirm_for_the_full_duration_buys_the_selected_node() -> void:
	_grant_cores(50)
	_screen.set_active(true)
	_screen.select_for_test("vitality")
	assert_int(MetaProgress.get_rank("vitality")).is_equal(0)

	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(HOLD + STEP)

	assert_int(MetaProgress.get_rank("vitality")).append_failure_message("a full 1.0s hold on a buyable node must buy it").is_equal(1)
	assert_int(MetaProgress.get_cores()).is_equal(50 - SkillNodeDefinition.price_for_rank(1, 1))


func test_a_short_tap_does_not_buy_and_resets_the_hold_ring() -> void:
	_grant_cores(50)
	_screen.set_active(true)
	_screen.select_for_test("vitality")

	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(0.3) # well short of the 1.0 s requirement
	_screen.set_action_pressed_for_test(&"confirm", false)
	_screen.tick_for_test(STEP)

	assert_int(MetaProgress.get_rank("vitality")).append_failure_message("a short tap must not purchase the node").is_equal(0)
	assert_float(_screen.get_hold_progress_for_test()).append_failure_message("releasing before the hold completes must reset progress to 0").is_equal(0.0)

	# A fresh, uninterrupted hold afterward still buys normally.
	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(HOLD + STEP)
	assert_int(MetaProgress.get_rank("vitality")).is_equal(1)


# --- Refusal when unaffordable -------------------------------------------------

func test_holding_confirm_on_an_unaffordable_node_never_buys_it() -> void:
	assert_int(MetaProgress.get_cores()).is_equal(0)
	_screen.set_active(true)
	_screen.select_for_test("vitality") # price 5, 0 Cores held -- unaffordable, not locked (root is always owned)

	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(HOLD * 2.0) # well past the hold duration

	assert_int(MetaProgress.get_rank("vitality")).append_failure_message("an unaffordable node must never be purchased no matter how long confirm is held").is_equal(0)
	assert_float(_screen.get_hold_progress_for_test()).append_failure_message("hold progress must never accumulate on an unaffordable node").is_equal(0.0)


# --- MAX state ------------------------------------------------------------------

func test_a_maxed_node_shows_max_and_refuses_further_purchase() -> void:
	_grant_cores(200)
	_screen.set_active(true)
	for i in 3: # Vitality's authored max_rank is 3
		assert_bool(MetaProgress.buy("vitality")).is_true()
	_screen.refresh()
	_screen.select_for_test("vitality")

	var view: SkillNodeView = _screen.get_node_view_for_test("vitality")
	assert_str(view.get_price_label_for_test().text).append_failure_message("a maxed node's grid badge must read MAX").is_equal(tr("SKILL_TREE_MAX"))

	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(HOLD + STEP)
	assert_int(MetaProgress.get_rank("vitality")).is_equal(3)


# --- Fog states: owned / revealed / silhouette ---------------------------------

func test_an_unrevealed_node_shows_as_a_silhouette() -> void:
	_screen.set_active(true) # nothing bought yet
	var view: SkillNodeView = _screen.get_node_view_for_test("sharpened_arrows")
	assert_str(view.get_rank_label_for_test().text).append_failure_message("an unrevealed node's grid badge must read the silhouette placeholder, never its rank").is_equal(tr("SKILL_TREE_SILHOUETTE_NAME"))
	assert_bool(view.get_price_label_for_test().visible).append_failure_message("a silhouette must never show a price").is_false()


func test_a_revealed_but_not_yet_owned_node_shows_its_price_not_a_silhouette() -> void:
	_grant_cores(5)
	assert_bool(MetaProgress.buy("vitality")).is_true() # reveals sharpened_arrows
	_screen.set_active(true)
	_screen.refresh()

	var view: SkillNodeView = _screen.get_node_view_for_test("sharpened_arrows")
	assert_str(view.get_rank_label_for_test().text).append_failure_message("a revealed node must show its real rank badge, not the silhouette").is_not_equal(tr("SKILL_TREE_SILHOUETTE_NAME"))
	assert_bool(view.get_price_label_for_test().visible).is_true()


func test_a_revealed_convergence_node_missing_one_prerequisite_is_locked_not_buyable() -> void:
	_grant_cores(200)
	assert_bool(MetaProgress.buy("vitality")).is_true()
	assert_bool(MetaProgress.buy("sharpened_arrows")).is_true() # reveals long_reach (one of its two prerequisites owned)
	_screen.set_active(true)
	_screen.refresh()

	assert_bool(MetaProgress.is_visible("long_reach")).is_true()
	assert_bool(MetaProgress.prerequisites_met("long_reach")).append_failure_message("long_reach needs BOTH sharpened_arrows and quick_draw -- only one is owned").is_false()

	_screen.select_for_test("long_reach")
	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(HOLD + STEP)
	assert_int(MetaProgress.get_rank("long_reach")).append_failure_message("a locked node (prerequisites not met) must never be purchasable, however long confirm is held").is_equal(0)


func test_an_owned_node_is_never_shown_as_a_silhouette() -> void:
	_grant_cores(5)
	assert_bool(MetaProgress.buy("vitality")).is_true()
	_screen.set_active(true)
	_screen.refresh()
	var view: SkillNodeView = _screen.get_node_view_for_test("vitality")
	assert_str(view.get_rank_label_for_test().text).is_equal("1/3")


# --- Respec hold refunds --------------------------------------------------------

func test_holding_confirm_on_the_respec_node_refunds_every_core_spent() -> void:
	_grant_cores(200)
	assert_bool(MetaProgress.buy("vitality")).is_true()
	assert_bool(MetaProgress.buy("vitality")).is_true() # rank 2
	assert_bool(MetaProgress.buy("swift_boots")).is_true()
	var cores_before_respec: int = MetaProgress.get_cores()
	var expected_refund: int = SkillNodeDefinition.price_for_rank(1, 1) + SkillNodeDefinition.price_for_rank(1, 2) + SkillNodeDefinition.price_for_rank(1, 1)

	_screen.set_active(true)
	_screen.refresh()
	_screen.select_for_test(SkillTreeScreen.RESPEC_ID)
	assert_int(MetaProgress.get_respec_refund_preview()).is_equal(expected_refund)

	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(HOLD + STEP)

	assert_int(MetaProgress.get_cores()).append_failure_message("holding confirm on the Reset Tree node must refund every Core ever spent").is_equal(cores_before_respec + expected_refund)
	assert_int(MetaProgress.get_rank("vitality")).is_equal(0)
	assert_int(MetaProgress.get_rank("swift_boots")).is_equal(0)


func test_respec_with_nothing_owned_shows_max_and_does_nothing() -> void:
	_screen.set_active(true)
	_screen.select_for_test(SkillTreeScreen.RESPEC_ID)
	assert_int(MetaProgress.get_respec_refund_preview()).is_equal(0)
	var view: SkillNodeView = _screen.get_respec_view_for_test()
	assert_str(view.get_price_label_for_test().text).is_equal(tr("SKILL_TREE_MAX"))

	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(HOLD + STEP)
	assert_int(MetaProgress.get_cores()).is_equal(0)


# --- Keyboard navigation reaches every revealed node ---------------------------

func _do_move(action: StringName) -> String:
	_screen.press_action_once_for_test(action)
	_screen.tick_for_test(STEP)
	_screen.release_action_for_test(action)
	_screen.tick_for_test(STEP)
	return _screen.get_selected_id_for_test()


func test_keyboard_navigation_reaches_every_revealed_node() -> void:
	_grant_cores(2000)
	var tree: SkillTreeDefinition = MetaProgress.skill_tree
	var all_ids: Array[String] = tree.get_purchasable_node_ids()
	# Fixed-point purchase: a handful of passes is enough to clear the tree's
	# own max depth (4 tiers), buying rank 1 of everything so every node is
	# revealed (owned or one-prerequisite-away is not enough here -- OWNING
	# every node is the simplest way to guarantee the "every revealed node"
	# set is the FULL node set, exercising the navigation graph end to end).
	for pass_i in 6:
		for id in all_ids:
			if MetaProgress.can_buy(id):
				MetaProgress.buy(id)
	for id in all_ids:
		assert_bool(MetaProgress.is_visible(id)).append_failure_message("fixture setup failed to reveal '%s' -- cannot test navigation to it" % id).is_true()

	_screen.set_active(true)
	var start: String = _screen.get_selected_id_for_test()
	assert_str(start).is_equal(tree.root_id)

	var visited: Dictionary = {start: true}
	var frontier: Array[String] = [start]
	var directions: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		for action in directions:
			_screen.select_for_test(current)
			var next_id: String = _do_move(action)
			if next_id != current and not visited.has(next_id):
				visited[next_id] = true
				frontier.append(next_id)

	for id in tree.get_all_node_ids():
		assert_bool(visited.has(id)).append_failure_message("keyboard navigation never reached revealed node '%s'" % id).is_true()


## docs/18 section 6 edge case: "Double input on purchase (held key
## repeats): One rank per completed hold; the hold must release before the
## next." Holding confirm continuously past 1.0 s must buy exactly ONE
## rank, not one per elapsed 1.0 s interval.
func test_holding_confirm_continuously_buys_only_one_rank_per_release() -> void:
	_grant_cores(50) # enough for two ranks of vitality (5 + 8 = 13)
	_screen.set_active(true)
	_screen.select_for_test("vitality")

	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(HOLD + STEP)
	assert_int(MetaProgress.get_rank("vitality")).is_equal(1)
	assert_bool(_screen.is_confirm_requires_release_for_test()).append_failure_message("the hold must require a release before it can buy again").is_true()

	# Still held, well past a second full HOLD duration -- must not buy again.
	_tick_seconds(HOLD * 2.0)
	assert_int(MetaProgress.get_rank("vitality")).append_failure_message("holding confirm continuously must not buy a second rank without a release in between").is_equal(1)

	_screen.set_action_pressed_for_test(&"confirm", false)
	_screen.tick_for_test(STEP)
	assert_bool(_screen.is_confirm_requires_release_for_test()).is_false()

	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(HOLD + STEP)
	assert_int(MetaProgress.get_rank("vitality")).append_failure_message("a fresh hold after releasing must buy the next rank").is_equal(2)


## docs/19 > "Input Lockout & Arming" (Draft's own rule, reused here): a
## `confirm` press already held at the moment the screen opens must not
## instantly confirm a purchase once navigation reaches a buyable node.
func test_confirm_already_held_at_open_does_not_auto_buy_on_arrival() -> void:
	_grant_cores(50)
	_screen.set_action_pressed_for_test(&"confirm", true) # held BEFORE the screen even opens
	_screen.set_active(true)
	_screen.select_for_test("vitality") # jump straight to a buyable node, bypassing real navigation

	_tick_seconds(HOLD * 2.0) # held continuously, well past the hold duration
	assert_int(MetaProgress.get_rank("vitality")).append_failure_message("a confirm press already held at open must not auto-buy once a buyable node is reached").is_equal(0)

	_screen.set_action_pressed_for_test(&"confirm", false)
	_screen.tick_for_test(STEP)
	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(HOLD + STEP)
	assert_int(MetaProgress.get_rank("vitality")).append_failure_message("a fresh hold after releasing once must still buy normally").is_equal(1)


func test_navigating_away_and_back_resets_hold_progress() -> void:
	_grant_cores(50)
	_screen.set_active(true)
	_screen.select_for_test("vitality")
	_screen.set_action_pressed_for_test(&"confirm", true)
	_tick_seconds(0.5)
	assert_float(_screen.get_hold_progress_for_test()).is_greater(0.0)

	_screen.select_for_test("stone_walls") # changing selection must not carry a partial hold onto a different node
	assert_float(_screen.get_hold_progress_for_test()).is_equal(0.0)
	assert_int(MetaProgress.get_rank("vitality")).is_equal(0)
