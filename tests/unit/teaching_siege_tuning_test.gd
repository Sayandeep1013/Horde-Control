extends GdUnitTestSuite

## Teaching Siege tuning check (P2.14 named acceptance test; MASTER_SDLC.md
## > Acceptance Test Matrix > Technical Tests > "Teaching Siege tuning
## check"; > Provisional Values Register > "Encounter Budgets" > "T4 Siege,
## teaching" row: "Seekers 12 @3 s interval 2.0 s (starting estimate;
## tuned in P2.14) ... tuning target: a no-player run loses the Tower
## before T4 ends in >= 3 of 5 seeds, and a player reaching within 480 px
## of the Tower within 10 s of the warning keeps it above 50%"; docs/11 >
## "Encounter Budgets for the Prototype" > T4 row, same target).
##
## This IS the tuning task: MEASURE the CURRENT authored numbers
## (data/waves/t4.tres, data/encounters/t4_siege.tres, unedited) against
## both halves of the target, over 5 fixed seeds each. This file never
## edits `data/waves/t4.tres` (outside this task's write scope, and the
## Register is the single place the number lives) -- see the P2.14
## evidence report for the measured result and, if the current numbers
## miss the target, the proposed replacement WITH the measurement that
## supports it.
##
## ## Real combat, not a logic-only harness
## Unlike tests/unit/overtime_test.gd's dummy-enemy fixture (fine for
## proving the SPAWN decision, not the DAMAGE outcome), this suite
## instantiates the REAL Tower Seeker / Player Hunter scenes
## (scenes/entities/*.tscn), the REAL Tower (scenes/tower.tscn), and lets
## melee contact damage resolve through the REAL Area2D Hitbox/Hurtbox
## overlap + SimLoop hit queue path (src/combat/hitbox.gd,
## src/core/sim_loop.gd) -- matching tests/unit/
## hit_queue_real_combat_test.gd's own precedent for "a genuine Area2D
## overlap, not a simulated call." Real Area2D overlap detection can only
## happen on a REAL engine physics tick, so this suite drives time via
## `await get_tree().physics_frame` in a loop keyed on `SimClock.now`
## (never a fixed iteration count assumption).
##
## ## One test function PER SEED, not one function looping over five
## MEASURED, not assumed: an earlier version of this file ran all 5 seeds
## of each scenario inside a single test function and hit gdUnit4's own
## per-test-case timeout (5 minutes) before finishing even one scenario --
## a real ~40-simulated-second run of a real physics scene (up to 14
## spawned enemies plus their hitboxes/hurtboxes) costs noticeably more
## real wall-clock time than 40 seconds once instancing/teardown and actual
## combat overhead are counted, confirmed by this project's own
## tests/unit/pause_authority_full_test.gd (10 real seconds observed per 10
## SIMULATED seconds on a lighter scene, no combat). Raising
## `Engine.time_scale` did not help (measured: still timed out) -- Godot's
## fixed-step physics dispatches one `physics_frame` per real engine frame
## regardless of `Engine.time_scale`, so the NUMBER of `await get_tree().
## physics_frame` calls needed to cover 40 simulated seconds does not fall
## just because `time_scale` rose; that hypothesis is recorded here as
## tried and wrong, not silently dropped. Splitting into one function per
## seed keeps every individual run comfortably inside its own 5-minute
## budget; a `static var` accumulator (below) carries each seed's own
## result to a SINGLE final aggregate function, where the Register's own
## ">= 3 of 5" / "5 of 5" assertions actually live.
##
## ## Why the two halves are asserted in ONE final function, not two
## MEASURED, not assumed: this project's own established gdUnit4 behaviour
## (phases/PHASE_05.../PLAN.md's own carried lesson; confirmed again here)
## is that once a test FUNCTION fails, gdUnit4 skips every remaining
## function DECLARED AFTER IT in that same file/invocation. An earlier
## version of this file asserted the no-player target in its own
## `test_a6_...` function, declared before the five responsive-bot
## functions -- when that assertion measured red (see the P2.14 evidence
## report), gdUnit4 skipped the entire responsive-bot scenario and this
## suite produced NO measurement for the second half of the target at all.
## Multiple `assert_*` calls WITHIN one function all run and get tallied
## regardless of an earlier one in the SAME function failing (confirmed:
## `tests/unit/focus_loss_test.gd`'s own falsification run reported "2
## failures" from one function's two assertions) -- so both halves of the
## Register's target are now asserted inside one function, declared last,
## so a red result on one half can never suppress the other half's own
## measurement or assertion. Every per-seed function below records data
## only and asserts nothing the actual combat outcome could fail (the one
## true precondition check, "the bot started within response range," is
## deterministic by construction and moved out of the assertion path
## entirely -- a warning line in the report, not a gate).

