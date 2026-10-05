extends RefCounted
class_name GameSettings

## GameSettings (Settings screen task). MASTER_SDLC.md > Provisional Values
## Register > "Interfaces" > "Settings" row (defaults, 10% volume step, the
## four sound-effect buses); docs/19_UI_UX.md > "Settings" section; Review
## Decision Log D121.
##
## A static class, like UiTheme/UiPalette/MenuFrame -- NOT a sixth Autoload
## (CLAUDE.md hard constraint). ConfigFile persistence at `user://settings.cfg`
## by default, with an injectable path (`set_path_for_test`) so a test never
## touches the real file, matching this project's established `MetaProgress.
## set_base_path_for_test()` precedent (src/meta/meta_progress.gd) for the
## same reason.
##
## ## Boot-apply site (task brief: "pick the least invasive, document it")
## `apply()` is called once from `src/ui/title_screen.gd`'s `_ready()` --
## `run/main_scene` (project.godot), the one scene every real launch passes
## through before anything else -- NOT from an Autoload's `_ready()`. Every
## Autoload (`BootCheck` included) boots once per PROCESS, which means the
## whole gdUnit4 headless suite -- every single test file, whether or not it
## has anything to do with Settings -- would otherwise read (and, since
## AudioServer/DisplayServer calls have side effects on the running engine,
## partially apply) whatever `user://settings.cfg` happens to exist on the
## machine running the tests, before any test gets a chance to call
## `set_path_for_test()` first. That would violate this task's own hard
## constraint ("tests must never touch the real user://settings.cfg") on
## EVERY test run, not just ones that exercise Settings. Gating the load/apply
## behind the title screen instead means only a real launch (or a test that
## explicitly instantiates TitleScreen) ever reaches `user://settings.cfg` at
## all; AudioServer bus volumes and the window's display mode are global
## engine state that survives the later scene changes to the Hub and into a
## run, so applying once at the title is sufficient -- no other scene needs
## its own boot-apply call.
##
## ## Bus names (verified against default_bus_layout.tres, not assumed)
## Master (bus 0, unnamed in the .tres since it is the engine's own implicit
## first bus), Music, SFX, SFX_Priority, UI, Ambience, TowerCue -- six buses
## total, matching MASTER_SDLC.md > Audio > "Buses" row ("Master -> Music,
## SFX, SFX_Priority (<- TowerCue), UI, Ambience -- six buses (C-TOWERCUE)").
## Master volume drives the Master bus; Music volume drives Music; "Sound
## effects" drives SFX, SFX_Priority, UI, and Ambience.
##
## ## TowerCue is NOT driven directly (blind review fix)
## `TowerCue` sends INTO `SFX_Priority` (default_bus_layout.tres: `bus/6/send
## = &"SFX_Priority"`), which is itself one of the four buses `EFFECTS_BUSES`
## already drives. A prior version of this file also applied the Sound
## Effects gain to `TowerCue`'s own `volume_db` directly, which attenuated
## the Tower-damage cue TWICE for the same setting (once on TowerCue itself,
## again when SFX_Priority mixed it in) -- so at, say, 50% Sound Effects, the
## cue was quieter than every other effect on the SAME slider. `TowerCue`'s
## own `volume_db` is left untouched (unity gain, its `default_bus_layout.tres`
## default), so its EFFECTIVE gain equals Sound Effects exactly once, via the
## one send it already goes through. Muting still reaches it correctly:
## muting a bus silences everything mixed INTO it before that bus's own
## output stage, so `SFX_Priority` muted at 0% Sound Effects silences
## `TowerCue` too, with no direct mute needed here.
##
## ## 0% = muted, not silent-by-volume (task brief)
## A bus at exactly 0% is muted via `AudioServer.set_bus_mute()`, not merely
## driven to a very negative dB -- `linear_to_db(0.0)` is `-INF`, which is
## legal but pointless to store when a dedicated mute flag already exists and
## reads far better from a save file. `Mute all` mutes the Master bus
## independently of `master_volume_pct` (task brief: "Mute all (on/off) -
## mutes Master"); un-muting restores whatever percentage was already set.
##
## ## Headless guard (task brief: "guard DisplayServer calls so they do not
## error")
## Every `DisplayServer.window_*` call is skipped when
## `DisplayServer.get_name() == "headless"` -- gdUnit4's own runner, and this
## project's `--headless` CLI convention throughout (see src/camera/
## game_camera.gd's own `_setup_vignette()` for the identical guard).
## AudioServer calls need no such guard: the bus graph exists (and answers
## `get_bus_index()`/`set_bus_volume_db()`/`set_bus_mute()` correctly) even
## under the headless "Dummy" audio driver.
##
## ## `_for_test` setters never touch disk (existing hard constraint, and the
## Movement-only setting's own precedent)
## `src/ui/settings_menu.gd`'s pre-existing `_static_last_value` was a
## process-lifetime value with NO disk write at all; `tests/unit/
## skill_tree_screen_test.gd`'s `after_test()` already calls `SettingsMenu.
## set_movement_only_controls_enabled_for_test(false)` with no test path of
## its own set up. Routing that setting through this file (task brief) must
## not turn that pre-existing, path-agnostic test seam into one that suddenly
## writes to the real `user://settings.cfg` -- so EVERY `..._for_test` setter
## below mutates the in-memory field ONLY (no `apply()`, no `save()`). A test
## that wants to exercise real persistence calls `set_path_for_test()` first
## and then the ordinary production setters, exactly like `MetaProgress`'s
## own suites do.
##
## ## `AudioDucking` reads its base volumes from here, live (blind review fix)
## `src/audio/audio_ducking.gd` used to capture Music/SFX/Ambience bus dB
## ONCE in its own `_ready()` and rewrite those same buses every frame from
## that one-time snapshot -- so a Settings volume change made mid-run (pause
## -> Settings -> back) was silently reverted by the very next ducking tick.
## `AudioDucking.step()` now reads `volume_pct_to_db(get_music_volume_pct())`
## / `volume_pct_to_db(get_effects_volume_pct())` fresh every call instead of
## its own captured snapshot, so a live change is reflected on the very next
## tick. `volume_pct_to_db()` is public (not `_volume_db`, its name before
## this fix) specifically so `AudioDucking` shares the SAME pct->dB
## conversion this file's own appliers use, rather than a second, drifting
## copy of the same formula.
##
## ## `load()` renamed to `load_from_disk()` (blind review nit)
## `load()` shadowed the GDScript global `load()` (the resource-loading
## function every other file in this project calls constantly) within any
## scope that also called `GameSettings.load()` unqualified -- harmless here
## since this file never calls the global `load()` itself, but a needless
## foot-gun for any future edit. Renamed; every call site updated
## (`src/ui/title_screen.gd`, the test suites).

