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
## ## Polish pass (coordinator review of skill_tree_1920b_150.png)
## A revealed node now shows its NAME (2 lines, autowrap -- every authored
## `display_name` in data/meta/skill_tree.tres is short enough to wrap into
## two lines at this widget's own width; none needs ellipsis truncation),
## rank as PIPS (one small filled/dim dot per rank, `UiShapeGlyph.Shape.COIN`
## at `PIP_SIZE`, filled = owned, dim = not yet) instead of "n/max" text, and
## the price as a small crystal icon (`UiPalette.CORES`) + number instead of
## a bare number. `NODE_SIZE` grew 84 -> 112 (1.33x, the requested 1.3-1.6x)
## to fit the extra rows of content legibly.
##
## ## Runtime StyleBoxTexture, not a UiTheme variation
## A node's frame changes per state and per branch -- a shared Theme
## variation cannot express that (the same seam UiTheme's own header names
## for `draft_card_view.gd`'s card frame and `console.gd`'s per-row panel:
## "a real corner-radius/colour toggle a texture cannot express"; here it is
## a real TEXTURE toggle). `UiTheme.make_texture_box()` builds the box; this
## file only mutates its `texture`/`modulate_color` fields, the identical
## "one persistent StyleBox, mutated in place" convention this file already
## used for its own former StyleBoxFlat.
##
## ## Skill Tree art pass (author request, 2026-09-23: "the skill tree
## graphics needs to be more detailed ... framed medallions ... carved
## border from the pack's 9-slices")
## The flat, hand-tinted `StyleBoxFlat` frame is replaced by the Tiny Swords
## pack's own carved stone-tablet 9-slices (`UiPalette.TEX_BUTTON_*`) --
## real "framed" art with a bevelled border baked in, rather than a flat
## rounded rectangle -- picked per STATE, inline in `set_state()`'s own
## `match`: dim stone for SILHOUETTE/LOCKED, a red-rimmed tablet for
## UNAFFORDABLE, a
## plain blue tablet for BUYABLE ("available, not yet yours"), and the
## pack's own gold-rimmed "hover" tablet for MAX/OWNED_MAX ("owned nodes
## with a gold rim," task instruction) -- MAX/OWNED_MAX also gets a subtle
## static glow drawn just outside the frame's own edge (`_draw()` below).
## The root (Command Tent) keeps its own distinct round rosette frame
## (`UiPalette.TEX_PANEL_CARVED_SWATCH`) instead of a square tablet, per the
## earlier polish pass's "keep the root visibly special" instruction, now a
## real framed medallion rather than a flat tinted circle-less square.
## Branch identity, since the tablet art itself is not per-branch, is
## carried by three OTHER cues that already existed before this pass and
## still do: the icon's own `glyph_color`, the rank pips' colour, and the
## connecting lines' colour -- a light branch-coloured `modulate_color`
## tint is layered on top of the tablet art ONLY once a node is owned
## (`rank > 0`), so a freshly-revealed, never-bought node reads as neutral
## stone and an owned one warms toward its branch's own colour.
##
## ## Selection is a sibling concern
## This node emits `node_hovered(id)` on mouse hover (hover selects, matching
## the Draft/Console/PausedChoiceBar convention) but does NOT track selection
## itself -- `SkillTreeScreen` owns `_selected_id`; the actual "is this the
## highlighted node" visual is a single shared caret sibling
## (`SkillTreeScreen._selection_caret`), matching `ChoiceHighlightRow`'s own
## "a sibling indicator tracking the highlighted control's rect" technique
## rather than a per-node highlight flag. The hold-to-confirm fill ring lives
## in the detail panel now (polish pass, coordinator item 4), not overlaid on
## the grid node.
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

