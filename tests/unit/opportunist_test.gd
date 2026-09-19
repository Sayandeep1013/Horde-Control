extends GdUnitTestSuite

## Opportunist test (P2.5 named acceptance test). MASTER_SDLC.md >
## Acceptance Test Matrix > Encounter Tests; docs/09_Enemy_AI_Architecture.md
## > "Opportunist event rule": "An Opportunist picks the closer of player
## and Tower at spawn. Tower distance is measured to the Tower's footprint
## edge. The out-of-range event fires after 3 continuous seconds outside
## the 400 px aggro range, and its timer restarts after every
## re-evaluation, whether or not the Opportunist switched. It re-evaluates
## only on three events: it takes damage from the other target; the
## out-of-range event fires; its current target dies. On re-evaluation it
## switches only if the other target is at least 25% closer than the
## current target and at least 3 seconds have passed since its last
## switch." Register > Enemies > "Opportunist" row cites the same numbers.
##
## Uses the REAL scenes/tower.tscn and scenes/player.tscn (not stand-ins)
## so the footprint-edge distance rule is exercised against the Tower's
## actual TowerFootprint resource (106 px), not an assumed radius, and so
## the "target dies" event is exercised against the real DeathState both
## scenes already carry. All three share one injected, isolated
## EntityRegistry; SimClock is a fresh injected instance driven manually
## (`driven_externally = true`, matching tests/unit/
## tower_health_recovery_test.gd's own precedent) so the 3s/3s timers cost
## no real wall-clock time.

const OpportunistScene: PackedScene = preload("res://scenes/entities/opportunist.tscn")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")

const AGGRO_RANGE_PX: float = 400.0
const OUT_OF_RANGE_SECONDS: float = 3.0
const SWITCH_LOCKOUT_SECONDS: float = 3.0
const TOWER_FOOTPRINT_RADIUS_PX: float = 106.0

var _registry: Node
var _clock: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new()) as Node
	AttackSlotManager.clear_all_for_test()


func _build_tower(position: Vector2) -> Node:
	var tower: Node = auto_free(TowerScene.instantiate())
	add_child(tower)
	tower.global_position = position
	tower.weapon.set_registry_for_test(_registry) # keeps the Tower's own weapon from touching the real Autoload registry
	return tower


func _build_player(position: Vector2) -> Node:
	var player: Node = PlayerScene.instantiate()
	player.set_registry_for_test(_registry)
	add_child(player)
	auto_free(player)
	player.global_position = position
	return player


func _build_opportunist(position: Vector2, tower: Node, player: Node) -> EnemyController:
	var enemy: EnemyController = OpportunistScene.instantiate() as EnemyController
	enemy.set_registry_for_test(_registry)
	enemy.set_sim_clock_for_test(_clock)
	enemy.driven_externally = true
	add_child(enemy)
	auto_free(enemy)
	enemy.global_position = position
	enemy.set_tower_reference(tower)
	enemy.set_player_for_test(player)
	return enemy


func _tick(enemy: EnemyController, seconds: float, step: float = 0.05) -> void:
	var steps: int = int(floor(seconds / step + 0.0001)) # floor, never round -- a "just short of a threshold" test must never accidentally overshoot it
	for _i in steps:
		_clock.now += step
		enemy.physics_step(step)


# --- Spawn pick and the footprint-edge distance rule -----------------------

func test_picks_the_closer_target_at_spawn_player_case() -> void:
	var tower: Node = _build_tower(Vector2(0, 0))
	var player: Node = _build_player(Vector2(2000, 0)) # far
	var enemy: EnemyController = _build_opportunist(Vector2(50, 0), tower, player) # close to Tower... but see next test for the edge nuance
	_tick(enemy, 0.1)
	assert_object(enemy.get_target_for_test()).append_failure_message("did not pick the closer target (Tower) at spawn").is_same(tower)


func test_footprint_edge_measurement_flips_the_spawn_pick_versus_a_naive_centre_distance() -> void:
	# Tower footprint radius 106px. Opportunist placed 150px from the
	# Tower's CENTRE (edge distance 150-106=44) and 100px from the player
	# (plain centre distance, no adjustment). A naive centre-to-centre
	# comparison (150 vs 100) picks the PLAYER; the Register's own rule
	# ("Tower distance is measured to the Tower's footprint edge", 44 vs
	# 100) picks the TOWER. This is the falsification target for the
	# footprint-edge rule specifically.
	var tower: Node = _build_tower(Vector2(0, 0))
	var player: Node = _build_player(Vector2(250, 0)) # 100px from the enemy at (150,0)... see below
	var enemy: EnemyController = _build_opportunist(Vector2(150, 0), tower, player)
	assert_float(enemy.global_position.distance_to(tower.global_position)).is_equal_approx(150.0, 0.01)
	assert_float(enemy.global_position.distance_to(player.global_position)).is_equal_approx(100.0, 0.01)
	_tick(enemy, 0.1)
	assert_object(enemy.get_target_for_test()).append_failure_message("spawn pick did not use the Tower's footprint-edge distance (expected Tower: 150-106=44px edge distance beats the player's 100px)").is_same(tower)


