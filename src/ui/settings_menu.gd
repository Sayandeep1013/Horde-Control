extends CanvasLayer
class_name SettingsMenu

## Settings Menu (Settings screen task, rebuild). MASTER_SDLC.md > Provisional
## Values Register > "Interfaces" > "Settings" row; > "Movement-only controls
## setting (C-SECTORS)"; Review Decision Log D121; docs/19_UI_UX.md >
## "Settings". Reachable from the pause menu, the run-end screens (via
## `RunFlowController`, unchanged), the title screen, and the Hub (War Camp)
## -- each of the latter two instantiates its own `SettingsMenu` instance
## exactly like `RunFlowController` already does, and reacts to `closed`.
##
## ## Rebuilt as a vertical row list (task brief; D121)
## The three OTHER paused menus (`PauseMenu`, the Level-Up Draft, the run-end
## screens) stay a single horizontal `PausedChoiceBar` row, per MASTER_SDLC.md
## > Provisional Values Register > "Interfaces" > "Platform input floor":
## "every paused menu ... lays choices out horizontally". Settings itself now
## carries nine adjustable settings plus Back -- ten entries -- which do not
## read as one horizontal row at any legible size. D121 (below; see
## MASTER_SDLC.md's Review Decision Log) chose a vertical list of rows
## instead, each with its own left/right-adjustable value, and the Register's
## "Platform input floor" row is amended alongside it to carve Settings out
## of "lays out choices horizontally" by name -- named here rather than left
## as a silent contradiction between this file and that row.
##
## `PausedChoiceBar` stays exactly what the other three menus use -- this
## file no longer instantiates one (its horizontal cycle-and-hold-up shape
## does not fit a vertical list with a per-row value). (Blind review fix: it
## DID need its own open-lockout/held-input-seeding fix for the same bug
## class this file fixes below -- see its own header -- so "UNCHANGED" no
## longer describes it; its own SHAPE, cycling on left/right and confirming
## on a hold-up, is what stayed the same.)
## `SettingsRow` (src/ui/settings_row.gd) is this file's own equivalent
## building block, and `SettingsMenu` itself now owns the input polling
## `PausedChoiceBar` used to own on its behalf, reusing the SAME two timing
## constants (`CYCLE_REPEAT_SECONDS`, `HOLD_CONFIRM_SECONDS`) for the SAME
## reason `paused_choice_bar.gd`'s own header gives: the Register defines
## hold-to-confirm timing in exactly one place (the Draft input row), and
## every paused surface in this project reuses that one pair of numbers
## rather than inventing a second, uncited pair.
##
## ## Input shape (task brief: "left/right are movement keys; Back must be
## confirmable by hold-to-confirm")
## - Up/Down (`move_up`/`move_down`) move the highlighted row, with the same
##   0.3 s press-then-repeat cadence `PausedChoiceBar` uses for its own
##   left/right cycling (`_poll_vertical_input()`).
## - Left/Right (`move_left`/`move_right`) change the highlighted row's value
##   by one step, immediately applied and saved, with the same 0.3 s repeat
##   cadence (`_poll_horizontal_input()`) -- EXCEPT on the Back row, which has
##   no value to change.
## - The Back row is confirmed by holding EITHER `move_left` or `move_right`
##   for `HOLD_CONFIRM_SECONDS` (`_poll_back_hold()`), or by the `confirm`
##   action's instant press, or by a mouse click. This reuses left/right
##   (already the "adjust" axis, and idle on the one row that has nothing to
##   adjust) as the Back row's own hold gesture rather than reusing up/down
##   (the row-navigation axis, which a hold would ambiguously also be
##   walking through neighbouring rows) -- named as an interpretation, since
##   no document specifies which axis a VERTICAL list's own hold-to-confirm
##   should use (the Register's own hold-to-confirm text is written against
##   `PausedChoiceBar`'s horizontal shape). The same neutral-return arming
##   rule `paused_choice_bar.gd`'s header describes (a key already held the
##   instant Back becomes highlighted must not instantly confirm) applies
##   here too -- see `_poll_back_hold()`.
## - Movement-only players (task brief: "a movement-only player must still be
##   able to change values and leave") therefore need only `move_up`/`move_
##   down`/`move_left`/`move_right` for the entire screen -- no button.
## - Toggle and Display Mode rows change ONCE per press, never on repeat
##   (blind review fix, item 7): only the three volume rows keep the
##   press-then-repeat cadence above -- see `_is_volume_row()` and
##   `_poll_horizontal_input()`. A toggle held past the repeat interval must
##   not flip back and forth, and Display Mode must not skip past the value
##   the player actually wanted.
##
## ## 0.4 s open lockout + held-input seeding (blind review fix, items 3-4)
## `set_active(true)` now (a) resets `_highlighted_index` to row 0 (Master
## Volume) every time -- a stale highlight left on Back from the PREVIOUS
## session used to combine with (b) below into a same-frame reopen-and-close
## bug: the pause menu's own `PausedChoiceBar` runs its `_process()` earlier
## in the scene tree than this screen's, so the SAME physical "confirm" press
## that opened Settings (via `RunFlowController`) was still `just_pressed`
## when THIS screen's own `_process()` ran later in that identical frame --
## and if Back happened to still be highlighted, `_poll_confirm_input()`
## closed it again immediately; (b) starts a Register-cited `OPEN_LOCKOUT_
## SECONDS` window (MASTER_SDLC.md line 242; Author decision D3: "every
## paused menu" gets this lockout, reused from the Register's one citation
## of it, the Draft input row, rather than a new literal) during which
## `_process()` polls nothing at all -- by the time it ends, any leftover
## `just_pressed` edge from the opening frame is long gone (the lockout spans
## many real frames); and (c) seeds `_up_held`/`_down_held`/`_left_held`/
## `_right_held` from the LIVE input state at the moment of activation
## (`_seed_input_state()`), so a key already held when the menu opens (for
## example holding `move_up` to hold-confirm "Settings" on the pause menu
## itself) is not misread as a fresh press once the lockout ends -- the same
## fix `src/run/paused_choice_bar.gd` gets for its own `_left_held`/
## `_right_held` (its own header has the mirror-case citation).
##
## ## Reachability (task brief item 4)
## `RunFlowController` already owns one instance (pause menu / run-end
## screens, unchanged: `settings_requested` -> `set_active(true)`, `closed`
## -> `set_active(false)`). `TitleScreen` and `HubScreen` each own a SECOND,
## independent instance of their own (a fresh `settings_menu.tscn` load),
## opened by their own "Settings" button and closed the same way -- there is
## no run in progress at either screen for `RunFlowController` to mediate.
## Every instance reads/writes the SAME `GameSettings` static state, so a
## change made from any one of the three reachability points is visible from
## the other two without any cross-instance wiring.
##
## ## Movement-only controls: now routed through `GameSettings` (task brief)
## `movement_only_controls_enabled` used to be this file's own
## process-lifetime static (`_static_last_value`, header of the version this
## replaces). It is now one more field on `GameSettings`
## (src/core/game_settings.gd), persisted like every other setting here. The
## two static wrappers below (`get_movement_only_controls_enabled()`,
## `set_movement_only_controls_enabled_for_test()`) are kept, UNCHANGED in
## name and shape, purely so `src/ui/skill_tree_screen.gd` (its own
## movement-only stand-still-buy path) and `tests/unit/skill_tree_screen_test.gd`
## (which calls the `_for_test` seam with no `GameSettings` path of its own
## set up) need no edit of their own.

