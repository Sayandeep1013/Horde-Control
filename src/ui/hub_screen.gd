extends CanvasLayer
class_name HubScreen

## Hub (War Camp) -- Meta layer core screens. Replaces the P2.14 placeholder
## (docs/18_Permanent_Skill_Tree.md section 2: "Title's Play opens the Hub.
## The Hub has Start Run, the Skill Tree, the Core balance, the player's
## Records, and Back to Title") with the finished War Camp: a Tiny Swords
## backdrop, an animated wooden top bar showing the Core balance, the four
## Hub actions, the first-visit hint, and a non-blocking profile-warning
## banner (`MetaProgress.get_flags()`).
##
## ## Flow
## Title's Play -> `res://scenes/hub.tscn` (src/ui/title_screen.gd). This
## screen's own "Start Run" -> `res://scenes/prototype.tscn`; "Back to
## Title" -> `res://scenes/title.tscn`. `RunFlowController`'s run-end
## screen's "Continue" choice comes back here. "Skill Tree" and "Records"
## open their own overlay CanvasLayers (`SkillTreeScreen`/`RecordsPanel`),
## instantiated once here and toggled with `set_active()`, mirroring
## `RunFlowController`'s own PauseMenu/SettingsMenu/RunEndScreen pattern.
##
## ## MetaProgress loading (see src/meta/meta_progress.gd's own header,
## "Never touches the real user://profile.json unless asked to")
## This is the first production scene that calls `MetaProgress.
## ensure_loaded()` -- the real save is read (or created, on a first launch)
## here, not at Autoload boot. `mark_hub_seen()` follows, for the
## `first_hub_seen` profile flag; the first-visit hint (docs/18 section 2's
## own quoted line) is shown for exactly that first visit and never again.
##
## ## Background art (assets/third_party/tiny_swords/PROVENANCE.md)
## Grass ground (the same fully-opaque interior tile title_screen.gd's own
## `GRASS_TILE_REGION` already measured), the blue Castle as a static
## backdrop, two House_Blue buildings standing in for tents, a looping
## campfire (`Effects/Fire/Fire.png`), and idling Archer_Blue camp guards
## (this pack ships no separate "Pawn" troop sprite -- see PROVENANCE.md's
## own frame-layout table; Archer_Blue's own idle row stands in for both).
## Every background texture sets `TEXTURE_FILTER_NEAREST`, matching
## title_screen.gd's identical convention.
##
## ## Music
## Reuses the title's own battle theme, quieter (build brief: "Title music
## continues or battle theme at low volume") -- a fresh scene load frees the
## title's own `AudioStreamPlayer` regardless, so "continues" is not
## available; the lower-volume battle theme is the literal alternative the
## brief names.
##
## ## Profile warnings (docs/18 section 6 edge cases; `MetaProgress.
## get_flags()`)
## `last_save_failed` / `recovered_from_corruption` / `read_only_newer_
## version` each show a non-blocking banner (docs/18's own recovery wording,
## quoted into `UiStrings`) -- "non-blocking" means it never covers or
## disables Start Run/Skill Tree/Records/Back to Title; it sits above the
## top bar and can be dismissed once acknowledged, exactly like the
## first-visit hint.

const TS_ROOT: String = "res://assets/third_party/tiny_swords/"
const GRASS_SHEET: String = TS_ROOT + "Terrain/Ground/Tilemap_Flat.png"
const GRASS_TILE_REGION: Rect2 = Rect2(64.0, 64.0, 64.0, 64.0) # the one fully-opaque interior tile (title_screen.gd's own measured region)
const CASTLE_TEXTURE: String = TS_ROOT + "Factions/Knights/Buildings/Castle/Castle_Blue.png"
const HOUSE_TEXTURE: String = TS_ROOT + "Factions/Knights/Buildings/House/House_Blue.png"
const ARCHER_SHEET: String = TS_ROOT + "Factions/Knights/Troops/Archer/Blue/Archer_Blue.png"
const FIRE_SHEET: String = TS_ROOT + "Effects/Fire/Fire.png"
## Polish pass (coordinator review): "fill the empty middle a bit (the
## campfire and a banner/flag near the castle, a few sheep)." Both textures
## are already-provenanced Tiny Swords assets (PROVENANCE.md); the banner is
## a static cloth pennant (a `UI/Banners/` sheet, used here as a plain world
## decoration hanging by the castle gate, not as a themed panel), and the
## sheep reuses `HappySheep_All.png` row 0 (idle, 8 frames) via the same
## `TitleSprite` frame-strip helper the archers already use.
const BANNER_TEXTURE: String = TS_ROOT + "UI/Banners/Banner_Vertical.png"
const SHEEP_SHEET: String = TS_ROOT + "Resources/Sheep/HappySheep_All.png"
const MUSIC_STREAM_PATH: String = "res://assets/third_party/opengameart/music/battle_theme_a.ogg"

