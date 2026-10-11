extends GdUnitTestSuite

## PT-SWARM boss suite (docs/33 §C4; Register "v1.0 Enemies, Bosses & Waves",
## D340): the King attacks a moving player and the Tower (playtest defect), each
## boss's patterns trigger, stagger windows open after the big attacks with
## +50% damage taken, and the phase marks the HUD reads. Expectations are
## literals transcribed from docs/33 and the Register rows, not reads of the
## behaviour constants.

const WarchiefScene: PackedScene = preload("res://scenes/entities/goblin_warchief.tscn")
const JuggernautScene: PackedScene = preload("res://scenes/entities/gutbarrel_juggernaut.tscn")
const KingScene: PackedScene = preload("res://scenes/entities/bombardier_king.tscn")
const ShamanScene: PackedScene = preload("res://scenes/entities/goblin_shaman.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const Target: GDScript = preload("res://tests/unit/v1_test_target.gd")
const SummonRecorder: GDScript = preload("res://tests/unit/v1_summon_recorder.gd")


## A player stand-in that actually moves (a CharacterBody2D with a velocity, so
## lead-aiming bosses see what a real player gives them).
class MovingTarget extends CharacterBody2D:
	var hurtbox: Hurtbox = null
	var damage_log: Array[float] = []

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 0
		hurtbox = Hurtbox.new()
		hurtbox.faction = Hurtbox.Faction.PLAYER
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 14.0
		shape.shape = circle
		hurtbox.add_child(shape)
		add_child(hurtbox)
		hurtbox.damage_received.connect(func(amount: float, _s: Variant, _h: Node) -> void: damage_log.append(amount))

	func total_damage() -> float:
		var t: float = 0.0
		for d in damage_log:
			t += d
		return t


var _registry: Node
var _clock: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new())
	AttackSlotManager.clear_all_for_test()
	CombatStats.reset_run_stats()


func after_test() -> void:
	for c in get_children():
		if c is EnemyBomb or c is GroundTelegraph or c is ExplosionFx or c is LineTelegraph or c is EnemyBulletField:
			remove_child(c)
			c.free()


func _enemy(scene: PackedScene, pos: Vector2) -> EnemyController:
	var e: EnemyController = scene.instantiate() as EnemyController
	e.set_registry_for_test(_registry)
	e.set_sim_clock_for_test(_clock)
	e.driven_externally = true
	e.position = pos
	add_child(e)
	auto_free(e)
	return e


func _target(pos: Vector2, tag: StringName, faction: Hurtbox.Faction = Hurtbox.Faction.PLAYER) -> Node2D:
	var t: Node2D = Target.new()
	t.set("faction", faction)
	t.position = pos
	add_child(t)
	auto_free(t)
	_registry.register_entity(t, pos, [tag])
	return t


func _mover(pos: Vector2) -> MovingTarget:
	var m := MovingTarget.new()
	m.position = pos
	add_child(m)
	auto_free(m)
	_registry.register_entity(m, pos, [&"player"])
	return m


func _field() -> EnemyBulletField:
	for c in get_children():
		if c is EnemyBulletField:
			return c
	return null


## Steps the enemy, every bomb and the bullet field `seconds` of SimClock time.
## `mover` (optional) is called with the step first, to move a player.
func _advance(e: EnemyController, seconds: float, step: float = 0.05, mover: Callable = Callable()) -> void:
	for _i in int(round(seconds / step)):
		_clock.now += step
		if mover.is_valid():
			mover.call(step)
		e.physics_step(step)
		for c in get_children():
			if c is EnemyBomb:
				(c as EnemyBomb)._physics_process(step)
		var f: EnemyBulletField = _field()
		if f != null:
			f.check_obstacles = false
			f.step(step)


# --- Bombardier King: the playtest defect ----------------------------------------

