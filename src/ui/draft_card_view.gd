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
const BORDER_WIDTH_HIGHLIGHTED: int = UiPalette.BORDER_THICK
const BORDER_COLOR_NORMAL: Color = UiPalette.LINE_STRONG
const BORDER_COLOR_HIGHLIGHTED: Color = UiPalette.ACCENT

## No UiPalette token covers a card's inner content width or a highlight
## lift's scale factor -- the first is a single-widget minimum size, the
## second a motion-curve constant, neither a reusable spacing/colour/font
## concept. TODO(ui-pass): promote to UiPalette if another surface needs the
## same content width or the same lift feel.
const CONTENT_MIN_WIDTH: float = 300.0
const HIGHLIGHT_LIFT_SCALE: float = 1.05

var _column: VBoxContainer
var _accent_strip: ColorRect
var _header_label: Label
var _glyph_label: Label
var _name_label: Label
var _effect_label: Label
var _rank_label: Label
var _style: StyleBoxFlat

var _pool_ownership: int = ContractEnums.PoolOwnership.Player
var _upgrade_id: String = ""
var _highlighted: bool = false
var _lift_tween: Tween = null # killed before a new one starts -- see _animate_highlight_lift()


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
	_style = UiTheme.make_box(UiPalette.with_alpha(UiPalette.SURFACE, UiPalette.CARD_ALPHA), BORDER_COLOR_NORMAL, CORNER_SQUARED_PX, BORDER_WIDTH_NORMAL, UiPalette.SPACE_L)
	add_theme_stylebox_override("panel", _style)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", UiPalette.SPACE_M)
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
	header_row.add_theme_constant_override("separation", UiPalette.SPACE_S)
	_column.add_child(header_row)

	_glyph_label = Label.new()
	_glyph_label.name = "Glyph"
	_glyph_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_HEADING)
	header_row.add_child(_glyph_label)

	# Clear hierarchy (task brief): header word small and dim.
	_header_label = Label.new()
	_header_label.name = "Header"
	_header_label.theme_type_variation = UiTheme.SMALL
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_header_label)

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
	_effect_label = Label.new()
	_effect_label.name = "Effect"
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
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


## Typed command. Populates every Readability field and the Differentiation
## signals (frame corner radius, glyph, header word) for `def`, an upgrade
## currently at shared rank `current_rank` (0 if never taken).
func setup(def: UpgradeDefinition, current_rank: int) -> void:
	_pool_ownership = def.pool_ownership
	_upgrade_id = def.unique_id
	var is_player: bool = def.pool_ownership == ContractEnums.PoolOwnership.Player
	var radius: int = CORNER_ROUNDED_PX if is_player else CORNER_SQUARED_PX
	_style.set_corner_radius_all(radius)
	_glyph_label.text = GLYPH_PLAYER if is_player else GLYPH_TOWER
	_header_label.text = HEADER_PLAYER if is_player else HEADER_TOWER
	_accent_strip.color = UiPalette.PLAYER if is_player else UiPalette.TOWER

	var parts: PackedStringArray = def.effect_description.split(":", true, 1)
	var card_name: String = def.unique_id
	var effect_text: String = def.effect_description
	if parts.size() >= 2:
		card_name = parts[0].strip_edges()
		effect_text = parts[1].strip_edges()
	_name_label.text = card_name
	_effect_label.text = effect_text

	_rank_label.text = _rank_change_text(def, current_rank)
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


func _apply_highlight_style() -> void:
	if _style == null:
		return
	var width: int = BORDER_WIDTH_HIGHLIGHTED if _highlighted else BORDER_WIDTH_NORMAL
	var color: Color = BORDER_COLOR_HIGHLIGHTED if _highlighted else BORDER_COLOR_NORMAL
	_style.set_border_width_all(width)
	_style.border_color = color


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