const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const PlayerHunterScene: PackedScene = preload("res://scenes/entities/player_hunter.tscn")
const OpportunistScene: PackedScene = preload("res://scenes/entities/opportunist.tscn")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")

const T4_WAVE: WaveDefinition = preload("res://data/waves/t4.tres")
const T4_ENCOUNTER: EncounterDefinition = preload("res://data/encounters/t4_siege.tres")

## Register > "Encounter Budgets" > T4 row: "max 40 s" -- an independent
## literal, cited directly, NEVER read back from `T4_WAVE.maximum_duration_
## seconds` (this project's own established falsification discipline,
## named verbatim in tests/unit/console_rules_test.gd's header: a constant
## captured from the system under test would silently follow a mutation to
## that same field instead of catching it).
const T4_MAX_DURATION_SECONDS: float = 40.0

## Register > "T4 Siege, teaching" row: "a player reaching within 480 px of
## the Tower within 10 s of the warning."
const RESPONSE_DISTANCE_PX: float = 480.0
const RESPONSE_WINDOW_SECONDS: float = 10.0

## Five fixed, named seeds per side of the target (Register: "in >= 3 of 5
## seeds" / "in 5 of 5 seeds").
const SEEDS: Array[int] = [4001, 4002, 4003, 4004, 4005]

const SAFETY_TICK_CAP: int = 3000 # 50 simulated seconds' worth of ticks -- generous margin over the 40 s wave maximum; never the loop's own termination condition in a healthy run

## Cross-file-instance accumulator -- `static var` belongs to the CLASS,
## not any one `GdUnitTestSuite` instance gdUnit4 constructs per test case,
## so a result stored by one per-seed test function is still visible to the
## aggregate function declared afterward even if gdUnit4 uses a fresh
## instance for each. Keyed by seed so re-running a single seed function in
## isolation (e.g. during debugging) cannot silently reuse a stale entry
## from an unrelated seed.
static var _scenario_a_destroyed_by_seed: Dictionary = {}
static var _scenario_b_above_half_by_seed: Dictionary = {}
static var _scenario_b_within_response_by_seed: Dictionary = {}
static var _scenario_a_report_lines: Array[String] = []
static var _scenario_b_report_lines: Array[String] = []


func after_test() -> void:
	get_tree().paused = false


# --- Harness -----------------------------------------------------------------

func _build_harness(seed_value: int) -> Dictionary:
	var container: Node = Node.new()
	container.name = "T4Harness_%d" % seed_value
	add_child(container)

	var tower: Tower = TowerScene.instantiate() as Tower
	container.add_child(tower)

	var spawner: Node = EntitySpawnerScript.new()
	container.add_child(spawner)

	var director: WaveDirector = WaveDirectorScript.new() as WaveDirector
	director.run_seed = seed_value
	director.tower_seeker_scene = TowerSeekerScene
	director.player_hunter_scene = PlayerHunterScene
	director.opportunist_scene = OpportunistScene
	director.waves = [T4_WAVE]
	director.encounter_definitions = [T4_ENCOUNTER]
	container.add_child(director)
	director.set_entity_spawner_for_test(spawner)
	director.set_tower_reference(tower) # real typed command (not a test seam) -- Tower-centred spawn ring geometry
	director.rebuild_lookups_for_test()
	director.enemy_spawned.connect(func(instance: Node2D, _id: String, _pos: Vector2) -> void:
		_wire_spawned_enemy(instance, tower)
	)

	return {"container": container, "tower": tower, "director": director, "spawner": spawner}


## See class header, "Cross-task seam this suite had to work around" (in
## the P2.14 evidence report in full) -- closes the missing
## set_tower_reference() wiring locally, for THIS suite's own spawned
## enemies only, exactly as src/integration/prototype_integration.gd's own
## `_wire_enemies()` already does for the three hand-placed enemies in the
## real assembled scene. `src/integration/prototype_integration.gd`'s own
## header names the gap directly for Wave-Director-spawned enemies: "is NOT
## reached by this method at all ... named as a required seam ... for
## whichever task next owns entity_spawner.gd/wave_director.gd's own spawn
## call sites." Without this, every Tower Seeker spawned below would never
## learn where the Tower is and never attack it -- a wiring gap unrelated
## to T4's own spawn NUMBERS, which is what this suite is actually
## measuring.
func _wire_spawned_enemy(instance: Node2D, tower: Tower) -> void:
	if instance != null and instance.has_method(&"set_tower_reference"):
		instance.set_tower_reference(tower)