enum DisplayMode { WINDOWED = 0, FULLSCREEN = 1, BORDERLESS = 2 }

const DEFAULT_PATH: String = "user://settings.cfg"

const SECTION_AUDIO: String = "audio"
const SECTION_VIDEO: String = "video"
const SECTION_GAMEPLAY: String = "gameplay"

## Register > "Settings" row defaults.
const DEFAULT_MASTER_VOLUME_PCT: int = 100
const DEFAULT_MUSIC_VOLUME_PCT: int = 70
const DEFAULT_EFFECTS_VOLUME_PCT: int = 80
const DEFAULT_MUTE_ALL: bool = false
const DEFAULT_DISPLAY_MODE: int = DisplayMode.WINDOWED
const DEFAULT_VSYNC_ENABLED: bool = true
const DEFAULT_SCREEN_SHAKE_ENABLED: bool = true
const DEFAULT_DAMAGE_NUMBERS_ENABLED: bool = true
const DEFAULT_MOVEMENT_ONLY_ENABLED: bool = false

## Register > "Settings" row: "each 0-100% in 10% steps".
const VOLUME_STEP_PCT: int = 10
const VOLUME_MIN_PCT: int = 0
const VOLUME_MAX_PCT: int = 100

const MASTER_BUS: String = "Master"
const MUSIC_BUS: String = "Music"
## Register > "Settings" row: the "Sound effects" volume drives all four of
## these (default_bus_layout.tres; MASTER_SDLC.md > Audio > "Buses").
## `TowerCue` is deliberately NOT in this list -- see class header, "TowerCue
## is NOT driven directly."
const EFFECTS_BUSES: Array[String] = ["SFX", "SFX_Priority", "UI", "Ambience"]
## Named for tests/comments that need to point at it without a magic string
## -- never iterated over for a direct volume/mute write (see class header).
const TOWER_CUE_BUS: String = "TowerCue"

