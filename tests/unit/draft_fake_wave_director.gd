extends Node
class_name DraftFakeWaveDirector

## Test-only double for the subset of src/director/wave_director.gd's
## public surface src/ui/draft_controller.gd actually reads (duck-typed:
## `teaching_wave_unique_ids`, `get_current_wave_id()`, the `wave_ended`
## signal, `notify_draft_closed()`). Lets the six P2.12 suites exercise the
## Draft's teaching-wave/grace-period logic without constructing a full
## WaveDirector and its own dependency graph (EntityRegistry, Encounter/Wave
## Definitions, EntitySpawner, ...), none of which this task's write scope
## may touch or needs to touch.
##
## Not a gdUnit4 suite (does not extend GdUnitTestSuite) -- ignored by the
## test runner's own discovery, exactly like every other plain support
## script under tests/unit/.

signal wave_ended(wave_id: String, wave_index: int)

var teaching_wave_unique_ids: Array[String] = ["wave_t1", "wave_t2", "wave_t3", "wave_t4"]

var _current_wave_id: String = "wave_t1"
var _notify_draft_closed_calls: Array[float] = []


func set_current_wave_id_for_test(wave_id: String) -> void:
	_current_wave_id = wave_id


func get_current_wave_id() -> String:
	return _current_wave_id


## Test helper: fires the real signal exactly as the live WaveDirector would
## (docs/11 > "Wave Runtime Model"), advancing `_current_wave_id` to
## `next_wave_id` first so a listener reading get_current_wave_id() from
## inside its own signal handler observes the post-end state, matching
## src/director/wave_director.gd's own `_end_current_wave()` ordering
## (wave_ended.emit() happens before the director opens whatever is next).
func end_wave_for_test(wave_id: String, wave_index: int, next_wave_id: String = "") -> void:
	wave_ended.emit(wave_id, wave_index)
	if next_wave_id != "":
		_current_wave_id = next_wave_id


func notify_draft_closed(now: float) -> void:
	_notify_draft_closed_calls.append(now)


func get_notify_draft_closed_calls_for_test() -> Array[float]:
	return _notify_draft_closed_calls.duplicate()


func was_notify_draft_closed_called_for_test() -> bool:
	return not _notify_draft_closed_calls.is_empty()
