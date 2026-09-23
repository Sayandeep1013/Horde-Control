extends PanelContainer
class_name DraftCardView

## Single Level-Up Draft card visual (P2.12). docs/19_UI_UX.md > "Upgrade
## Draft UI & Navigation" > "Readability": "Upgrade cards must display the
## icon, name, a one-sentence mechanical effect, and, for a rank the player
## already holds, the rank change (for example 'Rank 1 -> 2 of 3'). They
## must not require reading paragraphs of text." > "Differentiation":
## "Player cards and Tower cards are distinguished by frame shape (rounded
## for player, squared for Tower), a fixed glyph, and a header word, never
## by colour alone." MASTER_SDLC.md > Provisional Values Register >
## "Progression & Upgrades" > "Draft card display" row (cited, not
## restated): same wording.
##
## ## Name/icon derivation -- an interpretation, named in the P2.12 evidence
## report ("Interpretations")
## The Upgrade Definition Contract (src/data/upgrade_definition.gd) has no
## separate `name` or `icon` field -- only `unique_id` (a snake_case
## identifier) and `effect_description` (a full sentence, e.g. "Rapid Fire:
## +20% player fire rate per rank"). Every one of the eight authored
## data/upgrades/*.tres files puts the display name before a ':' and the
## mechanical effect after it, consistently, so this view splits on the
## first ':' to recover both without editing the Upgrade Definition Contract
## or any .tres file (both outside this task's write scope). No icon asset
## exists either (docs/25_Asset_Pipeline.md was not extended with per-upgrade
## icons by any earlier task); the "icon" the Readability rule asks for is
## satisfied by the fixed Player/Tower glyph below, which IS what
## Differentiation names as one of the three required non-colour signals --
## the same glyph therefore does double duty as "the icon" and as the
## differentiation glyph, rather than being invented as a fourth thing this
## task has no asset for. Recorded as an escalation candidate, not invented
## further.
##
## ## Rank-change line -- an interpretation for the no-max-rank fallback
## cards
## The Register's example ("Rank 1 -> 2 of 3") only covers a ranked
## (has_max_rank true) upgrade. Overdrive/Reinforce (C-FALLBACK-CONSOLE)
## have no max rank at all, so "of 3" does not apply; this view shows
## "Taken x<n> already" once `current_rank > 0` for a no-max-rank card
## instead, and nothing when it has never been taken -- an interpretation,
## not a literal Register phrase, named in the P2.12 evidence report.
##
## ## UI Pass (look only -- every rule/seam above and get_frame_style()'s
## return type are unchanged)
## The frame is still a per-instance `StyleBoxFlat` this view owns and
## mutates directly (never `theme_type_variation = UiTheme.CARD`, whose
## stylebox is ONE shared resource cached inside UiTheme's Theme -- mutating
## it here would restyle every other CARD-styled control project-wide), just
## built from `UiTheme.make_box()` and `UiPalette` tokens instead of local
## Color/StyleBoxFlat literals, per phases/UI_PASS/BRIEF.md. Added: a
## Player/Tower-tinted accent strip (a redundant colour cue, never the only
## one -- the frame shape, glyph, and header word above still are), and two
## purely cosmetic `create_tween()` animations (`_animate_highlight_lift()`,
## `play_entrance()`) using Control's `offset_transform_*` properties
## (Godot 4.7.1; verified against a live 4.7.1 build for this pass) rather
## than `scale`/`position`/`size` -- `offset_transform_*` is visual-only by
## the engine's own default (`offset_transform_visual_only` defaults
## `true`), so it never perturbs the `position`/`size`/`global_position`
## values tests/unit/draft_input_lockout_test.gd reads. See
## draft_controller.gd's own header for why a bare, node-bound
## `create_tween()` is permitted here at all.
##
## ## Round 2 (review fixes)
## UR-03: `_glyph_label` is now a `UiShapeGlyph` (`extends Label`), drawn as
## a vector triangle/square instead of the "▲"/"■" characters -- both
## confirmed absent from the shipped font (`Font.has_char()` false for
## U+25B2 and U+25A0 against the shipped font (`UiPalette.FONT_PATH`; false for Pixelify Sans and for Jersey 10),
## checked directly for this pass; see package report). It keeps its node
## name and its `text` (`get_glyph_label().text` is still exactly
## `GLYPH_PLAYER`/`GLYPH_TOWER` -- `tests/unit/draft_input_lockout_test.gd`
## reads that), and `get_glyph_label()` still returns `Label` (its declared
## static type), since `UiShapeGlyph` IS a `Label` (see shape_glyph.gd's own
## header for why it keeps the text at all -- it is invisible, painted fully
## transparent, and exists only as the test seam).
## Highlight cue: the review found the border-width gap between normal and
## highlighted (2px/3px, UiPalette.BORDER_THIN/THICK) plus the 1.05 lift
## "materially weaker than before" in a still frame. `_apply_highlight_style()`
## now also sets the stylebox's own `shadow_color`/`shadow_size` when
## highlighted (present vs. absent, a silhouette difference, not a colour
## swap) and the border width/lift both grew -- see the constants below.

