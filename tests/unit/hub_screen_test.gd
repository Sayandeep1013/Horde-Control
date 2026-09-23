extends GdUnitTestSuite

## Hub (War Camp) screen tests. docs/18_Permanent_Skill_Tree.md section 2:
## "the first time the Hub opens ... a one-line hint" (shown once); section
## 6 edge cases: a recovered/corrupt/read-only-newer profile shows a
## non-blocking banner. Every test redirects MetaProgress to a throwaway
## directory first (hard constraint) -- HubScreen is the one production
## caller of MetaProgress.ensure_loaded(), so instantiating it here is the
## first real disk read/write these suites exercise.

var _dir: String


func before_test() -> void:
	_dir = "user://__hub_screen_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")


func _corrupt_profile_file() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var f: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	f.store_string("{ not valid json ]]]")
	f.close()


# --- First-visit hint (docs/18 section 2) --------------------------------------

func test_first_visit_hint_shows_on_a_fresh_profile() -> void:
	var hub: HubScreen = auto_free(HubScreen.new())
	add_child(hub)
	assert_bool(hub.get_hint_banner_for_test().visible).append_failure_message("a fresh profile (no prior Hub visit) must show the first-visit hint").is_true()
	assert_bool(MetaProgress.is_first_hub_seen()).append_failure_message("opening the Hub must mark first_hub_seen").is_true()


func test_first_visit_hint_never_shows_again_once_marked() -> void:
	var hub1: HubScreen = auto_free(HubScreen.new())
	add_child(hub1)
	assert_bool(hub1.get_hint_banner_for_test().visible).is_true()

	var hub2: HubScreen = auto_free(HubScreen.new())
	add_child(hub2)
	assert_bool(hub2.get_hint_banner_for_test().visible).append_failure_message("a returning visit (first_hub_seen already true) must not show the hint again").is_false()


func test_dismissing_the_hint_hides_it_immediately() -> void:
	var hub: HubScreen = auto_free(HubScreen.new())
	add_child(hub)
	assert_bool(hub.get_hint_banner_for_test().visible).is_true()
	var dismiss: Button = hub.get_hint_banner_for_test().get_node("Row/DismissButton") as Button
	dismiss.pressed.emit()
	assert_bool(hub.get_hint_banner_for_test().visible).is_false()


# --- Profile warning banner (docs/18 section 6) --------------------------------

func test_no_warning_banner_on_a_healthy_fresh_profile() -> void:
	var hub: HubScreen = auto_free(HubScreen.new())
	add_child(hub)
	assert_bool(hub.get_warning_banner_for_test().visible).is_false()


func test_a_recovered_from_corruption_profile_shows_the_warning_banner() -> void:
	_corrupt_profile_file()
	var hub: HubScreen = auto_free(HubScreen.new())
	add_child(hub)
	assert_bool(MetaProgress.get_flags()["recovered_from_corruption"]).is_true()
	assert_bool(hub.get_warning_banner_for_test().visible).append_failure_message("a corrupted-then-recovered profile must show a non-blocking warning").is_true()
	var label: Label = hub.get_warning_banner_for_test().get_node("Row/Label") as Label
	assert_str(label.text).is_equal(tr("HUB_WARNING_RECOVERED"))
	# Non-blocking: every real action stays usable underneath the banner.
	assert_bool(hub.get_start_run_button_for_test().disabled).is_false()
	assert_bool(hub.get_skill_tree_button_for_test().disabled).is_false()


# --- Cores balance display ------------------------------------------------------

func test_cores_label_reflects_the_current_wallet() -> void:
	MetaProgress.settle_run({
		"run_id": "hub_display_test", "sim_time_seconds": 300.0, "waves_cleared": 0,
		"kills": 0, "victory": false, "abandoned": false,
	})
	var hub: HubScreen = auto_free(HubScreen.new())
	add_child(hub)
	assert_str(hub.get_cores_label_for_test().text).is_equal(str(MetaProgress.get_cores()))
	assert_int(MetaProgress.get_cores()).is_greater(0)


# --- Skill Tree / Records overlays wire in and toggle correctly ----------------

func test_skill_tree_button_opens_the_skill_tree_overlay() -> void:
	var hub: HubScreen = auto_free(HubScreen.new())
	add_child(hub)
	assert_bool(hub.get_skill_tree_screen_for_test().is_active_for_test()).is_false()
	hub.get_skill_tree_button_for_test().pressed.emit()
	assert_bool(hub.get_skill_tree_screen_for_test().is_active_for_test()).is_true()


func test_records_button_opens_the_records_overlay() -> void:
	var hub: HubScreen = auto_free(HubScreen.new())
	add_child(hub)
	assert_bool(hub.get_records_panel_for_test().is_active_for_test()).is_false()
	hub.get_records_button_for_test().pressed.emit()
	assert_bool(hub.get_records_panel_for_test().is_active_for_test()).is_true()


func test_skill_tree_back_requested_closes_the_overlay() -> void:
	var hub: HubScreen = auto_free(HubScreen.new())
	add_child(hub)
	hub.get_skill_tree_button_for_test().pressed.emit()
	assert_bool(hub.get_skill_tree_screen_for_test().is_active_for_test()).is_true()
	hub.get_skill_tree_screen_for_test().back_requested.emit()
	assert_bool(hub.get_skill_tree_screen_for_test().is_active_for_test()).is_false()
