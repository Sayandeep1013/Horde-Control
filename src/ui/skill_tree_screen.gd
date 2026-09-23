extends CanvasLayer
class_name SkillTreeScreen

## Skill Tree screen (Hub/War Camp; docs/18_Permanent_Skill_Tree.md section
## 4 in full). Opened from `HubScreen` as a full-screen overlay, mirroring
## `RunFlowController`'s own "instantiate once, toggle with set_active()"
## pattern for PauseMenu/SettingsMenu/RunEndScreen.
##
## ## Polish pass (coordinator review of skill_tree_1920b_150.png)
## Five fixes, all visual/layout -- no change to the state machine
## (`_state_for()`, `_poll_hold()`, `_find_adjacent()`) underneath:
## 1. `SkillNodeView` itself now shows name/pips/price+icon (that file's own
##    header covers this one).
## 2. The grid no longer reserves a row for Respec (`MAX_Y` shrank from the
##    old `RESPEC_ROW` to the real tree's own `y=5`); Respec moved to a
##    compact header widget (`_respec_view`, sibling of `_board`, not a
##    child of it) so `_board`'s own size matches the tree's real bounding
##    box instead of a rectangle with an extra empty row. `NODE_SIZE` (see
##    SkillNodeView) grew, and `CELL_W`/`CELL_H` grew to match, so the
##    board reads as intentionally large rather than small-and-adrift.
##    `RESPEC_ID` keeps its OWN `_nav_positions` entry one step below the
##    lowest real node (docs/18's own "reachable by the same graph" design)
##    even though its WIDGET now lives outside `_board` -- navigation math
##    and widget placement are decoupled on purpose.
## 3. `Dim` is now fully opaque (alpha 1.0, was 0.92): at 92% the Hub's own
##    Title/Cores pill still read through faintly behind this screen's own
##    header, which a full-screen takeover (unlike the Draft's intentional
##    60% see-through) never wants.
## 4. The detail panel gained a branch line, a combined current-arrow-next
##    effect line, a requirements list with tick/cross glyphs (every
##    prerequisite, not just missing ones), a rank/price row, and the
##    hold-to-confirm fill ring moved HERE (`_detail_hold_ring`) instead of
##    floating over the grid node -- one ring, in the one place the player
##    is already reading price/requirements text.
## 5. Hub's own polish (banner/sheep/ribbon menu header) lives in
##    hub_screen.gd, not here.
##
## ## Layout: a diagram, not container-flowed text (named exception)
## `docs/19_UI_UX.md` > "UI Layout & Dynamic Container Rules" governs TEXT
## containers (labels, tooltips, cards, rows); this screen's grid is a node
## GRAPH whose layout comes from each node's own `grid_position`
## (docs/18 section 4.1: "the Hub/Skill Tree screen's own canvas layout"),
## exactly like a minimap or a graph editor -- there is no Container type
## that lays out nodes by arbitrary integer coordinates. `_board` (a plain
## `Control`, not a `Container`) positions each `SkillNodeView` by an offset
## computed from `grid_position`; every node WITHIN a node (its icon/name/
## pips/price column) still goes through ordinary `VBoxContainer` flow, and
## the whole screen is authored at the project's 1920x1080 design canvas
## (`canvas_items` stretch mode; project.godot), so it scales uniformly to
## 1280x720 with no separate layout pass.
##
## ## Buying: the shared `confirm` action, not a per-node mouse hold
## `project.godot`'s own `confirm` action already binds Space, Enter, LEFT
## MOUSE BUTTON, and gamepad A/Cross in one action -- so holding `confirm`
## while the currently SELECTED node is buyable (`_poll_hold()` below)
## covers mouse, keyboard, and gamepad with the exact same accumulator,
## mirroring `PausedChoiceBar._poll_hold_up_input()` /
## `DraftController._poll_hold_up_input()`'s pattern with `confirm` in place
## of `move_up` -- `move_up` is not free here the way it is on the Draft's
## 1D card row, since all four directions drive 2D grid navigation. A node
## is SELECTED by mouse hover, a mouse click, or arrow/WASD/d-pad navigation
## (`_find_adjacent()`); the shared `HOLD_CONFIRM_SECONDS` fill ring lives in
## the detail panel (polish pass item 4), matching Console's own single
## shared `DraftFillRing` rather than one ring per row/node.
##
## ## Movement-only path (docs/19 "the game is playable with movement input
## alone, and every menu has a movement-only path"), named as an
## interpretation
## `confirm` is not a movement key, so a strict movement-only player could
## not otherwise buy anything. This screen borrows the SAME mechanic the
## Console already uses for its own movement-only purchase path (docs/19 >
## "Tower Console UI": "Standing still ... for 1.0 second buys one rank"):
## once the player has navigated at least once (`_movement_only_armed`),
## holding NO directional input while a buyable node is selected accumulates
## the identical hold progress. Gated on having navigated at least once so
## opening the screen with no input held cannot silently auto-buy the
## default selection (root is never buyable, but the first REAL selection
## could be) -- the movement equivalent of the Draft's own neutral-return
## arming rule.
##
## ## Reveal / fog (docs/18 section 4.1)
## `refresh()` diffs `MetaProgress.is_visible(id)` against the previous call
## (`_was_visible`) and fades in (`SkillNodeView.play_reveal_fade()`) any
## node that just became visible -- never on the FIRST refresh after
## `set_active(true)` (`initial: true`), so nodes already revealed from a
## prior session do not replay the reveal animation every time the screen
## reopens.
##
## ## Respec is a node in the same graph, not a second input system
## `RESPEC_ID` is a synthetic entry in `_nav_positions`, one row below the
## Fortune branch's own capstone (War Chest) for NAVIGATION purposes only
## (see polish-pass item 2 above for why its WIDGET lives elsewhere) --
## reachable by the SAME keyboard/gamepad/mouse selection and the SAME
## hold-to-confirm gesture as every real node, so no second timing/
## selection system is invented for one button. Its "price" badge shows the
## refund preview (`MetaProgress.get_respec_refund_preview()`) instead of a
## cost.

