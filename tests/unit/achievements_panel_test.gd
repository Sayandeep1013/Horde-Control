extends GdUnitTestSuite

## Achievements panel tests (D118), mirroring records_panel_test.gd's own
## established pattern exactly: read-only, every test redirects MetaProgress
## to a throwaway directory first (hard constraint).

const AchievementListScript: GDScript = preload("res://src/data/achievement_list.gd")
const AchievementDefinitionScript: GDScript = preload("res://src/data/achievement_definition.gd")
const RealAchievementList: AchievementList = preload("res://data/meta/achievements.tres")

var _dir: String
var _back_requested_fired: bool = false


func before_test() -> void:
	_dir = "user://__achievements_panel_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_achievement_list_for_test(RealAchievementList)
	MetaProgress.set_base_path_for_test("user://")


func _make_achievement(id: String, metric: String, threshold: float) -> AchievementDefinition:
	var a: AchievementDefinition = AchievementDefinitionScript.new()
	a.id = id
	a.display_name = id.capitalize()
	a.description = "test fixture"
	a.metric = metric
	a.threshold = threshold
	a.unlocks_card_id = "test_card"
	return a


func _fake_list(achievements: Array[AchievementDefinition]) -> AchievementList:
	var list: AchievementList = AchievementListScript.new()
	list.achievements = achievements
	return list


func test_a_row_exists_for_every_authored_achievement() -> void:
	var panel: AchievementsPanel = auto_free(AchievementsPanel.new())
	add_child(panel)
	panel.set_active(true)
	assert_int(panel.get_row_count_for_test()).is_equal(RealAchievementList.achievements.size())


func test_an_unlocked_achievement_shows_unlocked() -> void:
	MetaProgress.set_achievement_list_for_test(_fake_list([_make_achievement("kill_five", "lifetime_kills", 5.0)]))
	MetaProgress.settle_run({"run_id": "p1", "sim_time_seconds": 0.0, "waves_cleared": 0, "kills": 5, "victory": false, "abandoned": false})

	var panel: AchievementsPanel = auto_free(AchievementsPanel.new())
	add_child(panel)
	panel.set_active(true)

	assert_str(panel.get_row_value_label_for_test("kill_five").text).is_equal("Unlocked")


func test_a_locked_lifetime_achievement_shows_its_progress_fraction() -> void:
	MetaProgress.set_achievement_list_for_test(_fake_list([_make_achievement("kill_hundred", "lifetime_kills", 100.0)]))
	MetaProgress.settle_run({"run_id": "p2", "sim_time_seconds": 0.0, "waves_cleared": 0, "kills": 37, "victory": false, "abandoned": false})

	var panel: AchievementsPanel = auto_free(AchievementsPanel.new())
	add_child(panel)
	panel.set_active(true)

	assert_str(panel.get_row_value_label_for_test("kill_hundred").text).is_equal("37 / 100")


func test_a_locked_per_run_achievement_shows_locked_not_a_fraction() -> void:
	MetaProgress.set_achievement_list_for_test(_fake_list([_make_achievement("win_a_run", "run_victory", 1.0)]))

	var panel: AchievementsPanel = auto_free(AchievementsPanel.new())
	add_child(panel)
	panel.set_active(true)

	assert_str(panel.get_row_value_label_for_test("win_a_run").text).is_equal("Locked")


func test_back_button_emits_back_requested() -> void:
	_back_requested_fired = false
	var panel: AchievementsPanel = auto_free(AchievementsPanel.new())
	add_child(panel)
	panel.set_active(true)
	panel.back_requested.connect(func() -> void: _back_requested_fired = true)
	panel.get_back_button_for_test().pressed.emit()
	assert_bool(_back_requested_fired).is_true()
