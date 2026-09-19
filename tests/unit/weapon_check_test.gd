extends GdUnitTestSuite

## Weapon check (P2.3 named acceptance test). MASTER_SDLC.md > Acceptance
## Test Matrix > Technical Tests > "Weapon check"; PLAN.md > P2.3 row:
## "Kills placeholder enemies at the sheet DPS; no targeting input exists."
## Provisional Values Register > Player & Weapons > "Handgun (Starting
## Weapon)": "10 dmg/shot, 2 shots/s (20 DPS), range 260 px, nearest
## re-picked every shot, projectile 1000 px/s" -- every number below is
## read from data/weapons/handgun.tres via AutoWeapon.configure(), never
## restated as a literal in the weapon's own logic (only in this suite's
## own assertions, which must independently know the expected figures to
## have anything to check against -- same convention as
## tests/unit/tower_weapon_test.gd's own REGISTER_* constants).
##
## Falsifications, each with its own test below:
##   1. Fires on cadence and deals exactly the Register's damage per shot.
##   2. CombatStats.sheet_dps_from_weapon() on the authored .tres reports
##      exactly 20 (PLAN.md's own exit criterion, stated explicitly).
##   3. Does not fire at a target beyond the Register's 260 px range, and
##      fires as soon as one is within range.
##   4. Re-picks the nearest target on every shot -- the one rule this
##      weapon does NOT share with tower_weapon.gd's targeting (C-TOWERTARGET
##      holds a target until it dies or leaves range; this weapon must not).
##   5. Kills a real scenes/entities/placeholder_enemy.tscn instance within
##      the expected number of shots at the Register's cadence.
##   6. Reads no Input action at all -- auto-targeting means there is no aim
##      input (MASTER_SDLC.md > Input Buffering Rules > "Auto-Fire
##      Targeting").
##   7. C-AUTOFIRE: set_auto_fire_suppressed(true) stops firing at any
##      range/cadence; false resumes it.
##   8. driven_externally suppresses this node's own _physics_process so a
##      future SimLoop integration can call physics_step() exactly once per
##      tick without double-firing.

const AutoWeaponScript: GDScript = preload("res://src/combat/auto_weapon.gd")
const HandgunResource: WeaponDefinition = preload("res://data/weapons/handgun.tres")
const PlaceholderEnemyScene: PackedScene = preload("res://scenes/entities/placeholder_enemy.tscn")

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

const REGISTER_DAMAGE_PER_SHOT: float = 10.0
const REGISTER_FIRE_RATE_PER_SECOND: float = 2.0
const REGISTER_FIRE_INTERVAL_SECONDS: float = 1.0 / REGISTER_FIRE_RATE_PER_SECOND
const REGISTER_RANGE_PX: float = 260.0
const REGISTER_SHEET_DPS: float = 20.0

var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)


## Builds a standalone AutoWeapon under a plain Node2D "shooter" (mirrors
## tower_weapon_test.gd's `_build_tower()` -- this weapon needs a real Node2D
## ancestor for `origin_path`'s get_parent() fallback to resolve, exactly
## like tower_weapon.gd needs a Tower). A sibling "Projectiles" Node2D is
## also built and wired via `projectiles_container_path`, matching
## scenes/tower.tscn's own precedent (`TowerWeapon.projectiles_container_
## path = NodePath("../Projectiles")`) -- without it, Pool never adds an
## acquired projectile to the SceneTree at all (Pool.acquire() only calls
## `_container.add_child(instance)` when `_container != null`), so it never
## runs `_physics_process()`, never hits anything, and never expires. This
## was found the hard way while building this suite (see this task's
## evidence report) and fixed in both this test and scenes/player.tscn.
func _build_weapon(position: Vector2 = Vector2.ZERO) -> AutoWeapon:
	var shooter: Node2D = auto_free(Node2D.new()) as Node2D
	add_child(shooter)
	shooter.global_position = position
	var projectiles_container: Node2D = Node2D.new()
	projectiles_container.name = "Projectiles"
	shooter.add_child(projectiles_container)
	var weapon: AutoWeapon = AutoWeaponScript.new() as AutoWeapon
	weapon.definition = HandgunResource
	weapon.projectiles_container_path = NodePath("../Projectiles")
	shooter.add_child(weapon)
	weapon.set_registry_for_test(_registry)
	return weapon


## `max_hp = -1.0` keeps death_state.gd's own default (30.0) untouched.
func _build_enemy(position: Vector2, tags: Array = [&"enemy"], max_hp: float = -1.0) -> Node:
	var enemy: Node = auto_free(PlaceholderEnemyScene.instantiate())
	if max_hp > 0.0:
		var ds: DeathState = enemy.get_node("DeathState") as DeathState
		ds.max_hp = max_hp
	add_child(enemy)
	enemy.global_position = position
	_registry.register_entity(enemy, position, tags)
	return enemy


