extends GdUnitTestSuite

## Pool unit check (P1.3; MASTER_SDLC.md > Acceptance Test Matrix > Technical
## Tests: "10,000 acquire/release cycles with object count stable within
## +/-1%"), plus the Logical Death flag-restoration contract docs/20 makes
## the critical requirement of acquire() (see pool.gd's own header comment).
## Every fixture built here is unparented (container = null), so tests free
## everything they create in after_test() to avoid orphan warnings -- gdUnit4
## does not auto_free() raw nodes a Pool holds internally.

const PoolScript: GDScript = preload("res://src/core/pool.gd")

var _pool: Pool


func after_test() -> void:
	if _pool != null:
		_pool.clear_for_test()
	_pool = null


func _plain_factory() -> Callable:
	return func() -> Node2D:
		return Node2D.new()


# --- Pool unit check: 10,000 acquire/release cycles, object count stable --

func test_ten_thousand_single_object_cycles_keep_object_count_stable() -> void:
	var created: Dictionary = {"count": 0}
	var counting_factory: Callable = func() -> Node2D:
		created["count"] += 1
		return Node2D.new()
	_pool = PoolScript.new(counting_factory, null, 50, Pool.OverflowPolicy.THROTTLE)

	const ITERATIONS: int = 10000
	var sample_at_1000: int = -1
	for i in ITERATIONS:
		var inst: Node = _pool.acquire()
		assert_object(inst).append_failure_message("acquire() returned null well under the cap on cycle %d" % i).is_not_null()
		assert_bool(_pool.release(inst)).append_failure_message("release() refused an instance this pool just handed out, cycle %d" % i).is_true()
		if i == 999:
			sample_at_1000 = _pool.get_total_instance_count()

	var final_count: int = _pool.get_total_instance_count()
	assert_int(created["count"]).append_failure_message(
		"pool created %d distinct instances over %d acquire/release cycles instead of reusing the free list -- a leak" % [created["count"], ITERATIONS]
	).is_equal(1)

	var tolerance: int = maxi(1, int(ceil(sample_at_1000 * 0.01)))
	assert_int(final_count).append_failure_message(
		"object count drifted from %d (sampled at cycle 1000) to %d (at cycle %d), outside the +/-1%% stability band" % [sample_at_1000, final_count, ITERATIONS]
	).is_between(sample_at_1000 - tolerance, sample_at_1000 + tolerance)


func test_ten_thousand_batched_cycles_keep_object_count_stable() -> void:
	# Same invariant, exercised with 5 objects concurrently active at once
	# (2,000 batches x 5 = 10,000 total acquire() calls) rather than 1, so a
	# leak that only shows up with concurrency > 1 is also caught.
	var created: Dictionary = {"count": 0}
	var counting_factory: Callable = func() -> Node2D:
		created["count"] += 1
		return Node2D.new()
	_pool = PoolScript.new(counting_factory, null, 50, Pool.OverflowPolicy.THROTTLE)

	const BATCHES: int = 2000
	const BATCH_SIZE: int = 5
	var sample_at_batch_200: int = -1
	for b in BATCHES:
		var batch: Array[Node] = []
		for j in BATCH_SIZE:
			var inst: Node = _pool.acquire()
			assert_object(inst).append_failure_message("acquire() returned null under the cap, batch %d slot %d" % [b, j]).is_not_null()
			batch.append(inst)
		for inst in batch:
			assert_bool(_pool.release(inst)).is_true()
		if b == 199:
			sample_at_batch_200 = _pool.get_total_instance_count()

	var final_count: int = _pool.get_total_instance_count()
	assert_int(created["count"]).append_failure_message(
		"pool created %d distinct instances instead of settling at the steady-state pool size of %d -- a leak" % [created["count"], BATCH_SIZE]
	).is_equal(BATCH_SIZE)

	var tolerance: int = maxi(1, int(ceil(sample_at_batch_200 * 0.01)))
	assert_int(final_count).append_failure_message(
		"object count drifted from %d (sampled at batch 200) to %d (at batch %d), outside the +/-1%% stability band" % [sample_at_batch_200, final_count, BATCHES]
	).is_between(sample_at_batch_200 - tolerance, sample_at_batch_200 + tolerance)


