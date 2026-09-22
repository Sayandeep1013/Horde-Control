extends CanvasLayer
class_name TitleScreen

## Title Screen (session task: add a title screen and credits). The
## project's `run/main_scene` (project.godot); "Play" hands off to
## `scenes/prototype.tscn`, which this file never touches.
##
## ## Root node choice
## `CanvasLayer`, matching every other full-screen UI surface this project
## already ships (src/ui/pause_menu.gd, run_end.gd, settings_menu.gd -- all
## three `CanvasLayer` at their scene root, with a plain `Control` built
## inside via `_build_ui()`), not a bare root `Control`. This screen reuses
## that exact same "apply the shared Theme once, at the inner Control root"
## shape those three files already use (see `UiTheme`'s own header: "A
## surface applies it ONCE, at its root Control"). There is no gameplay
## tree to layer against here -- this scene is the only thing on screen at
## boot -- so `layer` is left at its default.
##
## ## Reuses the UI pass's theme, not a second style
## Every colour, font, spacing, and panel style comes from
## `src/ui/theme/ui_theme.gd` / `ui_palette.gd`, the same `Theme` object
## every other menu in this project shares. No Tiny Swords UI chrome backs
## the title, tagline, or buttons (no banner/ribbon art ships in this
## repository); `UiTheme.CARD` is used instead, per this session's own
## instruction.
##
## ## Background art (assets/third_party/tiny_swords/PROVENANCE.md)
## A tiled grass ground (`Terrain/Ground/Tilemap_Flat.png`, `GRASS_TILE_REGION`
## below -- the one fully-opaque, edge-free cell in that sheet's 4x4 grass
## block, confirmed by scanning the sheet's alpha channel directly rather
## than guessed: every OTHER cell in that block has at least one transparent
## or partially-transparent pixel, the organic "cloud edge" Tiny Swords
## draws around a terrain patch), the blue Castle as a static backdrop, two
## swaying trees (`Resources/Trees/Tree.png`, row 0, 4 frames), and four
## idling goblins (`Factions/Goblins/Troops/Torch/Red/Torch_Red.png`, row 0,
## 7 frames) via `TitleSprite`. Every background texture sets
## `texture_filter = TEXTURE_FILTER_NEAREST` (this session's instruction;
## the project sets no global default filter, so a per-node override is the
## only way to get a crisp, un-blurred pixel-art look here).
##
## ## Music
## `assets/third_party/opengameart/music/battle_theme_a.ogg` on the `Music`
## bus (default_bus_layout.tres) at -14 dB, looped by reconnecting
## `AudioStreamPlayer.finished` to `play()` rather than mutating the shared
## `AudioStreamOggVorbis` resource's own `loop` flag (its import default is
## `loop=false`; this resource has no other reader anywhere in this
## codebase as of this session, but leaving the shared resource itself
## unmodified is the safer default regardless of that).
##
## ## Returning here from a run
## `src/run/run_flow_controller.gd`'s pause menu and run-end screen now
## offer a "Main Menu" choice alongside Resume/Settings -- see that file's
## own `_on_main_menu_requested()` for how it clears every active
## `PauseAuthority` reason before changing the scene, so this screen never
## opens already paused.

const TS_ROOT: String = "res://assets/third_party/tiny_swords/"
const GRASS_SHEET: String = TS_ROOT + "Terrain/Ground/Tilemap_Flat.png"
const CASTLE_TEXTURE: String = TS_ROOT + "Factions/Knights/Buildings/Castle/Castle_Blue.png"
const TREE_SHEET: String = TS_ROOT + "Resources/Trees/Tree.png"
const GOBLIN_SHEET: String = TS_ROOT + "Factions/Goblins/Troops/Torch/Red/Torch_Red.png"
const MUSIC_STREAM_PATH: String = "res://assets/third_party/opengameart/music/battle_theme_a.ogg"

## See class header, "Background art": the grass sheet's one fully-opaque,
## edge-free interior tile.
const GRASS_TILE_REGION: Rect2 = Rect2(64.0, 64.0, 64.0, 64.0)

const CASTLE_SIZE: Vector2 = Vector2(576.0, 461.0) ## 1.8x Castle_Blue.png's native 320x256
const CASTLE_TOP_LEFT: Vector2 = Vector2(672.0, 280.0)

const TREE_FRAME: Vector2i = Vector2i(192, 192)
const TREE_SIZE: Vector2 = Vector2(460.0, 460.0)

const GOBLIN_FRAME: Vector2i = Vector2i(192, 192)
const GOBLIN_SIZE: Vector2 = Vector2(240.0, 240.0)

