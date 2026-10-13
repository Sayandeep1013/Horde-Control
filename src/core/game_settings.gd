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
const SECTION_ACCESSIBILITY: String = "accessibility"
const SECTION_CONTROLS: String = "controls"

## Register > "Settings" row defaults.
const DEFAULT_MASTER_VOLUME_PCT: int = 100
const DEFAULT_MUSIC_VOLUME_PCT: int = 70
const DEFAULT_EFFECTS_VOLUME_PCT: int = 80
const DEFAULT_MUTE_ALL: bool = false
const DEFAULT_DISPLAY_MODE: int = DisplayMode.FULLSCREEN # D375: a desktop game opens full screen (author, 2026-10-13: "the game doesnt go full screen")
## The saved key. `display_mode_v2` replaced `display_mode` (D375) so a profile saved
## under the old Windowed default opens full screen once; a later choice is kept.
const DISPLAY_MODE_KEY: String = "display_mode_v2"
const DEFAULT_VSYNC_ENABLED: bool = true
const DEFAULT_DAMAGE_NUMBERS_ENABLED: bool = true
const DEFAULT_MOVEMENT_ONLY_ENABLED: bool = false
# v1.0 shared contract keys (WP0, decision D174; docs/31 §8.4). Readers:
# WP-COMBAT (auto-cast), WP-ENEMIES (enemy outlines), WP-UI (HUD scale,
# overhead bars, reduce flashing). WP-UI adds the Settings rows for them.
const DEFAULT_AUTO_CAST_DESKTOP: bool = false
const DEFAULT_AUTO_CAST_TOUCH: bool = true
const DEFAULT_SHOW_OVERHEAD_BARS: bool = true
const DEFAULT_REDUCE_FLASHING: bool = false
const DEFAULT_ENEMY_OUTLINES: bool = false
const DEFAULT_HUD_SCALE_PCT: int = 100
const HUD_SCALE_MIN_PCT: int = 75
const HUD_SCALE_MAX_PCT: int = 150
const HUD_SCALE_STEP_PCT: int = 5
# WP-UI (decision D230+; docs/31 §8.4, Register "v1.0 Interface").
const DEFAULT_INTERFACE_VOLUME_PCT: int = 80
const DEFAULT_SCREEN_SHAKE_PCT: int = 100
const SCREEN_SHAKE_STEP_PCT: int = 10
const DEFAULT_PAUSE_WHEN_UNFOCUSED: bool = true
const DEFAULT_SHOW_FPS: bool = false
# PT-UI (docs/33 A4): first-encounter explainer cards; the card's checkbox clears it.
const DEFAULT_SHOW_FIRST_TIME_TIPS: bool = true
const DEFAULT_WINDOW_SIZE_INDEX: int = 2
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
## 0 = Unlimited (Engine.max_fps = 0).
const FPS_LIMITS: Array[int] = [30, 60, 120, 144, 240, 0]
const DEFAULT_FPS_LIMIT: int = 0
## Keyboard actions the Controls tab can rebind (docs/31 §8.4). Two key slots
## each: the first and one alternative. Gamepad/mouse events are never touched.
const REBINDABLE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right", &"dash", &"battle_skill", &"pause"]
const BINDING_SLOTS: int = 2

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
const EFFECTS_BUSES: Array[String] = ["SFX", "SFX_Priority", "Ambience"]
## WP-UI: the UI bus has its own Interface volume (was part of Effects).
const INTERFACE_BUS: String = "UI"
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
static var _damage_numbers_enabled: bool = DEFAULT_DAMAGE_NUMBERS_ENABLED
static var _movement_only_controls_enabled: bool = DEFAULT_MOVEMENT_ONLY_ENABLED
static var _auto_cast_set: bool = false # false = never chosen; default follows the device
static var _auto_cast_enabled: bool = DEFAULT_AUTO_CAST_DESKTOP
static var _show_overhead_bars: bool = DEFAULT_SHOW_OVERHEAD_BARS
static var _reduce_flashing: bool = DEFAULT_REDUCE_FLASHING
static var _enemy_outlines: bool = DEFAULT_ENEMY_OUTLINES
static var _hud_scale_pct: int = DEFAULT_HUD_SCALE_PCT
static var _interface_volume_pct: int = DEFAULT_INTERFACE_VOLUME_PCT
static var _screen_shake_pct: int = DEFAULT_SCREEN_SHAKE_PCT
static var _pause_when_unfocused: bool = DEFAULT_PAUSE_WHEN_UNFOCUSED
static var _show_fps: bool = DEFAULT_SHOW_FPS
static var _show_first_time_tips: bool = DEFAULT_SHOW_FIRST_TIME_TIPS
static var _window_size_set: bool = false # false = never chosen; the window is left as the OS/project made it
static var _window_size_index: int = DEFAULT_WINDOW_SIZE_INDEX
static var _fps_limit: int = DEFAULT_FPS_LIMIT
static var _default_keys: Dictionary = {} # StringName -> Array[int] (physical keycodes), captured once from the project Input Map
static var _custom_keys: Dictionary = {} # StringName -> Array[int]; only actions the player changed


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
	_display_mode = _clamp_display_mode(int(cfg.get_value(SECTION_VIDEO, DISPLAY_MODE_KEY, _display_mode)))
	_vsync_enabled = bool(cfg.get_value(SECTION_VIDEO, "vsync_enabled", _vsync_enabled))
	var legacy_shake_on: bool = bool(cfg.get_value(SECTION_GAMEPLAY, "screen_shake_enabled", true))
	if cfg.has_section_key(SECTION_GAMEPLAY, "screen_shake_pct"):
		_screen_shake_pct = _clamp_shake(int(cfg.get_value(SECTION_GAMEPLAY, "screen_shake_pct", _screen_shake_pct)))
	elif cfg.has_section_key(SECTION_GAMEPLAY, "screen_shake_enabled"):
		_screen_shake_pct = DEFAULT_SCREEN_SHAKE_PCT if legacy_shake_on else 0 # migrate the pre-v1.0 on/off toggle
	_damage_numbers_enabled = bool(cfg.get_value(SECTION_GAMEPLAY, "damage_numbers_enabled", _damage_numbers_enabled))
	_movement_only_controls_enabled = bool(cfg.get_value(SECTION_GAMEPLAY, "movement_only_controls_enabled", _movement_only_controls_enabled))
	if cfg.has_section_key(SECTION_GAMEPLAY, "auto_cast_enabled"):
		_auto_cast_set = true
		_auto_cast_enabled = bool(cfg.get_value(SECTION_GAMEPLAY, "auto_cast_enabled", _auto_cast_enabled))
	_show_overhead_bars = bool(cfg.get_value(SECTION_GAMEPLAY, "show_overhead_bars", _show_overhead_bars))
	_reduce_flashing = bool(cfg.get_value(SECTION_ACCESSIBILITY, "reduce_flashing", _reduce_flashing))
	_enemy_outlines = bool(cfg.get_value(SECTION_ACCESSIBILITY, "enemy_outlines", _enemy_outlines))
	_hud_scale_pct = _clamp_hud_scale(int(cfg.get_value(SECTION_ACCESSIBILITY, "hud_scale_pct", _hud_scale_pct)))
	_interface_volume_pct = _snap_to_step(int(cfg.get_value(SECTION_AUDIO, "interface_volume_pct", _interface_volume_pct)))
	_pause_when_unfocused = bool(cfg.get_value(SECTION_GAMEPLAY, "pause_when_unfocused", _pause_when_unfocused))
	_show_fps = bool(cfg.get_value(SECTION_VIDEO, "show_fps", _show_fps))
	_show_first_time_tips = bool(cfg.get_value(SECTION_GAMEPLAY, "show_first_time_tips", _show_first_time_tips))
	_fps_limit = _clamp_fps_limit(int(cfg.get_value(SECTION_VIDEO, "fps_limit", _fps_limit)))
	if cfg.has_section_key(SECTION_VIDEO, "window_size_index"):
		_window_size_set = true
		_window_size_index = clampi(int(cfg.get_value(SECTION_VIDEO, "window_size_index", _window_size_index)), 0, WINDOW_SIZES.size() - 1)
	_custom_keys.clear()
	_ensure_default_keys()
	for action: StringName in REBINDABLE_ACTIONS:
		if cfg.has_section_key(SECTION_CONTROLS, String(action) + "_1") or cfg.has_section_key(SECTION_CONTROLS, String(action) + "_2"):
			var slots: Array[int] = []
			for i: int in BINDING_SLOTS:
				slots.append(int(cfg.get_value(SECTION_CONTROLS, "%s_%d" % [action, i + 1], 0)))
			_custom_keys[action] = slots



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
	cfg.set_value(SECTION_VIDEO, DISPLAY_MODE_KEY, _display_mode)
	cfg.set_value(SECTION_VIDEO, "vsync_enabled", _vsync_enabled)
	cfg.set_value(SECTION_GAMEPLAY, "screen_shake_pct", _screen_shake_pct)
	cfg.set_value(SECTION_GAMEPLAY, "damage_numbers_enabled", _damage_numbers_enabled)
	cfg.set_value(SECTION_GAMEPLAY, "movement_only_controls_enabled", _movement_only_controls_enabled)
	if _auto_cast_set:
		cfg.set_value(SECTION_GAMEPLAY, "auto_cast_enabled", _auto_cast_enabled)
	cfg.set_value(SECTION_GAMEPLAY, "show_overhead_bars", _show_overhead_bars)
	cfg.set_value(SECTION_ACCESSIBILITY, "reduce_flashing", _reduce_flashing)
	cfg.set_value(SECTION_ACCESSIBILITY, "enemy_outlines", _enemy_outlines)
	cfg.set_value(SECTION_ACCESSIBILITY, "hud_scale_pct", _hud_scale_pct)
	cfg.set_value(SECTION_AUDIO, "interface_volume_pct", _interface_volume_pct)
	cfg.set_value(SECTION_GAMEPLAY, "pause_when_unfocused", _pause_when_unfocused)
	cfg.set_value(SECTION_VIDEO, "show_fps", _show_fps)
	cfg.set_value(SECTION_GAMEPLAY, "show_first_time_tips", _show_first_time_tips)
	cfg.set_value(SECTION_VIDEO, "fps_limit", _fps_limit)
	if _window_size_set:
		cfg.set_value(SECTION_VIDEO, "window_size_index", _window_size_index)
	for action: StringName in _custom_keys:
		var slots: Array = _custom_keys[action]
		for i: int in BINDING_SLOTS:
			cfg.set_value(SECTION_CONTROLS, "%s_%d" % [action, i + 1], int(slots[i]))
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
	_apply_interface_bus()
	_apply_display_mode()
	_apply_window_size()
	_apply_vsync()
	_apply_fps_limit()
	_apply_controls()
	FpsOverlay.sync()


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
	return _screen_shake_pct > 0