## MEASURED, not assumed: the first version of this teardown freed only the
## container, and the finished suite reported ~160 orphan nodes PER SEED at
## process exit. `src/core/entity_spawner.gd` pools its Node2D instances
## (matching tests/unit/prototype_wave_integration_test.gd's own header:
## "released instances are kept alive but out of the scene tree, which is
## what pooling is for and is also Godot's definition of an orphan") -- a
## despawned Tower Seeker is DETACHED from the tree but kept alive in the
## Pool's own internal free list, so freeing the container's tree hierarchy
## never reaches it. `clear_all_for_test()` (that same project convention)
## fixed most of it (~160/seed -> ~20/seed) but did not reach zero.
##
## Integration task (F05-25), chased to its actual cause rather than left
## at "reduced": `EntitySpawner.clear_all_for_test()` only clears the
## pools IT owns (enemy/pickup/projectile pools registered through
## `spawn_enemy()`/`spawn_pickup()`). `TowerWeapon` builds its OWN,
## entirely separate `Pool` for `TowerProjectile` instances
## (`tower_weapon.gd`'s own `_pool`, created in `configure()`,
## `Pool.OverflowPolicy.RECYCLE_OLDEST`) that the spawner never knows
## about and this teardown never touched. Every `TowerProjectile` this
## harness's own Tower fires and then recycles (any Siege scenario with
## the Tower's weapon live, which is every scenario in this file) sits in
## THAT pool's free list -- alive, detached from the tree -- for the rest
## of the process. MEASURED: adding the clear below took the suite's own
## orphan count from 200 to 0 (`tests/run_tests.ps1 -TestPath
## res://tests/unit/teaching_siege_tuning_test.gd`, full 11-case run,
## before/after), and the 5 "ENGINE ERROR: ... leaked RIDs" lines the
## F05-25 finding also named went with it -- both symptoms of the same
## single uncleared pool, not two separate causes. `get_pool_for_test()`
## is a `_for_test()` seam; calling it from this test file (not gameplay
## code) is the same class of usage `console_rules_test.gd` and others
## already make of similar seams.
func _teardown_harness(h: Dictionary) -> void:
	var spawner: Node = h.get("spawner")
	if spawner != null and is_instance_valid(spawner) and spawner.has_method("clear_all_for_test"):
		spawner.clear_all_for_test()
	var tower: Tower = h.get("tower")
	if tower != null and is_instance_valid(tower) and tower.weapon != null:
		var weapon_pool: Pool = tower.weapon.get_pool_for_test()
		if weapon_pool != null:
			weapon_pool.clear_for_test()
	var container: Node = h["container"]
	if is_instance_valid(container):
		container.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame # a second settle frame for anything the first frame's deferred frees themselves queued


## Drives real engine physics frames until either the Tower is destroyed or
## `T4_MAX_DURATION_SECONDS` of SIMULATED time has elapsed since this call
## began (measured against `SimClock.now`, never a fixed iteration count).
func _run_until_destroyed_or_wave_ends(tower: Tower) -> Dictionary:
	var start_sim_time: float = SimClock.now
	var iterations: int = 0
	while iterations < SAFETY_TICK_CAP:
		await get_tree().physics_frame
		iterations += 1
		var elapsed: float = SimClock.now - start_sim_time
		if tower.health.is_destroyed():
			break
		if elapsed >= T4_MAX_DURATION_SECONDS:
			break
	return {
		"destroyed": tower.health.is_destroyed(),
		"elapsed": SimClock.now - start_sim_time,
		"iterations": iterations,
	}


func _run_one_no_player_seed(seed_value: int) -> void:
	var h: Dictionary = _build_harness(seed_value)
	var tower: Tower = h["tower"]

	var result: Dictionary = await _run_until_destroyed_or_wave_ends(tower)
	_scenario_a_destroyed_by_seed[seed_value] = bool(result["destroyed"])
	_scenario_a_report_lines.append("seed %d: destroyed=%s at t=%.2fs (%d ticks), final health=%.1f/%.1f" % [
		seed_value, result["destroyed"], result["elapsed"], result["iterations"],
		tower.health.get_current_health(), tower.health.max_health,
	])

	await _teardown_harness(h)


# --- Scenario A: no player, one seed per test function ------------------------

func test_a1_no_player_seed_4001() -> void:
	await _run_one_no_player_seed(SEEDS[0])


func test_a2_no_player_seed_4002() -> void:
	await _run_one_no_player_seed(SEEDS[1])


func test_a3_no_player_seed_4003() -> void:
	await _run_one_no_player_seed(SEEDS[2])


