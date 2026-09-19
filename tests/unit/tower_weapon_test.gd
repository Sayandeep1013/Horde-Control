extends GdUnitTestSuite

## Tower weapon check (P2.4 named acceptance test). MASTER_SDLC.md > Tower
## Overview > "Tower Targeting Rule": "The Tower auto-fires at 20 damage
## per shot, 1.25 shots per second (25 DPS, Provisional Default),
## projectile speed 900 px/s. The Tower targets the nearest Tower Seeker in
## range, else the nearest enemy in range; a non-Seeker target is dropped
## on the tick a Seeker enters range; otherwise it retargets only when its
## target dies or leaves range. Provisional Default range: three times the
## Interaction Radius (480 pixels in the prototype arena)." (C-TOWERTARGET)
## -- every number read from data/tower/base.tres / data/tower/
## base_weapon.tres via scenes/tower.tscn, never restated as a literal in
## assertions below.
##
## Real Area2D overlap detection (the projectile hitting an enemy's
## Hurtbox) requires Godot's own physics server, which only runs on real
## engine physics ticks -- unlike the other two P2.4 suites, this one uses
## `await get_tree().physics_frame` throughout (matching tests/unit/
## ghost_hit_test.gd's and death_state_test.gd's own established pattern
## for anything that needs a real Area2D overlap), reading the REAL
## SimClock Autoload directly rather than an injected fresh instance.
##
## Falsifications, each with its own test below:
##   1. Fires on cadence and deals exactly the Register's damage per shot,
##      confirmed by both the per-shot amount AND the inter-shot timing.
##   2. Prefers a farther Tower Seeker over a nearer non-Seeker (falsifies
##      "just targets nearest enemy regardless of intent").
##   3. Drops a non-Seeker target the tick a Seeker enters range (falsifies
##      "keeps whatever it already had").
##   4. Keeps its current target even when a strictly closer enemy appears
##      (falsifies "always re-picks the nearest every tick").
##   5. An actual kill at the Register's damage-per-shot cadence.

const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlaceholderEnemyScene: PackedScene = preload("res://scenes/entities/placeholder_enemy.tscn")

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

const REGISTER_DAMAGE_PER_SHOT: float = 20.0
const REGISTER_FIRE_RATE_PER_SECOND: float = 1.25
const REGISTER_FIRE_INTERVAL_SECONDS: float = 1.0 / REGISTER_FIRE_RATE_PER_SECOND

var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)


func _build_tower(position: Vector2 = Vector2.ZERO) -> Node:
	var tower: Node = auto_free(TowerScene.instantiate())
	add_child(tower)
	tower.global_position = position
	tower.weapon.set_registry_for_test(_registry)
	return tower


## `max_hp = -1.0` keeps death_state.gd's own default (30.0, per its own
## header's "framework/test-fixture default" carve-out) untouched.
func _build_enemy(position: Vector2, tags: Array = [&"enemy"], max_hp: float = -1.0) -> Node:
	var enemy: Node = auto_free(PlaceholderEnemyScene.instantiate())
	if max_hp > 0.0:
		var ds: DeathState = enemy.get_node("DeathState") as DeathState
		ds.max_hp = max_hp
	add_child(enemy)
	enemy.global_position = position
	_registry.register_entity(enemy, position, tags)
	return enemy


# --- Falsification 1: fires on cadence, exact damage per shot --------------

func test_fires_at_the_registers_cadence_and_damage_per_shot() -> void:
	var tower: Node = _build_tower()
	var enemy: Node = _build_enemy(Vector2(100, 0), [&"enemy"], 100000.0) # will not die mid-test

	var hits: Array = [] # [{amount, timestamp}]
	(enemy.get_node("DeathState") as DeathState).damage_applied.connect(func(amount: float, _source: Variant, _remaining: float) -> void:
		hits.append({"amount": amount, "timestamp": SimClock.now})
	)

	var iterations: int = 0
	while hits.size() < 3 and iterations < 400:
		await get_tree().physics_frame
		iterations += 1

	assert_int(hits.size()).append_failure_message("fewer than 3 shots landed within the timeout -- weapon is not firing on cadence").is_greater_equal(3)
	for h in hits:
		assert_float(h["amount"]).append_failure_message("a shot dealt the wrong damage amount").is_equal_approx(REGISTER_DAMAGE_PER_SHOT, 0.01)

	# Inter-shot timing: consecutive hits should be REGISTER_FIRE_INTERVAL_
	# SECONDS apart (1 / 1.25 = 0.8s), within a couple of physics ticks'
	# tolerance for the frame the overlap was actually detected on.
	var tolerance: float = SimClock.PHYSICS_STEP * 3.0
	for i in range(1, hits.size()):
		var gap: float = hits[i]["timestamp"] - hits[i - 1]["timestamp"]
		assert_float(gap).append_failure_message("shot %d->%d gap was %.4fs, expected ~%.4fs (1 / fire_rate_per_second)" % [i - 1, i, gap, REGISTER_FIRE_INTERVAL_SECONDS]).is_equal_approx(REGISTER_FIRE_INTERVAL_SECONDS, tolerance)