## Skill Tree art pass: shrunk from 112 (unchanged since the earlier polish
## pass) to make room for the new branch-header-ribbon row and legend row
## ABOVE/BELOW the board (SkillTreeScreen._build_branch_header_row()/
## _build_legend_row()) inside the SAME 1080-px vertical budget -- a real
## capture at 1920x1080 with those two rows added, taken during this pass,
## showed the board's own last row clipped past the screen's bottom edge at
## the old NODE_SIZE/CELL_H. 92 (down from 112, matching CELL_H's own
## proportional shrink in skill_tree_screen.gd) keeps the same node/cell gap
## ratio while freeing roughly 18px x 7 rows = 126px of vertical room.
const NODE_SIZE: float = 92.0
const ICON_SIDE: int = 24
const NAME_FONT_SIZE: int = 13
const PRICE_FONT_SIZE: int = 12
const PIP_SIZE: int = 10
const PIP_GAP: int = 2
const PRICE_ICON_SIDE: int = 13

## Skill Tree art pass: how far the glow drawn in `_draw()` extends past the
## frame's own edge, and its two layered alphas (outer, fainter; inner,
## stronger) -- a cheap two-ring halo, matching this project's own "a couple
## of overlapping semi-transparent rects" convention for a soft glow rather
## than a blur shader (no other Control in this codebase uses one).
const GLOW_OUTER_GROW: float = 10.0
const GLOW_INNER_GROW: float = 4.0
const GLOW_OUTER_ALPHA: float = 0.12
const GLOW_INNER_ALPHA: float = 0.22

var node_id: String = ""
var _last_rank: int = 0

## The branch-appropriate icon `configure()` was given -- restored by
## `set_state()` for every state except LOCKED, which temporarily swaps
## `_icon.shape` to `UiShapeGlyph.Shape.LOCK` instead (see that method).
var _true_shape: int = UiShapeGlyph.Shape.SQUARE

var _icon: UiShapeGlyph
var _name_label: Label
var _silhouette_label: Label
var _pips_row: HBoxContainer
var _price_row: HBoxContainer
var _price_icon: UiShapeGlyph
var _price_label: Label
var _style: StyleBoxTexture

## Skill Tree art pass: true while this node should draw the owned/MAX gold
## halo in `_draw()` below -- set by `set_state()`/`set_silhouette()`, never
## computed inside `_draw()` itself (which only reads it), matching this
## file's existing "state pushed in, view only renders it" convention.
var _glow_enabled: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE # keyboard nav is driven by SkillTreeScreen's own cursor, not Godot focus traversal
	mouse_entered.connect(func() -> void: node_hovered.emit(node_id))
	_style = UiTheme.make_texture_box(UiPalette.TEX_BUTTON_DISABLED, UiPalette.NODE_TEXTURE_MARGIN, 10)
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

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.theme_type_variation = UiTheme.SMALL
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_name_label.custom_minimum_size = Vector2(NODE_SIZE - 20.0, 0.0)
	_name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_name_label)

	_silhouette_label = Label.new()
	_silhouette_label.name = "SilhouetteLabel"
	_silhouette_label.theme_type_variation = UiTheme.VALUE
	_silhouette_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_silhouette_label.visible = false
	column.add_child(_silhouette_label)

	_pips_row = HBoxContainer.new()
	_pips_row.name = "PipsRow"
	_pips_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pips_row.add_theme_constant_override("separation", PIP_GAP)
	_pips_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_pips_row)

	_price_row = HBoxContainer.new()
	_price_row.name = "PriceRow"
	_price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_price_row.add_theme_constant_override("separation", 4)
	_price_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_price_row)

	_price_icon = UiShapeGlyph.new()
	_price_icon.name = "PriceIcon"
	_price_icon.shape = UiShapeGlyph.Shape.CRYSTAL
	_price_icon.glyph_color = UiPalette.CORES
	_price_icon.set_side(PRICE_ICON_SIDE)
	_price_row.add_child(_price_icon)

	_price_label = Label.new()
	_price_label.name = "PriceLabel"
	_price_label.theme_type_variation = UiTheme.SMALL
	_price_label.add_theme_font_size_override("font_size", PRICE_FONT_SIZE)
	_price_row.add_child(_price_label)


## `display_name` is shown on the node itself (polish pass item 1). `shape`/
## `branch_color` are supplied directly (rather than derived from a
## SkillNodeDefinition) so the synthetic "Reset Tree" pseudo-node can share
## this exact widget.
func configure(id: String, shape: int, branch_color: Color, display_name: String) -> void:
	node_id = id
	_true_shape = shape
	_icon.shape = shape
	_icon.glyph_color = branch_color
	_name_label.text = display_name