signal back_requested()

const RESPEC_ID: String = "__respec__"

## Reused from PausedChoiceBar/DraftController (class header) -- the one
## hold-to-confirm timing the Register defines anywhere (Draft input row).
const HOLD_CONFIRM_SECONDS: float = 1.0
const CYCLE_REPEAT_SECONDS: float = 0.3

const SKILL_TREE_CANVAS_LAYER: int = 5

## Grid bounding box (data/meta/skill_tree.tres' own authored grid_position
## values, see that file's own layout comment): x in [-4, 4], y in [-1, 5].
## Respec is NOT part of this box any more (polish pass item 2) -- its own
## `_nav_positions` entry sits one step past MAX_Y, for navigation only.
const MIN_X: int = -4
const MAX_X: int = 4
const MIN_Y: int = -1
const MAX_Y: int = 5

## Polish pass item 2: bigger cells for the bigger `SkillNodeView.NODE_SIZE`
## (84 -> 112). Padding (CELL - NODE_SIZE) stays roomy enough for the
## prerequisite lines to read clearly between nodes.
const CELL_W: float = 150.0
const CELL_H: float = 122.0 # 7 rows x 122 = 854 px fits the 1080p board; 132 clipped the bottom row (orchestrator review)
const DETAIL_PANEL_WIDTH: float = 420.0
## The root's own footprint (polish pass item 2: "keep the root visibly
## special ... larger").
const ROOT_SIZE: float = 172.0 # a clearly bigger footprint than any real node's own NODE_SIZE (112) -- see coordinator review, "keep the root visibly special ... larger"
const RESPEC_WIDGET_SIZE: float = 92.0

var _tree: SkillTreeDefinition = null
var _content_root: Control = null # the root Control _build_ui() creates -- see set_active()'s own header on why the fade targets this, not `self`
var _node_views: Dictionary = {} # String id -> SkillNodeView
var _nav_positions: Dictionary = {} # String id -> Vector2 (grid-space, RESPEC_ID included)
var _was_visible: Dictionary = {} # String id -> bool, for reveal-fade diffing
var _selected_id: String = ""
var _respec_view: SkillNodeView = null

var _board: Control = null # SkillTreeBoard instance
var _selection_caret: UiShapeGlyph = null
var _cores_label: Label = null
var _back_button: Button = null
var _detail_name: Label = null
var _detail_branch: Label = null
var _detail_effect: Label = null
var _detail_requirements_box: VBoxContainer = null
var _detail_rank: Label = null
var _detail_price_icon: UiShapeGlyph = null
var _detail_price: Label = null
var _detail_hint: Label = null
var _detail_hold_ring: DraftFillRing = null

var _hold_progress: float = 0.0
var _movement_only_armed: bool = false
## docs/18 section 6 edge case: "Double input on purchase (held key
## repeats): One rank per completed hold; the hold must release before the
## next." Set the instant a purchase completes; cleared only once `confirm`
## is observed NOT pressed at least once -- so a `confirm` key/click/button
## still held down after buying rank N cannot immediately keep filling and
## buy rank N+1 without the player releasing first. The movement-only path's
## own equivalent reuses `_movement_only_armed` (cleared on purchase,
## re-armed only after the player moves again), needing no second flag.
var _confirm_requires_release: bool = false

## action name -> {"vec": Vector2i, "held": bool, "timer": float}
var _dir_state: Dictionary = {}

var _use_test_input: bool = false
var _test_pressed: Dictionary = {}
var _test_just_pressed: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = SKILL_TREE_CANVAS_LAYER
	visible = false
	_tree = MetaProgress.skill_tree
	_dir_state = {
		"move_up": {"vec": Vector2i(0, -1), "held": false, "timer": 0.0},
		"move_down": {"vec": Vector2i(0, 1), "held": false, "timer": 0.0},
		"move_left": {"vec": Vector2i(-1, 0), "held": false, "timer": 0.0},
		"move_right": {"vec": Vector2i(1, 0), "held": false, "timer": 0.0},
	}
	_build_ui()
	refresh(true)


func _process(delta: float) -> void:
	if not visible:
		return
	_poll_navigation(delta)
	_poll_back_input()
	_poll_hold(delta)
	_clear_test_edges_for_frame()


