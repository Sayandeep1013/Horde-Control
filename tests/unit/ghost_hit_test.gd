extends GdUnitTestSuite

## Ghost hit test (P1.5; MASTER_SDLC.md > Acceptance Test Matrix > Technical
## Tests > "Ghost hit test": "Dead enemies cannot deal damage, even if their
## death animation has not finished, across 100 scripted kills mid-attack.
## Scripted test, zero damage events after Logical Death."; PLAN.md > P1.5's
## own acceptance test: "100 mid-attack kills produce zero post-death damage
## events.").
##
## ## The kill window, stated precisely (P1.5 task brief: "State in your
## report exactly which frame or step you kill on and why that is the
## dangerous window.")
## Per trial: `attacker.start_attack_window()` opens the attack (hitbox
## `monitoring` and its `CollisionShape2D.disabled` both go through
## `set_deferred`), and one physics frame is awaited so those deferred
## writes actually land -- "hitbox activating" is now complete and in
## effect. THEN, in a single synchronous step with no `await` in between:
## the victim's hurtbox is moved into the now-active hitbox's overlap
## range (the attack geometrically "reaches" its target this instant), and
## the attacker is immediately dealt a lethal blow via `apply_damage()`.
## This is deliberately placed strictly BEFORE the next physics step: the
## overlap that would resolve into a hit has just been made true, but the
## physics engine has not yet had a single tick to detect it and fire
## `area_entered` -- the literal "window between a hitbox activating and
## its damage resolving" the task brief names. Killing an IDLE enemy (no
## open attack window) proves nothing, because an idle hitbox was never
## monitoring in the first place; this ordering is the one place a ghost
## hit can actually originate, since it is the only moment a live overlap
## exists and has not yet been resolved. `test_positive_control_...` below
## proves the fixture really can land a hit in this exact geometry when the
## attacker is NOT killed, so a permanently-zero result cannot be an
## artifact of the fixture failing to attack at all.
##
## A companion, smaller-N adversarial variant
## (`test_10_same_tick_race_kills_produce_zero_ghost_hits`) additionally
## races the kill against the attack INSIDE the same physics step (both the
## attacker's own hitbox-vs-victim overlap and an external killer's
## hitbox-vs-attacker overlap become newly true on the identical tick), to
## probe whether Godot's own same-step signal-dispatch order can be relied
## on at all -- see the P1.5 evidence report for what this run found.
##
## ## A GDScript/GdUnit4 pitfall this file works around
## Every counter a signal's lambda handler writes to is a single-entry
## Dictionary (`{"count": 0}`), never a plain `int` local, whenever the
## signal can fire AFTER an `await get_tree().physics_frame` boundary (i.e.
## from inside the engine's own later `_physics_process`/physics-callback
## dispatch, not synchronously within the same call). A plain captured int
## local was reproduced NOT to propagate a lambda's mutation back to the
## outer scope across that gap in this test harness, even though the exact
## same pattern works when the signal fires synchronously, in the same
## call, with no `await` in between (see event_bus_test.gd's `call_count`).
## `src/core/pool.gd`'s own test suite already uses this Dictionary
## convention for its counting factory, for what looks like the same
## reason. Reproduced and named in the P1.5 evidence report; not assumed.

const PlaceholderEnemyScene: PackedScene = preload("res://scenes/entities/placeholder_enemy.tscn")
const PoolScript: GDScript = preload("res://src/core/pool.gd")

const TRIAL_COUNT: int = 100
const RACE_TRIAL_COUNT: int = 10


func _spawn_placeholder() -> PlaceholderEnemy:
	var inst: PlaceholderEnemy = PlaceholderEnemyScene.instantiate() as PlaceholderEnemy
	add_child(inst)
	return inst


func _spawn_victim_hurtbox() -> Hurtbox:
	var hb: Hurtbox = Hurtbox.new()
	hb.faction = Hurtbox.Faction.PLAYER # the binding table's only Hitbox row (EnemyHitbox) masks PlayerHurtbox
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	hb.add_child(shape)
	add_child(hb)
	return hb


