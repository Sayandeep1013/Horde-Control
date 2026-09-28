extends GdUnitTestSuite

## PausedChoiceBar tests (blind review of the Settings screen task,
## 2026-09-28): the 0.4 s open lockout and the held-input seeding fix for
## the mirror-case bug named in that file's own header ("Neutral-return
## arming AND a 0.4 s open lockout"). No dedicated suite existed for this
## file before -- `tests/unit/run_end_outcome_style_test.gd`'s own use of
## `confirm_highlighted_for_test()` calls `_confirm()` directly and never
## exercised this bar's own `_process()`-driven input timing at all.

const STEP: float = 1.0 / 60.0


func _make_bar() -> PausedChoiceBar:
	var bar: PausedChoiceBar = auto_free(PausedChoiceBar.new())
	add_child(bar)
	bar.set_options(["Resume", "Settings", "Main Menu"])
	bar.set_test_input_mode_for_test(true)
	return bar


func _advance_past_lockout(bar: PausedChoiceBar) -> void:
	var elapsed: float = 0.0
	while elapsed < PausedChoiceBar.OPEN_LOCKOUT_SECONDS + STEP:
		bar.tick_for_test(STEP)
		elapsed += STEP


# --- 0.4 s open lockout (MASTER_SDLC.md line 242; Author decision D3) -------

func test_activation_starts_a_lockout() -> void:
	var bar: PausedChoiceBar = _make_bar()
	bar.set_active(true)
	assert_float(bar.get_lockout_remaining_for_test()).is_greater(0.0)


func test_cycle_input_is_ignored_during_the_lockout() -> void:
	var bar: PausedChoiceBar = _make_bar()
	bar.set_active(true)
	bar.press_action_once_for_test(&"move_right")
	bar.tick_for_test(STEP)
	assert_int(bar.get_highlighted_index()).append_failure_message("input must be locked out during the open lockout window").is_equal(0)


func test_cycle_input_works_once_the_lockout_elapses() -> void:
	var bar: PausedChoiceBar = _make_bar()
	bar.set_active(true)
	_advance_past_lockout(bar)
	bar.press_action_once_for_test(&"move_right")
	bar.tick_for_test(STEP)
	assert_int(bar.get_highlighted_index()).is_equal(1)


func test_skip_lockout_for_test_seam_bypasses_the_window() -> void:
	var bar: PausedChoiceBar = _make_bar()
	bar.set_active(true)
	bar.skip_lockout_for_test()
	bar.press_action_once_for_test(&"move_right")
	bar.tick_for_test(STEP)
	assert_int(bar.get_highlighted_index()).is_equal(1)


## Reproduces the same-frame reopen bug named in the class header: a
## leftover just-pressed confirm from the frame that activated this bar must
## not fire once polling resumes -- the lockout means it is never even read
## while it is still "just pressed" (0.4 s spans many real frames).
func test_a_confirm_pressed_the_frame_it_activates_does_not_fire() -> void:
	var bar: PausedChoiceBar = _make_bar()
	var confirmed: Array = []
	bar.option_confirmed.connect(func(_i: int) -> void: confirmed.append(true))
	bar.press_action_once_for_test(&"confirm")
	bar.set_active(true)
	bar.tick_for_test(STEP)
	assert_int(confirmed.size()).append_failure_message("a leftover just-pressed confirm from the activation frame must not fire").is_equal(0)


# --- Held-input seeding (the "mirror case" the review named) ----------------

## The mirror case named in the class header: a direction already held when
## the bar (re)activates (e.g. returning to the pause menu from Settings
## while still holding left/right) must not read as a fresh press once the
## lockout ends.
func test_a_direction_already_held_at_activation_does_not_cycle_once_the_lockout_ends() -> void:
	var bar: PausedChoiceBar = _make_bar()
	bar.set_action_pressed_for_test(&"move_right", true) # held BEFORE activation
	bar.set_active(true)
	_advance_past_lockout(bar)
	assert_int(bar.get_highlighted_index()).append_failure_message("a direction already held at activation must not count as a fresh press once the lockout ends").is_equal(0)
	bar.release_action_for_test(&"move_right")


func test_a_direction_already_held_does_not_auto_repeat_instantly_either() -> void:
	var bar: PausedChoiceBar = _make_bar()
	bar.set_action_pressed_for_test(&"move_right", true)
	bar.set_active(true)
	_advance_past_lockout(bar)
	# One more tick right after the lockout elapses: an already-held key must
	# not have its repeat timer already expired (seeded to a FULL interval).
	bar.tick_for_test(STEP)
	assert_int(bar.get_highlighted_index()).is_equal(0)
	bar.release_action_for_test(&"move_right")


func test_releasing_and_pressing_again_after_activation_cycles_normally() -> void:
	var bar: PausedChoiceBar = _make_bar()
	bar.set_action_pressed_for_test(&"move_right", true)
	bar.set_active(true)
	_advance_past_lockout(bar)
	bar.release_action_for_test(&"move_right")
	bar.tick_for_test(STEP)
	bar.press_action_once_for_test(&"move_right")
	bar.tick_for_test(STEP)
	assert_int(bar.get_highlighted_index()).is_equal(1)


# --- Hold-to-confirm still works after the lockout ---------------------------

func test_hold_up_still_confirms_after_the_lockout() -> void:
	var bar: PausedChoiceBar = _make_bar()
	var confirmed: Array = []
	bar.option_confirmed.connect(func(_i: int) -> void: confirmed.append(true))
	bar.set_active(true)
	_advance_past_lockout(bar)
	bar.set_action_pressed_for_test(&"move_up", true)
	var elapsed: float = 0.0
	while elapsed < PausedChoiceBar.HOLD_CONFIRM_SECONDS + STEP:
		bar.tick_for_test(STEP)
		elapsed += STEP
	assert_int(confirmed.size()).is_equal(1)