signal closed()

## Above src/ui/hud.gd (10) / src/ui/threat_feedback.gd (11); above
## src/ui/pause_menu.gd (18) and src/ui/run_end.gd (19) since this screen is
## always opened ON TOP of one of those two, or of the title/Hub screens
## (which use no other CanvasLayer this high). Not a Provisional Values
## Register number -- see hud.gd's identical note.
const SETTINGS_MENU_CANVAS_LAYER: int = 21

# --- Row ids, in display order (task brief's own list) -----------------------
const ROW_MASTER_VOLUME: String = "master_volume"
const ROW_MUSIC_VOLUME: String = "music_volume"
const ROW_EFFECTS_VOLUME: String = "effects_volume"
const ROW_MUTE_ALL: String = "mute_all"
const ROW_DISPLAY_MODE: String = "display_mode"
const ROW_VSYNC: String = "vsync"
const ROW_SCREEN_SHAKE: String = "screen_shake"
const ROW_DAMAGE_NUMBERS: String = "damage_numbers"
const ROW_MOVEMENT_ONLY: String = "movement_only"
const ROW_BACK: String = "back"

const ROW_ORDER: Array[String] = [
	ROW_MASTER_VOLUME, ROW_MUSIC_VOLUME, ROW_EFFECTS_VOLUME, ROW_MUTE_ALL,
	ROW_DISPLAY_MODE, ROW_VSYNC, ROW_SCREEN_SHAKE, ROW_DAMAGE_NUMBERS,
	ROW_MOVEMENT_ONLY, ROW_BACK,
]

