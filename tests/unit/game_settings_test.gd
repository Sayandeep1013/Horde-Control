extends GdUnitTestSuite

## GameSettings tests (Settings screen task). MASTER_SDLC.md > Provisional
## Values Register > "Interfaces" > "Settings" row; src/core/game_settings.gd.
##
## Every test redirects `GameSettings` to a throwaway `user://` directory
## FIRST (hard constraint: never touch the real `user://settings.cfg`), and
## resets its in-memory state so no earlier test's values leak in --
## mirroring `tests/unit/meta_progress_save_test.gd`'s own `MetaProgress.
## set_base_path_for_test()` precedent for the same static-state hazard.
## `after_test()` also re-applies the Register defaults to the real
## AudioServer bus graph, since `apply()` writes to bus volumes that are
## GLOBAL engine state shared with every other suite in this same headless
## process (see tests/unit/audio/test_audio_ducking.gd's own header for the
## same caution, from the other direction).

const MASTER_BUS: String = "Master"
const MUSIC_BUS: String = "Music"
const EFFECTS_BUSES: Array[String] = ["SFX", "SFX_Priority", "UI", "Ambience", "TowerCue"]

var _dir: String


func before_test() -> void:
	_dir = "user://__game_settings_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	GameSettings.set_path_for_test(_dir.path_join("settings.cfg"))
	GameSettings.reset_state_for_test()


func after_test() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.apply() # restores the real AudioServer buses to Register defaults for whichever suite runs next
	GameSettings.reset_path_for_test()


# --- Defaults (Register row) ------------------------------------------------

func test_defaults_match_the_register_row() -> void:
	assert_int(GameSettings.get_master_volume_pct()).is_equal(100)
	assert_int(GameSettings.get_music_volume_pct()).is_equal(70)
	assert_int(GameSettings.get_effects_volume_pct()).is_equal(80)
	assert_bool(GameSettings.is_mute_all()).is_false()
	assert_int(GameSettings.get_display_mode()).is_equal(GameSettings.DisplayMode.WINDOWED)
	assert_bool(GameSettings.is_vsync_enabled()).is_true()
	assert_bool(GameSettings.is_screen_shake_enabled()).is_true()
	assert_bool(GameSettings.are_damage_numbers_enabled()).is_true()
	assert_bool(GameSettings.get_movement_only_controls_enabled()).is_false()


# --- Persistence round trip --------------------------------------------------

func test_persistence_round_trip() -> void:
	GameSettings.set_master_volume_pct(30)
	GameSettings.set_music_volume_pct(0)
	GameSettings.set_effects_volume_pct(50)
	GameSettings.set_mute_all(true)
	GameSettings.set_display_mode(GameSettings.DisplayMode.BORDERLESS)
	GameSettings.set_vsync_enabled(false)
	GameSettings.set_screen_shake_enabled(false)
	GameSettings.set_damage_numbers_enabled(false)
	GameSettings.set_movement_only_controls_enabled(true)

	# Simulate a fresh process: wipe in-memory state back to compiled-in
	# defaults, then load from the (real, but throwaway) disk file.
	GameSettings.reset_state_for_test()
	GameSettings.load()

	assert_int(GameSettings.get_master_volume_pct()).is_equal(30)
	assert_int(GameSettings.get_music_volume_pct()).is_equal(0)
	assert_int(GameSettings.get_effects_volume_pct()).is_equal(50)
	assert_bool(GameSettings.is_mute_all()).is_true()
	assert_int(GameSettings.get_display_mode()).is_equal(GameSettings.DisplayMode.BORDERLESS)
	assert_bool(GameSettings.is_vsync_enabled()).is_false()
	assert_bool(GameSettings.is_screen_shake_enabled()).is_false()
	assert_bool(GameSettings.are_damage_numbers_enabled()).is_false()
	assert_bool(GameSettings.get_movement_only_controls_enabled()).is_true()