# --- Event 1: damaged by the other target, plus the 25%/lockout gate -------

func test_damaged_by_the_other_target_switches_when_at_least_25_percent_closer() -> void:
	var tower: Node = _build_tower(Vector2(0, 0))
	var player: Node = _build_player(Vector2(10000, 0)) # irrelevant to distance comparisons below except as "the other target"
	var enemy: EnemyController = _build_opportunist(Vector2(500, 0), tower, player) # ~394 edge-distance to Tower at spawn
	_tick(enemy, 0.1)
	assert_object(enemy.get_target_for_test()).is_same(tower) # closer at spawn

	# Computed from the enemy's ACTUAL post-tick distance, not a hardcoded
	# spawn-time figure -- a falsification finding from this task's own
	# pass: the enemy moves toward the Tower during `_tick(enemy, 0.1)`
	# (~11-22px), so a fixed offset assumed from the spawn distance leaves
	# far too thin a margin around the real 25% threshold once that drift
	# is added in, and can fail to distinguish "correctly not switching"
	# from "the 25% gate is broken" (see the sibling test's identical note).
	var dist_current: float = enemy.global_position.distance_to(tower.global_position) - TOWER_FOOTPRINT_RADIUS_PX
	# Comfortably past the 25%-closer threshold (0.75x): 0.4x, a wide margin.
	player.global_position = enemy.global_position + Vector2(dist_current * 0.4, 0)
	enemy.hurtbox.damage_received.emit(5.0, &"player", null)

	assert_object(enemy.get_target_for_test()).append_failure_message("did not switch to the player even though the player is well over 25% closer than the current Tower target").is_same(player)


func test_damaged_by_the_other_target_does_not_switch_when_not_25_percent_closer() -> void:
	var tower: Node = _build_tower(Vector2(0, 0))
	var player: Node = _build_player(Vector2(10000, 0))
	var enemy: EnemyController = _build_opportunist(Vector2(500, 0), tower, player) # ~394 edge-distance to Tower at spawn
	_tick(enemy, 0.1)
	assert_object(enemy.get_target_for_test()).is_same(tower)

	# Computed from the enemy's ACTUAL post-tick distance -- see the sibling
	# test's note above for why a hardcoded spawn-time figure is unsafe here
	# (this task's own falsification pass found the ORIGINAL hardcoded
	# version of this test failed to catch the 25%-threshold being removed
	# entirely: the fixed offset ended up on the wrong side of "closer at
	# all" once the enemy's own movement during setup was accounted for,
	# so mutating the threshold away changed nothing this test could see).
	# 0.9x is clearly "closer" (would switch under a broken/no-threshold
	# gate) but clearly short of the real 0.75x (25% closer) requirement --
	# a 15-percentage-point margin, robust to any remaining movement noise.
	var dist_current: float = enemy.global_position.distance_to(tower.global_position) - TOWER_FOOTPRINT_RADIUS_PX
	player.global_position = enemy.global_position + Vector2(dist_current * 0.9, 0)
	enemy.hurtbox.damage_received.emit(5.0, &"player", null)

	assert_object(enemy.get_target_for_test()).append_failure_message("switched even though the other target was not at least 25% closer -- hysteresis was not honoured").is_same(tower)


func test_damage_from_the_currently_targeted_faction_is_not_a_reevaluation_event() -> void:
	# "damage from the OTHER target" -- damage attributed to the faction the
	# Opportunist is ALREADY targeting must not trigger anything.
	var tower: Node = _build_tower(Vector2(0, 0))
	var player: Node = _build_player(Vector2(10000, 0))
	var enemy: EnemyController = _build_opportunist(Vector2(500, 0), tower, player)
	_tick(enemy, 0.1)
	assert_object(enemy.get_target_for_test()).is_same(tower)

	player.global_position = enemy.global_position + Vector2(1, 0) # trivially closer -- would switch if this counted as a trigger
	enemy.hurtbox.damage_received.emit(5.0, &"tower", null) # SAME faction as current target

	assert_object(enemy.get_target_for_test()).append_failure_message("re-evaluated on damage from its OWN current target's faction, not the other one").is_same(tower)


# --- The switch lockout ------------------------------------------------------

func test_switch_lockout_blocks_a_second_switch_within_3_seconds_then_allows_it_after() -> void:
	var tower: Node = _build_tower(Vector2(0, 0))
	var player: Node = _build_player(Vector2(2000, 0))
	var enemy: EnemyController = _build_opportunist(Vector2(500, 0), tower, player)
	_tick(enemy, 0.1)
	assert_object(enemy.get_target_for_test()).is_same(tower)

	# First switch: player moves adjacent to the enemy, well over 25% closer.
	player.global_position = enemy.global_position
	enemy.hurtbox.damage_received.emit(5.0, &"player", null)
	assert_object(enemy.get_target_for_test()).append_failure_message("first qualifying switch did not occur").is_same(player)

	# Immediately try to switch back: Tower is now far closer than the
	# player (which just teleported far away), well over 25%, but under 3s
	# have passed since the last switch.
	player.global_position = Vector2(20000, 20000)
	enemy.hurtbox.damage_received.emit(5.0, &"tower", null)
	assert_object(enemy.get_target_for_test()).append_failure_message("switched back within the 3s lockout window").is_same(player)

	_tick(enemy, SWITCH_LOCKOUT_SECONDS + 0.1)
	enemy.hurtbox.damage_received.emit(5.0, &"tower", null)
	assert_object(enemy.get_target_for_test()).append_failure_message("did not switch back once the 3s lockout had elapsed").is_same(tower)


