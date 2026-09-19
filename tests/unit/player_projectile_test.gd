extends GdUnitTestSuite

## PlayerProjectile unit coverage (P2.3). Not itself the named "Weapon check"
## acceptance test (that lives in tests/unit/weapon_check_test.gd) -- this
## suite covers the projectile's own mechanics in isolation: Readability
## (Register > Interfaces), Projectile Orphans (docs/20), lifetime expiry,
## and the intersect_ray sweep this file's own header names as a deliberate
## departure from tower_projectile.gd's precedent (docs/20 > "Physics &
## Collisions").

const PlayerProjectileScript: GDScript = preload("res://src/combat/player_projectile.gd")
const HurtboxScript: GDScript = preload("res://src/combat/hurtbox.gd")

const REGISTER_MAX_OPACITY: float = 0.7
const REGISTER_Z_INDEX: int = 30


func _make_hurtbox(position: Vector2, radius: float) -> Hurtbox:
	var hurtbox: Hurtbox = auto_free(HurtboxScript.new()) as Hurtbox
	hurtbox.faction = Hurtbox.Faction.ENEMY
	add_child(hurtbox)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hurtbox.add_child(shape)
	hurtbox.global_position = position
	return hurtbox


func _make_projectile() -> PlayerProjectile:
	var projectile: PlayerProjectile = auto_free(PlayerProjectileScript.new()) as PlayerProjectile
	add_child(projectile)
	return projectile


# --- Readability (Register > Interfaces > "Readability") -------------------

func test_draws_at_z_index_30_and_at_most_70_percent_opacity() -> void:
	var projectile: PlayerProjectile = _make_projectile()
	assert_int(projectile.z_index).append_failure_message("player projectiles must draw at z_index 30 (Register > Interfaces > Readability)").is_equal(REGISTER_Z_INDEX)
	assert_float(projectile.modulate.a).append_failure_message("player projectiles must render at <= 70%% opacity (Register > Interfaces > Readability); got %.3f" % projectile.modulate.a).is_less_equal(REGISTER_MAX_OPACITY)


# --- Projectile Orphans: source resolved by value ---------------------------

func test_launch_source_is_a_value_not_a_live_node_reference() -> void:
	var hurtbox: Hurtbox = _make_hurtbox(Vector2(10, 0), 3.0)
	var projectile: PlayerProjectile = _make_projectile()
	var received: Dictionary = {"landed": false, "source": null}
	projectile.hit_landed.connect(func(_hb: Hurtbox, _dmg: float, source: Variant) -> void:
		received["landed"] = true
		received["source"] = source
	)

	# Let the hurtbox settle into the physics space before the projectile's
	# own first _physics_process (and therefore its first sweep) runs --
	# same reasoning as the sweep test below.
	await get_tree().physics_frame

	# &"player" (a StringName) is passed, never a Node -- see this file's
	# and player_projectile.gd's own header, "Projectile Orphans": the
	# damage source must be resolved by value at fire time so a freed/
	# destroyed shooter can never leave a dangling reference on an
	# in-flight projectile.
	projectile.launch(Vector2.ZERO, Vector2(1000, 0), 10.0, &"player", 1.0)

	var iterations: int = 0
	while not received["landed"] and iterations < 30:
		await get_tree().physics_frame
		iterations += 1

	assert_bool(received["landed"]).append_failure_message("projectile never registered a hit against the hurtbox").is_true()
	assert_bool(received["source"] is StringName).append_failure_message("damage source was not a value type (StringName) -- got %s" % typeof(received["source"])).is_true()
	assert_str(String(received["source"])).is_equal("player")


# --- Lifetime expiry (no target ever hit) -----------------------------------

func test_expires_after_its_lifetime_with_no_target_in_range() -> void:
	var projectile: PlayerProjectile = _make_projectile()
	var expired_state: Dictionary = {"expired": false}
	projectile.expired.connect(func(_p: PlayerProjectile) -> void: expired_state["expired"] = true)

	projectile.launch(Vector2.ZERO, Vector2(1000, 0), 10.0, &"player", 0.05) # short lifetime, empty space ahead

	var iterations: int = 0
	while not expired_state["expired"] and iterations < 60:
		await get_tree().physics_frame
		iterations += 1

	assert_bool(expired_state["expired"]).append_failure_message("projectile never self-expired after its lifetime elapsed with nothing to hit").is_true()


