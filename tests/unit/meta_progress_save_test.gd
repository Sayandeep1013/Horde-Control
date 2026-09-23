extends GdUnitTestSuite

## MetaProgress save/load tests (Meta layer core, build brief item 6).
## MASTER_SDLC.md > Provisional Values Register > "Meta: Save profile":
## atomic write via .tmp then rename with a .bak of the previous file;
## corrupt file falls back to .bak, then a fresh profile with
## profile.corrupt.json kept; reconcile (rank above max / unknown id
## refunded). Every test redirects the REAL `MetaProgress` autoload to a
## throwaway `user://` subdirectory via `set_base_path_for_test()` BEFORE
## touching anything else on it (hard constraint: never touch the real
## `user://profile.json`) -- `after_test()` restores the real skill tree and
## detaches from the throwaway directory (itself no I/O -- see
## meta_progress.gd's own header).

var _dir: String


func before_test() -> void:
	_dir = "user://__meta_test_save_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_fail_after_tmp_write_for_test(false)
	MetaProgress.set_fail_after_bak_write_for_test(false)
	MetaProgress.set_skill_tree_for_test(load("res://data/meta/skill_tree.tres"))
	MetaProgress.set_base_path_for_test("user://")


func _settle(run_id: String, sim_seconds: float, waves: int, kills: int, victory: bool = false) -> Dictionary:
	return MetaProgress.settle_run({
		"run_id": run_id, "sim_time_seconds": sim_seconds,
		"waves_cleared": waves, "kills": kills, "victory": victory, "abandoned": false,
	})


func _read_raw(filename: String) -> Variant:
	var path: String = _dir.path_join(filename)
	if not FileAccess.file_exists(path):
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return "CORRUPT:%s" % text
	return json.data


func _corrupt_file(filename: String) -> void:
	var f: FileAccess = FileAccess.open(_dir.path_join(filename), FileAccess.WRITE)
	f.store_string("{ this is not valid json ]]]")
	f.close()


# --- Round trip ---------------------------------------------------------------

func test_round_trip_save_load_preserves_cores_and_ranks() -> void:
	_settle("rt_1", 300.0, 2, 60) # some Cores earned, real save on disk
	var cores_before: int = MetaProgress.get_cores()
	assert_int(cores_before).is_greater(0)
	assert_bool(MetaProgress.buy("vitality")).is_true()
	var rank_before: int = MetaProgress.get_rank("vitality")

	MetaProgress.reload_for_test() # re-reads from disk, discards in-memory state

	assert_int(MetaProgress.get_cores()).append_failure_message("Cores did not round-trip through save/load").is_equal(cores_before - SkillNodeDefinition.price_for_rank(1, 1))
	assert_int(MetaProgress.get_rank("vitality")).append_failure_message("tree rank did not round-trip through save/load").is_equal(rank_before)


# --- Kill mid-write (both injectable failure points) -------------------------

## FALSIFICATION (named in the report): temporarily making `buy()` call
## `_save()` before mutating `_profile` (instead of after) made this test's
## final assertion fail with a bogus higher cores figure, because the failed
## save would then have "succeeded" against pre-purchase state. Reverted
## after confirming the failure; the real ordering (mutate in memory, then
## attempt to persist) is what this test actually polices.
func test_kill_after_tmp_write_leaves_previous_profile_intact() -> void:
	_settle("kill_tmp_1", 300.0, 2, 60) # real, complete save -- state A on disk (11 Cores, enough to afford a rank below)
	var cores_state_a: int = MetaProgress.get_cores()

	MetaProgress.set_fail_after_tmp_write_for_test(true)
	MetaProgress.buy("vitality") # mutates in-memory state; _save() fails before ever touching profile.json/.bak
	assert_int(MetaProgress.get_cores()).append_failure_message("in-memory purchase should still apply even though the save failed").is_less(cores_state_a)

	MetaProgress.set_fail_after_tmp_write_for_test(false)
	MetaProgress.reload_for_test() # reads whatever is ACTUALLY on disk
	assert_int(MetaProgress.get_cores()).append_failure_message("a crash after the .tmp write (before .bak/rename) must leave the previous complete profile.json untouched").is_equal(cores_state_a)
	assert_int(MetaProgress.get_rank("vitality")).is_equal(0)


func test_kill_after_bak_write_leaves_previous_profile_intact() -> void:
	_settle("kill_bak_1", 300.0, 2, 60) # state A on disk (11 Cores, enough to afford a rank below)
	var cores_state_a: int = MetaProgress.get_cores()

	MetaProgress.set_fail_after_bak_write_for_test(true)
	MetaProgress.buy("vitality") # .tmp is written fully, .bak write is attempted, then the injected failure fires before the rename
	assert_int(MetaProgress.get_cores()).is_less(cores_state_a)

	MetaProgress.set_fail_after_bak_write_for_test(false)
	MetaProgress.reload_for_test()
	assert_int(MetaProgress.get_cores()).append_failure_message("a crash after .bak (before the rename) must leave the previous complete profile.json untouched").is_equal(cores_state_a)


