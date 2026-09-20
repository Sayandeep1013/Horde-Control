extends GdUnitTestSuite

## Draft input lockout test (MASTER_SDLC.md > Acceptance Test Matrix >
## Encounter Tests, P2.12): "Input is locked for 0.4 seconds after the
## Level-Up Draft opens; hold-to-confirm arms only after input returns to
## neutral once; left/right cycle with a 0.3 second repeat and wrap;
## holding up for 1.0 second confirms the highlighted card with a fill ring
## that resets on release." docs/19_UI_UX.md > "Upgrade Draft UI &
## Navigation" > "Input Lockout & Arming", "Movement-only".
##
## Drives DraftController through its test-input double
## (set_action_pressed_for_test / press_action_once_for_test +
## tick_for_test()) rather than real hardware InputEvents -- this project's
## own convention for input-timing suites (see
## tests/unit/player_input_buffer_test.gd's set_input_direction_for_test()
## + direct physics_step() calls), and the only way to get frame-exact
## control over a 0.3 s / 1.0 s / 0.4 s timing rule in a headless run.

const STEP: float = 1.0 / 60.0 # matches SimClock.PHYSICS_STEP; frame delta, not sim time (see draft_controller.gd's own header)

var _controller: DraftController
var _run_inventory: RunInventory
var _upgrade_system: UpgradeSystem
var _pause: Node
var _clock: Node


func before_test() -> void:
	_run_inventory = DraftTestHelpers.build_run_inventory()
	_upgrade_system = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(_upgrade_system)
	_pause = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(_pause)
	_clock = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(_clock)

	_controller = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(_controller)
	_controller.set_run_inventory_for_test(_run_inventory)
	_controller.set_upgrade_system_for_test(_upgrade_system)
	_controller.set_pause_authority_for_test(_pause)
	_controller.set_sim_clock_for_test(_clock)
	_controller.set_test_input_mode_for_test(true)
	_controller.force_open_for_test(false)


func after_test() -> void:
	PauseAuthority.pop_reason(&"draft")
	PauseAuthority.flush()
	get_tree().paused = false