# --- Event 2: the out-of-range timer ----------------------------------------

func test_out_of_range_event_fires_after_3_continuous_seconds_and_switches_when_qualified() -> void:
	var tower: Node = _build_tower(Vector2(0, 0))
	var player: Node = _build_player(Vector2(100, 0))
	var enemy: EnemyController = _build_opportunist(Vector2(0, 0), tower, player)
	# Force the initial pick to the Tower directly rather than relying on
	# spawn-time distances, so this test is about the out-of-range timer
	# alone.
	enemy.set_tower_reference(tower)
	_tick(enemy, 0.1)
	assert_object(enemy.get_target_for_test()).is_same(tower)

	# Put the Tower target far beyond the 400px aggro range, and the player
	# (the "other" target) close enough to be well over 25% closer once the
	# event fires. Far enough away (3000px) that the Opportunist's own
	# chase movement (speed 224 px/s, at most ~700px over the 3.1s this
	# test ticks) can never close the gap back inside the 400px aggro range
	# on its own -- a real test-design bug found and fixed during this
	# task's own falsification pass: an earlier version placed the Tower
	# only 1000px away, and the Opportunist's own pursuit closed the
	# distance back under 400px before the 3s mark, so the out-of-range
	# timer never had a genuinely continuous 3s to accumulate.
	tower.global_position = Vector2(3000, 0) # edge-distance 3000-106=2894, well past the 400px aggro range even after ~700px of chase movement
	player.global_position = enemy.global_position + Vector2(50, 0)

	_tick(enemy, OUT_OF_RANGE_SECONDS - 0.2)
	assert_object(enemy.get_target_for_test()).append_failure_message("switched before the full 3 continuous seconds outside aggro range elapsed").is_same(tower)

	_tick(enemy, 0.3)
	assert_object(enemy.get_target_for_test()).append_failure_message("did not switch once 3 continuous seconds outside the 400px aggro range elapsed").is_same(player)


func test_moving_back_into_range_before_3_seconds_resets_the_out_of_range_timer() -> void:
	var tower: Node = _build_tower(Vector2(0, 0))
	var player: Node = _build_player(Vector2(50, 0))
	var enemy: EnemyController = _build_opportunist(Vector2(0, 0), tower, player)
	enemy.set_tower_reference(tower)
	_tick(enemy, 0.1)
	assert_object(enemy.get_target_for_test()).is_same(tower)

	tower.global_position = Vector2(3000, 0) # out of range -- far enough that the Opportunist's own chase movement cannot close it back under 400px within either 2.5s segment below (see the sibling test's header note on this exact pitfall)
	_tick(enemy, OUT_OF_RANGE_SECONDS - 0.5)
	tower.global_position = Vector2(50, 0) # back in range before the 3s mark
	_tick(enemy, 1.0)
	tower.global_position = Vector2(3000, 0) # out of range again -- if the timer did not reset, this would complete the ORIGINAL 3s window almost immediately
	_tick(enemy, OUT_OF_RANGE_SECONDS - 0.5)
	assert_object(enemy.get_target_for_test()).append_failure_message("the out-of-range timer was not reset by moving back into range -- it must be CONTINUOUS seconds outside range").is_same(tower)


# --- Event 3: the current target dies ---------------------------------------

func test_current_target_dying_forces_a_switch_regardless_of_the_25_percent_gate_or_lockout() -> void:
	var tower: Node = _build_tower(Vector2(0, 0))
	var player: Node = _build_player(Vector2(2000, 0)) # NOT 25% closer than the Tower once it "dies" -- irrelevant, this event forces the switch anyway
	var enemy: EnemyController = _build_opportunist(Vector2(500, 0), tower, player)
	_tick(enemy, 0.1)
	assert_object(enemy.get_target_for_test()).is_same(tower)

	tower.death_state.kill("test_setup")

	assert_object(enemy.get_target_for_test()).append_failure_message("did not switch away from its current target once that target died").is_same(player)


# --- Tag registration (LEDGER F03-15 side check) ----------------------------

func test_opportunist_registers_as_enemy_but_not_as_tower_seeker() -> void:
	var tower: Node = _build_tower(Vector2(0, 0))
	var player: Node = _build_player(Vector2(2000, 0))
	var enemy: EnemyController = _build_opportunist(Vector2(0, 0), tower, player)
	var tags: Array[StringName] = _registry.get_tags(enemy)
	assert_bool(tags.has(&"enemy")).is_true()
	assert_bool(tags.has(&"tower_seeker")).append_failure_message("an Opportunist must never register as tower_seeker").is_false()
