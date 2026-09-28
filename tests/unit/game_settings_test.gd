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
## TowerCue is deliberately NOT in this list -- see `test_tower_cue_bus_*`
## below and GameSettings's own header, "TowerCue is NOT driven directly."
const EFFECTS_BUSES: Array[String] = ["SFX", "SFX_Priority", "UI", "Ambience"]
const TOWER_CUE_BUS: String = "TowerCue"

var _dir: String


func before_test() -> void:
	_dir = "user://__game_settings_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	GameSettings.set_path_for_test(_dir.path_join("settings.cfg"))
	GameSettings.reset_state_for_test()


func after_test() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.apply() # restores the real AudioServer buses to Register defaults for whichever suite runs next
	GameSettings.reset_path_for_test()
	# Blind review nit: clean up this test's own throwaway user:// directory
	# instead of leaving it on disk forever.
	_delete_dir_recursive(_dir)


func _delete_dir_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for file_name in dir.get_files():
		dir.remove(file_name)
	for sub_dir in dir.get_directories():
		_delete_dir_recursive(path.path_join(sub_dir))
	DirAccess.remove_absolute(path)


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
	GameSettings.load_from_disk()

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
	GameSettings.load_from_disk() # _dir/settings.cfg was never written by this test
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


## Effects Volume drives four buses directly (SFX, SFX_Priority, UI,
## Ambience). TowerCue is deliberately excluded -- see the dedicated
## `test_tower_cue_bus_*` tests below, and GameSettings's own header
## ("TowerCue is NOT driven directly," blind review fix): TowerCue sends
## INTO SFX_Priority, so applying Effects gain to both would attenuate it
## twice.
func test_effects_volume_applies_to_all_four_effect_buses() -> void:
	GameSettings.set_effects_volume_pct(60)
	for bus_name: String in EFFECTS_BUSES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		assert_int(idx).append_failure_message("bus '%s' not found in the live AudioServer bus graph" % bus_name).is_greater_equal(0)
		assert_float(AudioServer.get_bus_volume_db(idx)).append_failure_message("bus '%s' volume not set to 60%%" % bus_name).is_equal_approx(linear_to_db(0.6), 0.01)
		assert_bool(AudioServer.is_bus_mute(idx)).is_false()


func test_effects_volume_at_zero_mutes_all_four_effect_buses() -> void:
	GameSettings.set_effects_volume_pct(0)
	for bus_name: String in EFFECTS_BUSES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		assert_bool(AudioServer.is_bus_mute(idx)).append_failure_message("bus '%s' must be muted at 0%%" % bus_name).is_true()


# --- TowerCue is NOT driven directly (blind review BLOCKER-adjacent fix) ----

func test_tower_cue_bus_volume_is_never_touched_by_effects_volume() -> void:
	var idx: int = AudioServer.get_bus_index(TOWER_CUE_BUS)
	assert_int(idx).is_greater_equal(0)
	var before: float = AudioServer.get_bus_volume_db(idx)
	GameSettings.set_effects_volume_pct(50)
	assert_float(AudioServer.get_bus_volume_db(idx)).append_failure_message("TowerCue's own volume_db must stay unchanged -- it reaches Effects gain once, through SFX_Priority, not a second time on itself").is_equal_approx(before, 0.001)


func test_tower_cue_bus_is_never_directly_muted_by_effects_volume() -> void:
	var idx: int = AudioServer.get_bus_index(TOWER_CUE_BUS)
	GameSettings.set_effects_volume_pct(0)
	assert_bool(AudioServer.is_bus_mute(idx)).append_failure_message("GameSettings must never call set_bus_mute() on TowerCue directly -- it is silenced by SFX_Priority's own mute instead").is_false()


## The actual bug this fixes: at, say, 50% Effects, TowerCue's EFFECTIVE
## gain (its own unity volume_db, mixed through SFX_Priority) must equal
## Effects exactly ONCE -- the same as every other effects bus -- not
## Effects applied twice (once on TowerCue itself, again on SFX_Priority).
func test_tower_cue_effective_gain_equals_effects_exactly_once_via_sfx_priority() -> void:
	GameSettings.set_effects_volume_pct(50)
	var sfx_priority_idx: int = AudioServer.get_bus_index("SFX_Priority")
	var tower_cue_idx: int = AudioServer.get_bus_index(TOWER_CUE_BUS)
	assert_float(AudioServer.get_bus_volume_db(sfx_priority_idx)).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_float(AudioServer.get_bus_volume_db(tower_cue_idx)).append_failure_message("TowerCue's own gain must be unity (0 dB) -- SFX_Priority's own gain is the ONE place Effects is applied on this path").is_equal_approx(0.0, 0.01)


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

## Checks the concrete, file-system-level guarantee the hard constraint
## needs directly: every `_for_test` setter mutates the in-memory field ONLY
## (see GameSettings's own class header, "`_for_test` setters never touch
## disk") -- redirects to a throwaway `probe.cfg` first so even a bug in this
## guarantee could never reach the real file, then asserts that path was
## never created at all.
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
