extends GdUnitTestSuite

## New coverage for LEDGER F03-17 (fixed): src/tower/tower_projectile.gd's
## own intersect_ray sweep, added by this task to close the gap docs/20 >
## "Physics & Collisions" names against the Tower's own 900 px/s projectile
## by name ("even the Tower's slowest, at 900 px/s, covers 15 px per
## tick"). Mirrors tests/unit/player_projectile_test.gd's own sweep test
## structure and its documented falsification history exactly, adapted to
## this projectile's speed (900 px/s = 15 px/tick, not 1000 px/s).
##
## LEDGER F03-17's own text warns that a first attempt at this test can
## pass even with NO sweep at all, if the target hurtbox's radius is large
## enough that the projectile's own COLLISION_RADIUS_PX (6 px) plus that
## radius already overlaps at one of the two tick-boundary positions --
## Godot's native, discrete, end-of-tick Area2D overlap check would then
## catch the hit on its own, proving nothing about the sweep. This test's
## geometry is chosen specifically to defeat that: a target hurtbox with a
## tiny 0.5 px radius sits at x=7.5, the exact MIDPOINT of one tick's 15 px
## travel (from x=0 to x=15). Combined radius is 6.5 px; the distance from
## either tick boundary (x=0 or x=15) to the target's centre is 7.5 px --
## greater than 6.5 at BOTH ends, so neither the tick-start nor the
## tick-end position overlaps the target under a plain radius check. Only a
## genuine swept query along the whole segment -- which passes directly
## through the target's centre at its midpoint -- can catch this hit.

const TowerProjectileScript: GDScript = preload("res://src/tower/tower_projectile.gd")
const HurtboxScript: GDScript = preload("res://src/combat/hurtbox.gd")

const TOWER_PROJECTILE_SPEED_PX_S: float = 900.0 # Register > Tower: "projectile 900 px/s" -- read here only to derive the test's own travel-distance geometry, never fed back into the projectile as a literal.


func _make_hurtbox(position: Vector2, radius: float) -> Hurtbox:
	var hurtbox: Hurtbox = auto_free(HurtboxScript.new()) as Hurtbox
	hurtbox.faction = Hurtbox.Faction.ENEMY # LAYER_ENEMY_HURTBOX (9) -- the one layer MASK_TOWER_PROJECTILE actually scans for a Hurtbox hit
	add_child(hurtbox)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hurtbox.add_child(shape)
	hurtbox.global_position = position
	return hurtbox


func _make_projectile() -> TowerProjectile:
	var projectile: TowerProjectile = auto_free(TowerProjectileScript.new()) as TowerProjectile
	add_child(projectile)
	return projectile


# --- The intersect_ray sweep: no tunnelling through a thin hurtbox ---------

func test_sweep_detects_a_hurtbox_the_projectile_would_otherwise_jump_over() -> void:
	# See this file's header for the full geometry reasoning: a 0.5 px
	# hurtbox sits at the exact midpoint (x=7.5) of one tick's 15 px travel
	# (900 px/s / 60 Hz), so neither tick boundary's discrete overlap check
	# (6 px projectile radius + 0.5 px hurtbox radius = 6.5, versus a 7.5 px
	# distance at both x=0 and x=15) can catch this hit without the sweep.
	var hurtbox: Hurtbox = _make_hurtbox(Vector2(7.5, 0), 0.5)
	var projectile: TowerProjectile = _make_projectile()

	var received: Dictionary = {"landed": false}
	projectile.hit_landed.connect(func(_hb: Hurtbox, _dmg: float, _source: Variant) -> void: received["landed"] = true)

	# Let both nodes settle into the physics space before the projectile's
	# own first _physics_process (and therefore its first sweep) runs --
	# matching player_projectile_test.gd's own settle-frame convention.
	await get_tree().physics_frame

	projectile.launch(Vector2(0, 0), Vector2(TOWER_PROJECTILE_SPEED_PX_S, 0), 20.0, &"tower", 1.0)

	var iterations: int = 0
	while not received["landed"] and iterations < 10:
		await get_tree().physics_frame
		iterations += 1

	assert_bool(received["landed"]).append_failure_message("Tower projectile tunnelled through a hurtbox smaller than one tick's travel distance instead of the intersect_ray sweep catching it (docs/20 > Physics & Collisions; LEDGER F03-17)").is_true()
	assert_bool(hurtbox.is_dead).append_failure_message("sanity: hurtbox should still be alive, this test is about detection, not damage resolution").is_false()