const CASTLE_SIZE: Vector2 = Vector2(480.0, 384.0) # 1.5x Castle_Blue.png's native 320x256
const CASTLE_TOP_LEFT: Vector2 = Vector2(1180.0, 300.0)
const HOUSE_SIZE: Vector2 = Vector2(192.0, 288.0) # 1.5x House_Blue.png's native 128x192
const HOUSE_SPOTS: Array = [Vector2(120.0, 560.0), Vector2(330.0, 620.0)]
const ARCHER_FRAME: Vector2i = Vector2i(192, 192)
const ARCHER_IDLE_ROW: int = 0
const ARCHER_IDLE_COUNT: int = 6
const ARCHER_SIZE: Vector2 = Vector2(150.0, 150.0)
## [top_left, flip_h] pairs -- clear of the menu card's own footprint (see
## `_build_menu_card()`) so no guard is hidden behind it.
const ARCHER_SPOTS: Array = [
	[Vector2(60.0, 760.0), false],
	[Vector2(420.0, 800.0), true],
	[Vector2(1260.0, 760.0), false],
	[Vector2(1560.0, 800.0), true],
]
const FIRE_FRAME: Vector2i = Vector2i(128, 128)
const FIRE_COUNT: int = 7
const FIRE_SIZE: Vector2 = Vector2(96.0, 96.0)
const FIRE_TOP_LEFT: Vector2 = Vector2(905.0, 330.0) # open grass between the title and the menu card -- the card itself sits lower (see _build_menu_card()) and would otherwise hide the fire entirely

const BANNER_SIZE: Vector2 = Vector2(120.0, 120.0)
const BANNER_TOP_LEFT: Vector2 = Vector2(1130.0, 220.0) # hangs just left of the castle gate, clear of both the title block above and the castle texture's own footprint

const SHEEP_FRAME: Vector2i = Vector2i(128, 128)
const SHEEP_IDLE_COUNT: int = 8
const SHEEP_SIZE: Vector2 = Vector2(80.0, 80.0)
const SHEEP_SPOTS: Array = [Vector2(560.0, 470.0), Vector2(650.0, 520.0), Vector2(1400.0, 760.0)]

const MUSIC_VOLUME_DB: float = -22.0 # quieter than the title's own -14 dB -- see class header, "Music"

const MENU_CARD_MIN_WIDTH: float = 460.0
const BUTTON_MIN_SIZE: Vector2 = Vector2(360.0, 68.0)
const START_RUN_MIN_SIZE: Vector2 = Vector2(360.0, 84.0) # the primary action, visibly larger

## Harness-only flag (title_screen.gd's own `--debug-panel=` precedent):
## `--debug-panel=skill_tree` / `--debug-panel=records` opens that overlay
## immediately in `_ready()`, since the capture harness cannot simulate a
## button click.
const DEBUG_PANEL_FLAG_PREFIX: String = "--debug-panel="

var _root: Control
var _cores_label: Label
var _cores_icon: UiShapeGlyph
var _start_run_button: Button
var _skill_tree_button: Button
var _records_button: Button
var _back_to_title_button: Button
var _hint_banner: PanelContainer
var _warning_banner: PanelContainer
var _warning_label: Label
var _music_player: AudioStreamPlayer

var _skill_tree_screen: SkillTreeScreen
var _records_panel: RecordsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaProgress.ensure_loaded()
	var first_visit: bool = not MetaProgress.is_first_hub_seen()
	MetaProgress.mark_hub_seen()
	_build_ui()
	_build_music()
	_refresh_cores_label()
	_hint_banner.visible = first_visit
	_refresh_warning_banner()
	if not MetaProgress.cores_changed.is_connected(_on_cores_changed):
		MetaProgress.cores_changed.connect(_on_cores_changed)
	_start_run_button.grab_focus()
	_apply_debug_panel_flag()


func _exit_tree() -> void:
	if MetaProgress.cores_changed.is_connected(_on_cores_changed):
		MetaProgress.cores_changed.disconnect(_on_cores_changed)


