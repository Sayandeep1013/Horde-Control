extends GdUnitTestSuite

## Supplementary coverage for src/core/../src/debug/run_recorder.gd (P1.4),
## separate from the named acceptance test in run_recorder_schema_test.gd.
## Exists so that a recorder which writes the RIGHT headers but the WRONG
## row content is still caught here (Phase 02 carried lesson 1: "a check is
## not believed until it has been made to fail" -- these are the
## correctness assertions the schema check itself does not cover).
##
## Fresh RunRecorder instance per test, added to this suite's own tree, so
## one test's open run/EventBus connections can never leak into the next.

var _recorder: RunRecorder


func before_test() -> void:
	_recorder = auto_free(RunRecorder.new())
	add_child(_recorder)


func after_test() -> void:
	if _recorder != null and is_instance_valid(_recorder) and _recorder.is_running():
		_recorder.end_run("test cleanup")


func _read_lines(path: String) -> Array[String]:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var lines: Array[String] = []
	while not f.eof_reached():
		var l: String = f.get_line()
		if not l.is_empty():
			lines.append(l)
	f.close()
	return lines


func test_process_mode_is_pausable() -> void:
	# See run_recorder.gd's own header comment: ticks.csv samples
	# simulation state, which freezes under pause, so this node stops with
	# it -- matching SimClock's own process mode.
	assert_int(_recorder.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)


func test_record_tick_sample_writes_current_injected_state() -> void:
	_recorder.start_run("human", 1001)
	_recorder.set_player_state(85.0, Vector2(120.0, -40.0), 3, 50, 12.5)
	_recorder.set_tower_state(400.0, 25.0)
	_recorder.set_pressure(1.75)
	_recorder.set_health_quadrant("PlayerHigh_TowerHigh")
	_recorder.record_tick_sample()
	_recorder.end_run("test")

	var lines: Array[String] = _read_lines(_recorder.get_run_dir() + "/ticks.csv")
	assert_int(lines.size()).is_equal(2) # header + one sampled row
	var fields: PackedStringArray = lines[1].split(",")
	assert_int(fields.size()).is_equal(11)
	assert_float(fields[1].to_float()).is_equal_approx(120.0, 0.001) # player_pos_x
	assert_float(fields[2].to_float()).is_equal_approx(-40.0, 0.001) # player_pos_y
	assert_float(fields[3].to_float()).is_equal_approx(85.0, 0.001) # player_hp
	assert_float(fields[4].to_float()).is_equal_approx(400.0, 0.001) # tower_hp
	assert_float(fields[5].to_float()).is_equal_approx(25.0, 0.001) # tower_shield
	assert_float(fields[6].to_float()).is_equal_approx(1.75, 0.001) # pressure
	assert_str(fields[7]).is_equal("PlayerHigh_TowerHigh") # health_quadrant
	assert_int(fields[8].to_int()).is_equal(3) # xp_level
	assert_int(fields[9].to_int()).is_equal(50) # scrap
	assert_float(fields[10].to_float()).is_equal_approx(12.5, 0.001) # hopper_amount


func test_record_event_writes_sim_time_type_intent_bearing_amount() -> void:
	_recorder.start_run("human", 1002)
	_recorder.set_tower_position(Vector2.ZERO)
	_recorder.record_event(&"purchase", &"console", 90.0, 3.0)
	_recorder.end_run("test")

	var lines: Array[String] = _read_lines(_recorder.get_run_dir() + "/events.csv")
	# header + purchase row + run_end row from end_run()
	assert_int(lines.size()).is_equal(3)
	var fields: PackedStringArray = lines[1].split(",")
	assert_str(fields[1]).is_equal("purchase")
	assert_str(fields[2]).is_equal("console")
	assert_float(fields[3].to_float()).is_equal_approx(90.0, 0.001)
	assert_float(fields[4].to_float()).is_equal_approx(3.0, 0.001)


func test_end_run_writes_a_run_end_event() -> void:
	_recorder.start_run("human", 1003)
	_recorder.end_run("player_death")
	var lines: Array[String] = _read_lines(_recorder.get_run_dir() + "/events.csv")
	assert_int(lines.size()).is_equal(2) # header + run_end
	var fields: PackedStringArray = lines[1].split(",")
	assert_str(fields[1]).is_equal("run_end")
	assert_str(fields[2]).is_equal("player_death")


