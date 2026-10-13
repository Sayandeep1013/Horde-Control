class_name HudActionButton
extends Control

## The Dash and Battle Skill buttons (docs/31 §8.1, bottom-right action
## cluster). One class, two uses: on the HUD it is a read-only display (key
## hint from the live Input Map, radial cooldown sweep, charge pips); in
## `TouchControls` the same node is `interactive` and presses/releases the
## `dash` / `battle_skill` action, so a phone has real buttons that show the
## same cooldown. Sizes: Register > v1.0 Interface > "HUD action cluster".
##
## State comes from nodes the combat package builds, found defensively by
## group, so the button renders a sensible empty state until they exist:
##   group "player"        get_dash_state() -> {charges, max_charges, cooldown_remaining, cooldown_total}
##   group "battle_skill"  get_state()      -> {skill_id, cooldown_remaining, cooldown_total, ready}

enum Kind { DASH, SKILL }

const DASH_SIZE_PX: float = 72.0
const SKILL_SIZE_PX: float = 96.0
const DASH_ICON_PATH: String = "res://assets/ui/icons/icon_dash.png"
const CHARGE_PIP_PX: float = 16.0 ## Register > v1.0 Interface > "HUD polish": at least 10 px at 100% HUD scale
## The key hint sits in a strip under the icon, so it never covers the art.
const HINT_STRIP_PX: float = 34.0
const HINT_GAP_PX: float = 4.0

var kind: int = Kind.DASH
var interactive: bool = false
var charges: int = 1
var max_charges: int = 1
var cooldown_remaining: float = 0.0
var cooldown_total: float = 0.0
var skill_id: String = ""
var skill_ready: bool = true

var _icon_side: float = DASH_SIZE_PX
var _held: bool = false
var _was_ready: bool = true
var _drawn_key: String = ""


func _init(button_kind: int = Kind.DASH) -> void:
	kind = button_kind
	_icon_side = SKILL_SIZE_PX if kind == Kind.SKILL else DASH_SIZE_PX
	custom_minimum_size = Vector2(_icon_side, _icon_side + HINT_GAP_PX + HINT_STRIP_PX)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skill_id = RunConfig.battle_skill_id if kind == Kind.SKILL else ""


func get_action() -> StringName:
	return &"dash" if kind == Kind.DASH else &"battle_skill"


## Makes this a real button (touch layout). `side` overrides the HUD size.
func make_interactive(side: float) -> void:
	interactive = true
	_icon_side = side
	custom_minimum_size = Vector2(side, side) # no hint strip: a phone has no key to name
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_state(new_charges: int, new_max: int, remaining: float, total: float) -> void:
	charges = new_charges
	max_charges = maxi(1, new_max)
	cooldown_remaining = maxf(0.0, remaining)
	cooldown_total = maxf(0.0, total)
	queue_redraw()


func set_skill_state(id: String, remaining: float, total: float, is_ready: bool) -> void:
	if id != "":
		skill_id = id
	cooldown_remaining = maxf(0.0, remaining)
	cooldown_total = maxf(0.0, total)
	_was_ready = is_ready # no "skill ready" chime (author, 2026-10-13: off-theme)
	skill_ready = is_ready
	queue_redraw()


func _process(_delta: float) -> void:
	_pull_sources()
	var key: String = InputHints.key_text(get_action())
	if key != _drawn_key:
		_drawn_key = key
		queue_redraw()
	if cooldown_remaining > 0.0:
		queue_redraw()


func _pull_sources() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if kind == Kind.DASH:
		var player: Node = tree.get_first_node_in_group("player")
		if player != null and player.has_method("get_dash_state"):
			var s: Dictionary = player.get_dash_state()
			set_state(int(s.get("charges", 1)), int(s.get("max_charges", 1)), float(s.get("cooldown_remaining", 0.0)), float(s.get("cooldown_total", 0.0)))
	else:
		var node: Node = tree.get_first_node_in_group("battle_skill")
		if node != null and node.has_method("get_state"):
			var s2: Dictionary = node.get_state()
			set_skill_state(String(s2.get("skill_id", skill_id)), float(s2.get("cooldown_remaining", 0.0)), float(s2.get("cooldown_total", 0.0)), bool(s2.get("ready", true)))


