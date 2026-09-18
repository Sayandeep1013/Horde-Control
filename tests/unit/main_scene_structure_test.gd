extends GdUnitTestSuite

## Verification (not one of the two named P1.3 acceptance tests, but Phase
## 02 carried lesson 5: "Verify by reading the artifact back; a tool
## reporting success is not evidence") that scenes/main.tscn, as built,
## actually matches docs/20_Technical_Architecture.md > Godot 4.x
## Implementation Standards > "Scene Tree": the named container list, the
## z_index draw order, y_sort_enabled on Entities only, and "Nothing under
## the gameplay root may set PROCESS_MODE_ALWAYS."

const MainScene: PackedScene = preload("res://scenes/main.tscn")

var _main: Node


func before_test() -> void:
	_main = auto_free(MainScene.instantiate()) as Node
	add_child(_main)


func test_gameplay_root_is_pausable() -> void:
	assert_int(_main.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)


func test_all_six_named_containers_exist() -> void:
	for name in ["Entities", "Projectiles", "Pickups", "Effects", "Environment", "Audio"]:
		assert_object(_main.get_node_or_null(name)).append_failure_message("missing gameplay-root container: %s" % name).is_not_null()


func test_entities_is_y_sorted_and_others_are_not() -> void:
	assert_bool(_main.get_node("Entities").y_sort_enabled).is_true()
	for name in ["Projectiles", "Pickups", "Effects", "Environment"]:
		var n: Node2D = _main.get_node(name)
		assert_bool(n.y_sort_enabled).append_failure_message("%s must not be y-sorted; only Entities is (docs/20 > Scene Tree)" % name).is_false()


func test_container_z_index_matches_docs_20_draw_order() -> void:
	# docs/20 > Scene Tree: "environment 0, pickups 10, enemies 20 (Y-sorted
	# among themselves), Tower 25, player projectiles 30 ..., effects 35,
	# telegraphs 40, player 50, damage numbers 60." Environment/Pickups/
	# Entities/Projectiles map 1:1 to one z-band each and are set on the
	# container itself; Effects hosts three different bands (35/40/60) that
	# do not share one value, so it is left at 0 and each instance spawned
	# into it must set its own absolute z_index (P1.3 evidence report).
	assert_int((_main.get_node("Environment") as Node2D).z_index).is_equal(0)
	assert_int((_main.get_node("Pickups") as Node2D).z_index).is_equal(10)
	assert_int((_main.get_node("Entities") as Node2D).z_index).is_equal(20)
	assert_int((_main.get_node("Projectiles") as Node2D).z_index).is_equal(30)
	assert_int((_main.get_node("Effects") as Node2D).z_index).is_equal(0)


func test_nothing_under_the_gameplay_root_is_process_mode_always() -> void:
	var offenders: Array[String] = _find_process_mode_always(_main, "")
	assert_array(offenders).append_failure_message(
		"nodes under the gameplay root set PROCESS_MODE_ALWAYS, banned by docs/20 > Scene Tree: %s" % str(offenders)
	).is_empty()


func _find_process_mode_always(node: Node, path: String) -> Array[String]:
	var out: Array[String] = []
	var here: String = path + "/" + node.name
	if node.process_mode == Node.PROCESS_MODE_ALWAYS:
		out.append(here)
	for child in node.get_children():
		out.append_array(_find_process_mode_always(child, here))
	return out


func test_sim_loop_is_present_under_the_gameplay_root() -> void:
	var sim_loop: Node = _main.get_node_or_null("SimLoop")
	assert_object(sim_loop).append_failure_message("SimLoop must live under the gameplay root (LEDGER F02-06); no such node found").is_not_null()
	assert_int(sim_loop.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)


func test_entity_spawner_is_wired_to_all_four_pooled_containers() -> void:
	var spawner: Node = _main.get_node_or_null("EntitySpawner")
	assert_object(spawner).is_not_null()
	# A live spawn/despawn round trip through each of the four registry-
	# wired categories confirms the exported NodePaths actually resolved
	# to real containers, not merely that the properties are non-empty
	# strings.
	var e: Node2D = spawner.spawn_enemy(Vector2.ZERO)
	assert_object(e.get_parent()).is_same(_main.get_node("Entities"))
	spawner.despawn_enemy(e)

	var pr: Node2D = spawner.spawn_projectile(Vector2.ZERO)
	assert_object(pr.get_parent()).is_same(_main.get_node("Projectiles"))
	spawner.despawn_projectile(pr)

	var pk: Node2D = spawner.spawn_pickup(Vector2.ZERO)
	assert_object(pk.get_parent()).is_same(_main.get_node("Pickups"))
	spawner.despawn_pickup(pk)

	var dn: Node2D = spawner.spawn_damage_number()
	assert_object(dn.get_parent()).is_same(_main.get_node("Effects"))
	spawner.despawn_damage_number(dn)

	spawner.clear_all_for_test()


func test_player_would_not_be_placed_inside_entities_container() -> void:
	# docs/20 > Scene Tree: "The player is not a child of Entities and is
	# not part of that Y-sort group." No Player node exists yet (P2.1); this
	# asserts the structural precondition that makes that rule satisfiable:
	# Entities is a sibling of Main's other direct children, not a
	# catch-all parent for the whole gameplay root.
	var entities: Node = _main.get_node("Entities")
	assert_object(entities.get_parent()).is_same(_main)
	assert_int(_main.get_child_count()).is_greater(1)
