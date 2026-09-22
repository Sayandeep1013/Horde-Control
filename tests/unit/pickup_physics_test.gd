extends GdUnitTestSuite

## Pickup physics test (P2.10; MASTER_SDLC.md > Acceptance Test Matrix >
## Technical Tests: "Pickups accelerate toward the player, stop while an
## enemy body blocks the magnet ray, and never pass through terrain.").
## Also covers the clauses feeding this task's own exit criterion ("blocked
## pickups stop instead of sliding") and the F03-27 visual-regression
## pattern (tests/unit/entity_visual_test.gd's own header) applied to the
## new pickup scene.
##
## Isolation matches entity_cap_test.gd / leash_test.gd: a fresh
## EntityRegistry and SimClock instance per test, injected via
## set_registry_for_test()/set_sim_clock_for_test(), never the real
## Autoload singletons -- so this suite's own player/enemy/terrain doubles
## cannot leak into any other suite in the same run.

const PickupScene: PackedScene = preload("res://scenes/pickups/pickup.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const XpShardDefinition: PickupDefinition = preload("res://data/pickups/xp_shard.tres")
const ScrapDefinition: PickupDefinition = preload("res://data/pickups/scrap.tres")

const PHYSICS_DELTA: float = 1.0 / 60.0

var _registry: Node
var _clock: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)
	_clock = auto_free(SimClockScript.new()) as Node
	add_child(_clock)


func _make_pickup(position: Vector2, definition: PickupDefinition = XpShardDefinition) -> Pickup:
	var pickup: Pickup = auto_free(PickupScene.instantiate()) as Pickup
	add_child(pickup)
	pickup.set_registry_for_test(_registry)
	pickup.set_sim_clock_for_test(_clock)
	pickup.driven_externally = true # only this suite's own physics_step() calls step it
	pickup.configure(definition, definition.value, position, 0)
	return pickup


func _make_player(position: Vector2) -> Node2D:
	var player: Node2D = auto_free(Node2D.new())
	add_child(player)
	player.global_position = position
	_registry.register_entity(player, position, [&"player"])
	return player


func _make_body(position: Vector2, layer: int, radius: float = 40.0) -> StaticBody2D:
	var body: StaticBody2D = auto_free(StaticBody2D.new())
	add_child(body)
	body.global_position = position
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	return body


# --- Visual (F03-27 pattern; tests/unit/entity_visual_test.gd's own header) -

func test_pickup_scene_renders_a_texture_even_before_configure() -> void:
	var pickup: Pickup = auto_free(PickupScene.instantiate()) as Pickup
	add_child(pickup)
	var sprite: Sprite2D = pickup.get_node_or_null("Sprite") as Sprite2D
	assert_object(sprite).append_failure_message("scenes/pickups/pickup.tscn has no Sprite node named 'Sprite'").is_not_null()
	assert_object(sprite.texture).append_failure_message("pickup.tscn's Sprite has no texture baked in -- a raw instantiation (before configure()) would render nothing, the exact F03-27 defect class").is_not_null()
	assert_int(sprite.texture.get_width()).is_greater(0)
	assert_int(sprite.texture.get_height()).is_greater(0)


## Art session: swapped from the flat Kenney icons to the crystal (XP) and
## the Tiny Swords gold pouch (Scrap) -- updated here rather than left
## asserting paths this task deliberately changed (CLAUDE.md: "if a test
## asserts on the old ... structure, update it minimally").
func test_configure_swaps_the_sprite_to_the_correct_per_type_icon() -> void:
	var xp_pickup: Pickup = _make_pickup(Vector2.ZERO, XpShardDefinition)
	var xp_sprite: Sprite2D = xp_pickup.get_node_or_null("Sprite") as Sprite2D
	assert_str(xp_sprite.texture.resource_path).contains("pickup_xp_crystal.png")

	var scrap_pickup: Pickup = _make_pickup(Vector2.ZERO, ScrapDefinition)
	var scrap_sprite: Sprite2D = scrap_pickup.get_node_or_null("Sprite") as Sprite2D
	assert_str(scrap_sprite.texture.resource_path).contains("G_Idle.png")