func _apply_debug_panel_flag() -> void:
	var requested: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(DEBUG_PANEL_FLAG_PREFIX):
			requested = arg.trim_prefix(DEBUG_PANEL_FLAG_PREFIX)
	if requested == "skill_tree":
		_on_skill_tree_pressed()
	elif requested == "records":
		_on_records_pressed()


func _on_cores_changed(_new_total: int) -> void:
	_refresh_cores_label()
	_punch_cores_label()


func _refresh_cores_label() -> void:
	_cores_label.text = str(MetaProgress.get_cores())


func _punch_cores_label() -> void:
	_cores_label.pivot_offset = _cores_label.size * 0.5
	var tween: Tween = _cores_label.create_tween()
	tween.tween_property(_cores_label, "scale", Vector2(UiPalette.VALUE_PUNCH_SCALE, UiPalette.VALUE_PUNCH_SCALE), UiPalette.VALUE_PUNCH * 0.4)
	tween.tween_property(_cores_label, "scale", Vector2.ONE, UiPalette.VALUE_PUNCH * 0.6)


## docs/18 section 6: three of the profile's own recovery flags each show a
## non-blocking banner; the first one found wins (all three are mutually
## rare and never meaningfully co-occur -- `read_only_newer_version` alone
## already implies the save could be read at all).
func _refresh_warning_banner() -> void:
	var flags: Dictionary = MetaProgress.get_flags()
	var text: String = ""
	if bool(flags.get("recovered_from_corruption", false)):
		text = tr("HUB_WARNING_RECOVERED")
	elif bool(flags.get("read_only_newer_version", false)):
		text = tr("HUB_WARNING_READ_ONLY")
	elif bool(flags.get("last_save_failed", false)):
		text = tr("HUB_WARNING_SAVE_FAILED")
	_warning_banner.visible = text != ""
	_warning_label.text = text


func _on_start_run_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/prototype.tscn")


func _on_back_to_title_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _on_skill_tree_pressed() -> void:
	_hint_banner.visible = false
	_skill_tree_screen.set_active(true)


func _on_skill_tree_back_requested() -> void:
	_skill_tree_screen.set_active(false)
	_refresh_cores_label()
	_start_run_button.grab_focus()


func _on_records_pressed() -> void:
	_hint_banner.visible = false
	_records_panel.set_active(true)


func _on_records_back_requested() -> void:
	_records_panel.set_active(false)
	_start_run_button.grab_focus()


func _on_hint_dismiss_pressed() -> void:
	_hint_banner.visible = false


func _on_warning_dismiss_pressed() -> void:
	_warning_banner.visible = false


# --- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	UiStrings.ensure_registered()
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_background()
	_build_scrim()
	_build_foreground()
	_build_top_bar()
	_build_banners()

	_skill_tree_screen = (preload("res://scenes/ui/skill_tree_screen.tscn") as PackedScene).instantiate() as SkillTreeScreen
	add_child(_skill_tree_screen)
	_skill_tree_screen.back_requested.connect(_on_skill_tree_back_requested)

	_records_panel = (preload("res://scenes/ui/records_panel.tscn") as PackedScene).instantiate() as RecordsPanel
	add_child(_records_panel)
	_records_panel.back_requested.connect(_on_records_back_requested)


func _build_background() -> void:
	var background := Control.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.clip_contents = true
	_root.add_child(background)

	_add_grass(background)
	for spot in HOUSE_SPOTS:
		_add_house(background, spot)
	_add_castle(background)
	_add_banner(background)
	for spot in ARCHER_SPOTS:
		_add_archer(background, spot[0], spot[1])
	for spot in SHEEP_SPOTS:
		_add_sheep(background, spot)
	_add_campfire(background)


func _build_scrim() -> void:
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiPalette.with_alpha(UiPalette.DIM_TINT, 0.35)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)


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


func _add_house(parent: Control, top_left: Vector2) -> void:
	var rect := TextureRect.new()
	rect.name = "House"
	rect.texture = load(HOUSE_TEXTURE)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place(rect, top_left, HOUSE_SIZE)
	parent.add_child(rect)


func _add_banner(parent: Control) -> void:
	var rect := TextureRect.new()
	rect.name = "Banner"
	rect.texture = load(BANNER_TEXTURE)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place(rect, BANNER_TOP_LEFT, BANNER_SIZE)
	parent.add_child(rect)


