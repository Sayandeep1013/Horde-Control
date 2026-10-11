extends CanvasLayer
class_name AchievementsPanel

## Achievements panel (Hub/War Camp; D118). Opened from `HubScreen`'s own
## "Achievements" button, mirroring `RecordsPanel`'s exact
## instantiate-once / `set_active()` / read-only-rows-from-a-MetaProgress-
## query pattern (that file's own header) -- a small centred modal card
## listing every authored achievement (`MetaProgress.achievement_list`),
## its unlocked/locked state, and a progress figure for the two lifetime-
## counter metrics.
##
## Read-only: this screen never mutates `MetaProgress`, exactly like
## `RecordsPanel`.
##
## ## v1.0 (D251, WP-META)
## 16 achievements, each with its pixel icon and a progress bar fed by
## `MetaProgress.get_achievement_progress()` ("1240 / 2000"). A per-run
## achievement (reach wave 8, clear a wave untouched, ...) has no lifetime
## figure, so its bar stays empty with the label "In one run" until earned.

signal back_requested()

const ACHIEVEMENTS_CANVAS_LAYER: int = 5
const ROW_LABEL_MIN_WIDTH: float = 460.0
const ROW_VALUE_MIN_WIDTH: float = 300.0
const ICON_SIDE: float = 64.0
const BAR_HEIGHT: float = 22.0

## D147: height of the scrolling list on the mobile layout (720-base px).
const MOBILE_SCROLL_HEIGHT: float = 380.0

var _rows_parent: Container
var _rows_scroll: ScrollContainer

var _frame: MenuFrame.Parts
var _back_button: Button
var _rows: Dictionary = {} # String (achievement id) -> Label (the value cell)
var _bars: Dictionary = {} # String (achievement id) -> ProgressBar
var _icons: Dictionary = {} # String (achievement id) -> TextureRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = ACHIEVEMENTS_CANVAS_LAYER
	visible = false
	_build_ui()


func set_active(active: bool) -> void:
	visible = active
	if active:
		_refresh()
		MenuFrame.fit_scroll(_frame, _rows_scroll, get_viewport().get_visible_rect().size.y)
		MenuFrame.animate_in(_frame)
	else:
		MenuFrame.reset_motion(_frame)


func is_active_for_test() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if MetaProgress.achievement_list == null:
		return
	for achievement in MetaProgress.achievement_list.achievements:
		if achievement == null or not _rows.has(achievement.id):
			continue
		var progress: Dictionary = MetaProgress.get_achievement_progress(achievement.id)
		var unlocked: bool = bool(progress.get("unlocked", false))
		var value_label: Label = _rows[achievement.id]
		value_label.text = _status_text(achievement, progress)
		# UX review item 8 (D132): unlocked reads at a glance (colour is
		# redundant; the word "Unlocked" is the primary signal).
		if unlocked:
			value_label.add_theme_color_override("font_color", UiPalette.SUCCESS_ON_PARCHMENT)
		else:
			value_label.remove_theme_color_override("font_color")
		var bar: ProgressBar = _bars[achievement.id]
		bar.value = float(progress.get("fraction", 0.0)) * bar.max_value
		(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = UiPalette.SUCCESS_ON_PARCHMENT if unlocked else UiPalette.TOWER
		var icon: TextureRect = _icons[achievement.id]
		icon.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.55, 0.55, 0.55, 0.9)


## Unlocked: "Unlocked". Locked, cumulative metric: "n / threshold". Locked,
## per-run metric: "In one run" -- there is no lifetime figure for a condition
## that resets every run.
func _status_text(achievement: AchievementDefinition, progress: Dictionary) -> String:
	if bool(progress.get("unlocked", false)):
		return tr("ACHIEVEMENTS_UNLOCKED")
	if bool(progress.get("per_run", false)):
		return tr("ACHIEVEMENTS_PER_RUN")
	return "%d / %d" % [int(progress.get("current", 0.0)), int(achievement.threshold)]


## "Unlocks card: Multishot" / "Reward: +1 Draft reroll". Figures come from the
## same constants the perks are applied with, never a second copy.
static func reward_text(achievement: AchievementDefinition) -> String:
	if achievement.unlocks_card_id != "":
		return TranslationServer.translate("ACHIEVEMENTS_REWARD_CARD") % AbilityDisplay.display_name(achievement.unlocks_card_id)
	match achievement.perk_id:
		"bonus_reroll":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % TranslationServer.translate("ACHIEVEMENTS_PERK_REROLL")
		"weapon_damage_bonus":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % (TranslationServer.translate("ACHIEVEMENTS_PERK_DAMAGE") % roundi(MetaLoadoutApplier.ACHIEVEMENT_WEAPON_DAMAGE_BONUS * 100.0))
		"settlement_cores_bonus":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % (TranslationServer.translate("ACHIEVEMENTS_PERK_CORES") % roundi(MetaProgress.ACHIEVEMENT_SETTLEMENT_CORES_BONUS * 100.0))
		"settlement_cores_bonus_regicide":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % (TranslationServer.translate("ACHIEVEMENTS_PERK_REGICIDE") % roundi(MetaProgress.ACHIEVEMENT_REGICIDE_CORES_BONUS * 100.0))
		"move_speed_bonus":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % (TranslationServer.translate("ACHIEVEMENTS_PERK_MOVE_SPEED") % roundi(MetaLoadoutApplier.ACHIEVEMENT_MOVE_SPEED_BONUS * 100.0))
		"repair_bonus":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % (TranslationServer.translate("ACHIEVEMENTS_PERK_REPAIR") % roundi(MetaLoadoutApplier.ACHIEVEMENT_REPAIR_BONUS * 100.0))
		"luck_bonus":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % (TranslationServer.translate("ACHIEVEMENTS_PERK_LUCK") % MetaLoadoutApplier.ACHIEVEMENT_LUCK_BONUS)
		"xp_bonus":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % (TranslationServer.translate("ACHIEVEMENTS_PERK_XP") % roundi(MetaLoadoutApplier.ACHIEVEMENT_XP_BONUS * 100.0))
		"ability_damage_bonus":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % (TranslationServer.translate("ACHIEVEMENTS_PERK_ABILITY_DAMAGE") % roundi(MetaLoadoutApplier.ACHIEVEMENT_ABILITY_DAMAGE_BONUS * 100.0))
		"start_scrap_bonus":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % (TranslationServer.translate("ACHIEVEMENTS_PERK_START_SCRAP") % MetaLoadoutApplier.ACHIEVEMENT_START_SCRAP_BONUS)
		"warlord_title":
			return TranslationServer.translate("ACHIEVEMENTS_REWARD_PERK") % TranslationServer.translate("ACHIEVEMENTS_PERK_WARLORD")
	return ""


