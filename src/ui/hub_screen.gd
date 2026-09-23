extends CanvasLayer
class_name HubScreen

## Hub (War Camp) -- MINIMAL PLACEHOLDER (build brief item 4: "create a
## MINIMAL placeholder hub.tscn ... so flow works end to end; the screen
## agent will replace it"). MASTER_SDLC.md > Review Decision Log D109: "a Hub
## (War Camp) between runs ... Title Play now opens the Hub."
##
## Deliberately plain, undecorated Godot Controls -- NO `UiTheme`/
## `UiPalette`/`UiStrings` dependency at all, unlike every other screen in
## this project. Two other sessions are editing `src/ui/theme/*` and
## `src/ui/hud*.gd`/`draft_card_view`/`threat_feedback` concurrently as part
## of this same task; this file is explicitly the one the Hub/Skill-Tree
## screen agent replaces next, so it deliberately shares no styling surface
## with that work and cannot conflict with it.
##
## ## Flow (build brief item 4)
## Title's Play -> `res://scenes/hub.tscn` (src/ui/title_screen.gd). This
## screen's own "Start Run" -> `res://scenes/prototype.tscn`; "Back to
## Title" -> `res://scenes/title.tscn`. `RunFlowController`'s run-end
## screen's "Continue" choice comes back here.
##
## ## MetaProgress loading (see src/meta/meta_progress.gd's own header,
## "Never touches the real user://profile.json unless asked to")
## This is the first production scene that calls `MetaProgress.
## ensure_loaded()` -- the real save is read (or created, on a first launch)
## here, not at Autoload boot. `mark_hub_seen()` follows, for the
## `first_hub_seen` profile flag (Register > "Meta: Save profile").

@export var cores_label_text_prefix: String = "Cores: "

var _root: Control
var _cores_label: Label
var _start_run_button: Button
var _back_to_title_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaProgress.ensure_loaded()
	MetaProgress.mark_hub_seen()
	_build_ui()
	_refresh_cores_label()
	if not MetaProgress.cores_changed.is_connected(_on_cores_changed):
		MetaProgress.cores_changed.connect(_on_cores_changed)
	_start_run_button.grab_focus()


func _exit_tree() -> void:
	if MetaProgress.cores_changed.is_connected(_on_cores_changed):
		MetaProgress.cores_changed.disconnect(_on_cores_changed)


func _on_cores_changed(_new_total: int) -> void:
	_refresh_cores_label()


func _refresh_cores_label() -> void:
	_cores_label.text = "%s%d" % [cores_label_text_prefix, MetaProgress.get_cores()]


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	var title := Label.new()
	title.name = "HubTitle"
	title.text = "War Camp"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_cores_label = Label.new()
	_cores_label.name = "CoresLabel"
	_cores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_cores_label)

	_start_run_button = Button.new()
	_start_run_button.name = "StartRunButton"
	_start_run_button.text = "Start Run"
	_start_run_button.custom_minimum_size = Vector2(280, 56)
	_start_run_button.pressed.connect(_on_start_run_pressed)
	column.add_child(_start_run_button)

	_back_to_title_button = Button.new()
	_back_to_title_button.name = "BackToTitleButton"
	_back_to_title_button.text = "Back to Title"
	_back_to_title_button.custom_minimum_size = Vector2(280, 56)
	_back_to_title_button.pressed.connect(_on_back_to_title_pressed)
	column.add_child(_back_to_title_button)


func _on_start_run_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/prototype.tscn")


func _on_back_to_title_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


# --- Test seams --------------------------------------------------------------

func get_cores_label_for_test() -> Label:
	return _cores_label


func get_start_run_button_for_test() -> Button:
	return _start_run_button


func get_back_to_title_button_for_test() -> Button:
	return _back_to_title_button