## Reused from src/run/paused_choice_bar.gd -- see that file's own header for
## why this is the Register's one hold-to-confirm timing figure (Draft input
## row), reused rather than a second, uncited pair of numbers.
const CYCLE_REPEAT_SECONDS: float = 0.3
const HOLD_CONFIRM_SECONDS: float = 1.0
## MASTER_SDLC.md line 242 / Author decision D3: "every paused menu" opens
## with this lockout. The Register's own one citation of the figure is the
## "Draft input" row ("0.4 s input lockout on open") -- reused here for the
## same reason `CYCLE_REPEAT_SECONDS`/`HOLD_CONFIRM_SECONDS` already are (see
## class header).
const OPEN_LOCKOUT_SECONDS: float = 0.4

## Rows whose value keeps changing while held (blind review fix, item 7) --
## every OTHER row (toggles, Display Mode, Back) changes once per press only.
const REPEATING_ROWS: Array[String] = [ROW_MASTER_VOLUME, ROW_MUSIC_VOLUME, ROW_EFFECTS_VOLUME]

var _root: Control
var _frame: MenuFrame.Parts
var _fill_ring: DraftFillRing
var _rows: Dictionary = {} # String id -> SettingsRow

var _active: bool = false
var _highlighted_index: int = 0
var _lockout_remaining: float = 0.0

var _up_held: bool = false
var _up_repeat_timer: float = 0.0
var _down_held: bool = false
var _down_repeat_timer: float = 0.0
var _left_held: bool = false
var _left_repeat_timer: float = 0.0
var _right_held: bool = false
var _right_repeat_timer: float = 0.0

var _back_hold_armed: bool = false
var _back_hold_progress: float = 0.0

## Test input override -- mirrors src/ui/draft_controller.gd's / src/run/
## paused_choice_bar.gd's own `_use_test_input`/`_test_pressed`/
## `_test_just_pressed` convention letter for letter.
var _use_test_input: bool = false
var _test_pressed: Dictionary = {}
var _test_just_pressed: Dictionary = {}


## `GameSettings.load()` is deliberately NOT called here -- only
## `src/ui/title_screen.gd`'s `_ready()` calls it (see class header,
## "Reachability," and src/core/game_settings.gd's own header, "Boot-apply
## site"). This screen is built by `RunFlowController`, `HubScreen`, AND
## `TitleScreen` itself; if construction alone touched disk, every test that
## instantiates any ONE of those three (most with no `GameSettings` path of
## their own set up -- e.g. `tests/unit/hub_screen_test.gd`, `tests/unit/
## run_flow_check_test.gd`) would read the real `user://settings.cfg` the
## instant it built its own SettingsMenu child, violating this task's own
## hard constraint. `_refresh_all_rows()` below reads whatever `GameSettings`
## already holds in memory -- the real boot's own loaded values in real play,
## or the compiled-in Register defaults in a test that never called `load()`
## at all.
func _ready() -> void:
	layer = SETTINGS_MENU_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	_refresh_all_rows()
	_refresh_highlight()


