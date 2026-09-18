extends GdUnitTestSuite

## Correctness coverage for src/combat/hitbox.gd and src/combat/hurtbox.gd
## (P1.5), separate from the named acceptance test in ghost_hit_test.gd.
## Exercises the binding layer/mask table (docs/20_Technical_Architecture.md
## > "Collision Layers"; MASTER_SDLC.md > Provisional Values Register >
## "Collision layers (binding)"), the Pool discovery groups, and the
## deferred-vs-direct mutation rule each component's own header comment
## documents.

const CollisionLayersScript: GDScript = preload("res://src/combat/collision_layers.gd")

var _hitbox: Hitbox
var _hurtbox: Hurtbox


func after_test() -> void:
	_hitbox = null
	_hurtbox = null


func _make_hitbox(targets_tower: bool = false) -> Hitbox:
	var h: Hitbox = Hitbox.new()
	h.targets_tower = targets_tower
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	h.add_child(shape)
	add_child(h)
	auto_free(h)
	return h


func _make_hurtbox(faction: Hurtbox.Faction = Hurtbox.Faction.ENEMY) -> Hurtbox:
	var hb: Hurtbox = Hurtbox.new()
	hb.faction = faction
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	hb.add_child(shape)
	add_child(hb)
	auto_free(hb)
	return hb


# --- Layer/mask assignment, diffed against the Register row -------------

func test_hitbox_applies_enemy_hitbox_layer_and_player_only_mask_by_default() -> void:
	_hitbox = _make_hitbox(false)
	# docs/20 table row 11: "EnemyHitbox ... masks 8".
	assert_int(_hitbox.collision_layer).is_equal(1 << 10)
	assert_int(_hitbox.collision_mask).is_equal(1 << 7)


func test_hitbox_extends_mask_to_tower_hurtbox_when_targeting_the_tower() -> void:
	_hitbox = _make_hitbox(true)
	# docs/20 table row 11: "... and 10 only for telegraphed attacks aimed at the Tower".
	assert_int(_hitbox.collision_mask).is_equal((1 << 7) | (1 << 9))


func test_hurtbox_layer_matches_faction_and_mask_is_always_zero() -> void:
	var player_hb: Hurtbox = _make_hurtbox(Hurtbox.Faction.PLAYER)
	var enemy_hb: Hurtbox = _make_hurtbox(Hurtbox.Faction.ENEMY)
	var tower_hb: Hurtbox = _make_hurtbox(Hurtbox.Faction.TOWER)

	assert_int(player_hb.collision_layer).is_equal(1 << 7) # 8 PlayerHurtbox
	assert_int(enemy_hb.collision_layer).is_equal(1 << 8) # 9 EnemyHurtbox
	assert_int(tower_hb.collision_layer).is_equal(1 << 9) # 10 TowerHurtbox
	for hb in [player_hb, enemy_hb, tower_hb]:
		assert_int(hb.collision_mask).append_failure_message("every Hurtbox row's Masks column is 'none' in the binding table").is_equal(0)
		assert_bool(hb.monitoring).append_failure_message("a hurtbox never scans").is_false()


# --- Pool discovery groups ------------------------------------------------

func test_hitbox_joins_pool_hitbox_group() -> void:
	_hitbox = _make_hitbox()
	assert_bool(_hitbox.is_in_group(&"pool_hitbox")).is_true()


func test_hurtbox_joins_pool_hurtbox_group() -> void:
	_hurtbox = _make_hurtbox()
	assert_bool(_hurtbox.is_in_group(&"pool_hurtbox")).is_true()


# --- Window activation: synchronous flag vs. deferred engine flag --------

func test_activate_window_sets_synchronous_flag_immediately() -> void:
	_hitbox = _make_hitbox()
	assert_bool(_hitbox.is_window_active()).is_false()
	_hitbox.activate_window()
	# The synchronous flag flips THIS SAME CALL, with no await needed --
	# this is what protects a same-tick overlap signal already in flight.
	assert_bool(_hitbox.is_window_active()).is_true()


func test_deactivate_window_clears_synchronous_flag_immediately() -> void:
	_hitbox = _make_hitbox()
	_hitbox.activate_window()
	_hitbox.deactivate_window()
	assert_bool(_hitbox.is_window_active()).is_false()


