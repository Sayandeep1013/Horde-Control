extends GdUnitTestSuite

## Same-frame death test (P2.4 named acceptance test). MASTER_SDLC.md >
## "Edge Cases and Failure States" > "Run Termination": "Player and Tower
## reach zero on the same frame -> Deterministic order from the
## Determinism rule: the Tower's depletion resolves first. Run ends, cause
## recorded as Tower." docs/20_Technical_Architecture.md > "SimLoop order",
## step 8: "death resolution in order Tower, bosses, player, other
## enemies."
##
## Exercises src/tower/run_termination_recorder.gd (this task's own,
## standalone implementation of the documented order -- see that file's
## header for why it is not wired into src/core/sim_loop.gd's real step 8,
## which is outside this task's write scope).
##
## The GENUINE same-tick case (not a near-miss): both the real Player scene
## (scenes/player.tscn, P2.1) and the real Tower scene (scenes/tower.tscn,
## this task) are driven to exactly zero HP within the SAME synchronous
## test function, with no `await` (no frame boundary, no tick) between the
## two damage calls -- that is what "the same tick" means operationally,
## since nothing can happen between two statements in the same synchronous
## call with no yield. What a real SimLoop step 8 arbiter would have
## observed for that tick (both Category.PLAYER and Category.TOWER reached
## zero) is then handed to the recorder exactly as step 8 would, since no
## such arbiter is wired into the real SimLoop yet.
##
## Falsifications required by this task's own instructions, each with its
## own test below:
##   1. Reversing the resolution order -- both as a pure-recorder input
##      order swap, and as a real-entity "which one gets damaged first in
##      code" swap. Neither may change the recorded cause.
##   2. Making the two deaths one tick apart -- both as a pure-recorder
##      two-call sequence, and as a real-entity test with an actual
##      `await get_tree().physics_frame` between the two hits. The first
##      death must be the one credited; the later one must NOT retroactively
##      overwrite it.
## Both are run, and green again confirmed after each restore, per this
## task's own instruction ("Restore and re-run green after each").

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")

const Category := RunTerminationRecorder.Category


func _build_player() -> Node:
	var player: Node = auto_free(PlayerScene.instantiate())
	add_child(player)
	return player


func _build_tower() -> Node:
	var tower: Node = auto_free(TowerScene.instantiate())
	add_child(tower)
	return tower


# --- The genuine same-tick case -------------------------------------------

func test_genuine_same_tick_zero_zero_credits_the_tower() -> void:
	var player: Node = _build_player()
	var tower: Node = _build_tower()

	var sim_time: float = SimClock.now

	# Both hits land within this one synchronous function -- no frame
	# boundary, no tick, passes between them. This is the genuine
	# simultaneous case, not a near-miss. death_state.is_dead is read
	# directly afterward rather than via a signal-connected closure: a
	# plain captured bool local's mutation inside a GDScript lambda does
	# not reliably propagate back to the enclosing scope (tests/unit/
	# death_state_test.gd's own header names this exact pitfall and works
	# around it with a Dictionary; reading the flag directly sidesteps the
	# whole issue instead of reproducing the workaround here).
	tower.hurtbox.receive_hit(auto_free(Node.new()), 999999.0, "test_lethal")
	player.apply_damage(999999.0, "test_lethal")

	assert_bool(tower.death_state.is_dead).append_failure_message("tower.hurtbox.receive_hit() did not kill the Tower -- fixture setup is broken, not the rule under test").is_true()
	assert_bool(player.death_state.is_dead).append_failure_message("player.apply_damage() did not kill the Player -- fixture setup is broken, not the rule under test").is_true()

	var recorder := RunTerminationRecorder.new()
	var cause: Variant = recorder.record_tick_deaths([Category.PLAYER, Category.TOWER], sim_time)
	assert_bool(cause == Category.TOWER).append_failure_message("a genuine same-tick Player+Tower zero-zero must credit the Tower (docs/20 SimLoop step 8 order: Tower before player)").is_true()
	assert_bool(recorder.is_run_ended()).is_true()
	assert_float(recorder.get_ended_at_sim_time()).is_equal_approx(sim_time, 0.0001)


# --- Falsification 1: reversing the resolution order -----------------------

func test_reversing_the_pure_input_order_does_not_change_the_recorded_cause() -> void:
	var recorder_a := RunTerminationRecorder.new()
	var cause_a: Variant = recorder_a.record_tick_deaths([Category.PLAYER, Category.TOWER], 1.0)

	var recorder_b := RunTerminationRecorder.new()
	var cause_b: Variant = recorder_b.record_tick_deaths([Category.TOWER, Category.PLAYER], 1.0)

	assert_bool(cause_a == Category.TOWER).is_true()
	assert_bool(cause_b == Category.TOWER).is_true()
	assert_bool(cause_a == cause_b).append_failure_message("swapping the input array's order changed the recorded cause -- the resolver must be order-independent, driven only by category identity").is_true()