## The card's own fade/scale-in (UI pass convention, see menu_frame.gd) is
## purely cosmetic and runs AFTER these lines, never before or instead of
## them -- input activation is never delayed by it.
##
## Blind review fix (items 3-4): `_highlighted_index` resets to row 0 and a
## fresh `OPEN_LOCKOUT_SECONDS` window begins EVERY activation -- see class
## header, "0.4 s open lockout + held-input seeding," for why both are
## needed together.
func set_active(active: bool) -> void:
	visible = active
	_active = active
	if active:
		_highlighted_index = 0
		_lockout_remaining = OPEN_LOCKOUT_SECONDS
		_seed_input_state()
		_refresh_all_rows()
		_refresh_highlight()
		MenuFrame.animate_in(_frame)
	else:
		MenuFrame.reset_motion(_frame)


## Test seam (mirrors src/ui/draft_controller.gd's `skip_lockout_for_test()`
## naming): forces the open lockout to have already elapsed, for tests that
## do not care about its timing.
func skip_lockout_for_test() -> void:
	_lockout_remaining = 0.0


func get_lockout_remaining_for_test() -> float:
	return _lockout_remaining


func is_active_for_test() -> bool:
	return visible


func get_highlighted_index_for_test() -> int:
	return _highlighted_index


func get_row_for_test(id: String) -> SettingsRow:
	return _rows.get(id) as SettingsRow


func get_back_hold_progress_for_test() -> float:
	return _back_hold_progress


func get_fill_ring_for_test() -> DraftFillRing:
	return _fill_ring


func highlight_row_for_test(id: String) -> void:
	var idx: int = ROW_ORDER.find(id)
	if idx != -1:
		_highlighted_index = idx
		_refresh_highlight()


## Public static read of the Movement-only controls setting -- see class
## header, "Movement-only controls: now routed through GameSettings".
static func get_movement_only_controls_enabled() -> bool:
	return GameSettings.get_movement_only_controls_enabled()


## Test seam kept for `tests/unit/skill_tree_screen_test.gd` -- see class
## header. Memory-only (no disk write): `GameSettings.
## set_movement_only_controls_enabled_for_test()`'s own contract.
static func set_movement_only_controls_enabled_for_test(enabled: bool) -> void:
	GameSettings.set_movement_only_controls_enabled_for_test(enabled)


# --- test input seams (mirror paused_choice_bar.gd's own convention) --------

func set_test_input_mode_for_test(enabled: bool) -> void:
	_use_test_input = enabled
	_test_pressed.clear()
	_test_just_pressed.clear()


func set_action_pressed_for_test(action: StringName, pressed: bool) -> void:
	_test_pressed[action] = pressed


func press_action_once_for_test(action: StringName) -> void:
	_test_just_pressed[action] = true
	_test_pressed[action] = true


func release_action_for_test(action: StringName) -> void:
	_test_pressed[action] = false


func tick_for_test(delta: float) -> void:
	_process(delta)


# --- Build --------------------------------------------------------------

func _build_ui() -> void:
	UiStrings.ensure_registered() # explicit here, not only reached as UiTheme.get_theme()'s side effect (matches every other menu in this pass).
	_frame = MenuFrame.build(self, 0.6, "L")
	_root = _frame.root

	MenuFrame.build_title(_frame.column, tr("SETTINGS_MENU_TITLE"), UiTheme.HEADING, 460.0)
	MenuFrame.build_separator(_frame.column)

	var list := VBoxContainer.new()
	list.name = "RowList"
	list.theme_type_variation = UiTheme.vbox("XS")
	_frame.column.add_child(list)

	_add_row(list, ROW_MASTER_VOLUME, tr("SETTINGS_MASTER_VOLUME"), true)
	_add_row(list, ROW_MUSIC_VOLUME, tr("SETTINGS_MUSIC_VOLUME"), true)
	_add_row(list, ROW_EFFECTS_VOLUME, tr("SETTINGS_EFFECTS_VOLUME"), true)
	_add_row(list, ROW_MUTE_ALL, tr("SETTINGS_MUTE_ALL"), true)
	_add_row(list, ROW_DISPLAY_MODE, tr("SETTINGS_DISPLAY_MODE"), true)
	_add_row(list, ROW_VSYNC, tr("SETTINGS_VSYNC"), true)
	_add_row(list, ROW_SCREEN_SHAKE, tr("SETTINGS_SCREEN_SHAKE"), true)
	_add_row(list, ROW_DAMAGE_NUMBERS, tr("SETTINGS_DAMAGE_NUMBERS"), true)
	_add_row(list, ROW_MOVEMENT_ONLY, tr("SETTINGS_MOVEMENT_ONLY"), true)
	_add_row(list, ROW_BACK, tr("SETTINGS_BACK"), false)

	var hold_footer: VBoxContainer = MenuFrame.build_hold_footer(_frame.column)
	_fill_ring = DraftFillRing.new()
	_fill_ring.name = "HoldRing"
	_fill_ring.custom_minimum_size = Vector2(40, 40)
	MenuFrame.style_fill_ring(_fill_ring)
	hold_footer.add_child(_fill_ring)