## Register > "Draft card display": "frame shape ... rounded for player,
## squared for Tower". NO REGISTER ROW for the exact pixel radius -- a
## visual constant, not a gameplay number, chosen only to make "rounded" and
## "squared" unambiguous at this card's authored size. UI Pass: rounded now
## reads off UiPalette.RADIUS_PILL (no test asserts the old 18 px literal --
## only that it is greater than zero); squared stays a bare 0, which is not
## a magic spacing/colour number to promote, just the absence of rounding.
const CORNER_ROUNDED_PX: int = UiPalette.RADIUS_PILL
const CORNER_SQUARED_PX: int = 0

## Fixed glyph + header word (Register: "a fixed glyph, and a header word,
## never by colour alone"). Plain-text glyphs, not an image asset -- no
## per-upgrade or per-pool icon asset exists in this project yet (see class
## header); named as an escalation candidate rather than an invented sprite.
const GLYPH_PLAYER: String = "▲"
const GLYPH_TOWER: String = "■"
const HEADER_PLAYER: String = "PLAYER"
const HEADER_TOWER: String = "TOWER"

## UI Pass: BORDER_WIDTH_*/BORDER_COLOR_* now read off UiPalette instead of
## local literals -- no test asserts the old numeric values (grepped; see
## the report). The width GAP between normal and highlighted narrows from
## the old 3px/7px pair to UiPalette's own THIN/THICK pair (2px/3px); the
## cosmetic lift in _animate_highlight_lift() below is what keeps the
## highlighted state clearly distinct now that the border alone reads
## subtler (Colour-only-distinctions rule: shape AND colour AND motion all
## differ, not colour alone).
const BORDER_WIDTH_NORMAL: int = UiPalette.BORDER_THIN
## Round 2 (review): normal->highlighted stayed a 1px gap even with
## UiPalette.BORDER_THICK; the review called the still-frame cue "materially
## weaker than before." UiPalette has only a THIN/THICK pair, no third
## "emphatic selection" tier, so this is a local const, not
## UiPalette.BORDER_THICK. TODO(ui-pass): promote to UiPalette if another
## surface wants a border weight beyond THICK for a selection/focus cue.
const BORDER_WIDTH_HIGHLIGHTED: int = 5
## HUD polish (coordinator review, third pass): a dark wood-brown frame
## (task instruction, "a flat parchment StyleBoxFlat with a wood border"),
## not the bronze LINE_STRONG every HUD pill uses -- higher contrast against
## the card's own light UiPalette.PARCHMENT fill (below) than bronze-on-tan
## would be.
const BORDER_COLOR_NORMAL: Color = UiPalette.WOOD_BORDER
const BORDER_COLOR_HIGHLIGHTED: Color = UiPalette.ACCENT