## Typed command (HubScreen's own "Skill Tree" button / RunEndScreen-style
## `set_active()` convention). Resets selection to the root and re-arms the
## movement-only gate every time the screen opens.
func set_active(active: bool) -> void:
	visible = active
	if active:
		_movement_only_armed = false
		_hold_progress = 0.0
		refresh(true)
		# Neutral-return arming (docs/19 > "Input Lockout & Arming"), applied
		# by `_select()` itself: a `confirm` press already held at the
		# moment this screen opens (e.g. a keyboard player held Space
		# through the Hub's own "Skill Tree" button activation) must not
		# immediately start filling the hold the instant navigation reaches
		# a buyable node -- mirrors `PausedChoiceBar._reset_input_state()`'s
		# identical `_hold_up_armed = not _is_pressed(...)` rule.
		_select(_tree.root_id)
		# `self` is a CanvasLayer (no `modulate` of its own -- only CanvasItem/
		# Control has one); the fade animates `_content_root`, the actual
		# Control this screen builds, exactly like MenuFrame.animate_in()
		# fades `parts.card`, never the owning CanvasLayer.
		if _content_root != null:
			_content_root.modulate.a = 0.0
			var tween: Tween = _content_root.create_tween()
			tween.tween_property(_content_root, "modulate:a", 1.0, UiPalette.MOTION_BASE)


func is_active_for_test() -> bool:
	return visible


# --- MetaProgress -> visuals -------------------------------------------------

## Rebuilds every node's visual state from `MetaProgress` and the connecting
## lines, fading in any node that just became revealed. `initial == true`
## (the first call after `set_active(true)`) suppresses that fade -- see
## class header, "Reveal / fog."
func refresh(initial: bool = false) -> void:
	var newly_revealed: Array[String] = []
	for def in _tree.nodes:
		if def.id == _tree.root_id:
			continue
		var now_visible: bool = MetaProgress.is_visible(def.id)
		if not initial and now_visible and not _was_visible.get(def.id, false):
			newly_revealed.append(def.id)
		_was_visible[def.id] = now_visible

	_refresh_all_node_visuals()
	_rebuild_lines()
	_refresh_cores_label()
	_refresh_detail_panel()
	_refresh_hold_ring_visibility()
	_reposition_indicators()

	for id in newly_revealed:
		var view: SkillNodeView = _node_views.get(id)
		if view != null:
			view.play_reveal_fade()


func _refresh_all_node_visuals() -> void:
	for def in _tree.nodes:
		var view: SkillNodeView = _node_views.get(def.id)
		if view == null:
			continue
		if def.id == _tree.root_id:
			view.set_state(SkillNodeView.State.OWNED_MAX, 1, 1, 0, _branch_color(def.branch), true)
			continue
		if not MetaProgress.is_visible(def.id):
			view.set_silhouette()
			continue
		var state: int = _state_for(def.id)
		var rank: int = MetaProgress.get_rank(def.id)
		var price: int = maxi(MetaProgress.price_of_next_rank(def.id), 0)
		view.set_state(state, rank, def.max_rank, price, _branch_color(def.branch), false)
	_refresh_respec_visual()


func _refresh_respec_visual() -> void:
	if _respec_view == null:
		return
	var refund: int = MetaProgress.get_respec_refund_preview()
	var state: int = SkillNodeView.State.BUYABLE if refund > 0 else SkillNodeView.State.MAX
	_respec_view.set_state(state, 0, 0, refund, UiPalette.DANGER, false)


## The node-graph state a node currently reads as (SkillNodeView.State),
## computed from the public MetaProgress queries only -- see this file's
## own header on `prerequisites_met()`/`get_respec_refund_preview()`.
func _state_for(id: String) -> int:
	if id == RESPEC_ID:
		return SkillNodeView.State.BUYABLE if MetaProgress.get_respec_refund_preview() > 0 else SkillNodeView.State.MAX
	if _tree != null and id == _tree.root_id:
		return SkillNodeView.State.OWNED_MAX
	if not MetaProgress.is_visible(id):
		return SkillNodeView.State.SILHOUETTE
	var def: SkillNodeDefinition = _tree.get_node_definition(id) if _tree != null else null
	if def == null:
		return SkillNodeView.State.SILHOUETTE
	var rank: int = MetaProgress.get_rank(id)
	if rank >= def.max_rank:
		return SkillNodeView.State.MAX
	if not MetaProgress.prerequisites_met(id):
		return SkillNodeView.State.LOCKED
	var price: int = MetaProgress.price_of_next_rank(id)
	return SkillNodeView.State.BUYABLE if MetaProgress.get_cores() >= price else SkillNodeView.State.UNAFFORDABLE


func _rebuild_lines() -> void:
	var lines: Array = []
	for def in _tree.nodes:
		if def.id == _tree.root_id:
			continue
		if not MetaProgress.is_visible(def.id):
			continue
		var child_view: Control = _node_views.get(def.id)
		if child_view == null:
			continue
		var child_owned: bool = MetaProgress.get_rank(def.id) > 0
		for prereq_id in def.prerequisite_ids:
			var parent_view: Control = _node_views.get(prereq_id)
			if parent_view == null:
				continue
			var parent_owned: bool = prereq_id == _tree.root_id or MetaProgress.get_rank(prereq_id) > 0
			var line_color: Color = _branch_color(def.branch) if (parent_owned and child_owned) else (UiPalette.LINE_STRONG if parent_owned else UiPalette.LINE)
			lines.append({
				"from": _node_center(parent_view),
				"to": _node_center(child_view),
				"color": line_color,
				"width": 5.0 if parent_owned else 2.0,
			})
	_board.set_lines(lines)


func _node_center(view: Control) -> Vector2:
	return view.position + view.size * 0.5