func _tick_seconds(seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.0:
		var d: float = minf(STEP, remaining)
		_controller.tick_for_test(d)
		remaining -= d


# --- 0.4 s lockout -----------------------------------------------------------

func test_confirm_is_ignored_during_the_0_4_second_lockout() -> void:
	_controller.press_action_once_for_test(&"confirm")
	_tick_seconds(0.1)
	assert_bool(_controller.is_draft_showing_for_test()).append_failure_message("confirm fired during the input lockout window").is_true()
	assert_bool(_controller.is_lockout_elapsed_for_test()).is_false()


func test_confirm_works_immediately_once_the_lockout_elapses() -> void:
	_tick_seconds(0.4)
	assert_bool(_controller.is_lockout_elapsed_for_test()).is_true()
	_controller.press_action_once_for_test(&"confirm")
	_tick_seconds(STEP)
	assert_bool(_controller.is_draft_showing_for_test()).append_failure_message("confirm after the lockout elapsed did not resolve the draft").is_false()


# --- Neutral-return arming ----------------------------------------------------

func test_hold_up_already_held_at_open_does_not_arm_after_lockout() -> void:
	_controller.set_action_pressed_for_test(&"move_up", true) # held BEFORE the draft even opened, simulated as still held throughout
	_tick_seconds(0.4) # lockout elapses with move_up still pressed
	assert_bool(_controller.is_hold_up_armed_for_test()).append_failure_message("hold-up armed immediately even though move_up was never released -- a key already held at open would auto-confirm").is_false()

	# Keep holding well past 1.0 s: must never accumulate, must never confirm.
	_tick_seconds(1.5)
	assert_bool(_controller.is_hold_up_armed_for_test()).is_false()
	assert_float(_controller.get_hold_progress_for_test()).is_equal(0.0)
	assert_bool(_controller.is_draft_showing_for_test()).append_failure_message("held move_up auto-confirmed a card despite never being released once").is_true()


func test_hold_up_arms_after_one_full_release_then_confirms_on_a_fresh_hold() -> void:
	_controller.set_action_pressed_for_test(&"move_up", true)
	_tick_seconds(0.4)
	assert_bool(_controller.is_hold_up_armed_for_test()).is_false()

	_controller.set_action_pressed_for_test(&"move_up", false) # neutral, once
	_tick_seconds(STEP)
	assert_bool(_controller.is_hold_up_armed_for_test()).append_failure_message("did not arm after input returned to neutral").is_true()

	_controller.set_action_pressed_for_test(&"move_up", true)
	_tick_seconds(1.0 + STEP)
	assert_bool(_controller.is_draft_showing_for_test()).append_failure_message("armed hold-up for a full 1.0 s did not confirm").is_false()


# --- Hold-to-confirm fill ring, and reset on release --------------------------

func test_hold_ring_fills_proportionally_and_resets_on_early_release() -> void:
	_tick_seconds(0.4) # lockout elapses; move_up never pressed, so already neutral/armed
	assert_bool(_controller.is_hold_up_armed_for_test()).is_true()

	_controller.set_action_pressed_for_test(&"move_up", true)
	_tick_seconds(0.5)
	assert_float(_controller.get_hold_progress_for_test()).is_between(0.45, 0.55)
	assert_float(_controller.get_fill_ring_for_test().get_progress_for_test()).is_between(0.45, 0.55)
	assert_bool(_controller.is_draft_showing_for_test()).is_true() # not yet confirmed

	_controller.set_action_pressed_for_test(&"move_up", false) # released before completing
	_tick_seconds(STEP)
	assert_float(_controller.get_hold_progress_for_test()).append_failure_message("hold progress did not reset on early release").is_equal(0.0)
	assert_float(_controller.get_fill_ring_for_test().get_progress_for_test()).is_equal(0.0)

	# A fresh, uninterrupted 1.0 s hold now confirms.
	_controller.set_action_pressed_for_test(&"move_up", true)
	_tick_seconds(1.0 + STEP)
	assert_bool(_controller.is_draft_showing_for_test()).is_false()


# --- Left/right cycling: 0.3 s repeat and wrap --------------------------------

func test_cycle_moves_one_step_per_press_and_repeats_every_0_3_seconds() -> void:
	_tick_seconds(0.4)
	assert_int(_controller.get_highlighted_index_for_test()).is_equal(0)

	_controller.set_action_pressed_for_test(&"draft_cycle_right", true)
	_controller.tick_for_test(STEP) # rising edge -- immediate cycle
	assert_int(_controller.get_highlighted_index_for_test()).is_equal(1)

	# Held, but under 0.3 s more -- must not repeat yet.
	_tick_seconds(0.29)
	assert_int(_controller.get_highlighted_index_for_test()).append_failure_message("cycle repeated before the 0.3 s repeat interval elapsed").is_equal(1)

	# Cross the 0.3 s repeat threshold.
	_tick_seconds(0.02)
	assert_int(_controller.get_highlighted_index_for_test()).is_equal(2)

	_controller.set_action_pressed_for_test(&"draft_cycle_right", false)


func test_cycle_wraps_at_both_ends() -> void:
	_tick_seconds(0.4)
	assert_int(_controller.get_current_card_ids_for_test().size()).is_equal(3)

	_controller.set_action_pressed_for_test(&"draft_cycle_left", true)
	_controller.tick_for_test(STEP)
	assert_int(_controller.get_highlighted_index_for_test()).append_failure_message("cycling left from index 0 did not wrap to the last card").is_equal(2)
	_controller.set_action_pressed_for_test(&"draft_cycle_left", false)
	_controller.tick_for_test(STEP) # let the release register before the next press

	_controller.set_action_pressed_for_test(&"draft_cycle_right", true)
	_controller.tick_for_test(STEP) # fresh rising edge -- immediate cycle
	assert_int(_controller.get_highlighted_index_for_test()).append_failure_message("cycling right from the last card did not wrap to index 0").is_equal(0)

	_controller.set_action_pressed_for_test(&"draft_cycle_right", false)
	_controller.tick_for_test(STEP) # let the release register before the next press

	_controller.set_action_pressed_for_test(&"draft_cycle_right", true)
	_controller.tick_for_test(STEP) # another fresh rising edge -- advances normally past the wrap
	assert_int(_controller.get_highlighted_index_for_test()).append_failure_message("cycling right again after the wrap did not advance to index 1").is_equal(1)


func test_movement_only_keys_also_cycle_with_the_same_rule() -> void:
	_tick_seconds(0.4)
	_controller.set_action_pressed_for_test(&"move_right", true)
	_controller.tick_for_test(STEP)
	assert_int(_controller.get_highlighted_index_for_test()).append_failure_message("move_right (movement-only path) did not cycle the highlight").is_equal(1)


# --- Layout: asserted at a real screen position, not merely existence -------
# Phase 05's own carried lesson 1 (PLAN.md, F03-20): a raw-anchor Control can
# exist, pass every content assertion, and still render off-screen. Every one
# of these assertions is a POSITION/SIZE check on a 1920x1080 reference
# viewport (MASTER_SDLC.md > Provisional Values Register > "Viewport"), not
# merely a null check.

const VIEWPORT_REF: Vector2 = Vector2(1920.0, 1080.0)


func test_dim_background_covers_the_full_1920x1080_viewport() -> void:
	await get_tree().process_frame
	var root: Control = _controller.get_root_control_for_test()
	assert_object(root).is_not_null()
	var dim: Control = root.get_node("Dim") as Control
	assert_object(dim).append_failure_message("Dim background node missing").is_not_null()
	assert_vector(dim.size).append_failure_message("Dim background does not cover the full viewport: %s" % dim.size).is_equal(VIEWPORT_REF)
	assert_vector(dim.position).is_equal(Vector2.ZERO)


func test_card_views_render_on_screen_within_the_1920x1080_viewport() -> void:
	await get_tree().process_frame
	assert_int(_controller.get_card_view_count_for_test()).is_equal(3)
	for i in _controller.get_card_view_count_for_test():
		var card: DraftCardView = _controller.get_card_view_for_test(i)
		var pos: Vector2 = card.global_position
		var size: Vector2 = card.size
		# The exact F03-20 defect class: a Control pinned at y >= viewport
		# height (or with zero size) passes every "does it exist / does it
		# have the right text" assertion and still never appears on screen.
		assert_float(pos.x).append_failure_message("card %d rendered off the left/right edge of a 1920-wide viewport: x=%f" % [i, pos.x]).is_between(-1.0, VIEWPORT_REF.x)
		assert_float(pos.y).append_failure_message("card %d rendered off the top/bottom edge of a 1080-tall viewport: y=%f" % [i, pos.y]).is_between(-1.0, VIEWPORT_REF.y)
		assert_float(size.x).append_failure_message("card %d has zero/degenerate width" % i).is_greater(0.0)
		assert_float(size.y).append_failure_message("card %d has zero/degenerate height" % i).is_greater(0.0)


func test_card_differentiation_is_never_colour_alone() -> void:
	for i in _controller.get_card_view_count_for_test():
		var card: DraftCardView = _controller.get_card_view_for_test(i)
		var is_player: bool = card.get_pool_ownership() == ContractEnums.PoolOwnership.Player
		var style: StyleBoxFlat = card.get_frame_style()
		# Frame shape.
		if is_player:
			assert_int(style.corner_radius_top_left).append_failure_message("card %d is a Player card but its frame is not rounded" % i).is_greater(0)
		else:
			assert_int(style.corner_radius_top_left).append_failure_message("card %d is a Tower card but its frame is not squared" % i).is_equal(0)
		# Fixed glyph + header word (docs/19 > "Differentiation").
		var expected_glyph: String = DraftCardView.GLYPH_PLAYER if is_player else DraftCardView.GLYPH_TOWER
		var expected_header: String = DraftCardView.HEADER_PLAYER if is_player else DraftCardView.HEADER_TOWER
		assert_str(card.get_glyph_label().text).is_equal(expected_glyph)
		assert_str(card.get_header_label().text).is_equal(expected_header)