# --- The intersect_ray sweep: no tunnelling through a thin hurtbox ----------

func test_sweep_detects_a_hurtbox_the_projectile_would_otherwise_jump_over() -> void:
	# At 1000 px/s and a 60 Hz physics tick, one tick's travel is ~16.67 px.
	#
	# Falsification history, kept because it is instructive (see this task's
	# evidence report): the first version of this test used a 2 px hurtbox
	# at x=10 and disabling the sweep did NOT make it fail, because it
	# forgot that the PROJECTILE also has its own COLLISION_RADIUS_PX (6 px)
	# -- Godot's native, discrete, end-of-tick Area2D overlap check compares
	# the two shapes' actual circles, not point-to-point, so a hurtbox
	# radius 2 at x=10 already overlaps the projectile's end-of-tick centre
	# at x=16.67 once the projectile's own 6 px radius is added in
	# (distance 6.67 < 2+6=8) -- the native check alone already caught it,
	# proving nothing about the sweep specifically.
	#
	# This version places a MUCH smaller hurtbox (0.5 px) at x=8, so the
	# combined radius (0.5 + 6 = 6.5) is smaller than the tick's own travel
	# distance (~16.67 px) and neither tick boundary is within it: distance
	# from x=0 to x=8 is 8 (> 6.5, no native overlap at tick start), and
	# from x=16.67 to x=8 is 8.67 (> 6.5, no native overlap at tick end
	# either). The projectile's CENTRE path (the zero-width segment
	# intersect_ray actually queries) still passes directly through the
	# hurtbox's own tiny shape at x=8, so only a genuine swept query along
	# the whole segment (this file's own `_sweep_and_resolve()`) can catch
	# this hit -- this is exactly the tunnelling docs/20 > "Physics &
	# Collisions" describes, now actually isolated from the native check.
	var hurtbox: Hurtbox = _make_hurtbox(Vector2(8, 0), 0.5)
	var projectile: PlayerProjectile = _make_projectile()

	var received: Dictionary = {"landed": false}
	projectile.hit_landed.connect(func(_hb: Hurtbox, _dmg: float, _source: Variant) -> void: received["landed"] = true)

	# Let both nodes settle into the physics space before the projectile's
	# own first _physics_process (and therefore its first sweep) runs.
	await get_tree().physics_frame

	projectile.launch(Vector2(0, 0), Vector2(1000, 0), 10.0, &"player", 1.0)

	var iterations: int = 0
	while not received["landed"] and iterations < 10:
		await get_tree().physics_frame
		iterations += 1

	assert_bool(received["landed"]).append_failure_message("projectile tunnelled through a hurtbox smaller than one tick's travel distance instead of the intersect_ray sweep catching it (docs/20 > Physics & Collisions)").is_true()
	assert_bool(hurtbox.is_dead).append_failure_message("sanity: hurtbox should still be alive, this test is about detection, not damage resolution").is_false()


# --- No piercing: a hit deactivates the projectile immediately -------------

func test_a_hit_deactivates_the_projectile_so_it_cannot_hit_a_second_target() -> void:
	var near_hurtbox: Hurtbox = _make_hurtbox(Vector2(10, 0), 2.0)
	var far_hurtbox: Hurtbox = _make_hurtbox(Vector2(200, 0), 2.0)
	var projectile: PlayerProjectile = _make_projectile()

	var hits: Array = []
	projectile.hit_landed.connect(func(hb: Hurtbox, _dmg: float, _source: Variant) -> void: hits.append(hb))

	await get_tree().physics_frame
	projectile.launch(Vector2(0, 0), Vector2(1000, 0), 10.0, &"player", 1.0)

	for _i in 20:
		await get_tree().physics_frame

	assert_int(hits.size()).append_failure_message("projectile registered %d hits instead of exactly 1 -- no piercing, one target per shot (docs/20 > Physics & Collisions)" % hits.size()).is_equal(1)
	assert_object(hits[0]).append_failure_message("projectile pierced through to the farther hurtbox instead of stopping at the first (nearest) one it hit").is_same(near_hurtbox)
	assert_object(far_hurtbox).append_failure_message("sanity: the farther hurtbox must exist for this test to mean anything").is_not_null()