## D117 (card rarity). Register > "Draft rarity": "the draft card UI shows
## rarity with colour (Common parchment/grey, Rare blue, Epic purple/gold)".
## A per-rarity border tint REPLACES BORDER_COLOR_NORMAL while the card is
## NOT highlighted (_apply_highlight_style() below); the highlighted state
## keeps its own distinct BORDER_COLOR_HIGHLIGHTED/width/shadow untouched.
## Plain Color literals, not UiPalette tokens: no existing token names
## "grey"/"blue"/"purple-gold", and a rarity tint is this file's own
## single-widget concept, matching this class's own established pattern for
## constants nothing else needs (see class header, CORNER_ROUNDED_PX etc.).
const RARITY_BORDER_TINT_COMMON: Color = Color(0.62, 0.60, 0.56) # parchment/grey
const RARITY_BORDER_TINT_RARE: Color = Color(0.30, 0.55, 0.95) # blue
const RARITY_BORDER_TINT_EPIC: Color = Color(0.70, 0.35, 0.90) # purple/gold
const RARITY_LABEL_TEXT: Dictionary = {
	ContractEnums.Rarity.Common: "COMMON",
	ContractEnums.Rarity.Rare: "RARE",
	ContractEnums.Rarity.Epic: "EPIC",
}

## Round 2 (review): a shadow, present only while highlighted, is a
## silhouette difference (visible with colour desaturated, unlike a colour
## swap alone) layered on top of the border-width/lift cues, not a
## replacement for either. UiPalette has a colour and a spacing scale but no
## "shadow blur/offset" scale. TODO(ui-pass): promote to UiPalette if
## another surface wants the same elevation cue.
const HIGHLIGHT_SHADOW_SIZE_PX: int = 10
const HIGHLIGHT_SHADOW_OFFSET_PX: float = 3.0
## Not `UiPalette.with_alpha(UiPalette.ACCENT, ...)` directly -- a `const`
## initializer must be a constant expression, and `with_alpha()` is a
## function call; the colour is built from these two constants where used.
const HIGHLIGHT_SHADOW_ALPHA: float = 0.55

## No UiPalette token covers a card's inner content width or a highlight
## lift's scale factor -- the first is a single-widget minimum size, the
## second a motion-curve constant, neither a reusable spacing/colour/font
## concept. TODO(ui-pass): promote to UiPalette if another surface needs the
## same content width or the same lift feel.
const CONTENT_MIN_WIDTH: float = 300.0
## Round 2 (review): 1.05 read as too subtle in a still frame; raised
## alongside the border-width/shadow changes above, same reasoning.
const HIGHLIGHT_LIFT_SCALE: float = 1.09

## Second UI pass (Tiny Swords restyle): a small custom-drawn Control
## showing rank progress as filled/empty pips (task instruction: "rank
## pips"), alongside -- never instead of -- the existing `_rank_label` text
## ("Rank 1 -> 2 of 3"): docs/19's Readability rule is satisfied by the
## text alone already; the pips are a purely additive visual reinforcement.
## A no-max-rank fallback card (Overdrive/Reinforce) has nothing to show
## pips FOR, so it hides them (see setup()) rather than drawing zero pips.
class RankPips extends Control:
	var max_rank: int = 0
	var filled: int = 0
	var fill_color: Color = UiPalette.ACCENT
	## HUD polish (third pass): darkened to UiPalette.WOOD_BORDER, matching
	## the card's own new wood-border frame colour -- LINE_STRONG (bronze)
	## at 0.5 alpha read too close to the new light UiPalette.PARCHMENT fill
	## behind it to register as an "empty" pip.
	var empty_color: Color = UiPalette.with_alpha(UiPalette.WOOD_BORDER, 0.45)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func configure(new_max_rank: int, new_filled: int) -> void:
		max_rank = new_max_rank
		filled = new_filled
		queue_redraw()

	func _draw() -> void:
		if max_rank <= 0 or size.y <= 0.0:
			return
		var pip_radius: float = size.y * 0.5
		var gap: float = UiPalette.SPACE_S
		for i in range(max_rank):
			var cx: float = pip_radius + float(i) * (pip_radius * 2.0 + gap)
			var color: Color = fill_color if i < filled else empty_color
			draw_circle(Vector2(cx, pip_radius), pip_radius, color)