static func _branch_color(branch: int) -> Color:
	match branch:
		SkillNodeDefinition.Branch.ARCHER:
			return UiPalette.PLAYER
		SkillNodeDefinition.Branch.TOWER:
			return UiPalette.TOWER
		SkillNodeDefinition.Branch.FORTUNE:
			return UiPalette.GOLD
	return UiPalette.ACCENT


## Not `static`, unlike its siblings above: `tr()` needs an instance (the
## SAME "static func can't call tr()" constraint run_end.gd's own
## `_apply_total_text()` already worked around once this session).
func _branch_name(branch: int) -> String:
	match branch:
		SkillNodeDefinition.Branch.ARCHER:
			return tr("SKILL_TREE_BRANCH_ARCHER")
		SkillNodeDefinition.Branch.TOWER:
			return tr("SKILL_TREE_BRANCH_TOWER")
		SkillNodeDefinition.Branch.FORTUNE:
			return tr("SKILL_TREE_BRANCH_FORTUNE")
	return ""


static func _shape_for(def: SkillNodeDefinition) -> int:
	match def.branch:
		SkillNodeDefinition.Branch.ARCHER:
			return UiShapeGlyph.Shape.TRIANGLE
		SkillNodeDefinition.Branch.TOWER:
			return UiShapeGlyph.Shape.TOWER
		SkillNodeDefinition.Branch.FORTUNE:
			return UiShapeGlyph.Shape.COIN
	return UiShapeGlyph.Shape.SQUARE


## `def.value_per_rank * ranks` is the TOTAL effect at that many ranks
## (docs/18 section 4.1: "Percentages add within a node"). Whether the
## template is a percentage or a flat number is read off the template text
## itself ("%" present or not) rather than a second effect-kind switch
## duplicating `MetaLoadoutApplier`'s own one.
static func _value_text(def: SkillNodeDefinition, ranks: int) -> String:
	var total: float = def.value_per_rank * float(ranks)
	if def.description_template.contains("%"):
		return "+%d%%" % int(round(total * 100.0))
	return "+%d" % int(round(total))


static func _format_effect(def: SkillNodeDefinition, ranks: int) -> String:
	return def.description_template.format({"value": _value_text(def, ranks).trim_prefix("+")})


## docs/18's own three "mechanic" one-rank nodes (Second Wind, Fortress, War
## Chest) have no numeric progression to arrow between -- their template
## carries no "{value}"/"%" placeholder at all, so `description_template`
## alone (rather than the "current → next" line below) already says
## everything there is to say.
static func _is_mechanic_node(def: SkillNodeDefinition) -> bool:
	return not def.description_template.contains("{value}")


# --- Selection ----------------------------------------------------------------

func _on_node_hovered(id: String) -> void:
	_select(id)


func _select(id: String) -> void:
	if id == "" or not _node_views.has(id):
		return
	_selected_id = id
	_hold_progress = 0.0
	# Re-arm for the NEW selection, not unconditionally: if `confirm` happens
	# to still be held down at the moment selection changes (e.g. the player
	# is navigating while still holding the key/button that opened this
	# screen, or that just bought the previous node), the new node must
	# still require an observed release first -- the same neutral-return
	# rule `set_active()` applies on open, applied uniformly on every
	# selection change rather than only at open time.
	_confirm_requires_release = _is_pressed(&"confirm")
	_refresh_detail_panel()
	_refresh_hold_ring_visibility()
	_reposition_indicators()


## The board caret only makes sense over a node actually inside `_board`
## (polish pass item 2 moved Respec's own widget out of it); selecting
## Respec instead brightens its own header widget.
func _reposition_indicators() -> void:
	if _respec_view != null:
		_respec_view.modulate = Color(1.15, 1.15, 1.15) if _selected_id == RESPEC_ID else Color(1.0, 1.0, 1.0)
	if _selection_caret == null:
		return
	if _selected_id == RESPEC_ID:
		_selection_caret.visible = false
		return
	var view: Control = _node_views.get(_selected_id)
	if view == null:
		_selection_caret.visible = false
		return
	_selection_caret.visible = true
	var center: Vector2 = _node_center(view)
	_selection_caret.size = Vector2(24.0, 16.0)
	_selection_caret.position = Vector2(center.x - 12.0, view.position.y + view.size.y + 6.0)


func _refresh_hold_ring_visibility() -> void:
	if _detail_hold_ring == null:
		return
	_detail_hold_ring.visible = _state_for(_selected_id) == SkillNodeView.State.BUYABLE
	if not _detail_hold_ring.visible:
		_detail_hold_ring.progress = 0.0