func _add_row(parent: Container, id: String, label_text: String, has_value: bool) -> void:
	var row := SettingsRow.new()
	row.name = "Row_" + id
	parent.add_child(row)
	row.configure(label_text, has_value)
	row.hovered.connect(_on_row_hovered.bind(id))
	row.clicked.connect(_on_row_clicked.bind(id))
	row.left_pressed.connect(_on_row_left_pressed.bind(id))
	row.right_pressed.connect(_on_row_right_pressed.bind(id))
	_rows[id] = row


# --- Mouse handlers ----------------------------------------------------------

func _on_row_hovered(id: String) -> void:
	_highlight_row(id)


func _on_row_clicked(id: String) -> void:
	_highlight_row(id)
	if id == ROW_BACK:
		closed.emit()


func _on_row_left_pressed(id: String) -> void:
	_highlight_row(id)
	_apply_direction(-1)


func _on_row_right_pressed(id: String) -> void:
	_highlight_row(id)
	_apply_direction(1)


func _highlight_row(id: String) -> void:
	var idx: int = ROW_ORDER.find(id)
	if idx != -1:
		_highlighted_index = idx
		_refresh_highlight()


# --- Keyboard / gamepad polling ----------------------------------------------

## During the open lockout, every edge (including a leftover `just_pressed`
## from the frame that opened this screen) is swallowed -- `_clear_test_edges_
## for_frame()` still runs so a queued test edge does not leak past the
## lockout either. See class header, "0.4 s open lockout + held-input
## seeding."
func _process(delta: float) -> void:
	if not _active:
		return
	if _lockout_remaining > 0.0:
		_lockout_remaining = maxf(_lockout_remaining - delta, 0.0)
		_clear_test_edges_for_frame()
		return
	_poll_vertical_input(delta)
	_poll_horizontal_input(delta)
	_poll_confirm_input()
	_poll_back_hold(delta)
	_update_fill_ring_visual()
	_clear_test_edges_for_frame()


func _poll_vertical_input(delta: float) -> void:
	var up_now: bool = _is_pressed(&"move_up")
	var down_now: bool = _is_pressed(&"move_down")

	if up_now and not _up_held:
		_move_highlight(-1)
		_up_repeat_timer = CYCLE_REPEAT_SECONDS
	elif up_now and _up_held:
		_up_repeat_timer -= delta
		if _up_repeat_timer <= 0.0:
			_move_highlight(-1)
			_up_repeat_timer = CYCLE_REPEAT_SECONDS
	_up_held = up_now

	if down_now and not _down_held:
		_move_highlight(1)
		_down_repeat_timer = CYCLE_REPEAT_SECONDS
	elif down_now and _down_held:
		_down_repeat_timer -= delta
		if _down_repeat_timer <= 0.0:
			_move_highlight(1)
			_down_repeat_timer = CYCLE_REPEAT_SECONDS
	_down_held = down_now


