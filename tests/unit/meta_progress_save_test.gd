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


# --- last_save_failed lifecycle (finding #3) -----------------------------------

## FALSIFICATION (named in the report): reverting `_save()` to set
## `last_save_failed` only AFTER `_write_atomic()` (the pre-fix ordering)
## made the LAST assertion below fail: a successful save persisted the
## PREVIOUS attempt's failure flag to disk (`_write_atomic()` serialises
## `_profile` verbatim, before the post-write update ever ran). Reverted
## after confirming the failure.
func test_a_failed_save_sets_last_save_failed_and_a_later_successful_save_clears_it_on_disk() -> void:
	_settle("flag_1", 600.0, 4, 100) # a real, successful save paying enough Cores (10 + 8 + 4 = 22) for the two tier-1 buys below
	assert_bool(MetaProgress.get_flags()["last_save_failed"]).is_false()

	MetaProgress.set_fail_after_tmp_write_for_test(true)
	MetaProgress.buy("vitality") # in-memory purchase succeeds; the save attempt fails
	assert_bool(MetaProgress.get_flags()["last_save_failed"]).append_failure_message("a failed save must set the warning flag").is_true()
	assert_int(MetaProgress.get_rank("vitality")).append_failure_message("the in-memory purchase must still apply even though the save failed").is_equal(1)

	MetaProgress.set_fail_after_tmp_write_for_test(false)
	assert_bool(MetaProgress.buy("swift_boots")).append_failure_message("the next save point (docs/18: retry succeeds at the next save point)").is_true()
	assert_bool(MetaProgress.get_flags()["last_save_failed"]).append_failure_message("a successful save must clear the in-memory warning flag").is_false()

	MetaProgress.reload_for_test() # re-reads from disk -- proves the clear was actually WRITTEN, not merely held in memory
	assert_bool(MetaProgress.get_flags()["last_save_failed"]).append_failure_message("a successful save must persist last_save_failed=false to disk -- it must never carry the PREVIOUS attempt's failure into a successful write's own file").is_false()


# --- Never back up a file that failed to parse (finding #4) --------------------

## FALSIFICATION (named in the report): temporarily removing the
## `_try_parse_file(real_path) is Dictionary` re-validation in
## `_write_atomic()` (unconditionally copying `real_path` to `.bak` again,
## the pre-fix behaviour) made the middle assertion below fail -- the good
## `.bak` from `precorrupt_2` was overwritten with the corrupt content still
## sitting in `profile.json` at the time of the next save. Reverted after
## confirming the failure.
func test_a_corrupt_profile_on_disk_is_never_copied_into_bak_by_a_later_save() -> void:
	_settle("precorrupt_1", 120.0, 2, 50) # state A: profile.json only (no .bak yet)
	_settle("precorrupt_2", 120.0, 2, 50) # state B: profile.json=B, profile.json.bak=A (the "good .bak")
	var good_bak: Variant = _read_raw("profile.json.bak")
	assert_bool(good_bak is Dictionary).append_failure_message("fixture setup: a real .bak must exist before profile.json is corrupted").is_true()

	# Something corrupts profile.json OUTSIDE this process's own atomic-write
	# path (disk corruption, a hand-edit, another process) -- the exact
	# scenario `_load_from_disk()` already recovers from via `.bak`. The bug
	# (finding #4): profile.json itself is NEVER touched by that recovery
	# (only read), so it stays corrupt on disk until the NEXT save -- which
	# used to copy it straight over the one good `.bak`, destroying it.
	_corrupt_file("profile.json")
	MetaProgress.reload_for_test() # recovers from .bak (state A); profile.json on disk is STILL corrupt
	assert_bool(MetaProgress.get_flags()["recovered_from_corruption"]).is_true()

	assert_bool(MetaProgress.buy("vitality")).append_failure_message("fixture setup: state A must afford at least one rank").is_true() # the next save point

	var bak_after: Variant = _read_raw("profile.json.bak")
	assert_bool(bak_after == good_bak).append_failure_message("a save must never back up a profile.json that failed to parse -- it must leave the last GOOD .bak untouched").is_true()
	assert_bool(_read_raw("profile.json") is Dictionary).append_failure_message("the save itself must still succeed and produce a valid profile.json").is_true()


