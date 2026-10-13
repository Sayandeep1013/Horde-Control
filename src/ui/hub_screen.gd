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
## ## v1.0 War Camp (D254, WP-META)
## A "Run Setup" card sits left of the menu card: a Difficulty picker (four
## buttons; a locked one is greyed and, when focused or pressed, says what
## unlocks it), a Battle Skill picker (a locked skill names the Skill Tree node
## that opens it), an Endless toggle (hidden until a victory unlocks it) and the
## Start Run button. Each choice is saved in the profile as it is made
## (`MetaProgress.set_selected_*`); Start Run writes the three into `RunConfig`
## and only then changes scene. The pickers are plain Buttons on Godot's native
## focus chain, so keyboard, pad, mouse and touch all reach them (movement-only
## navigation: up/down/left/right to move, Space/Enter to choose). A one-time
## banner after the v2 -> v3 profile migration says the Skill Tree was rebuilt.
## The calm "town theme" plays on the Music bus.
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
##
## BUGFIX (blind review of the meta layer, finding #3): `recovered_from_
## corruption` used to have no lifecycle at all -- once set, it showed this
## banner on EVERY future Hub visit, forever. `_refresh_warning_banner()`
## now calls `MetaProgress.acknowledge_recovered_from_corruption()` the
## instant it reads a true value, mirroring `mark_hub_seen()`'s own
## "capture the pre-clear value locally, THEN clear it" shape for the
## first-visit hint above: `text` is built from the flags captured BEFORE
## the acknowledge call, so THIS visit still shows the banner once, and the
## clear is persisted (`acknowledge_recovered_from_corruption()` calls
## `_save()`) so no LATER visit -- this session or a future one -- shows it
## again. `read_only_newer_version` is deliberately NOT given the same
## treatment: it reflects a condition that stays true (the file on disk
## really is newer) until the player upgrades, so it must keep showing on
## every visit; `last_save_failed` corrects itself the next time a save
## actually succeeds (`_save()`'s own header).
##
## ## Settings (Settings screen task; blind review fix, item 5)
## A "Settings" button opens its own `SettingsMenu` instance, instantiated
## here exactly like `_skill_tree_screen`/`_records_panel`/`_achievements_
## panel` above -- toggled with `set_active()`. UNLIKE those three
## overlays, opening it ALSO releases keyboard focus and hides `_menu_card`
## (`_on_settings_pressed()`'s own header note has the full reasoning: the
## Hub's buttons use Godot's native focus system, which `ui_up`/`ui_down`/
## `ui_accept` would otherwise keep driving underneath the dimmed overlay).

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
const SHEEP_SHEET: String = TS_ROOT + "Resources/Sheep/HappySheep_All.png"
const MUSIC_STREAM_PATH: String = "res://assets/third_party/opengameart/music/town_theme_rpg.ogg"

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


const SHEEP_FRAME: Vector2i = Vector2i(128, 128)
const SHEEP_IDLE_COUNT: int = 8
const SHEEP_SIZE: Vector2 = Vector2(80.0, 80.0)
const SHEEP_SPOTS: Array = [Vector2(560.0, 470.0), Vector2(650.0, 520.0), Vector2(1400.0, 760.0)]

const MUSIC_VOLUME_DB: float = -14.0 # the calm town theme (D254) plays at the title's own level; the old -22 dB was for the battle theme

const MENU_CARD_MIN_WIDTH: float = 460.0
const SETUP_CARD_MIN_WIDTH: float = 960.0 # PT-UI: wide enough for a name AND a selection word on one picker
const PICKER_BUTTON_MIN_SIZE: Vector2 = Vector2(440.0, 72.0)
const PICKER_ICON_SIDE: int = 40
const BUTTON_MIN_SIZE: Vector2 = Vector2(360.0, 60.0)
const HUB_MENU_BAND_TOP: float = 250.0 # 1080-base px; UX review P0-1
const HUB_MENU_BAND_BOTTOM: float = 1050.0
const RELIC_BUTTON_MIN_SIZE: Vector2 = Vector2(200.0, 104.0) # icon tablets with an EQUIPPED word along the bottom, 4 per row
const RELIC_ICON_SIDE: int = 48
const PICKER_HINT_MIN_HEIGHT: float = 130.0 # three lines at the 37 px floor
const PAGE_RUN: String = "run"
const PAGE_LOADOUT: String = "loadout"
const START_RUN_MIN_SIZE: Vector2 = Vector2(360.0, 84.0) # the primary action, visibly larger
const UI_BASE_HEIGHT: float = 1080.0
## D147, D370: the mobile layout draws the Hub on an 864 px tall logical canvas inside the
## safe area; the card (which already carries its own "War Camp" ribbon) takes the whole
## height and the separate title above it is dropped. The Cores pill sits in the left
## gutter (Register "Hub compact gutter"), the banners flow above the cards, and the
## page area of the Run Setup card scrolls when the cards are taller than what is left.
const COMPACT_LEFT_GUTTER: float = 104.0
const COMPACT_PICKER_HINT_MIN_HEIGHT: float = 88.0 # two lines at the 37 px floor; a third line grows the card and shrinks the scroll area
const COMPACT_MENU_CARD_MIN_WIDTH: float = 400.0
const COMPACT_MENU_CARD_NARROW_WIDTH: float = 360.0 # when the safe width is under 1524 px: the narrow buttons plus the card chrome
const COMPACT_MENU_BUTTON_NARROW_PX: float = 290.0
const COMPACT_ROW_SLACK_PX: float = 40.0 # the cards are a little wider than their minimum (card chrome, scroll bar)

## Harness-only flag (title_screen.gd's own `--debug-panel=` precedent):
## `--debug-panel=skill_tree` / `--debug-panel=records` / `--debug-panel=
## achievements` opens that overlay
## immediately in `_ready()`, since the capture harness cannot simulate a
## button click.
const DEBUG_PANEL_FLAG_PREFIX: String = "--debug-panel="

