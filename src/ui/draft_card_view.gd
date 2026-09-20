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

## Register > "Draft card display": "frame shape ... rounded for player,
## squared for Tower". NO REGISTER ROW for the exact pixel radius -- a
## visual constant, not a gameplay number, chosen only to make "rounded" and
## "squared" unambiguous at this card's authored size.
const CORNER_ROUNDED_PX: int = 18
const CORNER_SQUARED_PX: int = 0

## Fixed glyph + header word (Register: "a fixed glyph, and a header word,
## never by colour alone"). Plain-text glyphs, not an image asset -- no
## per-upgrade or per-pool icon asset exists in this project yet (see class
## header); named as an escalation candidate rather than an invented sprite.
const GLYPH_PLAYER: String = "▲"
const GLYPH_TOWER: String = "■"
const HEADER_PLAYER: String = "PLAYER"
const HEADER_TOWER: String = "TOWER"

const BORDER_WIDTH_NORMAL: int = 3
const BORDER_WIDTH_HIGHLIGHTED: int = 7
const BORDER_COLOR_NORMAL: Color = Color(0.55, 0.55, 0.6)
const BORDER_COLOR_HIGHLIGHTED: Color = Color(1.0, 0.85, 0.2)

var _column: VBoxContainer
var _header_label: Label
var _glyph_label: Label
var _name_label: Label
var _effect_label: Label
var _rank_label: Label
var _style: StyleBoxFlat

var _pool_ownership: int = ContractEnums.PoolOwnership.Player
var _upgrade_id: String = ""
var _highlighted: bool = false


func _init() -> void:
	# Built in _init(), not _ready(): DraftController constructs this node
	# with `.new()` and calls setup() before it necessarily has a parent
	# with a running tree; _ready() would not have fired yet at that point.
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.12, 0.12, 0.17, 0.95)
	_style.border_width_left = BORDER_WIDTH_NORMAL
	_style.border_width_top = BORDER_WIDTH_NORMAL
	_style.border_width_right = BORDER_WIDTH_NORMAL
	_style.border_width_bottom = BORDER_WIDTH_NORMAL
	_style.border_color = BORDER_COLOR_NORMAL
	add_theme_stylebox_override("panel", _style)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 10)
	add_child(_column)

	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", 10)
	_column.add_child(header_row)

	_glyph_label = Label.new()
	_glyph_label.name = "Glyph"
	_glyph_label.add_theme_font_size_override("font_size", 28)
	header_row.add_child(_glyph_label)

	_header_label = Label.new()
	_header_label.name = "Header"
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_header_label)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.custom_minimum_size = Vector2(300, 0)
	_name_label.add_theme_font_size_override("font_size", 20)
	_column.add_child(_name_label)

	_effect_label = Label.new()
	_effect_label.name = "Effect"
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_effect_label.custom_minimum_size = Vector2(300, 0)
	_column.add_child(_effect_label)

	_rank_label = Label.new()
	_rank_label.name = "Rank"
	_rank_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rank_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rank_label.custom_minimum_size = Vector2(300, 0)
	_column.add_child(_rank_label)


## Typed command. Populates every Readability field and the Differentiation
## signals (frame corner radius, glyph, header word) for `def`, an upgrade
## currently at shared rank `current_rank` (0 if never taken).
func setup(def: UpgradeDefinition, current_rank: int) -> void:
	_pool_ownership = def.pool_ownership
	_upgrade_id = def.unique_id
	var is_player: bool = def.pool_ownership == ContractEnums.PoolOwnership.Player
	var radius: int = CORNER_ROUNDED_PX if is_player else CORNER_SQUARED_PX
	_style.corner_radius_top_left = radius
	_style.corner_radius_top_right = radius
	_style.corner_radius_bottom_left = radius
	_style.corner_radius_bottom_right = radius
	_glyph_label.text = GLYPH_PLAYER if is_player else GLYPH_TOWER
	_header_label.text = HEADER_PLAYER if is_player else HEADER_TOWER

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


func set_highlighted(value: bool) -> void:
	_highlighted = value
	_apply_highlight_style()


func _apply_highlight_style() -> void:
	if _style == null:
		return
	var width: int = BORDER_WIDTH_HIGHLIGHTED if _highlighted else BORDER_WIDTH_NORMAL
	var color: Color = BORDER_COLOR_HIGHLIGHTED if _highlighted else BORDER_COLOR_NORMAL
	_style.border_width_left = width
	_style.border_width_top = width
	_style.border_width_right = width
	_style.border_width_bottom = width
	_style.border_color = color


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
