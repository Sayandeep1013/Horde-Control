extends GdUnitTestSuite

## AttackSlotManager unit test (P2.5). Register > Spawning & Waves >
## "Attack slots (C-SLOTS)"; docs/09_Enemy_AI_Architecture.md > "Attack
## slots" bullet. Covers the geometry formula against the Register's own
## two worked examples, and the claim/release/reap bookkeeping
## src/enemy/enemy_controller.gd's stuck-exemption logic depends on.

func before_test() -> void:
	AttackSlotManager.clear_all_for_test()


func after_test() -> void:
	AttackSlotManager.clear_all_for_test()


# --- The formula against the Register's own worked examples -----------------

func test_slot_count_matches_the_registers_tower_seeker_worked_example() -> void:
	# "Tower with Tower Seekers: 27" -- footprint 106, body 14, reach 20.
	var n: int = AttackSlotManager.compute_slot_count(106.0, 14.0, 20.0)
	assert_int(n).is_equal(27)


func test_slot_count_matches_the_registers_player_hunter_worked_example() -> void:
	# "player with Player Hunters, reach = contact hitbox margin 6 px: 7" --
	# player body radius 14, Hunter body radius 12, reach = 6.
	var n: int = AttackSlotManager.compute_slot_count(14.0, 12.0, 6.0)
	assert_int(n).is_equal(7)


func test_ring_radius_is_the_sum_the_formula_itself_uses() -> void:
	assert_float(AttackSlotManager.ring_radius(106.0, 14.0, 20.0)).is_equal_approx(140.0, 0.001)


# --- Claim / release / reap bookkeeping --------------------------------------

func test_claims_distinct_slots_for_distinct_claimants_and_reuses_none() -> void:
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	var claimants: Array[Node2D] = []
	var claimed_slots: Dictionary = {}
	for i in 5:
		var c: Node2D = auto_free(Node2D.new())
		add_child(c)
		c.global_position = Vector2(100, 0).rotated(TAU * float(i) / 5.0)
		claimants.append(c)
		var slot: int = AttackSlotManager.claim_nearest_free_slot(target, c, 5, 100.0)
		assert_int(slot).append_failure_message("claimant %d could not claim a slot" % i).is_greater_equal(0)
		assert_bool(claimed_slots.has(slot)).append_failure_message("slot %d was claimed by more than one claimant" % slot).is_false()
		claimed_slots[slot] = c


func test_a_full_ring_refuses_a_new_claim() -> void:
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	for i in 3:
		var c: Node2D = auto_free(Node2D.new())
		add_child(c)
		AttackSlotManager.claim_nearest_free_slot(target, c, 3, 100.0)
	assert_bool(AttackSlotManager.has_free_slot(target, 3)).is_false()
	var extra: Node2D = auto_free(Node2D.new())
	add_child(extra)
	var slot: int = AttackSlotManager.claim_nearest_free_slot(target, extra, 3, 100.0)
	assert_int(slot).append_failure_message("a full ring must refuse a new claim (-1), not silently double up on an existing slot").is_equal(-1)


func test_releasing_a_claim_frees_it_for_another_claimant() -> void:
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	var holders: Array[Node2D] = []
	for i in 3:
		var c: Node2D = auto_free(Node2D.new())
		add_child(c)
		AttackSlotManager.claim_nearest_free_slot(target, c, 3, 100.0)
		holders.append(c)
	AttackSlotManager.release_claim(target, holders[0])
	assert_bool(AttackSlotManager.has_free_slot(target, 3)).is_true()
	var waiting: Node2D = auto_free(Node2D.new())
	add_child(waiting)
	var slot: int = AttackSlotManager.claim_nearest_free_slot(target, waiting, 3, 100.0)
	assert_int(slot).append_failure_message("did not claim the slot just released").is_greater_equal(0)


func test_a_freed_claimant_instance_is_reaped_and_its_slot_becomes_available() -> void:
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	var doomed: Node2D = Node2D.new()
	add_child(doomed)
	AttackSlotManager.claim_nearest_free_slot(target, doomed, 1, 100.0)
	assert_bool(AttackSlotManager.has_free_slot(target, 1)).is_false()
	doomed.free()
	assert_bool(AttackSlotManager.has_free_slot(target, 1)).append_failure_message("a slot held by a freed (invalid) claimant was never reaped").is_true()