## Polish pass item 4: name, branch, current->next effect, a full
## requirements list (every prerequisite, ticked or crossed -- not just the
## missing ones), rank/price, and the hold hint the ring sits beside.
func _refresh_detail_panel() -> void:
	if _detail_name == null:
		return
	var id: String = _selected_id
	_clear_requirements_box()

	if id == RESPEC_ID:
		_detail_name.text = tr("SKILL_TREE_RESPEC")
		_detail_branch.visible = false
		_detail_effect.text = tr("SKILL_TREE_RESPEC_DESC")
		_detail_rank.visible = false
		_detail_price_icon.visible = false
		_detail_price.remove_theme_color_override("font_color")
		var refund: int = MetaProgress.get_respec_refund_preview()
		if refund > 0:
			_detail_price.text = tr("SKILL_TREE_RESPEC_REFUND") % refund
			_detail_price.add_theme_color_override("font_color", UiPalette.SUCCESS)
			_detail_hint.text = tr("SKILL_TREE_HOLD_TO_RESET")
			_detail_hint.visible = true
		else:
			_detail_price.text = tr("SKILL_TREE_RESPEC_NONE")
			_detail_price.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
			_detail_hint.visible = false
		return

	if not MetaProgress.is_visible(id):
		_detail_name.text = tr("SKILL_TREE_SILHOUETTE_NAME")
		_detail_branch.visible = false
		_detail_effect.text = tr("SKILL_TREE_SILHOUETTE_HINT")
		_detail_rank.visible = false
		_detail_price_icon.visible = false
		_detail_price.text = ""
		_detail_hint.visible = false
		return

	var def: SkillNodeDefinition = _tree.get_node_definition(id)
	if def == null:
		return
	_detail_name.text = def.display_name

	if id == _tree.root_id:
		_detail_branch.visible = false
		_detail_effect.text = tr("SKILL_TREE_ROOT_EXPLANATION")
		_detail_rank.visible = false
		_detail_price_icon.visible = false
		_detail_price.text = ""
		_detail_hint.visible = false
		return

	_detail_branch.visible = true
	_detail_branch.text = _branch_name(def.branch)

	var rank: int = MetaProgress.get_rank(id)
	if _is_mechanic_node(def):
		_detail_effect.text = def.description_template
	elif rank >= def.max_rank:
		_detail_effect.text = "%s (%s)" % [_value_text(def, rank), tr("SKILL_TREE_MAX")]
	else:
		_detail_effect.text = "%s -> %s" % [_value_text(def, rank), _value_text(def, rank + 1)]

	_build_requirements_box(def)

	_detail_rank.visible = def.max_rank > 0
	if def.max_rank > 0:
		_detail_rank.text = tr("SKILL_TREE_RANK_OF") % [rank, def.max_rank]

	var state: int = _state_for(id)
	_detail_price.remove_theme_color_override("font_color")
	_detail_hint.visible = false
	_detail_price_icon.visible = true
	match state:
		SkillNodeView.State.MAX:
			_detail_price_icon.visible = false
			_detail_price.text = tr("SKILL_TREE_MAX")
			_detail_price.add_theme_color_override("font_color", UiPalette.ACCENT)
		SkillNodeView.State.LOCKED:
			_detail_price.text = str(MetaProgress.price_of_next_rank(id))
			_detail_price.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
			_detail_price_icon.glyph_color = UiPalette.TEXT_DIM
		SkillNodeView.State.UNAFFORDABLE:
			_detail_price.text = str(MetaProgress.price_of_next_rank(id))
			_detail_price.add_theme_color_override("font_color", UiPalette.DANGER)
			_detail_price_icon.glyph_color = UiPalette.DANGER
		SkillNodeView.State.BUYABLE:
			_detail_price.text = str(MetaProgress.price_of_next_rank(id))
			_detail_price.add_theme_color_override("font_color", UiPalette.SUCCESS)
			_detail_price_icon.glyph_color = UiPalette.CORES
			_detail_hint.text = tr("SKILL_TREE_HOLD_TO_BUY")
			_detail_hint.visible = true


func _clear_requirements_box() -> void:
	for child in _detail_requirements_box.get_children():
		_detail_requirements_box.remove_child(child)
		child.free()


## One row per prerequisite -- a small check/cross glyph (reusing
## `OutcomeGlyph`'s own drawn check-or-X, matching this project's "draw it,
## don't rely on a font glyph" convention) plus that prerequisite's display
## name. Shows EVERY prerequisite, ticked or crossed (polish pass item 4:
## "requirements with ticks/crosses"), not only the ones still missing.
func _build_requirements_box(def: SkillNodeDefinition) -> void:
	for prereq_id in def.prerequisite_ids:
		var pdef: SkillNodeDefinition = _tree.get_node_definition(prereq_id)
		var owned: bool = MetaProgress.get_rank(prereq_id) > 0
		var row := HBoxContainer.new()
		row.theme_type_variation = UiTheme.hbox("XS")
		_detail_requirements_box.add_child(row)

		var glyph := OutcomeGlyph.new()
		glyph.custom_minimum_size = Vector2(18.0, 18.0)
		glyph.set_defeat(not owned)
		row.add_child(glyph)

		var label := Label.new()
		label.text = pdef.display_name if pdef != null else prereq_id
		label.theme_type_variation = UiTheme.DIM
		row.add_child(label)


func _refresh_cores_label() -> void:
	if _cores_label != null:
		_cores_label.text = str(MetaProgress.get_cores())


# --- Navigation / input -------------------------------------------------------

func _poll_navigation(delta: float) -> void:
	var moved_any: bool = false
	for action in _dir_state.keys():
		var st: Dictionary = _dir_state[action]
		var now: bool = _is_pressed(StringName(action))
		if now and not st["held"]:
			_try_move(st["vec"])
			st["timer"] = CYCLE_REPEAT_SECONDS
			moved_any = true
		elif now and st["held"]:
			st["timer"] -= delta
			if st["timer"] <= 0.0:
				_try_move(st["vec"])
				st["timer"] = CYCLE_REPEAT_SECONDS
				moved_any = true
		st["held"] = now
	if moved_any:
		_movement_only_armed = true


func _try_move(dir: Vector2i) -> void:
	var target: String = _find_adjacent(_selected_id, dir)
	if target != "":
		_select(target)