func test_enemy_died_signal_is_recorded_as_a_death_event() -> void:
	_recorder.start_run("human", 1004)
	_recorder.set_tower_position(Vector2.ZERO)
	var dummy: Node2D = auto_free(Node2D.new())
	EventBus.emit_enemy_died(dummy, Vector2(100, 0))
	_recorder.end_run("test")

	var lines: Array[String] = _read_lines(_recorder.get_run_dir() + "/events.csv")
	assert_int(lines.size()).is_equal(3) # header + death + run_end
	var fields: PackedStringArray = lines[1].split(",")
	assert_str(fields[1]).is_equal("death")
	assert_str(fields[2]).is_equal("enemy")


func test_tower_damaged_signal_is_recorded_with_amount() -> void:
	_recorder.start_run("human", 1005)
	EventBus.emit_tower_damaged(15.0, 485.0, 0.0)
	_recorder.end_run("test")

	var lines: Array[String] = _read_lines(_recorder.get_run_dir() + "/events.csv")
	var fields: PackedStringArray = lines[1].split(",")
	assert_str(fields[1]).is_equal("damage")
	assert_str(fields[2]).is_equal("tower")
	assert_float(fields[4].to_float()).is_equal_approx(15.0, 0.001)


func test_end_run_disconnects_from_event_bus() -> void:
	_recorder.start_run("human", 1006)
	_recorder.end_run("test")
	assert_bool(EventBus.enemy_died.is_connected(_recorder._on_enemy_died)).is_false()
	assert_bool(EventBus.tower_damaged.is_connected(_recorder._on_tower_damaged)).is_false()
	assert_bool(EventBus.draft_opened.is_connected(_recorder._on_draft_opened)).is_false()


func test_csv_fields_containing_commas_are_quoted() -> void:
	_recorder.start_run("human", 1007)
	_recorder.record_event(&"purchase", &"note, with a comma", 0.0, 0.0)
	_recorder.end_run("test")
	var lines: Array[String] = _read_lines(_recorder.get_run_dir() + "/events.csv")
	assert_str(lines[1]).contains("\"note, with a comma\"")


func test_idleness_does_not_flag_before_the_threshold() -> void:
	_recorder.start_run("human", 1008)
	_recorder.set_idle_thresholds(0.0, 0.0)
	# No enemies registered, no pickups registered: idle conditions are
	# met, but the fixed 3 s grace has not yet elapsed.
	_recorder.force_idle_update_for_test(2.9)
	_recorder.end_run("test")
	var lines: Array[String] = _read_lines(_recorder.get_run_dir() + "/events.csv")
	assert_int(lines.size()).is_equal(2) # header + run_end only, no idle row


func test_idleness_flags_once_past_the_threshold_and_does_not_repeat() -> void:
	_recorder.start_run("human", 1009)
	_recorder.set_idle_thresholds(0.0, 0.0)
	_recorder.force_idle_update_for_test(3.1) # past the fixed 3 s grace
	_recorder.force_idle_update_for_test(1.0) # still idle: must not re-flag
	_recorder.end_run("test")
	var lines: Array[String] = _read_lines(_recorder.get_run_dir() + "/events.csv")
	assert_int(lines.size()).is_equal(3) # header + one idle row + run_end
	var fields: PackedStringArray = lines[1].split(",")
	assert_str(fields[1]).is_equal("idle")


func test_idleness_respects_scheduled_gap_and_grace_period() -> void:
	_recorder.start_run("human", 1010)
	_recorder.set_idle_thresholds(5.0, 2.0) # threshold = 5 + 2 + 3 = 10
	_recorder.force_idle_update_for_test(9.9)
	_recorder.end_run("test")
	var lines_before: Array[String] = _read_lines(_recorder.get_run_dir() + "/events.csv")
	assert_int(lines_before.size()).is_equal(2) # not flagged yet

	_recorder.start_run("human", 1011)
	_recorder.set_idle_thresholds(5.0, 2.0)
	_recorder.force_idle_update_for_test(10.1)
	_recorder.end_run("test")
	var lines_after: Array[String] = _read_lines(_recorder.get_run_dir() + "/events.csv")
	assert_int(lines_after.size()).is_equal(3) # flagged