func test_z_index_is_10_per_readability_row() -> void:
	var pickup: Pickup = _make_pickup(Vector2.ZERO)
	assert_int(pickup.z_index).append_failure_message("Register > Interfaces > Readability: pickups draw at z_index 10").is_equal(10)


# --- "Never attracted does not simulate" ------------------------------------

func test_pickup_out_of_magnet_range_never_moves_or_attracts() -> void:
	_make_player(Vector2(5000, 0)) # far outside any plausible magnet radius
	var pickup: Pickup = _make_pickup(Vector2.ZERO)
	pickup.magnet_radius_px = 96.0

	for _i in 30:
		pickup.physics_step(PHYSICS_DELTA)

	assert_bool(pickup.is_attracted()).append_failure_message("pickup attracted despite the player never entering its magnet radius").is_false()
	assert_vector(pickup.global_position).append_failure_message("an unattracted pickup must not move at all").is_equal_approx(Vector2.ZERO, Vector2(0.001, 0.001))
	assert_float(pickup.get_current_speed_for_test()).is_equal(0.0)


# --- Acceleration toward the player ------------------------------------------

func test_pickup_accelerates_toward_the_player_once_in_range() -> void:
	_make_player(Vector2(1000, 0))
	var pickup: Pickup = _make_pickup(Vector2.ZERO)
	pickup.magnet_radius_px = 96.0 # player starts inside this radius (distance 1000 is NOT inside 96 -- see next line)

	# Move the player into range for the attraction check itself: the
	# registry query in physics_step() is what tests "in magnet radius", so
	# the player must actually be within it for attraction to begin.
	_registry.update_position(_registry.get_entities_with_tag(&"player")[0], Vector2(50, 0))

	pickup.physics_step(PHYSICS_DELTA)
	assert_bool(pickup.is_attracted()).append_failure_message("pickup did not attract with the player inside its magnet radius").is_true()

	# Register > Economy & Pickups > "Magnet radius / pickup motion":
	# initial 40 px/s, acceleration 900 px/s^2. First tick: 40 + 900*delta.
	var expected_speed_after_tick1: float = 40.0 + 900.0 * PHYSICS_DELTA
	assert_float(pickup.get_current_speed_for_test()).append_failure_message("speed after the first attracted tick did not match initial + acceleration*delta (Register > Economy & Pickups > magnet motion)").is_equal_approx(expected_speed_after_tick1, 0.01)

	var expected_position_after_tick1: float = expected_speed_after_tick1 * PHYSICS_DELTA
	assert_float(pickup.global_position.x).append_failure_message("pickup did not move toward the player by speed*delta on the attracted tick").is_equal_approx(expected_position_after_tick1, 0.05)

	var speed_after_tick1: float = pickup.get_current_speed_for_test()
	pickup.physics_step(PHYSICS_DELTA)
	assert_float(pickup.get_current_speed_for_test()).append_failure_message("speed did not keep increasing on a second unblocked, attracted tick").is_greater(speed_after_tick1)

	# Clamped at the Register's stated maximum (700 px/s) -- run enough
	# ticks to exceed it and confirm the clamp holds.
	for _i in 200:
		pickup.physics_step(PHYSICS_DELTA)
	assert_float(pickup.get_current_speed_for_test()).append_failure_message("speed exceeded the Register's stated maximum of 700 px/s").is_less_equal(700.0)


func test_attraction_is_sticky_even_after_the_player_leaves_range() -> void:
	var player: Node2D = _make_player(Vector2(50, 0))
	var pickup: Pickup = _make_pickup(Vector2.ZERO)
	pickup.magnet_radius_px = 96.0

	pickup.physics_step(PHYSICS_DELTA)
	assert_bool(pickup.is_attracted()).is_true()

	# Player leaves the magnet radius entirely.
	_registry.update_position(player, Vector2(5000, 0))
	var position_before: Vector2 = pickup.global_position
	pickup.physics_step(PHYSICS_DELTA)

	assert_bool(pickup.is_attracted()).append_failure_message("Register: once attracted a pickup stays attracted (sticky) even if the player leaves range").is_true()
	assert_vector(pickup.global_position).append_failure_message("a sticky, attracted pickup must keep chasing the player even outside the magnet radius").is_not_equal(position_before)


# --- Blocking: stop, do not slide --------------------------------------------

