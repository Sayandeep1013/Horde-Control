extends CanvasLayer
class_name SettingsMenu

## Settings Menu (P2.14 - Run flow). Reachable from the pause menu and from
## the run-end screens (task brief; MASTER_SDLC.md > Provisional Values
## Register > "Interfaces" > "Movement-only controls setting" (C-SECTORS):
## "Default off; offered as a hold-to-confirm choice on run-end screens and
## pause/settings menus"). Carries exactly one setting in this prototype:
## the Movement-only controls toggle.
##
## ## The one thing this file actually controls
## `Console.movement_only_controls_enabled` (src/ui/console.gd) "already
## exposes [it] as a plain exported bool, default off" (task brief) -- this
## file's `_apply_to_console()` sets that field directly, a legitimate
## typed-property write on a public `@export`ed field the Console's own
## header already documents as the pause/settings menu's seam
## (`console.movement_only_controls_enabled = true`), not a new command
## invented here.
##
## ## "Temporary debug persistence" (task brief, P2.14 inputs), named as an
## interpretation
## The prototype has no save system (explicitly out of scope for this
## task) and no "start a new run" flow exists yet in this phase (that is
## P2.16/prototype-validation territory) -- so there is nothing today for
## this setting to persist ACROSS. Rather than invent a save file this
## task's own hard constraints forbid, the toggle's value is kept on this
## script's own field for as long as ONE `SettingsMenu` instance lives
## (surviving a Console being freed and re-wired, or a run ending and a
## fresh RunEndScreen/PauseMenu opening this same instance again), and
## `_STATIC_LAST_VALUE` additionally remembers it at the CLASS level so a
## brand-new `SettingsMenu` instance (e.g. one built by a fresh
## RunFlowController for a new run, in-process) starts from whatever the
## player last chose rather than silently resetting to the Register's
## "default off" every time. This is in-memory only -- it does not survive
## the Godot process exiting, which is exactly what "save system excluded"
## rules out. Named here and in the P2.14 evidence report, not silently
## assumed to mean disk persistence.
##
## ## Paused-menu timing carve-out (Author decision D104)
## Owns no timing of its own -- see src/run/paused_choice_bar.gd's header.
##
## ## UI pass (package D): look and feel only
## `_build_ui()` now goes through `src/ui/menu_frame.gd`'s shared builders,
## matching pause_menu.gd/run_end.gd. The choice bar itself is UNCHANGED:
## still one `PausedChoiceBar`, still the same two options, still the same
## `_refresh_toggle_label()` call that sets its Option0 text. `set_active()`
## gained the same purely cosmetic fade/scale-in as the other two menus. No
## signal, public method, node name, or `_for_test` seam changed. See
## phases/UI_PASS/reports/D_menus.md.
##
## ## Follow-up (coordinator review): decorative row removed
## An earlier version of this pass added a second, purely decorative
## "labelled row" mirroring the toggle state above the choice bar -- the
## coordinator's review (looking at the launched scene) found it read as a
## redundant restatement of the SAME line the bar's own Option0 already
## shows ("Movement-only controls: Off" twice). Removed; the toggle option
## Label is instead given enough `custom_minimum_size.x` to fit its own
## longest state on one line at 1920x1080 (`TOGGLE_OPTION_MIN_WIDTH`,
## measured against the actual `UiTheme.VALUE` font -- see
## phases/UI_PASS/reports/D_menus.md for the exact measurement), so the
## one real control reads clearly without a duplicate.

signal closed()

const OPTION_TOGGLE: int = 0
const OPTION_BACK: int = 1

## Above src/ui/hud.gd (10) / src/ui/threat_feedback.gd (11); above
## src/ui/pause_menu.gd (18) and src/ui/run_end.gd (19) since this screen
## is always opened ON TOP of one of those two (task brief: "reachable
## from the pause menu and from the run-end screens") and must occlude
## whichever one is underneath. Not a Provisional Values Register number
## -- see hud.gd's identical note.
const SETTINGS_MENU_CANVAS_LAYER: int = 21

static var _static_last_value: bool = false # see class header, "Temporary debug persistence"

var movement_only_controls_enabled: bool = false

var _console: Console = null

var _root: Control
var _bar: PausedChoiceBar
var _fill_ring: DraftFillRing
var _title_label: Label
var _toggle_label_prefix: String = ""
var _frame: MenuFrame.Parts

## The toggle option's own minimum width, wide enough that "Movement-only
## controls: Off" (the longer of the two states, `UiTheme.VALUE` font,
## measured directly against the shipped font) fits on one line at
## 1920x1080 -- 340 px measured, this leaves headroom for the outline.
## TODO(ui-pass): promote to UiPalette if another menu ever needs it.
const TOGGLE_OPTION_MIN_WIDTH: float = 360.0


