extends Control
class_name SelectableState

## One selection-state language for every selectable thing (PT-UI, docs/33 A1;
## docs/19 > "Selection states"; decision D320). The overlay is a mouse-transparent
## child of the selectable (a card, a picker Button, a Skill Tree node, a Settings
## row) and draws the four states over it, each with a SHAPE and a WORD so none
## depends on colour:
##   Available  plain plate, nothing drawn
##   Focused    4 px gold outline, 1.05x scale, a pointer arrow, the `ui_hover` cue
##   Selected   green check badge + a ribbon word (SELECTED / EQUIPPED / OWNED) +
##              a tinted fill; stays while focus moves away
##   Locked     hatched dark veil + padlock + a reason line; a press shakes the plate
## plus the confirming ring (hold-to-confirm, drawn on the card) and the CHOSEN
## stamp (0.35 s). The flags are independent (a focused, selected plate shows both
## cue groups) so "which one am I on" and "which one is locked in" never look alike.
## Sizes and timings: Register > "v1.0 Interface" > "Selection states".

enum State { AVAILABLE, FOCUSED, SELECTED, LOCKED }
enum RibbonSide { BOTTOM, RIGHT }

const OUTLINE_PX: float = 4.0
const FOCUS_SCALE: float = 1.05
const ARROW_PX: float = 28.0
const BADGE_PX: float = 52.0
const BADGE_PX_SMALL: float = 40.0 ## on a plate shorter than SMALL_PLATE_PX (a picker row)
const SMALL_PLATE_PX: float = 100.0
const BADGE_OVERHANG_PX: float = 12.0
const SHAKE_SECONDS: float = 0.3
const SHAKE_PX: float = 10.0
const CHOSEN_SECONDS: float = 0.35
const REASON_FLASH_SECONDS: float = 0.9
const RING_RADIUS_PX: float = 40.0
const RING_WIDTH_PX: float = 8.0
const TINT_ALPHA: float = 0.22
const VEIL_ALPHA: float = 0.5
const WORD_SELECTED: String = "SEL_SELECTED"
const WORD_EQUIPPED: String = "SEL_EQUIPPED"
const WORD_OWNED: String = "SEL_OWNED"

signal locked_pressed(reason: String)

var ribbon_side: int = RibbonSide.BOTTOM
## Where the confirming ring centres, as a fraction of the plate (a card puts it on its icon).
var ring_anchor: Vector2 = Vector2(0.5, 0.2)
var ring_radius: float = RING_RADIUS_PX
## false for a plate whose neighbours are close (an arrow outside would cover them).
var arrow_outside: bool = true
## false for a strip of tabs: the check badge and tint carry "selected" where a word would not fit.
var show_word: bool = true
## How far the check / padlock badge hangs outside the corner (0 inside a scrolling list, which would clip it).
var badge_overhang: float = BADGE_OVERHANG_PX
## How dark the locked veil is; a text-heavy plate (an achievement row) keeps it light so its words stay readable.
var veil_alpha: float = VEIL_ALPHA
## A word on the focused plate (a Draft card says what pressing confirm does); "" for none.
var focus_word: String = "":
	set(value):
		focus_word = value
		if _focus_plate != null:
			_focus_label.text = value
			_refresh()
## true when focus/hover on the TARGET should not be read (the host drives set_focused itself).
var externally_driven: bool = false

var _target: Control = null
var _focused: bool = false
var _hover: bool = false
var _selected: bool = false
var _locked: bool = false
var _word: String = ""
var _reason: String = ""
var _confirm: float = 0.0
var _chosen_left: float = 0.0
var _reason_flash_left: float = 0.0
var _last_reason_shown: String = ""
var _ribbon: PanelContainer = null
var _ribbon_label: Label = null
var _reason_plate: PanelContainer = null
var _focus_plate: PanelContainer = null
var _focus_label: Label = null
var _reason_label: Label = null
var _stamp: PanelContainer = null
var _tween: Tween = null


