extends PanelContainer
class_name SkillNodeView

## One Skill Tree grid node (Hub/Skill Tree screen; docs/18_Permanent_Skill_Tree.md
## section 4.1/4.2). A pure display widget -- ALL state (silhouette / owned /
## buyable / locked / unaffordable / MAX) is computed by SkillTreeScreen from
## MetaProgress and pushed in via `set_state()`/`set_silhouette()`; this file
## holds no MetaProgress reference of its own, matching DraftCardView's own
## "pure display" convention (src/ui/draft_card_view.gd's header) and
## Console's own per-row `StyleBoxFlat` mutation (src/ui/console.gd's header,
## "UI pass follow-up (compaction): one owned StyleBoxFlat per row").
##
## ## Runtime StyleBoxFlat, not a UiTheme variation
## A node's fill/border colour changes per state and per branch -- a shared
## Theme variation cannot express that (the same seam UiTheme's own header
## names for `draft_card_view.gd`'s card frame and `console.gd`'s per-row
## panel: "a real corner-radius/colour toggle a texture cannot express").
## `UiTheme.make_box()` builds the box; this file only mutates its fields.
##
## ## Selection is a sibling concern
## This node emits `node_hovered(id)` on mouse hover (hover selects, matching
## the Draft/Console/PausedChoiceBar convention) but does NOT track selection
## itself -- `SkillTreeScreen` owns `_selected_id` and calls `set_selected()`
## here purely for the caret's own positioning query
## (`get_node_view_rect_for_test()`); the actual "is this the highlighted
## node" visual is a single shared caret sibling
## (`SkillTreeScreen._selection_caret`), matching `ChoiceHighlightRow`'s own
## "a sibling indicator tracking the highlighted control's rect" technique
## rather than a per-node highlight flag.
##
## ## Never a mouse-hold target of its own
## Buying is driven by `SkillTreeScreen._process()` polling the shared
## `confirm` action (Space/Enter/left mouse/gamepad A -- project.godot's own
## `confirm` action already binds all four) while THIS node is the selected
## one, exactly mirroring `PausedChoiceBar._poll_hold_up_input()`'s pattern
## with `confirm` in place of `move_up` (all four directions are needed for
## 2D grid navigation here, unlike the Draft's 1D card row, which leaves
## `move_up` free). This node therefore needs no `gui_input` press-tracking
## of its own for the hold; only `mouse_entered` (selection) is wired.

enum State { SILHOUETTE, LOCKED, UNAFFORDABLE, BUYABLE, MAX, OWNED_MAX }

signal node_hovered(id: String)

const NODE_SIZE: float = 108.0
const RADIUS: float = 18.0
const ICON_SIDE: int = 30

var node_id: String = ""

var _icon: UiShapeGlyph
var _rank_label: Label
var _price_label: Label
var _style: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE # keyboard nav is driven by SkillTreeScreen's own cursor, not Godot focus traversal
	mouse_entered.connect(func() -> void: node_hovered.emit(node_id))
	_style = UiTheme.make_box(UiPalette.SURFACE, UiPalette.LINE, RADIUS, UiPalette.BORDER_THIN, 0)
	add_theme_stylebox_override("panel", _style)
	_build_children()


func _build_children() -> void:
	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.theme_type_variation = UiTheme.vbox("XS")
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	_icon = UiShapeGlyph.new()
	_icon.name = "Icon"
	_icon.set_side(ICON_SIDE)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_icon)

	_rank_label = Label.new()
	_rank_label.name = "RankLabel"
	_rank_label.theme_type_variation = UiTheme.SMALL
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_rank_label)

	_price_label = Label.new()
	_price_label.name = "PriceLabel"
	_price_label.theme_type_variation = UiTheme.SMALL
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_price_label)


## `def` may be null for the synthetic "Reset Tree" pseudo-node (see
## SkillTreeScreen's own header) -- `shape`/`branch_color` are supplied
## directly by the caller in that case instead of being derived from a
## SkillNodeDefinition.
func configure(id: String, shape: int, branch_color: Color) -> void:
	node_id = id
	_icon.shape = shape
	_icon.glyph_color = branch_color