## 0.0-1.0; the camera multiplies every shake by it.
static func get_screen_shake_scale() -> float:
	return float(_screen_shake_pct) / 100.0


static func get_screen_shake_pct() -> int:
	return _screen_shake_pct


static func get_interface_volume_pct() -> int:
	return _interface_volume_pct


static func is_pause_when_unfocused() -> bool:
	return _pause_when_unfocused


static func is_show_fps() -> bool:
	return _show_fps


static func get_fps_limit() -> int:
	return _fps_limit


static func get_window_size_index() -> int:
	return _window_size_index


static func get_window_size() -> Vector2i:
	return WINDOW_SIZES[_window_size_index]


static func are_damage_numbers_enabled() -> bool:
	return _damage_numbers_enabled


static func get_movement_only_controls_enabled() -> bool:
	return _movement_only_controls_enabled


## docs/31 §3.3: the effective auto-cast flag. Movement-only controls force it
## on (the movement-alone input floor, MASTER_SDLC.md:242). Never chosen ->
## the device default (on for touch, off for desktop).
static func is_auto_cast_enabled() -> bool:
	if _movement_only_controls_enabled:
		return true
	if not _auto_cast_set:
		return DEFAULT_AUTO_CAST_TOUCH if _is_touch_device() else DEFAULT_AUTO_CAST_DESKTOP
	return _auto_cast_enabled