## Nearest-in-direction spatial navigation over `_nav_positions` (real nodes'
## own `grid_position` plus `RESPEC_ID`'s synthetic slot): among every OTHER
## revealed node whose offset from `current_id` has a positive dot product
## with the requested direction, picks the one with the best combination of
## directional alignment and proximity. `RESPEC_ID` is always a candidate
## regardless of visibility (it has none); every real node is filtered on
## `MetaProgress.is_visible()`, matching "keyboard navigation reaches every
## REVEALED node" -- a silhouette is never a valid nav target.
func _find_adjacent(current_id: String, dir: Vector2i) -> String:
	if not _nav_positions.has(current_id):
		return ""
	var current_pos: Vector2 = _nav_positions[current_id]
	var dir_v: Vector2 = Vector2(dir).normalized()
	var best_id: String = ""
	var best_score: float = -INF
	for id in _nav_positions.keys():
		if id == current_id:
			continue
		if id != RESPEC_ID and not MetaProgress.is_visible(id):
			continue
		var delta: Vector2 = _nav_positions[id] - current_pos
		if delta.length() < 0.001:
			continue
		var dot: float = delta.normalized().dot(dir_v)
		if dot < 0.3:
			continue
		var score: float = dot * 1000.0 - delta.length()
		if score > best_score:
			best_score = score
			best_id = id
	return best_id


func _any_direction_pressed() -> bool:
	for action in _dir_state.keys():
		if _is_pressed(StringName(action)):
			return true
	return false


func _poll_back_input() -> void:
	if _is_just_pressed(&"ui_cancel"):
		back_requested.emit()


## See class header, "Buying" and "Movement-only path." `confirm` covers
## mouse/keyboard/gamepad in one action; the movement-only branch requires
## at least one prior navigation move (`_movement_only_armed`) and no
## direction currently pressed, mirroring the Console's own "stand still to
## buy" gate for the same accessibility reason.
##
## docs/18 section 6 edge case ("the hold must release before the next"):
## `_confirm_requires_release` blocks the confirm-hold path from
## immediately re-accumulating the instant a purchase completes while the
## same key/click/button is still held down; the movement-only path's own
## equivalent is `_movement_only_armed` being cleared on purchase (the
## player must move away and stop again to re-arm it).
func _poll_hold(delta: float) -> void:
	var state: int = _state_for(_selected_id)
	var confirm_down: bool = _is_pressed(&"confirm")

	if _confirm_requires_release and not confirm_down:
		_confirm_requires_release = false

	if _is_just_pressed(&"confirm") and state == SkillNodeView.State.UNAFFORDABLE:
		var view: SkillNodeView = _node_views.get(_selected_id)
		if view != null:
			view.play_shake()

	var accumulating: bool = false
	if state == SkillNodeView.State.BUYABLE:
		if confirm_down and not _confirm_requires_release:
			accumulating = true
		elif _movement_only_armed and not _any_direction_pressed():
			accumulating = true

	if accumulating:
		_hold_progress += delta
		if _hold_progress >= HOLD_CONFIRM_SECONDS:
			_hold_progress = 0.0
			_confirm_requires_release = true
			_movement_only_armed = false
			_confirm_selected()
	else:
		_hold_progress = 0.0

	if _detail_hold_ring != null and _detail_hold_ring.visible:
		_detail_hold_ring.progress = clampf(_hold_progress / HOLD_CONFIRM_SECONDS, 0.0, 1.0)


func _confirm_selected() -> void:
	var id: String = _selected_id
	if id == RESPEC_ID:
		MetaProgress.respec()
		refresh()
		if _respec_view != null:
			_respec_view.play_purchase_pulse()
	else:
		if MetaProgress.buy(id):
			refresh()
			var view: SkillNodeView = _node_views.get(id)
			if view != null:
				view.play_purchase_pulse()


func _is_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_pressed.get(action, false))
	return Input.is_action_pressed(action)


func _is_just_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_just_pressed.get(action, false))
	return Input.is_action_just_pressed(action)


func _clear_test_edges_for_frame() -> void:
	if _use_test_input:
		_test_just_pressed.clear()


# --- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	UiStrings.ensure_registered()
	var root := Control.new()
	root.name = "Root"
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	_content_root = root

	# Polish pass item 3: fully opaque -- this screen fully covers/dims the
	# Hub underneath (unlike the Draft's own intentional 60% see-through
	# over live gameplay), so nothing of the Hub's own Title/Cores pill
	# reads through behind this screen's own header.
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = UiPalette.DIM_TINT
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, UiPalette.SPACE_XL)
	root.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.theme_type_variation = UiTheme.vbox("M")
	margin.add_child(column)

	_build_header(column)
	var sep := HSeparator.new()
	column.add_child(sep)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.theme_type_variation = UiTheme.hbox("L")
	column.add_child(body)

	# The tree's own parchment board (docs/18 section 4.1: "nodes laid out
	# ... on a parchment board") -- a real UiTheme.PANEL, matching the
	# detail panel's own material, so the node graph reads as one wooden-
	# framed board rather than floating over the bare screen dim.
	var board_panel := PanelContainer.new()
	board_panel.name = "BoardPanel"
	board_panel.theme_type_variation = UiTheme.PANEL
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(board_panel)

	var board_center := CenterContainer.new()
	board_center.name = "BoardCenter"
	board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_center.mouse_filter = Control.MOUSE_FILTER_PASS
	board_panel.add_child(board_center)

	_board = SkillTreeBoard.new()
	_board.name = "Board"
	_board.custom_minimum_size = Vector2((MAX_X - MIN_X + 1) * CELL_W, (MAX_Y - MIN_Y + 1) * CELL_H)
	_board.mouse_filter = Control.MOUSE_FILTER_PASS
	board_center.add_child(_board)

	_build_nodes()

	_selection_caret = UiShapeGlyph.new()
	_selection_caret.name = "SelectionCaret"
	_selection_caret.shape = UiShapeGlyph.Shape.TRIANGLE
	_selection_caret.glyph_color = UiPalette.ACCENT
	_selection_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_selection_caret)

	var vsep := VSeparator.new()
	body.add_child(vsep)

	_build_detail_panel(body)


