extends Control
class_name SelectableState

## One selection-state language for every selectable thing (PT-UI, docs/33 A1; docs/19 >
## "Selection states"; decisions D320, redone by D380-D389 after the author's feedback "the
## selection thing u implemented is wrong in both windows n android", then "for the selected
## options remove the word 'selected'", "just show the tick .. and also remove the yellow
## rectangle border", "the yellow triangle arrow to indicate what to press is okay tho"). The
## overlay is a mouse-transparent child of the selectable (a card, a picker Button, a tab, a Skill
## Tree node, a Settings row) and draws its state INSIDE the plate, never over the label:
##   Available  the plain plate
##   Hover      (a real mouse only) the plate brightened; the focus moves to the plate, so hover and
##              keyboard focus can never mark two plates at once
##   Focused    the yellow pointer arrow ("this is what to press"), drawn beside the plate on
##              whichever side has room (never clipped by the screen or a scroll area, never over a
##              neighbour; inside the plate when there is no room), plus a subtle brighten while the
##              last input was keyboard / gamepad. No outline, no scale
##   Selected   ONLY a tick badge inside the plate (right edge of a row, top-right of a tile). No
##              word, no border, no tint; the label stays dark ink
##   Tab        the active tab is brightened, the others darkened: no tick, no word
##   Locked     the host greys the plate; the overlay adds a padlock inside it and the reason as
##              plain text beside it (a row) or on the bottom line (a tile). A press shakes the
##              plate and flashes the reason
##   Armed      the Draft / event card that confirm will pick: the arrow, a brighter card (the
##              others dimmed) and a prompt plate inside the card's bottom edge naming the live
##              device. On touch no card is armed until a finger is on it
## plus the press feedback (a quick scale-down and flash), the confirming ring (hold-to-confirm,
## drawn on the card) and the CHOSEN stamp (0.35 s). Shape and an icon carry every state, so none
## depends on colour. Sizes and timings: Register > "v1.0 Interface" > "Selection states".

enum State { AVAILABLE, FOCUSED, SELECTED, LOCKED }
## ROW: a wide button (picker, menu button): badge at the right edge, reason beside it.
## TILE: a card-like plate (relic, Skill Tree node, Field Guide tile): badge in the top-right
## corner, reason on the bottom line. TAB: a page selector (see above).
enum Layout { ROW, TILE, TAB }
enum ArrowSide { LEFT, RIGHT, INSIDE }

const ARROW_PX: float = 28.0
const ARROW_GAP_PX: float = 2.0
const BADGE_MARGIN_PX: float = 10.0
const BADGE_PX_MAX: float = 48.0
const BADGE_PX_MIN: float = 28.0
const PRESS_SCALE: float = 0.95
const HOVER_ALPHA: float = 0.14
const FOCUS_ALPHA: float = 0.14
const PRESS_ALPHA: float = 0.22
const ARMED_ALPHA: float = 0.20
const DIM_ALPHA: float = 0.22
const TAB_RAISE_ALPHA: float = 0.16
const TAB_DIM_ALPHA: float = 0.30
const SHAKE_SECONDS: float = 0.3
const SHAKE_PX: float = 10.0
const CHOSEN_SECONDS: float = 0.35
const REASON_FLASH_SECONDS: float = 0.9
const RING_RADIUS_PX: float = 40.0
const RING_WIDTH_PX: float = 8.0
const PROMPT_MARGIN_PX: float = 14.0
const PROMPT_KEYBOARD: String = "SEL_PROMPT_KEYBOARD"
const PROMPT_MOUSE: String = "SEL_PROMPT_MOUSE"

signal locked_pressed(reason: String)

var layout: int = Layout.ROW
## Where the confirming ring centres, as a fraction of the plate (a card puts it on its icon).
var ring_anchor: Vector2 = Vector2(0.5, 0.2)
var ring_radius: float = RING_RADIUS_PX
## false for a read-only row (an achievement): it shows selected / locked but never hover, focus or press.
var interactive: bool = true
## true when the host drives the cursor itself (a Draft card, the Skill Tree, the explainer buttons):
## the overlay does not read the target's focus / mouse signals.
var externally_driven: bool = false
## Colour of the reason text; a dark plate (a Skill Tree node) sets a light one.
var note_color: Color = UiPalette.TEXT_ON_PARCHMENT:
	set(value):
		note_color = value
		if _reason_label != null:
			_reason_label.add_theme_color_override("font_color", value)