var _column: VBoxContainer
var _accent_strip: ColorRect
var _header_label: Label
## Declared `Label` (get_glyph_label()'s own return type, unchanged --
## tests/unit/draft_input_lockout_test.gd's seam) though the instance built
## in _init() is a UiShapeGlyph, which extends Label (Round 2, UR-03).
var _glyph_label: Label
var _name_label: Label
var _effect_label: Label
var _rank_label: Label
## Second UI pass: rank pips alongside _rank_label (see RankPips above).
var _rank_pips: RankPips
var _style: StyleBoxFlat

var _pool_ownership: int = ContractEnums.PoolOwnership.Player
var _upgrade_id: String = ""
var _highlighted: bool = false
var _lift_tween: Tween = null # killed before a new one starts -- see _animate_highlight_lift()

## D117 (card rarity).
var _rarity: int = ContractEnums.Rarity.Common
var _rarity_label: Label


func _init() -> void:
	# Built in _init(), not _ready(): DraftController constructs this node
	# with `.new()` and calls setup() before it necessarily has a parent
	# with a running tree; _ready() would not have fired yet at that point.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# UI Pass motion (see class header): `offset_transform_*` is visual-only
	# and needs `offset_transform_enabled` on before either animation below
	# has any effect; the pivot is centred once, here, since both the
	# highlight lift and the entrance rise want the same pivot.
	offset_transform_enabled = true
	offset_transform_pivot_ratio = Vector2(0.5, 0.5)

	# UiTheme.CARD's own look, built as a PER-INSTANCE StyleBoxFlat via
	# UiTheme.make_box() (never `theme_type_variation = UiTheme.CARD` --
	# see class header) so setup()/_apply_highlight_style() can keep
	# mutating corner radius, border width, and border colour at runtime.
	#
	# HUD polish (coordinator review, third pass): a flat UiPalette.PARCHMENT
	# fill (opaque -- a "calm surface" for the text, task instruction) with a
	# UiPalette.WOOD_BORDER frame, not a tiled texture swatch. The earlier
	# version of this pass added a SECOND child, a TextureRect tiling
	# Carved_Regular.png (64x64) behind `_column` for a parchment TEXTURE;
	# a real capture showed it as a visible "waffle grid" of repeat seams
	# at the card's size, not a seamless parchment surface -- a flat fill
	# has no seam to show, by construction, so it replaces the texture
	# entirely rather than trying to hide the seam.
	_style = UiTheme.make_box(UiPalette.PARCHMENT, BORDER_COLOR_NORMAL, CORNER_SQUARED_PX, BORDER_WIDTH_NORMAL, UiPalette.SPACE_L)
	add_theme_stylebox_override("panel", _style)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.theme_type_variation = UiTheme.vbox("M") # Round 2, UR-06
	add_child(_column)

	# Redundant colour cue (MASTER_SDLC.md > Visual Edge Cases >
	# "Colour-only distinctions"): a Player/Tower-tinted band ABOVE the
	# shape/glyph/word signals that remain the actual differentiation, never
	# the only one. Coloured per-card in setup().
	_accent_strip = ColorRect.new()
	_accent_strip.name = "AccentStrip"
	_accent_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_accent_strip.custom_minimum_size = Vector2(0.0, UiPalette.SPACE_XS)
	_column.add_child(_accent_strip)

	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Round 2, UR-06: SPACE_S is the theme's own HBoxContainer default
	# (ui_theme.gd's _build_containers()) -- no override needed at all.
	_column.add_child(header_row)

	# Round 2, UR-03: a UiShapeGlyph (extends Label), not a "▲"/"■" character
	# -- see class header. Still named "Glyph"; setup() still sets its
	# `.text` to GLYPH_PLAYER/GLYPH_TOWER (the test seam), and now also its
	# `.shape`/`.glyph_color`. Sized with set_side() from a UiPalette
	# font-size token in place of the old font-size override, so it tracks
	# the text beside it the same way it did as a Label.
	_glyph_label = UiShapeGlyph.new()
	_glyph_label.name = "Glyph"
	(_glyph_label as UiShapeGlyph).set_side(UiPalette.FONT_SIZE_HEADING)
	header_row.add_child(_glyph_label)

	# Clear hierarchy (task brief): header word small and dim.
	_header_label = Label.new()
	_header_label.name = "Header"
	_header_label.theme_type_variation = UiTheme.SMALL
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_header_label)

	# D117 (card rarity): a small badge at the header row's far right
	# (SIZE_EXPAND_FILL on _header_label above pushes this to the end),
	# coloured per rarity in setup() -- the colour is a REDUNDANT cue
	# alongside the text itself ("COMMON"/"RARE"/"EPIC"), never the only
	# signal, matching this project's own Colour-only-distinctions rule.
	_rarity_label = Label.new()
	_rarity_label.name = "Rarity"
	_rarity_label.theme_type_variation = UiTheme.SMALL
	_rarity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rarity_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	header_row.add_child(_rarity_label)

	# Clear hierarchy: name in VALUE weight (display font, larger than body).
	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.theme_type_variation = UiTheme.VALUE
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.custom_minimum_size = Vector2(CONTENT_MIN_WIDTH, 0)
	_column.add_child(_name_label)

	# Clear hierarchy: one-sentence effect in body -- the root Theme's own
	# default Label styling (UiPalette.FONT_SIZE_BODY / UiPalette.TEXT),
	# inherited from _root, needs no override here.
	# Round 2 (review): this label used to be the VBoxContainer's only
	# SIZE_EXPAND_FILL-vertical child, so it alone absorbed every pixel of
	# slack between the card's fixed CARD_MIN_SIZE height
	# (draft_controller.gd) and the column's natural content height -- read
	# in a still frame as ~200px of dead space between the one-sentence
	# effect and the "Rank n of 3" line below it. No child now claims
	# vertical expansion, so the VBoxContainer's default top alignment packs
	# every label tight against its neighbour and leaves any leftover slack
	# at the BOTTOM of the card as a plain margin, never mid-content.
	_effect_label = Label.new()
	_effect_label.name = "Effect"
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_effect_label.custom_minimum_size = Vector2(CONTENT_MIN_WIDTH, 0)
	_column.add_child(_effect_label)

	# Clear hierarchy: rank change line dim.
	_rank_label = Label.new()
	_rank_label.name = "Rank"
	_rank_label.theme_type_variation = UiTheme.DIM
	_rank_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rank_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rank_label.custom_minimum_size = Vector2(CONTENT_MIN_WIDTH, 0)
	_column.add_child(_rank_label)

	# Second UI pass: rank pips, right below the text line they reinforce.
	_rank_pips = RankPips.new()
	_rank_pips.name = "RankPips"
	_rank_pips.custom_minimum_size = Vector2(CONTENT_MIN_WIDTH, 14.0)
	_column.add_child(_rank_pips)


