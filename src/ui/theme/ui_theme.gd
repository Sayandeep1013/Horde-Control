extends RefCounted
class_name UiTheme

## UiTheme (UI pass). Builds the one shared `Theme` every UI surface uses,
## from `UiPalette` tokens, and caches it.
##
## Built in code rather than authored as a `.tres` for the same reason every
## scene under src/ui/ is (see src/ui/hud.gd's header): the whole look stays
## in reviewable GDScript, and a gdUnit4 test that instances `Hud.new()` with
## no scene load still gets the real theme. A surface applies it ONCE, at its
## root Control (`root.theme = UiTheme.get_theme()`), and inherits from there;
## per-node `add_theme_*_override` is for genuine one-offs only.
##
## Type variations (set `theme_type_variation` on the node):
##   PanelContainer: &"UiPill", &"UiPanel", &"UiCard", &"UiTooltip", &"UiRow",
##                   &"UiRowHighlighted"
##   Label:          &"UiTitle", &"UiHeading", &"UiValue", &"UiDim", &"UiSmall"

const PILL: StringName = &"UiPill"
const PANEL: StringName = &"UiPanel"
const CARD: StringName = &"UiCard"
const TOOLTIP: StringName = &"UiTooltip"
const ROW: StringName = &"UiRow"
const ROW_HIGHLIGHTED: StringName = &"UiRowHighlighted"

const TITLE: StringName = &"UiTitle"
const HEADING: StringName = &"UiHeading"
const VALUE: StringName = &"UiValue"
const DIM: StringName = &"UiDim"
const SMALL: StringName = &"UiSmall"

static var _theme: Theme = null
static var _body_font: Font = null
static var _display_font: Font = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func get_body_font() -> Font:
	if _body_font == null:
		_body_font = _make_font(UiPalette.FONT_WEIGHT_BODY)
	return _body_font


static func get_display_font() -> Font:
	if _display_font == null:
		_display_font = _make_font(UiPalette.FONT_WEIGHT_DISPLAY)
	return _display_font


## A flat box from palette tokens. Public so custom-drawn controls (HudBar,
## the fill rings, a card frame that changes shape at runtime) can build a
## matching box without restating colours.
static func make_box(fill: Color, border: Color, radius: int, border_width: int = UiPalette.BORDER_THIN, padding: int = UiPalette.SPACE_M) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(padding)
	sb.anti_aliasing = true
	return sb


static func _make_font(weight: int) -> Font:
	var base: Font = null
	if ResourceLoader.exists(UiPalette.FONT_PATH):
		base = load(UiPalette.FONT_PATH) as Font
	if base == null:
		# Font not imported yet (fresh clone before its first import): fall
		# back to the engine font rather than failing the whole UI.
		return ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = base
	var wght_tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	variation.variation_opentype = {wght_tag: weight}
	return variation


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = get_body_font()
	t.default_font_size = UiPalette.FONT_SIZE_BODY

	_build_labels(t)
	_build_panels(t)
	_build_buttons(t)
	_build_inputs(t)
	_build_containers(t)
	return t


static func _build_labels(t: Theme) -> void:
	t.set_color("font_color", "Label", UiPalette.TEXT)
	t.set_color("font_outline_color", "Label", UiPalette.TEXT_OUTLINE)
	t.set_constant("outline_size", "Label", UiPalette.OUTLINE_BODY)
	t.set_constant("line_spacing", "Label", 2)

	_label_variation(t, TITLE, UiPalette.FONT_SIZE_TITLE, UiPalette.TEXT, UiPalette.OUTLINE_DISPLAY, true)
	_label_variation(t, HEADING, UiPalette.FONT_SIZE_HEADING, UiPalette.TEXT, UiPalette.OUTLINE_DISPLAY, true)
	_label_variation(t, VALUE, UiPalette.FONT_SIZE_VALUE, UiPalette.TEXT, UiPalette.OUTLINE_BODY, true)
	_label_variation(t, DIM, UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_DIM, UiPalette.OUTLINE_BODY, false)
	_label_variation(t, SMALL, UiPalette.FONT_SIZE_SMALL, UiPalette.TEXT_DIM, UiPalette.OUTLINE_BODY, false)

	t.set_color("default_color", "RichTextLabel", UiPalette.TEXT)
	t.set_color("font_outline_color", "RichTextLabel", UiPalette.TEXT_OUTLINE)
	t.set_constant("outline_size", "RichTextLabel", UiPalette.OUTLINE_BODY)
	t.set_font("normal_font", "RichTextLabel", get_body_font())
	t.set_font("bold_font", "RichTextLabel", get_display_font())


static func _label_variation(t: Theme, variation: StringName, font_size: int, color: Color, outline: int, display: bool) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font_size("font_size", variation, font_size)
	t.set_color("font_color", variation, color)
	t.set_color("font_outline_color", variation, UiPalette.TEXT_OUTLINE)
	t.set_constant("outline_size", variation, outline)
	if display:
		t.set_font("font", variation, get_display_font())