var _root: Control
var _safe: Control ## D370: the safe-area-fitted parent of everything interactive
var _content_parent: Control
var _menu_center: CenterContainer
## D370: card widths; the compact layout narrows them when the safe width is short (16:9 phone with a cut-out).
var _setup_width: float = SETUP_CARD_MIN_WIDTH
var _menu_width: float = MENU_CARD_MIN_WIDTH
var _menu_button_min_w: float = BUTTON_MIN_SIZE.x
var _picker_min_width: float = PICKER_BUTTON_MIN_SIZE.x
var _relic_min_width: float = RELIC_BUTTON_MIN_SIZE.x
var _page_scroll: ScrollContainer
var _menu_scroll: ScrollContainer
var _menu_column: VBoxContainer
var _banner_column: VBoxContainer
var _fit_pending: bool = false
var _cores_label: Label
var _cores_icon: UiShapeGlyph
var _start_run_button: Button
var _skill_tree_button: Button
var _records_button: Button
var _achievements_button: Button
var _field_guide_button: Button
var _field_guide: FieldGuideScreen
var _settings_button: Button
var _back_to_title_button: Button
var _hint_banner: PanelContainer
var _warning_banner: PanelContainer
var _warning_label: Label
var _music_player: AudioStreamPlayer

var _skill_tree_screen: SkillTreeScreen
var _records_panel: RecordsPanel
var _achievements_panel: AchievementsPanel
var _settings_menu: SettingsMenu
var _menu_card: PanelContainer
var _setup_card: PanelContainer
var _difficulty_buttons: Dictionary = {} # difficulty id -> Button
var _skill_buttons: Dictionary = {} # Battle Skill id -> Button
var _endless_button: Button
## WP-LOADOUT (docs/32 C): the Run Setup card has two pages, "Run" and "Loadout".
var _run_page: VBoxContainer
var _loadout_page: VBoxContainer
var _tab_buttons: Dictionary = {} # page name ("run" / "loadout") -> Button
var _champion_buttons: Dictionary = {} # Champion id -> Button
var _relic_buttons: Dictionary = {} # Relic id -> Button
var _relics_heading: Label
var _picker_hint: Label
var _v3_banner: PanelContainer
var _v3_label: Label
var _suppress_scene_change_for_test: bool = false
var _last_scene_change_for_test: String = ""


func _ready() -> void:
	TouchUi.apply_ui_scale(get_window()) # D147
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaProgress.ensure_loaded()
	var first_visit: bool = not MetaProgress.is_first_hub_seen()
	MetaProgress.mark_hub_seen()
	_build_ui()
	_build_music()
	_refresh_cores_label()
	_hint_banner.visible = first_visit
	_refresh_warning_banner()
	_refresh_v3_banner()
	_refresh_pickers()
	if not MetaProgress.cores_changed.is_connected(_on_cores_changed):
		MetaProgress.cores_changed.connect(_on_cores_changed)
	_start_run_button.grab_focus()
	_apply_debug_panel_flag()


func _exit_tree() -> void:
	if MetaProgress.cores_changed.is_connected(_on_cores_changed):
		MetaProgress.cores_changed.disconnect(_on_cores_changed)


## Blind review fix (item 6): Esc closes Settings on the Hub too, the same
## way it already does in-run (`RunFlowController`) and on the title screen
## (`TitleScreen._handle_ui_cancel()`). No other Hub overlay (Skill Tree,
## Records, Achievements) has an Esc path today -- adding one for those is
## out of this task's scope, named rather than silently extended.
func _handle_ui_cancel() -> bool:
	if _settings_menu.visible:
		_on_settings_closed()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _handle_ui_cancel():
		get_viewport().set_input_as_handled()


## D146: Android Back acts as Escape: Settings, Records and Achievements close.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var cancel := InputEventAction.new()
		cancel.action = &"ui_cancel"
		cancel.pressed = true
		get_viewport().push_input(cancel)


func simulate_ui_cancel_for_test() -> void:
	_handle_ui_cancel()


func _apply_debug_panel_flag() -> void:
	var requested: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(DEBUG_PANEL_FLAG_PREFIX):
			requested = arg.trim_prefix(DEBUG_PANEL_FLAG_PREFIX)
	if requested == "skill_tree":
		_on_skill_tree_pressed()
	elif requested == "records":
		_on_records_pressed()
	elif requested == "achievements":
		_on_achievements_pressed()
	elif requested == "settings":
		_on_settings_pressed()
	elif requested == "loadout":
		_show_page(PAGE_LOADOUT) # WP-LOADOUT capture helper: opens the Loadout tab


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
		MetaProgress.acknowledge_recovered_from_corruption() # one-time banner -- see class header, "BUGFIX" (finding #3)
	elif bool(flags.get("read_only_newer_version", false)):
		text = tr("HUB_WARNING_READ_ONLY")
	elif bool(flags.get("last_save_failed", false)):
		text = tr("HUB_WARNING_SAVE_FAILED")
	_warning_banner.visible = text != ""
	_warning_label.text = text


func _on_start_run_pressed() -> void:
	MetaProgress.apply_selection_to_run_config() # D254: the three persisted choices become the run's RunConfig
	_change_scene("res://scenes/prototype.tscn")


func _change_scene(path: String) -> void:
	_last_scene_change_for_test = path
	if _suppress_scene_change_for_test:
		return
	get_tree().change_scene_to_file(path)


func _on_back_to_title_pressed() -> void:
	_change_scene("res://scenes/title.tscn")


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


func _on_achievements_pressed() -> void:
	_hint_banner.visible = false
	_achievements_panel.set_active(true)


func _on_field_guide_pressed() -> void:
	_hint_banner.visible = false
	get_viewport().gui_release_focus()
	_field_guide.open()


func _on_field_guide_closed() -> void:
	_field_guide_button.grab_focus()


