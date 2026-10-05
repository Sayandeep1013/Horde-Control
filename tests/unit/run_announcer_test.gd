extends GdUnitTestSuite

## UX review items 4 and 9 (D129/D130): wave banner, Siege warning, run
## objective and first-run hints gated by a MetaProgress flag.

var _dir: String


class FakeDirector extends Node:
	signal wave_opened(wave_id: String, wave_index: int)
	var siege: bool = false

	func get_wave_total_count() -> int:
		return 8

	func is_current_wave_siege() -> bool:
		return siege


func before_test() -> void:
	_dir = "user://__run_announcer_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")


func _make() -> Array:
	var director: FakeDirector = auto_free(FakeDirector.new())
	add_child(director)
	var announcer: RunAnnouncer = auto_free(RunAnnouncer.new())
	add_child(announcer)
	announcer.bind_wave_director(director)
	return [director, announcer]


func _texts(box: Control) -> Array[String]:
	var out: Array[String] = []
	for n in box.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


func test_each_wave_start_shows_a_wave_banner() -> void:
	var parts: Array = _make()
	var director: FakeDirector = parts[0]
	var announcer: RunAnnouncer = parts[1]
	director.wave_opened.emit("wave_combat_1", 4)
	assert_array(_texts(announcer.get_banner_box_for_test())).contains(["Wave 5"])
	assert_array(_texts(announcer.get_banner_box_for_test())).not_contains(["Siege incoming"])


func test_a_siege_wave_adds_the_siege_warning() -> void:
	var parts: Array = _make()
	var director: FakeDirector = parts[0]
	var announcer: RunAnnouncer = parts[1]
	director.siege = true
	director.wave_opened.emit("wave_combat_2", 5)
	assert_array(_texts(announcer.get_banner_box_for_test())).contains(["Wave 6", "Siege incoming"])


func test_wave_one_shows_the_objective_line() -> void:
	var parts: Array = _make()
	var director: FakeDirector = parts[0]
	var announcer: RunAnnouncer = parts[1]
	director.wave_opened.emit("t1", 0)
	assert_array(_texts(announcer.get_toast_box_for_test())).contains(["Protect yourself and the Tower - survive 8 waves"])


func test_hints_run_on_a_fresh_profile_and_are_skipped_once_seen() -> void:
	var parts: Array = _make()
	var director: FakeDirector = parts[0]
	var announcer: RunAnnouncer = parts[1]
	director.wave_opened.emit("t1", 0)
	assert_bool(announcer.is_hint_sequence_running_for_test()).is_true()
	MetaProgress.mark_first_run_hints_seen()
	assert_bool(MetaProgress.is_first_run_hints_seen()).is_true()

	var parts2: Array = _make()
	var director2: FakeDirector = parts2[0]
	var announcer2: RunAnnouncer = parts2[1]
	director2.wave_opened.emit("t1", 0)
	assert_bool(announcer2.is_hint_sequence_running_for_test()).append_failure_message("hints must not repeat once seen").is_false()


func test_the_seen_flag_defaults_false_and_persists() -> void:
	MetaProgress.ensure_loaded()
	assert_bool(MetaProgress.is_first_run_hints_seen()).is_false()
	MetaProgress.mark_first_run_hints_seen()
	MetaProgress.set_base_path_for_test(_dir) # drop memory, reload from disk
	MetaProgress.ensure_loaded()
	assert_bool(MetaProgress.is_first_run_hints_seen()).is_true()