# --- Overflow policy -------------------------------------------------------

func test_throttle_policy_refuses_once_cap_reached() -> void:
	_pool = PoolScript.new(_plain_factory(), null, 3, Pool.OverflowPolicy.THROTTLE)
	for i in 3:
		assert_object(_pool.acquire()).append_failure_message("acquire() refused under the cap, slot %d" % i).is_not_null()
	assert_object(_pool.acquire()).append_failure_message("THROTTLE handed out a 4th instance past a cap of 3").is_null()
	assert_int(_pool.get_active_count()).is_equal(3)


func test_recycle_oldest_policy_never_exceeds_cap_and_reclaims_oldest() -> void:
	_pool = PoolScript.new(_plain_factory(), null, 3, Pool.OverflowPolicy.RECYCLE_OLDEST)
	var first: Node = _pool.acquire()
	var second: Node = _pool.acquire()
	var third: Node = _pool.acquire()
	assert_int(_pool.get_active_count()).is_equal(3)

	var fourth: Node = _pool.acquire() # cap already reached; must reclaim `first`
	assert_object(fourth).append_failure_message("RECYCLE_OLDEST returned null instead of reclaiming the oldest active instance").is_not_null()
	assert_int(_pool.get_active_count()).append_failure_message("RECYCLE_OLDEST let the active count exceed the cap").is_equal(3)
	assert_object(fourth).append_failure_message("RECYCLE_OLDEST did not reuse the oldest active instance's own object").is_same(first)
	# `first` is no longer active under its own reference; the pool no
	# longer considers releasing it (a second time) to be a refusal.
	assert_bool(_pool.release(second)).is_true()
	assert_bool(_pool.release(third)).is_true()
	assert_bool(_pool.release(fourth)).is_true()


func test_zero_cap_never_spawns_under_either_policy() -> void:
	var throttle_pool: Pool = PoolScript.new(_plain_factory(), null, 0, Pool.OverflowPolicy.THROTTLE)
	assert_object(throttle_pool.acquire()).is_null()
	var recycle_pool: Pool = PoolScript.new(_plain_factory(), null, 0, Pool.OverflowPolicy.RECYCLE_OLDEST)
	assert_object(recycle_pool.acquire()).append_failure_message("RECYCLE_OLDEST crashed or spawned past a cap of 0 with nothing active to recycle").is_null()
	throttle_pool.clear_for_test()
	recycle_pool.clear_for_test()


func test_release_refuses_an_instance_it_never_handed_out() -> void:
	_pool = PoolScript.new(_plain_factory(), null, 5, Pool.OverflowPolicy.THROTTLE)
	var stranger: Node2D = auto_free(Node2D.new()) as Node2D
	assert_bool(_pool.release(stranger)).is_false()


# --- Logical Death flag restoration (the critical requirement) ------------

## Fixture standing in for a real pooled enemy, once P1.5's hitbox.gd /
## hurtbox.gd land: a body (root, group pool_body) with a hitbox child
## (group pool_hitbox) and a hurtbox child (group pool_hurtbox). Layer/mask
## numbers match docs/20's binding Collision Layers table (EnemyBody = 2,
## masks 1/2/3/4/15; EnemyHurtbox = 9) so the fixture reads as a real case,
## not an arbitrary one.
func _build_enemy_fixture() -> Dictionary:
	const ENEMY_BODY_LAYER: int = 1 << 1 # layer 2, EnemyBody
	const ENEMY_BODY_MASK: int = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 14) # masks 1,2,3,4,15
	const DYING_BODY_MASK: int = (1 << 3) | (1 << 14) # World(4) + ArenaBounds(15) only
	const ENEMY_HURTBOX_LAYER: int = 1 << 8 # layer 9, EnemyHurtbox

	var body: CharacterBody2D = CharacterBody2D.new()
	body.name = "Body"
	body.add_to_group(&"pool_body")
	body.collision_layer = ENEMY_BODY_LAYER
	body.collision_mask = ENEMY_BODY_MASK

	var hitbox: Area2D = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.add_to_group(&"pool_hitbox")
	hitbox.monitoring = true
	body.add_child(hitbox)

	var hurtbox: Area2D = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.add_to_group(&"pool_hurtbox")
	hurtbox.monitorable = true
	hurtbox.collision_layer = ENEMY_HURTBOX_LAYER
	body.add_child(hurtbox)

	return {
		"body": body, "hitbox": hitbox, "hurtbox": hurtbox,
		"body_layer": ENEMY_BODY_LAYER, "body_mask": ENEMY_BODY_MASK,
		"dying_mask": DYING_BODY_MASK, "hurtbox_layer": ENEMY_HURTBOX_LAYER,
	}


