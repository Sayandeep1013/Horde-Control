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
##                   &"UiRowHighlighted", &"UiRibbon"
##   Label:          &"UiTitle", &"UiHeading", &"UiValue", &"UiDim", &"UiSmall"
##   HBoxContainer / VBoxContainer: a separation step per UiPalette spacing
##                   token, via `hbox(step)` / `vbox(step)`. SPACE_S is the
##                   theme default and needs no variation.
##
## ## Tiny Swords medieval restyle (author decision, second UI pass)
## Every panel/pill/card/tooltip/row variation and every Button state below
## is now a `StyleBoxTexture` built from the pack's own carved-wood/parchment
## and button 9-slice sheets (`UiPalette.TEX_*`,
## assets/third_party/tiny_swords/UI/, PROVENANCE.md) instead of a flat
## `StyleBoxFlat`. `make_box()` (below) is UNCHANGED and stays the helper for
## every caller that mutates a StyleBox at RUNTIME (src/ui/console.gd's own
## per-row/per-instance panels, src/ui/draft_card_view.gd's per-card frame,
## which needs a real corner-radius toggle a texture cannot express) --
## console.gd's own header names this exact seam ("restyle it only through
## the theme"): its calls to `UiTheme.make_box()` and the `UiPalette` tokens
## it passes are untouched by this file, so the Console reskins automatically
## through the retinted `UiPalette` surface tokens (INK/SURFACE/LINE/...)
## alone, with no edit to console.gd itself.
const RIBBON: StringName = &"UiRibbon"

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

## Box-container separation steps: suffix -> UiPalette spacing token. A box
## that wants a non-default gap sets `theme_type_variation = UiTheme.hbox("XS")`
## rather than overriding the "separation" constant per node.
const BOX_STEPS: Dictionary = {
	"XS": UiPalette.SPACE_XS,
	"M": UiPalette.SPACE_M,
	"L": UiPalette.SPACE_L,
	"XL": UiPalette.SPACE_XL,
	"XXL": UiPalette.SPACE_XXL,
}

static var _theme: Theme = null
static var _body_font: Font = null
static var _display_font: Font = null


static func get_theme() -> Theme:
	# Every surface fetches the theme while it builds, before it sets any
	# text, which makes this the one choke point that guarantees the UI's
	# strings are registered first. See ui_strings.gd for why this is here
	# and when to remove it.
	UiStrings.ensure_registered()
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


## Variation name for an HBoxContainer whose separation is `BOX_STEPS[step]`.
static func hbox(step: String) -> StringName:
	assert(BOX_STEPS.has(step), "UiTheme.hbox: unknown separation step '%s'" % step)
	return StringName("UiHBox" + step)


## Variation name for a VBoxContainer whose separation is `BOX_STEPS[step]`.
static func vbox(step: String) -> StringName:
	assert(BOX_STEPS.has(step), "UiTheme.vbox: unknown separation step '%s'" % step)
	return StringName("UiVBox" + step)


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


