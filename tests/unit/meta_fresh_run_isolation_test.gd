extends GdUnitTestSuite

## docs/18_Permanent_Skill_Tree.md section 6 edge case: "Starting a run with
## a Draft queued from the previous run: Impossible -- a run always starts
## from a fresh prototype scene." (D115, no in-run shop, removed the Tower
## Console this row used to also cover; its own half of this test,
## `test_a_fresh_prototype_scenes_console_starts_closed_independent_of_a_
## previous_instance`, is removed with it -- there is no Console left to
## start closed.) Proves the claim against the REAL assembled scene
## (`scenes/prototype.tscn`), the way `get_tree().change_scene_to_file()`
## actually produces a new run: the whole scene tree for the FIRST run is
## torn down and a brand new instance of the SAME PackedScene is built for
## the SECOND, exactly like `HubScreen._on_start_run_pressed()` -> a run
## ending -> the Hub -> Start Run again. `DraftController` carries no
## `static var` of its own (checked directly), so this is expected to hold
## by construction; this test is the regression guard against that ever
## silently changing.

const PrototypeScene: PackedScene = preload("res://scenes/prototype.tscn")


func test_a_fresh_prototype_scene_never_inherits_a_queued_or_showing_draft_from_a_previous_instance() -> void:
	var first_root: Node = PrototypeScene.instantiate()
	add_child(first_root)
	var first_draft: DraftController = first_root.get_node("DraftInstance") as DraftController

	first_draft.queue_forced_draft_for_meta()
	assert_bool(first_draft.is_draft_showing_for_test()).append_failure_message("fixture setup: queuing a forced Draft on a fresh, fully-wired scene must actually open one").is_true()

	# Tear the WHOLE first scene down before building the second -- not
	# auto_free()/queue_free() (deferred): the assertions below must run
	# against a genuinely torn-down first instance, matching what
	# change_scene_to_file() does synchronously to the previous scene.
	remove_child(first_root)
	first_root.free()

	var second_root: Node = auto_free(PrototypeScene.instantiate())
	add_child(second_root)
	var second_draft: DraftController = second_root.get_node("DraftInstance") as DraftController

	assert_bool(second_draft.is_draft_showing_for_test()).append_failure_message("a fresh prototype scene must never inherit a showing Draft from a previous run").is_false()
	assert_int(second_draft.get_pending_draft_count_for_test()).append_failure_message("a fresh prototype scene must never inherit a queued Draft from a previous run").is_equal(0)