## Regression for docs/33 §C4 ("he did not attack the Tower or the player"): a
## player strafing at 280 px/s, reversing every 4 s, must take damage from the
## King within 16 s, and so must the Tower. Before PT-SWARM this player took 0
## (the Barrage landed where the player had been 1.1 s earlier).
func test_king_hits_a_strafing_player_and_the_tower() -> void:
	var tower: Node2D = _target(Vector2.ZERO, &"tower", Hurtbox.Faction.TOWER)
	var player: MovingTarget = _mover(Vector2(-200.0, 260.0))
	var king: EnemyController = _enemy(KingScene, Vector2(380, 0))
	var leg: Array = [0.0, 1.0]
	var mover: Callable = func(dt: float) -> void:
		leg[0] += dt
		if leg[0] >= 4.0:
			leg[0] = 0.0
			leg[1] = -leg[1]
		player.velocity = Vector2(280.0 * leg[1], 0.0)
		player.global_position += player.velocity * dt
		_registry.update_position(player, player.global_position)
	_advance(king, 16.0, 0.05, mover)
	assert_float(player.total_damage()).append_failure_message("a moving player took no damage from the King in 16 s").is_greater(0.0)
	assert_float(tower.total_damage()).append_failure_message("the Tower took no damage from the King in 16 s").is_greater(0.0)
	var kb: KingBehavior = king.behavior as KingBehavior
	assert_int(kb.fans_fired).append_failure_message("the dynamite fan (every 3.5 s from 2 s) should have fired 4 times").is_greater_equal(4)
	assert_int(kb.siege_bombs).is_greater_equal(1)


func test_king_phase_marks_are_60_and_25_percent_and_the_hud_property_stays() -> void:
	var king: EnemyController = _enemy(KingScene, Vector2(380, 0))
	var kb: KingBehavior = king.behavior as KingBehavior
	assert_array(kb.phase_fractions).is_equal([0.6, 0.25])
	assert_float(kb.phase_two_fraction).append_failure_message("the HUD reads phase_two_fraction").is_equal(0.6)
	var max_hp: float = king.death_state.max_hp
	king.death_state.apply_damage(max_hp * 0.4, "test")
	assert_int(kb.phase).append_failure_message("exactly 60% is still phase 1").is_equal(1)
	king.death_state.apply_damage(1.0, "test")
	assert_int(kb.phase).is_equal(2)
	king.death_state.apply_damage(max_hp * 0.35, "test")
	assert_int(kb.phase).is_equal(3)


func test_king_phase_two_spins_a_rotating_spiral_then_is_staggered_and_takes_half_again_damage() -> void:
	_target(Vector2.ZERO, &"tower", Hurtbox.Faction.TOWER)
	_target(Vector2(0, 600), &"player")
	var king: EnemyController = _enemy(KingScene, Vector2(380, 0))
	var kb: KingBehavior = king.behavior as KingBehavior
	king.death_state.apply_damage(king.death_state.max_hp * 0.45, "test")
	assert_int(kb.phase).is_equal(2)
	_advance(king, 1.6)
	assert_int(kb.state).append_failure_message("the spiral starts 1.5 s into phase 2").is_equal(KingBehavior.State.SPIRAL)
	var fired_before: int = _field().fired_total
	_advance(king, 1.0)
	assert_int(_field().fired_total - fired_before).append_failure_message("3 arms every 0.12 s for 1 s").is_between(21, 30)
	_advance(king, 2.1)
	assert_bool(kb.is_staggered()).append_failure_message("winded after the 3 s spiral").is_true()
	var hp: float = king.death_state.current_hp
	king.hurtbox.receive_hit(null, 100.0, "test")
	assert_float(hp - king.death_state.current_hp).append_failure_message("+50% damage while staggered").is_equal_approx(150.0, 0.01)
	_advance(king, 1.6)
	assert_bool(kb.is_staggered()).is_false()
	hp = king.death_state.current_hp
	king.hurtbox.receive_hit(null, 100.0, "test")
	assert_float(hp - king.death_state.current_hp).append_failure_message("the window closed").is_equal_approx(100.0, 0.01)


func test_king_phase_three_powder_storm_leaves_safe_gaps_and_calls_bombers() -> void:
	var recorder: Node = SummonRecorder.new()
	add_child(recorder)
	auto_free(recorder)
	_target(Vector2.ZERO, &"tower", Hurtbox.Faction.TOWER)
	_target(Vector2(0, 600), &"player")
	var king: EnemyController = _enemy(KingScene, Vector2(380, 0))
	var kb: KingBehavior = king.behavior as KingBehavior
	king.death_state.apply_damage(king.death_state.max_hp * 0.8, "test")
	assert_int(kb.phase).is_equal(3)
	_advance(king, 1.2)
	assert_int(kb.state).is_equal(KingBehavior.State.STORM)
	assert_array(recorder.calls).contains([["bomber", 3]])
	_advance(king, 4.4) # 0.5 s lead-in, 5 waves 0.7 s apart, then the stagger
	assert_int(kb.storms).is_equal(1)
	# 5 waves of 22 orbs, each with two gaps: well under 5 x 22 orbs left the King.
	var fired: int = _field().fired_total
	assert_int(fired).append_failure_message("five radial waves").is_between(5 * 12, 5 * 21)
	assert_bool(kb.is_staggered()).append_failure_message("stagger 2 s after the storm (state=%d waves_left=%d t=%.2f next_shot=%.2f staggers=%d)" % [kb.state, kb.get("_storm_waves_left"), _clock.now, kb.get("_next_shot"), kb.staggers_total]).is_true()


