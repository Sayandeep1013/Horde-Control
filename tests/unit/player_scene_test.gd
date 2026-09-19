extends GdUnitTestSuite

## Scene-wiring and contact-damage-receipt coverage for scenes/player.tscn +
## src/player/player.gd (P2.1). Verifies the scene, as built, actually
## matches what it claims (Phase 02 carried lesson: "Verify by reading the
## artifact back; a tool reporting success is not evidence" --
## tests/unit/main_scene_structure_test.gd applies the same discipline to
## scenes/main.tscn) rather than trusting the .tscn text alone: collision
## layers/masks/radii per docs/20 > Physics & Collisions ("Entity sizes",
## Collision Layers table), all sourced from data/player/prototype.tres at
## runtime, and the Logical Death wiring (hurtbox -> DeathState) P2.1's Plan
## row lists as in scope ("contact damage receipt ... death").

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

var _player: Player
var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)
	_player = auto_free(PlayerScene.instantiate()) as Player
	_player.set_registry_for_test(_registry)
	add_child(_player)
	await get_tree().physics_frame


# --- Structural shape -------------------------------------------------------

func test_player_root_is_character_body_2d_with_floating_motion_mode() -> void:
	assert_object(_player).is_not_null()
	assert_bool(_player is CharacterBody2D).is_true()
	assert_int(_player.motion_mode).append_failure_message("top-down player should use MOTION_MODE_FLOATING, not the default grounded mode (no floor/gravity concept for this game)").is_equal(CharacterBody2D.MOTION_MODE_FLOATING)


func test_player_z_index_matches_register_readability_row() -> void:
	# MASTER_SDLC.md > Provisional Values Register > Readability: "draw
	# order z_index: environment 0, pickups 10, enemies 20 ..., player 50,
	# damage numbers 60."
	assert_int(_player.z_index).is_equal(50)


func test_process_mode_is_pausable() -> void:
	assert_int(_player.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)


# --- Body -------------------------------------------------------------------

func test_body_collision_layer_and_mask_match_binding_table() -> void:
	assert_int(_player.collision_layer).is_equal(CollisionLayers.LAYER_PLAYER_BODY)
	assert_int(_player.collision_mask).is_equal(CollisionLayers.MASK_PLAYER_BODY)


func test_body_radius_is_read_from_definition() -> void:
	var body_shape: CollisionShape2D = _player.get_node(_player.body_shape_path)
	var circle: CircleShape2D = body_shape.shape as CircleShape2D
	assert_object(circle).is_not_null()
	assert_float(circle.radius).append_failure_message("body radius must be read from PlayerDefinition.body_radius_px (Register: 14), not hardcoded").is_equal(float(_player.definition.body_radius_px))
	assert_float(circle.radius).is_equal(14.0)


# --- Hurtbox (hurtbox_definition == SameAsBody) -----------------------------

func test_hurtbox_faction_layer_and_radius() -> void:
	assert_object(_player.hurtbox).is_not_null()
	assert_int(_player.hurtbox.faction).is_equal(Hurtbox.Faction.PLAYER)
	assert_int(_player.hurtbox.collision_layer).is_equal(CollisionLayers.LAYER_PLAYER_HURTBOX)
	assert_int(_player.hurtbox.collision_mask).append_failure_message("a hurtbox never scans -- collision_mask must stay 0").is_equal(0)
	assert_bool(_player.hurtbox.monitoring).is_false()
	assert_bool(_player.hurtbox.monitorable).is_true()

	var hurtbox_shape: CollisionShape2D = _player.get_node(_player.hurtbox_shape_path)
	var circle: CircleShape2D = hurtbox_shape.shape as CircleShape2D
	assert_float(circle.radius).append_failure_message("hurtbox_definition is SameAsBody -- hurtbox radius must equal body_radius_px").is_equal(float(_player.definition.body_radius_px))


# --- Collector ---------------------------------------------------------------