static func get_auto_cast_setting_raw() -> bool:
	if not _auto_cast_set:
		return DEFAULT_AUTO_CAST_TOUCH if _is_touch_device() else DEFAULT_AUTO_CAST_DESKTOP
	return _auto_cast_enabled


static func is_show_first_time_tips() -> bool:
	return _show_first_time_tips


static func is_show_overhead_bars() -> bool:
	return _show_overhead_bars


static func is_reduce_flashing() -> bool:
	return _reduce_flashing


static func is_enemy_outlines() -> bool:
	return _enemy_outlines


static func get_hud_scale_pct() -> int:
	return _hud_scale_pct


static func get_hud_scale() -> float:
	return float(_hud_scale_pct) / 100.0


static func set_auto_cast_enabled(enabled: bool) -> void:
	_auto_cast_set = true
	_auto_cast_enabled = enabled
	save()


static func set_show_first_time_tips(enabled: bool) -> void:
	_show_first_time_tips = enabled
	save()


static func set_show_overhead_bars(enabled: bool) -> void:
	_show_overhead_bars = enabled
	save()


static func set_reduce_flashing(enabled: bool) -> void:
	_reduce_flashing = enabled
	save()


static func set_enemy_outlines(enabled: bool) -> void:
	_enemy_outlines = enabled
	save()