func test_sweep_does_not_false_positive_when_nothing_is_on_the_path() -> void:
	# Sanity/negative counterpart: the same speed and lifetime, but no
	# hurtbox anywhere near the path -- the projectile must simply expire
	# after its lifetime, never spuriously report a hit.
	var projectile: TowerProjectile = _make_projectile()
	var expired_state: Dictionary = {"expired": false}
	var landed_state: Dictionary = {"landed": false}
	projectile.expired.connect(func(_p: TowerProjectile) -> void: expired_state["expired"] = true)
	projectile.hit_landed.connect(func(_hb: Hurtbox, _dmg: float, _source: Variant) -> void: landed_state["landed"] = true)

	projectile.launch(Vector2.ZERO, Vector2(TOWER_PROJECTILE_SPEED_PX_S, 0), 20.0, &"tower", 0.05)

	var iterations: int = 0
	while not expired_state["expired"] and iterations < 60:
		await get_tree().physics_frame
		iterations += 1

	assert_bool(expired_state["expired"]).append_failure_message("Tower projectile never self-expired after its lifetime elapsed with nothing to hit").is_true()
	assert_bool(landed_state["landed"]).append_failure_message("Tower projectile reported a hit with no hurtbox anywhere near its path").is_false()


# --- Existing behaviour preserved: no piercing, damage/lifetime intact ----

func test_a_hit_still_deactivates_the_projectile_so_it_cannot_hit_a_second_target() -> void:
	var near_hurtbox: Hurtbox = _make_hurtbox(Vector2(10, 0), 2.0)
	var far_hurtbox: Hurtbox = _make_hurtbox(Vector2(200, 0), 2.0)
	var projectile: TowerProjectile = _make_projectile()

	var hits: Array = []
	projectile.hit_landed.connect(func(hb: Hurtbox, _dmg: float, _source: Variant) -> void: hits.append(hb))

	await get_tree().physics_frame
	projectile.launch(Vector2(0, 0), Vector2(TOWER_PROJECTILE_SPEED_PX_S, 0), 20.0, &"tower", 1.0)

	for _i in 20:
		await get_tree().physics_frame

	assert_int(hits.size()).append_failure_message("Tower projectile registered %d hits instead of exactly 1 -- no piercing, one target per shot (docs/20 > Physics & Collisions)" % hits.size()).is_equal(1)
	assert_object(hits[0]).append_failure_message("Tower projectile pierced through to the farther hurtbox instead of stopping at the first (nearest) one it hit").is_same(near_hurtbox)
	assert_object(far_hurtbox).append_failure_message("sanity: the farther hurtbox must exist for this test to mean anything").is_not_null()


func test_launch_still_deals_the_damage_amount_it_was_given() -> void:
	var hurtbox: Hurtbox = _make_hurtbox(Vector2(7.5, 0), 0.5)
	var projectile: TowerProjectile = _make_projectile()

	var received_damage: Dictionary = {"amount": -1.0}
	hurtbox.damage_received.connect(func(amount: float, _source: Variant, _hitbox: Node) -> void: received_damage["amount"] = amount)

	await get_tree().physics_frame
	projectile.launch(Vector2(0, 0), Vector2(TOWER_PROJECTILE_SPEED_PX_S, 0), 20.0, &"tower", 1.0)

	var iterations: int = 0
	while received_damage["amount"] < 0.0 and iterations < 10:
		await get_tree().physics_frame
		iterations += 1

	assert_float(received_damage["amount"]).append_failure_message("Tower projectile's sweep-resolved hit did not carry the damage amount launch() was given").is_equal(20.0)