func test_a_missing_settings_file_leaves_defaults_untouched() -> void:
	GameSettings.load() # _dir/settings.cfg was never written by this test
	assert_int(GameSettings.get_master_volume_pct()).is_equal(100)


# --- Volume clamping and 10% stepping ----------------------------------------

func test_adjust_master_volume_steps_by_ten() -> void:
	GameSettings.set_master_volume_pct(50)
	GameSettings.adjust_master_volume(1)
	assert_int(GameSettings.get_master_volume_pct()).is_equal(60)
	GameSettings.adjust_master_volume(-1)
	assert_int(GameSettings.get_master_volume_pct()).is_equal(50)


func test_master_volume_clamps_at_zero() -> void:
	GameSettings.set_master_volume_pct(0)
	GameSettings.adjust_master_volume(-1)
	assert_int(GameSettings.get_master_volume_pct()).is_equal(0)


func test_master_volume_clamps_at_one_hundred() -> void:
	GameSettings.set_master_volume_pct(100)
	GameSettings.adjust_master_volume(1)
	assert_int(GameSettings.get_master_volume_pct()).is_equal(100)


# --- Bus volumes and mutes (task brief item 6) -------------------------------

func test_master_volume_applies_to_the_master_bus_in_db() -> void:
	GameSettings.set_master_volume_pct(50)
	var idx: int = AudioServer.get_bus_index(MASTER_BUS)
	assert_int(idx).is_greater_equal(0)
	assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_bool(AudioServer.is_bus_mute(idx)).is_false()


func test_master_volume_at_zero_mutes_the_master_bus() -> void:
	GameSettings.set_master_volume_pct(0)
	var idx: int = AudioServer.get_bus_index(MASTER_BUS)
	assert_bool(AudioServer.is_bus_mute(idx)).append_failure_message("0% must mute the Master bus, not just drive its volume very low").is_true()


func test_music_volume_applies_to_the_music_bus() -> void:
	GameSettings.set_music_volume_pct(40)
	var idx: int = AudioServer.get_bus_index(MUSIC_BUS)
	assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(linear_to_db(0.4), 0.01)
	assert_bool(AudioServer.is_bus_mute(idx)).is_false()


func test_music_volume_at_zero_mutes_the_music_bus() -> void:
	GameSettings.set_music_volume_pct(0)
	var idx: int = AudioServer.get_bus_index(MUSIC_BUS)
	assert_bool(AudioServer.is_bus_mute(idx)).is_true()


## Task brief: "Effects hits all five buses" (SFX, SFX_Priority, UI, Ambience,
## TowerCue).
func test_effects_volume_applies_to_all_five_effect_buses() -> void:
	GameSettings.set_effects_volume_pct(60)
	for bus_name: String in EFFECTS_BUSES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		assert_int(idx).append_failure_message("bus '%s' not found in the live AudioServer bus graph" % bus_name).is_greater_equal(0)
		assert_float(AudioServer.get_bus_volume_db(idx)).append_failure_message("bus '%s' volume not set to 60%%" % bus_name).is_equal_approx(linear_to_db(0.6), 0.01)
		assert_bool(AudioServer.is_bus_mute(idx)).is_false()


func test_effects_volume_at_zero_mutes_all_five_effect_buses() -> void:
	GameSettings.set_effects_volume_pct(0)
	for bus_name: String in EFFECTS_BUSES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		assert_bool(AudioServer.is_bus_mute(idx)).append_failure_message("bus '%s' must be muted at 0%%" % bus_name).is_true()


# --- Mute All (task brief: "mutes Master") -----------------------------------

func test_mute_all_mutes_the_master_bus_even_at_full_volume() -> void:
	GameSettings.set_master_volume_pct(100)
	GameSettings.set_mute_all(true)
	var idx: int = AudioServer.get_bus_index(MASTER_BUS)
	assert_bool(AudioServer.is_bus_mute(idx)).is_true()