func _build_ui() -> void:
	UiStrings.ensure_registered()
	_frame = MenuFrame.build(self, 0.8, "L")

	MenuFrame.build_title(_frame.column, tr("ACHIEVEMENTS_TITLE"), UiTheme.HEADING, 480.0)
	MenuFrame.build_separator(_frame.column)

	# D147: on the 720 px tall mobile canvas the rows do not fit above the Back
	# button, so they scroll by finger drag inside a capped area (docs/19 >
	# "Max Dimensions": a container over 30% of the screen scrolls).
	_rows_parent = _frame.column
	# D166/D167: with 37 px text the list does not fit on any screen, so it always scrolls.
	if true:
		var scroll := ScrollContainer.new()
		scroll.name = "RowsScroll"
		scroll.custom_minimum_size = Vector2(0.0, MOBILE_SCROLL_HEIGHT)
		_rows_scroll = scroll
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_frame.column.add_child(scroll)
		var inner := VBoxContainer.new()
		inner.name = "RowsColumn"
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.theme_type_variation = UiTheme.vbox("XS")
		scroll.add_child(inner)
		_rows_parent = inner
	if MetaProgress.achievement_list != null:
		for achievement in MetaProgress.achievement_list.achievements:
			if achievement != null:
				_build_row(achievement)

	MenuFrame.build_separator(_frame.column)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = tr("ACHIEVEMENTS_BACK")
	_back_button.custom_minimum_size = TouchUi.button_size(Vector2(220, 56))
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	_frame.column.add_child(_back_button)


func _build_row(achievement: AchievementDefinition) -> void:
	var row := PanelContainer.new()
	row.name = "%sRow" % achievement.id.capitalize().replace(" ", "")
	row.theme_type_variation = UiTheme.ROW
	row.mouse_filter = Control.MOUSE_FILTER_PASS # lets a finger drag scroll the list
	_rows_parent.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.theme_type_variation = UiTheme.hbox("L")
	row.add_child(hbox)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = "res://assets/ui/icons/icon_%s.png" % achievement.icon_id
	if achievement.icon_id != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	hbox.add_child(icon)
	_icons[achievement.id] = icon

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(column)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = achievement.display_name
	name_label.theme_type_variation = UiTheme.VALUE
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(ROW_LABEL_MIN_WIDTH, 0.0)
	column.add_child(name_label)

	var description_label := Label.new()
	description_label.text = achievement.description
	description_label.theme_type_variation = UiTheme.DIM_PARCHMENT
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(ROW_LABEL_MIN_WIDTH, 0.0)
	column.add_child(description_label)

	# UX review item 8 (D132): the reward is always shown (D118 achievements
	# unlock a Draft card or a small permanent perk).
	var reward_label := Label.new()
	reward_label.name = "Reward"
	reward_label.text = reward_text(achievement)
	reward_label.theme_type_variation = UiTheme.DIM_PARCHMENT
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.custom_minimum_size = Vector2(ROW_LABEL_MIN_WIDTH, 0.0)
	column.add_child(reward_label)

	var progress_column := VBoxContainer.new()
	progress_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_column.custom_minimum_size = Vector2(ROW_VALUE_MIN_WIDTH, 0.0)
	hbox.add_child(progress_column)

	var value := Label.new()
	value.name = "Value"
	value.theme_type_variation = UiTheme.HUD_VALUE
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_column.add_child(value)

	var bar := ProgressBar.new()
	bar.name = "Progress"
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	bar.add_theme_stylebox_override("background", UiTheme.make_box(UiPalette.INK, UiPalette.WOOD_BORDER, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THIN, 0))
	bar.add_theme_stylebox_override("fill", UiTheme.make_box(UiPalette.TOWER, UiPalette.TOWER, UiPalette.RADIUS_SMALL, 0, 0))
	progress_column.add_child(bar)

	_rows[achievement.id] = value
	_bars[achievement.id] = bar


# --- Test seams --------------------------------------------------------------

func get_row_value_label_for_test(id: String) -> Label:
	return _rows.get(id)


func get_back_button_for_test() -> Button:
	return _back_button


func get_row_count_for_test() -> int:
	return _rows.size()


func get_row_bar_for_test(id: String) -> ProgressBar:
	return _bars.get(id)