## Adds the overlay to `target` and wires its focus / hover signals. Idempotent.
static func attach(target: Control, side: int = RibbonSide.BOTTOM) -> SelectableState:
	var existing: SelectableState = of(target)
	if existing != null:
		existing.ribbon_side = side
		existing._layout_plates()
		return existing
	var overlay := SelectableState.new()
	overlay.name = "SelectableState"
	overlay.ribbon_side = side
	overlay._target = target
	target.add_child(overlay)
	return overlay


static func of(target: Control) -> SelectableState:
	return null if target == null else target.get_node_or_null("SelectableState") as SelectableState


## The distinguishing cues for one state, as data (tests and docs read it).
static func cues_for(state: int) -> Dictionary:
	return {
		"outline": state == State.FOCUSED,
		"arrow": state == State.FOCUSED,
		"scale": state == State.FOCUSED,
		"check": state == State.SELECTED,
		"ribbon_word": state == State.SELECTED,
		"tint": state == State.SELECTED,
		"padlock": state == State.LOCKED,
		"reason_line": state == State.LOCKED,
		"veil": state == State.LOCKED,
	}


func _init() -> void:
	UiStrings.ensure_registered()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 1
	_build_plates()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # paused menus and Drafts animate their cues
	if _target == null:
		_target = get_parent() as Control
	if _target != null:
		_target.offset_transform_enabled = true
		_target.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
		if not externally_driven:
			_target.focus_entered.connect(_on_target_focus.bind(true))
			_target.focus_exited.connect(_on_target_focus.bind(false))
			_target.mouse_entered.connect(_on_target_hover.bind(true))
			_target.mouse_exited.connect(_on_target_hover.bind(false))
		_target.resized.connect(_on_target_resized)
		_target.visibility_changed.connect(_on_target_visibility)
		_focused = _target.has_focus()
		_apply_focus_visual(false)
	item_rect_changed.connect(_on_target_resized)
	set_process(false)
	_layout_plates()


func _exit_tree() -> void:
	_kill_tween()


# --- State ---------------------------------------------------------------------------------

func set_focused(on: bool) -> void:
	_set_focus_state(on, _hover)


func set_selected(on: bool, word: String = "") -> void:
	_selected = on
	_word = word if word != "" else tr(WORD_SELECTED)
	_ribbon_label.text = _word
	_refresh()


## `reason` is the line shown while locked ("Win on Soldier"); empty keeps it hidden.
func set_locked(on: bool, reason: String = "") -> void:
	_locked = on
	_reason = reason
	_reason_label.text = reason
	_refresh()


func set_confirm_progress(progress: float) -> void:
	_confirm = clampf(progress, 0.0, 1.0)
	queue_redraw()


## The CHOSEN stamp for CHOSEN_SECONDS (a confirmed card).
func flash_chosen() -> void:
	_chosen_left = CHOSEN_SECONDS
	_stamp.visible = true
	_confirm = 0.0
	set_process(true)
	queue_redraw()


## A press on a locked plate: shake it and light the reason; never a silent ignore.
## Returns the reason shown ("" when the plate is not locked).
func press_locked() -> String:
	if not _locked:
		return ""
	_last_reason_shown = _reason
	_reason_flash_left = REASON_FLASH_SECONDS
	_reason_plate.visible = true
	_style_reason(true)
	set_process(true)
	_shake()
	locked_pressed.emit(_reason)
	return _reason


func set_show_word(on: bool) -> void:
	show_word = on
	_refresh()


func get_state() -> int:
	if _locked:
		return State.LOCKED
	if _selected:
		return State.SELECTED
	if _focused or _hover:
		return State.FOCUSED
	return State.AVAILABLE


func is_focused() -> bool:
	return _focused or _hover


func is_selected() -> bool:
	return _selected


func is_locked() -> bool:
	return _locked


func get_reason() -> String:
	return _reason


func get_last_reason_shown() -> String:
	return _last_reason_shown


func is_chosen_visible() -> bool:
	return _chosen_left > 0.0


func get_confirm_progress() -> float:
	return _confirm