## Mutates the fixture exactly as docs/20 > Logical Death specifies:
## "every hitbox Area2D sets monitoring = false, the hurtbox Area2D sets
## monitorable = false and also collision_layer = 0 ..., and the body sets
## collision_layer = 0 and collision_mask to World (4) and ArenaBounds (15)
## only."
func _apply_logical_death(f: Dictionary) -> void:
	f["hitbox"].monitoring = false
	f["hurtbox"].monitorable = false
	f["hurtbox"].collision_layer = 0
	f["body"].collision_layer = 0
	f["body"].collision_mask = f["dying_mask"]


func test_acquire_restores_all_four_logical_death_flags_on_reuse() -> void:
	var f: Dictionary = _build_enemy_fixture()
	var factory: Callable = func() -> Node: return f["body"]
	_pool = PoolScript.new(factory, null, 5, Pool.OverflowPolicy.THROTTLE)

	var first: Node = _pool.acquire() # baseline snapshot taken here, at the fixture's clean state
	assert_object(first).is_same(f["body"])

	_apply_logical_death(f) # simulate the entity dying while active
	assert_bool(_pool.release(first)).is_true() # simulate Visual Death timer expiry -> pool return

	# Confirm the corpse really is in the mutated state before reuse, so a
	# passing restore assertion below cannot be an accident of the fixture
	# never having changed in the first place.
	assert_bool(f["hitbox"].monitoring).is_false()
	assert_bool(f["hurtbox"].monitorable).is_false()
	assert_int(f["hurtbox"].collision_layer).is_equal(0)
	assert_int(f["body"].collision_layer).is_equal(0)
	assert_int(f["body"].collision_mask).is_equal(f["dying_mask"])

	var reused: Node = _pool.acquire()
	assert_object(reused).append_failure_message("acquire() did not reuse the freed instance").is_same(first)

	assert_bool(f["hitbox"].monitoring).append_failure_message("acquire() did not restore hitbox.monitoring").is_true()
	assert_bool(f["hurtbox"].monitorable).append_failure_message("acquire() did not restore hurtbox.monitorable").is_true()
	assert_int(f["hurtbox"].collision_layer).append_failure_message("acquire() did not restore hurtbox.collision_layer").is_equal(f["hurtbox_layer"])
	assert_int(f["body"].collision_layer).append_failure_message("acquire() did not restore body.collision_layer").is_equal(f["body_layer"])
	assert_int(f["body"].collision_mask).append_failure_message("acquire() did not restore body.collision_mask").is_equal(f["body_mask"])
	# `reused` (== first, the fixture body) is still active; after_test()'s
	# _pool.clear_for_test() frees it, so this test does not free it itself.


func test_acquire_restore_is_a_no_op_for_an_instance_with_no_pool_groups() -> void:
	# A plain placeholder (no pool_hitbox/pool_hurtbox/pool_body groups) has
	# nothing Logical Death could have touched via this pool's convention;
	# acquire() must not error or fabricate flags for it.
	var plain := Node2D.new()
	var factory: Callable = func() -> Node: return plain
	_pool = PoolScript.new(factory, null, 5, Pool.OverflowPolicy.THROTTLE)
	var inst: Node = _pool.acquire()
	assert_object(inst).is_same(plain)
	assert_bool(_pool.release(inst)).is_true()
	var reused: Node = _pool.acquire()
	assert_object(reused).is_same(plain)
	# `reused` (== plain) is still active; after_test()'s
	# _pool.clear_for_test() frees it, so this test does not free it itself.
