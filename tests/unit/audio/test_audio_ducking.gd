extends GdUnitTestSuite

## P1.6 - ducking ramp math.
##
## Follows docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic
## Ducking" > "Dynamic Ducking"; values from MASTER_SDLC.md > Provisional
## Values Register > Audio > "Buses" row: SFX & Ambience duck 9 dB (50 ms
## attack, 300 ms release); Music ducks 6 dB, floored at -18 dB.
##
## Drives `step(delta)` directly with synthetic deltas instead of waiting on
## real frames (headless has no audio device to time playback against
## anyway - see p16_report.md), and configures base bus volumes via
## `configure_base_volumes_for_test()` so these tests do not depend on
## "SFX"/"Ambience"/"Music" existing in whatever the live AudioServer's bus
## graph happens to be during a headless run.

func _make_ducking() -> AudioDucking:
	var d := AudioDucking.new()
	add_child(d)
	auto_free(d)
	d.configure_base_volumes_for_test(0.0, 0.0, 0.0)
	return d


func test_idle_state_is_fully_unducked() -> void:
	var d := _make_ducking()
	assert_float(d.get_ramp_t()).is_equal_approx(0.0, 0.0001)
	assert_int(d.get_active_priority_count()).is_equal(0)


func test_attack_reaches_full_duck_in_50ms() -> void:
	var d := _make_ducking()
	d.notify_priority_started()
	d.step(0.05) # exactly the 50 ms attack time
	assert_float(d.get_ramp_t()).is_equal_approx(1.0, 0.0001)
	assert_float(d.get_last_sfx_db()).is_equal_approx(-9.0, 0.01)
	assert_float(d.get_last_ambience_db()).is_equal_approx(-9.0, 0.01)
	assert_float(d.get_last_music_db()).is_equal_approx(-6.0, 0.01)


func test_attack_partway_is_proportional() -> void:
	var d := _make_ducking()
	d.notify_priority_started()
	d.step(0.025) # half the 50 ms attack
	assert_float(d.get_ramp_t()).is_equal_approx(0.5, 0.02)
	assert_float(d.get_last_sfx_db()).is_equal_approx(-4.5, 0.1)


func test_release_returns_to_baseline_in_300ms() -> void:
	var d := _make_ducking()
	d.notify_priority_started()
	d.step(0.05) # fully ducked
	d.notify_priority_stopped()
	d.step(0.3) # exactly the 300 ms release
	assert_float(d.get_ramp_t()).is_equal_approx(0.0, 0.0001)
	assert_float(d.get_last_sfx_db()).is_equal_approx(0.0, 0.01)


func test_release_partway_is_proportional() -> void:
	var d := _make_ducking()
	d.notify_priority_started()
	d.step(0.05)
	d.notify_priority_stopped()
	d.step(0.15) # half the 300 ms release
	assert_float(d.get_ramp_t()).is_equal_approx(0.5, 0.02)


func test_music_floor_clamps_when_base_is_already_near_floor() -> void:
	var d := _make_ducking()
	d.configure_base_volumes_for_test(0.0, 0.0, -15.0) # -15 - 6 = -21, below the -18 floor
	d.notify_priority_started()
	d.step(0.05)
	assert_float(d.get_last_music_db()).is_equal_approx(-18.0, 0.01)


func test_active_priority_count_does_not_go_negative() -> void:
	var d := _make_ducking()
	d.notify_priority_stopped() # stopping with nothing active
	assert_int(d.get_active_priority_count()).is_equal(0)


func test_second_overlapping_priority_sound_keeps_it_ducked() -> void:
	var d := _make_ducking()
	d.notify_priority_started()
	d.step(0.05)
	d.notify_priority_started() # a second priority sound overlaps the first
	d.notify_priority_stopped() # the first one ends
	d.step(1.0) # plenty of time for a release to have completed, if wrongly released
	assert_float(d.get_ramp_t()).is_equal_approx(1.0, 0.0001) # still ducked - one is still active


func test_re_trigger_during_release_ramps_back_toward_ducked() -> void:
	var d := _make_ducking()
	d.notify_priority_started()
	d.step(0.05)
	d.notify_priority_stopped()
	d.step(0.15) # halfway released
	d.notify_priority_started() # a new priority sound starts mid-release
	d.step(1.0) # plenty of time to reach fully ducked again
	assert_float(d.get_ramp_t()).is_equal_approx(1.0, 0.0001)


func test_process_mode_is_always() -> void:
	var d := _make_ducking()
	assert_int(d.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
