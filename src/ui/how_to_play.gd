class_name HowToPlay
extends RefCounted

## The How to Play page (docs/31 §8.5; review fix D242). One builder serves the
## title screen (a sub-panel) and the pause menu (an overlay), so the two can
## never drift apart. Contents:
##   - four short sections that name the live key bindings;
##   - "Know your enemy": a sprite and one line for each threat the player meets
##     (Seeker, Hunter, Opportunist, Bomber, Brute, elites, bosses);
##   - "Controls": the live bindings list (formerly the title screen's separate
##     Controls page, now merged here so there is one entry point). The F1 / F2
##     developer rows appear only in a debug build.
## Desktop lays the page out in two columns so it fits the 1080 canvas (and so
## 1280x720, which scales it) without scrolling; the touch layout stacks them in
## a scrolling column.

const SECTION_COUNT: int = 4
const BODY_MIN_WIDTH_PX: float = 820.0 ## single (touch) column
const COLUMN_WIDTH_PX: float = 800.0 ## each of the two desktop columns
const COLUMN_GAP_PX: float = 56.0
const ENEMY_ICON_PX: float = 72.0
const ENEMY_ICON_CROP: Rect2 = Rect2(50.0, 42.0, 92.0, 100.0) ## the goblin's own pixels inside the 192 px frame

## [string id, SpriteFrames path, tint] for each "Know your enemy" row.
const ENEMIES: Array = [
	["SEEKER", "res://assets/sprite_frames/tower_seeker.tres", Color(1, 1, 1, 1)],
	["HUNTER", "res://assets/sprite_frames/player_hunter.tres", Color(1, 1, 1, 1)],
	["OPPORTUNIST", "res://assets/sprite_frames/opportunist.tres", Color(1, 1, 1, 1)],
	["BOMBER", "res://assets/sprite_frames/player_hunter.tres", Color(0.62, 0.55, 0.78, 1)],
	["BRUTE", "res://assets/sprite_frames/tower_seeker.tres", Color(0.75, 0.45, 0.45, 1)],
	["ELITE", "res://assets/sprite_frames/tower_seeker.tres", Color(1.0, 0.86, 0.35, 1)],
	["BOSS", "res://assets/sprite_frames/tower_seeker.tres", Color(1.0, 0.62, 0.38, 1)],
]


## The text of section `index` (1-4), with the bindings read from the Input Map
## now. The touch table has no key slots, so it returns the template as is.
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


## The one-line description of enemy row `id` (see ENEMIES).
static func enemy_line(id: String) -> String:
	return TranslationServer.translate(StringName("HOWTO_ENEMY_" + id))


## The Controls rows as [action label, binding text] pairs, read from the Input
## Map now. Developer rows (F1 / F2) only in a debug build; the touch layout has
## its own wording and no keys.
static func controls_rows() -> Array:
	var tr_: Callable = func(key: String) -> String: return TranslationServer.translate(StringName(key))
	var rows: Array = []
	var moves: String = _moves_joined()
	rows.append([tr_.call("TITLE_CONTROLS_MOVE"), _fill(tr_.call("HOWTO_CTRL_MOVE_VALUE"), [moves])])
	rows.append([tr_.call("TITLE_CONTROLS_DASH"), _fill(tr_.call("HOWTO_CTRL_DASH_VALUE"), [InputHints.joined(&"dash", ", ")])])
	rows.append([tr_.call("TITLE_CONTROLS_SKILL"), _fill(tr_.call("HOWTO_CTRL_SKILL_VALUE"), [InputHints.joined(&"battle_skill", ", ")])])
	rows.append([tr_.call("TITLE_CONTROLS_DRAFT"), tr_.call("HOWTO_CTRL_DRAFT_VALUE")])
	if not TouchUi.is_mobile_layout():
		rows.append([tr_.call("TITLE_CONTROLS_CONFIRM"), tr_.call("HOWTO_CTRL_CONFIRM_VALUE")])
	rows.append([tr_.call("TITLE_CONTROLS_REROLL"), tr_.call("HOWTO_CTRL_REROLL_VALUE")])
	rows.append([tr_.call("TITLE_CONTROLS_PAUSE"), _fill(tr_.call("HOWTO_CTRL_PAUSE_VALUE"), [InputHints.joined(&"pause", ", ")])])
	if not TouchUi.is_mobile_layout() and DebugOverlay.dev_tools_enabled():
		rows.append([tr_.call("TITLE_CONTROLS_DEBUG_OVERLAY"), "F1"])
		rows.append([tr_.call("TITLE_CONTROLS_DEBUG_PSEUDOLOC"), "F2"])
	return rows


static func _moves_joined() -> String:
	return _moves()


## `template % args` when the text has a `%s` slot, else the text unchanged (the touch table).
static func _fill(template: String, args: Array) -> String:
	return (template % args) if template.contains("%s") else template


## Keeps the page reachable without a mouse: while it is visible, the movement
## keys, the arrow keys and the stick scroll it (the pause menu has no focus to move).
class ScrollDriver extends Node:
	const SPEED_PX_PER_SECOND: float = 900.0
	var scroll: ScrollContainer = null

	func _process(delta: float) -> void:
		if scroll == null or not scroll.is_visible_in_tree():
			return
		var axis: float = Input.get_axis(&"ui_up", &"ui_down")
		if is_zero_approx(axis):
			axis = Input.get_axis(&"move_up", &"move_down")
		if not is_zero_approx(axis):
			scroll.scroll_vertical += int(round(axis * SPEED_PX_PER_SECOND * delta))