## Polls up to `max_iterations` real physics frames until `tower.weapon.
## get_current_target()` matches `expected` (or gives up). A freshly
## add_child()-ed node is not guaranteed to receive its first
## _physics_process call on the very next awaited physics_frame
## (tests/unit/pause_clock_test.gd's own before_test() comment names this
## exact engine caveat) -- polling with a generous cap, rather than a fixed
## single/double await, is robust to that without weakening what the
## assertion after this call actually checks.
func _wait_until_target_is(tower: Node, expected: Node, max_iterations: int = 30) -> void:
	var iterations: int = 0
	while tower.weapon.get_current_target() != expected and iterations < max_iterations:
		await get_tree().physics_frame
		iterations += 1


# --- Falsification 2: prefers a farther Seeker over a nearer non-Seeker ----

func test_prefers_a_farther_tower_seeker_over_a_nearer_non_seeker() -> void:
	var tower: Node = _build_tower()
	var near_non_seeker: Node = _build_enemy(Vector2(50, 0), [&"enemy"])
	var far_seeker: Node = _build_enemy(Vector2(200, 0), [&"enemy", &"tower_seeker"])

	await _wait_until_target_is(tower, far_seeker)

	assert_object(tower.weapon.get_current_target()).append_failure_message("Tower targeted the nearer non-Seeker (%s) instead of the farther Tower Seeker -- C-TOWERTARGET requires Seeker priority" % near_non_seeker).is_same(far_seeker)


# --- Falsification 3: drops a non-Seeker target the tick a Seeker enters --

func test_drops_a_non_seeker_target_the_tick_a_seeker_enters_range() -> void:
	var tower: Node = _build_tower()
	var non_seeker: Node = _build_enemy(Vector2(80, 0), [&"enemy"])

	await _wait_until_target_is(tower, non_seeker)
	assert_object(tower.weapon.get_current_target()).is_same(non_seeker)

	var seeker: Node = _build_enemy(Vector2(300, 0), [&"enemy", &"tower_seeker"])
	await _wait_until_target_is(tower, seeker)

	assert_object(tower.weapon.get_current_target()).append_failure_message("a non-Seeker target was not dropped on the tick a Tower Seeker entered range").is_same(seeker)


# --- Falsification 4: keeps its target even when a closer enemy appears ----

func test_keeps_its_current_target_until_it_dies_or_leaves_range_even_if_a_closer_enemy_appears() -> void:
	var tower: Node = _build_tower()
	var original_target: Node = _build_enemy(Vector2(300, 0), [&"enemy"])

	await _wait_until_target_is(tower, original_target)
	assert_object(tower.weapon.get_current_target()).is_same(original_target)

	var _closer_enemy: Node = _build_enemy(Vector2(20, 0), [&"enemy"])
	# Give the weapon several extra ticks to (wrongly) re-target if it were
	# going to -- more than the single tick a "drop" would need, so this
	# genuinely exercises "otherwise it retargets only when its target dies
	# or leaves range" rather than just not having looked yet.
	for _i in 10:
		await get_tree().physics_frame

	assert_object(tower.weapon.get_current_target()).append_failure_message("Tower re-picked a closer target instead of keeping the one that has neither died nor left range").is_same(original_target)


# --- Falsification 5: an actual kill at the Register's cadence -------------

func test_kills_a_target_within_the_expected_number_of_shots() -> void:
	var tower: Node = _build_tower()
	# 2 shots (40 dmg) kill a 25-HP target; ceil(25 / 20) = 2.
	var enemy: Node = _build_enemy(Vector2(60, 0), [&"enemy"], 25.0)
	var death_state: DeathState = enemy.get_node("DeathState") as DeathState
	var start_time: float = SimClock.now # SimClock.now is a shared, never-reset Autoload across the whole suite run -- measure ELAPSED time, never an absolute value

	var iterations: int = 0
	while not death_state.is_dead and iterations < 400:
		await get_tree().physics_frame
		iterations += 1

	assert_bool(death_state.is_dead).append_failure_message("target was not killed within the timeout").is_true()
	# 2 shots at 0.8s cadence: death should land well before a 3rd shot
	# would have been due (2.4s) -- generous upper bound, not a tight one,
	# since the first shot's travel time and frame quantization both add a
	# small amount of slack.
	var elapsed: float = SimClock.now - start_time
	assert_float(elapsed).append_failure_message("kill took %.4fs, expected under 2 shots' worth of cadence plus slack" % elapsed).is_less(2.0 * REGISTER_FIRE_INTERVAL_SECONDS + 0.5)