func _wait_until(condition: Callable, max_iterations: int = 400) -> void:
	var iterations: int = 0
	while not condition.call() and iterations < max_iterations:
		await get_tree().physics_frame
		iterations += 1


# --- Falsification 1: fires on cadence, exact damage per shot --------------

func test_fires_at_the_registers_cadence_and_damage_per_shot() -> void:
	var weapon: AutoWeapon = _build_weapon()
	var enemy: Node = _build_enemy(Vector2(100, 0), [&"enemy"], 100000.0) # will not die mid-test

	var hits: Array = [] # [{amount, timestamp}]
	(enemy.get_node("DeathState") as DeathState).damage_applied.connect(func(amount: float, _source: Variant, _remaining: float) -> void:
		hits.append({"amount": amount, "timestamp": SimClock.now})
	)

	await _wait_until(func() -> bool: return hits.size() >= 3)

	assert_int(hits.size()).append_failure_message("fewer than 3 shots landed within the timeout -- weapon is not firing on cadence").is_greater_equal(3)
	for h in hits:
		assert_float(h["amount"]).append_failure_message("a shot dealt the wrong damage amount").is_equal_approx(REGISTER_DAMAGE_PER_SHOT, 0.01)

	var tolerance: float = SimClock.PHYSICS_STEP * 3.0
	for i in range(1, hits.size()):
		var gap: float = hits[i]["timestamp"] - hits[i - 1]["timestamp"]
		assert_float(gap).append_failure_message("shot %d->%d gap was %.4fs, expected ~%.4fs (1 / fire_rate_per_second)" % [i - 1, i, gap, REGISTER_FIRE_INTERVAL_SECONDS]).is_equal_approx(REGISTER_FIRE_INTERVAL_SECONDS, tolerance)


# --- Falsification 2: sheet DPS computed from the authored .tres -----------

func test_sheet_dps_from_weapon_matches_the_register() -> void:
	var dps: float = CombatStats.sheet_dps_from_weapon(HandgunResource)
	assert_float(dps).append_failure_message("data/weapons/handgun.tres does not compute to the Register's 20 DPS (10 dmg/shot x 2 shots/s)").is_equal_approx(REGISTER_SHEET_DPS, 0.01)


# --- Falsification 3: range -------------------------------------------------

func test_does_not_fire_beyond_the_registers_range_and_fires_once_in_range() -> void:
	var weapon: AutoWeapon = _build_weapon()
	var _out_of_range_enemy: Node = _build_enemy(Vector2(REGISTER_RANGE_PX + 140.0, 0)) # comfortably past 260 px

	# Dictionary-wrapped counter, not a bare int -- matching this project's
	# own established convention (pool_test.gd's `created["count"]`,
	# ghost_hit_test.gd's `counters[...]`, player_scene_test.gd's
	# `received["count"]`): a plain local int captured by a lambda and
	# mutated inside it is NOT reliably visible to the enclosing function
	# afterward, only a container (Dictionary/Array) is.
	var range_state: Dictionary = {"shots_while_out_of_range": 0}
	var connection: Callable = func(_t: float) -> void: range_state["shots_while_out_of_range"] += 1
	weapon.fired.connect(connection)

	# Long enough for several cadence intervals (0.5s) to have elapsed.
	for _i in 60:
		await get_tree().physics_frame

	assert_int(range_state["shots_while_out_of_range"]).append_failure_message("weapon fired at a target beyond the Register's 260 px range").is_equal(0)

	weapon.fired.disconnect(connection)
	var in_range_enemy: Node = _build_enemy(Vector2(100, 0))

	var in_range_state: Dictionary = {"fired": false}
	weapon.fired.connect(func(_t: float) -> void: in_range_state["fired"] = true)
	await _wait_until(func() -> bool: return in_range_state["fired"])

	assert_bool(in_range_state["fired"]).append_failure_message("weapon never fired once a target entered the Register's range").is_true()
	assert_object(weapon.get_current_target()).is_same(in_range_enemy)


# --- Falsification 4: re-picks the nearest target every shot ---------------

func test_repicks_the_nearest_target_every_shot() -> void:
	var weapon: AutoWeapon = _build_weapon()
	var far_enemy: Node = _build_enemy(Vector2(200, 0), [&"enemy"], 100000.0)

	var fire_log: Array = []
	weapon.fired.connect(func(_t: float) -> void: fire_log.append(weapon.get_current_target()))

	await _wait_until(func() -> bool: return fire_log.size() >= 1)
	assert_int(fire_log.size()).append_failure_message("weapon never fired at the only enemy in range").is_greater_equal(1)
	assert_object(fire_log[0]).append_failure_message("first shot did not target the only enemy in range").is_same(far_enemy)

	# A strictly closer enemy appears AFTER the first shot. Unlike
	# tower_weapon.gd's C-TOWERTARGET (which would keep far_enemy until it
	# dies or leaves range), this weapon must switch to near_enemy on the
	# very next shot, since every shot re-picks the nearest target fresh.
	var near_enemy: Node = _build_enemy(Vector2(50, 0), [&"enemy"], 100000.0)

	await _wait_until(func() -> bool: return fire_log.size() >= 2)
	assert_int(fire_log.size()).append_failure_message("weapon did not fire a second shot").is_greater_equal(2)
	assert_object(fire_log[1]).append_failure_message("second shot kept the original (now farther) target instead of re-picking the nearest one -- this is tower_weapon.gd's C-TOWERTARGET hold-until-dead-or-out-of-range rule, which this weapon must NOT copy").is_same(near_enemy)