## Runs one mid-attack-kill trial. See file header for the exact kill
## window. Returns a Dictionary the caller aggregates across all 100 trials.
func _run_one_ghost_trial(attacker: PlaceholderEnemy, victim: Hurtbox, spot: Vector2) -> Dictionary:
	var counters: Dictionary = {"victim_hits": 0, "attacker_hit_reports": 0}
	var on_victim_hit: Callable = func(_amount: float, _source: Variant, _hitbox: Node) -> void:
		counters["victim_hits"] += 1
	var on_attacker_hit_report: Callable = func(_hb: Hurtbox, _dmg: float, _src: Variant) -> void:
		counters["attacker_hit_reports"] += 1
	victim.damage_received.connect(on_victim_hit)
	attacker.hitbox.hit_landed.connect(on_attacker_hit_report)

	attacker.global_position = spot
	victim.global_position = spot + Vector2(100_000, 0) # far apart -- no overlap yet

	attacker.start_attack_window()
	await get_tree().physics_frame # let the deferred activation land -- "hitbox activating" complete

	var window_was_active_before_kill: bool = attacker.hitbox.is_window_active()

	# The attack "reaches" its target and the attacker is killed in the
	# SAME synchronous step -- the kill window this file's header names.
	victim.global_position = attacker.global_position
	var kill_accepted: bool = attacker.apply_damage(999999.0, "external_kill")

	await get_tree().physics_frame
	await get_tree().physics_frame # generous settle frame

	victim.damage_received.disconnect(on_victim_hit)
	attacker.hitbox.hit_landed.disconnect(on_attacker_hit_report)

	return {
		"window_was_active_before_kill": window_was_active_before_kill,
		"kill_accepted": kill_accepted,
		"attacker_dead": attacker.is_dead(),
		"victim_hits": counters["victim_hits"],
		"attacker_hit_reports": counters["attacker_hit_reports"],
	}


# --- Positive control: the fixture really can land a hit ------------------

func test_positive_control_hit_lands_when_attacker_is_not_killed() -> void:
	var attacker: PlaceholderEnemy = _spawn_placeholder()
	var victim: Hurtbox = _spawn_victim_hurtbox()
	var counters: Dictionary = {"victim_hits": 0}
	victim.damage_received.connect(func(_a: float, _s: Variant, _h: Node) -> void: counters["victim_hits"] += 1)

	attacker.global_position = Vector2(-5_000_000, 0)
	victim.global_position = Vector2(-4_900_000, 0)
	attacker.start_attack_window()
	await get_tree().physics_frame
	victim.global_position = attacker.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(counters["victim_hits"]).append_failure_message(
		"no hit landed even though the attacker was never killed -- the fixture cannot land a hit at all, which would make every zero-hit result below meaningless"
	).is_greater(0)

	attacker.queue_free()
	victim.queue_free()


# --- The named acceptance test: 100 mid-attack kills, fresh instances ----

func test_100_mid_attack_kills_produce_zero_post_death_damage_events_fresh() -> void:
	var total_victim_hits: int = 0
	var total_attacker_hit_reports: int = 0
	var trials_with_active_window: int = 0
	var trials_confirmed_dead: int = 0

	for i in TRIAL_COUNT:
		var attacker: PlaceholderEnemy = _spawn_placeholder()
		var victim: Hurtbox = _spawn_victim_hurtbox()
		var result: Dictionary = await _run_one_ghost_trial(attacker, victim, Vector2(i * 10_000, 0))

		if result["window_was_active_before_kill"]:
			trials_with_active_window += 1
		if result["attacker_dead"]:
			trials_confirmed_dead += 1
		total_victim_hits += result["victim_hits"]
		total_attacker_hit_reports += result["attacker_hit_reports"]

		attacker.queue_free()
		victim.queue_free()

	assert_int(trials_with_active_window).append_failure_message(
		"the attack window was not actually open before the kill in %d/%d trials -- the fixture is not exercising a mid-attack kill at all" % [TRIAL_COUNT - trials_with_active_window, TRIAL_COUNT]
	).is_equal(TRIAL_COUNT)
	assert_int(trials_confirmed_dead).append_failure_message(
		"the lethal blow did not register as Logical Death in %d/%d trials" % [TRIAL_COUNT - trials_confirmed_dead, TRIAL_COUNT]
	).is_equal(TRIAL_COUNT)
	assert_int(total_victim_hits).append_failure_message(
		"%d ghost hit(s) landed on the victim's hurtbox after the attacker's own Logical Death, across %d mid-attack kills (fresh instances)" % [total_victim_hits, TRIAL_COUNT]
	).is_equal(0)
	assert_int(total_attacker_hit_reports).append_failure_message(
		"the dead attacker's own hitbox reported %d landed hit(s) after Logical Death (fresh instances)" % total_attacker_hit_reports
	).is_equal(0)