# --- Missing profile.json with a surviving, parseable .tmp (finding #5) --------

## FALSIFICATION (named in the report): temporarily removing the new
## `FileAccess.file_exists(tmp_path)` fallback branch in `_load_from_disk()`
## (falling straight through to `.bak`, the pre-fix behaviour) made the
## final assertion fail -- the reload landed on stale pre-purchase Cores
## from `.bak` instead of the newer, complete `.tmp` write. Reverted after
## confirming the failure.
func test_missing_profile_json_with_a_parseable_tmp_loads_from_the_tmp() -> void:
	_settle("tmp_recovery_1", 300.0, 2, 60) # state A on disk (profile.json only)

	MetaProgress.set_fail_after_tmp_write_for_test(true)
	MetaProgress.buy("vitality") # writes profile.json.tmp fully (state A + purchase), then the injected failure fires before .bak/rename
	var cores_with_purchase: int = MetaProgress.get_cores() # in-memory only so far

	# Reproduces finding #5's exact scenario: `DirAccess.rename()` is not
	# guaranteed atomic on every platform (Register > "Meta: Save profile";
	# Windows in particular) -- profile.json is GONE (whatever a
	# non-atomic rename left behind) while profile.json.tmp is still sitting
	# there, fully written and parseable: the newest COMPLETE write.
	var dir: DirAccess = DirAccess.open(_dir)
	assert_object(dir).is_not_null()
	assert_int(dir.remove(MetaProgress.PROFILE_FILENAME)).append_failure_message("fixture setup: profile.json must exist to remove").is_equal(OK)
	MetaProgress.set_fail_after_tmp_write_for_test(false)

	MetaProgress.reload_for_test()

	assert_int(MetaProgress.get_cores()).append_failure_message("a missing profile.json with a fully-written, parseable .tmp must load from the .tmp -- it is the newest complete write, newer than .bak").is_equal(cores_with_purchase)
	assert_int(MetaProgress.get_rank("vitality")).is_equal(1)


# --- Newer-schema profile loads read-only and is never overwritten (finding #7) -

func test_a_newer_schema_profile_loads_read_only_and_is_never_overwritten() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var f: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"schema_version": MetaProgress.SCHEMA_VERSION + 1, "cores": 777, "lifetime_cores": 777,
		"tree_ranks": {}, "records": {}, "settled_run_ids": [], "first_hub_seen": false, "flags": {},
	}))
	f.close()

	MetaProgress.reload_for_test()

	assert_int(MetaProgress.get_cores()).append_failure_message("a newer-schema profile must still load its own values, read-only").is_equal(777)
	assert_bool(MetaProgress.get_flags()["read_only_newer_version"]).is_true()

	var raw_before: Variant = _read_raw("profile.json")
	# settle_run() has no read_only_newer_version guard of its own (see
	# meta_progress.gd) -- it always calls _save() unconditionally, making
	# it the one production path that proves _save() ITSELF refuses to
	# write, not merely buy()'s/respec()'s own early-outs.
	var breakdown: Dictionary = MetaProgress.settle_run({"run_id": "newer_1", "sim_time_seconds": 600.0, "waves_cleared": 5, "kills": 200, "victory": true, "abandoned": false})
	assert_bool(breakdown["saved"]).append_failure_message("settle_run()'s own breakdown must report that this settlement was NOT saved").is_false()
	assert_bool(MetaProgress.buy("vitality")).append_failure_message("buy() must also refuse outright on a read-only newer-version profile").is_false()

	var raw_after: Variant = _read_raw("profile.json")
	assert_bool(raw_after == raw_before).append_failure_message("a newer-schema profile.json on disk must never be overwritten by an older build").is_true()


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
