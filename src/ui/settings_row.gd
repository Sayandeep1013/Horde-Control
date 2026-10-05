extends HBoxContainer
class_name SettingsRow

## One row of the rebuilt Settings screen (src/ui/settings_menu.gd; Review
## Decision Log D121: "a row-list settings screen with 10% steps"). Label on
## the left, "< value >" on the right for every row except Back (task
## brief). Built in code, like every other UI surface in this project (see
## src/ui/menu_frame.gd's own header) -- no scene file, instantiated via
## `SettingsRow.new()` exactly like `PausedChoiceBar`.
##
## Highlight is a `modulate` tint (matching `PausedChoiceBar._refresh_highlight()`'s
## own convention letter for letter) PLUS a shape cue -- a leading marker
## glyph that only exists on the highlighted row -- so the highlight is never
## colour-only (MASTER_SDLC.md > Visual Edge Cases > "Colour-only
## distinctions"; the same rule `MenuFrame`'s `ChoiceHighlightRow` exists to
## satisfy for the three horizontal menus, applied here with a cheaper cue
## since `ChoiceHighlightRow` is built specifically around a `PausedChoiceBar`'s
## own horizontal rect and does not fit a vertical row list without changes
## to a file this task did not need to touch).
##
## Purely presentational: this row never reads GameSettings or Input itself.
## `SettingsMenu` owns the row order, the current value text, and every
## signal below is a raw user gesture reported upward, matching
## `PausedChoiceBar`'s own "report, don't decide" shape.

signal hovered() ## mouse entered anywhere on this row -- SettingsMenu highlights it
signal clicked() ## mouse press on the row's own name/value area (not an arrow) -- Back closes on this; other rows just (re)confirm the highlight
signal left_pressed() ## mouse press on the "<" arrow
signal right_pressed() ## mouse press on the ">" arrow

## D166: tints over white label text, so the row reads as dark ink at rest and deep red-brown when highlighted (parchment card).
const HIGHLIGHT_COLOR: Color = UiPalette.HIGHLIGHT_ON_PARCHMENT
const NORMAL_COLOR: Color = UiPalette.TEXT_ON_PARCHMENT
const MARKER_HIGHLIGHTED: String = "▸ " # "▸" -- the shape cue, see class header
const MARKER_NORMAL: String = "   "

const VALUE_MIN_WIDTH: float = 200.0
const ARROW_MIN_WIDTH: float = 36.0
const NAME_MIN_WIDTH: float = 420.0

var _marker_label: Label
var _name_label: Label
var _left_arrow: Label
var _value_label: Label
var _right_arrow: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme_type_variation = UiTheme.hbox("M")
	modulate = NORMAL_COLOR

	_marker_label = Label.new()
	_marker_label.name = "Marker"
	_marker_label.theme_type_variation = UiTheme.HUD_VALUE
	_white_text(_marker_label)
	_marker_label.text = MARKER_NORMAL
	_marker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker_label)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.theme_type_variation = UiTheme.HUD_VALUE
	_white_text(_name_label)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.custom_minimum_size = Vector2(NAME_MIN_WIDTH, TouchUi.touch_height(0.0))
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_label.mouse_entered.connect(_on_hovered)
	_name_label.gui_input.connect(_on_body_gui_input)
	add_child(_name_label)

	_left_arrow = _make_arrow("<")
	_left_arrow.gui_input.connect(_on_left_gui_input)
	add_child(_left_arrow)

	_value_label = Label.new()
	_value_label.name = "Value"
	_value_label.theme_type_variation = UiTheme.HUD_VALUE
	_white_text(_value_label)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.custom_minimum_size = Vector2(VALUE_MIN_WIDTH, TouchUi.touch_height(0.0))
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_value_label.mouse_entered.connect(_on_hovered)
	_value_label.gui_input.connect(_on_body_gui_input)
	add_child(_value_label)

	_right_arrow = _make_arrow(">")
	_right_arrow.gui_input.connect(_on_right_gui_input)
	add_child(_right_arrow)


func _make_arrow(text: String) -> Label:
	var lbl := Label.new()
	lbl.name = "ArrowLeft" if text == "<" else "ArrowRight"
	lbl.text = text
	lbl.theme_type_variation = UiTheme.HUD_VALUE
	_white_text(lbl)
	lbl.custom_minimum_size = Vector2(TouchUi.touch_height(ARROW_MIN_WIDTH), TouchUi.touch_height(0.0))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl.mouse_entered.connect(_on_hovered)
	return lbl



## White base colour and no outline: the row's `modulate` tint is the visible colour.
static func _white_text(lbl: Label) -> void:
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", 0)


## `has_value` is false for the Back row: no arrows, no value text.
func configure(name_text: String, has_value: bool) -> void:
	_name_label.text = name_text
	_left_arrow.visible = has_value
	_right_arrow.visible = has_value
	_value_label.visible = has_value


func set_value_text(text: String) -> void:
	_value_label.text = text


func set_highlighted(active: bool) -> void:
	modulate = HIGHLIGHT_COLOR if active else NORMAL_COLOR
	_marker_label.text = MARKER_HIGHLIGHTED if active else MARKER_NORMAL


# --- test seams ------------------------------------------------------------

func get_name_label_for_test() -> Label:
	return _name_label


func get_value_label_for_test() -> Label:
	return _value_label


func get_left_arrow_for_test() -> Label:
	return _left_arrow


func get_right_arrow_for_test() -> Label:
	return _right_arrow


func is_highlighted_for_test() -> bool:
	return _marker_label.text == MARKER_HIGHLIGHTED


# --- internals ---------------------------------------------------------------

func _on_hovered() -> void:
	hovered.emit()


func _on_body_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()


func _on_left_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _left_arrow.visible:
			return
		left_pressed.emit()


func _on_right_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _right_arrow.visible:
			return
		right_pressed.emit()
