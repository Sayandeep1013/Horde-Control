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
##
## ## Blind review fix: base volumes track GameSettings live
## `configure_base_volumes_for_test()` sets `_use_test_base_volumes = true`
## (audio_ducking.gd's own header, "BLOCKER FIX"), so every test above this
## point never touches `GameSettings` at all -- fully hermetic, exactly as
## before. The tests BELOW this point instead exercise the real, un-stubbed
## path: a plain `AudioDucking.new()` with no `configure_base_volumes_for_
## test()` call reads its bases from `GameSettings` on every `step()`. Every
## one of those tests uses a `_for_test` setter only (never a path
## redirection, never a disk write) and resets `GameSettings` state in
## `before_test()`/`after_test()` so it never leaks into another suite.

func before_test() -> void:
	GameSettings.reset_state_for_test()


func after_test() -> void:
	GameSettings.reset_state_for_test()


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


# --- Blind review fix: base volumes track GameSettings live (BLOCKER) -------

## FALSIFICATION (named in the report): temporarily reverted `step()` to call
## a one-time `_capture_base_volumes_from_audio_server()` in `_ready()`
## instead of `_refresh_base_volumes_from_settings()` on every call (the
## pre-fix behaviour) -- this test failed, because the real Music bus's own
## `volume_db` at the moment `AudioDucking.new()` ran was whatever an EARLIER
## test in this process happened to leave it at, not `linear_to_db(0.3)`.
## Reverted after confirming the failure.
func test_music_bus_reflects_a_live_game_settings_change() -> void:
	GameSettings.set_music_volume_pct_for_test(30)
	var d: AudioDucking = auto_free(AudioDucking.new())
	add_child(d)
	d.step(0.016) # no priority sound active -- fully unducked, the base passes straight through
	var idx: int = AudioServer.get_bus_index("Music")
	assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(linear_to_db(0.3), 0.01)


func test_effects_volume_change_reaches_sfx_and_ambience_live() -> void:
	GameSettings.set_effects_volume_pct_for_test(40)
	var d: AudioDucking = auto_free(AudioDucking.new())
	add_child(d)
	d.step(0.016)
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	var ambience_idx: int = AudioServer.get_bus_index("Ambience")
	assert_float(AudioServer.get_bus_volume_db(sfx_idx)).is_equal_approx(linear_to_db(0.4), 0.01)
	assert_float(AudioServer.get_bus_volume_db(ambience_idx)).is_equal_approx(linear_to_db(0.4), 0.01)


## The exact scenario named in the review: a Settings change made WHILE a
## priority cue is ducking everything must still reach the bus on the very
## next tick, not be reverted by ducking's own write.
func test_a_settings_change_reaches_the_bus_even_while_fully_ducked() -> void:
	GameSettings.set_music_volume_pct_for_test(70)
	var d: AudioDucking = auto_free(AudioDucking.new())
	add_child(d)
	d.notify_priority_started()
	d.step(0.05) # fully ducked at the OLD 70% base
	GameSettings.set_music_volume_pct_for_test(30) # pause -> Settings -> lower Music, mid-cue
	d.step(0.001) # a tiny tick: the ramp barely moves, but the base must already be the new one
	var idx: int = AudioServer.get_bus_index("Music")
	var expected: float = maxf(linear_to_db(0.3) - AudioDucking.DUCK_MUSIC_DB, AudioDucking.MUSIC_FLOOR_DB)
	assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(expected, 0.05)


## The mute/0% interaction named in the review: AudioDucking only ever
## writes `volume_db`, never `set_bus_mute()`, so a bus GameSettings muted at
## 0% must stay silent no matter what dB value ducking computes for it.
func test_ducking_never_unmutes_a_bus_game_settings_muted_at_zero_percent() -> void:
	GameSettings.set_music_volume_pct_for_test(0)
	var idx: int = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(idx, true) # what GameSettings.set_music_volume_pct() applies for real at 0%
	var d: AudioDucking = auto_free(AudioDucking.new())
	add_child(d)
	d.step(0.016)
	assert_bool(AudioServer.is_bus_mute(idx)).append_failure_message("AudioDucking must never unmute a bus GameSettings muted at 0%").is_true()
	AudioServer.set_bus_mute(idx, false) # cleanup -- Music is shared global AudioServer state
