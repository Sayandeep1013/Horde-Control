extends GdUnitTestSuite

## Stuck exemption test (P2.5 named acceptance test). MASTER_SDLC.md >
## Acceptance Test Matrix > Encounter Tests; docs/09_Enemy_AI_Architecture.md
## > "Stuck rules": "Stuck timers run only while an enemy is outside attack
## or contact reach of its target and is not merely held back by other
## enemies already attacking that same target; an enemy queued behind
## others simply moves to the nearest free attack slot. After 3 seconds
## without path progress... it falls back... After 8 seconds of less than
## 8 pixels of displacement the global stuck detector forces direct
## approach; after 20 seconds still stuck it despawns"; > "Tower Seeker
## body-block rule": "time blocked by the player accrues no stuck time."
## This task's own brief adds: "Time a Tower Seeker spends blocked by the
## player's body also accrues no stuck time."
##
## Three mechanisms under test:
##   1. Queued-exempt: an enemy waiting for a full attack-slot ring accrues
##      zero stuck time and claims the nearest free slot once one opens.
##   2. Body-block-exempt: a Tower Seeker blocked by the player's body
##      accrues zero stuck time.
##   3. Genuinely blocked: an enemy that cannot progress at all runs the
##      3s (fallback) / 8s (forced direct approach) / 20s (despawn) ladder.
##
## Timing strategy matches leash_test.gd and opportunist_test.gd: an
## injected, fresh SimClock driven manually with `driven_externally = true`
## so 20+ simulated seconds cost no real wall-clock time.

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const OpportunistScene: PackedScene = preload("res://scenes/entities/opportunist.tscn")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")

const TOWER_FOOTPRINT_RADIUS_PX: float = 106.0
const SEEKER_BODY_RADIUS_PX: float = 14.0
const SEEKER_REACH_PX: float = 20.0

var _registry: Node
var _clock: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new()) as Node
	AttackSlotManager.clear_all_for_test()


func after_test() -> void:
	AttackSlotManager.clear_all_for_test()


func _build_tower(position: Vector2) -> Node:
	var tower: Node = auto_free(TowerScene.instantiate())
	add_child(tower)
	tower.global_position = position
	tower.weapon.set_registry_for_test(_registry)
	return tower


func _build_seeker(position: Vector2, tower: Node) -> EnemyController:
	var enemy: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	enemy.set_registry_for_test(_registry)
	enemy.set_sim_clock_for_test(_clock)
	enemy.driven_externally = true
	add_child(enemy)
	auto_free(enemy)
	enemy.global_position = position
	enemy.set_tower_reference(tower)
	return enemy


func _tick(enemy: EnemyController, seconds: float, step: float = 0.05) -> void:
	var steps: int = int(floor(seconds / step + 0.0001)) # floor, never round -- a "just short of a threshold" test must never accidentally overshoot it
	for _i in steps:
		_clock.now += step
		enemy.physics_step(step)


# --- Mechanism 1: queued-exempt (a full attack-slot ring) -------------------

func test_an_enemy_waiting_for_a_full_ring_accrues_no_stuck_time_and_claims_a_freed_slot() -> void:
	var tower: Node = _build_tower(Vector2(0, 0))
	var slot_count: int = AttackSlotManager.compute_slot_count(TOWER_FOOTPRINT_RADIUS_PX, SEEKER_BODY_RADIUS_PX, SEEKER_REACH_PX)
	# Register > Spawning & Waves > "Attack slots (C-SLOTS)": "Tower with
	# Tower Seekers: 27" -- this also cross-checks AttackSlotManager's own
	# formula against the Register's own worked example.
	assert_int(slot_count).append_failure_message("N=%d does not match the Register's own worked example of 27 for a Tower Seeker ring around the Tower" % slot_count).is_equal(27)
	var ring_radius: float = AttackSlotManager.ring_radius(TOWER_FOOTPRINT_RADIUS_PX, SEEKER_BODY_RADIUS_PX, SEEKER_REACH_PX)

	var dummies: Array[Node2D] = []
	for i in slot_count:
		var d: Node2D = Node2D.new()
		add_child(d)
		auto_free(d)
		dummies.append(d)
		var claimed: int = AttackSlotManager.claim_nearest_free_slot(tower, d, slot_count, ring_radius)
		assert_int(claimed).append_failure_message("dummy claimant %d could not claim a slot while the ring was not yet full" % i).is_greater_equal(0)
	assert_bool(AttackSlotManager.has_free_slot(tower, slot_count)).append_failure_message("ring is not actually full after claiming all %d slots" % slot_count).is_false()

	# Already sitting exactly at the "wait 32px outside the ring" spot, so
	# it is waiting for a slot from tick one, not merely still travelling.
	var enemy: EnemyController = _build_seeker(Vector2(ring_radius + 32.0, 0), tower)
	_tick(enemy, 0.1)
	assert_bool(enemy.is_waiting_for_slot_for_test()).append_failure_message("did not detect itself as waiting for a slot with the ring full").is_true()

	_tick(enemy, 25.0) # well past the 20s despawn mark
	assert_float(enemy.get_stuck_seconds_for_test()).append_failure_message("a queued/waiting enemy accrued stuck time -- it must accrue none").is_equal_approx(0.0, 0.001)
	assert_bool(enemy.is_stuck_despawned()).append_failure_message("a queued/waiting enemy despawned -- it must never accrue stuck time at all").is_false()
	assert_int(enemy.get_current_intent()).is_equal(ContractEnums.TargetIntent.TowerSeeker) # sanity: still alive and un-converted

	# Free one slot -- the enemy must move to claim it.
	AttackSlotManager.release_claim(tower, dummies[0])
	_tick(enemy, 0.5)
	assert_int(enemy.get_claimed_slot_for_test()).append_failure_message("did not claim the newly freed attack slot").is_greater_equal(0)
	assert_bool(enemy.is_waiting_for_slot_for_test()).is_false()