# --- Goblin Warchief ---------------------------------------------------------------

func test_warchief_triple_charge_redirects_at_the_player_and_ends_winded() -> void:
	# No Tower: he stands still until his first lunge, so the lunge geometry is exact.
	var player: Node2D = _target(Vector2(420, 0), &"player")
	var boss: EnemyController = _enemy(WarchiefScene, Vector2.ZERO)
	var wb: WarchiefBehavior = boss.behavior as WarchiefBehavior
	_advance(boss, 5.2)
	assert_int(wb.state).append_failure_message("first charge wind-up at 5 s").is_equal(WarchiefBehavior.State.CHARGE_WIND)
	assert_bool(get_children().any(func(c: Node) -> bool: return c is LineTelegraph)).append_failure_message("a lane telegraph shows the charge").is_true()
	var guard: int = 0
	while wb.charges_made < 3 and guard < 200:
		_advance(boss, 0.05)
		guard += 1
	assert_int(wb.charges_made).is_equal(3)
	assert_bool(wb.is_staggered()).append_failure_message("winded after the third lunge").is_true()
	assert_int((player as Node).get("damage_log").size()).append_failure_message("the lunges pass through the player").is_greater(0)


func test_warchief_charging_into_a_rock_is_stunned_and_staggered() -> void:
	_target(Vector2(500, 0), &"player")
	var wall := StaticBody2D.new()
	wall.collision_layer = CollisionLayers.LAYER_WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(220, 0)
	add_child(wall)
	auto_free(wall)
	await get_tree().physics_frame
	var boss: EnemyController = _enemy(WarchiefScene, Vector2.ZERO)
	var wb: WarchiefBehavior = boss.behavior as WarchiefBehavior
	_advance(boss, 6.2, 1.0 / 60.0) # move_and_slide moves by the engine tick, so step at 60 Hz
	assert_int(wb.wall_stuns).append_failure_message("the first lunge hits the wall at x=200 (x=%.1f charges=%d state=%d)" % [boss.global_position.x, wb.charges_made, wb.state]).is_equal(1)
	assert_bool(wb.is_staggered()).is_true()
	assert_float(wb.stagger_time_left()).is_greater(1.0)
	assert_float(boss.global_position.x).append_failure_message("the rock stops him").is_less(200.0)


func test_warchief_ground_fissures_lane_the_player_and_enrage_raises_them_to_five() -> void:
	var player: Node2D = _target(Vector2(0, 100), &"player") # inside charge minimum range: no charge
	var boss: EnemyController = _enemy(WarchiefScene, Vector2.ZERO)
	var wb: WarchiefBehavior = boss.behavior as WarchiefBehavior
	_advance(boss, 0.05)
	wb.set("_next_slam", 1000.0) # isolate the fissures from the slam
	_advance(boss, 9.05)
	assert_int(wb.state).is_equal(WarchiefBehavior.State.FISSURE_WIND)
	assert_int(get_children().filter(func(c: Node) -> bool: return c is LineTelegraph).size()).is_equal(3)
	_advance(boss, 1.05)
	assert_int(wb.fissures_erupted).is_equal(1)
	assert_array((player as Node).get("damage_log")).contains([26.0])
	boss.death_state.apply_damage(boss.death_state.max_hp * 0.6, "test")
	wb.set("_next_fissure", _clock.now)
	_advance(boss, 0.05)
	assert_int(get_children().filter(func(c: Node) -> bool: return c is LineTelegraph and not c.is_queued_for_deletion()).size()).append_failure_message("enraged: 5 lanes").is_equal(5)


# --- Gutbarrel the Juggernaut ---------------------------------------------------------