const DISPLAY_MODE_COUNT: int = 3 # DisplayMode has exactly 3 named values

## Silent floor used instead of `linear_to_db(0.0)` (`-INF`) when a 0%
## bus is also, redundantly, given a volume_db (mute is what actually
## silences it; this value is never audible either way).
const SILENT_DB: float = -80.0

static var _path: String = DEFAULT_PATH

static var _master_volume_pct: int = DEFAULT_MASTER_VOLUME_PCT
static var _music_volume_pct: int = DEFAULT_MUSIC_VOLUME_PCT
static var _effects_volume_pct: int = DEFAULT_EFFECTS_VOLUME_PCT
static var _mute_all: bool = DEFAULT_MUTE_ALL
static var _display_mode: int = DEFAULT_DISPLAY_MODE
static var _vsync_enabled: bool = DEFAULT_VSYNC_ENABLED
static var _screen_shake_enabled: bool = DEFAULT_SCREEN_SHAKE_ENABLED
static var _damage_numbers_enabled: bool = DEFAULT_DAMAGE_NUMBERS_ENABLED
static var _movement_only_controls_enabled: bool = DEFAULT_MOVEMENT_ONLY_ENABLED


# --- Persistence -------------------------------------------------------------

## Reads `_path` into the in-memory fields. A missing or unreadable file (a
## first launch, or a fresh test's throwaway directory) leaves every field at
## whatever it already held (its compiled-in default, unless a test set one
## via a `_for_test` setter first) -- matching `MetaProgress`'s own "fresh
## profile" precedent (src/meta/meta_progress.gd's header) rather than
## treating a missing file as an error.
static func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	_master_volume_pct = _snap_to_step(int(cfg.get_value(SECTION_AUDIO, "master_volume_pct", _master_volume_pct)))
	_music_volume_pct = _snap_to_step(int(cfg.get_value(SECTION_AUDIO, "music_volume_pct", _music_volume_pct)))
	_effects_volume_pct = _snap_to_step(int(cfg.get_value(SECTION_AUDIO, "effects_volume_pct", _effects_volume_pct)))
	_mute_all = bool(cfg.get_value(SECTION_AUDIO, "mute_all", _mute_all))
	_display_mode = _clamp_display_mode(int(cfg.get_value(SECTION_VIDEO, "display_mode", _display_mode)))
	_vsync_enabled = bool(cfg.get_value(SECTION_VIDEO, "vsync_enabled", _vsync_enabled))
	_screen_shake_enabled = bool(cfg.get_value(SECTION_GAMEPLAY, "screen_shake_enabled", _screen_shake_enabled))
	_damage_numbers_enabled = bool(cfg.get_value(SECTION_GAMEPLAY, "damage_numbers_enabled", _damage_numbers_enabled))
	_movement_only_controls_enabled = bool(cfg.get_value(SECTION_GAMEPLAY, "movement_only_controls_enabled", _movement_only_controls_enabled))


## Writes every field to `_path`, creating its parent directory first (a
## fresh `user://` profile, or a test's throwaway directory, may not exist
## yet -- `make_dir_recursive_absolute()` is a safe no-op if it already does).
static func save() -> void:
	var dir: String = _path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_AUDIO, "master_volume_pct", _master_volume_pct)
	cfg.set_value(SECTION_AUDIO, "music_volume_pct", _music_volume_pct)
	cfg.set_value(SECTION_AUDIO, "effects_volume_pct", _effects_volume_pct)
	cfg.set_value(SECTION_AUDIO, "mute_all", _mute_all)
	cfg.set_value(SECTION_VIDEO, "display_mode", _display_mode)
	cfg.set_value(SECTION_VIDEO, "vsync_enabled", _vsync_enabled)
	cfg.set_value(SECTION_GAMEPLAY, "screen_shake_enabled", _screen_shake_enabled)
	cfg.set_value(SECTION_GAMEPLAY, "damage_numbers_enabled", _damage_numbers_enabled)
	cfg.set_value(SECTION_GAMEPLAY, "movement_only_controls_enabled", _movement_only_controls_enabled)
	cfg.save(_path)


