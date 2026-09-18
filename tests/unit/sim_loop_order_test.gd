extends GdUnitTestSuite

## Supplementary coverage for src/core/sim_loop.gd -- NOT one of P1.1's two
## named acceptance tests (see pause_clock_test.gd and keyed_rng_test.gd
## for those). Exercises the fixed fifteen-step per-tick order docs/20 >
## Godot 4.x Implementation Standards > "SimLoop order" defines, and the
## hit queue's (target serial, attacker serial) sort -- the one step with
## fully specified logic at this phase.

const SimLoopScript: GDScript = preload("res://src/core/sim_loop.gd")

const EXPECTED_ORDER: Array[String] = [
	"01_input", "02_player_movement", "03_enemy_ai_and_movement",
	"04_weapon_targeting_and_firing", "05_projectile_movement_and_sweep",
	"06_windup_completion_and_contact_ticks", "07_hit_queue_resolution",
	"08_death_resolution", "09_drops", "10_pickup_movement_and_collection",
	"11_xp_and_level_up_requests", "12_console_channel_completion",
	"13_wave_director", "14_pause_flush", "15_ui_state",
]

var _loop: Node


func before_test() -> void:
	_loop = auto_free(SimLoopScript.new()) as Node
	add_child(_loop)
	# See pause_clock_test.gd's before_test() for why: one untested warm-up
	# tick settles the freshly-added node into the physics processing list
	# before a test starts counting ticks or reading step logs.
	await get_tree().physics_frame


func after_test() -> void:
	get_tree().paused = false


func test_one_tick_runs_all_fifteen_steps_in_order() -> void:
	await get_tree().physics_frame
	assert_array(_loop.get_last_step_log_for_test()).is_equal(EXPECTED_ORDER)


func test_hit_queue_sorts_by_target_then_attacker_serial() -> void:
	_loop.enqueue_hit(5, 2, 10.0, "player_weapon")
	_loop.enqueue_hit(1, 2, 7.0, "tower_weapon")
	_loop.enqueue_hit(3, 0, 4.0, "enemy_contact") # target serial 0 = player
	_loop.enqueue_hit(9, 1, 6.0, "enemy_contact") # target serial 1 = Tower

	await get_tree().physics_frame

	var snapshot: Array = _loop.get_last_hit_queue_snapshot_for_test()
	var ordered_attackers: Array = []
	for hit in snapshot:
		ordered_attackers.append(hit["attacker_serial"])
	# Expected: target 0 (attacker 3), target 1 (attacker 9), then target 2
	# ordered by attacker (1 before 5).
	assert_array(ordered_attackers).is_equal([3, 9, 1, 5])
