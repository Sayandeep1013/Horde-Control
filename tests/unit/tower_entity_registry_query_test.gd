extends GdUnitTestSuite

## New coverage for LEDGER F03-26 (fixed): src/tower/tower.gd now registers
## itself with EntityRegistry under the &"tower" tag in _ready(), a query
## route ADDED alongside the pre-existing set_tower_reference()/tower_path
## paths (src/enemy/enemy_controller.gd, src/director/wave_director.gd) --
## this suite exercises only the new query route and does not touch either
## of the old ones, which remain untested here because they are unchanged.
##
## Fresh EntityRegistry instance per test (never the real Autoload
## singleton), injected via Tower.set_registry_for_test() BEFORE add_child()
## so the guarded assignment in Tower._ready() picks up the injected
## instance instead of the real one -- same convention as
## tests/unit/death_state_test.gd and death_state_player_died_test.gd.

const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)


func _build_tower() -> Node:
	var tower: Node = TowerScene.instantiate()
	tower.set_registry_for_test(_registry) # BEFORE add_child() -- see Tower._ready()'s own guard
	add_child(tower)
	auto_free(tower)
	return tower


func test_tower_registers_itself_under_the_tower_tag_on_ready() -> void:
	var tower: Node = _build_tower()
	assert_bool(_registry.is_registered(tower)).append_failure_message("Tower did not register itself with EntityRegistry in _ready() -- LEDGER F03-26 regression").is_true()
	assert_int(_registry.get_entity_count(&"tower")).is_equal(1)


func test_tower_is_findable_via_get_entities_in_radius_by_the_tower_tag() -> void:
	var tower: Node2D = _build_tower() as Node2D
	var found: Array[Node2D] = _registry.get_entities_in_radius(tower.global_position, 1.0, &"tower")
	assert_int(found.size()).append_failure_message("Tower was not findable via EntityRegistry.get_entities_in_radius() under its own position and the &\"tower\" tag").is_equal(1)
	assert_object(found[0]).is_same(tower)


func test_tower_is_findable_via_get_entities_with_tag() -> void:
	var tower: Node = _build_tower()
	var found: Array[Node2D] = _registry.get_entities_with_tag(&"tower")
	assert_int(found.size()).append_failure_message("Tower was not findable via EntityRegistry.get_entities_with_tag(&\"tower\")").is_equal(1)
	assert_object(found[0]).is_same(tower)


func test_a_query_for_an_unrelated_tag_does_not_find_the_tower() -> void:
	_build_tower()
	# Sanity: the Tower must not also, or instead, be findable under a tag
	# it never registered under -- the fix must add exactly one tag, not
	# make the Tower match every query indiscriminately.
	assert_int(_registry.get_entity_count(&"enemy")).is_equal(0)
	assert_int(_registry.get_entity_count(&"player")).is_equal(0)


func test_tower_deregisters_from_the_registry_when_freed() -> void:
	# Not wrapped in auto_free() here -- this test frees the Tower itself,
	# mid-test, matching tests/unit/attack_slot_manager_test.gd's own
	# "doomed" fixture convention (a node meant to be explicitly freed
	# during a test is never also handed to auto_free(), which would try to
	# free it a second time at teardown).
	var tower: Node = TowerScene.instantiate()
	tower.set_registry_for_test(_registry)
	add_child(tower)
	assert_bool(_registry.is_registered(tower)).is_true()

	tower.free()
	await get_tree().process_frame

	assert_int(_registry.get_entity_count(&"tower")).append_failure_message("Tower did not deregister from EntityRegistry on _exit_tree() -- a freed Tower would leave a stale slot behind").is_equal(0)