## Typed command. Populates every Readability field and the Differentiation
## signals (frame corner radius, glyph, header word) for `def`, an upgrade
## currently at shared rank `current_rank` (0 if never taken). `rarity`
## (D117) is the card's own ROLLED rarity for THIS draft -- never read off
## `def.rarity` (a shared Resource's own unrolled default) -- defaulted to
## Common so every pre-D117 caller (none left in this codebase, but any
## future direct test construction) keeps working unchanged.
func setup(def: UpgradeDefinition, current_rank: int, rarity: int = ContractEnums.Rarity.Common) -> void:
	_pool_ownership = def.pool_ownership
	_upgrade_id = def.unique_id
	_rarity = rarity
	var is_player: bool = def.pool_ownership == ContractEnums.PoolOwnership.Player
	var radius: int = CORNER_ROUNDED_PX if is_player else CORNER_SQUARED_PX
	_style.set_corner_radius_all(radius)
	# get_glyph_label().text stays exactly GLYPH_PLAYER/GLYPH_TOWER (the test
	# seam); shape and glyph_color are the new UiShapeGlyph-only properties
	# (Round 2, UR-03) and touch nothing a test reads.
	_glyph_label.text = GLYPH_PLAYER if is_player else GLYPH_TOWER
	var shape_glyph: UiShapeGlyph = _glyph_label as UiShapeGlyph
	shape_glyph.shape = UiShapeGlyph.Shape.TRIANGLE if is_player else UiShapeGlyph.Shape.SQUARE
	shape_glyph.glyph_color = UiPalette.PLAYER if is_player else UiPalette.TOWER
	_header_label.text = HEADER_PLAYER if is_player else HEADER_TOWER
	_accent_strip.color = UiPalette.PLAYER if is_player else UiPalette.TOWER
	_rarity_label.text = String(RARITY_LABEL_TEXT.get(_rarity, "COMMON"))
	_rarity_label.add_theme_color_override("font_color", _rarity_border_tint())

	var parts: PackedStringArray = def.effect_description.split(":", true, 1)
	var card_name: String = def.unique_id
	var effect_text: String = def.effect_description
	if parts.size() >= 2:
		card_name = parts[0].strip_edges()
		effect_text = parts[1].strip_edges()
	_name_label.text = card_name
	_effect_label.text = effect_text

	_rank_label.text = _rank_change_text(def, current_rank)
	# Second UI pass: pips only make sense for a ranked upgrade -- a no-max-
	# rank fallback card (C-FALLBACK-CONSOLE) has no "of N" to show progress
	# against, so the row is hidden rather than drawn with zero pips.
	_rank_pips.visible = def.has_max_rank
	if def.has_max_rank:
		_rank_pips.configure(def.max_rank, current_rank)
	_apply_highlight_style()