func test_collector_layer_mask_and_radius() -> void:
	assert_object(_player.collector).is_not_null()
	assert_int(_player.collector.collision_layer).is_equal(CollisionLayers.LAYER_PLAYER_COLLECTOR)
	assert_int(_player.collector.collision_mask).is_equal(CollisionLayers.MASK_PLAYER_COLLECTOR)
	assert_bool(_player.collector.monitoring).append_failure_message("PlayerCollector's binding-table row masks Pickup (12) -- unlike a Hurtbox, it must actually scan").is_true()

	var collector_shape: CollisionShape2D = _player.get_node(_player.collector_shape_path)
	var circle: CircleShape2D = collector_shape.shape as CircleShape2D
	assert_float(circle.radius).append_failure_message("collector radius must be read from PlayerDefinition.collector_area_radius_px (Register: body + 8 = 22)").is_equal(float(_player.definition.collector_area_radius_px))
	assert_float(circle.radius).is_equal(22.0)


func test_collector_emits_pickup_entered_on_overlap() -> void:
	var received: Dictionary = {"count": 0, "area": null}
	_player.collector.pickup_entered.connect(func(area: Area2D) -> void:
		received["count"] += 1
		received["area"] = area
	)

	var pickup_area: Area2D = auto_free(Area2D.new())
	pickup_area.collision_layer = CollisionLayers.LAYER_PICKUP
	pickup_area.collision_mask = 0
	pickup_area.monitorable = true
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	pickup_area.add_child(shape)
	add_child(pickup_area)

	pickup_area.global_position = _player.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(received["count"]).append_failure_message("Collector did not detect an overlapping Pickup-layer Area2D").is_greater(0)
	assert_object(received["area"]).is_same(pickup_area)


# --- DeathState (health, from the Register, not a hardcoded framework default) ---

func test_death_state_max_hp_and_current_hp_come_from_definition() -> void:
	assert_object(_player.death_state).is_not_null()
	assert_float(_player.death_state.max_hp).append_failure_message("DeathState.max_hp must be overwritten from PlayerDefinition.max_health (Register: 100), not left at death_state.gd's own 30.0 framework default").is_equal(float(_player.definition.max_health))
	assert_float(_player.death_state.current_hp).append_failure_message("current_hp must be resynced to the new max_hp (reset_for_reuse()), not stuck at whatever _ready() computed before max_hp was overwritten").is_equal(float(_player.definition.max_health))
	assert_float(_player.death_state.max_hp).is_equal(100.0)


func test_death_state_hitbox_paths_are_empty_player_has_no_hitbox() -> void:
	# The player deals no contact damage (Register: no PlayerHitbox row) --
	# weapons are out of this task's scope (PLAN.md P2.1 row: "dash and
	# weapons excluded").
	assert_array(_player.death_state.hitbox_paths).is_empty()


# --- Contact damage receipt (Plan row: "contact damage receipt ... death") --

func _build_attacking_hitbox() -> Hitbox:
	var hitbox: Hitbox = Hitbox.new()
	hitbox.damage = 15.0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	hitbox.add_child(shape)
	add_child(hitbox)
	auto_free(hitbox)
	return hitbox


func test_player_hurtbox_receives_damage_and_reduces_hp() -> void:
	var attacker: Hitbox = _build_attacking_hitbox()
	attacker.owner_entity = attacker
	attacker.global_position = _player.global_position + Vector2(100_000, 0) # far away first

	attacker.activate_window()
	await get_tree().physics_frame # let the deferred activation land

	attacker.global_position = _player.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	var expected_hp: float = float(_player.definition.max_health) - 15.0
	assert_float(_player.death_state.current_hp).append_failure_message("player HP did not decrease after an EnemyHitbox overlapped the player's Hurtbox -- contact damage receipt is not wired").is_equal_approx(expected_hp, 0.01)


func test_lethal_damage_kills_the_player() -> void:
	assert_bool(_player.is_dead()).is_false()
	var accepted: bool = _player.apply_damage(float(_player.definition.max_health) + 50.0, "test_lethal")
	assert_bool(accepted).is_true()
	assert_bool(_player.is_dead()).append_failure_message("apply_damage() past max_health did not register Logical Death on the player").is_true()
	assert_bool(_player.hurtbox.is_dead).append_failure_message("Logical Death must mark_dead() the player's own hurtbox synchronously").is_true()


func test_dead_player_hurtbox_discards_a_further_hit_ghost_hit_guard() -> void:
	_player.apply_damage(float(_player.definition.max_health) + 50.0, "test_lethal")
	var accepted_again: bool = _player.hurtbox.receive_hit(null, 10.0, "second_hit")
	assert_bool(accepted_again).append_failure_message("a hurtbox already marked dead accepted a second hit -- ghost-hit protection is broken for the player").is_false()