static func _build_panels(t: Theme) -> void:
	var ink := UiPalette.with_alpha(UiPalette.INK, UiPalette.PANEL_ALPHA)
	var surface := UiPalette.with_alpha(UiPalette.SURFACE, UiPalette.CARD_ALPHA)

	t.set_stylebox("panel", "PanelContainer", make_box(ink, UiPalette.LINE, UiPalette.RADIUS_PANEL))

	_panel_variation(t, PILL, make_box(ink, UiPalette.LINE, UiPalette.RADIUS_PILL, UiPalette.BORDER_THIN, UiPalette.SPACE_S))
	_panel_variation(t, PANEL, make_box(ink, UiPalette.LINE, UiPalette.RADIUS_PANEL, UiPalette.BORDER_THIN, UiPalette.SPACE_L))
	_panel_variation(t, CARD, make_box(surface, UiPalette.LINE_STRONG, UiPalette.RADIUS_PANEL, UiPalette.BORDER_THIN, UiPalette.SPACE_L))
	_panel_variation(t, TOOLTIP, make_box(UiPalette.INK, UiPalette.LINE_STRONG, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THIN, UiPalette.SPACE_S))
	_panel_variation(t, ROW, make_box(UiPalette.with_alpha(UiPalette.SURFACE, 0.55), UiPalette.with_alpha(UiPalette.LINE, 0.0), UiPalette.RADIUS_SMALL, UiPalette.BORDER_THIN, UiPalette.SPACE_XS))
	_panel_variation(t, ROW_HIGHLIGHTED, make_box(UiPalette.with_alpha(UiPalette.SURFACE_HOVER, 0.95), UiPalette.ACCENT, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THIN, UiPalette.SPACE_XS))


static func _panel_variation(t: Theme, variation: StringName, box: StyleBox) -> void:
	t.set_type_variation(variation, "PanelContainer")
	t.set_stylebox("panel", variation, box)


static func _build_buttons(t: Theme) -> void:
	var pad_h: int = UiPalette.SPACE_XL
	var pad_v: int = UiPalette.SPACE_M
	var normal := _button_box(UiPalette.SURFACE, UiPalette.LINE, pad_h, pad_v)
	var hover := _button_box(UiPalette.SURFACE_HOVER, UiPalette.LINE_STRONG, pad_h, pad_v)
	var pressed := _button_box(UiPalette.INK, UiPalette.ACCENT, pad_h, pad_v)
	var disabled := _button_box(UiPalette.with_alpha(UiPalette.SURFACE, 0.5), UiPalette.with_alpha(UiPalette.LINE, 0.5), pad_h, pad_v)
	# Focus is drawn OVER the normal box, so it is border-only: a thicker
	# accent outline. Shape (border weight), not colour alone, marks focus
	# (MASTER_SDLC.md > Visual Edge Cases > "Colour-only distinctions").
	var focus := _button_box(Color(0, 0, 0, 0), UiPalette.ACCENT, pad_h, pad_v)
	focus.set_border_width_all(UiPalette.BORDER_THICK)
	focus.draw_center = false

	for type_name: String in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", type_name, normal)
		t.set_stylebox("hover", type_name, hover)
		t.set_stylebox("pressed", type_name, pressed)
		t.set_stylebox("hover_pressed", type_name, pressed)
		t.set_stylebox("disabled", type_name, disabled)
		t.set_stylebox("focus", type_name, focus)
		t.set_color("font_color", type_name, UiPalette.TEXT)
		t.set_color("font_hover_color", type_name, UiPalette.ACCENT)
		t.set_color("font_focus_color", type_name, UiPalette.ACCENT)
		t.set_color("font_pressed_color", type_name, UiPalette.ACCENT)
		t.set_color("font_hover_pressed_color", type_name, UiPalette.ACCENT)
		t.set_color("font_disabled_color", type_name, UiPalette.TEXT_DISABLED)
		t.set_color("font_outline_color", type_name, UiPalette.TEXT_OUTLINE)
		t.set_constant("outline_size", type_name, UiPalette.OUTLINE_BODY)
		t.set_font("font", type_name, get_display_font())
		t.set_font_size("font_size", type_name, UiPalette.FONT_SIZE_VALUE)


static func _button_box(fill: Color, border: Color, pad_h: int, pad_v: int) -> StyleBoxFlat:
	var sb := make_box(fill, border, UiPalette.RADIUS_PANEL)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func _build_inputs(t: Theme) -> void:
	var track := make_box(UiPalette.INK, UiPalette.LINE, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THIN, 0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := make_box(UiPalette.ACCENT, UiPalette.ACCENT, UiPalette.RADIUS_SMALL, 0, 0)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)

	var separator := StyleBoxLine.new()
	separator.color = UiPalette.LINE
	separator.thickness = UiPalette.BORDER_THIN
	t.set_stylebox("separator", "HSeparator", separator)

	t.set_stylebox("panel", "TooltipPanel", make_box(UiPalette.INK, UiPalette.LINE_STRONG, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THIN, UiPalette.SPACE_S))
	t.set_color("font_color", "TooltipLabel", UiPalette.TEXT)


static func _build_containers(t: Theme) -> void:
	t.set_constant("separation", "VBoxContainer", UiPalette.SPACE_S)
	t.set_constant("separation", "HBoxContainer", UiPalette.SPACE_S)
	t.set_constant("h_separation", "GridContainer", UiPalette.SPACE_L)
	t.set_constant("v_separation", "GridContainer", UiPalette.SPACE_S)