func _ready() -> void:
	layer = SETTINGS_MENU_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	movement_only_controls_enabled = _static_last_value
	_build_ui()
	_refresh_toggle_label()


## Typed command. The orchestrator (whoever assembles the run scene) calls
## this once with the real Console instance so this menu's toggle can
## actually reach it; a test calls the same seam under its usual
## `_for_test` name for symmetry with the rest of this codebase's
## convention, but this is production wiring, not merely a test double --
## matching src/ui/console.gd's own `set_run_inventory()` (a "typed
## COMMAND, not merely a test seam").
func set_console_ref(console: Console) -> void:
	_console = console
	if _console != null:
		_console.movement_only_controls_enabled = movement_only_controls_enabled


func set_console_ref_for_test(console: Console) -> void:
	set_console_ref(console)


func get_console_ref_for_test() -> Console:
	return _console


## The card's own fade/scale-in (UI pass) is purely cosmetic and runs
## AFTER these two lines, never before or instead of them -- input
## activation is never delayed by it (rule 6).
func set_active(active: bool) -> void:
	visible = active
	_bar.set_active(active)
	if active:
		MenuFrame.animate_in(_frame)
	else:
		MenuFrame.reset_motion(_frame)


func is_active_for_test() -> bool:
	return visible


func get_bar_for_test() -> PausedChoiceBar:
	return _bar


func get_movement_only_controls_enabled_for_test() -> bool:
	return movement_only_controls_enabled


func _on_option_confirmed(index: int) -> void:
	if index == OPTION_TOGGLE:
		_toggle_movement_only()
	elif index == OPTION_BACK:
		closed.emit()


func _toggle_movement_only() -> void:
	movement_only_controls_enabled = not movement_only_controls_enabled
	_static_last_value = movement_only_controls_enabled
	if _console != null:
		_console.movement_only_controls_enabled = movement_only_controls_enabled
	_refresh_toggle_label()


func _refresh_toggle_label() -> void:
	if _bar == null or _bar.get_option_count() < 1:
		return
	var state_text: String = tr("SETTINGS_ON") if movement_only_controls_enabled else tr("SETTINGS_OFF")
	var label: Label = _bar.get_option_label_for_test(OPTION_TOGGLE)
	if label != null:
		label.text = "%s: %s" % [_toggle_label_prefix, state_text]


func _build_ui() -> void:
	# UiPalette.SPACE_XL (24) replaces this file's own former literal
	# separation (28); this menu's dim never had its own comment on the
	# alpha (nothing to preserve there).
	_frame = MenuFrame.build(self, 0.6, UiPalette.SPACE_XL)
	_root = _frame.root

	_title_label = MenuFrame.build_title(_frame.column, tr("SETTINGS_MENU_TITLE"), UiTheme.HEADING, 360.0)
	MenuFrame.build_separator(_frame.column)

	_toggle_label_prefix = tr("SETTINGS_MOVEMENT_ONLY")

	_bar = PausedChoiceBar.new()
	_bar.name = "ChoiceBar"
	_bar.set_options(["%s: %s" % [_toggle_label_prefix, tr("SETTINGS_OFF")], tr("SETTINGS_BACK")])
	_bar.option_confirmed.connect(_on_option_confirmed)
	_frame.column.add_child(_bar)
	MenuFrame.style_choice_labels(_bar)
	_widen_toggle_option(_bar)

	var hold_footer: VBoxContainer = MenuFrame.build_hold_footer(_frame.column)
	MenuFrame.build_highlight_row(hold_footer, _bar)

	_fill_ring = DraftFillRing.new()
	_fill_ring.name = "HoldRing"
	_fill_ring.custom_minimum_size = Vector2(48, 48)
	MenuFrame.style_fill_ring(_fill_ring)
	hold_footer.add_child(_fill_ring)
	_bar.set_fill_ring(_fill_ring)


## Widens ONLY the toggle option's Label so its own longest state text
## ("Movement-only controls: Off") fits on one line at 1920x1080, without
## touching the shorter "Back" option next to it. Reached via
## `get_children()` (positional -- Option0 is always built first by
## `PausedChoiceBar.set_options()`), never the `_for_test` seam, matching
## `MenuFrame.style_choice_labels()`'s own hard-boundary carve-out.
func _widen_toggle_option(bar: PausedChoiceBar) -> void:
	var children := bar.get_children()
	if OPTION_TOGGLE >= 0 and OPTION_TOGGLE < children.size() and children[OPTION_TOGGLE] is Label:
		(children[OPTION_TOGGLE] as Label).custom_minimum_size.x = TOGGLE_OPTION_MIN_WIDTH