var note_outline: int = 0:
	set(value):
		note_outline = value
		if _reason_label != null:
			_reason_label.add_theme_constant_override("outline_size", value)
## A Draft card is "armed" while it is the one confirm would pick.
var prompt_enabled: bool = true
## The tick / padlock badge: 0 = sized from the plate; a tile whose corner holds text puts it lower.
var badge_px: float = 0.0
var badge_y_fraction: float = -1.0 ## -1 = top-right corner (a tile) or centred (a row); else the badge centre at this fraction of the height

var _target: Control = null
var _focused: bool = false
var _hover: bool = false
var _pressed: bool = false
var _selected: bool = false
var _locked: bool = false
var _armed: bool = false
var _dimmed: bool = false
var _reason: String = ""
var _confirm: float = 0.0
var _chosen_left: float = 0.0
var _reason_flash_left: float = 0.0
var _last_reason_shown: String = ""
var _reason_label: Label = null
var _prompt_plate: PanelContainer = null
var _prompt_label: Label = null
var _stamp: PanelContainer = null
var _tween: Tween = null
var _scale_goal: float = 1.0


## Adds the overlay to `target` and wires its focus / hover / press signals. Idempotent.
static func attach(target: Control, layout_kind: int = Layout.ROW) -> SelectableState:
	var existing: SelectableState = of(target)
	if existing != null:
		existing.layout = layout_kind
		existing._layout_plates()
		return existing
	var overlay := SelectableState.new()
	overlay.name = "SelectableState"
	overlay.layout = layout_kind
	overlay._target = target
	target.add_child(overlay)
	return overlay


static func of(target: Control) -> SelectableState:
	return null if target == null else target.get_node_or_null("SelectableState") as SelectableState


## The distinguishing cues for one state, as data (tests and docs read it). Selected is a tick
## (or, on a tab, the raised face), locked a padlock and a reason, focused the arrow, so no state
## depends on colour and none draws a word or a border.
static func cues_for(state: int, layout_kind: int = Layout.ROW) -> Dictionary:
	var selected: bool = state == State.SELECTED
	return {
		"arrow": state == State.FOCUSED,
		"check": selected and layout_kind != Layout.TAB,
		"tab_raise": selected and layout_kind == Layout.TAB,
		"padlock": state == State.LOCKED,
		"reason_line": state == State.LOCKED,
	}


func _init() -> void:
	UiStrings.ensure_registered()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 1
	_build_plates()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # paused menus and Drafts animate their cues
	UiInputMode.ensure_listening()
	UiInputMode.watch(_on_input_mode_changed)
	if _target == null:
		_target = get_parent() as Control
	if _target != null:
		_target.offset_transform_enabled = true
		_target.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
		if _target is BaseButton:
			# The overlay owns the focus cue: the theme's own focus box would draw a second one.
			_target.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if interactive and not externally_driven:
			_target.focus_entered.connect(_on_target_focus.bind(true))
			_target.focus_exited.connect(_on_target_focus.bind(false))
			_target.mouse_entered.connect(_on_target_hover.bind(true))
			_target.mouse_exited.connect(_on_target_hover.bind(false))
			if _target is BaseButton:
				(_target as BaseButton).button_down.connect(set_pressed.bind(true))
				(_target as BaseButton).button_up.connect(set_pressed.bind(false))
		_target.resized.connect(_on_target_resized)
		_target.visibility_changed.connect(_on_target_visibility)
		_focused = interactive and not externally_driven and _target.has_focus()
	item_rect_changed.connect(_on_target_resized)
	set_process(false)
	_layout_plates()


func _exit_tree() -> void:
	_kill_tween()
	UiInputMode.unwatch(_on_input_mode_changed)


# --- State ---------------------------------------------------------------------------------

## The host's cursor (keyboard focus, the mouse's hover focus, or the Skill Tree's inspected node)
## is on this plate.
func set_focused(on: bool) -> void:
	_focused = on
	if on and not _locked and not externally_driven and interactive and UiInputMode.is_keyboard():
		Sfx.play_ui.call_deferred("ui_hover") # deferred: the first focus lands while a scene is still being built
	_refresh()


## Selected: the tick badge. (No word: the author asked for the tick alone.)
func set_selected(on: bool) -> void:
	_selected = on
	_refresh()


## `reason` is the line shown while locked ("Win on Soldier"); empty keeps it hidden.
func set_locked(on: bool, reason: String = "") -> void:
	_locked = on
	_reason = reason
	_reason_label.text = reason
	_refresh()