func _build_header(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.name = "Header"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.theme_type_variation = UiTheme.hbox("L")
	parent.add_child(row)

	var title := Label.new()
	title.name = "Title"
	title.text = tr("SKILL_TREE_TITLE")
	title.theme_type_variation = UiTheme.HEADING
	row.add_child(title)

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Polish pass item 2: Respec is a compact widget here now, not a grid
	# row -- still the SAME SkillNodeView component (shake/pulse/state
	# styling all reused as-is), just placed in the header instead of
	# `_board`. `_nav_positions[RESPEC_ID]` (set in `_build_nodes()`) still
	# lets keyboard/gamepad navigation reach it from the bottom of the tree.
	_respec_view = SkillNodeView.new()
	_respec_view.name = "RespecWidget"
	row.add_child(_respec_view)
	_respec_view.configure(RESPEC_ID, UiShapeGlyph.Shape.RECYCLE, UiPalette.DANGER, tr("SKILL_TREE_RESPEC"))
	_respec_view.custom_minimum_size = Vector2(RESPEC_WIDGET_SIZE, RESPEC_WIDGET_SIZE)
	_respec_view.size = Vector2(RESPEC_WIDGET_SIZE, RESPEC_WIDGET_SIZE)
	_respec_view.node_hovered.connect(_on_node_hovered)
	_node_views[RESPEC_ID] = _respec_view
	_nav_positions[RESPEC_ID] = Vector2(0, MAX_Y + 1)

	var cores_pill := PanelContainer.new()
	cores_pill.name = "CoresPill"
	cores_pill.theme_type_variation = UiTheme.PILL
	row.add_child(cores_pill)

	var cores_row := HBoxContainer.new()
	cores_row.theme_type_variation = UiTheme.hbox("XS")
	cores_pill.add_child(cores_row)

	var cores_icon := UiShapeGlyph.new()
	cores_icon.shape = UiShapeGlyph.Shape.CRYSTAL
	cores_icon.glyph_color = UiPalette.CORES
	cores_icon.set_side(28)
	cores_row.add_child(cores_icon)

	_cores_label = Label.new()
	_cores_label.name = "CoresLabel"
	_cores_label.theme_type_variation = UiTheme.VALUE
	cores_row.add_child(_cores_label)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = tr("SKILL_TREE_BACK")
	_back_button.custom_minimum_size = Vector2(160, 56)
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(_back_button)


## `SkillNodeView.configure()` reaches into children `_ready()` builds
## (`_icon`, `_name_label`, `_price_label`) -- each view is therefore added
## to `_board` (already inside the live tree at this point, so `_ready()`
## fires synchronously, same as `RunFlowController`'s own
## `pause_menu_scene.instantiate(); add_child(pause_menu)` pattern) BEFORE
## `configure()`/`_position_node()` ever touch it.
func _build_nodes() -> void:
	for def in _tree.nodes:
		var view := SkillNodeView.new()
		view.name = "Node_%s" % def.id
		_board.add_child(view)
		var is_root: bool = def.id == _tree.root_id
		var shape: int = UiShapeGlyph.Shape.TENT if is_root else _shape_for(def)
		view.configure(def.id, shape, _branch_color(def.branch), def.display_name)
		view.node_hovered.connect(_on_node_hovered)
		_position_node(view, def.grid_position, ROOT_SIZE if is_root else SkillNodeView.NODE_SIZE)
		_node_views[def.id] = view
		_nav_positions[def.id] = Vector2(def.grid_position)


func _position_node(view: Control, grid_pos: Vector2i, size: float) -> void:
	var col: int = grid_pos.x - MIN_X
	var row: int = grid_pos.y - MIN_Y
	view.position = Vector2(
		col * CELL_W + (CELL_W - size) * 0.5,
		row * CELL_H + (CELL_H - size) * 0.5,
	)
	view.size = Vector2(size, size)


func _build_detail_panel(parent: Container) -> void:
	var panel := PanelContainer.new()
	panel.name = "DetailPanel"
	panel.theme_type_variation = UiTheme.ROW
	panel.custom_minimum_size = Vector2(DETAIL_PANEL_WIDTH, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	# No theme_type_variation here: UiPalette.SPACE_S is the theme's own
	# default VBoxContainer separation (UiTheme.BOX_STEPS's own header:
	# "SPACE_S is the theme default and needs no variation").
	panel.add_child(column)

	_detail_name = Label.new()
	_detail_name.name = "NameLabel"
	_detail_name.theme_type_variation = UiTheme.HEADING
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_detail_name)

	_detail_branch = Label.new()
	_detail_branch.name = "BranchLabel"
	_detail_branch.theme_type_variation = UiTheme.DIM
	column.add_child(_detail_branch)
	column.add_child(HSeparator.new())

	_detail_effect = Label.new()
	_detail_effect.name = "EffectLabel"
	_detail_effect.theme_type_variation = UiTheme.VALUE
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_effect.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_detail_effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_detail_effect)

	_detail_requirements_box = VBoxContainer.new()
	_detail_requirements_box.name = "RequirementsBox"
	_detail_requirements_box.theme_type_variation = UiTheme.vbox("XS")
	column.add_child(_detail_requirements_box)

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_detail_rank = Label.new()
	_detail_rank.name = "RankLabel"
	_detail_rank.theme_type_variation = UiTheme.DIM
	_detail_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_detail_rank)

	var price_row := HBoxContainer.new()
	price_row.name = "PriceRow"
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.theme_type_variation = UiTheme.hbox("XS")
	column.add_child(price_row)

	_detail_price_icon = UiShapeGlyph.new()
	_detail_price_icon.name = "PriceIcon"
	_detail_price_icon.shape = UiShapeGlyph.Shape.CRYSTAL
	_detail_price_icon.glyph_color = UiPalette.CORES
	_detail_price_icon.set_side(24)
	price_row.add_child(_detail_price_icon)

	_detail_price = Label.new()
	_detail_price.name = "PriceLabel"
	_detail_price.theme_type_variation = UiTheme.HEADING
	price_row.add_child(_detail_price)

	var hold_row := HBoxContainer.new()
	hold_row.name = "HoldRow"
	hold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	# No theme_type_variation here either -- same SPACE_S default as above.
	column.add_child(hold_row)

	_detail_hint = Label.new()
	_detail_hint.name = "HintLabel"
	_detail_hint.theme_type_variation = UiTheme.DIM
	hold_row.add_child(_detail_hint)

	_detail_hold_ring = DraftFillRing.new()
	_detail_hold_ring.name = "HoldRing"
	_detail_hold_ring.custom_minimum_size = Vector2(40.0, 40.0)
	_detail_hold_ring.ring_color = UiPalette.ACCENT
	_detail_hold_ring.track_color = UiPalette.with_alpha(UiPalette.LINE, 0.5)
	_detail_hold_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_hold_ring.visible = false
	hold_row.add_child(_detail_hold_ring)