# --- Falsification 5: an actual kill at the Register's cadence -------------

func test_kills_a_placeholder_enemy_within_the_expected_number_of_shots() -> void:
	var weapon: AutoWeapon = _build_weapon()
	# 3 shots (30 dmg) kill a 25-HP target; ceil(25 / 10) = 3.
	var enemy: Node = _build_enemy(Vector2(60, 0), [&"enemy"], 25.0)
	var death_state: DeathState = enemy.get_node("DeathState") as DeathState
	var start_time: float = SimClock.now # SimClock.now is a shared, never-reset Autoload across the whole suite run -- measure ELAPSED time, never an absolute value

	await _wait_until(func() -> bool: return death_state.is_dead)

	assert_bool(death_state.is_dead).append_failure_message("placeholder enemy was not killed within the timeout").is_true()
	var elapsed: float = SimClock.now - start_time
	# 3 shots at 0.5s cadence: death should land well before a 4th shot
	# would have been due (2.0s) -- generous upper bound for projectile
	# travel time and frame quantization, not a tight one.
	assert_float(elapsed).append_failure_message("kill took %.4fs, expected under 3 shots' worth of cadence plus slack" % elapsed).is_less(3.0 * REGISTER_FIRE_INTERVAL_SECONDS + 0.5)


# --- Falsification 6: no targeting input exists -----------------------------

func test_reads_no_input_action_at_all() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/combat/auto_weapon.gd")
	assert_str(source).append_failure_message("auto_weapon.gd reads the Input singleton -- auto-targeting means there is no aim/target input for this weapon to read at all (MASTER_SDLC.md > Input Buffering Rules > 'Auto-Fire Targeting')").not_contains("Input.")


# --- Falsification 7: C-AUTOFIRE suppression --------------------------------

func test_set_auto_fire_suppressed_stops_firing_and_unsuppressing_resumes_it() -> void:
	var weapon: AutoWeapon = _build_weapon()
	var _enemy: Node = _build_enemy(Vector2(80, 0), [&"enemy"], 100000.0)

	var shots: Dictionary = {"count": 0} # see the range test's header comment for why this is a Dictionary, not a bare int
	weapon.fired.connect(func(_t: float) -> void: shots["count"] += 1)

	await _wait_until(func() -> bool: return shots["count"] >= 1)
	assert_int(shots["count"]).append_failure_message("weapon never fired before suppression was applied").is_greater_equal(1)

	weapon.set_auto_fire_suppressed(true)
	assert_bool(weapon.is_auto_fire_suppressed()).is_true()
	var count_at_suppression: int = shots["count"]

	# Long enough for several cadence intervals (0.5s) to have elapsed.
	for _i in 90:
		await get_tree().physics_frame

	assert_int(shots["count"]).append_failure_message("weapon fired while auto-fire was suppressed (C-AUTOFIRE)").is_equal(count_at_suppression)

	weapon.set_auto_fire_suppressed(false)
	await _wait_until(func() -> bool: return shots["count"] > count_at_suppression)
	assert_int(shots["count"]).append_failure_message("weapon did not resume firing after suppression was lifted").is_greater(count_at_suppression)


# --- Falsification 8: driven_externally / physics_step() seam --------------

func test_driven_externally_disables_self_stepping_but_physics_step_still_fires() -> void:
	var weapon: AutoWeapon = _build_weapon()
	weapon.driven_externally = true
	var _enemy: Node = _build_enemy(Vector2(80, 0), [&"enemy"], 100000.0)

	var shots: Dictionary = {"count": 0} # see the range test's header comment for why this is a Dictionary, not a bare int
	weapon.fired.connect(func(_t: float) -> void: shots["count"] += 1)

	for _i in 90: # far more than one cadence interval's worth of ticks
		await get_tree().physics_frame

	assert_int(shots["count"]).append_failure_message("weapon fired on its own _physics_process while driven_externally was true").is_equal(0)

	var manual_iterations: int = 0
	while shots["count"] == 0 and manual_iterations < 400:
		weapon.physics_step(SimClock.PHYSICS_STEP)
		manual_iterations += 1

	assert_int(shots["count"]).append_failure_message("weapon did not fire when physics_step() was called directly").is_greater_equal(1)
