extends CanvasLayer
class_name RecordsPanel

## Records panel (Hub/War Camp; docs/18_Permanent_Skill_Tree.md section 5:
## "best wave reached, longest time survived, most kills in a run, total
## runs, total victories and lifetime Cores earned"). Opened from
## `HubScreen`'s own "Records" button, mirroring `SkillTreeScreen`'s
## instantiate-once / `set_active()` pattern.
##
## Read-only: this screen never mutates `MetaProgress`, so it goes through
## `MenuFrame`'s shared Root/Dim/Center/Card/Column builders exactly like
## PauseMenu/SettingsMenu/RunEndScreen -- a small centred modal card is the
## right shape for a read-only stat list, unlike the Skill Tree's own
## full-screen node graph.

signal back_requested()

const RECORDS_CANVAS_LAYER: int = 5
const ROW_LABEL_MIN_WIDTH: float = 420.0
const ROW_VALUE_MIN_WIDTH: float = 200.0

var _frame: MenuFrame.Parts
var _back_button: Button
var _rows: Dictionary = {} # String key -> Label (the value cell)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = RECORDS_CANVAS_LAYER
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
	var records: Dictionary = MetaProgress.get_records()
	_rows["best_wave"].text = str(int(records.get("best_waves_cleared", 0)))
	_rows["longest_time"].text = _format_time(float(records.get("best_survival_seconds", 0.0)))
	_rows["most_kills"].text = str(int(records.get("best_kills", 0)))
	_rows["runs"].text = str(int(records.get("runs_settled", 0)))
	_rows["victories"].text = str(int(records.get("victories", 0)))
	# lifetime_cores is a top-level profile field, not part of get_records()'s
	# own dictionary -- MetaProgress.get_lifetime_cores() (a minimal addition,
	# this session) is the dedicated read-only query for it.
	_rows["lifetime_cores"].text = str(MetaProgress.get_lifetime_cores())


static func _format_time(total_seconds: float) -> String:
	var whole: int = int(floor(maxf(0.0, total_seconds)))
	var minutes: int = whole / 60
	var seconds: int = whole % 60
	return "%d:%02d" % [minutes, seconds]


func _build_ui() -> void:
	UiStrings.ensure_registered()
	_frame = MenuFrame.build(self, 0.75, "L")

	MenuFrame.build_title(_frame.column, tr("RECORDS_TITLE"), UiTheme.HEADING, 420.0)
	MenuFrame.build_separator(_frame.column)

	_build_row(tr("RECORDS_BEST_WAVE"), "best_wave")
	_build_row(tr("RECORDS_LONGEST_TIME"), "longest_time")
	_build_row(tr("RECORDS_MOST_KILLS"), "most_kills")
	_build_row(tr("RECORDS_RUNS"), "runs")
	_build_row(tr("RECORDS_VICTORIES"), "victories")
	_build_row(tr("RECORDS_LIFETIME_CORES"), "lifetime_cores")

	MenuFrame.build_separator(_frame.column)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = tr("RECORDS_BACK")
	_back_button.custom_minimum_size = Vector2(220, 56)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	_frame.column.add_child(_back_button)


func _build_row(label_text: String, key: String) -> void:
	var row := PanelContainer.new()
	row.name = "%sRow" % key.capitalize().replace(" ", "")
	row.theme_type_variation = UiTheme.ROW
	_frame.column.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.theme_type_variation = UiTheme.hbox("L")
	row.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = UiTheme.DIM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(ROW_LABEL_MIN_WIDTH, 0.0)
	hbox.add_child(label)

	var value := Label.new()
	value.name = "Value"
	value.theme_type_variation = UiTheme.VALUE
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.custom_minimum_size = Vector2(ROW_VALUE_MIN_WIDTH, 0.0)
	hbox.add_child(value)

	_rows[key] = value


# --- Test seams --------------------------------------------------------------

func get_row_value_label_for_test(key: String) -> Label:
	return _rows.get(key)


func get_back_button_for_test() -> Button:
	return _back_button
