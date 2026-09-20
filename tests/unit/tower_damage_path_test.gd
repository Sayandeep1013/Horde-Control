extends GdUnitTestSuite

## Tower damage-path diagnosis (integration task, item 2 of its brief).
##
## P2.14 measured T4 (tests/unit/teaching_siege_tuning_test.gd) over five
## seeds with no player and found the Tower ending EVERY seed at exactly
## 500.0/500.0 health -- never hit once -- even after locally patching the
## F05-23 Tower-reference gap so the Seekers could target the Tower at all.
## Twelve melee Seekers arriving over a 22 s window against a single-target
## Tower, with the Tower taking literally zero damage, reads as more
## consistent with a disconnected damage path than with perfect
## interception (evidence/p214_report.md, section 3). This project's own
## rule is that a root cause written from reasoning, without measuring it,
## is not a root cause -- so this file builds the SMALLEST scenario that
## can answer the question, then widens it by one variable at a time,
## rather than asserting a diagnosis from code inspection alone.
##
## Both scenarios below instantiate the REAL scenes/tower.tscn and REAL
## scenes/entities/tower_seeker.tscn, exactly like
## teaching_siege_tuning_test.gd's own harness (see that file's header, "Real
## combat, not a logic-only harness") -- a logic-only stand-in cannot prove
## a real Area2D Hitbox/Hurtbox overlap ever happens at all.

const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const SimLoopScript: GDScript = preload("res://src/core/sim_loop.gd")

## docs/09 / data/enemies/tower_seeker.tres: reach 20 px, body radius 14 px.
## data/tower/base.tres: footprint radius 106 px. Melee triggers when
## centre-to-centre distance minus both radii is <= reach, i.e. distance <=
## 106 + 14 + 20 = 140 px (EnemyController._reach_distance_to()). 130 px
## places the Seeker inside that ring from the very first tick, with margin.
const MELEE_DISTANCE_PX: float = 130.0

## Register > "Spawning & Waves" / p214_report.md section 3: the Tower ring
## the Wave Director spawns Tower Seekers on sits at roughly 1331-1459 px
## from the Tower. 1400 px is a representative point in that band, used
## here only to reproduce the REALISTIC travel distance for scenario B --
## the ring's own exact geometry is spawn_ring_test.gd's job, not this
## file's.
const REALISTIC_SPAWN_DISTANCE_PX: float = 1400.0

var _container: Node
var _tower: Tower
var _loop: Node


func before_test() -> void:
	_container = auto_free(Node.new())
	add_child(_container)
	_loop = SimLoopScript.new()
	_container.add_child(_loop)
	_tower = TowerScene.instantiate() as Tower
	_container.add_child(_tower)


func after_test() -> void:
	get_tree().paused = false
	# The same single uncleared pool the integration task chased down for
	# teaching_siege_tuning_test.gd (finding F05-25): `TowerWeapon` builds
	# its OWN Pool for TowerProjectile instances, separate from the one
	# EntitySpawner owns, and a recycled projectile sits in that pool's free
	# list alive and detached from the tree -- which is Godot's definition
	# of an orphan. Scenario B below fires real Tower projectiles, so this
	# suite leaks them exactly as that one did. MEASURED rather than
	# assumed: see this suite's own orphan count before and after.
	if _tower != null and is_instance_valid(_tower) and _tower.weapon != null:
		var weapon_pool: Pool = _tower.weapon.get_pool_for_test()
		if weapon_pool != null:
			weapon_pool.clear_for_test()
	# The Tower registers itself with the EntityRegistry autoload under the
	# &"tower" tag (F03-39) and scenario B registers it explicitly too. The
	# autoload outlives every test in the process, so leaving the entry
	# behind would let a freed Tower be returned to a LATER suite's registry
	# query -- the dangling-reference class that hid in EntityRegistry for a
	# whole phase (F02-14).
	if _tower != null and is_instance_valid(_tower) and EntityRegistry.is_registered(_tower):
		EntityRegistry.deregister_entity(_tower)


func _total_tower_pool() -> float:
	return _tower.health.current_shield + _tower.health.get_current_health()


func _max_tower_pool() -> float:
	return _tower.health.max_shield + _tower.health.max_health


