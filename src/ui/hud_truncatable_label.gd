extends Label
class_name HudTruncatableLabel

## HudTruncatableLabel (P2.6). docs/19_UI_UX.md > "UI Layout & Dynamic
## Container Rules" > "Truncation Fallback": "If text absolutely must be
## truncated (e.g., in a tight HUD element), it must truncate with an
## ellipsis (...) and display the full text in a custom focus tooltip on
## hover or on gamepad/keyboard focus. Silent truncation is banned."
##
## Used for the Scrap counter ("n/200") specifically: docs/19's own example
## of "a tight HUD element" IS this field, and it is the one HUD field this
## task designs to truncate at all -- every other HUD label (Wave, Level,
## Rerolls) instead grows via `autowrap_mode = AUTOWRAP_WORD_SMART` +
## `size_flags_horizontal = SIZE_EXPAND_FILL` (docs/19's general container
## rule), matching the Register's own "HUD numbers may truncate with
## ellipsis plus a custom focus tooltip" wording, which names it as a
## fallback, not the default for every field.
##
## `focus_mode = FOCUS_ALL` so the tooltip is also reachable "on gamepad/
## keyboard focus", per the same rule -- a Label does not accept focus by
## default.

func _ready() -> void:
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	autowrap_mode = TextServer.AUTOWRAP_OFF
	clip_text = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL


## Typed command: sets the label's own display text AND the tooltip's full
## text in one call, so a caller can never update one and forget the other
## -- the exact bug this rule exists to prevent ("silent truncation").
func set_full_text(value: String) -> void:
	text = value
	tooltip_text = value


## Godot calls this to build the tooltip shown on hover or focus. Returning
## a styled Control here (rather than relying on the default plain-text
## tooltip window) is what makes this a "custom focus tooltip", literally,
## not merely the engine's default one.
func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	var label := Label.new()
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(160, 0)
	panel.add_child(label)
	return panel