## A Draft card the confirm will pick: the arrow, a brighter card and the prompt plate.
func set_armed(on: bool) -> void:
	_armed = on
	_refresh()


## A Draft card that is NOT the armed one while another is: darkened so the armed one stands out.
func set_dimmed(on: bool) -> void:
	_dimmed = on
	queue_redraw()


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


## The press feedback: a quick scale-down and flash while a finger / button is held on the plate.
func set_pressed(on: bool) -> void:
	if _pressed == on:
		return
	_pressed = on
	_tween_scale(PRESS_SCALE if on else 1.0)
	_refresh()


## A press on a locked plate: shake it and light the reason; never a silent ignore.
## Returns the reason shown ("" when the plate is not locked).
func press_locked() -> String:
	if not _locked:
		return ""
	_last_reason_shown = _reason
	_reason_flash_left = REASON_FLASH_SECONDS
	_style_reason(true)
	set_process(true)
	_shake()
	locked_pressed.emit(_reason)
	return _reason


func set_layout(kind: int) -> void:
	layout = kind
	_refresh()


func get_state() -> int:
	if _locked:
		return State.LOCKED
	if _selected:
		return State.SELECTED
	if is_arrow_visible() or is_hover_visible():
		return State.FOCUSED
	return State.AVAILABLE


## The yellow arrow shows on the plate that holds the host's cursor (keyboard focus, the mouse's
## hover focus, the Skill Tree's inspected node) and on the armed Draft card.
func is_arrow_visible() -> bool:
	if _locked and not _focused:
		return false
	if _armed and not _locked and (not UiInputMode.is_touch() or _pressed):
		return true
	return _focused and (interactive or externally_driven)


func is_hover_visible() -> bool:
	return _hover and interactive and not externally_driven and UiInputMode.is_mouse()


func is_focused() -> bool:
	return _focused


func is_selected() -> bool:
	return _selected


func is_locked() -> bool:
	return _locked


func is_armed() -> bool:
	return _armed


func is_pressed() -> bool:
	return _pressed


func get_reason() -> String:
	return _reason


func get_last_reason_shown() -> String:
	return _last_reason_shown


func is_chosen_visible() -> bool:
	return _chosen_left > 0.0


func get_confirm_progress() -> float:
	return _confirm


## What is drawn right now (independent flags, so a focused, selected plate shows both groups).
func visible_cues() -> Dictionary:
	var selected: bool = _selected and not _locked
	var tab: bool = layout == Layout.TAB
	var armed: bool = _armed and not _locked and (not UiInputMode.is_touch() or _pressed)
	return {
		"arrow": is_arrow_visible(),
		"focus_wash": _focused and UiInputMode.is_keyboard() and interactive and not externally_driven,
		"hover": is_hover_visible() and not _pressed,
		"pressed": _pressed,
		"check": selected and not tab,
		"tab_raise": selected and tab,
		"tab_dim": tab and not selected,
		"padlock": _locked,
		"reason_line": _locked and _reason != "",
		"armed": armed,
		"dim": _dimmed and not armed,
		"prompt": armed and prompt_enabled and not UiInputMode.is_touch(),
		"ring": _confirm > 0.0,
		"chosen": _chosen_left > 0.0,
	}


func get_reason_label() -> Label:
	return _reason_label


func get_prompt_label() -> Label:
	return _prompt_label


func get_target_scale() -> float:
	return _target.offset_transform_scale.x if _target != null else 1.0


## The word on an armed Draft card for the live device.
func prompt_text() -> String:
	return tr(PROMPT_MOUSE) if UiInputMode.is_mouse() else tr(PROMPT_KEYBOARD)


## Which side of the plate the arrow goes: the left (pointing right) when there is room, else the
## right (pointing left), else inside the plate's left padding. Room means: inside the viewport
## and every scroll area that would clip it, and not over a sibling plate.
func arrow_side() -> int:
	if _target == null:
		return ArrowSide.LEFT
	return SelectableState.pick_arrow_side(self, _rect(), _siblings())


