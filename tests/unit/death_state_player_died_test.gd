extends GdUnitTestSuite

## New coverage for LEDGER F03-06 (fixed): src/combat/death_state.gd's
## `_enter_logical_death()` now emits `EventBus.player_died` (never
## `enemy_died`) when the dying entity is registered under EntityRegistry's
## `&"player"` tag -- and keeps emitting `enemy_died` for everything else,
## including an entity tagged `&"enemy"` and an entity never registered at
## all (matching every fixture in tests/unit/death_state_test.gd, which
## this suite deliberately does not modify -- it is out of this task's
## write scope and its own assertions must keep passing unchanged).
##
## Fresh EntityRegistry/EventBus instances per test, matching
## death_state_test.gd's and event_bus_test.gd's own isolation convention.
## Skill-vs-project conflict, recorded per CLAUDE.md: godot-prompter's
## event-bus skill's own "Testing" section says to test against the real
## Autoload EventBus, "not a fresh instance" -- this project's established
## convention (every EventBus/EntityRegistry-consuming suite in this repo)
## builds a fresh instance per test instead, and that convention wins.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const EventBusScript: GDScript = preload("res://src/core/event_bus.gd")
const HurtboxScript: GDScript = preload("res://src/combat/hurtbox.gd")

var _registry: Node
var _bus: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	_bus = auto_free(EventBusScript.new()) as Node
	add_child(_registry)
	add_child(_bus)


## Builds one CharacterBody2D + Hurtbox + DeathState fixture, matching
## death_state_test.gd's own `_build_entity()` shape (hurtbox only -- no
## hitbox needed for this suite's assertions). `tags`, if non-empty,
## registers the body with `_registry` under those tags BEFORE any damage
## is applied; an empty array leaves the body unregistered entirely, the
## same "never registered" case death_state_test.gd's own fixtures exercise.
func _build_entity(tags: Array) -> Dictionary:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.add_to_group(&"pool_body")
	body.collision_layer = CollisionLayers.LAYER_ENEMY_BODY
	body.collision_mask = CollisionLayers.MASK_ENEMY_BODY_GROUND

	var hurtbox: Hurtbox = HurtboxScript.new() as Hurtbox
	var hurtbox_shape: CollisionShape2D = CollisionShape2D.new()
	var hurtbox_circle: CircleShape2D = CircleShape2D.new()
	hurtbox_circle.radius = 14.0
	hurtbox_shape.shape = hurtbox_circle
	hurtbox.add_child(hurtbox_shape)
	hurtbox.name = "Hurtbox"
	body.add_child(hurtbox)

	var death_state: DeathState = DeathState.new()
	death_state.hurtbox_paths = [NodePath("../Hurtbox")]
	death_state.body_path = NodePath("..")
	death_state.registry_entity_path = NodePath("..")
	body.add_child(death_state)

	add_child(body)
	auto_free(body)

	death_state.set_registry_for_test(_registry)
	death_state.set_event_bus_for_test(_bus)

	if not tags.is_empty():
		_registry.register_entity(body, body.global_position, tags)

	return {"body": body, "death_state": death_state}


func _watch_bus() -> Dictionary:
	var seen: Dictionary = {"player_died": 0, "enemy_died": 0, "player_died_entity": null, "enemy_died_entity": null}
	_bus.player_died.connect(func(entity: Node2D, _position: Vector2, _timestamp: float) -> void:
		seen["player_died"] += 1
		seen["player_died_entity"] = entity
	)
	_bus.enemy_died.connect(func(entity: Node2D, _position: Vector2, _timestamp: float) -> void:
		seen["enemy_died"] += 1
		seen["enemy_died_entity"] = entity
	)
	return seen


# --- The fix: a &"player"-tagged entity emits player_died, never enemy_died --

func test_player_tagged_entity_emits_player_died_and_not_enemy_died() -> void:
	var f: Dictionary = _build_entity([&"player"])
	var ds: DeathState = f["death_state"]
	var body: CharacterBody2D = f["body"]
	body.global_position = Vector2(3, 4)
	var seen: Dictionary = _watch_bus()

	var before_now: float = SimClock.now
	ds.apply_damage(ds.max_hp + 500.0, "test")

	assert_int(seen["player_died"]).append_failure_message("player_died was not emitted exactly once for a &\"player\"-tagged entity's death").is_equal(1)
	assert_int(seen["enemy_died"]).append_failure_message("enemy_died was ALSO emitted for the player's own death -- LEDGER F03-06 regression: the player's death is being counted as an enemy kill").is_equal(0)
	assert_object(seen["player_died_entity"]).is_same(body)


func test_player_died_carries_the_same_shape_as_enemy_died() -> void:
	var f: Dictionary = _build_entity([&"player"])
	var ds: DeathState = f["death_state"]
	var body: CharacterBody2D = f["body"]
	body.global_position = Vector2(42, 7)

	var received: Array = []
	_bus.player_died.connect(func(entity: Node2D, position: Vector2, timestamp: float) -> void:
		received.append([entity, position, timestamp])
	)

	var before_now: float = SimClock.now
	ds.apply_damage(ds.max_hp + 500.0, "test")

	assert_int(received.size()).is_equal(1)
	assert_object(received[0][0]).is_same(body)
	assert_vector(received[0][1]).is_equal(Vector2(42, 7))
	assert_float(received[0][2]).is_equal_approx(before_now, 0.001)


# --- Everything else keeps emitting enemy_died, unchanged -------------------

func test_enemy_tagged_entity_still_emits_enemy_died_and_not_player_died() -> void:
	var f: Dictionary = _build_entity([&"enemy"])
	var ds: DeathState = f["death_state"]
	var body: CharacterBody2D = f["body"]
	var seen: Dictionary = _watch_bus()

	ds.apply_damage(ds.max_hp + 500.0, "test")

	assert_int(seen["enemy_died"]).append_failure_message("an &\"enemy\"-tagged entity's death did not emit enemy_died").is_equal(1)
	assert_int(seen["player_died"]).append_failure_message("an &\"enemy\"-tagged entity's death incorrectly emitted player_died").is_equal(0)
	assert_object(seen["enemy_died_entity"]).is_same(body)


func test_unregistered_entity_still_emits_enemy_died_and_not_player_died() -> void:
	# Matches every fixture in tests/unit/death_state_test.gd: never
	# registered with EntityRegistry at all. This is the exact case the fix
	# must not regress -- see this file's header.
	var f: Dictionary = _build_entity([])
	var ds: DeathState = f["death_state"]
	var body: CharacterBody2D = f["body"]
	var seen: Dictionary = _watch_bus()

	assert_bool(_registry.is_registered(body)).append_failure_message("test setup error: this fixture must be unregistered").is_false()

	ds.apply_damage(ds.max_hp + 500.0, "test")

	assert_int(seen["enemy_died"]).append_failure_message("an unregistered entity's death did not fall back to enemy_died -- this would break every existing death_state_test.gd fixture").is_equal(1)
	assert_int(seen["player_died"]).append_failure_message("an unregistered entity's death incorrectly emitted player_died").is_equal(0)