# --- Mechanism 2: Tower Seeker body-block exemption -------------------------

func test_a_tower_seeker_blocked_by_the_players_body_accrues_no_stuck_time() -> void:
	var tower: Node = _build_tower(Vector2(2000, 0)) # far away -- the Seeker cannot reach it while blocked
	var enemy: EnemyController = _build_seeker(Vector2(0, 0), tower)
	var fake_player: Node2D = Node2D.new()
	add_child(fake_player)
	auto_free(fake_player)
	fake_player.global_position = Vector2(15, 0) # within the Seeker's 20px reach
	enemy.set_player_for_test(fake_player)

	# Pin the enemy's own position every tick, exactly like the "genuinely
	# blocked" test below -- the player's body, not a wall, is what is
	# named as the blocker here, but the mechanical effect (zero net
	# displacement toward the Tower) is the same fixture technique.
	var pinned_position: Vector2 = enemy.global_position
	for _i in range(500): # 25s at 0.05s steps
		_clock.now += 0.05
		enemy.physics_step(0.05)
		enemy.global_position = pinned_position

	assert_bool(enemy.is_body_blocked_for_test()).append_failure_message("body-block was never detected even though the player has sat within reach for 25s with zero progress").is_true()
	assert_float(enemy.get_stuck_seconds_for_test()).append_failure_message("a body-blocked Tower Seeker accrued stuck time -- it must accrue none").is_equal_approx(0.0, 0.001)
	assert_bool(enemy.is_stuck_despawned()).append_failure_message("a body-blocked Tower Seeker despawned").is_false()


# --- Mechanism 3: genuinely blocked runs the 3s/8s/20s ladder ---------------

func test_a_genuinely_blocked_enemy_runs_the_3s_8s_20s_ladder() -> void:
	var tower: Node = _build_tower(Vector2(3000, 0)) # far enough that reaching it needs real, sustained progress
	var enemy: EnemyController = _build_seeker(Vector2(0, 0), tower)
	var pinned_position: Vector2 = enemy.global_position

	# No player anywhere -- body-block can never apply; no other enemies --
	# queued-exemption can never apply either. This isolates the "genuinely
	# blocked" path from both exemptions.
	_advance_pinned(enemy, pinned_position, 2.9)
	assert_bool(enemy.is_direct_approach_for_test()).append_failure_message("direct approach triggered before the 3s mark").is_false()

	_advance_pinned(enemy, pinned_position, 0.2) # crosses 3.0s
	assert_bool(enemy.is_direct_approach_for_test()).append_failure_message("Tower Seeker (no secondary target) did not fall back to direct approach at the 3s mark").is_true()
	assert_bool(enemy.is_stuck_despawned()).is_false()

	_advance_pinned(enemy, pinned_position, 4.9) # up to just before 8.0s total
	assert_bool(enemy.is_stuck_despawned()).append_failure_message("despawned before the 20s mark").is_false()

	_advance_pinned(enemy, pinned_position, 11.9) # up to just before 20.0s total
	assert_bool(enemy.is_stuck_despawned()).append_failure_message("despawned before the full 20s elapsed").is_false()

	_advance_pinned(enemy, pinned_position, 0.3) # crosses 20.0s total
	assert_bool(enemy.is_stuck_despawned()).append_failure_message("did not despawn once genuinely stuck for the full 20s").is_true()


func test_opportunist_falls_back_to_the_other_target_at_3s_then_forces_direct_approach_at_8s_if_still_stuck() -> void:
	var tower: Node = _build_tower(Vector2(3000, 0))
	var enemy: EnemyController = OpportunistScene.instantiate() as EnemyController
	enemy.set_registry_for_test(_registry)
	enemy.set_sim_clock_for_test(_clock)
	enemy.driven_externally = true
	add_child(enemy)
	auto_free(enemy)
	enemy.global_position = Vector2(0, 0)
	enemy.set_tower_reference(tower)
	var fake_player: Node2D = Node2D.new()
	add_child(fake_player)
	auto_free(fake_player)
	fake_player.global_position = Vector2(3000, 500) # also far -- genuinely unreachable, so it stays stuck even after the 3s switch
	enemy.set_player_for_test(fake_player)

	_tick(enemy, 0.1)
	assert_object(enemy.get_target_for_test()).is_same(tower) # closer at spawn

	var pinned_position: Vector2 = enemy.global_position
	_advance_pinned(enemy, pinned_position, 3.2) # crosses the 3s mark
	assert_object(enemy.get_target_for_test()).append_failure_message("Opportunist did not fall back to its secondary target (the other target) at the 3s stuck mark").is_same(fake_player)
	assert_bool(enemy.is_direct_approach_for_test()).append_failure_message("direct approach fired at the 3s mark for an Opportunist -- its 3s fallback is the OTHER target, not direct approach").is_false()

	_advance_pinned(enemy, pinned_position, 5.0) # crosses 8s total -- still stuck toward the new target
	assert_bool(enemy.is_direct_approach_for_test()).append_failure_message("the global 8s stuck detector did not force direct approach even after the Opportunist's own 3s fallback failed to unstick it").is_true()


func _advance_pinned(enemy: EnemyController, pinned_position: Vector2, seconds: float, step: float = 0.05) -> void:
	var steps: int = int(floor(seconds / step + 0.0001)) # floor, never round -- a "just short of a threshold" test must never accidentally overshoot it
	for _i in steps:
		_clock.now += step
		enemy.physics_step(step)
		enemy.global_position = pinned_position
