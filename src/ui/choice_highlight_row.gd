extends Control
class_name ChoiceHighlightRow

## Shape cue for `PausedChoiceBar`'s highlighted option (UI pass, package
## D). `src/run/paused_choice_bar.gd` is OUTSIDE the UI pass's write scope
## and highlights its current option by `modulate` colour alone
## (`_refresh_highlight()`) -- MASTER_SDLC.md's colour-only-distinctions
## rule means that highlight needs a non-colour companion, added from the
## outside (phases/UI_PASS/HANDOFF.md, H-04).
##
## This sits directly under the bar as a thin strip and DRAWS one accent
## underline beneath whichever option is highlighted, so the cue has a
## position: it moves when the highlight moves. `highlighted_changed(index)`
## -- a public `PausedChoiceBar` signal that fires on cycle and on mouse
## hover alike -- drives it.
##
## ## Why it draws instead of laying out marker nodes
## The first version was an HBoxContainer of one marker per option, toggled
## by `visible`. A hidden child takes no space in a box container, so the
## one visible marker stretched across the whole row and the cue never
## moved -- it said nothing (found on a screenshot of the launched scene;
## no test could see it). Drawing from the highlighted option's REAL
## rectangle also removes the earlier approximation of mirroring the bar's
## private width and separation literals: the underline is exactly as wide
## as the option it marks, including under pseudo-localization.
##
## The option's rectangle is read from the bar's child at that index, which
## is how the owning menus already style those labels; it is re-read
## whenever the bar re-sorts its children or either control resizes, so it
## follows layout rather than fixing a position.

const UNDERLINE_HEIGHT: float = 4.0

var _bar: PausedChoiceBar = null
var _highlighted: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, UNDERLINE_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)


## Typed command. Starts tracking `bar`'s highlight. Safe to call again.
func configure(bar: PausedChoiceBar) -> void:
	_bar = bar
	_highlighted = bar.get_highlighted_index()
	if not bar.highlighted_changed.is_connected(_on_highlighted_changed):
		bar.highlighted_changed.connect(_on_highlighted_changed)
	if not bar.sort_children.is_connected(queue_redraw):
		bar.sort_children.connect(queue_redraw)
	queue_redraw()


func get_highlighted_index() -> int:
	return _highlighted


func _on_highlighted_changed(index: int) -> void:
	_highlighted = index
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = get_underline_rect()
	if rect.size.x > 0.0:
		draw_rect(rect, UiPalette.ACCENT, true)


## The rectangle `_draw()` fills, in this control's local space; an empty
## Rect2 when there is nothing to mark. Its own method so a test asserts the
## SAME geometry that is rendered (src/ui/hud_bar.gd's convention).
func get_underline_rect() -> Rect2:
	if _bar == null or not is_instance_valid(_bar):
		return Rect2()
	if _highlighted < 0 or _highlighted >= _bar.get_child_count():
		return Rect2()
	var option: Control = _bar.get_child(_highlighted) as Control
	if option == null or option.is_queued_for_deletion():
		return Rect2()
	# Mapped through the transforms rather than subtracting global positions,
	# so the underline stays aligned while the card's cosmetic open tween is
	# still scaling both controls.
	var left: float = (get_global_transform().affine_inverse() * option.get_global_transform().origin).x
	return Rect2(left, 0.0, option.size.x, UNDERLINE_HEIGHT)