func _on_achievements_back_requested() -> void:
	_achievements_panel.set_active(false)
	_start_run_button.grab_focus()


## Settings screen task, reachability item 4. Blind review fix (item 5):
## the Hub's own menu buttons use Godot's NATIVE focus system
## (`focus_mode = FOCUS_ALL`, `grab_focus()` in `_ready()`), unlike
## `SettingsMenu`'s own poll-driven `move_*`/`confirm` input -- leaving
## `_start_run_button` (or whichever button) focused while Settings is open
## let the engine's own `ui_up`/`ui_down`/`ui_accept` navigate and activate
## the HUB's buttons underneath the overlay. `get_viewport().gui_release_
## focus()` plus hiding `_menu_card` (so nothing in it can be clicked or
## re-focused either) closes both holes -- this NO LONGER matches the
## Skill Tree/Records/Achievements overlays' own choice not to hide
## `MenuCard` (see this class's earlier header note, superseded here for
## Settings specifically): those three overlays do not poll native input at
## all AWAY from Godot's focus system the way Settings' rows do not either,
## so the same focus-bleed risk likely exists there too, but fixing it is
## out of this task's scope.
func _on_settings_pressed() -> void:
	_hint_banner.visible = false
	get_viewport().gui_release_focus()
	_menu_card.visible = false
	_settings_menu.set_active(true)


func _on_settings_closed() -> void:
	_settings_menu.set_active(false)
	_menu_card.visible = true
	_start_run_button.grab_focus()
	# D167: the Settings Back row acts on a finger's press, so the same finger's release
	# lands on whatever button now sits under it (Back to Title on a phone). The card
	# ignores the mouse and touch for a moment; keyboard and gamepad are unaffected.
	_menu_card.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	var timer: SceneTreeTimer = get_tree().create_timer(0.3, true, false, true)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_menu_card):
			_menu_card.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED)


func _on_hint_dismiss_pressed() -> void:
	_hint_banner.visible = false


func _on_warning_dismiss_pressed() -> void:
	_warning_banner.visible = false


## One-time notice after the v2 -> v3 migration (D252): shown until dismissed,
## and the dismissal is saved so it never returns.
func _refresh_v3_banner() -> void:
	var show: bool = MetaProgress.has_v3_notice()
	_v3_banner.visible = show
	if show:
		var refund: int = MetaProgress.get_v3_refund_amount()
		_v3_label.text = tr("HUB_V3_NOTICE") + ((" " + tr("HUB_V3_NOTICE_AMOUNT") % refund) if refund > 0 else "")


func _on_v3_dismiss_pressed() -> void:
	_v3_banner.visible = false
	MetaProgress.acknowledge_v3_notice()


# --- UI construction ----------------------------------------------------------

## Compact layout: gutter + setup card + gap + menu card must fit the safe width. 400 px of menu
## card and the full 960 px setup card need 1488 px; a 16:9 phone with a camera cut-out has about 1400.
func _compute_compact_widths() -> void:
	if not TouchUi.is_mobile_layout():
		_menu_width = MENU_CARD_MIN_WIDTH
		return
	var avail: float = SafeArea.rect(get_window()).size.x - COMPACT_LEFT_GUTTER
	_menu_width = COMPACT_MENU_CARD_MIN_WIDTH if avail >= 1420.0 else COMPACT_MENU_CARD_NARROW_WIDTH
	_menu_button_min_w = BUTTON_MIN_SIZE.x if avail >= 1420.0 else COMPACT_MENU_BUTTON_NARROW_PX
	_setup_width = minf(SETUP_CARD_MIN_WIDTH, avail - _menu_width - float(UiPalette.SPACE_XL) - COMPACT_ROW_SLACK_PX)
	_picker_min_width = minf(PICKER_BUTTON_MIN_SIZE.x, (_setup_width - 72.0) / 2.0)
	_relic_min_width = minf(RELIC_BUTTON_MIN_SIZE.x, (_setup_width - 72.0 - 36.0) / 4.0)


