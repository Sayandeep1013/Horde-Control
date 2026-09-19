extends GdUnitTestSuite

## Leash test (P2.5 named acceptance test). MASTER_SDLC.md > Acceptance Test
## Matrix > Encounter Tests; docs/09_Enemy_AI_Architecture.md > "Player
## Hunter leash rule": "A leash timer starts the moment a Hunter spawns and
## resets every time it damages the player. If 20 seconds pass without a
## reset, the Hunter telegraphs for 0.5 seconds and then converts
## permanently into a full Tower Seeker -- it adopts the Tower Seeker's
## complete behaviour and stat profile while keeping its current HP."
## Register > Enemies > "Player Hunter" row cites the same 20 s / 0.5 s
## figures.
##
## Two mechanisms under test:
##   1. No reset for 20 s -> 0.5 s telegraph -> permanent conversion,
##      keeping current HP, re-tagged as a real Tower Seeker
##      (EntityRegistry `tower_seeker` tag -- LEDGER F03-15).
##   2. Landing a hit on the player resets the timer (tested with REAL
##      physics so an actual Hitbox/Hurtbox overlap resolves the hit, not a
##      simulated call).
##
## Timing strategy: test 1 injects a fresh SimClock instance and drives
## `physics_step()` manually with `driven_externally = true` (matching
## tests/unit/tower_health_recovery_test.gd's own established pattern), so
## 20.5 simulated seconds cost no real wall-clock time and this controller's
## own `_physics_process()` never double-steps alongside the manual calls.
## Test 2 uses the REAL SimClock/EntityRegistry Autoloads and real
## `await get_tree().physics_frame` ticks, matching tests/unit/
## tower_weapon_test.gd's own precedent for anything that needs a genuine
## Area2D overlap.

const PlayerHunterScene: PackedScene = preload("res://scenes/entities/player_hunter.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")

const LEASH_TIMEOUT_SECONDS: float = 20.0 # Register > Enemies > "Player Hunter": "leash 20 s"
const LEASH_TELEGRAPH_SECONDS: float = 0.5 # Register > Enemies > "Player Hunter": "0.5 s telegraph"

var _registry: Node
var _clock: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new()) as Node
	AttackSlotManager.clear_all_for_test()


func _build_hunter() -> EnemyController:
	var enemy: EnemyController = PlayerHunterScene.instantiate() as EnemyController
	enemy.set_registry_for_test(_registry)
	enemy.set_sim_clock_for_test(_clock)
	enemy.driven_externally = true
	add_child(enemy)
	auto_free(enemy)
	return enemy


func _advance(enemy: EnemyController, seconds: float, step: float = 0.05) -> void:
	var steps: int = int(floor(seconds / step + 0.0001)) # floor, never round -- a "just short of a threshold" test must never accidentally overshoot it
	for _i in steps:
		_clock.now += step
		enemy.physics_step(step)


# --- Mechanism 1: no reset for 20s + 0.5s telegraph -> permanent conversion -

func test_hunter_does_not_convert_before_the_leash_timeout() -> void:
	var enemy: EnemyController = _build_hunter()
	_advance(enemy, LEASH_TIMEOUT_SECONDS - 0.5)
	assert_bool(enemy.is_leash_telegraphing()).append_failure_message("telegraph started too early -- before the 20s leash timeout elapsed").is_false()
	assert_int(enemy.get_current_intent()).append_failure_message("converted before the leash timeout elapsed").is_equal(ContractEnums.TargetIntent.PlayerHunter)