## Pushes every field onto the engine (AudioServer bus volumes/mutes,
## DisplayServer window mode/vsync). Called once at boot (see class header,
## "Boot-apply site") and, piecemeal, by every production setter below so a
## change takes effect immediately (task brief: "left/right changes the
## value immediately (applied + saved)").
static func apply() -> void:
	_apply_master_bus()
	_apply_music_bus()
	_apply_effects_buses()
	_apply_display_mode()
	_apply_vsync()


# --- Getters -------------------------------------------------------------

static func get_master_volume_pct() -> int:
	return _master_volume_pct


static func get_music_volume_pct() -> int:
	return _music_volume_pct


static func get_effects_volume_pct() -> int:
	return _effects_volume_pct


static func is_mute_all() -> bool:
	return _mute_all


static func get_display_mode() -> int:
	return _display_mode


static func is_vsync_enabled() -> bool:
	return _vsync_enabled


static func is_screen_shake_enabled() -> bool:
	return _screen_shake_enabled


static func are_damage_numbers_enabled() -> bool:
	return _damage_numbers_enabled


static func get_movement_only_controls_enabled() -> bool:
	return _movement_only_controls_enabled


# --- Production setters (apply + save immediately) --------------------------

static func set_master_volume_pct(pct: int) -> void:
	_master_volume_pct = _clamp_pct(_snap_to_step(pct))
	_apply_master_bus()
	save()


static func set_music_volume_pct(pct: int) -> void:
	_music_volume_pct = _clamp_pct(_snap_to_step(pct))
	_apply_music_bus()
	save()


static func set_effects_volume_pct(pct: int) -> void:
	_effects_volume_pct = _clamp_pct(_snap_to_step(pct))
	_apply_effects_buses()
	save()


## One step (+-`VOLUME_STEP_PCT`) at a time -- the SettingsMenu row's own
## left/right handler, so it never has to restate the step size.
static func adjust_master_volume(direction: int) -> void:
	set_master_volume_pct(_master_volume_pct + direction * VOLUME_STEP_PCT)


static func adjust_music_volume(direction: int) -> void:
	set_music_volume_pct(_music_volume_pct + direction * VOLUME_STEP_PCT)


static func adjust_effects_volume(direction: int) -> void:
	set_effects_volume_pct(_effects_volume_pct + direction * VOLUME_STEP_PCT)


static func set_mute_all(enabled: bool) -> void:
	_mute_all = enabled
	_apply_master_bus()
	save()


static func set_display_mode(mode: int) -> void:
	_display_mode = _clamp_display_mode(mode)
	_apply_display_mode()
	save()


static func cycle_display_mode(direction: int) -> void:
	set_display_mode(wrapi(_display_mode + direction, 0, DISPLAY_MODE_COUNT))


static func set_vsync_enabled(enabled: bool) -> void:
	_vsync_enabled = enabled
	_apply_vsync()
	save()


## No engine push: `src/camera/game_camera.gd`'s `add_trauma()` reads this
## flag directly at the point of effect (task brief: "gate the shake").
static func set_screen_shake_enabled(enabled: bool) -> void:
	_screen_shake_enabled = enabled
	save()


## No engine push: `src/fx/damage_number_fx.gd`'s `spawn()` reads this flag
## directly at the point of effect (task brief: "gate ... static spawn()").
static func set_damage_numbers_enabled(enabled: bool) -> void:
	_damage_numbers_enabled = enabled
	save()


## The one setting this file did not invent (task brief): the pre-existing
## Movement-only controls toggle, now routed through here instead of
## `SettingsMenu`'s own former `_static_last_value` -- see
## `src/ui/settings_menu.gd`'s header for the thin static wrappers that keep
## `SettingsMenu.get_movement_only_controls_enabled()` /
## `set_movement_only_controls_enabled_for_test()` working for their one
## existing caller (`src/ui/skill_tree_screen.gd`).
static func set_movement_only_controls_enabled(enabled: bool) -> void:
	_movement_only_controls_enabled = enabled
	save()


# --- Test-only setters (memory only -- see class header) ---------------------

static func set_master_volume_pct_for_test(pct: int) -> void:
	_master_volume_pct = _clamp_pct(_snap_to_step(pct))


static func set_music_volume_pct_for_test(pct: int) -> void:
	_music_volume_pct = _clamp_pct(_snap_to_step(pct))


static func set_effects_volume_pct_for_test(pct: int) -> void:
	_effects_volume_pct = _clamp_pct(_snap_to_step(pct))