## The arrow's side for a plate `local_rect` (in `canvas`'s local space), given the plates beside
## it. Static so the paused choice bars (not a plain Control) share it.
static func pick_arrow_side(canvas: Control, local_rect: Rect2, siblings: Array[Control]) -> int:
	var to_global: Transform2D = canvas.get_global_transform()
	var clip: Rect2 = canvas.get_viewport_rect()
	var node: Node = canvas.get_parent()
	while node != null:
		if node is ScrollContainer:
			clip = clip.intersection((node as ScrollContainer).get_global_rect())
		node = node.get_parent()
	var cy: float = local_rect.position.y + local_rect.size.y * 0.5
	var left_rect := Rect2(local_rect.position.x - ARROW_GAP_PX - ARROW_PX, cy - ARROW_PX * 0.6, ARROW_PX, ARROW_PX * 1.2)
	var right_rect := Rect2(local_rect.end.x + ARROW_GAP_PX, cy - ARROW_PX * 0.6, ARROW_PX, ARROW_PX * 1.2)
	for pair: Array in [[ArrowSide.LEFT, left_rect], [ArrowSide.RIGHT, right_rect]]:
		var r: Rect2 = pair[1]
		var g := Rect2(to_global * r.position, r.size)
		if not clip.encloses(g):
			continue
		var blocked: bool = false
		for sib: Control in siblings:
			if is_instance_valid(sib) and sib.is_visible_in_tree() and sib.get_global_rect().intersects(g):
				blocked = true
				break
		if not blocked:
			return pair[0]
	return ArrowSide.INSIDE


# --- Internals ------------------------------------------------------------------------------

func _siblings() -> Array[Control]:
	var out: Array[Control] = []
	var parent: Node = _target.get_parent()
	if parent == null:
		return out
	for ch: Node in parent.get_children():
		if ch is Control and ch != _target and not (ch is SelectableState):
			out.append(ch as Control)
	return out


func _on_input_mode_changed(mode: int) -> void:
	# A resting mouse that was already over this plate when the menu opened fired no `mouse_entered`
	# after the first real move, so the focus never followed: take it now.
	if mode == UiInputMode.Mode.MOUSE and _hover:
		_take_focus_for_hover()
	_refresh()


func _take_focus_for_hover() -> void:
	if interactive and not externally_driven and _target != null and _target.focus_mode != Control.FOCUS_NONE and not _target.has_focus() and _target.is_visible_in_tree():
		_target.grab_focus() # hover and keyboard focus never mark two plates: the mouse takes the focus along


func _on_target_focus(on: bool) -> void:
	set_focused(on)


func _on_target_hover(on: bool) -> void:
	if on == _hover:
		return
	_hover = on
	if on and UiInputMode.is_mouse() and not _locked:
		Sfx.play_ui.call_deferred("ui_hover")
	if on and UiInputMode.is_mouse():
		_take_focus_for_hover()
	_refresh()


func _on_target_resized() -> void:
	_layout_plates()
	queue_redraw()


func _on_target_visibility() -> void:
	if _target != null and not _target.is_visible_in_tree():
		_hover = false
		_pressed = false
		_focused = false
		_scale_goal = 1.0
		_target.offset_transform_scale = Vector2.ONE
		queue_redraw()


func _refresh() -> void:
	var cues: Dictionary = visible_cues()
	_reason_label.visible = cues["reason_line"]
	_prompt_plate.visible = cues["prompt"]
	if _prompt_label != null and cues["prompt"]:
		_prompt_label.text = prompt_text()
	if _locked and _reason_flash_left <= 0.0:
		_style_reason(false)
	_layout_plates()
	_layout_plates.call_deferred() # a plate's minimum size settles after its text changes
	queue_redraw()


func _tween_scale(goal: float) -> void:
	if _target == null:
		return
	_scale_goal = goal
	_kill_tween()
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		_target.offset_transform_scale = Vector2.ONE * goal
		return
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_target, "offset_transform_scale", Vector2.ONE * goal, UiPalette.MOTION_FAST)


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
	_tween.finished.connect(_tween_scale.bind(PRESS_SCALE if _pressed else 1.0))


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
	_reason_label = _make_note_label()
	_reason_label.name = "ReasonLine"
	add_child(_reason_label)
	_style_reason(false)

	_prompt_plate = PanelContainer.new()
	_prompt_plate.name = "PromptPlate"
	_prompt_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_plate.visible = false
	_prompt_plate.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.ACCENT, UiPalette.INK_PIXEL, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THICK, UiPalette.SPACE_XS))
	add_child(_prompt_plate)
	_prompt_label = _make_note_label()
	_prompt_label.name = "PromptWord"
	_prompt_label.add_theme_color_override("font_color", UiPalette.INK_PIXEL)
	_prompt_label.add_theme_constant_override("outline_size", 0)
	_prompt_label.visible = true # the plate carries the visibility
	_prompt_plate.add_child(_prompt_label)

	_stamp = PanelContainer.new()
	_stamp.name = "ChosenStamp"
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.visible = false
	_stamp.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.ACCENT, UiPalette.INK_PIXEL, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THICK, UiPalette.SPACE_S))
	add_child(_stamp)
	var stamp_label: Label = _make_note_label()
	stamp_label.name = "ChosenWord"
	stamp_label.text = tr("SEL_CHOSEN")
	stamp_label.add_theme_color_override("font_color", UiPalette.INK_PIXEL)
	stamp_label.add_theme_constant_override("outline_size", 0)
	stamp_label.visible = true
	stamp_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_HEADING)
	_stamp.add_child(stamp_label)
	_stamp.rotation = deg_to_rad(-8.0)


