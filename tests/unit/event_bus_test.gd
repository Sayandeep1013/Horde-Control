extends GdUnitTestSuite

## Supplementary coverage for src/core/event_bus.gd (P1.2). Not the named
## acceptance test (see entity_registry_query_perf_test.gd for that); this
## exercises docs/20 > "Communication, events": a fresh EventBus instance
## per test (not the project's autoload singleton, so one test's connections
## can never leak into the next -- pause_clock_test.gd's own pattern), added
## to this suite's own tree so _ready() runs and process_mode is set.

const EventBusScript: GDScript = preload("res://src/core/event_bus.gd")

var _bus: Node


func before_test() -> void:
	_bus = auto_free(EventBusScript.new()) as Node
	add_child(_bus)


func test_process_mode_is_always() -> void:
	# MASTER_SDLC.md > Global Simulation Authority: "EventBus ... PROCESS_
	# MODE_ALWAYS, so they keep functioning while paused".
	assert_int(_bus.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_emit_enemy_died_carries_entity_position_and_sim_time() -> void:
	var received: Array = []
	_bus.enemy_died.connect(func(entity: Node2D, position: Vector2, timestamp: float) -> void:
		received.append([entity, position, timestamp])
	)
	var dummy: Node2D = auto_free(Node2D.new())
	var before_now: float = SimClock.now
	_bus.emit_enemy_died(dummy, Vector2(100, 200))

	assert_int(received.size()).is_equal(1)
	var call: Array = received[0]
	assert_object(call[0]).is_same(dummy)
	assert_vector(call[1]).is_equal(Vector2(100, 200))
	# Timestamp is SimClock.now (simulation time), never wall clock: it must
	# be readable back as a value SimClock itself would report at emit time,
	# not merely "some float" -- so a wall-clock stand-in (e.g. seconds since
	# epoch) would fail this bound just as loudly as a hardcoded 0.0 would.
	assert_float(call[2]).is_equal_approx(before_now, 0.001)


func test_emit_tower_damaged_carries_amount_and_resulting_pools() -> void:
	var received: Array = []
	_bus.tower_damaged.connect(func(amount: float, new_health: float, new_shield: float, timestamp: float) -> void:
		received.append([amount, new_health, new_shield, timestamp])
	)
	_bus.emit_tower_damaged(15.0, 485.0, 0.0)

	assert_int(received.size()).is_equal(1)
	var call: Array = received[0]
	assert_float(call[0]).is_equal(15.0)
	assert_float(call[1]).is_equal(485.0)
	assert_float(call[2]).is_equal(0.0)
	assert_float(call[3]).is_equal_approx(SimClock.now, 0.001)


func test_emit_draft_opened_carries_sim_time() -> void:
	var received: Array = []
	_bus.draft_opened.connect(func(timestamp: float) -> void: received.append(timestamp))
	_bus.emit_draft_opened()

	assert_int(received.size()).is_equal(1)
	assert_float(received[0]).is_equal_approx(SimClock.now, 0.001)


func test_signals_do_not_fire_without_an_explicit_emit_call() -> void:
	# A regression guard against the anti-pattern docs/20 bans elsewhere
	# (state broadcast on its own, with no caller-driven trigger): merely
	# holding a connection must never itself produce a call.
	var call_count: int = 0
	_bus.enemy_died.connect(func(_e: Node2D, _p: Vector2, _t: float) -> void: call_count += 1)
	await get_tree().process_frame
	await get_tree().physics_frame
	assert_int(call_count).is_equal(0)
