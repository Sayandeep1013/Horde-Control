class_name HudAbilitySlot
extends Control

## One build-bar slot: the ability icon at 2x, 1-5 level pips along its
## bottom edge, in a frame coloured by owner (green = player, orange = Tower;
## docs/19 shape language). An empty slot is dimmed. Purely a display; the
## owner is `Hud`. Sizes: Register > v1.0 Interface > "HUD build bar".

const SLOT_SIZE_PX: float = 72.0
const ICON_SCALE: int = 2
const PIP_SIZE_PX: float = 8.0
const PIP_GAP_PX: float = 3.0
const MAX_LEVEL: int = 5

enum Owner { PLAYER, TOWER }

var slot_owner: int = Owner.PLAYER
var ability_id: String = ""
var level: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(SLOT_SIZE_PX, SLOT_SIZE_PX)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_ability(id: String, new_level: int) -> void:
	if id == ability_id and new_level == level:
		return
	ability_id = id
	level = clampi(new_level, 0, MAX_LEVEL)
	queue_redraw()


func is_empty() -> bool:
	return ability_id == ""


func _owner_color() -> Color:
	return UiPalette.PLAYER if slot_owner == Owner.PLAYER else UiPalette.TOWER


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var empty: bool = is_empty()
	var accent: Color = _owner_color()
	draw_rect(box, UiPalette.INK_PIXEL, true)
	var inner := box.grow(-2.0)
	draw_rect(inner, UiPalette.with_alpha(UiPalette.INK, 0.45 if empty else 0.92), true)
	var frame_color: Color = UiPalette.with_alpha(accent, 0.35 if empty else 1.0)
	draw_rect(inner, frame_color, false, 2.0)
	if empty:
		# A dim "+" tells the player the slot can still be filled.
		var c: Vector2 = box.get_center()
		var dim: Color = UiPalette.with_alpha(accent, 0.3)
		draw_rect(Rect2(c - Vector2(10.0, 2.0), Vector2(20.0, 4.0)), dim, true)
		draw_rect(Rect2(c - Vector2(2.0, 10.0), Vector2(4.0, 20.0)), dim, true)
		return
	var icon_rect := Rect2(inner.position + Vector2(2.0, 2.0), inner.size - Vector2(4.0, 4.0))
	HudGlyphs.draw_icon_or(self, AbilityIds.icon_path(ability_id), icon_rect, func(r: Rect2) -> void: HudGlyphs.draw_monogram(self, r, ability_id, accent))
	_draw_pips(box)


func _draw_pips(box: Rect2) -> void:
	var total_w: float = float(MAX_LEVEL) * PIP_SIZE_PX + float(MAX_LEVEL - 1) * PIP_GAP_PX
	var start := Vector2(box.position.x + (box.size.x - total_w) * 0.5, box.end.y - PIP_SIZE_PX - 5.0).round()
	for i: int in MAX_LEVEL:
		var pip := Rect2(start + Vector2(float(i) * (PIP_SIZE_PX + PIP_GAP_PX), 0.0), Vector2(PIP_SIZE_PX, PIP_SIZE_PX))
		draw_rect(pip.grow(2.0), UiPalette.INK_PIXEL, true)
		draw_rect(pip, UiPalette.GOLD if i < level else UiPalette.with_alpha(UiPalette.LINE, 0.8), true)