static func set_hud_scale_pct(pct: int) -> void:
	_hud_scale_pct = _clamp_hud_scale(pct)
	save()


static func adjust_hud_scale(direction: int) -> void:
	set_hud_scale_pct(_hud_scale_pct + direction * HUD_SCALE_STEP_PCT)


static func _clamp_hud_scale(pct: int) -> int:
	var snapped: int = int(round(float(pct) / HUD_SCALE_STEP_PCT)) * HUD_SCALE_STEP_PCT
	return clampi(snapped, HUD_SCALE_MIN_PCT, HUD_SCALE_MAX_PCT)


static func _is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


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
	set_screen_shake_pct(DEFAULT_SCREEN_SHAKE_PCT if enabled else 0)


static func set_screen_shake_pct(pct: int) -> void:
	_screen_shake_pct = _clamp_shake(pct)
	save()


static func adjust_screen_shake(direction: int) -> void:
	set_screen_shake_pct(_screen_shake_pct + direction * SCREEN_SHAKE_STEP_PCT)


static func set_interface_volume_pct(pct: int) -> void:
	_interface_volume_pct = _clamp_pct(_snap_to_step(pct))
	_apply_interface_bus()
	save()


static func adjust_interface_volume(direction: int) -> void:
	set_interface_volume_pct(_interface_volume_pct + direction * VOLUME_STEP_PCT)


static func set_pause_when_unfocused(enabled: bool) -> void:
	_pause_when_unfocused = enabled
	save()


static func set_show_fps(enabled: bool) -> void:
	_show_fps = enabled
	FpsOverlay.sync()
	save()


static func set_fps_limit(fps: int) -> void:
	_fps_limit = _clamp_fps_limit(fps)
	_apply_fps_limit()
	save()


static func cycle_fps_limit(direction: int) -> void:
	set_fps_limit(FPS_LIMITS[wrapi(FPS_LIMITS.find(_fps_limit) + direction, 0, FPS_LIMITS.size())])


static func set_window_size_index(index: int) -> void:
	_window_size_set = true
	_window_size_index = clampi(index, 0, WINDOW_SIZES.size() - 1)
	_apply_window_size()
	save()