func test_juggernaut_uses_all_five_patterns_and_staggers_after_roll_and_spin() -> void:
	_target(Vector2(-3000, 0), &"tower", Hurtbox.Faction.TOWER)
	var player: Node2D = _target(Vector2(250, 0), &"player")
	var boss: EnemyController = _enemy(JuggernautScene, Vector2.ZERO)
	var jb: JuggernautBehavior = boss.behavior as JuggernautBehavior
	assert_float(boss.death_state.max_hp).is_equal_approx(6500.0, 0.01)
	assert_float(jb.phase_two_fraction).is_equal(0.5)
	var mover: Callable = func(_dt: float) -> void:
		player.global_position = boss.global_position + Vector2(250, 0) # keep the player 250 px away
		_registry.update_position(player, player.global_position)
	_advance(boss, 30.0, 0.05, mover)
	for p in ["roll", "barrels", "shrapnel", "spin", "stomp"]:
		assert_bool(jb.patterns_used.has(p)).append_failure_message("pattern %s never fired in 30 s: %s" % [p, jb.patterns_used]).is_true()
	assert_int(jb.staggers_total).append_failure_message("roll and spin both end in a stagger").is_greater_equal(2)


func test_juggernaut_drops_eight_barrels_on_a_ring_round_the_player_that_explode_after_1_5_s() -> void:
	_target(Vector2(-3000, 0), &"tower", Hurtbox.Faction.TOWER)
	var player: Node2D = _target(Vector2(600, 0), &"player")
	var boss: EnemyController = _enemy(JuggernautScene, Vector2.ZERO)
	var jb: JuggernautBehavior = boss.behavior as JuggernautBehavior
	_advance(boss, 0.05)
	jb.set("_next", {"roll": 1000.0, "barrels": _clock.now + 0.1, "shrapnel": 1000.0, "spin": 1000.0, "stomp": 1000.0})
	_advance(boss, 0.2)
	var bombs: Array = get_children().filter(func(c: Node) -> bool: return c is EnemyBomb)
	assert_int(bombs.size()).is_equal(8)
	for b in bombs:
		assert_float((b as EnemyBomb).target_position.distance_to(player.global_position)).is_equal_approx(190.0, 1.0)
		assert_float((b as EnemyBomb).flight_seconds).is_equal(1.5)
		assert_object((b as EnemyBomb).ground_texture).append_failure_message("a barrel sits on each ring").is_not_null()


func test_juggernaut_shrapnel_is_twelve_evenly_spaced_orbs_and_two_volleys_when_enraged() -> void:
	_target(Vector2(-3000, 0), &"tower", Hurtbox.Faction.TOWER)
	_target(Vector2(600, 0), &"player")
	var boss: EnemyController = _enemy(JuggernautScene, Vector2.ZERO)
	var jb: JuggernautBehavior = boss.behavior as JuggernautBehavior
	_advance(boss, 0.05)
	jb.set("_next", {"roll": 1000.0, "barrels": 1000.0, "shrapnel": _clock.now, "spin": 1000.0, "stomp": 1000.0})
	_advance(boss, 0.6)
	assert_int(_field().fired_total).is_equal(12)
	boss.death_state.apply_damage(boss.death_state.max_hp * 0.6, "test")
	jb.set("_next", {"roll": 1000.0, "barrels": 1000.0, "shrapnel": _clock.now, "spin": 1000.0, "stomp": 1000.0})
	_advance(boss, 1.0)
	assert_int(_field().fired_total).append_failure_message("enraged: 12 + 12 offset").is_equal(36)


# --- Goblin Shaman --------------------------------------------------------------------

func test_shaman_holds_range_and_casts_a_slow_three_orb_fan_that_hits_a_player_who_stays() -> void:
	var player: Node2D = _target(Vector2(320, 0), &"player")
	var shaman: EnemyController = _enemy(ShamanScene, Vector2.ZERO)
	var sb: ShamanBehavior = shaman.behavior as ShamanBehavior
	_advance(shaman, 3.6)
	assert_int(sb.casts_made).append_failure_message("first cast within one interval plus the wind-up").is_greater_equal(1)
	var f: EnemyBulletField = _field()
	assert_int(f.fired_total).is_equal(3 * sb.casts_made)
	assert_float(f.get_bullet_velocity(0).length()).append_failure_message("slow orbs").is_equal_approx(150.0, 0.01)
	_advance(shaman, 2.5)
	assert_array((player as Node).get("damage_log")).append_failure_message("the middle orb flies straight at a player who stays").contains([12.0])
	assert_float(shaman.global_position.distance_to(player.global_position)).is_between(270.0, 390.0)