# --- Corruption fallback -------------------------------------------------------

func test_corrupt_profile_falls_back_to_backup() -> void:
	_settle("corrupt_1", 60.0, 0, 0) # state A -> profile.json (no .bak yet, first save)
	var cores_state_a: int = MetaProgress.get_cores()
	_settle("corrupt_2", 60.0, 1, 25) # state B -> profile.json=B, profile.json.bak=A
	assert_int(MetaProgress.get_cores()).is_greater(cores_state_a)

	_corrupt_file("profile.json")
	MetaProgress.reload_for_test()

	assert_int(MetaProgress.get_cores()).append_failure_message("a corrupt profile.json must fall back to profile.json.bak").is_equal(cores_state_a)
	assert_bool(MetaProgress.get_flags()["recovered_from_corruption"]).is_true()
	# _read_raw() returns a String (prefixed "CORRUPT:") for content that does
	# not parse as JSON, which this deliberately-corrupt copy never does --
	# assert_object() only accepts an Object/null, so a plain not-null check
	# on the raw Variant is used instead.
	assert_bool(_read_raw("profile.corrupt.json") != null).append_failure_message("the corrupt file must be kept, not silently discarded").is_true()


func test_corrupt_profile_and_backup_falls_back_to_fresh() -> void:
	_settle("corrupt_fresh_1", 60.0, 1, 25)
	_settle("corrupt_fresh_2", 60.0, 1, 25) # now a .bak exists too
	_corrupt_file("profile.json")
	_corrupt_file("profile.json.bak")

	MetaProgress.reload_for_test()

	assert_int(MetaProgress.get_cores()).append_failure_message("both files corrupt must start a fresh profile (0 Cores)").is_equal(0)
	assert_bool(MetaProgress.get_flags()["recovered_from_corruption"]).is_true()


# --- Reconcile (rank above max / unknown id refunded) -------------------------

func _fake_two_node_tree() -> SkillTreeDefinition:
	var root := SkillNodeDefinition.new()
	root.id = "root"
	root.tier = 0
	root.max_rank = 1
	var child := SkillNodeDefinition.new()
	child.id = "test_node"
	child.tier = 1
	child.max_rank = 2
	child.prerequisite_ids = ["root"]
	var tree := SkillTreeDefinition.new()
	tree.root_id = "root"
	tree.nodes = [root, child]
	return tree


func test_reconcile_refunds_a_rank_above_current_max_and_clamps_it() -> void:
	MetaProgress.set_skill_tree_for_test(_fake_two_node_tree())
	# Hand-write a profile as if it were saved against an OLDER tree where
	# test_node's max_rank was higher than 2 (the reconcile scenario the
	# Register names: "a node ... its max_rank lowered"). `_dir` is a fresh,
	# not-yet-created throwaway directory (before_test() only redirects
	# MetaProgress's own _base_path to it, no I/O yet) -- FileAccess.open()
	# for WRITE does not create missing parent directories itself.
	DirAccess.make_dir_recursive_absolute(_dir)
	var f: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"schema_version": 1, "cores": 0, "lifetime_cores": 0,
		"tree_ranks": {"test_node": 5},
		"records": {}, "settled_run_ids": [], "first_hub_seen": false, "flags": {},
	}))
	f.close()

	MetaProgress.reload_for_test()

	assert_int(MetaProgress.get_rank("test_node")).append_failure_message("a stored rank above the node's current max_rank must be clamped").is_equal(2)
	var expected_refund: int = SkillNodeDefinition.price_for_rank(1, 3) + SkillNodeDefinition.price_for_rank(1, 4) + SkillNodeDefinition.price_for_rank(1, 5)
	assert_int(MetaProgress.get_cores()).append_failure_message("ranks 3-5 (no longer purchasable) must be refunded in Cores").is_equal(expected_refund)


func test_reconcile_refunds_and_drops_an_unknown_node_id() -> void:
	MetaProgress.set_skill_tree_for_test(_fake_two_node_tree())
	DirAccess.make_dir_recursive_absolute(_dir) # see the sibling test's identical comment above
	var f: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"schema_version": 1, "cores": 0, "lifetime_cores": 0,
		"tree_ranks": {"ghost_node_removed_from_tree": 3},
		"records": {}, "settled_run_ids": [], "first_hub_seen": false, "flags": {},
	}))
	f.close()

	MetaProgress.reload_for_test()

	assert_int(MetaProgress.get_rank("ghost_node_removed_from_tree")).append_failure_message("an unknown node id must not be kept as a live rank").is_equal(0)
	assert_int(MetaProgress.get_cores()).append_failure_message("Cores spent on a node removed from the authored tree must be refunded, not silently lost").is_greater(0)