## Sizes `scroll` to its content, up to `max_height`. Call once the page is in
## the tree and laid out (the text wraps to the real width first), so the page
## shows whole on a normal screen and only scrolls on a short one.
static func fit(scroll: ScrollContainer, max_height: float) -> void:
	var content: Control = scroll.find_child("HowToColumns", false, false) as Control
	scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, max_height)


## Fills `parent` with the page and returns the ScrollContainer so the caller can
## size it. Node names: Head1..Head4 / Body1..Body4 (sections), EnemyHead and
## EnemyRow_<ID> (Know your enemy), ControlsHead and ControlsGrid.
static func build_content(parent: Container, max_height: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "HowToScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, max_height)
	parent.add_child(scroll)
	var touch: bool = TouchUi.is_mobile_layout()
	var width: float = BODY_MIN_WIDTH_PX if touch else COLUMN_WIDTH_PX

	var outer: Container
	if touch:
		outer = VBoxContainer.new()
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(COLUMN_GAP_PX))
		outer = row
	outer.name = "HowToColumns"
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer)

	var left := _column("HowToColumn")
	outer.add_child(left)
	for i: int in range(1, SECTION_COUNT + 1):
		_add_text(left, "Head%d" % i, "%d. %s" % [i, heading(i)], UiTheme.HUD_VALUE, width)
		_add_text(left, "Body%d" % i, body(i), UiTheme.DIM_PARCHMENT, width)

	var right: VBoxContainer = left if touch else _column("InfoColumn")
	if not touch:
		right.theme_type_variation = UiTheme.vbox("XS") # tighter: the enemy list and Controls must fit under the title
		outer.add_child(right)
	_build_enemies(right, width)
	_build_controls(right, width)
	var driver := ScrollDriver.new()
	driver.name = "ScrollDriver"
	driver.process_mode = Node.PROCESS_MODE_ALWAYS # the pause menu's page runs while the tree is paused
	driver.scroll = scroll
	scroll.add_child(driver)
	return scroll


static func _column(node_name: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = node_name
	column.theme_type_variation = UiTheme.vbox("M")
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return column


static func _add_text(parent: Container, node_name: String, text: String, variation: StringName, width: float) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0.0)
	parent.add_child(label)
	return label


static func _build_enemies(parent: Container, width: float) -> void:
	_add_text(parent, "EnemyHead", "5. %s" % TranslationServer.translate(&"HOWTO_ENEMIES_HEAD"), UiTheme.HUD_VALUE, width)
	var grid := GridContainer.new()
	grid.name = "EnemyList"
	grid.columns = 1 if TouchUi.is_mobile_layout() else 2 # two across on desktop: seven rows would not fit the 1080 canvas
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	var line_width: float = (width if grid.columns == 1 else width * 0.5 - 8.0) - ENEMY_ICON_PX - 16.0
	for entry: Array in ENEMIES:
		var id: String = String(entry[0])
		var row := HBoxContainer.new()
		row.name = "EnemyRow_%s" % id
		row.theme_type_variation = UiTheme.hbox("XS")
		grid.add_child(row)
		row.add_child(_enemy_icon(String(entry[1]), entry[2] as Color))
		var line := _add_text(row, "Line", enemy_line(id), UiTheme.DIM_PARCHMENT, line_width)
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## The goblin's idle frame from its own SpriteFrames, cropped to its pixels, tinted as in the arena.
static func _enemy_icon(frames_path: String, tint: Color) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ENEMY_ICON_PX, ENEMY_ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frames: SpriteFrames = load(frames_path) as SpriteFrames
	if frames != null and frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
		var frame: Texture2D = frames.get_frame_texture(&"idle", 0)
		if frame is AtlasTexture:
			var atlas := AtlasTexture.new()
			var source := frame as AtlasTexture
			atlas.atlas = source.atlas
			var crop: Rect2 = ENEMY_ICON_CROP
			atlas.region = Rect2(source.region.position + crop.position, crop.size).intersection(source.region)
			icon.texture = atlas
		else:
			icon.texture = frame
	return icon


static func _build_controls(parent: Container, width: float) -> void:
	_add_text(parent, "ControlsHead", "6. %s" % TranslationServer.translate(&"HOWTO_CONTROLS_HEAD"), UiTheme.HUD_VALUE, width)
	var grid := GridContainer.new()
	grid.name = "ControlsGrid"
	grid.columns = 2
	parent.add_child(grid)
	for pair: Array in controls_rows():
		var action := Label.new()
		action.text = String(pair[0])
		action.theme_type_variation = UiTheme.HUD_VALUE
		action.custom_minimum_size = Vector2(width * 0.30, 0.0)
		grid.add_child(action)
		var keys := Label.new()
		keys.text = String(pair[1])
		keys.theme_type_variation = UiTheme.DIM_PARCHMENT
		keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keys.custom_minimum_size = Vector2(width * 0.64, 0.0)
		grid.add_child(keys)
