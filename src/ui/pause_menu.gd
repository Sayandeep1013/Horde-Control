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

signal resume_requested()
signal settings_requested()

var _root: Control
var _bar: PausedChoiceBar
var _fill_ring: DraftFillRing
var _title_label: Label


func _ready() -> void:
	layer = PAUSE_MENU_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


## Typed command. `active` shows/hides this whole screen AND gates its
## input bar's own polling (a hidden bar must not still be consuming
## `pause`-adjacent movement input meant for gameplay or another menu).
func set_active(active: bool) -> void:
	visible = active
	_bar.set_active(active)


func is_active_for_test() -> bool:
	return visible


func get_bar_for_test() -> PausedChoiceBar:
	return _bar


func _on_option_confirmed(index: int) -> void:
	if index == OPTION_RESUME:
		resume_requested.emit()
	elif index == OPTION_SETTINGS:
		settings_requested.emit()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.6) # matches the Draft's own 60% dim (Register > "Level-Up Draft") -- no Register row of its own for THIS menu, cited as the same reused interpretation named in paused_choice_bar.gd's header
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(center)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 28)
	center.add_child(column)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = tr("PAUSE_MENU_TITLE")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.custom_minimum_size = Vector2(320, 0)
	column.add_child(_title_label)

	_bar = PausedChoiceBar.new()
	_bar.name = "ChoiceBar"
	_bar.set_options([tr("PAUSE_MENU_RESUME"), tr("PAUSE_MENU_SETTINGS")])
	_bar.option_confirmed.connect(_on_option_confirmed)
	column.add_child(_bar)

	_fill_ring = DraftFillRing.new()
	_fill_ring.name = "HoldRing"
	_fill_ring.custom_minimum_size = Vector2(48, 48)
	column.add_child(_fill_ring)
	_bar.set_fill_ring(_fill_ring)