## Scenario A ("the smallest scenario that answers it"): one Seeker,
## already standing in melee range of a real Tower, the Tower's own weapon
## DISABLED (process_mode set to disabled the instant it is added, before
## any physics tick, so it never fires and can never confound the result).
## No set_tower_reference() call is made here -- the Seeker must resolve
## the Tower entirely through the F05-23 fix (EntityRegistry, tag
## &"tower"), so this scenario also doubles as a regression proof for that
## fix, using the real production call path rather than a test seam.
func test_a_a_seeker_already_in_melee_range_with_the_tower_weapon_disabled_damages_the_tower() -> void:
	_tower.weapon.process_mode = Node.PROCESS_MODE_DISABLED

	var seeker: EnemyController = auto_free(TowerSeekerScene.instantiate()) as EnemyController
	_container.add_child(seeker)
	seeker.global_position = _tower.global_position + Vector2(MELEE_DISTANCE_PX, 0.0)

	var starting_pool: float = _total_tower_pool()
	assert_float(starting_pool).append_failure_message("fixture error: starting pool should equal the max pool").is_equal_approx(_max_tower_pool(), 0.01)

	# A plain int would be captured BY VALUE inside the lambda below (this
	# project's own established gotcha -- CLAUDE.md > Project conventions:
	# "Lambdas capture locals by value"; hit_queue_real_combat_test.gd's own
	# fixture works around the identical trap the same way), so the counter
	# is a Dictionary -- a reference type -- exactly like that file's.
	var hit_landed_count: Dictionary = {"n": 0}
	seeker.hitbox.hit_landed.connect(func(_hb: Hurtbox, _d: float, _s: Variant) -> void: hit_landed_count["n"] += 1)

	# Two full 1.5 s attack cycles' worth of margin (0.4 s windup + 1.5 s
	# cycle, per data/enemies/tower_seeker.tres) -- 4 simulated seconds at
	# 60 physics ticks/second.
	var iterations: int = 0
	while int(hit_landed_count["n"]) < 1 and iterations < 240:
		await get_tree().physics_frame
		iterations += 1

	var ending_pool: float = _total_tower_pool()

	assert_int(int(hit_landed_count["n"])).append_failure_message(
		"the Seeker's own hitbox never reported a landed hit within %d ticks (%.1f s) even standing inside melee range with the Tower's weapon disabled -- the Seeker never entered its attack cycle at all (movement/attack-slot/targeting path), not merely a damage-application gap" % [iterations, iterations / 60.0]
	).is_greater(0)

	assert_float(ending_pool).append_failure_message(
		"the Seeker landed %d hit(s) (hit_landed fired) but the Tower's own shield+health pool did NOT drop (%.2f -> %.2f) -- this is the disconnected-damage-path defect: the Hitbox/Hurtbox overlap resolves, but it never reaches tower_health.gd's shield-then-health split" % [int(hit_landed_count["n"]), starting_pool, ending_pool]
	).is_less(starting_pool)


## Scenario B ("then widen"): one Seeker at the REALISTIC ring distance
## (~1400 px), the Tower's own weapon left ENABLED at full strength -- the
## single variable this scenario adds over Scenario A. If Scenario A is
## green (the damage path itself works) and this scenario shows the
## Seeker dying to the Tower's own projectile before it ever lands a hit,
## that is real, measured evidence for the "perfect interception"
## hypothesis p214_report.md proposed but did not verify. If the Seeker
## DOES land a hit before dying, interception is not the explanation for
## a single attacker and the mystery is not yet closed by this file alone.
func test_b_a_seeker_at_realistic_spawn_distance_with_the_tower_weapon_enabled() -> void:
	EntityRegistry.register_entity(_tower, _tower.global_position, [&"tower"]) if not EntityRegistry.is_registered(_tower) else null

	var seeker: EnemyController = auto_free(TowerSeekerScene.instantiate()) as EnemyController
	_container.add_child(seeker)
	seeker.global_position = _tower.global_position + Vector2(REALISTIC_SPAWN_DISTANCE_PX, 0.0)

	# Reference-type counter -- see Scenario A's own comment on this project's
	# lambda-captures-by-value gotcha (CLAUDE.md > Project conventions).
	var hit_landed_count: Dictionary = {"n": 0}
	seeker.hitbox.hit_landed.connect(func(_hb: Hurtbox, _d: float, _s: Variant) -> void: hit_landed_count["n"] += 1)

	var starting_pool: float = _total_tower_pool()
	var seeker_died: bool = false
	var seeker_landed_hit: bool = false
	var ticks_to_outcome: int = -1

	# 1400 px / 176 px/s (Tower Seeker's own speed) ~= 8.0 s travel, plus
	# margin for the Tower's weapon kill time (2.4 s) and attack-cycle
	# windup -- 20 simulated seconds (1200 ticks) is generous over both.
	var iterations: int = 0
	while iterations < 1200:
		await get_tree().physics_frame
		iterations += 1
		if int(hit_landed_count["n"]) > 0:
			seeker_landed_hit = true
			ticks_to_outcome = iterations
			break
		if not is_instance_valid(seeker) or (seeker.death_state != null and seeker.death_state.is_dead):
			seeker_died = true
			ticks_to_outcome = iterations
			break

	var ending_pool: float = _total_tower_pool()

	print("ZZZSCENARIOB seeker_died=%s seeker_landed_hit=%s ticks_to_outcome=%d (%.2fs) tower_pool %.2f -> %.2f" % [seeker_died, seeker_landed_hit, ticks_to_outcome, ticks_to_outcome / 60.0, starting_pool, ending_pool])

	# This function records the outcome as a measurement, not a pass/fail
	# gate on a specific winner -- the task explicitly says the
	# "interception" proposal was not independently verified, so this file
	# does not assert one outcome over the other, only that SOME outcome
	# resolved within the budget.
	assert_bool(seeker_died or seeker_landed_hit).append_failure_message(
		"neither outcome resolved within %d ticks (%.1f s) -- inconclusive, not evidence for either hypothesis" % [iterations, iterations / 60.0]
	).is_true()