func _make_note_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	label.add_theme_color_override("font_color", note_color)
	label.add_theme_color_override("font_outline_color", UiPalette.TEXT_OUTLINE)
	label.add_theme_constant_override("outline_size", note_outline)
	return label


## The reason is plain text on the plate; pressing a locked plate flashes it on a gold chip.
func _style_reason(flash: bool) -> void:
	if flash:
		_reason_label.add_theme_stylebox_override("normal", UiTheme.make_box(UiPalette.ACCENT, UiPalette.INK_PIXEL, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THIN, UiPalette.SPACE_XS))
		_reason_label.add_theme_color_override("font_color", UiPalette.INK_PIXEL)
		_reason_label.add_theme_constant_override("outline_size", 0)
	else:
		_reason_label.remove_theme_stylebox_override("normal")
		_reason_label.add_theme_color_override("font_color", note_color)
		_reason_label.add_theme_constant_override("outline_size", note_outline)


## The plate the cues are drawn on: the target's whole rect, even when the target is a
## container that has inset this overlay by its content margins (a Draft card's frame).
func _rect() -> Rect2:
	if _target == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(-position, _target.size)


func _badge_side(rect: Rect2) -> float:
	if badge_px > 0.0:
		return badge_px
	return clampf(rect.size.y * 0.5, BADGE_PX_MIN, BADGE_PX_MAX)


## The tick / padlock badge, INSIDE the plate: right edge, centred (a row) or top-right corner.
func _badge_rect(rect: Rect2) -> Rect2:
	var side: float = _badge_side(rect)
	var x: float = rect.end.x - side - BADGE_MARGIN_PX
	var y: float = rect.position.y + (rect.size.y - side) * 0.5 if layout == Layout.ROW else rect.position.y + BADGE_MARGIN_PX
	if badge_y_fraction >= 0.0:
		y = rect.position.y + rect.size.y * badge_y_fraction - side * 0.5
	return Rect2(x, y, side, side)


## Places the text plates by hand (a container host would otherwise stretch them).
func _layout_plates() -> void:
	if _reason_label == null or _target == null:
		return
	var r: Rect2 = _rect()
	var badge: Rect2 = _badge_rect(r)
	var s: Vector2 = _reason_label.get_combined_minimum_size()
	_reason_label.size = s
	if layout == Layout.ROW:
		_reason_label.position = Vector2(badge.position.x - BADGE_MARGIN_PX - s.x, r.position.y + (r.size.y - s.y) * 0.5)
	else:
		_reason_label.position = Vector2(r.position.x + (r.size.x - s.x) * 0.5, r.end.y - s.y - 8.0)
	var ps: Vector2 = _prompt_plate.get_combined_minimum_size()
	_prompt_plate.size = ps
	_prompt_plate.position = Vector2(r.position.x + (r.size.x - ps.x) * 0.5, r.end.y - ps.y - PROMPT_MARGIN_PX)
	var ss: Vector2 = _stamp.get_combined_minimum_size()
	_stamp.size = ss
	_stamp.pivot_offset = ss * 0.5
	_stamp.position = r.get_center() - ss * 0.5


