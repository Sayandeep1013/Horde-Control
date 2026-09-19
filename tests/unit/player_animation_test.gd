extends GdUnitTestSuite

## Code-driven player animation coverage for src/player/player_animator.gd
## (P2.1 task brief: "Animation matters here and must be code-driven ...
## Give it: a subtle idle bob, squash-and-stretch on acceleration and stop,
## a lean into the movement direction, and a hit flash."). Also covers
## pause-safety end to end through the real player scene (task brief: "no
## create_tween() on the tree -- use Node.create_tween() ... or hand-rolled
## interpolation on SimClock").
##
## The three continuous effects (bob, stretch, lean) are exercised directly
## against a standalone PlayerAnimator instance (unit-level, no Player/
## SimLoop dependency); the hit flash and the pause-freeze claim are
## exercised through the real scenes/player.tscn (integration-level),
## since pause-safety is a property of HOW player.gd drives this node
## (only from inside its own _physics_process, which the engine itself does
## not call while paused), not of PlayerAnimator in isolation.

const PlayerAnimatorScript: GDScript = preload("res://src/player/player_animator.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

const REFERENCE_SPEED: float = 320.0
const DELTA: float = 1.0 / 60.0

var _animator: PlayerAnimator
var _sprite: Sprite2D


func before_test() -> void:
	_animator = PlayerAnimatorScript.new()
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_animator.add_child(_sprite) # child exists BEFORE the animator enters the tree, so _ready() resolves sprite_path
	_animator.sprite_path = NodePath("Sprite2D")
	add_child(_animator)
	auto_free(_animator)


# --- Idle bob ----------------------------------------------------------------

func test_idle_bob_oscillates_while_stationary() -> void:
	var samples: Array[float] = []
	for _i in range(6):
		await get_tree().physics_frame # advances the real SimClock.now the bob reads
		_animator.update_visuals(DELTA, Vector2.ZERO, REFERENCE_SPEED)
		samples.append(_animator.position.y)

	var distinct: Dictionary = {}
	for s in samples:
		distinct[snappedf(s, 0.001)] = true
	assert_int(distinct.size()).append_failure_message("idle bob produced a constant position.y (%s) across 6 sampled ticks -- it is not oscillating" % str(samples)).is_greater(1)

	for s in samples:
		assert_float(absf(s)).append_failure_message("idle bob offset %f exceeded its configured amplitude %f" % [s, _animator.idle_bob_amplitude_px]).is_less_equal(_animator.idle_bob_amplitude_px + 0.01)


func test_idle_bob_fades_out_at_full_speed() -> void:
	for _i in range(6):
		await get_tree().physics_frame
		_animator.update_visuals(DELTA, Vector2(REFERENCE_SPEED, 0.0), REFERENCE_SPEED)
	assert_float(absf(_animator.position.y)).append_failure_message("idle bob did not fade out at full speed (position.y=%f) -- it should not fight the movement lean/stretch while actively moving" % _animator.position.y).is_less(0.05)


# --- Squash-and-stretch --------------------------------------------------

func test_stretches_along_motion_when_accelerating() -> void:
	_animator.update_visuals(DELTA, Vector2.ZERO, REFERENCE_SPEED) # establish a zero baseline for the acceleration delta
	_animator.update_visuals(DELTA, Vector2(REFERENCE_SPEED, 0.0), REFERENCE_SPEED) # a full jump in one tick == hard acceleration
	var s: Vector2 = _animator.get_current_scale_for_test()
	assert_float(s.y).append_failure_message("expected stretch (scale.y > 1.0) while accelerating hard, got scale=%s" % str(s)).is_greater(1.0)
	assert_float(s.x).append_failure_message("expected squash on the perpendicular axis (scale.x < 1.0) while stretching, got scale=%s" % str(s)).is_less(1.0)


func test_squashes_when_stopping() -> void:
	_animator.update_visuals(DELTA, Vector2(REFERENCE_SPEED, 0.0), REFERENCE_SPEED) # cruising at full speed, zero acceleration
	_animator.update_visuals(DELTA, Vector2(REFERENCE_SPEED, 0.0), REFERENCE_SPEED)
	_animator.update_visuals(DELTA, Vector2.ZERO, REFERENCE_SPEED) # a full stop in one tick == hard deceleration
	var s: Vector2 = _animator.get_current_scale_for_test()
	assert_float(s.y).append_failure_message("expected squash (scale.y < 1.0) while stopping hard, got scale=%s" % str(s)).is_less(1.0)


func test_scale_settles_back_to_neutral_at_steady_cruise() -> void:
	for _i in range(40):
		_animator.update_visuals(DELTA, Vector2(REFERENCE_SPEED, 0.0), REFERENCE_SPEED) # constant velocity every tick -- zero acceleration throughout
	var s: Vector2 = _animator.get_current_scale_for_test()
	assert_vector(s).append_failure_message("scale did not settle back to neutral (1,1) during a steady cruise with no acceleration, got %s" % str(s)).is_equal_approx(Vector2.ONE, Vector2(0.02, 0.02))


# --- Lean --------------------------------------------------------------------

func test_leans_into_rightward_movement() -> void:
	for _i in range(30):
		_animator.update_visuals(DELTA, Vector2(REFERENCE_SPEED, 0.0), REFERENCE_SPEED)
	assert_float(_animator.get_current_lean_for_test()).append_failure_message("expected a positive lean while moving right, got %f" % _animator.get_current_lean_for_test()).is_greater(0.0)


func test_leans_into_leftward_movement_the_opposite_way() -> void:
	for _i in range(30):
		_animator.update_visuals(DELTA, Vector2(-REFERENCE_SPEED, 0.0), REFERENCE_SPEED)
	assert_float(_animator.get_current_lean_for_test()).append_failure_message("expected a negative lean while moving left, got %f" % _animator.get_current_lean_for_test()).is_less(0.0)


func test_lean_never_exceeds_its_configured_maximum() -> void:
	for _i in range(60):
		_animator.update_visuals(DELTA, Vector2(REFERENCE_SPEED, 0.0), REFERENCE_SPEED)
	assert_float(absf(_animator.get_current_lean_for_test())).is_less_equal(_animator.max_lean_radians + 0.001)


# --- Hit flash (Node.create_tween(), cosmetic-only) -------------------------

func test_hit_flash_sets_flash_colour_immediately() -> void:
	_animator.play_hit_flash()
	assert_that(_sprite.modulate).append_failure_message("hit flash did not immediately set modulate to the flash colour").is_equal(_animator.hit_flash_color)


func test_hit_flash_reverts_to_base_modulate_after_it_finishes() -> void:
	var base: Color = _sprite.modulate
	_animator.play_hit_flash()
	await _animator._hit_tween.finished
	assert_bool(_sprite.modulate.is_equal_approx(base)).append_failure_message("hit flash did not revert to the base modulate (%s) after finishing, ended at %s" % [str(base), str(_sprite.modulate)]).is_true()


func test_a_second_rapid_hit_restarts_the_flash_instead_of_competing() -> void:
	_animator.play_hit_flash()
	var first_tween: Tween = _animator._hit_tween
	_animator.play_hit_flash()
	assert_bool(first_tween.is_valid()).append_failure_message("the first hit-flash tween must be killed when a second hit lands before it finishes, to avoid two tweens competing on the same modulate property").is_false()
	assert_that(_sprite.modulate).is_equal(_animator.hit_flash_color)


# --- Pause-safety, end to end through the real player scene -----------------

func test_continuous_effects_freeze_while_the_player_is_paused() -> void:
	var registry: Node = auto_free(EntityRegistryScript.new())
	add_child(registry)
	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	player.set_registry_for_test(registry)
	add_child(player)
	await get_tree().physics_frame

	player.set_input_direction_for_test(Vector2(1.0, 0.0))
	for _i in range(4):
		await get_tree().physics_frame

	var visuals: Node2D = player.get_node(player.animator_path)
	var scale_before_pause: Vector2 = visuals.scale
	var rotation_before_pause: float = visuals.rotation

	PauseAuthority.push_reason(&"debug")
	PauseAuthority.flush()
	assert_bool(get_tree().paused).is_true()

	for _i in range(5):
		await get_tree().physics_frame

	assert_vector(visuals.scale).append_failure_message("Visuals.scale changed while the player was paused -- continuous animation is not freezing under pause").is_equal(scale_before_pause)
	assert_float(visuals.rotation).append_failure_message("Visuals.rotation changed while the player was paused").is_equal(rotation_before_pause)

	PauseAuthority.pop_reason(&"debug")
	PauseAuthority.flush()
	assert_bool(get_tree().paused).is_false()

	player.clear_input_direction_override_for_test()


func test_hurtbox_damage_triggers_the_hit_flash_through_player() -> void:
	var registry: Node = auto_free(EntityRegistryScript.new())
	add_child(registry)
	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	player.set_registry_for_test(registry)
	add_child(player)
	await get_tree().physics_frame

	var sprite: CanvasItem = player.get_node(player.animator_path).get_node("Sprite2D")
	var base: Color = sprite.modulate

	var attacker: Hitbox = Hitbox.new()
	attacker.damage = 5.0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	attacker.add_child(shape)
	add_child(attacker)
	auto_free(attacker)
	attacker.owner_entity = attacker
	attacker.global_position = player.global_position + Vector2(100_000, 0)

	attacker.activate_window()
	await get_tree().physics_frame
	attacker.global_position = player.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_that(sprite.modulate).append_failure_message("taking damage through the real Hurtbox did not trigger the hit flash (sprite.modulate stayed %s, base was %s)" % [str(sprite.modulate), str(base)]).is_not_equal(base)
