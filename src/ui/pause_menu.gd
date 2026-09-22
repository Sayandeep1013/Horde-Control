extends CanvasLayer
class_name PauseMenu

## Pause Menu (P2.14 - Run flow). MASTER_SDLC.md > Provisional Values
## Register > "Interfaces" > "Platform input floor" (horizontal layout,
## hold-to-confirm); docs/19_UI_UX.md > "Input Map": "Pause Escape / Start."
##
## ## One writer, this file only reacts (mirrors src/ui/console.gd's own
## header, point 2, for the identical reason)
## This file NEVER calls `PauseAuthority.push_reason()` / `pop_reason()` /
## `push_reason_immediate()` / `pop_reason_immediate()` and never writes
## `get_tree().paused` -- grep confirms it. `src/run/run_flow_controller.gd`
## is the one caller that pushes/pops `PauseAuthority.REASON_PAUSE_MENU`
## (on the `pause` action), `REASON_FOCUS_LOSS` (window focus lost), and
## `REASON_CONTROLLER_DISCONNECT` (a joypad disconnects) -- all three
## reasons this menu exists to represent to the player. This file's own job
## is presentation and to report which option the player picked
## (`resume_requested` / `settings_requested`); RunFlowController decides
## what that means for PauseAuthority's reason set. See
## src/run/paused_choice_bar.gd's own header for the matching GodotPrompter
## skill-conflict note (the `godot-ui` skill's pause-menu example writes
## `get_tree().paused` directly; this project's document wins).
##
## ## Coexistence with the Level-Up Draft and the Tower Console
## The Draft (src/ui/draft_controller.gd) has no Cancel and must always
## resolve -- RunFlowController refuses to open this menu at all while
## `PauseAuthority.REASON_DRAFT` is active, so this menu is never shown
## stacked on top of an open Draft (see run_flow_controller.gd's own
## `_on_pause_action_pressed()`). The Tower Console
## (src/ui/console.gd) already hides itself and goes input-dead whenever
## ANY pause reason is active (that file's own `_on_pause_reasons_changed()`
## handler, built in P2.13) -- this menu opening (pushing
## `REASON_PAUSE_MENU`) is therefore already sufficient to hide the Console
## with no code in this file or the Console needing to know about each
## other directly, matching docs/20 > "Communication, events": systems
## react to PauseAuthority, never to each other.
##
## ## Paused-menu timing carve-out (Author decision D104)
## This file owns no timing of its own -- see
## src/run/paused_choice_bar.gd's header for the one accumulator this
## screen's hold-to-confirm ring actually runs on.
##
## ## UI pass (package D): look and feel only
## `_build_ui()` now goes through `src/ui/menu_frame.gd`'s shared builders
## (Root/Dim/Center/Card/Column, title, separator, the bar's own choice
## labels, and a highlight-shape sibling row) so this screen, SettingsMenu,
## and RunEndScreen read as one design. `set_active()` gained a purely
## cosmetic fade/scale-in on the card (rule 6) -- it still sets `visible`
## and calls `_bar.set_active()` FIRST, synchronously, exactly as before;
## the motion never delays either. No signal, public method, node name, or
## `_for_test` seam changed. See phases/UI_PASS/reports/D_menus.md.
##
## ## Follow-up (coordinator review): hold-ring spacing tightened
## The highlight row and the hold-to-confirm ring now sit together inside
## `MenuFrame.build_hold_footer()`'s own tight `VBoxContainer` (matching
## SettingsMenu/RunEndScreen) instead of being two more direct children of
## the column at its normal, larger separation -- the coordinator's review
## found the ring "floating alone ... with a lot of empty space" below the
## underline. No hint text was added to the ring; it had none before.
##
## ## Main Menu option (title screen + credits session)
## A third choice, "Main Menu," alongside Resume/Settings -- this project
## had no restart or quit option anywhere to retarget (grepped; none
## existed), so this is a genuinely new choice, not a retargeted one.
## `RunFlowController._on_main_menu_requested()` is the one caller that
## reacts to `main_menu_requested` -- exactly like `resume_requested` and
## `settings_requested` above, this file only reports which option the
## player picked and owns no scene-change or PauseAuthority logic of its
## own.

## Above src/ui/hud.gd (layer 10) and src/ui/threat_feedback.gd (layer 11);
## below the Level-Up Draft (src/ui/draft_controller.gd, layer 20) only
## because the two are never shown at once (see class header,
## "Coexistence") -- there is no ordering requirement between them in
## practice, but keeping this menu's layer below the Draft's costs nothing
## and reads as "the Draft, when it can appear at all, always wins." Not a
## Provisional Values Register number -- see hud.gd's identical note: no
## Register row assigns CanvasLayer indices.
const PAUSE_MENU_CANVAS_LAYER: int = 18

const OPTION_RESUME: int = 0
const OPTION_SETTINGS: int = 1
const OPTION_MAIN_MENU: int = 2

signal resume_requested()
signal settings_requested()
signal main_menu_requested()

var _root: Control
var _bar: PausedChoiceBar
var _fill_ring: DraftFillRing
var _title_label: Label
var _frame: MenuFrame.Parts


func _ready() -> void:
	layer = PAUSE_MENU_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


## Typed command. `active` shows/hides this whole screen AND gates its
## input bar's own polling (a hidden bar must not still be consuming
## `pause`-adjacent movement input meant for gameplay or another menu).
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


func _on_option_confirmed(index: int) -> void:
	if index == OPTION_RESUME:
		resume_requested.emit()
	elif index == OPTION_SETTINGS:
		settings_requested.emit()
	elif index == OPTION_MAIN_MENU:
		main_menu_requested.emit()


func _build_ui() -> void:
	UiStrings.ensure_registered() # UI pass round 2, UR-08: explicit here, not only reached as UiTheme.get_theme()'s side effect.
	# 0.6 matches the Draft's own 60% dim (Register > "Level-Up Draft") --
	# no Register row of its own for THIS menu, cited as the same reused
	# interpretation named in paused_choice_bar.gd's header. UiTheme.vbox("XL")
	# (UiPalette.SPACE_XL, 24) replaces this file's own former literal
	# separation (28).
	_frame = MenuFrame.build(self, 0.6, "XL")
	_root = _frame.root

	_title_label = MenuFrame.build_title(_frame.column, tr("PAUSE_MENU_TITLE"), UiTheme.HEADING, 320.0)
	MenuFrame.build_separator(_frame.column)

	_bar = PausedChoiceBar.new()
	_bar.name = "ChoiceBar"
	_bar.set_options([tr("PAUSE_MENU_RESUME"), tr("PAUSE_MENU_SETTINGS"), tr("PAUSE_MENU_MAIN_MENU")])
	_bar.option_confirmed.connect(_on_option_confirmed)
	_frame.column.add_child(_bar)
	MenuFrame.style_choice_labels(_bar)

	var hold_footer: VBoxContainer = MenuFrame.build_hold_footer(_frame.column)
	MenuFrame.build_highlight_row(hold_footer, _bar)

	_fill_ring = DraftFillRing.new()
	_fill_ring.name = "HoldRing"
	_fill_ring.custom_minimum_size = Vector2(48, 48)
	MenuFrame.style_fill_ring(_fill_ring)
	hold_footer.add_child(_fill_ring)
	_bar.set_fill_ring(_fill_ring)