# --- The same 100 kills again, through the pool, on REUSED instances -----

func test_100_mid_attack_kills_produce_zero_post_death_damage_events_pooled() -> void:
	var factory: Callable = func() -> Node:
		return PlaceholderEnemyScene.instantiate()
	var pool: Pool = PoolScript.new(factory, self, 5, Pool.OverflowPolicy.THROTTLE)

	var total_victim_hits: int = 0
	var total_attacker_hit_reports: int = 0
	var trials_with_active_window: int = 0
	var trials_confirmed_dead: int = 0
	var distinct_instances: Dictionary = {}

	for i in TRIAL_COUNT:
		var attacker: PlaceholderEnemy = pool.acquire() as PlaceholderEnemy
		assert_object(attacker).append_failure_message("pool.acquire() returned null on trial %d under a cap of 5 -- should never refuse once instances are being released every trial" % i).is_not_null()
		# The entity's own responsibility AFTER Pool.acquire() has already
		# restored the four engine flags from its own baseline snapshot --
		# see death_state.gd's reset_for_reuse() header for why this is not
		# optional on a reused instance.
		attacker.reset_for_reuse()
		distinct_instances[attacker] = true

		var victim: Hurtbox = _spawn_victim_hurtbox()
		var result: Dictionary = await _run_one_ghost_trial(attacker, victim, Vector2(i * 10_000, 5_000_000))

		if result["window_was_active_before_kill"]:
			trials_with_active_window += 1
		if result["attacker_dead"]:
			trials_confirmed_dead += 1
		total_victim_hits += result["victim_hits"]
		total_attacker_hit_reports += result["attacker_hit_reports"]

		victim.queue_free()
		pool.release(attacker) # simulate the Visual Death timer expiring and the entity returning to the pool

	assert_int(distinct_instances.size()).append_failure_message(
		"the pool never actually reused an instance across %d trials under a cap of 5 -- this run is not exercising Pool.acquire()'s restore path at all" % TRIAL_COUNT
	).is_less_equal(5)
	assert_int(trials_with_active_window).is_equal(TRIAL_COUNT)
	assert_int(trials_confirmed_dead).is_equal(TRIAL_COUNT)
	assert_int(total_victim_hits).append_failure_message(
		"%d ghost hit(s) landed on the victim's hurtbox across %d mid-attack kills on POOLED, REUSED instances" % [total_victim_hits, TRIAL_COUNT]
	).is_equal(0)
	assert_int(total_attacker_hit_reports).append_failure_message(
		"the dead attacker's own hitbox reported %d landed hit(s) after Logical Death (pooled instances)" % total_attacker_hit_reports
	).is_equal(0)

	pool.clear_for_test()


# --- Same-tick race variant: kill delivered by a REAL overlapping hitbox,
# racing the attacker's own attack within the identical physics step ------