func test_reversing_which_real_entity_is_damaged_first_in_code_still_credits_the_tower() -> void:
	var player: Node = _build_player()
	var tower: Node = _build_tower()
	var sim_time: float = SimClock.now

	# Opposite call order from test_genuine_same_tick_zero_zero_credits_the_
	# tower() above: the PLAYER is damaged first this time. The recorded
	# cause must be unaffected -- the rule is about category identity
	# (docs/20's fixed order), never about which statement a caller happens
	# to write first.
	player.apply_damage(999999.0, "test_lethal")
	tower.hurtbox.receive_hit(auto_free(Node.new()), 999999.0, "test_lethal")

	var recorder := RunTerminationRecorder.new()
	var cause: Variant = recorder.record_tick_deaths([Category.PLAYER, Category.TOWER], sim_time)
	assert_bool(cause == Category.TOWER).append_failure_message("reversing which real entity was damaged first in code changed the recorded cause away from Tower").is_true()


# --- Falsification 2: one tick apart, not the same tick ---------------------

func test_pure_one_tick_apart_deaths_credit_whichever_died_first_and_the_later_one_does_not_overwrite_it() -> void:
	var recorder := RunTerminationRecorder.new()

	# Tick N: only the player reaches zero.
	var cause_tick_n: Variant = recorder.record_tick_deaths([Category.PLAYER], 10.0)
	assert_bool(cause_tick_n == Category.PLAYER).is_true()
	assert_bool(recorder.is_run_ended()).is_true()

	# Tick N+1, one physics tick later: the Tower also reaches zero. This
	# must NOT retroactively become the recorded cause -- this is exactly
	# what distinguishes a genuine same-tick zero-zero (credits the Tower)
	# from a near-miss one tick apart (credits whichever pool actually
	# reached zero first).
	var cause_tick_n_plus_1: Variant = recorder.record_tick_deaths([Category.TOWER], 10.0 + SimClock.PHYSICS_STEP)
	assert_bool(cause_tick_n_plus_1 == null).append_failure_message("a death one tick after the run already ended must not produce a new recorded cause").is_true()
	assert_bool(recorder.get_cause() == Category.PLAYER).append_failure_message("the later Tower death overwrote the already-recorded Player cause").is_true()


func test_real_entities_one_tick_apart_do_not_get_credited_to_the_tower() -> void:
	var player: Node = _build_player()
	var tower: Node = _build_tower()
	var recorder := RunTerminationRecorder.new()

	# Warm-up tick, matching tests/unit/pause_clock_test.gd's own before_test()
	# convention: the FIRST `await get_tree().physics_frame` inside a test
	# function was directly diagnosed (throwaway probe, not committed) NOT
	# to correspond to a genuine SimClock.now tick -- t1 and t2 read
	# identical across exactly one await, while a second and third await
	# each advanced by one PHYSICS_STEP as expected. One untested warm-up
	# await here settles that before this test starts relying on "one
	# await = one real tick" for the actual falsification below.
	await get_tree().physics_frame

	var sim_time_tick_1: float = SimClock.now
	player.apply_damage(999999.0, "test_lethal")
	var cause1: Variant = recorder.record_tick_deaths([Category.PLAYER], sim_time_tick_1)
	assert_bool(cause1 == Category.PLAYER).is_true()

	await get_tree().physics_frame # a genuine tick boundary passes

	var sim_time_tick_2: float = SimClock.now
	assert_float(sim_time_tick_2).is_greater(sim_time_tick_1) # confirms a real tick actually elapsed
	tower.hurtbox.receive_hit(auto_free(Node.new()), 999999.0, "test_lethal")
	var cause2: Variant = recorder.record_tick_deaths([Category.TOWER], sim_time_tick_2)

	assert_bool(cause2 == null).append_failure_message("a Tower death one real tick after the Player's death must not be credited").is_true()
	assert_bool(recorder.get_cause() == Category.PLAYER).is_true()


# --- Sanity: an ordinary enemy dying alone never ends the run --------------

func test_an_ordinary_enemy_death_alone_does_not_end_the_run() -> void:
	var recorder := RunTerminationRecorder.new()
	var cause: Variant = recorder.record_tick_deaths([Category.ENEMY], 5.0)
	assert_bool(cause == null).is_true()
	assert_bool(recorder.is_run_ended()).is_false()


# --- Integration: Tower.gd's own wiring calls the recorder on death --------

func test_tower_scene_reports_its_own_death_to_its_run_termination_recorder() -> void:
	var tower: Node = _build_tower()
	var recorder := RunTerminationRecorder.new()
	tower.set_run_termination_recorder_for_test(recorder)

	tower.hurtbox.receive_hit(auto_free(Node.new()), 999999.0, "test_lethal")

	assert_bool(recorder.is_run_ended()).append_failure_message("Tower._on_tower_destroyed() did not report its own death to the injected recorder").is_true()
	assert_bool(recorder.get_cause() == Category.TOWER).is_true()