## Blind review fix (item 7): the repeat branches below only re-fire for a
## volume row (`_is_volume_row()`) -- the initial press-edge still fires for
## EVERY row (including toggles/Display Mode), which is what makes a single
## press change them at all; holding past the repeat interval must not.
func _poll_horizontal_input(delta: float) -> void:
	var left_now: bool = _is_pressed(&"move_left")
	var right_now: bool = _is_pressed(&"move_right")
	var repeats: bool = _is_volume_row(ROW_ORDER[_highlighted_index])

	if left_now and not _left_held:
		_apply_direction(-1)
		_left_repeat_timer = CYCLE_REPEAT_SECONDS
	elif left_now and _left_held and repeats:
		_left_repeat_timer -= delta
		if _left_repeat_timer <= 0.0:
			_apply_direction(-1)
			_left_repeat_timer = CYCLE_REPEAT_SECONDS
	_left_held = left_now

	if right_now and not _right_held:
		_apply_direction(1)
		_right_repeat_timer = CYCLE_REPEAT_SECONDS
	elif right_now and _right_held and repeats:
		_right_repeat_timer -= delta
		if _right_repeat_timer <= 0.0:
			_apply_direction(1)
			_right_repeat_timer = CYCLE_REPEAT_SECONDS
	_right_held = right_now


func _is_volume_row(id: String) -> bool:
	return REPEATING_ROWS.has(id)


## Instant confirm (matches PausedChoiceBar's own `_poll_confirm_input()`) --
## works only on the Back row; every other row has nothing to "confirm."
func _poll_confirm_input() -> void:
	if _is_just_pressed(&"confirm") and ROW_ORDER[_highlighted_index] == ROW_BACK:
		closed.emit()


## Movement-only path (task brief; class header). See that header for why
## left/right, not up/down, is this row's own hold axis.
func _poll_back_hold(delta: float) -> void:
	var on_back: bool = ROW_ORDER[_highlighted_index] == ROW_BACK
	var held: bool = _is_pressed(&"move_left") or _is_pressed(&"move_right")
	if not on_back:
		_back_hold_progress = 0.0
		_back_hold_armed = not held # neutral-return rule, applied continuously while off Back
		return
	if not _back_hold_armed:
		if not held:
			_back_hold_armed = true
		return
	if held:
		_back_hold_progress += delta
		if _back_hold_progress >= HOLD_CONFIRM_SECONDS:
			_back_hold_progress = 0.0
			closed.emit()
	else:
		_back_hold_progress = 0.0


func _move_highlight(step: int) -> void:
	_highlighted_index = wrapi(_highlighted_index + step, 0, ROW_ORDER.size())
	_refresh_highlight()


func _apply_direction(direction: int) -> void:
	var id: String = ROW_ORDER[_highlighted_index]
	match id:
		ROW_MASTER_VOLUME:
			GameSettings.adjust_master_volume(direction)
		ROW_MUSIC_VOLUME:
			GameSettings.adjust_music_volume(direction)
		ROW_EFFECTS_VOLUME:
			GameSettings.adjust_effects_volume(direction)
		ROW_MUTE_ALL:
			GameSettings.set_mute_all(not GameSettings.is_mute_all())
		ROW_DISPLAY_MODE:
			GameSettings.cycle_display_mode(direction)
		ROW_VSYNC:
			GameSettings.set_vsync_enabled(not GameSettings.is_vsync_enabled())
		ROW_SCREEN_SHAKE:
			GameSettings.set_screen_shake_enabled(not GameSettings.is_screen_shake_enabled())
		ROW_DAMAGE_NUMBERS:
			GameSettings.set_damage_numbers_enabled(not GameSettings.are_damage_numbers_enabled())
		ROW_MOVEMENT_ONLY:
			GameSettings.set_movement_only_controls_enabled(not GameSettings.get_movement_only_controls_enabled())
		ROW_BACK:
			return # no value -- see class header for the Back row's own hold gesture
	_refresh_row(id)


func _refresh_all_rows() -> void:
	for id: String in ROW_ORDER:
		_refresh_row(id)