func set_silhouette() -> void:
	_icon.visible = false
	_rank_label.visible = true
	_rank_label.theme_type_variation = UiTheme.VALUE
	_rank_label.text = tr("SKILL_TREE_SILHOUETTE_NAME")
	_price_label.visible = false
	_style.bg_color = UiPalette.INK
	_style.border_color = UiPalette.LINE
	_style.set_border_width_all(UiPalette.BORDER_THIN)
	modulate = Color(1, 1, 1, 1)


## `is_root`: the Command Tent -- always owned, free, no price/rank text of
## its own. `branch_color` tints the icon/fill when owned; `price` is only
## read for LOCKED/UNAFFORDABLE/BUYABLE.
func set_state(state: int, rank: int, max_rank: int, price: int, branch_color: Color, is_root: bool) -> void:
	_icon.visible = true
	_rank_label.theme_type_variation = UiTheme.SMALL
	var owned: bool = rank > 0
	_icon.glyph_color = branch_color if (owned or is_root) else UiPalette.TEXT_DIM

	if is_root:
		_rank_label.visible = false
		_price_label.visible = false
		_style.bg_color = UiPalette.with_alpha(branch_color, 0.4)
		_style.border_color = UiPalette.LINE_STRONG
		_style.set_border_width_all(UiPalette.BORDER_THICK)
		return

	_rank_label.visible = max_rank > 0
	if max_rank > 0:
		_rank_label.text = "%d/%d" % [rank, max_rank]

	_price_label.visible = true
	_price_label.remove_theme_color_override("font_color")
	match state:
		State.LOCKED:
			_price_label.text = str(price)
			_price_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
			_style.bg_color = UiPalette.SURFACE
			_style.border_color = UiPalette.LINE
			_style.set_border_width_all(UiPalette.BORDER_THIN)
		State.UNAFFORDABLE:
			_price_label.text = str(price)
			_price_label.add_theme_color_override("font_color", UiPalette.DANGER)
			_style.bg_color = UiPalette.with_alpha(branch_color, 0.18) if owned else UiPalette.SURFACE
			_style.border_color = UiPalette.DANGER
			_style.set_border_width_all(UiPalette.BORDER_THIN)
		State.BUYABLE:
			_price_label.text = str(price)
			_price_label.add_theme_color_override("font_color", UiPalette.SUCCESS)
			_style.bg_color = UiPalette.with_alpha(branch_color, 0.18) if owned else UiPalette.SURFACE
			_style.border_color = UiPalette.ACCENT
			_style.set_border_width_all(UiPalette.BORDER_THICK)
		State.MAX, State.OWNED_MAX:
			_price_label.text = tr("SKILL_TREE_MAX")
			_price_label.add_theme_color_override("font_color", UiPalette.ACCENT)
			_style.bg_color = UiPalette.with_alpha(branch_color, 0.45)
			_style.border_color = UiPalette.ACCENT
			_style.set_border_width_all(UiPalette.BORDER_THICK)


## Cosmetic feedback for an unaffordable hold attempt (docs/18 section 4.5:
## "the hold does nothing except a short shake"). A bare `create_tween()` on
## this node -- pure UI, permitted for cosmetic animation regardless of
## pause state (MASTER_SDLC.md; tools/checks/banned_api_check.sh exempts
## every `.../ui/...` path outright).
func play_shake() -> void:
	var tween: Tween = create_tween()
	var base_x: float = position.x
	tween.tween_property(self, "position:x", base_x + 6.0, 0.04)
	tween.tween_property(self, "position:x", base_x - 6.0, 0.08)
	tween.tween_property(self, "position:x", base_x + 4.0, 0.08)
	tween.tween_property(self, "position:x", base_x, 0.06)


func play_reveal_fade() -> void:
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, UiPalette.MOTION_SLOW)


func play_purchase_pulse() -> void:
	pivot_offset = size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14)


# --- Test seams (project convention: get_*_for_test()) ----------------------

func get_rank_label_for_test() -> Label:
	return _rank_label


func get_price_label_for_test() -> Label:
	return _price_label


func get_icon_for_test() -> UiShapeGlyph:
	return _icon