func _rank_change_text(def: UpgradeDefinition, current_rank: int) -> String:
	if def.has_max_rank:
		if current_rank <= 0:
			return "Rank 1 of %d" % def.max_rank
		return "Rank %d -> %d of %d" % [current_rank, current_rank + 1, def.max_rank]
	# No-max-rank fallback card (C-FALLBACK-CONSOLE) -- see class header.
	if current_rank <= 0:
		return ""
	return "Taken x%d already" % current_rank


## Highlight state differs by SHAPE as well as colour (Colour-only
## distinctions rule): border width/colour change synchronously below, so
## every test reading them sees the correct value the instant this returns;
## the lift in _animate_highlight_lift() is a separate, purely cosmetic
## effect layered on top, never a substitute for the synchronous change.
func set_highlighted(value: bool) -> void:
	_highlighted = value
	_apply_highlight_style()
	_animate_highlight_lift()


## D117: the NORMAL (non-highlighted) border colour is the card's own
## rarity tint rather than the fixed BORDER_COLOR_NORMAL wood -- the
## highlighted state keeps its own distinct ACCENT colour/width/shadow
## (already a strong, rarity-independent selection cue), and the rarity
## LABEL beside the header word (setup()) stays visible and correctly
## coloured either way, so rarity is never lost while a card is selected.
func _apply_highlight_style() -> void:
	if _style == null:
		return
	var width: int = BORDER_WIDTH_HIGHLIGHTED if _highlighted else BORDER_WIDTH_NORMAL
	var color: Color = BORDER_COLOR_HIGHLIGHTED if _highlighted else _rarity_border_tint()
	_style.set_border_width_all(width)
	_style.border_color = color
	# Round 2 (review): a shadow, present only while highlighted, so the
	# highlighted card reads as a distinct silhouette (not only a colour
	# change) even in a still frame with colour desaturated -- see class
	# header and the HIGHLIGHT_SHADOW_* constants above.
	_style.shadow_size = HIGHLIGHT_SHADOW_SIZE_PX if _highlighted else 0
	_style.shadow_color = UiPalette.with_alpha(UiPalette.ACCENT, HIGHLIGHT_SHADOW_ALPHA)
	_style.shadow_offset = Vector2(0.0, HIGHLIGHT_SHADOW_OFFSET_PX) if _highlighted else Vector2.ZERO


