extends GdUnitTestSuite

## Does the assembled prototype scene actually PRODUCE waves?
##
## The Wave Director has its own suites covering ring geometry, the wave
## sequence and determinism, and they pass against the director in
## isolation. That is not the same claim as "the scene a human launches
## spawns enemies", and this project has now been bitten twice by exactly
## that gap: F03-27 (three enemies with no sprite, 353 tests green) and
## F03-32 (the Tower rendered at a quarter of its collider, every test
## green). Both were wiring defects in the assembled scene that every
## component-level suite was blind to by construction.
##
## So this suite asserts the seam itself: the director is present in the
## scene, its NodePaths resolve to the real spawner, Tower and camera, its
## three enemy scenes are assigned, and -- the part that matters -- running
## the scene for a short stretch of simulation actually puts new enemies in
## the EntityRegistry that were not there at frame zero.

const PrototypeScene: PackedScene = preload("res://scenes/prototype.tscn")

## The prototype scene places one enemy per intent by hand, as P2.7's feel
## check defines. Anything above this count came from the director.
const HAND_PLACED_ENEMY_COUNT: int = 3

var _root: Node


func before_test() -> void:
	_root = auto_free(PrototypeScene.instantiate())
	add_child(_root)


func after_test() -> void:
	# Clear the pools: released instances are kept alive but out of the scene
	# tree, which is what pooling is for and is also Godot's definition of an
	# orphan, so freeing them here keeps the count honest.
	#
	# MEASURED, not assumed. An earlier version of this teardown blamed
	# pooling for ~2000 orphans and cleared the pools to fix it; clearing them
	# moved the count from 2016 to 1928, which disproved that explanation.
	# The real cause was the remove_child() this teardown also did (see the
	# note below): detaching the root made every descendant an orphan at the
	# instant gdUnit4 counted. Dropping remove_child() took the count to
	# ZERO. Both notes are kept because the wrong one was plausible enough to
	# have been written up as the cause without the second experiment.
	if is_instance_valid(_root):
		var spawner: Node = _root.get_node_or_null("Main/EntitySpawner")
		if spawner != null and spawner.has_method("clear_all_for_test"):
			spawner.clear_all_for_test()
	# NOTE: deliberately no remove_child() here. Detaching the root makes every
	# descendant an orphan at the instant gdUnit4 counts them, which reported
	# ~370 orphans from the very first test -- one that only instantiates the
	# scene and asserts a node exists. auto_free() in before_test() already
	# frees the whole tree at test end; removing it first only hides it from
	# the tree while gdUnit4 is looking.


func _director() -> Node:
	return _root.get_node_or_null("Main/WaveDirector")


func test_the_director_is_in_the_scene_at_all() -> void:
	assert_object(_director()).append_failure_message(
		"scenes/prototype.tscn has no Main/WaveDirector. The director can be "
		+ "perfectly correct and still never run if nothing instances it - "
		+ "which is exactly how the enemies ended up invisible in F03-27."
	).is_not_null()


func test_the_directors_node_paths_resolve_to_real_nodes() -> void:
	var d: Node = _director()
	assert_object(d).is_not_null()
	for prop in ["entity_spawner_path", "tower_path", "camera_path"]:
		var path: NodePath = d.get(prop)
		assert_bool(path.is_empty()).append_failure_message(
			"WaveDirector.%s is unset" % prop
		).is_false()
		assert_object(d.get_node_or_null(path)).append_failure_message(
			"WaveDirector.%s = '%s' resolves to nothing. A NodePath that misses "
			% [prop, path]
			+ "fails silently at runtime - the director simply never finds its "
			+ "spawner or its camera and quietly spawns nothing, or spawns "
			+ "without the camera-exclusion check the Register requires."
		).is_not_null()


func test_the_three_enemy_scenes_are_supplied_to_the_director() -> void:
	var d: Node = _director()
	for prop in ["tower_seeker_scene", "player_hunter_scene", "opportunist_scene"]:
		var packed: PackedScene = d.get(prop) as PackedScene
		assert_object(packed).append_failure_message(
			"WaveDirector.%s is null; the director would have nothing to spawn "
			% prop + "for that intent and the wave would silently come up short."
		).is_not_null()
		# auto_free: instantiate() with nothing freeing the result is itself an
		# orphan, and a suite that leaks while checking for leaks is noise.
		assert_object(auto_free(packed.instantiate())).append_failure_message(
			"WaveDirector.%s does not instantiate" % prop
		).is_not_null()


func test_running_the_scene_actually_spawns_enemies_beyond_the_hand_placed_three() -> void:
	var registry: Node = get_node_or_null("/root/EntityRegistry")
	assert_object(registry).append_failure_message(
		"EntityRegistry autoload missing; cannot count live enemies"
	).is_not_null()

	var at_start: int = registry.get_live_enemy_count()

	# T1's first spawn group is Hunters at a 0 s offset (Register > Encounter
	# Budgets > "T1"), so a short run is enough. Physics frames are awaited
	# rather than a wall-clock wait, because every wave deadline is on
	# SimClock and a wall-clock wait would prove nothing about tick timing.
	for _i in range(150):
		await get_tree().physics_frame

	var after: int = registry.get_live_enemy_count()
	assert_int(after).append_failure_message(
		"Live enemy count went from %d to %d over 150 physics ticks. The scene "
		% [at_start, after]
		+ "starts with %d hand-placed enemies, so the director spawned nothing: "
		% HAND_PLACED_ENEMY_COUNT
		+ "the arena is a fixture again, which is the exact thing the author's "
		+ "P2.7 verdict called out."
	).is_greater(HAND_PLACED_ENEMY_COUNT)


func test_the_director_left_its_idle_state_rather_than_sitting_still() -> void:
	var d: Node = _director()
	for _i in range(150):
		await get_tree().physics_frame
	var state: String = str(d.get_state_name())
	assert_str(state).append_failure_message(
		"WaveDirector is still in state '%s' after 150 ticks. A director that " % state
		+ "never leaves IDLE spawns nothing while every one of its own unit "
		+ "tests keeps passing, because those drive it directly."
	).is_not_equal("IDLE")
