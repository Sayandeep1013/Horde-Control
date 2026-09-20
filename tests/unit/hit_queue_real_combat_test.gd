extends GdUnitTestSuite

## Real-combat coverage for F03-22, the property whose absence the finding
## actually names: melee/contact damage from a real enemy against a real
## target must flow through SimLoop's hit queue, not resolve directly
## inside the Area2D overlap callback. Uses a REAL EnemyController
## (player_hunter.tscn, Contact 8 dmg / 0.5 s tick, 18 px reach -- see
## data/enemies/player_hunter.tres) against a fake player Hurtbox, matching
## tests/unit/leash_test.gd's own fixture precedent for "a genuine Area2D
## overlap, not a simulated call" -- but with a REAL SimLoop instance also
## present in the tree, which leash_test.gd's own fixture deliberately has
## none of (see that file's header: "Real Autoloads here").
##
## This is the falsification target the task brief names directly:
## reverting src/combat/hitbox.gd's `_on_area_entered()` to resolve
## `hurtbox.receive_hit()` immediately (never calling `SimLoop.enqueue_hit
## ()`) leaves `get_last_hit_queue_snapshot_for_test()` empty on every
## tick, even though the fake player still visibly takes damage -- which is
## exactly the shape of bug F03-22 named ("damage still lands" is not
## evidence the queue is being used).

const SimLoopScript: GDScript = preload("res://src/core/sim_loop.gd")
const PlayerHunterScene: PackedScene = preload("res://scenes/entities/player_hunter.tscn")

const MAX_ITERATIONS: int = 200

var _loop: Node
var _enemy: EnemyController
var _fake_player: Node2D
var _player_hurtbox: Hurtbox


func before_test() -> void:
	_loop = auto_free(SimLoopScript.new()) as Node
	add_child(_loop)

	_enemy = auto_free(PlayerHunterScene.instantiate()) as EnemyController
	add_child(_enemy)

	_fake_player = auto_free(Node2D.new())
	add_child(_fake_player)
	_player_hurtbox = Hurtbox.new()
	_player_hurtbox.faction = Hurtbox.Faction.PLAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	_player_hurtbox.add_child(shape)
	_fake_player.add_child(_player_hurtbox)
	EntityRegistry.register_entity(_fake_player, _fake_player.global_position, [&"player"])

	# Well within the Hunter's 18 px contact reach (data/enemies/
	# player_hunter.tres) -- same positioning leash_test.gd's own fixture
	# uses for the identical reason.
	_enemy.global_position = Vector2(700, -700)
	_fake_player.global_position = _enemy.global_position

	await get_tree().physics_frame # let the deferred SimLoop group lookup land (see hitbox.gd's header)


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_fake_player) and EntityRegistry.is_registered(_fake_player):
		EntityRegistry.deregister_entity(_fake_player)


func test_a_real_contact_hit_populates_the_hit_queue_and_the_fake_player_takes_damage() -> void:
	var damage_received: Dictionary = {"count": 0}
	var hit_landed: Dictionary = {"count": 0}
	_player_hurtbox.damage_received.connect(func(_a: float, _s: Variant, _h: Node) -> void: damage_received["count"] += 1)
	_enemy.hitbox.hit_landed.connect(func(_hb: Hurtbox, _d: float, _s: Variant) -> void: hit_landed["count"] += 1)

	var queue_was_ever_non_empty: bool = false
	var iterations: int = 0
	while damage_received["count"] < 1 and iterations < MAX_ITERATIONS:
		await get_tree().physics_frame
		if not _loop.get_last_hit_queue_snapshot_for_test().is_empty():
			queue_was_ever_non_empty = true
		iterations += 1

	assert_int(damage_received["count"]).append_failure_message(
		"the fake player never took damage within %d ticks -- fixture cannot exercise real combat at all" % MAX_ITERATIONS
	).is_greater(0)

	assert_bool(queue_was_ever_non_empty).append_failure_message(
		"the fake player took damage, but SimLoop's hit queue was NEVER observed non-empty on any tick -- the hit resolved through a path that bypasses SimLoop.enqueue_hit(), which is exactly F03-22"
	).is_true()

	assert_int(hit_landed["count"]).append_failure_message(
		"Hitbox.hit_landed never fired even though the fake player took damage -- the on_hit_accepted callback wired through the queue is not reaching the original signal"
	).is_greater(0)


## A companion check on the same fixture: the queue is not merely non-empty
## at SOME point, it is non-empty on the SPECIFIC tick the damage signal
## fires -- i.e. the snapshot taken at step 7 the same tick the hit landed
## actually carries this hit's own target Hurtbox, not an unrelated one.
func test_the_hit_queue_snapshot_on_the_landing_tick_names_the_real_target() -> void:
	var landed_this_tick: Dictionary = {"landed": false}
	_player_hurtbox.damage_received.connect(func(_a: float, _s: Variant, _h: Node) -> void: landed_this_tick["landed"] = true)

	var matched: bool = false
	var iterations: int = 0
	while not landed_this_tick["landed"] and iterations < MAX_ITERATIONS:
		await get_tree().physics_frame
		iterations += 1
		if landed_this_tick["landed"]:
			for hit in _loop.get_last_hit_queue_snapshot_for_test():
				if hit.get("target_hurtbox") == _player_hurtbox:
					matched = true

	assert_bool(landed_this_tick["landed"]).append_failure_message("fixture never landed a hit within %d ticks" % MAX_ITERATIONS).is_true()
	assert_bool(matched).append_failure_message("the tick the damage signal fired on did not carry a hit queue record naming the fake player's own Hurtbox as target_hurtbox").is_true()