func _build_ui() -> void:
	UiStrings.ensure_registered()
	_compute_compact_widths()
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_background()
	_build_scrim()
	# D370: everything a finger or an eye must reach lives under `Safe`, which keeps
	# clear of the camera cut-out, rounded corners and gesture bar; the backdrop bleeds.
	_safe = Control.new()
	_safe.name = "Safe"
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_safe)
	SafeArea.fit(_safe)
	_content_parent = _safe
	if TouchUi.is_mobile_layout():
		# Compact: a column [banners, cards] to the right of the Cores pill, so nothing overlaps.
		var layout := VBoxContainer.new()
		layout.name = "Layout"
		layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_theme_constant_override("separation", UiPalette.SPACE_S)
		layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layout.offset_left = COMPACT_LEFT_GUTTER
		_safe.add_child(layout)
		_content_parent = layout
	_build_foreground()
	_build_top_bar()
	_build_banners()

	_skill_tree_screen = (preload("res://scenes/ui/skill_tree_screen.tscn") as PackedScene).instantiate() as SkillTreeScreen
	add_child(_skill_tree_screen)
	_skill_tree_screen.back_requested.connect(_on_skill_tree_back_requested)

	_records_panel = (preload("res://scenes/ui/records_panel.tscn") as PackedScene).instantiate() as RecordsPanel
	add_child(_records_panel)
	_records_panel.back_requested.connect(_on_records_back_requested)

	_achievements_panel = (preload("res://scenes/ui/achievements_panel.tscn") as PackedScene).instantiate() as AchievementsPanel
	add_child(_achievements_panel)
	_achievements_panel.back_requested.connect(_on_achievements_back_requested)

	_settings_menu = (preload("res://scenes/ui/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
	add_child(_settings_menu)
	_settings_menu.closed.connect(_on_settings_closed)

	_field_guide = FieldGuideScreen.new()
	_field_guide.name = "FieldGuide"
	add_child(_field_guide)
	_field_guide.closed.connect(_on_field_guide_closed)


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
	# D169: the blank vertical banner that hung above the castle gate carried no meaning and is gone.
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
	if TouchUi.is_mobile_layout():
		_build_menu_card(_content_parent) # the banners are added first by _build_banners(); order fixed there
		return
	var foreground := Control.new()
	foreground.name = "Foreground"
	foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	foreground.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_parent.add_child(foreground)

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
	title.visible = not TouchUi.is_mobile_layout()
	parent.add_child(title)


func _build_menu_card(parent: Control) -> void:
	var center := CenterContainer.new()
	center.name = "MenuCenter"
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_menu_center = center
	if TouchUi.is_mobile_layout():
		# D370: a plain child of the compact column; it takes whatever height the banners leave.
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		parent.add_child(center)
		center.resized.connect(_fit_setup_pages_deferred)
		_build_card_row(center)
		return
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Round 2: the card's own real content (Start Run + 3 buttons + CARD's
	# own texture padding) measures ~372px tall -- centred on the ORIGINAL
	# 720/1050 band (centre y=885) that left only ~9px of clearance above
	# 1080, which read fine at native 1920x1080 but sat right at the bottom
	# edge once scaled down to 1280x720 (canvas_items stretch mode preserves
	# the same relative margin, so a tight fit at one scales to an equally
	# tight fit at the other). Centred higher (y=800) instead, for real
	# clearance at both resolutions.
	# UX review P0-1 (D127): the card now holds ribbon + Start Run + 5 buttons
	# (~600px), so the band spans nearly the whole lower screen and the card is
	# centred inside it; a test asserts every focusable button lies in 1280x720.
	center.offset_top = HUB_MENU_BAND_TOP
	center.offset_bottom = HUB_MENU_BAND_BOTTOM - UI_BASE_HEIGHT # the band's bottom margin, so any canvas height works
	parent.add_child(center)
	center.resized.connect(_fit_setup_pages_deferred)
	_build_card_row(center)


func _build_card_row(center: CenterContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "CardRow"
	row.theme_type_variation = UiTheme.hbox("XL")
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(row)

	_build_setup_card(row)

	var card := PanelContainer.new()
	card.name = "MenuCard"
	card.theme_type_variation = UiTheme.CARD
	card.theme = UiTheme.get_parchment_theme() # D166: dark ink on parchment
	card.custom_minimum_size = Vector2(_menu_width, 0.0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(card)
	_menu_card = card # Settings screen task, blind review fix (item 5): toggled while Settings is open, see _on_settings_pressed()/_on_settings_closed()

	var column := VBoxContainer.new()
	column.name = "MenuColumn"
	column.theme_type_variation = UiTheme.vbox("M")
	_menu_column = column
	# D370: the menu column scrolls only when the safe height (less any notice above) is shorter than it.
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.name = "MenuScroll"
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(_menu_scroll)
	var menu_pad := MarginContainer.new()
	menu_pad.name = "MenuPad"
	menu_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_pad.add_theme_constant_override("margin_right", 12)
	menu_pad.add_theme_constant_override("margin_bottom", 12)
	_menu_scroll.add_child(menu_pad)
	menu_pad.add_child(column)

	# Review fix (D249): the page title above the card already says "War Camp", so
	# the card's own ribbon only appears where that title is hidden (the touch layout).
	if TouchUi.is_mobile_layout():
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

	_skill_tree_button = _make_menu_button(tr("HUB_SKILL_TREE"))
	_skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	column.add_child(_skill_tree_button)

	_records_button = _make_menu_button(tr("HUB_RECORDS"))
	_records_button.pressed.connect(_on_records_pressed)
	column.add_child(_records_button)

	_achievements_button = _make_menu_button(tr("HUB_ACHIEVEMENTS"))
	_achievements_button.pressed.connect(_on_achievements_pressed)
	column.add_child(_achievements_button)

	_field_guide_button = _make_menu_button(tr("FG_OPEN")) # PT-UI (docs/33 A3)
	_field_guide_button.name = "FieldGuideButton"
	_field_guide_button.pressed.connect(_on_field_guide_pressed)
	column.add_child(_field_guide_button)

	_settings_button = _make_menu_button(tr("HUB_SETTINGS"))
	_settings_button.pressed.connect(_on_settings_pressed)
	column.add_child(_settings_button)

	_back_to_title_button = _make_menu_button(tr("HUB_BACK_TO_TITLE"))
	_back_to_title_button.pressed.connect(_on_back_to_title_pressed)
	column.add_child(_back_to_title_button)


## The Run Setup card (see class header). Built from plain Buttons so the native
## focus chain, mouse and touch all work; a locked option is a greyed tablet.
func _build_setup_card(parent: Container) -> void:
	var card := PanelContainer.new()
	card.name = "SetupCard"
	card.theme_type_variation = UiTheme.CARD
	card.theme = UiTheme.get_parchment_theme()
	card.custom_minimum_size = Vector2(_setup_width, 0.0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(card)
	_setup_card = card

	var column := VBoxContainer.new()
	column.name = "SetupColumn"
	card.add_child(column)

	column.add_child(_build_tab_row())

	# D370: the pages sit in a scroll area (horizontal off) that only scrolls when the card would
	# otherwise be taller than the screen; `_fit_setup_pages()` sizes it.
	_page_scroll = ScrollContainer.new()
	_page_scroll.name = "PageScroll"
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_page_scroll)
	# The selection badges hang over a picker's top-right corner and the locked reason plates below
	# its bottom edge (D320); the scroll clips to its rect, so the pages get room around them.
	var pad := MarginContainer.new()
	pad.name = "PagePad"
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 16)
	_page_scroll.add_child(pad)
	var pages := VBoxContainer.new()
	pages.name = "Pages"
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(pages)

	_run_page = VBoxContainer.new()
	_run_page.name = "RunPage"
	pages.add_child(_run_page)
	_run_page.add_child(_make_picker_heading(tr("HUB_DIFFICULTY")))
	var diff_grid := GridContainer.new()
	diff_grid.name = "DifficultyGrid"
	diff_grid.columns = 2
	diff_grid.add_theme_constant_override("h_separation", UiPalette.SPACE_M)
	diff_grid.add_theme_constant_override("v_separation", UiPalette.SPACE_S)
	_run_page.add_child(diff_grid)
	for profile in RunConfig.get_all_difficulties():
		var button: Button = _make_picker_button(profile.display_name, AbilityIds.icon_path(profile.id))
		button.name = "Difficulty_%s" % profile.id
		button.pressed.connect(_on_difficulty_pressed.bind(profile.id))
		button.focus_entered.connect(_on_difficulty_focused.bind(profile.id))
		button.mouse_entered.connect(_on_difficulty_focused.bind(profile.id))
		diff_grid.add_child(button)
		_difficulty_buttons[profile.id] = button

	_run_page.add_child(_make_picker_heading(tr("HUB_BATTLE_SKILL")))
	var skill_grid := GridContainer.new()
	skill_grid.name = "SkillGrid"
	skill_grid.columns = 2
	skill_grid.add_theme_constant_override("h_separation", UiPalette.SPACE_M)
	skill_grid.add_theme_constant_override("v_separation", UiPalette.SPACE_S)
	_run_page.add_child(skill_grid)
	for skill_id in AbilityIds.BATTLE_SKILLS:
		var button: Button = _make_picker_button(AbilityDisplay.display_name(skill_id), AbilityIds.icon_path(skill_id))
		button.name = "Skill_%s" % skill_id
		button.pressed.connect(_on_skill_pressed.bind(skill_id))
		button.focus_entered.connect(_on_skill_focused.bind(skill_id))
		button.mouse_entered.connect(_on_skill_focused.bind(skill_id))
		skill_grid.add_child(button)
		_skill_buttons[skill_id] = button

	_endless_button = _make_picker_button(tr("HUB_ENDLESS_OFF"), AbilityIds.icon_path("timer"))
	_endless_button.name = "EndlessToggle"
	_endless_button.toggle_mode = true
	_endless_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_endless_button.toggled.connect(_on_endless_toggled)
	_endless_button.focus_entered.connect(_on_endless_focused)
	_run_page.add_child(_endless_button)


	_loadout_page = _build_loadout_page()
	pages.add_child(_loadout_page)

	_picker_hint = Label.new()
	_picker_hint.name = "PickerHint"
	_picker_hint.theme_type_variation = UiTheme.DIM_PARCHMENT
	_picker_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_picker_hint.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_picker_hint.custom_minimum_size = Vector2(_setup_width - 60.0, COMPACT_PICKER_HINT_MIN_HEIGHT if TouchUi.is_mobile_layout() else PICKER_HINT_MIN_HEIGHT)
	_picker_hint.minimum_size_changed.connect(_fit_setup_pages_deferred) # a third line takes room from the page area, never from Start Run
	column.add_child(_picker_hint)

	_start_run_button = Button.new()
	_start_run_button.name = "StartRunButton"
	_start_run_button.text = tr("HUB_START_RUN_SETUP")
	_start_run_button.custom_minimum_size = TouchUi.touch_size(START_RUN_MIN_SIZE)
	_start_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_run_button.focus_mode = Control.FOCUS_ALL
	_start_run_button.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_VALUE)
	_start_run_button.pressed.connect(_on_start_run_pressed)
	column.add_child(_start_run_button)
	SelectableState.attach(_start_run_button, SelectableState.RibbonSide.RIGHT)


## The "Run | Loadout" tab strip. Plain toggle Buttons in a ButtonGroup, so focus,
## mouse and touch all work like every other picker.
func _build_tab_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SetupTabs"
	row.add_theme_constant_override("separation", UiPalette.SPACE_M)
	var group := ButtonGroup.new()
	for page in [PAGE_RUN, PAGE_LOADOUT]:
		var button := Button.new()
		button.name = "Tab_%s" % page
		button.text = tr("HUB_TAB_RUN") if page == PAGE_RUN else tr("HUB_TAB_LOADOUT")
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = TouchUi.touch_size(Vector2(0.0, 64.0))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_pressed_color", UiPalette.ACCENT)
		button.add_theme_color_override("font_hover_pressed_color", UiPalette.ACCENT)
		button.pressed.connect(_show_page.bind(page))
		row.add_child(button)
		_tab_buttons[page] = button
		var overlay: SelectableState = SelectableState.attach(button, SelectableState.RibbonSide.RIGHT)
		button.toggled.connect(overlay.set_selected.bind(""))
	(_tab_buttons[PAGE_RUN] as Button).set_pressed_no_signal(true)
	SelectableState.of(_tab_buttons[PAGE_RUN]).set_selected(true)
	return row


## Champion picker (2 x 2, icon + name) and the Relic grid (4 x 2 icon tablets).
func _build_loadout_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = "LoadoutPage"
	page.visible = false
	page.add_child(_make_picker_heading(tr("HUB_CHAMPION")))
	var champion_grid := GridContainer.new()
	champion_grid.name = "ChampionGrid"
	champion_grid.columns = 2
	champion_grid.add_theme_constant_override("h_separation", UiPalette.SPACE_M)
	champion_grid.add_theme_constant_override("v_separation", UiPalette.SPACE_S)
	page.add_child(champion_grid)
	for id in LoadoutCatalog.CHAMPION_IDS:
		var button: Button = _make_picker_button(LoadoutCatalog.display_name(id), LoadoutCatalog.icon_path(id))
		button.name = "Champion_%s" % id
		button.pressed.connect(_on_champion_pressed.bind(id))
		button.focus_entered.connect(_set_hint_for_champion.bind(id))
		button.mouse_entered.connect(_set_hint_for_champion.bind(id))
		champion_grid.add_child(button)
		_champion_buttons[id] = button

	_relics_heading = _make_picker_heading("")
	_relics_heading.name = "RelicsHeading"
	page.add_child(_relics_heading)
	var relic_grid := GridContainer.new()
	relic_grid.name = "RelicGrid"
	relic_grid.columns = 4
	relic_grid.add_theme_constant_override("h_separation", UiPalette.SPACE_M)
	relic_grid.add_theme_constant_override("v_separation", UiPalette.SPACE_S)
	page.add_child(relic_grid)
	for id in LoadoutCatalog.RELIC_IDS:
		var button := Button.new()
		button.name = "Relic_%s" % id
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = TouchUi.touch_size(Vector2(_relic_min_width, RELIC_BUTTON_MIN_SIZE.y))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width", RELIC_ICON_SIDE)
		if ResourceLoader.exists(LoadoutCatalog.icon_path(id)):
			button.icon = load(LoadoutCatalog.icon_path(id)) as Texture2D
		button.pressed.connect(_on_relic_pressed.bind(id))
		SelectableState.attach(button, SelectableState.RibbonSide.BOTTOM)
		button.focus_entered.connect(_set_hint_for_relic.bind(id))
		button.mouse_entered.connect(_set_hint_for_relic.bind(id))
		relic_grid.add_child(button)
		_relic_buttons[id] = button
	return page


func _fit_setup_pages_deferred() -> void:
	if _fit_pending:
		return
	_fit_pending = true
	_fit_setup_pages.call_deferred()


## D370: caps the Run Setup card to the height the band leaves and gives its page area exactly
## the room that is left (it scrolls by touch drag or wheel only when the pages are taller).
func _fit_setup_pages() -> void:
	_fit_pending = false
	if _page_scroll == null or _setup_card == null or _menu_center == null or not is_inside_tree():
		return
	var usable: float = _menu_center.size.y
	if usable < 200.0:
		return
	_page_scroll.custom_minimum_size.y = 0.0
	var fixed: float = _setup_card.get_combined_minimum_size().y
	var content: float = maxf(_run_page.get_combined_minimum_size().y, _loadout_page.get_combined_minimum_size().y) + 28.0 # PagePad's top and bottom
	_page_scroll.custom_minimum_size.y = minf(content, maxf(160.0, usable - fixed - 8.0)) # 8 px of slack for the layout's own rounding
	if _menu_scroll != null and _menu_card != null:
		_menu_scroll.custom_minimum_size.y = 0.0
		var menu_fixed: float = _menu_card.get_combined_minimum_size().y
		var menu_content: float = _menu_column.get_combined_minimum_size().y + 12.0 # MenuPad's bottom
		_menu_scroll.custom_minimum_size.y = minf(menu_content, maxf(160.0, usable - menu_fixed - 8.0))


func _show_page(page: String) -> void:
	_run_page.visible = page == PAGE_RUN
	_loadout_page.visible = page == PAGE_LOADOUT
	_fit_setup_pages_deferred()
	(_tab_buttons[page] as Button).button_pressed = true # the ButtonGroup releases the other tab; only `pressed` is connected, so this does not recurse
	if page == PAGE_LOADOUT:
		_set_hint_for_champion(MetaProgress.get_selected_champion())
	else:
		_set_hint_for_difficulty(MetaProgress.get_selected_difficulty())


func _make_picker_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UiTheme.DIM_PARCHMENT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_picker_button(text: String, icon_path: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = TouchUi.touch_size(Vector2(_picker_min_width, PICKER_BUTTON_MIN_SIZE.y))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT # PT-UI: the name sits beside the icon, the state word on the right
	button.add_theme_constant_override("icon_max_width", PICKER_ICON_SIDE)
	button.add_theme_color_override("font_pressed_color", UiPalette.ACCENT)
	button.add_theme_color_override("font_hover_pressed_color", UiPalette.ACCENT)
	if ResourceLoader.exists(icon_path):
		button.icon = load(icon_path) as Texture2D
	SelectableState.attach(button, SelectableState.RibbonSide.RIGHT) # PT-UI: focused / selected / locked language
	return button


# --- Pickers (D254) --------------------------------------------------------------

## Re-reads the profile and restyles every picker button: the chosen one is
## pressed, a locked one is a greyed tablet. Hides the Endless toggle until a
## victory has unlocked it.
func _refresh_pickers() -> void:
	var difficulty: String = MetaProgress.get_selected_difficulty()
	for id in _difficulty_buttons.keys():
		var button: Button = _difficulty_buttons[id]
		var unlocked: bool = MetaProgress.is_difficulty_unlocked(id)
		button.set_pressed_no_signal(unlocked and id == difficulty)
		_style_pick(button, unlocked and id == difficulty, not unlocked, "" if unlocked else SelectionReasons.difficulty(RunConfig.get_difficulty_by_id(id)))
	var skill: String = MetaProgress.get_selected_battle_skill()
	for id in _skill_buttons.keys():
		var button: Button = _skill_buttons[id]
		var unlocked: bool = MetaProgress.is_battle_skill_unlocked(id)
		button.set_pressed_no_signal(unlocked and id == skill)
		_style_pick(button, unlocked and id == skill, not unlocked, "" if unlocked else SelectionReasons.battle_skill(id))
	var endless_open: bool = MetaProgress.is_endless_unlocked()
	_endless_button.visible = endless_open
	_endless_button.set_pressed_no_signal(MetaProgress.get_selected_endless())
	_style_pick(_endless_button, MetaProgress.get_selected_endless(), false)
	_endless_button.text = tr("HUB_ENDLESS_ON") if _endless_button.button_pressed else tr("HUB_ENDLESS_OFF")
	_refresh_loadout_pickers()
	_set_hint_for_difficulty(difficulty)
	_fit_setup_pages_deferred()


## Champions and Relics: the chosen ones are pressed, locked ones are greyed tablets.
func _refresh_loadout_pickers() -> void:
	var champion: String = MetaProgress.get_selected_champion()
	for id in _champion_buttons.keys():
		var button: Button = _champion_buttons[id]
		var unlocked: bool = MetaProgress.is_champion_unlocked(id)
		button.set_pressed_no_signal(unlocked and id == champion)
		_style_pick(button, unlocked and id == champion, not unlocked, "" if unlocked else SelectionReasons.loadout(id))
	var equipped: Array[String] = MetaProgress.get_selected_relics()
	for id in _relic_buttons.keys():
		var button: Button = _relic_buttons[id]
		var unlocked: bool = MetaProgress.is_relic_unlocked(id)
		button.set_pressed_no_signal(unlocked and equipped.has(id))
		_style_pick(button, unlocked and equipped.has(id), not unlocked, "" if unlocked else SelectionReasons.loadout(id), tr("SEL_EQUIPPED"))
	_relics_heading.text = tr("HUB_RELICS") % [equipped.size(), MetaProgress.get_relic_slot_count()]


## PT-UI (docs/33 A1): the shared selection language on a picker. `word` names the
## selected state (SELECTED by default, EQUIPPED for a Relic); a locked one carries its reason.
func _style_pick(button: Button, selected: bool, locked: bool, reason: String = "", word: String = "") -> void:
	_style_locked(button, locked)
	var overlay: SelectableState = SelectableState.of(button)
	if overlay == null:
		return
	overlay.set_locked(locked, reason)
	overlay.set_selected(selected and not locked, word)


## A press on a locked picker shakes it and shows why (never a silent ignore).
func _press_locked_feedback(button: Button) -> void:
	var overlay: SelectableState = SelectableState.of(button)
	if overlay != null:
		overlay.press_locked()


func _style_locked(button: Button, locked: bool) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		if locked:
			button.add_theme_stylebox_override(state, UiTheme.make_texture_box(UiPalette.TEX_BUTTON_DISABLED, UiPalette.NODE_TEXTURE_MARGIN, 6))
		else:
			button.remove_theme_stylebox_override(state)
	if locked:
		button.add_theme_color_override("font_color", UiPalette.TEXT_DISABLED)
	else:
		button.remove_theme_color_override("font_color")
	button.modulate = Color(1, 1, 1, 0.75) if locked else Color(1, 1, 1, 1)


func _on_difficulty_pressed(id: String) -> void:
	var accepted: bool = MetaProgress.set_selected_difficulty(id)
	_refresh_pickers() # a locked (refused) toggle button switched itself on; this puts it back
	if not accepted:
		_set_hint_for_difficulty(id)
		_press_locked_feedback(_difficulty_buttons[id])


func _on_difficulty_focused(id: String) -> void:
	_set_hint_for_difficulty(id)


func _on_skill_pressed(id: String) -> void:
	var accepted: bool = MetaProgress.set_selected_battle_skill(id)
	_refresh_pickers()
	_set_hint_for_skill(id)
	if not accepted:
		_press_locked_feedback(_skill_buttons[id])


func _on_skill_focused(id: String) -> void:
	_set_hint_for_skill(id)


func _on_champion_pressed(id: String) -> void:
	var accepted: bool = MetaProgress.set_selected_champion(id)
	_refresh_loadout_pickers() # a refused (locked) toggle snaps back
	_set_hint_for_champion(id)
	if not accepted:
		_press_locked_feedback(_champion_buttons[id])


func _on_relic_pressed(id: String) -> void:
	var accepted: bool = MetaProgress.toggle_selected_relic(id)
	_refresh_loadout_pickers()
	_set_hint_for_relic(id)
	if not accepted and not MetaProgress.is_relic_unlocked(id):
		_press_locked_feedback(_relic_buttons[id])


## Twist, then the downside; a locked Champion says how to earn it.
func _set_hint_for_champion(id: String) -> void:
	if _picker_hint == null:
		return
	if MetaProgress.is_champion_unlocked(id):
		_picker_hint.text = "%s: %s\n%s" % [LoadoutCatalog.display_name(id), LoadoutCatalog.twist_text(id), tr("LOADOUT_DOWNSIDE") % LoadoutCatalog.downside_text(id)]
	else:
		_picker_hint.text = "%s. %s" % [LoadoutCatalog.display_name(id), LoadoutCatalog.unlock_text(id)]


## A Relic's effect, or what unlocks it. With one slot open, the hint also says when the second opens.
func _set_hint_for_relic(id: String) -> void:
	if _picker_hint == null:
		return
	var text: String
	if MetaProgress.is_relic_unlocked(id):
		text = "%s: %s" % [LoadoutCatalog.display_name(id), LoadoutCatalog.twist_text(id)]
	else:
		text = "%s. %s" % [LoadoutCatalog.display_name(id), LoadoutCatalog.unlock_text(id)]
	if MetaProgress.get_relic_slot_count() < LoadoutCatalog.RELIC_SLOTS_MAX:
		text += "\n" + tr("HUB_RELIC_SLOT2")
	_picker_hint.text = text


func _on_endless_toggled(on: bool) -> void:
	MetaProgress.set_selected_endless(on)
	_refresh_pickers()
	_picker_hint.text = tr("HUB_ENDLESS_HINT")


func _on_endless_focused() -> void:
	_picker_hint.text = tr("HUB_ENDLESS_HINT")


## The hint line says what the option does, or, for a locked one, what opens it.
func _set_hint_for_difficulty(id: String) -> void:
	if _picker_hint == null:
		return
	var profile: DifficultyProfile = RunConfig.get_difficulty_by_id(id)
	if MetaProgress.is_difficulty_unlocked(id):
		_picker_hint.text = "%s (Cores x%s)" % [profile.description, String.num(profile.cores_multiplier, 2).rstrip("0").rstrip(".")]
	else:
		_picker_hint.text = tr("HUB_LOCKED_DIFFICULTY") % RunConfig.get_difficulty_by_id(profile.unlocked_by_victory_on).display_name


func _set_hint_for_skill(id: String) -> void:
	if _picker_hint == null:
		return
	if MetaProgress.is_battle_skill_unlocked(id):
		_picker_hint.text = tr("ABILITY_DESC_%s" % id.to_upper())
	else:
		var node: SkillNodeDefinition = MetaProgress.skill_tree.get_node_definition(MetaProgress.get_battle_skill_unlock_node_id(id))
		_picker_hint.text = tr("HUB_LOCKED_SKILL") % (node.display_name if node != null else id)


func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = TouchUi.touch_size(Vector2(_menu_button_min_w, BUTTON_MIN_SIZE.y))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_VALUE) # D166: main menu buttons read at 56
	SelectableState.attach(button, SelectableState.RibbonSide.RIGHT) # PT-UI: the focused cue on every menu button
	return button


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.theme_type_variation = UiTheme.hbox("L")
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	bar.offset_left = 0.0 if TouchUi.is_mobile_layout() else UiPalette.SCREEN_MARGIN # D370: the safe margin already insets a phone
	bar.offset_top = 0.0 if TouchUi.is_mobile_layout() else UiPalette.SCREEN_MARGIN
	_safe.add_child(bar)

	var cores_pill := PanelContainer.new()
	cores_pill.name = "CoresPill"
	cores_pill.theme_type_variation = UiTheme.PILL
	bar.add_child(cores_pill)

	var cores_row := HBoxContainer.new()
	cores_row.theme_type_variation = UiTheme.hbox("XS")
	cores_pill.add_child(cores_row)

	_cores_icon = UiShapeGlyph.new()
	_cores_icon.name = "CoresIcon"
	_cores_icon.shape = UiShapeGlyph.Shape.CORE
	_cores_icon.glyph_color = UiPalette.CORES
	_cores_icon.set_side(32)
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
	_banner_column = column
	if TouchUi.is_mobile_layout():
		# D370: banners flow above the cards in the compact column (the pill sits in the gutter),
		# so a banner can never overlap a card; the Run Setup pages scroll to make room.
		_content_parent.add_child(column)
		_content_parent.move_child(column, 0)
	else:
		column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		column.offset_top = 100.0
		column.offset_left = 660.0
		column.offset_right = -660.0
		_safe.add_child(column)

	_hint_banner = _build_banner(column, "HintBanner", tr("HUB_FIRST_VISIT_HINT"), tr("HUB_HINT_DISMISS"), _on_hint_dismiss_pressed)
	_warning_banner = _build_banner(column, "WarningBanner", "", tr("HUB_HINT_DISMISS"), _on_warning_dismiss_pressed)
	_warning_label = _warning_banner.get_node("Row/Label") as Label
	_warning_banner.visible = false
	_v3_banner = _build_banner(column, "V3NoticeBanner", tr("HUB_V3_NOTICE"), tr("HUB_HINT_DISMISS"), _on_v3_dismiss_pressed)
	_v3_label = _v3_banner.get_node("Row/Label") as Label
	_v3_banner.visible = false


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
	label.theme_type_variation = UiTheme.DIM_PARCHMENT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(240.0 if TouchUi.is_mobile_layout() else 420.0, 0.0)
	row.add_child(label)

	var dismiss := Button.new()
	dismiss.name = "DismissButton"
	dismiss.text = dismiss_text
	dismiss.custom_minimum_size = TouchUi.button_size(Vector2(140.0, 48.0))
	dismiss.pressed.connect(on_dismiss)
	row.add_child(dismiss)

	return panel


func _build_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	_music_player.volume_db = MUSIC_VOLUME_DB
	var stream: AudioStream = load(MUSIC_STREAM_PATH) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true # looping; the finished handler below stays as a fallback
	_music_player.stream = stream
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


func get_field_guide_button_for_test() -> Button:
	return _field_guide_button


func get_field_guide_for_test() -> FieldGuideScreen:
	return _field_guide


func get_achievements_button_for_test() -> Button:
	return _achievements_button


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


func get_achievements_panel_for_test() -> AchievementsPanel:
	return _achievements_panel


func get_settings_button_for_test() -> Button:
	return _settings_button


func get_settings_menu_for_test() -> SettingsMenu:
	return _settings_menu


func get_menu_card_for_test() -> PanelContainer:
	return _menu_card


func get_setup_card_for_test() -> PanelContainer:
	return _setup_card


func get_difficulty_button_for_test(id: String) -> Button:
	return _difficulty_buttons.get(id)


func get_skill_button_for_test(id: String) -> Button:
	return _skill_buttons.get(id)


func get_champion_button_for_test(id: String) -> Button:
	return _champion_buttons.get(id) as Button


func get_relic_button_for_test(id: String) -> Button:
	return _relic_buttons.get(id) as Button


func get_relics_heading_for_test() -> Label:
	return _relics_heading


func get_tab_button_for_test(page: String) -> Button:
	return _tab_buttons.get(page) as Button


func get_run_page_for_test() -> Control:
	return _run_page


func get_loadout_page_for_test() -> Control:
	return _loadout_page


func show_page_for_test(page: String) -> void:
	_show_page(page)


func press_champion_for_test(id: String) -> void:
	_on_champion_pressed(id)


func press_relic_for_test(id: String) -> void:
	_on_relic_pressed(id)


func get_endless_button_for_test() -> Button:
	return _endless_button


func get_picker_hint_for_test() -> Label:
	return _picker_hint


func get_v3_banner_for_test() -> PanelContainer:
	return _v3_banner


func set_suppress_scene_change_for_test(suppress: bool) -> void:
	_suppress_scene_change_for_test = suppress


func get_last_scene_change_for_test() -> String:
	return _last_scene_change_for_test


func press_difficulty_for_test(id: String) -> void:
	_on_difficulty_pressed(id)


func press_skill_for_test(id: String) -> void:
	_on_skill_pressed(id)


func get_music_player_for_test() -> AudioStreamPlayer:
	return _music_player