## What is drawn right now (independent flags, so focus + selected shows both groups).
func visible_cues() -> Dictionary:
	var focused: bool = is_focused()
	var selected: bool = _selected and not _locked
	return {
		"outline": focused, "arrow": focused, "scale": focused,
		"focus_word": focused and focus_word != "" and not _selected and not _locked,
		"check": selected, "ribbon_word": selected and show_word, "tint": selected,
		"padlock": _locked, "reason_line": _locked and _reason != "", "veil": _locked,
		"ring": _confirm > 0.0, "chosen": _chosen_left > 0.0,
	}


func get_ribbon_label() -> Label:
	return _ribbon_label


func get_reason_label() -> Label:
	return _reason_label


func get_target_scale() -> float:
	return _target.offset_transform_scale.x if _target != null else 1.0


# --- Internals ------------------------------------------------------------------------------

func _on_target_focus(on: bool) -> void:
	_set_focus_state(on, _hover)


func _on_target_hover(on: bool) -> void:
	_set_focus_state(_focused, on)


func _on_target_resized() -> void:
	_layout_plates()
	queue_redraw()


func _on_target_visibility() -> void:
	if _target != null and not _target.is_visible_in_tree():
		_hover = false
		_focused = false
		_apply_focus_visual(false)
		queue_redraw()


func _set_focus_state(focus: bool, hover: bool) -> void:
	var was: bool = is_focused()
	_focused = focus
	_hover = hover
	if was != is_focused():
		_apply_focus_visual(true)
		if is_focused() and not _locked and not externally_driven: # a host that drives the focus (the Draft) owns its own cycle cue
			Sfx.play_ui.call_deferred("ui_hover") # deferred: the first focus lands while a scene is still being built
	_refresh()


func _refresh() -> void:
	var selected: bool = _selected and not _locked
	_ribbon.visible = selected and show_word
	_reason_plate.visible = _locked and _reason != ""
	_focus_plate.visible = is_focused() and focus_word != "" and not _selected and not _locked
	if _locked and _reason_flash_left <= 0.0:
		_style_reason(false)
	_layout_plates()
	_layout_plates.call_deferred() # a plate's minimum size settles after its text changes
	queue_redraw()


## The 1.05x lift (visual-only offset transform, so containers and tests see the real rect).
func _apply_focus_visual(animate: bool) -> void:
	if _target == null:
		return
	var goal: Vector2 = Vector2.ONE * (FOCUS_SCALE if is_focused() else 1.0)
	_kill_tween()
	if not animate or not is_inside_tree() or DisplayServer.get_name() == "headless":
		_target.offset_transform_scale = goal
		return
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_target, "offset_transform_scale", goal, UiPalette.MOTION_FAST)


func _shake() -> void:
	if _target == null:
		return
	_kill_tween()
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var step: float = SHAKE_SECONDS / 5.0
	for dx: float in [-SHAKE_PX, SHAKE_PX, -SHAKE_PX * 0.6, SHAKE_PX * 0.6, 0.0]:
		_tween.tween_property(_target, "offset_transform_position:x", dx, step)
	_tween.finished.connect(_apply_focus_visual.bind(false))


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _process(delta: float) -> void:
	var busy: bool = false
	if _chosen_left > 0.0:
		_chosen_left -= delta
		busy = true
		if _chosen_left <= 0.0:
			_stamp.visible = false
			queue_redraw()
	if _reason_flash_left > 0.0:
		_reason_flash_left -= delta
		busy = true
		if _reason_flash_left <= 0.0:
			_style_reason(false)
	set_process(busy)


