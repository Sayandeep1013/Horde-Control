class_name HudKillsGlyph
extends Control

## The skull beside the kills counter. Uses `icon_kills.png` once the icon set
## lands (docs/31 §9), else a built-in pixel skull, so the HUD never shows a hole.

const ICON_PATH: String = "res://assets/ui/icons/icon_kills.png"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	HudGlyphs.draw_icon_or(self, ICON_PATH, rect, func(r: Rect2) -> void: HudGlyphs.draw_skull(self, r, UiPalette.TEXT))