func test_hunter_telegraphs_for_0_5s_then_converts_permanently_to_a_full_tower_seeker() -> void:
	var enemy: EnemyController = _build_hunter()
	# Take some damage first so HP != max HP, so "keeping current HP" is a
	# real, falsifiable check rather than one that would also pass if the
	# conversion silently reset HP to the new max.
	enemy.death_state.apply_damage(10.0, "test_setup")
	var hp_before_conversion: float = enemy.death_state.current_hp
	assert_float(hp_before_conversion).is_equal_approx(20.0, 0.01) # 30 (Hunter max) - 10

	_advance(enemy, LEASH_TIMEOUT_SECONDS + 0.01)
	assert_bool(enemy.is_leash_telegraphing()).append_failure_message("telegraph did not start once the 20s leash timeout elapsed").is_true()
	assert_int(enemy.get_current_intent()).append_failure_message("converted before the 0.5s telegraph finished").is_equal(ContractEnums.TargetIntent.PlayerHunter)

	_advance(enemy, LEASH_TELEGRAPH_SECONDS - 0.02) # just short of the telegraph's own duration
	assert_int(enemy.get_current_intent()).append_failure_message("converted before the full 0.5s telegraph elapsed").is_equal(ContractEnums.TargetIntent.PlayerHunter)

	_advance(enemy, 0.05) # crosses the telegraph deadline
	assert_int(enemy.get_current_intent()).append_failure_message("did not convert to Tower Seeker once the telegraph finished").is_equal(ContractEnums.TargetIntent.TowerSeeker)

	# "adopts the Tower Seeker's complete behaviour and stat profile"
	assert_str(enemy.definition.unique_id).append_failure_message("did not adopt the Tower Seeker's EnemyDefinition").is_equal("tower_seeker")
	assert_float(enemy.death_state.max_hp).append_failure_message("did not adopt the Tower Seeker's max HP (60)").is_equal_approx(60.0, 0.01)

	# "while keeping its current HP"
	assert_float(enemy.death_state.current_hp).append_failure_message("current HP was not preserved across conversion").is_equal_approx(hp_before_conversion, 0.01)

	# LEDGER F03-15: tags must change with it.
	assert_bool(_registry.get_tags(enemy).has(&"tower_seeker")).append_failure_message("converted enemy is not tagged tower_seeker -- the real Tower's weapon (SEEKER_TAG) would never find it").is_true()
	assert_bool(_registry.get_tags(enemy).has(&"enemy")).is_true()


func test_finisher_hunters_carry_no_leash_timer() -> void:
	# Register > Spawning & Waves > "Overtime finishers": "no leash timer,
	# the finisher flag survives any conversion".
	var enemy: EnemyController = PlayerHunterScene.instantiate() as EnemyController
	enemy.is_finisher = true
	enemy.set_registry_for_test(_registry)
	enemy.set_sim_clock_for_test(_clock)
	enemy.driven_externally = true
	add_child(enemy)
	auto_free(enemy)

	_advance(enemy, LEASH_TIMEOUT_SECONDS + LEASH_TELEGRAPH_SECONDS + 5.0)
	assert_int(enemy.get_current_intent()).append_failure_message("a finisher Hunter converted despite carrying no leash timer").is_equal(ContractEnums.TargetIntent.PlayerHunter)
	assert_bool(enemy.is_leash_telegraphing()).is_false()


# --- Mechanism 2: landing a hit on the player resets the timer -------------

func test_landing_a_real_hit_on_the_player_resets_the_leash_timer() -> void:
	var enemy: EnemyController = PlayerHunterScene.instantiate() as EnemyController
	# Real Autoloads here -- this sub-test needs a genuine Area2D overlap.
	add_child(enemy)
	auto_free(enemy)

	var fake_player: Node2D = Node2D.new()
	add_child(fake_player)
	auto_free(fake_player)
	var player_hurtbox: Hurtbox = Hurtbox.new()
	player_hurtbox.faction = Hurtbox.Faction.PLAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	player_hurtbox.add_child(shape)
	fake_player.add_child(player_hurtbox)
	EntityRegistry.register_entity(fake_player, fake_player.global_position, [&"player"])

	# Force the leash right to the edge of firing, well short of the real
	# 20s, so this test does not need to wait 20 real seconds of physics
	# frames to prove the reset.
	enemy.set_leash_deadline_for_test(SimClock.now + 0.05)

	enemy.global_position = Vector2(500, 500)
	fake_player.global_position = enemy.global_position # well within the Hunter's 18px contact reach

	var hit_landed: Dictionary = {"count": 0}
	enemy.hitbox.hit_landed.connect(func(_hb, _dmg, _src) -> void: hit_landed["count"] += 1)

	var iterations: int = 0
	while hit_landed["count"] < 1 and iterations < 200:
		await get_tree().physics_frame
		iterations += 1

	assert_int(hit_landed["count"]).append_failure_message("no contact hit landed on the fake player within the timeout -- fixture cannot exercise the reset at all").is_greater(0)
	assert_bool(enemy.is_leash_telegraphing()).append_failure_message("leash telegraph fired even though a hit just landed -- the reset did not take effect").is_false()
	assert_int(enemy.get_current_intent()).append_failure_message("Hunter converted even though it just landed a hit on the player").is_equal(ContractEnums.TargetIntent.PlayerHunter)
	assert_float(enemy.get_leash_deadline_for_test()).append_failure_message("leash deadline was not pushed back out to a fresh ~20s window after the landed hit").is_greater(SimClock.now + LEASH_TIMEOUT_SECONDS - 1.0)

	EntityRegistry.deregister_entity(fake_player)
