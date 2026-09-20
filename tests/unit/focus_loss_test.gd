extends GdUnitTestSuite

## Focus loss test (P2.14 named acceptance test). MASTER_SDLC.md >
## Acceptance Test Matrix > Technical Tests > "Focus loss test": "Losing
## window focus pauses within one frame and the game does not resume until
## the player confirms; a controller disconnect opens the pause menu the
## same way; the harness's `--no-focus-pause` flag is exercised here."
##
## Exercises the REAL src/run/run_flow_controller.gd this task built,
## against a FRESH PauseAuthority instance (never the project's autoload
## singleton) added to this suite's own tree -- matching
## tests/unit/pause_clock_test.gd's own established precedent, including
## its `after_test()` safety net, since a fresh PauseAuthority instance
## still writes the SHARED `get_tree().paused` (it resolves `get_tree()`
## from wherever it is actually parented).
##
## Godot delivers `NOTIFICATION_APPLICATION_FOCUS_OUT` from the real OS
## window manager, which a headless gdUnit4 run cannot trigger -- this
## suite calls `simulate_focus_out_for_test()` /
## `simulate_controller_disconnected_for_test()` /
## `simulate_pause_pressed_for_test()`, which invoke the EXACT SAME private
## handlers those real engine events call (see run_flow_controller.gd's own
## "Test-only direct triggers" section), so what is proven here is the
## handler logic, not the OS's delivery of the notification itself -- named
## in the P2.14 evidence report as a clause a script cannot cover.

const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")
const RunFlowControllerScript: GDScript = preload("res://src/run/run_flow_controller.gd")

var _pause: Node
var _controller: RunFlowController


func before_test() -> void:
	_pause = auto_free(PauseAuthorityScript.new()) as Node
	add_child(_pause)

	_controller = RunFlowControllerScript.new() as RunFlowController
	_controller.set_pause_authority_for_test(_pause) # BEFORE add_child(), so _ready()'s own _connect_signals() wires the fresh instance, never the real autoload
	auto_free(_controller)
	add_child(_controller)


func after_test() -> void:
	# Safety net (pause_clock_test.gd's own precedent): a failed assertion
	# mid-test must never leave the SHARED scene tree paused for suites that
	# run after this one.
	get_tree().paused = false


func test_focus_loss_pauses_immediately_via_push_reason_immediate() -> void:
	assert_bool(get_tree().paused).is_false()

	_controller.simulate_focus_out_for_test()

	# push_reason_immediate() queues AND flushes in the same call (the Focus
	# Loss Rule's own documented escape hatch, pause_authority.gd's header:
	# "a request made BETWEEN ticks ... applies immediately") -- so this is
	# already true the instant simulate_focus_out_for_test() returns, with
	# no physics_frame await needed at all. That is strictly stronger than
	# "within one frame."
	assert_bool(_pause.has_reason(PauseAuthority.REASON_FOCUS_LOSS)).is_true()
	assert_bool(get_tree().paused).is_true()


func test_focus_regained_does_not_resume_on_its_own() -> void:
	_controller.simulate_focus_out_for_test()
	assert_bool(get_tree().paused).is_true()

	# Several ticks pass with no explicit player confirmation -- Godot
	# delivers no automatic "resume" notification, and this controller
	# defines none: only an explicit action (pause pressed again, or the
	# Pause Menu's own Resume choice) may pop REASON_FOCUS_LOSS.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_pause.has_reason(PauseAuthority.REASON_FOCUS_LOSS)).append_failure_message("focus loss's pause reason cleared itself with no confirmation").is_true()
	assert_bool(get_tree().paused).append_failure_message("the game resumed without the player confirming").is_true()
	assert_int(_controller.get_ui_mode_for_test()).is_equal(RunFlowController.UiMode.PAUSE)


## Regaining window focus, by itself, is not a "player confirmation" --
## `Object.notification()` is a real, directly-callable Godot API (not a
## simulate_*_for_test() double), so this drives the actual
## NOTIFICATION_APPLICATION_FOCUS_IN path the real engine would deliver.
func test_regaining_focus_alone_does_not_resume() -> void:
	_controller.simulate_focus_out_for_test()
	assert_bool(get_tree().paused).is_true()

	_controller.notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	assert_bool(_pause.has_reason(PauseAuthority.REASON_FOCUS_LOSS)).append_failure_message("regaining focus alone popped the focus-loss pause reason with no player confirmation").is_true()
	assert_bool(get_tree().paused).append_failure_message("regaining focus alone resumed the game with no player confirmation").is_true()


func test_resume_requires_an_explicit_confirmation() -> void:
	_controller.simulate_focus_out_for_test()
	assert_bool(get_tree().paused).is_true()

	_controller.simulate_pause_pressed_for_test() # the explicit confirmation this controller accepts while the Pause Menu is showing

	assert_bool(_pause.has_reason(PauseAuthority.REASON_FOCUS_LOSS)).is_false()
	assert_bool(get_tree().paused).append_failure_message("the game did not resume after an explicit confirmation").is_false()
	assert_int(_controller.get_ui_mode_for_test()).is_equal(RunFlowController.UiMode.NONE)


func test_controller_disconnect_opens_the_pause_menu_the_same_way() -> void:
	assert_bool(get_tree().paused).is_false()

	_controller.simulate_controller_disconnected_for_test()

	assert_bool(_pause.has_reason(PauseAuthority.REASON_CONTROLLER_DISCONNECT)).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(_controller.get_ui_mode_for_test()).append_failure_message("a controller disconnect must open the SAME Pause Menu UI mode as focus loss").is_equal(RunFlowController.UiMode.PAUSE)

	_controller.simulate_pause_pressed_for_test()
	assert_bool(get_tree().paused).is_false()


func test_no_focus_pause_flag_disables_both_focus_loss_and_controller_disconnect() -> void:
	_controller.set_focus_pause_disabled_for_test(true)

	_controller.simulate_focus_out_for_test()
	assert_bool(_pause.has_reason(PauseAuthority.REASON_FOCUS_LOSS)).append_failure_message("--no-focus-pause did not suppress focus loss").is_false()
	assert_bool(get_tree().paused).is_false()

	_controller.simulate_controller_disconnected_for_test()
	assert_bool(_pause.has_reason(PauseAuthority.REASON_CONTROLLER_DISCONNECT)).append_failure_message("--no-focus-pause did not suppress a controller disconnect").is_false()
	assert_bool(get_tree().paused).is_false()


## The flag-parsing logic itself, exercised directly against constructed
## argument arrays -- see run_flow_controller.gd's own header for why the
## real `OS.get_cmdline_user_args()`/`get_cmdline_args()` read cannot be
## exercised from inside this same process.
func test_flag_parsing_recognizes_the_literal_flag_and_nothing_else() -> void:
	assert_bool(RunFlowController._flag_present(PackedStringArray(["--no-focus-pause"]))).is_true()
	assert_bool(RunFlowController._flag_present(PackedStringArray(["--seed=42", "--no-focus-pause", "--headless"]))).is_true()
	assert_bool(RunFlowController._flag_present(PackedStringArray(["--headless"]))).is_false()
	assert_bool(RunFlowController._flag_present(PackedStringArray([]))).is_false()