func test_a4_no_player_seed_4004() -> void:
	await _run_one_no_player_seed(SEEDS[3])


func test_a5_no_player_seed_4005() -> void:
	await _run_one_no_player_seed(SEEDS[4])


# --- Scenario B: a responsive bot, one seed per test function -----------------

func _nearest_enemy_position(from: Vector2) -> Variant:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for e in EntityRegistry.get_entities_with_tag(TowerWeapon.ENEMY_TAG):
		if not is_instance_valid(e):
			continue
		var d: float = from.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest.global_position if nearest != null else null


## MEASURED, not assumed: a first version of this bot always chased
## whichever live Seeker was nearest, with no range cap. Tower Seekers spawn
## on the Tower-centred ring at roughly 1331-1459 px from the Tower
## (Register > "Spawn Rings & Placement" > "Two rings") and take several
## seconds to close that distance -- while none has yet arrived, "nearest
## enemy" is still a Seeker out on the ring, and blindly closing on it pulls
## the bot AWAY from the Tower it is supposed to be defending (measured:
## 1336 px from the Tower at the 10 s check, matching that ring radius
## almost exactly, in every one of 5 seeds -- see the P2.14 evidence
## report). Fixed here: the bot only breaks toward an enemy already within
## `ENGAGE_RADIUS_PX` of ITSELF (i.e. one that has actually closed most of
## the distance and is a genuine melee/short-range threat); otherwise it
## holds a defensive position `HOLD_DISTANCE_FROM_TOWER_PX` from the Tower,
## on whichever bearing it currently occupies -- "reaches within 480 px of
## the Tower ... and chases Seekers" (Register), not "chases Seekers
## wherever they are."
const ENGAGE_RADIUS_PX: float = 400.0
const HOLD_DISTANCE_FROM_TOWER_PX: float = 200.0

## "Reaches within 480 px of the Tower within 10 s of the Siege warning and
## chases Seekers" (Register). The Siege warning fires "3 seconds before
## the first Seeker spawn" and T4's own first Seeker group is authored
## "@3 s" specifically so the warning coincides with the encounter opening
## (docs/11 > "Siege warning"; > T4 row's own "@3 s" note) -- so this bot is
## placed within range from the moment the encounter opens and its
## within-480px state is asserted explicitly at 10s, rather than merely
## assumed from its starting position.
func _bot_tick(player: Player, tower: Tower) -> void:
	var target: Variant = _nearest_enemy_position(player.global_position)
	var target_pos: Vector2
	if target != null and player.global_position.distance_to(target) <= ENGAGE_RADIUS_PX:
		target_pos = target
	else:
		var bearing_from_tower: Vector2 = player.global_position - tower.global_position
		if bearing_from_tower.length() < 1.0:
			bearing_from_tower = Vector2.RIGHT
		target_pos = tower.global_position + bearing_from_tower.normalized() * HOLD_DISTANCE_FROM_TOWER_PX
	var to_target: Vector2 = target_pos - player.global_position
	var direction: Vector2 = to_target.normalized() if to_target.length() > 8.0 else Vector2.ZERO
	player.set_input_direction_for_test(direction)


func _run_one_responsive_bot_seed(seed_value: int) -> void:
	var h: Dictionary = _build_harness(seed_value)
	var tower: Tower = h["tower"]
	var container: Node = h["container"]

	var player: Player = PlayerScene.instantiate() as Player
	container.add_child(player)
	# Within the 480 px response distance from the instant the encounter
	# opens (t=0) -- see this function's own header for why t=0 is the
	# warning instant for T4 specifically.
	player.global_position = tower.global_position + Vector2(300.0, 0.0)
	EntityRegistry.register_entity(player, player.global_position, [&"player"])

	var initial_distance: float = player.global_position.distance_to(tower.global_position)
	var started_in_range: bool = initial_distance <= RESPONSE_DISTANCE_PX # recorded, not asserted here -- see class header, "Why the two halves are asserted in ONE final function"

	var start_sim_time: float = SimClock.now
	var checked_at_10s: bool = false
	var distance_at_10s: float = -1.0

	var iterations: int = 0
	while iterations < SAFETY_TICK_CAP:
		_bot_tick(player, tower)
		await get_tree().physics_frame
		iterations += 1
		var elapsed: float = SimClock.now - start_sim_time
		if not checked_at_10s and elapsed >= RESPONSE_WINDOW_SECONDS:
			checked_at_10s = true
			distance_at_10s = player.global_position.distance_to(tower.global_position)
		if tower.health.is_destroyed():
			break
		if elapsed >= T4_MAX_DURATION_SECONDS:
			break

	var reached_within_window: bool = checked_at_10s and distance_at_10s >= 0.0 and distance_at_10s <= RESPONSE_DISTANCE_PX # recorded, not asserted here

	var final_health: float = tower.health.get_current_health()
	var max_health: float = tower.health.max_health
	var fraction: float = final_health / max_health if max_health > 0.0 else 0.0
	var above_half: bool = fraction > 0.5
	_scenario_b_above_half_by_seed[seed_value] = above_half
	_scenario_b_within_response_by_seed[seed_value] = started_in_range and reached_within_window
	_scenario_b_report_lines.append("seed %d: final health=%.1f/%.1f (%.1f%%), above 50%%=%s, started_in_range=%s, distance at 10s=%.1fpx (within 480px=%s)" % [seed_value, final_health, max_health, fraction * 100.0, above_half, started_in_range, distance_at_10s, reached_within_window])

	if EntityRegistry.is_registered(player):
		EntityRegistry.deregister_entity(player)
	await _teardown_harness(h)