# --- Test seams (project convention: get_*_for_test() / set_*_for_test()) ----

func get_selected_id_for_test() -> String:
	return _selected_id


func select_for_test(id: String) -> void:
	_select(id)


func simulate_hover_for_test(id: String) -> void:
	_on_node_hovered(id)


func get_hold_progress_for_test() -> float:
	return _hold_progress


func get_node_view_for_test(id: String) -> SkillNodeView:
	return _node_views.get(id)


func get_respec_view_for_test() -> SkillNodeView:
	return _respec_view


func get_cores_label_for_test() -> Label:
	return _cores_label


func get_back_button_for_test() -> Button:
	return _back_button


func get_detail_name_label_for_test() -> Label:
	return _detail_name


func get_detail_branch_label_for_test() -> Label:
	return _detail_branch


func get_detail_effect_label_for_test() -> Label:
	return _detail_effect


func get_detail_requirements_box_for_test() -> VBoxContainer:
	return _detail_requirements_box


func get_detail_rank_label_for_test() -> Label:
	return _detail_rank


func get_detail_price_label_for_test() -> Label:
	return _detail_price


## Superseded name kept as an alias so any existing caller (tests included)
## reading "requires" text finds it under the requirements box instead --
## see `get_detail_requirements_box_for_test()`, the real seam now that
## requirements render as a list of rows rather than one summary Label.
func get_detail_requires_label_for_test() -> VBoxContainer:
	return _detail_requirements_box


func get_hold_ring_for_test() -> DraftFillRing:
	return _detail_hold_ring


func get_board_for_test() -> Control:
	return _board


func is_movement_only_armed_for_test() -> bool:
	return _movement_only_armed


func is_confirm_requires_release_for_test() -> bool:
	return _confirm_requires_release


func set_test_input_mode_for_test(enabled: bool) -> void:
	_use_test_input = enabled
	_test_pressed.clear()
	_test_just_pressed.clear()


func set_action_pressed_for_test(action: StringName, pressed: bool) -> void:
	_test_pressed[action] = pressed


func press_action_once_for_test(action: StringName) -> void:
	_test_just_pressed[action] = true
	_test_pressed[action] = true


func release_action_for_test(action: StringName) -> void:
	_test_pressed[action] = false


func tick_for_test(delta: float) -> void:
	_process(delta)


## Small custom-drawn Control that renders the prerequisite connection lines
## UNDER the SkillNodeView children `SkillTreeScreen._build_ui()` adds to it
## (a Control's own `_draw()` runs before its children's, so the lines
## always sit behind the node widgets). `set_lines()` is the only seam --
## see `SkillTreeScreen._rebuild_lines()`.
class SkillTreeBoard extends Control:
	var _lines: Array = []


	func set_lines(lines: Array) -> void:
		_lines = lines
		queue_redraw()


	func _draw() -> void:
		for line: Dictionary in _lines:
			draw_line(line["from"], line["to"], line["color"], line["width"], true)