## [top_left, flip_h] pairs, kept clear of the menu card's own horizontal
## footprint (roughly x 730-1190, see `_build_menu_card()`) so no goblin is
## fully hidden behind it.
const GOBLIN_SPOTS: Array = [
	[Vector2(60.0, 850.0), false],
	[Vector2(380.0, 880.0), true],
	[Vector2(1300.0, 880.0), false],
	[Vector2(1620.0, 850.0), true],
]

const MUSIC_VOLUME_DB: float = -14.0

const BUTTON_MIN_SIZE: Vector2 = Vector2(360.0, 68.0)
const MENU_CARD_MIN_WIDTH: float = 460.0
const SUB_PANEL_MIN_WIDTH: float = 900.0
const SUB_PANEL_SCROLL_MAX_HEIGHT: float = 480.0 ## docs/19 > "UI Layout & Dynamic Container Rules": a container over roughly 30% of screen height should scroll, not truncate -- both sub-panels wrap their list in a ScrollContainer capped near that budget.

var _root: Control
var _menu_center: CenterContainer
var _controls_center: CenterContainer
var _credits_center: CenterContainer
var _play_button: Button
var _controls_button: Button
var _credits_button: Button
var _quit_button: Button
var _controls_back_button: Button
var _credits_back_button: Button
var _music_player: AudioStreamPlayer
var _last_focused_main_button: Button = null


## Harness-only flag (matching src/run/run_flow_controller.gd's own
## `--no-focus-pause` precedent: a cmdline arg parsed for the visual-capture
## harness only, never read by real play). `--debug-panel=controls` or
## `--debug-panel=credits` opens that sub-panel immediately in `_ready()`,
## since `src/dev/scene_capture.gd` has no way to simulate a button click --
## it can only run a scene forward and screenshot it.
const DEBUG_PANEL_FLAG_PREFIX: String = "--debug-panel="

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiStrings.ensure_registered()
	_build_ui()
	_build_music()
	_play_button.grab_focus()
	_apply_debug_panel_flag()


func _apply_debug_panel_flag() -> void:
	var requested: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(DEBUG_PANEL_FLAG_PREFIX):
			requested = arg.trim_prefix(DEBUG_PANEL_FLAG_PREFIX)
	if requested == "controls":
		_on_controls_pressed()
	elif requested == "credits":
		_on_credits_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _controls_center.visible or _credits_center.visible:
		_hide_panels_and_return()
		get_viewport().set_input_as_handled()


# --- Assembly ----------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_background()
	_build_scrim()
	_build_foreground()
	_build_controls_panel()
	_build_credits_panel()


func _build_background() -> void:
	var background := Control.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.clip_contents = true
	_root.add_child(background)

	_add_grass(background)
	_add_tree(background, Vector2(-40.0, 500.0), false)
	_add_tree(background, Vector2(1500.0, 500.0), true)
	_add_castle(background)
	for spot in GOBLIN_SPOTS:
		_add_goblin(background, spot[0], spot[1])


func _build_scrim() -> void:
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiPalette.with_alpha(UiPalette.DIM_TINT, 0.35)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)


# --- Background pieces ---------------------------------------------------

func _add_grass(parent: Control) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(GRASS_SHEET)
	atlas.region = GRASS_TILE_REGION
	var rect := TextureRect.new()
	rect.name = "Grass"
	rect.texture = atlas
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rect)


func _add_castle(parent: Control) -> void:
	var rect := TextureRect.new()
	rect.name = "Castle"
	rect.texture = load(CASTLE_TEXTURE)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place(rect, CASTLE_TOP_LEFT, CASTLE_SIZE)
	parent.add_child(rect)


func _add_tree(parent: Control, top_left: Vector2, flip: bool) -> void:
	var sprite := TitleSprite.new()
	sprite.name = "Tree"
	sprite.fps = 5.0
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.flip_h = flip
	sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place(sprite, top_left, TREE_SIZE)
	parent.add_child(sprite)
	sprite.configure(load(TREE_SHEET), TREE_FRAME, 0, 4)


func _add_goblin(parent: Control, top_left: Vector2, flip: bool) -> void:
	var sprite := TitleSprite.new()
	sprite.name = "Goblin"
	sprite.fps = 7.0
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.flip_h = flip
	sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place(sprite, top_left, GOBLIN_SIZE)
	parent.add_child(sprite)
	sprite.configure(load(GOBLIN_SHEET), GOBLIN_FRAME, 0, 7)


## Positions an anchor-top-left Control at a fixed design-space rect
## (1920x1080 canvas; `window/stretch/mode = canvas_items` scales the whole
## rect uniformly, so these numbers stay correct at any window size).
func _place(control: Control, top_left: Vector2, size: Vector2) -> void:
	control.offset_left = top_left.x
	control.offset_top = top_left.y
	control.offset_right = top_left.x + size.x
	control.offset_bottom = top_left.y + size.y


# --- Foreground: title, tagline, menu -------------------------------------