func _add_sheep(parent: Control, top_left: Vector2) -> void:
	var sprite := TitleSprite.new()
	sprite.name = "Sheep"
	sprite.fps = 4.0
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place(sprite, top_left, SHEEP_SIZE)
	parent.add_child(sprite)
	sprite.configure(load(SHEEP_SHEET), SHEEP_FRAME, 0, SHEEP_IDLE_COUNT)


func _add_archer(parent: Control, top_left: Vector2, flip: bool) -> void:
	var sprite := TitleSprite.new()
	sprite.name = "Archer"
	sprite.fps = 6.0
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.flip_h = flip
	sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place(sprite, top_left, ARCHER_SIZE)
	parent.add_child(sprite)
	sprite.configure(load(ARCHER_SHEET), ARCHER_FRAME, ARCHER_IDLE_ROW, ARCHER_IDLE_COUNT)


func _add_campfire(parent: Control) -> void:
	var sprite := TitleSprite.new()
	sprite.name = "Campfire"
	sprite.fps = 10.0
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place(sprite, FIRE_TOP_LEFT, FIRE_SIZE)
	parent.add_child(sprite)
	sprite.configure(load(FIRE_SHEET), FIRE_FRAME, 0, FIRE_COUNT)


## Positions an anchor-top-left Control at a fixed design-space rect
## (1920x1080 canvas; `window/stretch/mode = canvas_items` scales the whole
## rect uniformly, matching title_screen.gd's identical `_place()`).
func _place(control: Control, top_left: Vector2, size: Vector2) -> void:
	control.offset_left = top_left.x
	control.offset_top = top_left.y
	control.offset_right = top_left.x + size.x
	control.offset_bottom = top_left.y + size.y


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
	title.name = "HubTitle"
	title.text = tr("HUB_TITLE")
	title.theme_type_variation = UiTheme.TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30.0
	title.offset_bottom = 130.0
	parent.add_child(title)


