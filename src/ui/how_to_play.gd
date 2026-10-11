class_name HowToPlay
extends RefCounted

## The How to Play page (docs/31 §8.5): four short sections that name the live
## key bindings. One builder serves the title screen (a sub-panel) and the
## pause menu (an overlay), so the two can never drift apart.

const SECTION_COUNT: int = 4
const BODY_MIN_WIDTH_PX: float = 820.0


## The text of section `index` (1-4), with the bindings read from the Input Map
## now. `touch` selects the phone wording (buttons instead of keys).
static func heading(index: int) -> String:
	return TranslationServer.translate(StringName("HOWTO_%d_HEAD" % index))


static func body(index: int) -> String:
	var template: String = TranslationServer.translate(StringName("HOWTO_%d_BODY" % index))
	if TouchUi.is_mobile_layout():
		return template # the phone wording has no key slots
	match index:
		1:
			return template % _moves()
		2:
			return template % [_key(&"dash"), _key(&"battle_skill")]
	return template


## "W / A / S / D" style, from the four movement actions' first keys.
static func _moves() -> String:
	var parts: Array[String] = []
	for action: StringName in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		parts.append(InputHints.key_text(action))
	return " ".join(parts)


static func _key(action: StringName) -> String:
	var keys: Array[String] = InputHints.key_texts(action)
	return " or ".join(keys.slice(0, 2)) if not keys.is_empty() else "-"


## Sizes `scroll` to its content, up to `max_height`. Call once the page is in
## the tree and laid out (the text wraps to the real width first), so the four
## sections show whole on a normal screen and only scroll on a short one.
static func fit(scroll: ScrollContainer, max_height: float) -> void:
	var content: Control = scroll.get_child(0) as Control
	scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, max_height)


## Fills `parent` with a scrollable column of the four sections and returns the
## ScrollContainer so the caller can size it.
static func build_content(parent: Container, max_height: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "HowToScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, max_height)
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.name = "HowToColumn"
	column.theme_type_variation = UiTheme.vbox("M")
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	for i: int in range(1, SECTION_COUNT + 1):
		var head := Label.new()
		head.name = "Head%d" % i
		head.text = "%d. %s" % [i, heading(i)]
		head.theme_type_variation = UiTheme.HUD_VALUE
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.custom_minimum_size = Vector2(BODY_MIN_WIDTH_PX, 0.0)
		column.add_child(head)
		var text := Label.new()
		text.name = "Body%d" % i
		text.text = body(i)
		text.theme_type_variation = UiTheme.DIM_PARCHMENT
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(BODY_MIN_WIDTH_PX, 0.0)
		column.add_child(text)
	return scroll