func test_b1_responsive_bot_seed_4001() -> void:
	await _run_one_responsive_bot_seed(SEEDS[0])


func test_b2_responsive_bot_seed_4002() -> void:
	await _run_one_responsive_bot_seed(SEEDS[1])


func test_b3_responsive_bot_seed_4003() -> void:
	await _run_one_responsive_bot_seed(SEEDS[2])


func test_b4_responsive_bot_seed_4004() -> void:
	await _run_one_responsive_bot_seed(SEEDS[3])


func test_b5_responsive_bot_seed_4005() -> void:
	await _run_one_responsive_bot_seed(SEEDS[4])


## THE Register assertion for BOTH halves of the T4 tuning target -- the
## single, deliberately LAST-declared function in this file (see class
## header, "Why the two halves are asserted in ONE final function"), so a
## red result on either half can never suppress the other half's own
## measurement.
func test_z_aggregate_both_halves_of_the_t4_tuning_target() -> void:
	assert_int(_scenario_a_destroyed_by_seed.size()).append_failure_message("only %d of %d no-player seeds recorded a result -- one of the test_a*_ functions did not run" % [_scenario_a_destroyed_by_seed.size(), SEEDS.size()]).is_equal(SEEDS.size())
	assert_int(_scenario_b_above_half_by_seed.size()).append_failure_message("only %d of %d responsive-bot seeds recorded a result -- one of the test_b*_ functions did not run" % [_scenario_b_above_half_by_seed.size(), SEEDS.size()]).is_equal(SEEDS.size())

	var destroyed_count: int = 0
	for seed_value in SEEDS:
		if bool(_scenario_a_destroyed_by_seed.get(seed_value, false)):
			destroyed_count += 1
	var a_message: String = "No-player T4 measurement (current authored numbers: Seekers 12 @3s interval 2.0s, Hunters 2 @10s):\n" + "\n".join(_scenario_a_report_lines) + "\nDestroyed in %d of %d seeds (target: >= 3 of 5)." % [destroyed_count, SEEDS.size()]
	print(a_message) # always visible regardless of pass/fail -- this task's brief: "MEASURE ... and report the measurement"

	var above_half_count: int = 0
	var within_response_count: int = 0
	for seed_value in SEEDS:
		if bool(_scenario_b_above_half_by_seed.get(seed_value, false)):
			above_half_count += 1
		if bool(_scenario_b_within_response_by_seed.get(seed_value, false)):
			within_response_count += 1
	var b_message: String = "Responsive-bot T4 measurement (current authored numbers):\n" + "\n".join(_scenario_b_report_lines) + "\nAbove 50%% in %d of %d seeds (target: 5 of 5); within 480px of the Tower within 10s of the warning in %d of %d seeds (precondition for the claim to be meaningful)." % [above_half_count, SEEDS.size(), within_response_count, SEEDS.size()]
	print(b_message)

	# Real assertions against the Register's own stated target, not vacuous
	# always-true checks -- this project's own run_tests.ps1 header: "a
	# check that cannot fail is worse than no check, because it is
	# trusted." Whether either is green or red on the CURRENTLY AUTHORED
	# numbers is itself the measurement this task exists to produce; see the
	# P2.14 evidence report for the reading and, if red, the proposed
	# replacement numbers with their own supporting measurement.
	assert_int(within_response_count).append_failure_message("the scripted bot's own starting position/steering failed its response-window precondition in at least one seed -- see " + b_message).is_equal(SEEDS.size())
	assert_int(destroyed_count).append_failure_message(a_message).is_greater_equal(3)
	assert_int(above_half_count).append_failure_message(b_message).is_equal(SEEDS.size())