func test_enemy_body_blocks_the_magnet_ray_and_the_pickup_holds_position() -> void:
	_make_player(Vector2(50, 0))
	var pickup: Pickup = _make_pickup(Vector2(-200, 0))
	pickup.magnet_radius_px = 500.0
	_make_body(Vector2(-75, 0), CollisionLayers.LAYER_ENEMY_BODY, 40.0) # sits on the segment between the pickup and the player

	await get_tree().physics_frame # let the blocker's shape register with the physics server

	pickup.physics_step(PHYSICS_DELTA) # first tick: attracts
	assert_bool(pickup.is_attracted()).is_true()
	var position_after_first_tick: Vector2 = pickup.global_position

	for _i in 30:
		pickup.physics_step(PHYSICS_DELTA)

	assert_bool(pickup.is_blocked_for_test()).append_failure_message("pickup did not detect the EnemyBody-layer blocker on its magnet raycast").is_true()
	assert_vector(pickup.global_position).append_failure_message("a blocked pickup moved instead of holding its position -- it must stop, not slide, while the ray is blocked (Register > Pickup Physics & Magnet Rules > Blocking)").is_equal_approx(position_after_first_tick, Vector2(0.001, 0.001))


func test_pickup_resumes_the_instant_the_blocking_ray_clears() -> void:
	_make_player(Vector2(50, 0))
	var pickup: Pickup = _make_pickup(Vector2(-200, 0))
	pickup.magnet_radius_px = 500.0
	var blocker: StaticBody2D = _make_body(Vector2(-75, 0), CollisionLayers.LAYER_ENEMY_BODY, 40.0)

	await get_tree().physics_frame
	pickup.physics_step(PHYSICS_DELTA)
	for _i in 10:
		pickup.physics_step(PHYSICS_DELTA)
	var blocked_position: Vector2 = pickup.global_position
	assert_bool(pickup.is_blocked_for_test()).is_true()

	blocker.queue_free()
	await get_tree().physics_frame

	pickup.physics_step(PHYSICS_DELTA)
	assert_bool(pickup.is_blocked_for_test()).append_failure_message("pickup still reports blocked after the obstacle was removed").is_false()
	assert_vector(pickup.global_position).append_failure_message("pickup did not resume moving once the ray cleared").is_not_equal(blocked_position)


func test_pickup_never_passes_through_terrain() -> void:
	_make_player(Vector2(50, 0))
	var pickup: Pickup = _make_pickup(Vector2(-200, 0))
	pickup.magnet_radius_px = 500.0
	_make_body(Vector2(-75, 0), CollisionLayers.LAYER_WORLD, 40.0) # terrain between the pickup and the player

	await get_tree().physics_frame
	pickup.physics_step(PHYSICS_DELTA)
	var position_after_first_tick: Vector2 = pickup.global_position

	for _i in 30:
		pickup.physics_step(PHYSICS_DELTA)

	assert_vector(pickup.global_position).append_failure_message("pickup passed through a World-layer terrain body instead of being blocked by it (named acceptance test: 'never pass through terrain')").is_equal_approx(position_after_first_tick, Vector2(0.001, 0.001))


# --- Lifetime -----------------------------------------------------------------

func test_pickup_expires_after_its_lifetime() -> void:
	var pickup: Pickup = _make_pickup(Vector2.ZERO)
	assert_bool(pickup.is_expired()).is_false()
	_clock.now = 60.0 # Register > Economy & Pickups > "Pickup lifetime": 60 s
	assert_bool(pickup.is_expired()).append_failure_message("pickup did not report expired at its 60 s lifetime").is_true()


func test_pickup_blinks_during_the_last_5_seconds_of_its_lifetime() -> void:
	var pickup: Pickup = _make_pickup(Vector2.ZERO)
	_clock.now = 56.0 # inside the last 5 s (lifetime 60 s)
	var alphas: Array[float] = []
	for _i in 40:
		pickup.physics_step(PHYSICS_DELTA)
		alphas.append(pickup.modulate.a)
		_clock.now += PHYSICS_DELTA
	assert_bool(alphas.any(func(a: float) -> bool: return a < 1.0)).append_failure_message("pickup never dimmed during its stated 5 s blink window (Register > Pickup lifetime)").is_true()