func _build_plates() -> void:
	_ribbon = PanelContainer.new()
	_ribbon.name = "Ribbon"
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.visible = false
	_ribbon.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.SUCCESS, UiPalette.INK_PIXEL, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THICK, UiPalette.SPACE_XS))
	add_child(_ribbon)
	_ribbon_label = _make_plate_label(UiPalette.INK_PIXEL)
	_ribbon_label.name = "RibbonWord"
	_ribbon.add_child(_ribbon_label)

	_focus_plate = PanelContainer.new()
	_focus_plate.name = "FocusPlate"
	_focus_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_plate.visible = false
	_focus_plate.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.ACCENT, UiPalette.INK_PIXEL, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THICK, UiPalette.SPACE_XS))
	add_child(_focus_plate)
	_focus_label = _make_plate_label(UiPalette.INK_PIXEL)
	_focus_label.name = "FocusWord"
	_focus_plate.add_child(_focus_label)

	_reason_plate = PanelContainer.new()
	_reason_plate.name = "ReasonPlate"
	_reason_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reason_plate.visible = false
	add_child(_reason_plate)
	_reason_label = _make_plate_label(UiPalette.TEXT)
	_reason_label.name = "ReasonLine"
	_reason_plate.add_child(_reason_label)
	_style_reason(false)

	_stamp = PanelContainer.new()
	_stamp.name = "ChosenStamp"
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.visible = false
	_stamp.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.ACCENT, UiPalette.INK_PIXEL, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THICK, UiPalette.SPACE_S))
	add_child(_stamp)
	var stamp_label: Label = _make_plate_label(UiPalette.INK_PIXEL)
	stamp_label.name = "ChosenWord"
	stamp_label.text = tr("SEL_CHOSEN")
	stamp_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_HEADING)
	_stamp.add_child(stamp_label)
	_stamp.rotation = deg_to_rad(-8.0)


func _make_plate_label(color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	return label


func _style_reason(flash: bool) -> void:
	var border: Color = UiPalette.ACCENT if flash else UiPalette.TEXT_DISABLED
	_reason_plate.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.INK, border, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THICK, UiPalette.SPACE_XS))
	_reason_label.add_theme_color_override("font_color", UiPalette.ACCENT if flash else UiPalette.TEXT)


## The plate the cues are drawn around: the target's whole rect, even when the target is a
## container that has inset this overlay by its content margins (a Draft card's frame).
func _rect() -> Rect2:
	if _target == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(-position, _target.size)


## Places the word plates by hand (a container host would otherwise stretch them): along the
## bottom edge (cards, tiles) or on the right (wide buttons); the CHOSEN stamp at the centre.
func _layout_plates() -> void:
	if _ribbon == null or _target == null:
		return
	var r: Rect2 = _rect()
	for plate: Control in [_ribbon, _reason_plate, _focus_plate]:
		var s: Vector2 = plate.get_combined_minimum_size()
		plate.size = s
		if ribbon_side == RibbonSide.RIGHT:
			plate.position = Vector2(r.end.x - s.x - float(UiPalette.SPACE_S) - _badge_side(r) * 0.5, r.position.y + (r.size.y - s.y) * 0.5)
		else:
			plate.position = Vector2(r.position.x + (r.size.x - s.x) * 0.5, r.end.y - s.y + float(UiPalette.SPACE_S))
	var ss: Vector2 = _stamp.get_combined_minimum_size()
	_stamp.size = ss
	_stamp.pivot_offset = ss * 0.5
	_stamp.position = r.get_center() - ss * 0.5


func _draw() -> void:
	var rect: Rect2 = _rect()
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var cues: Dictionary = visible_cues()
	if cues["tint"]:
		draw_rect(rect, UiPalette.with_alpha(UiPalette.SUCCESS, TINT_ALPHA), true)
	if cues["veil"]:
		_draw_veil(rect)
	if cues["outline"]:
		SelectableState.draw_focus_cue(self, rect, arrow_outside)
	if cues["check"]:
		_draw_check_badge(rect)
	if cues["padlock"]:
		_draw_padlock(rect)
	if cues["ring"]:
		_draw_ring(rect)


## Dark veil plus diagonal hatching: reads as "closed" with colour removed.
func _draw_veil(rect: Rect2) -> void:
	draw_rect(rect, UiPalette.with_alpha(UiPalette.INK, veil_alpha), true)
	var hatch: Color = UiPalette.with_alpha(UiPalette.TEXT_DISABLED, 0.35)
	var step: float = 24.0
	var x: float = -rect.size.y
	while x < rect.size.x:
		var x0: float = maxf(x, 0.0)
		var x1: float = minf(x + rect.size.y, rect.size.x)
		if x1 - x0 > 1.0:
			draw_line(rect.position + Vector2(x0, rect.size.y - (x0 - x)), rect.position + Vector2(x1, rect.size.y - (x1 - x)), hatch, 3.0)
		x += step


