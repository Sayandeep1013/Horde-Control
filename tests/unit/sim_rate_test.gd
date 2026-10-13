extends GdUnitTestSuite

## PT-PHONE (D395): the simulation runs at 30 Hz on a phone, so every rule that counts ticks
## must keep its wall-clock meaning. These tests pin SimRate (tick and budget conversion, the
## drift-free timer) at 60 and 30 Hz, and the rules built on it: the swarm think interval, the
## weapon cadence, the dash distance.

var _saved_hz: int = 60


func before_test() -> void:
	_saved_hz = Engine.physics_ticks_per_second


func after_test() -> void:
	Engine.physics_ticks_per_second = _saved_hz


func test_ticks_keep_their_wall_time_at_30_hz() -> void:
	Engine.physics_ticks_per_second = 60
	assert_int(SimRate.ticks(4)).is_equal(4)
	Engine.physics_ticks_per_second = 30
	assert_int(SimRate.ticks(4)).is_equal(2)
	assert_int(SimRate.ticks(8)).is_equal(4)
	assert_int(SimRate.ticks(1)).is_equal(1) # never below one tick
	assert_int(SimRate.ticks(20)).is_equal(10)


func test_a_per_tick_budget_is_the_same_per_second() -> void:
	Engine.physics_ticks_per_second = 60
	assert_int(SimRate.per_tick(6)).is_equal(6)
	Engine.physics_ticks_per_second = 30
	assert_int(SimRate.per_tick(6)).is_equal(12) # half the ticks, twice the budget per tick
	assert_int(SimRate.per_tick(5)).is_equal(10)


func test_swarm_think_interval_is_the_same_wall_time() -> void:
	SwarmState.reset()
	SwarmState.alive_count = 200
	Engine.physics_ticks_per_second = 60
	var at_60: int = EnemyController.swarm_think_interval()
	Engine.physics_ticks_per_second = 30
	var at_30: int = EnemyController.swarm_think_interval()
	assert_float(float(at_30) / 30.0).is_equal_approx(float(at_60) / 60.0, 1.0 / 60.0) # within half a 30 Hz tick
	SwarmState.reset()


## A 0.25 s weapon sampled by ticks: the number of shots in 60 s must be 240 at both rates.
func _shots_in(seconds: float, hz: int, interval: float) -> int:
	Engine.physics_ticks_per_second = hz
	var step: float = 1.0 / float(hz)
	var now: float = 0.0
	var due: float = 0.0
	var shots: int = 0
	var ticks: int = roundi(seconds * hz)
	for i in ticks:
		now += step
		if now >= due:
			shots += 1
			due = SimRate.reschedule(due, now, interval)
	return shots


func test_reschedule_gives_the_same_fire_rate_at_30_and_60_hz() -> void:
	for interval: float in [0.25, 0.4, 0.55, 0.9, 2.4]:
		var s60: int = _shots_in(60.0, 60, interval)
		var s30: int = _shots_in(60.0, 30, interval)
		var expected: float = 60.0 / interval
		assert_float(float(s60)).is_equal_approx(expected, 1.5)
		assert_float(float(s30)).is_equal_approx(expected, 1.5)


func test_the_naive_timer_would_lose_dps_at_30_hz() -> void:
	# Documents why reschedule exists: now + interval fires every ceil(interval / step) ticks.
	Engine.physics_ticks_per_second = 30
	var step: float = 1.0 / 30.0
	var now: float = 0.0
	var due: float = 0.0
	var shots: int = 0
	for i in 1800:
		now += step
		if now >= due:
			shots += 1
			due = now + 0.25
	assert_int(shots).is_less(235) # 8 ticks per shot = 0.267 s: 225 shots in 60 s, not 240


func test_a_timer_that_waited_restarts_from_now() -> void:
	Engine.physics_ticks_per_second = 60
	assert_float(SimRate.reschedule(1.0, 5.0, 0.5)).is_equal_approx(5.5, 0.0001)
	assert_float(SimRate.reschedule(1.0, 1.01, 0.5)).is_equal_approx(1.5, 0.0001) # fired on its first chance
	assert_float(SimRate.reschedule(-INF, 3.0, 0.5)).is_equal_approx(3.5, 0.0001)


func test_sim_clock_advances_by_the_running_tick() -> void:
	Engine.physics_ticks_per_second = 30
	var clock: Node = auto_free(preload("res://src/core/sim_clock.gd").new())
	add_child(clock)
	var before: float = clock.now
	clock._physics_process(0.0)
	assert_float(clock.now - before).is_equal_approx(1.0 / 30.0, 0.00001)
	Engine.physics_ticks_per_second = 60
	before = clock.now
	clock._physics_process(0.0)
	assert_float(clock.now - before).is_equal_approx(1.0 / 60.0, 0.00001)