static func cycle_window_size(direction: int) -> void:
	set_window_size_index(wrapi(_window_size_index + direction, 0, WINDOW_SIZES.size()))


# --- Key bindings (Controls tab) ---------------------------------------------

## Physical keycode in `slot` (0 or 1) of `action`; 0 = unbound.
static func get_key_binding(action: StringName, slot: int) -> int:
	_ensure_default_keys()
	var keys: Array = _custom_keys.get(action, _default_keys.get(action, [0, 0]))
	return int(keys[slot]) if slot >= 0 and slot < keys.size() else 0


## Binds `physical_keycode` to `action`'s `slot`. A key already bound to
## another rebindable action swaps places with this slot's old key, so no
## movement action is ever left without a key (the movement-only floor).
static func set_key_binding(action: StringName, slot: int, physical_keycode: int) -> void:
	_ensure_default_keys()
	if not REBINDABLE_ACTIONS.has(action) or slot < 0 or slot >= BINDING_SLOTS or physical_keycode <= 0:
		return
	var old_key: int = get_key_binding(action, slot)
	if old_key == physical_keycode:
		return
	for other: StringName in REBINDABLE_ACTIONS:
		for i: int in BINDING_SLOTS:
			if other == action and i == slot:
				continue
			if get_key_binding(other, i) == physical_keycode:
				var keys: Array = _keys_copy(other)
				keys[i] = old_key # the displaced key moves to the slot the new key left (0 if that slot was empty)
				_custom_keys[other] = keys
	var mine: Array = _keys_copy(action)
	mine[slot] = physical_keycode
	_custom_keys[action] = mine
	_apply_controls()
	save()


static func is_controls_customised() -> bool:
	return not _custom_keys.is_empty()


static func reset_controls() -> void:
	_custom_keys.clear()
	_apply_controls()
	save()


## "W" / "Up" ... for a physical keycode; "-" for unbound.
static func key_label(physical_keycode: int) -> String:
	if physical_keycode <= 0:
		return "-"
	var label: int = 0
	if DisplayServer.get_name() != "headless":
		label = DisplayServer.keyboard_get_label_from_physical(physical_keycode as Key)
	return OS.get_keycode_string((label if label != 0 else physical_keycode) as Key)


## Everything back to its Register default, applied and saved (the Settings
## screen's "Reset to defaults" after its confirm).
static func reset_to_defaults() -> void:
	reset_state_for_test()
	apply()
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
	_screen_shake_pct = DEFAULT_SCREEN_SHAKE_PCT if enabled else 0


static func set_reduce_flashing_for_test(enabled: bool) -> void:
	_reduce_flashing = enabled


static func set_show_first_time_tips_for_test(enabled: bool) -> void:
	_show_first_time_tips = enabled


static func set_show_overhead_bars_for_test(enabled: bool) -> void:
	_show_overhead_bars = enabled


static func set_hud_scale_pct_for_test(pct: int) -> void:
	_hud_scale_pct = _clamp_hud_scale(pct)


static func set_screen_shake_pct_for_test(pct: int) -> void:
	_screen_shake_pct = _clamp_shake(pct)


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
	_screen_shake_pct = DEFAULT_SCREEN_SHAKE_PCT
	_interface_volume_pct = DEFAULT_INTERFACE_VOLUME_PCT
	_pause_when_unfocused = DEFAULT_PAUSE_WHEN_UNFOCUSED
	_show_fps = DEFAULT_SHOW_FPS
	_show_first_time_tips = DEFAULT_SHOW_FIRST_TIME_TIPS
	_window_size_set = false
	_window_size_index = DEFAULT_WINDOW_SIZE_INDEX
	_fps_limit = DEFAULT_FPS_LIMIT
	_custom_keys.clear()
	_apply_controls() # restores the project's Input Map keys
	FpsOverlay.sync()
	_damage_numbers_enabled = DEFAULT_DAMAGE_NUMBERS_ENABLED
	_movement_only_controls_enabled = DEFAULT_MOVEMENT_ONLY_ENABLED
	_auto_cast_set = false
	_auto_cast_enabled = DEFAULT_AUTO_CAST_DESKTOP
	_show_overhead_bars = DEFAULT_SHOW_OVERHEAD_BARS
	_reduce_flashing = DEFAULT_REDUCE_FLASHING
	_enemy_outlines = DEFAULT_ENEMY_OUTLINES
	_hud_scale_pct = DEFAULT_HUD_SCALE_PCT


