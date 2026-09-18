extends GdUnitTestSuite

## Recorder schema check (MASTER_SDLC.md > Acceptance Test Matrix >
## Technical Tests, P1.4; phases/PHASE_02_Technical_Foundations/PLAN.md >
## P1.4's acceptance test: "the scripted run's written headers diffed
## against the schema docs/20 defines").
##
## Carried lesson 2 (PLAN.md > Carried lessons): "P1.4's Recorder schema
## check takes its column list directly from docs/20's Run Recorder
## section, transcribed, not read back from the writer." The two constants
## below are typed out independently from
## docs/20_Technical_Architecture.md > "Debugging, Telemetry & Run
## Recording" > Run Recorder's own prose -- NOT read from
## RunRecorder.TICKS_HEADER / EVENTS_HEADER, and not shared with that file
## in any way -- so a writer regression (a dropped, renamed, or reordered
## column) has something independent to diff against instead of the writer
## silently redefining its own expectation. This suite's falsification
## block at the bottom mutates the WRITER's own constants directly and
## restores them, proving the two really can disagree.
##
## docs/20's own wording: "ticks.csv, sampled at 2 Hz, with columns SimClock
## time, player position, player HP, Tower HP and shield, Pressure, health
## quadrant, XP level, Scrap, and hopper amount." "player position" is not
## itself a single CSV-safe scalar; this transcription follows the
## implementer's own documented interpretation of splitting it into an x
## and a y column (evidence/p14_report.md, "Contradictions and
## ambiguities") -- an interpretation call, not something docs/20 states in
## so many words, named here rather than silently assumed.
const EXPECTED_TICKS_HEADER: PackedStringArray = [
	"sim_time", "player_pos_x", "player_pos_y", "player_hp",
	"tower_hp", "tower_shield", "pressure", "health_quadrant",
	"xp_level", "scrap", "hopper_amount",
]

## docs/20's own wording: "events.csv, one row per discrete event, with
## columns SimClock time, event type, source intent, source bearing from
## the Tower, and amount."
const EXPECTED_EVENTS_HEADER: PackedStringArray = [
	"sim_time", "event_type", "source_intent", "source_bearing", "amount",
]

var _recorder: RunRecorder


func before_test() -> void:
	_recorder = auto_free(RunRecorder.new())
	add_child(_recorder)


func after_test() -> void:
	# Safety net, mirroring pause_clock_test.gd's after_test pattern: a
	# failed assertion must never leave a run open for the next test.
	if _recorder != null and is_instance_valid(_recorder) and _recorder.is_running():
		_recorder.end_run("test cleanup")


func _read_header_row(path: String) -> Array:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(f).is_not_null()
	var line: String = f.get_line()
	f.close()
	return Array(line.split(","))


func test_ticks_csv_header_matches_docs20_schema() -> void:
	_recorder.start_run("human", 111111)
	var got: Array = _read_header_row(_recorder.get_run_dir() + "/ticks.csv")
	assert_array(got).is_equal(Array(EXPECTED_TICKS_HEADER))


func test_events_csv_header_matches_docs20_schema() -> void:
	_recorder.start_run("human", 222222)
	var got: Array = _read_header_row(_recorder.get_run_dir() + "/events.csv")
	assert_array(got).is_equal(Array(EXPECTED_EVENTS_HEADER))


func test_ticks_and_events_files_both_exist_in_the_run_folder() -> void:
	_recorder.start_run("human", 333333)
	var dir: String = _recorder.get_run_dir()
	assert_bool(FileAccess.file_exists(dir + "/ticks.csv")).is_true()
	assert_bool(FileAccess.file_exists(dir + "/events.csv")).is_true()
	assert_bool(FileAccess.file_exists(dir + "/header.csv")).is_true()


func test_run_folder_name_carries_seed_and_controller_id() -> void:
	# docs/20: "user://telemetry/<run_seed>_<yyyyMMdd-HHmmss>_<controller_id>/"
	_recorder.start_run("orbit_bot", 777)
	var dir: String = _recorder.get_run_dir()
	assert_bool(dir.contains("/777_")).is_true()
	assert_bool(dir.ends_with("_orbit_bot")).is_true()


func test_header_csv_records_seed_build_hash_and_godot_version() -> void:
	_recorder.start_run("human", 555)
	var f: FileAccess = FileAccess.open(_recorder.get_run_dir() + "/header.csv", FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()
	assert_str(content).contains("run_seed")
	assert_str(content).contains("555")
	assert_str(content).contains("build_hash")
	# docs/20: "editor and headless runs record build hash 'editor'" -- this
	# suite always runs headless via the pinned console executable, so this
	# is the one value this test can ever observe here.
	assert_str(content).contains("editor")
	assert_str(content).contains("godot_version")
	assert_str(content).contains("4.7.1")