func _build_foreground() -> void:
	var foreground := Control.new()
	foreground.name = "Foreground"
	foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	foreground.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(foreground)

	_build_title_block(foreground)
	_build_menu_card(foreground)


func _build_title_block(parent: Control) -> void:
	var title := Label.new()
	title.name = "GameTitle"
	title.text = tr("TITLE_GAME_NAME")
	title.theme_type_variation = UiTheme.TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# One-off, deliberately larger than any other UiTheme.TITLE use in this
	# project (a logo, not a menu heading) -- UiPalette's own header allows
	# `theme_override_*` for "genuine one-offs only"; this is one.
	title.add_theme_font_size_override("font_size", 128)
	title.add_theme_constant_override("outline_size", 12)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40.0
	title.offset_bottom = 200.0
	parent.add_child(title)

	var tagline := Label.new()
	tagline.name = "Tagline"
	tagline.text = tr("TITLE_TAGLINE")
	tagline.theme_type_variation = UiTheme.HEADING
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tagline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tagline.offset_top = 205.0
	tagline.offset_bottom = 255.0
	parent.add_child(tagline)


func _build_menu_card(parent: Control) -> void:
	_menu_center = CenterContainer.new()
	_menu_center.name = "MenuCenter"
	_menu_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_menu_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_menu_center.offset_top = 705.0
	_menu_center.offset_bottom = 1050.0
	parent.add_child(_menu_center)

	var card := PanelContainer.new()
	card.name = "MenuCard"
	card.theme_type_variation = UiTheme.CARD
	card.custom_minimum_size = Vector2(MENU_CARD_MIN_WIDTH, 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_menu_center.add_child(card)

	var column := VBoxContainer.new()
	column.name = "MenuColumn"
	column.theme_type_variation = UiTheme.vbox("M")
	card.add_child(column)

	_play_button = _make_menu_button(tr("TITLE_PLAY"))
	_play_button.pressed.connect(_on_play_pressed)
	column.add_child(_play_button)

	_controls_button = _make_menu_button(tr("TITLE_CONTROLS"))
	_controls_button.pressed.connect(_on_controls_pressed)
	column.add_child(_controls_button)

	_credits_button = _make_menu_button(tr("TITLE_CREDITS"))
	_credits_button.pressed.connect(_on_credits_pressed)
	column.add_child(_credits_button)

	_quit_button = _make_menu_button(tr("TITLE_QUIT"))
	_quit_button.pressed.connect(_on_quit_pressed)
	column.add_child(_quit_button)


func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = BUTTON_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


# --- Controls panel --------------------------------------------------------

## Real bindings, decoded directly from this project's own `project.godot`
## `[input]` section (physical keycodes / joypad button indices / axes),
## not copied from docs/19 without checking -- cross-checked against it
## afterward and found consistent. Left as plain strings (key/button names),
## matching docs/19's own Input Map section, which does not localize them
## either.
func _controls_rows() -> Array:
	return [
		[tr("TITLE_CONTROLS_MOVE"), "WASD / Arrow Keys / Left Stick"],
		[tr("TITLE_CONTROLS_DRAFT_CYCLE"), "A/D, Left Stick, D-Pad"],
		[tr("TITLE_CONTROLS_DRAFT_SELECT"), "1 / 2 / 3"],
		[tr("TITLE_CONTROLS_CONFIRM"), "Space, Enter, Left Click, A / Cross"],
		[tr("TITLE_CONTROLS_REROLL"), "R, X / Square"],
		[tr("TITLE_CONTROLS_CONSOLE_CYCLE"), "Tab, Shift+Tab, Mouse Wheel, D-Pad, Right Stick"],
		[tr("TITLE_CONTROLS_CONSOLE_SELECT"), "1-7"],
		[tr("TITLE_CONTROLS_CONSOLE_CANCEL"), "Q, B / Circle"],
		[tr("TITLE_CONTROLS_PAUSE"), "Escape, Start"],
		[tr("TITLE_CONTROLS_DEBUG_OVERLAY"), "F1"],
		[tr("TITLE_CONTROLS_DEBUG_PSEUDOLOC"), "F2"],
	]


func _build_controls_panel() -> void:
	var parts: Dictionary = _build_sub_panel("ControlsPanel")
	_controls_center = parts["center"]
	var column: VBoxContainer = parts["column"]

	column.add_child(_make_panel_title(tr("TITLE_CONTROLS_TITLE")))
	column.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0.0, SUB_PANEL_SCROLL_MAX_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "BindingsGrid"
	grid.columns = 2 # separation comes from the theme's own GridContainer defaults (UiTheme._build_containers(): h=SPACE_L, v=SPACE_S) -- no per-node override needed
	scroll.add_child(grid)

	for pair in _controls_rows():
		grid.add_child(_make_row_label(String(pair[0]), true))
		grid.add_child(_make_row_label(String(pair[1]), false))

	_controls_back_button = _make_menu_button(tr("TITLE_BACK"))
	_controls_back_button.pressed.connect(_on_controls_back_pressed)
	column.add_child(_controls_back_button)


func _make_row_label(text: String, is_action: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UiTheme.VALUE if is_action else UiTheme.DIM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(300.0 if is_action else 480.0, 0.0)
	return label


# --- Credits panel -----------------------------------------------------

func _build_credits_panel() -> void:
	var parts: Dictionary = _build_sub_panel("CreditsPanel")
	_credits_center = parts["center"]
	var column: VBoxContainer = parts["column"]

	column.add_child(_make_panel_title(tr("TITLE_CREDITS_TITLE")))
	column.add_child(HSeparator.new())

	for key in ["TITLE_CREDITS_TINY_SWORDS", "TITLE_CREDITS_MUSIC", "TITLE_CREDITS_KENNEY", "TITLE_CREDITS_FONT", "TITLE_CREDITS_GODOT"]:
		column.add_child(_make_credit_line(tr(key)))

	_credits_back_button = _make_menu_button(tr("TITLE_BACK"))
	_credits_back_button.pressed.connect(_on_credits_back_pressed)
	column.add_child(_credits_back_button)


func _make_credit_line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UiTheme.DIM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


# --- Shared sub-panel scaffold ------------------------------------------

## Builds Center(full rect, hidden) -> Card(UiTheme.CARD) -> Column, mirroring
## src/ui/menu_frame.gd's own Root/Center/Card/Column shape (that helper is
## typed to a `CanvasLayer` root and cannot be reused directly from a
## `Control`-rooted sub-screen, so this is a small local equivalent, not a
## second design -- same theme variation, same construction order).
func _build_sub_panel(panel_name: String) -> Dictionary:
	var center := CenterContainer.new()
	center.name = panel_name + "Center"
	center.visible = false
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	# Top-wide, starting BELOW the title/tagline band (offset_bottom = 255
	# above) rather than a full-rect centre -- a full-rect centre put this
	# panel's own vertical middle close enough to the tagline's band that
	# the panel's top edge visibly overlapped it (its CARD stylebox is
	# 0.96 alpha, not fully opaque, so the tagline ghosted through at the
	# seam). Starting the band at 280 (the same y the Castle backdrop
	# starts at) keeps the panel entirely clear of the title block instead.
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 280.0
	center.offset_bottom = 1080.0
	_root.get_node("Foreground").add_child(center)

	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.theme_type_variation = UiTheme.CARD
	panel.custom_minimum_size = Vector2(SUB_PANEL_MIN_WIDTH, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.theme_type_variation = UiTheme.vbox("L")
	panel.add_child(column)

	return {"center": center, "column": column}


func _make_panel_title(text: String) -> Label:
	var label := Label.new()
	label.name = "Title"
	label.text = text
	label.theme_type_variation = UiTheme.HEADING
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


# --- Button / panel handlers ---------------------------------------------

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/prototype.tscn")


func _on_controls_pressed() -> void:
	_show_panel(_controls_center, _controls_button, _controls_back_button)


func _on_credits_pressed() -> void:
	_show_panel(_credits_center, _credits_button, _credits_back_button)


func _on_controls_back_pressed() -> void:
	_hide_panels_and_return()


func _on_credits_back_pressed() -> void:
	_hide_panels_and_return()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _show_panel(center: CenterContainer, opener: Button, focus_target: Button) -> void:
	_last_focused_main_button = opener
	_menu_center.visible = false
	center.visible = true
	focus_target.grab_focus()


func _hide_panels_and_return() -> void:
	_controls_center.visible = false
	_credits_center.visible = false
	_menu_center.visible = true
	var target: Button = _last_focused_main_button if _last_focused_main_button != null else _play_button
	target.grab_focus()


# --- Music -----------------------------------------------------------------

func _build_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	_music_player.volume_db = MUSIC_VOLUME_DB
	_music_player.stream = load(MUSIC_STREAM_PATH)
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)
	_music_player.play()


func _on_music_finished() -> void:
	_music_player.play()


# --- Test seams (project convention: set_*_for_test() / get_*_for_test()) --

func get_play_button_for_test() -> Button:
	return _play_button


func get_controls_button_for_test() -> Button:
	return _controls_button


func get_credits_button_for_test() -> Button:
	return _credits_button


func get_quit_button_for_test() -> Button:
	return _quit_button


func is_controls_panel_active_for_test() -> bool:
	return _controls_center.visible


func is_credits_panel_active_for_test() -> bool:
	return _credits_center.visible


func get_music_player_for_test() -> AudioStreamPlayer:
	return _music_player