func set_silhouette() -> void:
	_icon.visible = false
	_name_label.visible = false
	_silhouette_label.visible = true
	_silhouette_label.text = tr("SKILL_TREE_SILHOUETTE_NAME")
	_pips_row.visible = false
	_price_row.visible = false
	# Hiding `_price_row` alone hides the RENDERED result (an ancestor's
	# `visible = false` suppresses drawing) but leaves `_price_label`'s own
	# `visible` flag untouched -- a caller reading that flag directly (a
	# test, primarily) must see `false` too, not just "effectively
	# invisible because its parent is hidden."
	_price_label.visible = false
	_price_icon.visible = false
	_style.texture = load(UiPalette.TEX_BUTTON_DISABLED) as Texture2D
	_style.modulate_color = Color(1, 1, 1, 1)
	_glow_enabled = false
	queue_redraw()
	modulate = Color(1, 1, 1, 1)


## `is_root`: the Command Tent -- always owned, free, no price/pips of its
## own. `branch_color` tints the icon/fill when owned; `price` is only read
## for LOCKED/UNAFFORDABLE/BUYABLE.
func set_state(state: int, rank: int, max_rank: int, price: int, branch_color: Color, is_root: bool) -> void:
	_icon.visible = true
	_name_label.visible = true
	_silhouette_label.visible = false
	_last_rank = rank
	var owned: bool = rank > 0
	_icon.glyph_color = branch_color if owned else UiPalette.TEXT_DIM
	_icon.shape = _true_shape # undoes the LOCKED-state swap below, for a node this call finds NOT locked

	if is_root:
		# Polish pass (coordinator review): "keep the root visibly special
		# ... not a plain green square." A bright TEXT icon (not
		# `branch_color` again) reads against the root's own frame -- using
		# the same colour for both made the tent icon nearly invisible
		# against its own background.
		#
		# Skill Tree art pass: the root gets its OWN round rosette frame
		# (`TEX_PANEL_CARVED_SWATCH`), not one of the square stone tablets
		# every real node uses below -- a real framed MEDALLION, distinct at
		# a glance from a merely-maxed branch node, and a persistent glow
		# (it is always owned).
		_icon.glyph_color = UiPalette.TEXT
		_pips_row.visible = false
		_price_row.visible = false
		_style.texture = load(UiPalette.TEX_PANEL_CARVED_SWATCH) as Texture2D
		_style.modulate_color = Color(1, 1, 1, 1)
		_glow_enabled = true
		queue_redraw()
		return

	_rebuild_pips(max_rank, rank, branch_color)
	_pips_row.visible = max_rank > 0
	_price_row.visible = true
	_price_icon.visible = true
	_price_label.visible = true # undoes set_silhouette()'s own explicit hide, for a node transitioning silhouette -> revealed
	_price_label.remove_theme_color_override("font_color")
	# Skill Tree art pass: branch identity, since the frame TEXTURE below is
	# not per-branch, is carried instead by the icon/pips/line colours
	# (unchanged) plus a light branch-coloured tint layered on the frame
	# ITSELF once the node is owned -- a freshly-revealed, never-bought node
	# reads as neutral stone regardless of branch.
	var branch_tint: Color = Color(1, 1, 1, 1).lerp(branch_color, 0.30) if owned else Color(1, 1, 1, 1)
	_glow_enabled = false
	match state:
		State.LOCKED:
			_price_label.text = str(price)
			_price_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
			_price_icon.glyph_color = UiPalette.TEXT_DIM
			_style.texture = load(UiPalette.TEX_BUTTON_DISABLED) as Texture2D
			_style.modulate_color = Color(1, 1, 1, 1)
			# Task instruction: "locked fog nodes as dim silhouettes with a
			# lock" -- LOCKED (prerequisites not met) shows a padlock where
			# its own branch icon normally sits; SILHOUETTE (not yet
			# revealed at all) keeps the "???" text instead (set_silhouette()
			# never reaches this match arm).
			_icon.shape = UiShapeGlyph.Shape.LOCK
			_icon.glyph_color = UiPalette.TEXT_DIM
		State.UNAFFORDABLE:
			_price_label.text = str(price)
			_price_label.add_theme_color_override("font_color", UiPalette.DANGER)
			_price_icon.glyph_color = UiPalette.DANGER
			_style.texture = load(UiPalette.TEX_BUTTON_DANGER) as Texture2D
			_style.modulate_color = branch_tint
		State.BUYABLE:
			_price_label.text = str(price)
			_price_label.add_theme_color_override("font_color", UiPalette.SUCCESS)
			_price_icon.glyph_color = UiPalette.CORES
			_style.texture = load(UiPalette.TEX_BUTTON_NORMAL) as Texture2D
			_style.modulate_color = branch_tint
		State.MAX, State.OWNED_MAX:
			_price_icon.visible = false
			_price_label.text = tr("SKILL_TREE_MAX")
			_price_label.add_theme_color_override("font_color", UiPalette.ACCENT)
			# Task instruction: "owned nodes with a gold rim and subtle
			# glow" -- the pack's own gold-rimmed "hover" tablet, plus the
			# static halo `_draw()` paints just outside the frame's edge.
			_style.texture = load(UiPalette.TEX_BUTTON_HOVER) as Texture2D
			_style.modulate_color = branch_tint
			_glow_enabled = true
	queue_redraw()