## The focus cue itself, shared with the surfaces that are not a plain Control (the Settings rows, the
## paused choice bar): a 4 px gold outline with an ink rim, and a pointer arrow on the left edge
## (outside the plate, so it never covers content; `arrow_outside` false draws it just inside).
static func draw_focus_cue(canvas: CanvasItem, rect: Rect2, arrow_outside: bool = true) -> void:
	canvas.draw_rect(rect.grow(1.0), UiPalette.INK_PIXEL, false, 2.0)
	canvas.draw_rect(rect.grow(-OUTLINE_PX * 0.5), UiPalette.ACCENT, false, OUTLINE_PX)
	var cy: float = rect.position.y + rect.size.y * 0.5
	var tip_x: float = rect.position.x - 2.0
	var base_x: float = tip_x - ARROW_PX
	if not arrow_outside:
		base_x = rect.position.x + OUTLINE_PX + 2.0
		tip_x = base_x + ARROW_PX
	var pts := PackedVector2Array([Vector2(base_x, cy - ARROW_PX * 0.6), Vector2(tip_x, cy), Vector2(base_x, cy + ARROW_PX * 0.6)])
	canvas.draw_colored_polygon(pts, UiPalette.ACCENT)
	canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), UiPalette.INK_PIXEL, 3.0)


func _badge_side(rect: Rect2) -> float:
	return BADGE_PX_SMALL if rect.size.y < SMALL_PLATE_PX else BADGE_PX


func _badge_rect(rect: Rect2) -> Rect2:
	var side: float = _badge_side(rect)
	return Rect2(rect.end.x - side + badge_overhang, rect.position.y - badge_overhang, side, side)


func _draw_check_badge(rect: Rect2) -> void:
	var b: Rect2 = _badge_rect(rect)
	draw_rect(b.grow(3.0), UiPalette.INK_PIXEL, true)
	draw_rect(b, UiPalette.SUCCESS, true)
	var pts := PackedVector2Array([
		b.position + b.size * Vector2(0.22, 0.52), b.position + b.size * Vector2(0.42, 0.72), b.position + b.size * Vector2(0.80, 0.28)])
	draw_polyline(pts, UiPalette.INK_PIXEL, 9.0)


func _draw_padlock(rect: Rect2) -> void:
	var b: Rect2 = _badge_rect(rect)
	draw_rect(b.grow(3.0), UiPalette.INK_PIXEL, true)
	draw_rect(b, UiPalette.TEXT_DISABLED, true)
	var body := Rect2(b.position + b.size * Vector2(0.24, 0.46), b.size * Vector2(0.52, 0.38))
	var shackle_c: Vector2 = b.position + b.size * Vector2(0.5, 0.42)
	draw_arc(shackle_c, b.size.x * 0.17, PI, TAU, 12, UiPalette.INK_PIXEL, 5.0)
	draw_rect(body, UiPalette.TEXT, true)
	draw_rect(body, UiPalette.INK_PIXEL, false, 2.0)
	draw_rect(Rect2(body.get_center() - Vector2(2.0, 4.0), Vector2(4.0, 8.0)), UiPalette.INK_PIXEL, true)


func _draw_ring(rect: Rect2) -> void:
	var c: Vector2 = rect.position + rect.size * ring_anchor
	var width: float = minf(RING_WIDTH_PX, ring_radius * 0.3)
	draw_circle(c, ring_radius + 4.0, UiPalette.with_alpha(UiPalette.INK_PIXEL, 0.75))
	draw_arc(c, ring_radius, 0.0, TAU, 32, UiPalette.with_alpha(UiPalette.TEXT_DISABLED, 0.8), width)
	draw_arc(c, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * _confirm, 48, UiPalette.ACCENT, width)