func _is_ready() -> bool:
	if kind == Kind.DASH:
		return charges > 0
	return skill_ready


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, Vector2(_icon_side, _icon_side))
	var is_up: bool = _is_ready()
	draw_rect(box, UiPalette.INK_PIXEL, true)
	var inner := box.grow(-2.0)
	draw_rect(inner, UiPalette.with_alpha(UiPalette.INK, 0.92), true)
	var icon_rect := inner.grow(-2.0)
	if kind == Kind.DASH:
		HudGlyphs.draw_icon_or(self, DASH_ICON_PATH, icon_rect, func(r: Rect2) -> void: HudGlyphs.draw_dash(self, r, UiPalette.SHIELD))
	else:
		var sid: String = skill_id if skill_id != "" else RunConfig.battle_skill_id
		HudGlyphs.draw_icon_or(self, AbilityIds.icon_path(sid), icon_rect, func(r: Rect2) -> void: HudGlyphs.draw_monogram(self, r, sid, UiPalette.ACCENT))
	if cooldown_total > 0.0 and cooldown_remaining > 0.0 and (kind == Kind.SKILL or charges < max_charges):
		var f: float = clampf(cooldown_remaining / cooldown_total, 0.0, 1.0)
		var start_angle: float = -PI * 0.5 + TAU * (1.0 - f)
		draw_colored_polygon(HudGlyphs.wedge_points(inner, start_angle, PI * 1.5), UiPalette.with_alpha(UiPalette.INK_PIXEL, 0.74))
		if kind == Kind.SKILL:
			_draw_centered_text(str(int(ceil(cooldown_remaining))), box, UiPalette.TEXT)
	draw_rect(inner, UiPalette.ACCENT if is_up else UiPalette.with_alpha(UiPalette.LINE_STRONG, 0.9), false, 3.0 if is_up else 2.0)
	if kind == Kind.DASH:
		_draw_charge_pips(inner)
	_draw_key_hint(box)


## Charge pips along the icon's bottom edge, like the ability slots' level pips.
func _draw_charge_pips(inner: Rect2) -> void:
	var total_w: float = float(max_charges) * CHARGE_PIP_PX + float(max_charges - 1) * 4.0
	var start := Vector2(inner.position.x + (inner.size.x - total_w) * 0.5, inner.end.y - CHARGE_PIP_PX - 5.0).round()
	for i: int in max_charges:
		var pip := Rect2(start + Vector2(float(i) * (CHARGE_PIP_PX + 4.0), 0.0), Vector2(CHARGE_PIP_PX, CHARGE_PIP_PX))
		draw_rect(pip.grow(3.0), UiPalette.INK_PIXEL, true)
		if i < charges:
			draw_rect(pip, UiPalette.ACCENT, true) # a charge ready: solid gold
		else:
			draw_rect(pip, UiPalette.with_alpha(UiPalette.INK, 0.9), true) # spent: an empty socket with a bronze rim, so the cue is shape as well as colour
			draw_rect(pip.grow(-1.0), UiPalette.LINE_STRONG, false, 2.0)


func _draw_key_hint(box: Rect2) -> void:
	if interactive:
		return
	var text: String = InputHints.key_text(get_action())
	if text == "":
		return
	var font: Font = UiTheme.get_display_font()
	var font_size: int = UiPalette.FONT_SIZE_BODY
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var badge_size := Vector2(maxf(text_size.x + 16.0, 40.0), HINT_STRIP_PX)
	var badge := Rect2(Vector2(box.position.x + (box.size.x - badge_size.x) * 0.5, box.end.y + HINT_GAP_PX).round(), badge_size)
	draw_rect(badge, UiPalette.INK_PIXEL, true)
	draw_rect(badge.grow(-2.0), UiPalette.with_alpha(UiPalette.SURFACE, 0.95), true)
	var baseline := Vector2(badge.position.x + (badge.size.x - text_size.x) * 0.5, badge.position.y + (badge.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5).round()
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, UiPalette.TEXT)


func _draw_centered_text(text: String, box: Rect2, color: Color) -> void:
	var font: Font = UiTheme.get_display_font()
	var font_size: int = UiPalette.FONT_SIZE_BODY
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2((box.size.x - text_size.x) * 0.5, (box.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5 - 6.0).round()
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, UiPalette.OUTLINE_BODY, UiPalette.INK_PIXEL)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


# --- Touch / mouse press -------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventScreenTouch:
		_set_held((event as InputEventScreenTouch).pressed)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_set_held((event as InputEventMouseButton).pressed)
		accept_event()


func _set_held(held: bool) -> void:
	if held == _held:
		return # a touch also arrives as an emulated mouse press; act once
	_held = held
	var ev := InputEventAction.new()
	ev.action = get_action()
	ev.pressed = held
	ev.strength = 1.0 if held else 0.0
	Input.parse_input_event(ev)


func is_held_for_test() -> bool:
	return _held


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _held:
		_set_held(false)
	elif what == NOTIFICATION_EXIT_TREE and _held:
		_held = false
		Input.action_release(get_action())