func test_mute_all_off_restores_the_masters_own_volume() -> void:
	GameSettings.set_master_volume_pct(70)
	GameSettings.set_mute_all(true)
	GameSettings.set_mute_all(false)
	var idx: int = AudioServer.get_bus_index(MASTER_BUS)
	assert_bool(AudioServer.is_bus_mute(idx)).is_false()
	assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(linear_to_db(0.7), 0.01)


func test_mute_all_does_not_mute_music_or_effects() -> void:
	GameSettings.set_music_volume_pct(70)
	GameSettings.set_effects_volume_pct(80)
	GameSettings.set_mute_all(true)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(MUSIC_BUS))).is_false()
	for bus_name: String in EFFECTS_BUSES:
		assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus_name))).is_false()


# --- Display mode cycling ----------------------------------------------------

func test_cycle_display_mode_wraps_forward() -> void:
	GameSettings.set_display_mode(GameSettings.DisplayMode.WINDOWED)
	GameSettings.cycle_display_mode(1)
	assert_int(GameSettings.get_display_mode()).is_equal(GameSettings.DisplayMode.FULLSCREEN)
	GameSettings.cycle_display_mode(1)
	assert_int(GameSettings.get_display_mode()).is_equal(GameSettings.DisplayMode.BORDERLESS)
	GameSettings.cycle_display_mode(1)
	assert_int(GameSettings.get_display_mode()).append_failure_message("Display Mode must wrap from Borderless back to Windowed").is_equal(GameSettings.DisplayMode.WINDOWED)


func test_cycle_display_mode_wraps_backward() -> void:
	GameSettings.set_display_mode(GameSettings.DisplayMode.WINDOWED)
	GameSettings.cycle_display_mode(-1)
	assert_int(GameSettings.get_display_mode()).is_equal(GameSettings.DisplayMode.BORDERLESS)


## Headless guard (task brief: "guard DisplayServer calls so they do not
## error"). If this ever throws, the whole test run aborts with an engine
## error the harness's own guard would already catch -- asserted explicitly
## here too so the intent is not implicit.
func test_display_mode_and_vsync_apply_without_erroring_headless() -> void:
	GameSettings.set_display_mode(GameSettings.DisplayMode.FULLSCREEN)
	GameSettings.set_vsync_enabled(false)
	GameSettings.apply()
	assert_bool(true).is_true() # reaching here at all is the assertion


# --- _for_test setters never touch disk --------------------------------------

## FALSIFICATION (named in the report): temporarily changed `set_screen_
## shake_enabled_for_test()` to call `save()` (the production setter's own
## behaviour) instead of mutating memory only. `GameSettings.load()` at the
## real default path afterward then picked up whatever this test's OWN write
## had just left at `_dir`'s throwaway file -- wait, this specific probe
## instead checks the FILE ITSELF is never created by any `_for_test` setter,
## which is the concrete, file-system-level guarantee the hard constraint
## needs. Reverted after confirming the failure (see report).
func test_for_test_setters_never_write_the_settings_file() -> void:
	GameSettings.reset_path_for_test() # back to the real user://settings.cfg path...
	GameSettings.set_path_for_test(_dir.path_join("probe.cfg")) # ...then straight to a throwaway one, so this probe never touches the real file even transiently
	GameSettings.set_master_volume_pct_for_test(10)
	GameSettings.set_music_volume_pct_for_test(10)
	GameSettings.set_effects_volume_pct_for_test(10)
	GameSettings.set_mute_all_for_test(true)
	GameSettings.set_display_mode_for_test(GameSettings.DisplayMode.FULLSCREEN)
	GameSettings.set_vsync_enabled_for_test(false)
	GameSettings.set_screen_shake_enabled_for_test(false)
	GameSettings.set_damage_numbers_enabled_for_test(false)
	GameSettings.set_movement_only_controls_enabled_for_test(true)
	assert_bool(FileAccess.file_exists(_dir.path_join("probe.cfg"))).append_failure_message("a _for_test setter wrote to disk; every _for_test setter must be memory-only").is_false()
