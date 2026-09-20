extends GdUnitTestSuite

## Hit queue RESOLUTION tests (F03-22; src/core/sim_loop.gd >
## `_step_07_hit_queue_resolution()` / `_resolve_one_hit()`). Distinct from
## tests/unit/sim_loop_order_test.gd's own `test_hit_queue_sorts_by_target_
## then_attacker_serial`, which proves the SORT alone, against hit records
## with no `target_hurtbox` -- nothing in that test is ever actually
## damaged. This file proves the sort is used to drive real RESOLUTION
## against real Hurtbox instances: docs/20 > SimLoop order, step 7 sorts by
## (target serial, attacker serial) and applies the damage in that order,
## and a target already Logically Dead earlier in the same tick takes no
## further hits (the ghost-hit guarantee, now enforced at resolution time
## instead of at the moment an Area2D overlap fires).

const SimLoopScript: GDScript = preload("res://src/core/sim_loop.gd")
const HurtboxScript: GDScript = preload("res://src/combat/hurtbox.gd")

var _loop: Node


func before_test() -> void:
	_loop = auto_free(SimLoopScript.new()) as Node
	add_child(_loop)
	await get_tree().physics_frame


func after_test() -> void:
	get_tree().paused = false


func _make_hurtbox(faction: Hurtbox.Faction = Hurtbox.Faction.ENEMY) -> Hurtbox:
	var hb: Hurtbox = auto_free(HurtboxScript.new()) as Hurtbox
	hb.faction = faction
	add_child(hb)
	return hb


## The falsification target named in this task's brief: "removing the sort
## in step 7". Two hits are enqueued in the WRONG order (target serial 5
## before target serial 2); if `_step_07_hit_queue_resolution()` stopped
## sorting before resolving, they would apply in enqueue order (b then a)
## instead of the documented (target serial, attacker serial) order (a
## then b).
func test_two_hits_enqueued_out_of_order_resolve_in_target_then_attacker_serial_order() -> void:
	var target_a: Hurtbox = _make_hurtbox()
	var target_b: Hurtbox = _make_hurtbox()
	var resolution_order: Array = []
	target_a.damage_received.connect(func(_amt: float, _src: Variant, _hb: Node) -> void: resolution_order.append("a"))
	target_b.damage_received.connect(func(_amt: float, _src: Variant, _hb: Node) -> void: resolution_order.append("b"))

	# Enqueued "wrong" (b, target serial 5, first) on purpose.
	_loop.enqueue_hit(9, 5, 10.0, "attacker_b", target_b, null, Callable())
	_loop.enqueue_hit(3, 2, 10.0, "attacker_a", target_a, null, Callable())

	await get_tree().physics_frame

	assert_array(resolution_order).append_failure_message(
		"hits resolved in enqueue order %s instead of ascending target-serial order [a, b] (target serial 2 before 5)" % str(resolution_order)
	).is_equal(["a", "b"])


## Same claim, read back from get_last_hit_queue_snapshot_for_test() rather
## than signal order, matching the project's existing convention
## (sim_loop_order_test.gd's own test) but now on a queue that also carries
## resolvable target_hurtbox/attacker_node/callback fields.
func test_snapshot_reflects_the_sorted_order_used_for_resolution() -> void:
	var target_a: Hurtbox = _make_hurtbox()
	var target_b: Hurtbox = _make_hurtbox()
	_loop.enqueue_hit(9, 5, 10.0, "attacker_b", target_b, null, Callable())
	_loop.enqueue_hit(3, 2, 10.0, "attacker_a", target_a, null, Callable())

	await get_tree().physics_frame

	var snapshot: Array = _loop.get_last_hit_queue_snapshot_for_test()
	assert_int(snapshot.size()).is_equal(2)
	assert_int(snapshot[0]["target_serial"]).is_equal(2)
	assert_int(snapshot[1]["target_serial"]).is_equal(5)


## docs/20 > "Logical Death": "a hit already queued against a dying entity
## is discarded rather than applied twice." Marking the target dead
## synchronously (simulating an earlier step's Logical Death, same tick)
## BEFORE step 7 ever runs must still discard the queued hit -- this is the
## ghost-hit guarantee surviving the move from immediate resolution to
## queued resolution.
func test_a_hit_against_a_target_already_dead_this_same_tick_is_discarded() -> void:
	var target: Hurtbox = _make_hurtbox()
	var received: Dictionary = {"count": 0}
	target.damage_received.connect(func(_a: float, _s: Variant, _h: Node) -> void: received["count"] += 1)

	_loop.enqueue_hit(1, 0, 10.0, "attacker", target, null, Callable())
	target.mark_dead() # Logical Death already happened earlier this same tick

	await get_tree().physics_frame

	assert_int(received["count"]).append_failure_message(
		"a hit against an already-Logically-Dead target resolved anyway -- the ghost-hit guarantee did not survive moving resolution into step 7"
	).is_equal(0)


## The `on_hit_accepted` callback (what hitbox.gd/player_projectile.gd bind
## their own `hit_landed` signal into) must fire once per ACCEPTED hit, and
## must NOT fire for a discarded (already-dead-target) hit.
func test_on_hit_accepted_callback_fires_only_for_accepted_hits() -> void:
	var live_target: Hurtbox = _make_hurtbox()
	var dead_target: Hurtbox = _make_hurtbox()
	dead_target.mark_dead()

	var accepted_count: Dictionary = {"count": 0}
	_loop.enqueue_hit(1, 0, 10.0, "attacker", live_target, null, func() -> void: accepted_count["count"] += 1)
	_loop.enqueue_hit(2, 1, 10.0, "attacker", dead_target, null, func() -> void: accepted_count["count"] += 1)

	await get_tree().physics_frame

	assert_int(accepted_count["count"]).append_failure_message("on_hit_accepted fired a count other than exactly 1 (one accepted hit, one discarded)").is_equal(1)


## A record with no target_hurtbox (the sort-only shape
## sim_loop_order_test.gd's own coverage uses) must resolve to a no-op, not
## an error -- backward compatibility for that existing suite.
func test_a_hit_record_with_no_target_hurtbox_resolves_to_a_no_op() -> void:
	_loop.enqueue_hit(5, 2, 10.0, "player_weapon")
	await get_tree().physics_frame
	# No assertion beyond "this did not error" -- the point is exercised by
	# the suite simply completing; get_last_step_log_for_test() still shows
	# step 7 ran.
	assert_array(_loop.get_last_step_log_for_test()).contains(["07_hit_queue_resolution"])