## Skill Tree art pass: the owned/MAX gold halo -- two overlapping,
## semi-transparent outlined rects drawn just OUTSIDE this Control's own
## rect. Godot does not clip a CanvasItem's own `_draw()` calls to its rect
## by default, and the engine draws this PanelContainer's own `panel`
## StyleBox (the carved-stone frame) BEFORE calling into this script's
## `_draw()` override, so the halo -- confined to the region beyond the
## frame's own edge -- reads as a glow AROUND the medallion rather than a
## wash painted over its face. Cheap and static (no per-frame tween): the
## task asks for "a subtle glow," not an animated one, and every other
## per-frame cosmetic effect in this project's UI (HudBar's shake/flash,
## the level emblem's burst) exists to react to a CHANGE, which an
## always-on owned/MAX state has none of to react to.
func _draw() -> void:
	if not _glow_enabled:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect.grow(GLOW_OUTER_GROW), UiPalette.with_alpha(UiPalette.ACCENT, GLOW_OUTER_ALPHA), false, GLOW_OUTER_GROW, true)
	draw_rect(rect.grow(GLOW_INNER_GROW), UiPalette.with_alpha(UiPalette.ACCENT, GLOW_INNER_ALPHA), false, GLOW_INNER_GROW, true)


## One dot per rank -- filled (`branch_color`) for an achieved rank, dim
## (`UiPalette.LINE` at low alpha) for a remaining one. Rebuilt (not
## mutated in place) each call: `max_rank` never changes for a given node
## within one session, but this stays simple and matches every other
## rebuild-on-refresh pattern in this file. `remove_child()` + `free()`
## immediately (not `queue_free()`): these are simple leaf Controls with no
## deferred-teardown hazard, and a caller reading pip state synchronously
## right after `set_state()` (a test, primarily) must see the NEW pips, not
## stale ones still pending a deferred free.
func _rebuild_pips(max_rank: int, rank: int, branch_color: Color) -> void:
	for child in _pips_row.get_children():
		_pips_row.remove_child(child)
		child.free()
	for i in max_rank:
		var pip := UiShapeGlyph.new()
		pip.name = "Pip%d" % i
		pip.shape = UiShapeGlyph.Shape.COIN
		pip.set_side(PIP_SIZE)
		pip.glyph_color = branch_color if i < rank else UiPalette.with_alpha(UiPalette.LINE, 0.6)
		_pips_row.add_child(pip)


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

func get_name_label_for_test() -> Label:
	return _name_label


func get_silhouette_label_for_test() -> Label:
	return _silhouette_label


func get_displayed_rank_for_test() -> int:
	return _last_rank


func get_pip_count_for_test() -> int:
	return _pips_row.get_child_count()


func get_price_label_for_test() -> Label:
	return _price_label


func get_icon_for_test() -> UiShapeGlyph:
	return _icon