func _draw() -> void:
	var rect: Rect2 = _rect()
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var cues: Dictionary = visible_cues()
	var face: Rect2 = rect.grow(-3.0)
	if cues["tab_dim"]:
		draw_rect(rect, UiPalette.with_alpha(UiPalette.INK, TAB_DIM_ALPHA), true)
	if cues["dim"]:
		draw_rect(rect, UiPalette.with_alpha(UiPalette.INK, DIM_ALPHA), true)
	if cues["tab_raise"]:
		draw_rect(face, UiPalette.with_alpha(Color.WHITE, TAB_RAISE_ALPHA), true)
	if cues["armed"]:
		draw_rect(face, UiPalette.with_alpha(Color.WHITE, ARMED_ALPHA), true)
	if cues["focus_wash"]:
		draw_rect(face, UiPalette.with_alpha(Color.WHITE, FOCUS_ALPHA), true)
	if cues["hover"] and not _target is BaseButton: # a Button's own hover face is already the brighter plate
		draw_rect(face, UiPalette.with_alpha(Color.WHITE, HOVER_ALPHA), true)
	if cues["check"]:
		_draw_check(_badge_rect(rect))
	if cues["padlock"]:
		_draw_padlock(_badge_rect(rect))
	if cues["pressed"]:
		draw_rect(face, UiPalette.with_alpha(Color.WHITE, PRESS_ALPHA), true)
	if cues["arrow"]:
		SelectableState.draw_arrow(self, rect, arrow_side())
	if cues["ring"]:
		_draw_ring(rect)


## The yellow pointer arrow ("this is what to press"): a 28 px triangle with an ink rim, pointing
## at `rect` from its left or right edge, or drawn just inside the left edge when neither side has
## room. Shared with the surfaces that are not a plain Control (the paused choice bars).
static func draw_arrow(canvas: CanvasItem, rect: Rect2, side: int) -> void:
	var cy: float = rect.position.y + rect.size.y * 0.5
	var half: float = ARROW_PX * 0.6
	var pts: PackedVector2Array
	match side:
		ArrowSide.RIGHT:
			var tip_x: float = rect.end.x + ARROW_GAP_PX
			pts = PackedVector2Array([Vector2(tip_x + ARROW_PX, cy - half), Vector2(tip_x, cy), Vector2(tip_x + ARROW_PX, cy + half)])
		ArrowSide.INSIDE:
			var base_x: float = rect.position.x + 4.0
			pts = PackedVector2Array([Vector2(base_x, cy - half), Vector2(base_x + ARROW_PX, cy), Vector2(base_x, cy + half)])
		_:
			var tip_left: float = rect.position.x - ARROW_GAP_PX
			pts = PackedVector2Array([Vector2(tip_left - ARROW_PX, cy - half), Vector2(tip_left, cy), Vector2(tip_left - ARROW_PX, cy + half)])
	canvas.draw_colored_polygon(pts, UiPalette.ACCENT)
	canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), UiPalette.INK_PIXEL, 3.0)


func _draw_check(b: Rect2) -> void:
	draw_rect(b.grow(2.0), UiPalette.INK_PIXEL, true)
	draw_rect(b, UiPalette.SUCCESS, true)
	var pts := PackedVector2Array([
		b.position + b.size * Vector2(0.22, 0.52), b.position + b.size * Vector2(0.42, 0.72), b.position + b.size * Vector2(0.80, 0.28)])
	draw_polyline(pts, UiPalette.INK_PIXEL, maxf(4.0, b.size.x * 0.17))


func _draw_padlock(b: Rect2) -> void:
	draw_rect(b.grow(2.0), UiPalette.INK_PIXEL, true)
	draw_rect(b, UiPalette.TEXT_DIM, true)
	var body := Rect2(b.position + b.size * Vector2(0.24, 0.46), b.size * Vector2(0.52, 0.38))
	var shackle_c: Vector2 = b.position + b.size * Vector2(0.5, 0.42)
	draw_arc(shackle_c, b.size.x * 0.17, PI, TAU, 12, UiPalette.INK_PIXEL, maxf(3.0, b.size.x * 0.1))
	draw_rect(body, UiPalette.INK_PIXEL, true)
	draw_rect(Rect2(body.get_center() - Vector2(2.0, 4.0), Vector2(4.0, 8.0)), UiPalette.TEXT_DIM, true)


func _draw_ring(rect: Rect2) -> void:
	var c: Vector2 = rect.position + rect.size * ring_anchor
	var width: float = minf(RING_WIDTH_PX, ring_radius * 0.3)
	draw_circle(c, ring_radius + 4.0, UiPalette.with_alpha(UiPalette.INK_PIXEL, 0.75))
	draw_arc(c, ring_radius, 0.0, TAU, 32, UiPalette.with_alpha(UiPalette.TEXT_DISABLED, 0.8), width)
	draw_arc(c, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * _confirm, 48, UiPalette.ACCENT, width)