## A 9-slice `StyleBoxTexture` from one of `UiPalette`'s Tiny Swords sheets.
## `texture_margin` controls how much of the TEXTURE is treated as a fixed
## (non-stretched) corner/edge -- `UiPalette.PANEL_TEXTURE_MARGIN`, measured
## against the source PNGs, for every caller below. `content_margin` is
## independent and usually smaller: it is how much inner padding a child
## Container reserves, and Godot does not require it to match the texture
## margin (a thinner content inset than the decorative frame is a normal,
## supported "framed insert" look, and is what keeps a HUD pill's total
## height well under its sane-height test bound even with a generous-looking
## wood frame). `modulate` tints/fades the whole texture -- used to keep a
## HUD pill translucent over the battlefield the same way the old flat
## `PANEL_ALPHA`/`CARD_ALPHA` did.
static func make_texture_box(texture_path: String, texture_margin: int, content_margin: int, modulate: Color = Color(1.0, 1.0, 1.0, 1.0)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(texture_path) as Texture2D
	sb.texture_margin_left = texture_margin
	sb.texture_margin_top = texture_margin
	sb.texture_margin_right = texture_margin
	sb.texture_margin_bottom = texture_margin
	sb.content_margin_left = content_margin
	sb.content_margin_top = content_margin
	sb.content_margin_right = content_margin
	sb.content_margin_bottom = content_margin
	sb.modulate_color = modulate
	return sb


## A 3-slice ribbon banner (`UiPalette.TEX_RIBBON_*`, 192x64): only the
## horizontal margins are real slice boundaries (PROVENANCE.md's own layout
## note: the sheet is exactly three 64px thirds, left flag end / body /
## right flag end) -- the vertical margin stays 0 so the whole 64px-tall
## source simply scales to whatever height the ribbon is given, which is
## always close to its native size in practice (a ribbon is never squashed
## thin the way a HUD pill can be).
static func make_ribbon_box(texture_path: String, content_margin_h: int = UiPalette.SPACE_L, content_margin_v: int = UiPalette.SPACE_XS) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(texture_path) as Texture2D
	sb.texture_margin_left = UiPalette.RIBBON_TEXTURE_MARGIN
	sb.texture_margin_right = UiPalette.RIBBON_TEXTURE_MARGIN
	sb.texture_margin_top = 0
	sb.texture_margin_bottom = 0
	sb.content_margin_left = content_margin_h
	sb.content_margin_right = content_margin_h
	sb.content_margin_top = content_margin_v
	sb.content_margin_bottom = content_margin_v
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
	# Ligatures off. The pass's first font, Pixelify Sans, substituted "fi"
	# with a single glyph that read as a capital A at UI sizes: the Rapid Fire
	# card said "player Are rate" (phases/UI_PASS/LEDGER.md, UR-01). Kept off
	# for any font: UI text at these sizes gains nothing from ligatures.
	var features: Dictionary = {}
	for feature: String in ["liga", "clig", "dlig", "hlig"]:
		features[TextServerManager.get_primary_interface().name_to_tag(feature)] = 0
	variation.opentype_features = features
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
	t.set_constant("line_spacing", "Label", UiPalette.LINE_SPACING)

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
	# Tiny Swords medieval restyle: every static panel variation is now the
	# carved-wood/parchment 9-slice (`UiPalette.TEX_PANEL_CARVED`), which
	# already reads as a wood-framed parchment insert on its own -- no per-
	# variation recolouring needed the way the old flat boxes needed a
	# distinct fill Color each. A modal CARD stays fully opaque (CARD_ALPHA,
	# matching the old value) since it always sits over a dedicated dim,
	# never bare gameplay.
	#
	# HUD polish (coordinator review, third pass): PILL is the one variation
	# that sits directly over LIVE, undimmed gameplay (the HUD's own field
	# pills, the Draft's Reroll pill) -- see UiPalette.PILL_TINT's own header
	# for why it darkens the same texture instead of using the lighter
	# PANEL_ALPHA every other variation keeps.
	var pill_box := make_texture_box(UiPalette.TEX_PANEL_CARVED, UiPalette.PANEL_TEXTURE_MARGIN, UiPalette.SPACE_S, UiPalette.PILL_TINT)
	var panel_box := make_texture_box(UiPalette.TEX_PANEL_CARVED, UiPalette.PANEL_TEXTURE_MARGIN, UiPalette.SPACE_L, Color(1, 1, 1, UiPalette.PANEL_ALPHA))
	var card_box := make_texture_box(UiPalette.TEX_PANEL_CARVED, UiPalette.PANEL_TEXTURE_MARGIN, UiPalette.SPACE_XL, Color(1, 1, 1, UiPalette.CARD_ALPHA))
	var tooltip_box := make_texture_box(UiPalette.TEX_PANEL_CARVED, UiPalette.PANEL_TEXTURE_MARGIN, UiPalette.SPACE_S)
	# A row (the run-end stat grid; Console builds its OWN per-row
	# StyleBoxFlat directly through make_box(), never this variation -- see
	# console.gd's own header) is shallow -- UiPalette.ROW_TEXTURE_MARGIN
	# (12, not the panel's own 26) keeps its carved frame crisp at that real
	# height instead of Godot compressing the corner art to fit (see that
	# constant's own header for the measured defect this replaced).
	var row_box := make_texture_box(UiPalette.TEX_PANEL_CARVED, UiPalette.ROW_TEXTURE_MARGIN, UiPalette.SPACE_XS, Color(1, 1, 1, 0.9))
	# Highlighted row: the pack's own "hover" button sheet reads as a bright,
	# gold-bordered inset -- exactly a highlight, with no recolouring needed.
	var row_highlighted_box := make_texture_box(UiPalette.TEX_BUTTON_HOVER, UiPalette.ROW_TEXTURE_MARGIN, UiPalette.SPACE_XS)

	t.set_stylebox("panel", "PanelContainer", panel_box)

	_panel_variation(t, PILL, pill_box)
	_panel_variation(t, PANEL, panel_box)
	_panel_variation(t, CARD, card_box)
	_panel_variation(t, TOOLTIP, tooltip_box)
	_panel_variation(t, ROW, row_box)
	_panel_variation(t, ROW_HIGHLIGHTED, row_highlighted_box)
	# The HUD's Wave banner and any section-heading ribbon (task item 1:
	# "wave shown on a banner"). Yellow reads as a neutral/informational
	# banner colour, distinct from the Red/Blue ribbons this pack also ships
	# (kept available via UiPalette.TEX_RIBBON_BLUE/RED for a future caller
	# that wants a differently-coloured ribbon without a second theme
	# variation).
	_panel_variation(t, RIBBON, make_ribbon_box(UiPalette.TEX_RIBBON_YELLOW))


static func _panel_variation(t: Theme, variation: StringName, box: StyleBox) -> void:
	t.set_type_variation(variation, "PanelContainer")
	t.set_stylebox("panel", variation, box)


static func _build_buttons(t: Theme) -> void:
	var pad_h: int = UiPalette.SPACE_XL
	var pad_v: int = UiPalette.SPACE_M
	# Tiny Swords medieval restyle: carved wooden buttons (task item 2:
	# "Button_Blue/Red 9-slices for buttons with hover/pressed/disabled
	# variants"). The pack ships a matching sheet for every one of the four
	# states used here, so no per-state recolouring of a shared texture is
	# needed the way the old flat boxes needed one Color each.
	var normal := make_texture_box(UiPalette.TEX_BUTTON_NORMAL, UiPalette.PANEL_TEXTURE_MARGIN, 0, Color(1, 1, 1, 1))
	var hover := make_texture_box(UiPalette.TEX_BUTTON_HOVER, UiPalette.PANEL_TEXTURE_MARGIN, 0, Color(1, 1, 1, 1))
	var pressed := make_texture_box(UiPalette.TEX_BUTTON_PRESSED, UiPalette.PANEL_TEXTURE_MARGIN, 0, Color(1, 1, 1, 1))
	var disabled := make_texture_box(UiPalette.TEX_BUTTON_DISABLED, UiPalette.PANEL_TEXTURE_MARGIN, 0, Color(1, 1, 1, 1))
	for box: StyleBoxTexture in [normal, hover, pressed, disabled]:
		box.content_margin_left = pad_h
		box.content_margin_right = pad_h
		box.content_margin_top = pad_v
		box.content_margin_bottom = pad_v
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
	track.content_margin_top = UiPalette.SLIDER_PAD
	track.content_margin_bottom = UiPalette.SLIDER_PAD
	var fill := make_box(UiPalette.ACCENT, UiPalette.ACCENT, UiPalette.RADIUS_SMALL, 0, 0)
	fill.content_margin_top = UiPalette.SLIDER_PAD
	fill.content_margin_bottom = UiPalette.SLIDER_PAD
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
	for step: String in BOX_STEPS:
		t.set_type_variation(hbox(step), "HBoxContainer")
		t.set_constant("separation", hbox(step), BOX_STEPS[step])
		t.set_type_variation(vbox(step), "VBoxContainer")
		t.set_constant("separation", vbox(step), BOX_STEPS[step])