func _refresh_row(id: String) -> void:
	var row: SettingsRow = _rows.get(id) as SettingsRow
	if row == null:
		return
	match id:
		ROW_MASTER_VOLUME:
			row.set_value_text(_pct_text(GameSettings.get_master_volume_pct()))
		ROW_MUSIC_VOLUME:
			row.set_value_text(_pct_text(GameSettings.get_music_volume_pct()))
		ROW_EFFECTS_VOLUME:
			row.set_value_text(_pct_text(GameSettings.get_effects_volume_pct()))
		ROW_MUTE_ALL:
			row.set_value_text(_on_off_text(GameSettings.is_mute_all()))
		ROW_DISPLAY_MODE:
			row.set_value_text(_display_mode_text(GameSettings.get_display_mode()))
		ROW_VSYNC:
			row.set_value_text(_on_off_text(GameSettings.is_vsync_enabled()))
		ROW_SCREEN_SHAKE:
			row.set_value_text(_on_off_text(GameSettings.is_screen_shake_enabled()))
		ROW_DAMAGE_NUMBERS:
			row.set_value_text(_on_off_text(GameSettings.are_damage_numbers_enabled()))
		ROW_MOVEMENT_ONLY:
			row.set_value_text(_on_off_text(GameSettings.get_movement_only_controls_enabled()))
		ROW_BACK:
			pass


func _refresh_highlight() -> void:
	for i: int in ROW_ORDER.size():
		var row: SettingsRow = _rows.get(ROW_ORDER[i]) as SettingsRow
		if row != null:
			row.set_highlighted(i == _highlighted_index)


func _update_fill_ring_visual() -> void:
	if _fill_ring == null:
		return
	var on_back: bool = ROW_ORDER[_highlighted_index] == ROW_BACK
	_fill_ring.progress = clampf(_back_hold_progress / HOLD_CONFIRM_SECONDS, 0.0, 1.0) if on_back else 0.0


func _pct_text(pct: int) -> String:
	return "%d%%" % pct


func _on_off_text(enabled: bool) -> String:
	return tr("SETTINGS_ON") if enabled else tr("SETTINGS_OFF")


func _display_mode_text(mode: int) -> String:
	match mode:
		GameSettings.DisplayMode.FULLSCREEN:
			return tr("SETTINGS_DISPLAY_FULLSCREEN")
		GameSettings.DisplayMode.BORDERLESS:
			return tr("SETTINGS_DISPLAY_BORDERLESS")
		_:
			return tr("SETTINGS_DISPLAY_WINDOWED")


## Seeds every held-flag from the LIVE input state the instant this screen
## becomes active (blind review fix, item 4) -- a key already held at open
## (for example `move_up`, still held from hold-confirming "Settings" on the
## pause menu) must not be misread as a fresh press once the open lockout
## ends: `_up_held`/etc. start TRUE for a key that is already down, and their
## repeat timers start at a FULL `CYCLE_REPEAT_SECONDS` so an already-held
## key does not auto-repeat instantly either, matching how a genuinely fresh
## press-and-hold would only repeat after that same interval. See class
## header, "0.4 s open lockout + held-input seeding," and
## `src/run/paused_choice_bar.gd`'s own mirror-case fix.
func _seed_input_state() -> void:
	_up_held = _is_pressed(&"move_up")
	_down_held = _is_pressed(&"move_down")
	_left_held = _is_pressed(&"move_left")
	_right_held = _is_pressed(&"move_right")
	_up_repeat_timer = CYCLE_REPEAT_SECONDS
	_down_repeat_timer = CYCLE_REPEAT_SECONDS
	_left_repeat_timer = CYCLE_REPEAT_SECONDS
	_right_repeat_timer = CYCLE_REPEAT_SECONDS
	_back_hold_progress = 0.0
	_back_hold_armed = not (_is_pressed(&"move_left") or _is_pressed(&"move_right"))


func _is_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_pressed.get(action, false))
	return Input.is_action_pressed(action)


func _is_just_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_just_pressed.get(action, false))
	return Input.is_action_just_pressed(action)


func _clear_test_edges_for_frame() -> void:
	if _use_test_input:
		_test_just_pressed.clear()