func test_activate_window_monitoring_change_is_deferred_not_immediate() -> void:
	_hitbox = _make_hitbox()
	_hitbox.activate_window()
	# monitoring itself is set via set_deferred (docs/20 > Physics &
	# Collisions: the same caution the collision-shape rule states) -- it
	# must NOT already be true in the same call that requested it.
	assert_bool(_hitbox.monitoring).append_failure_message("hitbox.monitoring changed synchronously instead of via set_deferred").is_false()
	await get_tree().physics_frame
	assert_bool(_hitbox.monitoring).is_true()


func test_deactivate_window_monitoring_change_is_deferred_not_immediate() -> void:
	_hitbox = _make_hitbox()
	_hitbox.activate_window()
	await get_tree().physics_frame
	assert_bool(_hitbox.monitoring).is_true()

	_hitbox.deactivate_window()
	assert_bool(_hitbox.monitoring).append_failure_message("hitbox.monitoring was cleared synchronously instead of via set_deferred").is_true()
	await get_tree().physics_frame
	assert_bool(_hitbox.monitoring).is_false()


# --- Hurtbox hit acceptance / rejection -----------------------------------

func test_receive_hit_accepts_and_emits_when_not_dead() -> void:
	_hurtbox = _make_hurtbox()
	var received: Array = []
	_hurtbox.damage_received.connect(func(amount: float, source: Variant, hitbox: Node) -> void:
		received.append([amount, source, hitbox])
	)
	var accepted: bool = _hurtbox.receive_hit(null, 10.0, "attacker")
	assert_bool(accepted).is_true()
	assert_int(received.size()).is_equal(1)
	assert_float(received[0][0]).is_equal(10.0)


func test_receive_hit_is_discarded_once_marked_dead() -> void:
	_hurtbox = _make_hurtbox()
	var call_count: int = 0
	_hurtbox.damage_received.connect(func(_a: float, _s: Variant, _h: Node) -> void: call_count += 1)

	_hurtbox.mark_dead()
	var accepted: bool = _hurtbox.receive_hit(null, 10.0, "attacker")

	assert_bool(accepted).append_failure_message("receive_hit() accepted a hit against an already-dead hurtbox").is_false()
	assert_int(call_count).is_equal(0)


func test_apply_logical_death_layers_is_deferred() -> void:
	_hurtbox = _make_hurtbox()
	_hurtbox.apply_logical_death_layers()
	assert_bool(_hurtbox.monitorable).append_failure_message("monitorable changed synchronously instead of via set_deferred").is_true()
	assert_int(_hurtbox.collision_layer).append_failure_message("collision_layer changed synchronously instead of via set_deferred").is_equal(1 << 8)
	await get_tree().physics_frame
	assert_bool(_hurtbox.monitorable).is_false()
	assert_int(_hurtbox.collision_layer).is_equal(0)


# --- reset_for_reuse (the pooled-instance seam) ---------------------------

func test_hitbox_reset_for_reuse_clears_window_flag() -> void:
	_hitbox = _make_hitbox()
	_hitbox.activate_window()
	assert_bool(_hitbox.is_window_active()).is_true()
	_hitbox.reset_for_reuse()
	assert_bool(_hitbox.is_window_active()).is_false()


func test_hurtbox_reset_for_reuse_clears_dead_flag() -> void:
	_hurtbox = _make_hurtbox()
	_hurtbox.mark_dead()
	assert_bool(_hurtbox.is_dead).is_true()
	_hurtbox.reset_for_reuse()
	assert_bool(_hurtbox.is_dead).is_false()


# --- _on_area_entered ignores non-Hurtbox areas ---------------------------

func test_hitbox_ignores_an_overlapping_area_that_is_not_a_hurtbox() -> void:
	_hitbox = _make_hitbox()
	_hitbox.activate_window()
	var plain_area: Area2D = auto_free(Area2D.new())
	var hit_landed_count: int = 0
	_hitbox.hit_landed.connect(func(_hb, _d, _s) -> void: hit_landed_count += 1)
	_hitbox._on_area_entered(plain_area)
	assert_int(hit_landed_count).is_equal(0)