# --- Internals -----------------------------------------------------------

static func _clamp_pct(pct: int) -> int:
	return clampi(pct, VOLUME_MIN_PCT, VOLUME_MAX_PCT)


static func _snap_to_step(pct: int) -> int:
	return int(roundi(float(pct) / float(VOLUME_STEP_PCT)) * VOLUME_STEP_PCT)


static func _clamp_shake(pct: int) -> int:
	return clampi(int(roundi(float(pct) / float(SCREEN_SHAKE_STEP_PCT))) * SCREEN_SHAKE_STEP_PCT, 0, 100)


static func _clamp_fps_limit(fps: int) -> int:
	return fps if FPS_LIMITS.has(fps) else DEFAULT_FPS_LIMIT


static func _keys_copy(action: StringName) -> Array:
	return [get_key_binding(action, 0), get_key_binding(action, 1)]


## Captures the project's own keyboard bindings (first two InputEventKey
## events of each rebindable action) the first time anything asks.
static func _ensure_default_keys() -> void:
	if not _default_keys.is_empty():
		return
	for action: StringName in REBINDABLE_ACTIONS:
		var keys: Array = [0, 0]
		if InputMap.has_action(action):
			var n: int = 0
			for ev: InputEvent in InputMap.action_get_events(action):
				if ev is InputEventKey and n < BINDING_SLOTS:
					keys[n] = (ev as InputEventKey).physical_keycode
					n += 1
		_default_keys[action] = keys


## Rewrites the keyboard events of every rebindable action from the current
## bindings (custom, else the captured defaults); gamepad and mouse events stay.
static func _apply_controls() -> void:
	_ensure_default_keys()
	for action: StringName in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var keep: Array[InputEvent] = []
		for ev: InputEvent in InputMap.action_get_events(action):
			if not (ev is InputEventKey):
				keep.append(ev)
		InputMap.action_erase_events(action)
		for i: int in BINDING_SLOTS:
			var code: int = get_key_binding(action, i)
			if code > 0:
				var key := InputEventKey.new()
				key.physical_keycode = code as Key
				InputMap.action_add_event(action, key)
		for ev: InputEvent in keep:
			InputMap.action_add_event(action, ev)


static func _apply_interface_bus() -> void:
	var idx: int = AudioServer.get_bus_index(INTERFACE_BUS)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, volume_pct_to_db(_interface_volume_pct))
	AudioServer.set_bus_mute(idx, _interface_volume_pct <= 0)


static func _apply_fps_limit() -> void:
	Engine.max_fps = _fps_limit


static func _apply_window_size() -> void:
	if not _window_size_set or DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	if _display_mode != DisplayMode.WINDOWED:
		return
	var win: Vector2i = WINDOW_SIZES[_window_size_index]
	_fit_window_to_usable_area(win)


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
			if not _window_size_set:
				_fit_window_to_usable_area(DisplayServer.window_get_size())


## D375: a window never hangs under the taskbar. The usable rect is the screen
## minus the taskbar/dock; the title bar needs room too, so the client area is
## shrunk by the decoration size and the window is centred in what is left.
static func _fit_window_to_usable_area(wanted: Vector2i) -> void:
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var deco: Vector2i = DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var room: Vector2i = usable.size - deco
	var win: Vector2i = Vector2i(mini(wanted.x, room.x), mini(wanted.y, room.y))
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position(usable.position + Vector2i(deco.x / 2, deco.y - deco.x / 2) + (room - win) / 2)


static func _apply_vsync() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED)