## Cosmetic only (see class header): a bare, node-bound `create_tween()`
## animating the visual-only `offset_transform_scale` around the centred
## pivot set in _init() -- never `scale` itself (a real CanvasItem transform
## that WOULD perturb `global_position`/`size`) and never `position`/`size`
## (this card sits in a container -- docs/19 > "UI Layout"). `_highlighted`
## and the frame style above are already correct by the time this is called
## (set_highlighted() calls _apply_highlight_style() first); this never
## gates or delays anything a test or the input rules read.
func _animate_highlight_lift() -> void:
	if not is_inside_tree():
		return
	# Highlight can toggle faster than a lift finishes (the 0.3 s cycle
	# repeat cycling past this card and back) -- kill any still-running lift
	# tween first so two tweens never fight over the same property.
	if _lift_tween != null and _lift_tween.is_valid():
		_lift_tween.kill()
	var target: Vector2 = Vector2(HIGHLIGHT_LIFT_SCALE, HIGHLIGHT_LIFT_SCALE) if _highlighted else Vector2.ONE
	var duration: float = UiPalette.MOTION_FAST if _highlighted else UiPalette.MOTION_BASE
	var tween: Tween = create_tween()
	_lift_tween = tween
	# This card is only ever parented under DraftController, a
	# PROCESS_MODE_ALWAYS CanvasLayer (draft_controller.gd's own header) --
	# so it already inherits PROCESS_MODE_ALWAYS and this tween would keep
	# running under the Draft's own pause regardless. Set explicitly anyway,
	# per this task's own instruction, rather than relying on inherited
	# process_mode: MASTER_SDLC.md's own reasoning for why a bound tween
	# pauses correctly ("a tween bound to a paused node pauses with it")
	# is about the DEFAULT (TWEEN_PAUSE_BOUND); TWEEN_PAUSE_PROCESS makes
	# the intent explicit and keeps this correct even if this view were
	# ever reparented under something that is not PROCESS_MODE_ALWAYS.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "offset_transform_scale", target, duration)


## Card-row entrance (phases/UI_PASS/PLAN.md direction): a short staggered
## fade/rise the first time this card's content is built, driven by
## DraftController's `i * UiPalette.MOTION_FAST` stagger. Purely cosmetic --
## touches only `modulate`/`offset_transform_position`, never
## `_highlighted`, the frame style, or any `_for_test` state, so a card is
## fully interactable (hover, click, keyboard/gamepad select) at any point
## during or before this plays; the Draft's own 0.4 s lockout and
## hold-to-confirm arming are entirely unaffected (they read real input
## timers, never this animation's progress).
func play_entrance(delay: float = 0.0) -> void:
	if not is_inside_tree():
		return
	modulate.a = 0.0
	offset_transform_position = Vector2(0.0, UiPalette.SPACE_L)
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # see _animate_highlight_lift()'s own note
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, UiPalette.MOTION_BASE).set_delay(delay)
	tween.tween_property(self, "offset_transform_position", Vector2.ZERO, UiPalette.MOTION_BASE).set_delay(delay)


func is_highlighted() -> bool:
	return _highlighted


func get_upgrade_id() -> String:
	return _upgrade_id


func get_pool_ownership() -> int:
	return _pool_ownership


func get_header_label() -> Label:
	return _header_label


func get_glyph_label() -> Label:
	return _glyph_label


func get_name_label() -> Label:
	return _name_label


func get_effect_label() -> Label:
	return _effect_label


func get_rank_label() -> Label:
	return _rank_label


func get_frame_style() -> StyleBoxFlat:
	return _style


func _rarity_border_tint() -> Color:
	match _rarity:
		ContractEnums.Rarity.Rare:
			return RARITY_BORDER_TINT_RARE
		ContractEnums.Rarity.Epic:
			return RARITY_BORDER_TINT_EPIC
		_:
			return RARITY_BORDER_TINT_COMMON


func get_rarity_for_test() -> int:
	return _rarity


func get_rarity_label_for_test() -> Label:
	return _rarity_label