static func set_mute_all_for_test(enabled: bool) -> void:
	_mute_all = enabled


static func set_display_mode_for_test(mode: int) -> void:
	_display_mode = _clamp_display_mode(mode)


static func set_vsync_enabled_for_test(enabled: bool) -> void:
	_vsync_enabled = enabled


static func set_screen_shake_enabled_for_test(enabled: bool) -> void:
	_screen_shake_enabled = enabled


static func set_damage_numbers_enabled_for_test(enabled: bool) -> void:
	_damage_numbers_enabled = enabled


static func set_movement_only_controls_enabled_for_test(enabled: bool) -> void:
	_movement_only_controls_enabled = enabled


## Injectable path (task brief: "an injectable path for tests"), mirroring
## `MetaProgress.set_base_path_for_test()`. `apply()` itself never touches
## disk, so a test may call it freely after a `_for_test` setter to check the
## engine actually received the value, with no path redirection needed for
## that half of the check.
static func set_path_for_test(path: String) -> void:
	_path = path


static func reset_path_for_test() -> void:
	_path = DEFAULT_PATH


## Resets every in-memory field to its Register default, with no disk I/O --
## a test's `after_test()` calls this (and `reset_path_for_test()`) so this
## static class's state never leaks into whichever suite happens to run next
## in the same headless process (the same hazard `SettingsMenu`'s own former
## `_static_last_value` header already named).
static func reset_state_for_test() -> void:
	_master_volume_pct = DEFAULT_MASTER_VOLUME_PCT
	_music_volume_pct = DEFAULT_MUSIC_VOLUME_PCT
	_effects_volume_pct = DEFAULT_EFFECTS_VOLUME_PCT
	_mute_all = DEFAULT_MUTE_ALL
	_display_mode = DEFAULT_DISPLAY_MODE
	_vsync_enabled = DEFAULT_VSYNC_ENABLED
	_screen_shake_enabled = DEFAULT_SCREEN_SHAKE_ENABLED
	_damage_numbers_enabled = DEFAULT_DAMAGE_NUMBERS_ENABLED
	_movement_only_controls_enabled = DEFAULT_MOVEMENT_ONLY_ENABLED


# --- Internals -----------------------------------------------------------

static func _clamp_pct(pct: int) -> int:
	return clampi(pct, VOLUME_MIN_PCT, VOLUME_MAX_PCT)


static func _snap_to_step(pct: int) -> int:
	return int(roundi(float(pct) / float(VOLUME_STEP_PCT)) * VOLUME_STEP_PCT)


static func _clamp_display_mode(mode: int) -> int:
	return clampi(mode, 0, DISPLAY_MODE_COUNT - 1)


## `pct <= 0` never reaches `linear_to_db()` -- see class header, "0% = muted".
## Public (not `_volume_db`, its name before the blind review fix) so
## `src/audio/audio_ducking.gd` shares this SAME pct->dB conversion instead
## of a second, drifting copy of the same formula -- see class header,
## "AudioDucking reads its base volumes from here, live."
static func volume_pct_to_db(pct: int) -> float:
	if pct <= 0:
		return SILENT_DB
	return linear_to_db(float(pct) / 100.0)


static func _apply_master_bus() -> void:
	var idx: int = AudioServer.get_bus_index(MASTER_BUS)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, volume_pct_to_db(_master_volume_pct))
	AudioServer.set_bus_mute(idx, _mute_all or _master_volume_pct <= 0)


static func _apply_music_bus() -> void:
	var idx: int = AudioServer.get_bus_index(MUSIC_BUS)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, volume_pct_to_db(_music_volume_pct))
	AudioServer.set_bus_mute(idx, _music_volume_pct <= 0)


static func _apply_effects_buses() -> void:
	for bus_name: String in EFFECTS_BUSES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			continue # named bus not present in this build's default_bus_layout.tres -- skip rather than error
		AudioServer.set_bus_volume_db(idx, volume_pct_to_db(_effects_volume_pct))
		AudioServer.set_bus_mute(idx, _effects_volume_pct <= 0)


static func _apply_display_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if OS.has_feature("mobile"):
		return # D146: a phone window is always the whole screen; the saved desktop mode must not touch it.
	match _display_mode:
		DisplayMode.FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_: # DisplayMode.WINDOWED
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


static func _apply_vsync() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED)