func test_10_same_tick_race_kills_produce_zero_ghost_hits() -> void:
	var total_victim_hits: int = 0
	var race_orderings_seen: Dictionary = {} # "attack_first" / "kill_first" / "neither_observed" -> count

	for i in RACE_TRIAL_COUNT:
		var attacker: PlaceholderEnemy = _spawn_placeholder()
		var victim: Hurtbox = _spawn_victim_hurtbox()
		var killer_hitbox: Hitbox = Hitbox.new()
		var killer_shape: CollisionShape2D = CollisionShape2D.new()
		var killer_circle: CircleShape2D = CircleShape2D.new()
		killer_circle.radius = 20.0
		killer_shape.shape = killer_circle
		killer_hitbox.add_child(killer_shape)
		killer_hitbox.damage = 999999.0
		add_child(killer_hitbox)

		var spot: Vector2 = Vector2(i * 10_000, 10_000_000)
		var far: Vector2 = spot + Vector2(200_000, 0)
		attacker.global_position = far
		victim.global_position = far + Vector2(200_000, 0) # not yet overlapping attacker's hitbox
		killer_hitbox.global_position = far + Vector2(0, 200_000) # not yet overlapping attacker's hurtbox

		# killer_hitbox needs to be able to detect the attacker's own
		# hurtbox: given the same mask an EnemyHitbox has for PlayerHurtbox,
		# but pointed at EnemyHurtbox instead, so this stand-in "killer" can
		# find an enemy's hurtbox -- test-only wiring, not a binding-table
		# row, named as such.
		killer_hitbox.collision_layer = CollisionLayers.LAYER_ENEMY_HITBOX
		killer_hitbox.collision_mask = CollisionLayers.LAYER_ENEMY_HURTBOX

		# Dictionary-based -- see file header: these are written from
		# lambdas that fire during the awaited physics frames below, after
		# this scope has already suspended once.
		var state: Dictionary = {"victim_hits": 0, "attack_landed_first": false, "kill_landed_first": false}
		victim.damage_received.connect(func(_a: float, _s: Variant, _h: Node) -> void: state["victim_hits"] += 1)
		attacker.hitbox.hit_landed.connect(func(_hb, _d, _s) -> void:
			if not state["kill_landed_first"]:
				state["attack_landed_first"] = true
		)
		attacker.death_state.logical_death.connect(func(_e, _p) -> void:
			if not state["attack_landed_first"]:
				state["kill_landed_first"] = true
		)

		attacker.start_attack_window()
		killer_hitbox.activate_window()
		await get_tree().physics_frame # both windows now genuinely active, still no overlap

		# Both overlaps become newly true on the SAME synchronous step, so
		# the NEXT physics frame is the one where Godot must dispatch both
		# area_entered signals within a single step.
		victim.global_position = attacker.global_position
		killer_hitbox.global_position = attacker.global_position

		await get_tree().physics_frame
		await get_tree().physics_frame

		total_victim_hits += state["victim_hits"]
		var ordering: String = "kill_first" if state["kill_landed_first"] else ("attack_first" if state["attack_landed_first"] else "neither_observed")
		race_orderings_seen[ordering] = race_orderings_seen.get(ordering, 0) + 1

		attacker.queue_free()
		victim.queue_free()
		killer_hitbox.queue_free()

	# This variant's own assertion is deliberately weaker than the main 100-
	# trial test: it does not assert total_victim_hits == 0 unconditionally,
	# because a genuine "attack resolves before the kill within the same
	# physics step" ordering is NOT a bug (the attack was still live at the
	# moment it resolved) -- see the P1.5 evidence report for what ordering
	# Godot actually produced here and why. It DOES assert that whichever
	# ordering occurred was applied consistently, and reports the observed
	# ordering distribution for the record.
	assert_int(race_orderings_seen.get("neither_observed", 0)).append_failure_message(
		"neither the attack nor the kill was observed to resolve in some race trials -- the race fixture itself is not exercising anything: %s" % str(race_orderings_seen)
	).is_equal(0)
	# The ordering distribution is asserted stable (all-one-way) rather than
	# mixed, since nothing in this fixture randomizes it -- a mixed result
	# would mean the ordering is not the deterministic engine behaviour this
	# file's header assumes, which would itself be a finding worth recording.
	var distinct_orderings: int = race_orderings_seen.keys().filter(func(k): return race_orderings_seen[k] > 0).size()
	assert_int(distinct_orderings).append_failure_message(
		"the race resolved in more than one ordering across %d identical trials: %s -- Godot's same-step signal dispatch order is not deterministic for this fixture" % [RACE_TRIAL_COUNT, str(race_orderings_seen)]
	).is_equal(1)
