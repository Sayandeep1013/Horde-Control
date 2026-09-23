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

signal back_requested()

const ACHIEVEMENTS_CANVAS_LAYER: int = 5
const ROW_LABEL_MIN_WIDTH: float = 460.0
const ROW_VALUE_MIN_WIDTH: float = 220.0

var _frame: MenuFrame.Parts
var _back_button: Button
var _rows: Dictionary = {} # String (achievement id) -> Label (the value cell)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = ACHIEVEMENTS_CANVAS_LAYER
	visible = false
	_build_ui()


func set_active(active: bool) -> void:
	visible = active
	if active:
		_refresh()
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
		_rows[achievement.id].text = _status_text(achievement)


## Unlocked: "Unlocked". Locked, lifetime metric: "n / threshold" (the one
## progress figure a Hub visit -- outside any run -- can actually show).
## Locked, per-run metric (run_waves_cleared/run_victory/
## run_tower_health_fraction): "Locked" -- there is no meaningful lifetime
## progress number for a condition that resets every run.
func _status_text(achievement: AchievementDefinition) -> String:
	if MetaProgress.is_achievement_unlocked(achievement.id):
		return tr("ACHIEVEMENTS_UNLOCKED")
	match achievement.metric:
		"lifetime_kills":
			return "%d / %d" % [MetaProgress.get_lifetime_kills(), int(achievement.threshold)]
		"lifetime_scrap_collected":
			return "%d / %d" % [MetaProgress.get_lifetime_scrap_collected(), int(achievement.threshold)]
		_:
			return tr("ACHIEVEMENTS_LOCKED")


func _build_ui() -> void:
	UiStrings.ensure_registered()
	_frame = MenuFrame.build(self, 0.8, "L")

	MenuFrame.build_title(_frame.column, tr("ACHIEVEMENTS_TITLE"), UiTheme.HEADING, 480.0)
	MenuFrame.build_separator(_frame.column)

	if MetaProgress.achievement_list != null:
		for achievement in MetaProgress.achievement_list.achievements:
			if achievement != null:
				_build_row(achievement)

	MenuFrame.build_separator(_frame.column)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = tr("ACHIEVEMENTS_BACK")
	_back_button.custom_minimum_size = Vector2(220, 56)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	_frame.column.add_child(_back_button)


func _build_row(achievement: AchievementDefinition) -> void:
	var row := PanelContainer.new()
	row.name = "%sRow" % achievement.id.capitalize().replace(" ", "")
	row.theme_type_variation = UiTheme.ROW
	_frame.column.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.theme_type_variation = UiTheme.hbox("L")
	row.add_child(hbox)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(column)

	var name_label := Label.new()
	name_label.text = achievement.display_name
	name_label.theme_type_variation = UiTheme.VALUE
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(ROW_LABEL_MIN_WIDTH, 0.0)
	column.add_child(name_label)

	var description_label := Label.new()
	description_label.text = achievement.description
	description_label.theme_type_variation = UiTheme.DIM
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(ROW_LABEL_MIN_WIDTH, 0.0)
	column.add_child(description_label)

	var value := Label.new()
	value.name = "Value"
	value.theme_type_variation = UiTheme.VALUE
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.custom_minimum_size = Vector2(ROW_VALUE_MIN_WIDTH, 0.0)
	hbox.add_child(value)

	_rows[achievement.id] = value


# --- Test seams --------------------------------------------------------------

func get_row_value_label_for_test(id: String) -> Label:
	return _rows.get(id)


func get_back_button_for_test() -> Button:
	return _back_button


func get_row_count_for_test() -> int:
	return _rows.size()
