extends CanvasLayer
class_name RunEndScreen

## Run-end screen (P2.14 - Run flow). MASTER_SDLC.md > Provisional Values
## Register > Acceptance Test Matrix > "Run flow check": "The run-end
## screens show the death cause or the final wave reached, the Scrap held,
## and the time survived." > Tower Overview > "Health Recovery Rules" and
## > Player Overview for the death-cause/wave-reached/Scrap-held/
## time-survived fields this screen reads; > "Economy & Pickups" > "Scrap":
## "carried and lost on death ... unspent Scrap discarded at run end."
##
## ## The Scrap-zero seam this screen depends on (task brief, verbatim)
## "RunInventory already zeroes Scrap on player_died; your screen must show
## the zeroed value, not a cached one." This screen therefore NEVER caches
## a Scrap figure at the moment death is detected -- `show_summary()`
## reads `summary.scrap_held`, and `src/run/run_flow_controller.gd` (the
## only caller) builds that Dictionary from `RunInventory.scrap_current`
## itself only AFTER every `player_died` listener (RunInventory's own
## zeroing handler included) has already run for that death -- see that
## file's header, "Reading Scrap only after it is truly final," for why a
## `call_deferred()` is what makes that ordering safe regardless of
## listener-connection order. This file has no RunInventory reference of
## its own and cannot read a stale value even by accident.
##
## ## "The death cause or the final wave reached" (task brief; Register >
## Run flow check)
## Read literally as an exclusive "or", but MASTER_SDLC.md > "Development
## Phase Map" > P2.14's own exit criterion reads "a developer run reaches
## wave eight or dies with a recorded cause" -- two distinct END PATHS, not
## one field that hides information. This screen shows BOTH the wave
## reached AND, only when the run ended by a death, a cause line -- a run
## that ends by clearing the full wave sequence (no death occurred) shows
## the wave-reached line alone, with no cause line at all (there is no
## cause to report). Named as an interpretation, not a restated Register
## sentence, in the P2.14 evidence report.
##
## ## Paused-menu timing carve-out (Author decision D104)
## Owns no timing of its own -- see src/run/paused_choice_bar.gd's header
## for the accumulator its "Settings" hold-to-confirm choice runs on.

signal settings_requested()

const OPTION_SETTINGS: int = 0

## Above src/ui/hud.gd (10) / src/ui/threat_feedback.gd (11); same tier as
## src/ui/pause_menu.gd (18) since the two are mutually exclusive by
## construction (the run has either ended or it has not --
## run_flow_controller.gd never shows both at once). Not a Provisional
## Values Register number -- see hud.gd's identical note.
const RUN_END_CANVAS_LAYER: int = 19

var _root: Control
var _bar: PausedChoiceBar
var _fill_ring: DraftFillRing
var _title_label: Label
var _cause_label: Label
var _wave_label: Label
var _scrap_label: Label
var _time_label: Label


func _ready() -> void:
	layer = RUN_END_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


## Typed command. `summary` keys (all optional, missing/empty means "do not
## show this line"): `cause_text: String`, `wave_reached: int`,
## `wave_total: int`, `scrap_held: int`, `time_survived_seconds: float`.
## Called by src/run/run_flow_controller.gd once, at the moment the run
## ends, with values it has already finished computing (see class header).
func show_summary(summary: Dictionary) -> void:
	var cause_text: String = String(summary.get("cause_text", ""))
	_cause_label.visible = not cause_text.is_empty()
	if _cause_label.visible:
		_cause_label.text = "%s: %s" % [tr("RUN_END_CAUSE"), cause_text]

	var wave_reached: int = int(summary.get("wave_reached", -1))
	var wave_total: int = int(summary.get("wave_total", 0))
	_wave_label.visible = wave_reached >= 0
	if _wave_label.visible:
		_wave_label.text = "%s: %d/%d" % [tr("RUN_END_WAVE_REACHED"), wave_reached, wave_total]

	var scrap_held: int = int(summary.get("scrap_held", 0))
	_scrap_label.text = "%s: %d" % [tr("RUN_END_SCRAP_HELD"), scrap_held]

	var seconds: float = float(summary.get("time_survived_seconds", 0.0))
	_time_label.text = "%s: %s" % [tr("RUN_END_TIME_SURVIVED"), _format_time(seconds)]


func set_active(active: bool) -> void:
	visible = active
	_bar.set_active(active)


func is_active_for_test() -> bool:
	return visible


func get_bar_for_test() -> PausedChoiceBar:
	return _bar


func get_cause_label_for_test() -> Label:
	return _cause_label


func get_wave_label_for_test() -> Label:
	return _wave_label


func get_scrap_label_for_test() -> Label:
	return _scrap_label


func get_time_label_for_test() -> Label:
	return _time_label


func _on_option_confirmed(index: int) -> void:
	if index == OPTION_SETTINGS:
		settings_requested.emit()


static func _format_time(total_seconds: float) -> String:
	var whole: int = int(floor(maxf(0.0, total_seconds)))
	var minutes: int = whole / 60
	var seconds: int = whole % 60
	return "%d:%02d" % [minutes, seconds]


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.75) # deeper than the Draft's 60%: the run is over, not merely paused mid-play -- named as an interpretation, not a Register-restated figure
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(center)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = tr("RUN_END_TITLE")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.custom_minimum_size = Vector2(400, 0)
	column.add_child(_title_label)

	_cause_label = _make_field_label("CauseLabel")
	column.add_child(_cause_label)
	_wave_label = _make_field_label("WaveLabel")
	column.add_child(_wave_label)
	_scrap_label = _make_field_label("ScrapLabel")
	column.add_child(_scrap_label)
	_time_label = _make_field_label("TimeLabel")
	column.add_child(_time_label)

	_bar = PausedChoiceBar.new()
	_bar.name = "ChoiceBar"
	_bar.set_options([tr("RUN_END_SETTINGS")])
	_bar.option_confirmed.connect(_on_option_confirmed)
	column.add_child(_bar)

	_fill_ring = DraftFillRing.new()
	_fill_ring.name = "HoldRing"
	_fill_ring.custom_minimum_size = Vector2(48, 48)
	column.add_child(_fill_ring)
	_bar.set_fill_ring(_fill_ring)


func _make_field_label(node_name: String) -> Label:
	var lbl := Label.new()
	lbl.name = node_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(400, 0)
	return lbl