func _build_menu_card(parent: Control) -> void:
	var center := CenterContainer.new()
	center.name = "MenuCenter"
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# Round 2: the card's own real content (Start Run + 3 buttons + CARD's
	# own texture padding) measures ~372px tall -- centred on the ORIGINAL
	# 720/1050 band (centre y=885) that left only ~9px of clearance above
	# 1080, which read fine at native 1920x1080 but sat right at the bottom
	# edge once scaled down to 1280x720 (canvas_items stretch mode preserves
	# the same relative margin, so a tight fit at one scales to an equally
	# tight fit at the other). Centred higher (y=800) instead, for real
	# clearance at both resolutions.
	center.offset_top = 650.0
	center.offset_bottom = 950.0
	parent.add_child(center)

	var card := PanelContainer.new()
	card.name = "MenuCard"
	card.theme_type_variation = UiTheme.CARD
	card.custom_minimum_size = Vector2(MENU_CARD_MIN_WIDTH, 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(card)

	var column := VBoxContainer.new()
	column.name = "MenuColumn"
	column.theme_type_variation = UiTheme.vbox("M")
	card.add_child(column)

	# Polish pass (coordinator review): "give the menu card a ribbon
	# header." UiTheme.RIBBON is the same carved-cloth 3-slice the HUD's own
	# Wave banner already uses (ui_theme.gd's own header) -- reused here
	# rather than inventing a second banner style.
	var ribbon := PanelContainer.new()
	ribbon.name = "MenuRibbon"
	ribbon.theme_type_variation = UiTheme.RIBBON
	column.add_child(ribbon)

	var ribbon_label := Label.new()
	ribbon_label.name = "RibbonLabel"
	ribbon_label.text = tr("HUB_TITLE")
	ribbon_label.theme_type_variation = UiTheme.VALUE
	ribbon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon.add_child(ribbon_label)

	_start_run_button = Button.new()
	_start_run_button.name = "StartRunButton"
	_start_run_button.text = tr("HUB_START_RUN")
	_start_run_button.custom_minimum_size = START_RUN_MIN_SIZE
	_start_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_run_button.focus_mode = Control.FOCUS_ALL
	_start_run_button.pressed.connect(_on_start_run_pressed)
	column.add_child(_start_run_button)

	_skill_tree_button = _make_menu_button(tr("HUB_SKILL_TREE"))
	_skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	column.add_child(_skill_tree_button)

	_records_button = _make_menu_button(tr("HUB_RECORDS"))
	_records_button.pressed.connect(_on_records_pressed)
	column.add_child(_records_button)

	_back_to_title_button = _make_menu_button(tr("HUB_BACK_TO_TITLE"))
	_back_to_title_button.pressed.connect(_on_back_to_title_pressed)
	column.add_child(_back_to_title_button)


func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = BUTTON_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.theme_type_variation = UiTheme.hbox("L")
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	bar.offset_left = UiPalette.SCREEN_MARGIN
	bar.offset_top = UiPalette.SCREEN_MARGIN
	_root.add_child(bar)

	var cores_pill := PanelContainer.new()
	cores_pill.name = "CoresPill"
	cores_pill.theme_type_variation = UiTheme.PILL
	bar.add_child(cores_pill)

	var cores_row := HBoxContainer.new()
	cores_row.theme_type_variation = UiTheme.hbox("XS")
	cores_pill.add_child(cores_row)

	_cores_icon = UiShapeGlyph.new()
	_cores_icon.name = "CoresIcon"
	_cores_icon.shape = UiShapeGlyph.Shape.CRYSTAL
	_cores_icon.glyph_color = UiPalette.CORES
	_cores_icon.set_side(28)
	cores_row.add_child(_cores_icon)

	_cores_label = Label.new()
	_cores_label.name = "CoresLabel"
	_cores_label.theme_type_variation = UiTheme.VALUE
	cores_row.add_child(_cores_label)


## A column of dismissible, non-blocking banners (docs/18 section 2's hint;
## docs/18 section 6's profile-warning flags) -- top-anchored, never over
## the menu card or the top bar, so neither can ever cover Start Run/Skill
## Tree/Records/Back to Title or the Core balance it sits below. A real
## `VBoxContainer`, not a manually-offset rect: the profile-warning strings
## (docs/18 section 6's own recovery wording) run long enough to wrap to
## several lines, and only a Container auto-grows each banner's height to
## fit its own wrapped text (docs/19 > "UI Layout & Dynamic Container
## Rules") -- a fixed-height rect would clip it.
func _build_banners() -> void:
	var column := VBoxContainer.new()
	column.name = "Banners"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	# No theme_type_variation here: UiPalette.SPACE_S is the theme's own
	# default VBoxContainer separation (UiTheme.BOX_STEPS's own header:
	# "SPACE_S is the theme default and needs no variation").
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	column.offset_top = 100.0
	column.offset_left = 660.0
	column.offset_right = -660.0
	_root.add_child(column)

	_hint_banner = _build_banner(column, "HintBanner", tr("HUB_FIRST_VISIT_HINT"), tr("HUB_HINT_DISMISS"), _on_hint_dismiss_pressed)
	_warning_banner = _build_banner(column, "WarningBanner", "", tr("HUB_HINT_DISMISS"), _on_warning_dismiss_pressed)
	_warning_label = _warning_banner.get_node("Row/Label") as Label
	_warning_banner.visible = false


func _build_banner(parent: Container, node_name: String, text: String, dismiss_text: String, on_dismiss: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.theme_type_variation = UiTheme.PANEL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.theme_type_variation = UiTheme.hbox("L")
	panel.add_child(row)

	var label := Label.new()
	label.name = "Label"
	label.text = text
	label.theme_type_variation = UiTheme.DIM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(420.0, 0.0)
	row.add_child(label)

	var dismiss := Button.new()
	dismiss.name = "DismissButton"
	dismiss.text = dismiss_text
	dismiss.custom_minimum_size = Vector2(140.0, 48.0)
	dismiss.pressed.connect(on_dismiss)
	row.add_child(dismiss)

	return panel


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


# --- Test seams ----------------------------------------------------------

func get_cores_label_for_test() -> Label:
	return _cores_label


func get_start_run_button_for_test() -> Button:
	return _start_run_button


func get_skill_tree_button_for_test() -> Button:
	return _skill_tree_button


func get_records_button_for_test() -> Button:
	return _records_button


func get_back_to_title_button_for_test() -> Button:
	return _back_to_title_button


func get_hint_banner_for_test() -> PanelContainer:
	return _hint_banner


func get_warning_banner_for_test() -> PanelContainer:
	return _warning_banner


func get_skill_tree_screen_for_test() -> SkillTreeScreen:
	return _skill_tree_screen


func get_records_panel_for_test() -> RecordsPanel:
	return _records_panel


func get_music_player_for_test() -> AudioStreamPlayer:
	return _music_player
