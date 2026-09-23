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
##
## ## UI pass (package D): look and feel only
## `_build_ui()` now goes through `src/ui/menu_frame.gd`'s shared builders,
## matching pause_menu.gd/settings_menu.gd, plus a result-screen treatment
## (task brief item 3): the title is coloured `UiPalette.DANGER`/`SUCCESS`
## and paired with an `OutcomeGlyph` (an X or a check mark, drawn rather
## than a font glyph -- see that file's header for why), and the wave/
## Scrap/time fields sit in a 3-cell stat grid, each cell a `UiTheme.ROW`
## panel of consistent width -- the four existing cause/wave/scrap/time
## Labels keep the exact object identity, node name, and `show_summary()`
## text format they always had; `get_*_label_for_test()` returns the same
## nodes, restyled (`UiTheme.VALUE`/`DIM`), never replaced. The one new
## behaviour is `_apply_outcome_style()`, called from `show_summary()` and
## derived from the SAME `cause_text` emptiness the four existing lines
## already branch on -- no second source of truth, no new public seam.
## `set_active()` gained the same purely cosmetic fade/scale-in as the
## other two menus. See phases/UI_PASS/reports/D_menus.md.
##
## ## Follow-up (coordinator review): sibling stat captions removed
## An earlier version of this pass added a dim caption Label above each
## stat-grid value ("Scrap" above "Scrap held: 180") -- the coordinator's
## review (looking at the launched scene) found each caption just repeated
## the word already baked into the value Label's own text below it. Those
## captions are gone; `_build_stat_cell()` now builds a plain `UiTheme.ROW`
## panel per stat, all three `STAT_CELL_MIN_WIDTH` wide so the grid stays
## even, holding only the (unchanged) value Label, which centres itself
## via its own `horizontal_alignment`.
##
## ## Main Menu option (title screen + credits session)
## A second choice, "Main Menu," alongside Settings -- this project had no
## restart or quit option anywhere on this screen to retarget (grepped;
## none existed), so this is a genuinely new choice, not a retargeted one.
## `RunFlowController._on_main_menu_requested()` is the one caller that
## reacts to `main_menu_requested`, exactly like `settings_requested`
## above; this file only reports which option the player picked.

signal settings_requested()
signal main_menu_requested()
## Meta layer core (build brief item 4): "Add a run-end 'Continue' choice
## that goes to the Hub scene." `RunFlowController._on_continue_requested()`
## is the one caller, exactly like `settings_requested`/`main_menu_requested`
## above -- this file only reports which option the player picked and owns
## no scene-change logic of its own.
signal continue_requested()

const OPTION_CONTINUE: int = 0
const OPTION_SETTINGS: int = 1
const OPTION_MAIN_MENU: int = 2

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
var _frame: MenuFrame.Parts
var _outcome_glyph: OutcomeGlyph
var _wave_cell: PanelContainer ## the Wave stat cell; kept in sync with _wave_label's own visibility (UI pass) -- see show_summary(). A cell with no visible child sizes to ~0 in the grid rather than leaving an empty panel.

## Meta layer core (build brief item 4). The settlement card -- built once
## (empty) in `_build_ui()`; populated/cleared and styled by
## `set_settlement()`.
var _settlement_box: VBoxContainer

## Round 2 (LEDGER UR-14): 220 was measured too tight for the widest cell.
## "Time survived: 0:03" (the shortest, most common time reading) alone
## measured 221 px against the real UiTheme.VALUE font (`Font.get_string_size`,
## checked directly for this pass) -- already past the ~212 px a 220 px cell
## left after its own UiTheme.ROW content margins, which is exactly why it
## wrapped to two lines while "Scrap held: 150" (177 px) fit on one, so the
## two cells' baselines did not line up. 320 clears every plausible value
## checked the same way ("Time survived: 99:59" 236 px, "Wave reached: 8/8"
## 218 px, "Scrap held: 200" 181 px) with headroom left for the outline
## stroke and for pseudo-localization inflating the tr()'d prefix word
## (F2, docs/19: strings render roughly 30% longer, bracket-wrapped) --
## verified against the capture tool's --pseudo set, see the package report.
const STAT_CELL_MIN_WIDTH: float = 320.0 ## TODO(ui-pass): promote to UiPalette as a shared stat-grid cell width token


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
	# Meta layer core (Hub/Skill Tree screen session, build brief item 4):
	# the outcome header itself now reads Victory/Defeated/Tower Fallen/
	# Abandoned (run_flow_controller.gd's own `_build_summary()` resolves
	# which one) rather than the generic RUN_END_TITLE -- falls back to the
	# old fixed title if a caller supplies no `outcome_title` at all.
	_title_label.text = String(summary.get("outcome_title", tr("RUN_END_TITLE")))

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

	_wave_cell.visible = _wave_label.visible # the wrapping cell (UI pass) tracks the SAME visibility flag, never a second decision -- an invisible child alone would leave an empty panel showing
	_apply_outcome_style(cause_text.is_empty())


## Colours and marks the outcome title from the SAME data `show_summary()`
## already received above -- never a second source of truth (task brief,
## item 3: "derive the outcome only from data show_summary() already
## receives"). A defeat (player death or the Tower destroyed) always sets
## a cause line (class header, "The death cause or the final wave
## reached"); a victory (the wave sequence completed with nobody dead)
## never does -- so `cause_text`'s emptiness alone already IS the outcome.
func _apply_outcome_style(is_victory: bool) -> void:
	_title_label.add_theme_color_override("font_color", UiPalette.SUCCESS if is_victory else UiPalette.DANGER)
	_outcome_glyph.set_defeat(not is_victory)


## The card's own fade/scale-in (UI pass) is purely cosmetic and runs
## AFTER these two lines, never before or instead of them -- input
## activation is never delayed by it (rule 6).
func set_active(active: bool) -> void:
	visible = active
	_bar.set_active(active)
	if active:
		MenuFrame.animate_in(_frame)
	else:
		MenuFrame.reset_motion(_frame)


func is_active_for_test() -> bool:
	return visible


func get_bar_for_test() -> PausedChoiceBar:
	return _bar


func get_title_label_for_test() -> Label:
	return _title_label


func get_cause_label_for_test() -> Label:
	return _cause_label


func get_wave_label_for_test() -> Label:
	return _wave_label


func get_scrap_label_for_test() -> Label:
	return _scrap_label


func get_time_label_for_test() -> Label:
	return _time_label


func _on_option_confirmed(index: int) -> void:
	if index == OPTION_CONTINUE:
		continue_requested.emit()
	elif index == OPTION_SETTINGS:
		settings_requested.emit()
	elif index == OPTION_MAIN_MENU:
		main_menu_requested.emit()


## Meta layer core (build brief item 4). `breakdown` is exactly what
## `MetaProgress.settle_run()` returns (that file's own header documents the
## shape): `lines` (Array of {label, amount} Dictionaries), `total_cores`,
## `new_best_waves`/`new_best_kills`/`new_best_survival_seconds` (bool), and
## `already_settled` (true only for a cross-process idempotent replay with
## no itemisation to show).
##
## Hub/Skill Tree screen session: a proper settlement card -- each
## Core line as its own `UiTheme.ROW` (matching the stat grid's own cell
## treatment), the total prominent below, and a `UiTheme.RIBBON` per NEW
## BEST flag. `_animate_settlement()` reveals the rows one after another and
## counts each amount up from 0, rather than dumping every number at once --
## the build brief's own "each Core line counting up one after another."
## `_settlement_box`'s own node identity/name is unchanged
## (`get_settlement_box_for_test()`'s contract).
func set_settlement(breakdown: Dictionary) -> void:
	for child in _settlement_box.get_children():
		child.queue_free()
	var lines: Array = breakdown.get("lines", [])
	if lines.is_empty():
		_settlement_box.visible = false
		return
	_settlement_box.visible = true

	var entries: Array[Dictionary] = []
	for entry in lines:
		var line: Dictionary = entry
		var amount: int = int(line.get("amount", 0))
		var row := PanelContainer.new()
		row.theme_type_variation = UiTheme.ROW
		row.modulate.a = 0.0
		_settlement_box.add_child(row)

		var hbox := HBoxContainer.new()
		hbox.theme_type_variation = UiTheme.hbox("L")
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hbox)

		var name_label := Label.new()
		name_label.text = String(line.get("label", ""))
		name_label.theme_type_variation = UiTheme.DIM
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size = Vector2(280.0, 0.0)
		hbox.add_child(name_label)

		var amount_label := Label.new()
		amount_label.name = "Amount"
		amount_label.theme_type_variation = UiTheme.VALUE
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount_label.text = _format_settlement_amount(0)
		hbox.add_child(amount_label)

		entries.append({"row": row, "label": amount_label, "target": amount})

	var total_label := Label.new()
	total_label.name = "SettlementTotal"
	total_label.theme_type_variation = UiTheme.HEADING
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.modulate.a = 0.0
	total_label.text = "%s: 0" % tr("RUN_END_SETTLEMENT_TOTAL")
	_settlement_box.add_child(total_label)

	var ribbon_panels: Array[PanelContainer] = []
	if bool(breakdown.get("new_best_waves", false)):
		ribbon_panels.append(_build_new_best_ribbon(tr("RUN_END_NEW_BEST_WAVES")))
	if bool(breakdown.get("new_best_kills", false)):
		ribbon_panels.append(_build_new_best_ribbon(tr("RUN_END_NEW_BEST_KILLS")))
	if bool(breakdown.get("new_best_survival_seconds", false)):
		ribbon_panels.append(_build_new_best_ribbon(tr("RUN_END_NEW_BEST_TIME")))

	_animate_settlement(entries, total_label, int(breakdown.get("total_cores", 0)), ribbon_panels)


func _build_new_best_ribbon(text: String) -> PanelContainer:
	var ribbon := PanelContainer.new()
	ribbon.name = "NewBestRibbon"
	ribbon.theme_type_variation = UiTheme.RIBBON
	ribbon.modulate.a = 0.0
	_settlement_box.add_child(ribbon)

	var label := Label.new()
	label.text = text
	label.theme_type_variation = UiTheme.VALUE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ribbon.add_child(label)
	return ribbon


static func _format_settlement_amount(amount: int) -> String:
	return "%s%d" % ["+" if amount >= 0 else "", amount]


## One continuous `Node.create_tween()` sequence (pure cosmetic UI motion,
## permitted regardless of pause state; `tools/checks/banned_api_check.sh`
## exempts every `.../ui/...` path outright): each row fades in, its own
## amount counts up from 0 to its final value, then the next row starts --
## "one after another," never all at once. The total counts up the same way
## once every line has landed, and any NEW BEST ribbons fade in last.
func _animate_settlement(entries: Array[Dictionary], total_label: Label, total_target: int, ribbon_panels: Array[PanelContainer]) -> void:
	var tween: Tween = create_tween()
	for entry in entries:
		var row: PanelContainer = entry["row"]
		var amount_label: Label = entry["label"]
		var target: int = entry["target"]
		tween.tween_property(row, "modulate:a", 1.0, 0.12)
		tween.parallel().tween_method(_apply_amount_text.bind(amount_label), 0.0, float(target), 0.22)
		tween.tween_interval(0.05)
	tween.tween_property(total_label, "modulate:a", 1.0, 0.12)
	var total_prefix: String = tr("RUN_END_SETTLEMENT_TOTAL") # tr() needs an instance; resolved here, not inside the static callable below
	tween.parallel().tween_method(_apply_total_text.bind(total_label, total_prefix), 0.0, float(total_target), 0.3)
	for ribbon in ribbon_panels:
		tween.tween_property(ribbon, "modulate:a", 1.0, 0.2)


static func _apply_amount_text(value: float, label: Label) -> void:
	label.text = _format_settlement_amount(int(round(value)))


static func _apply_total_text(value: float, label: Label, prefix: String) -> void:
	label.text = "%s: %d" % [prefix, int(round(value))]


func get_settlement_box_for_test() -> VBoxContainer:
	return _settlement_box


static func _format_time(total_seconds: float) -> String:
	var whole: int = int(floor(maxf(0.0, total_seconds)))
	var minutes: int = whole / 60
	var seconds: int = whole % 60
	return "%d:%02d" % [minutes, seconds]


func _build_ui() -> void:
	UiStrings.ensure_registered() # UI pass round 2, UR-08: explicit here, not only reached as UiTheme.get_theme()'s side effect.
	# 0.75 is deeper than the Draft's 60%: the run is over, not merely
	# paused mid-play -- named as an interpretation, not a Register-restated
	# figure. UiTheme.vbox("L") (UiPalette.SPACE_L, 16) is an exact match
	# for this file's own former literal separation (16); no value change
	# here.
	_frame = MenuFrame.build(self, 0.75, "L")
	_root = _frame.root

	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.theme_type_variation = UiTheme.hbox("M")
	_frame.column.add_child(title_row)

	_outcome_glyph = OutcomeGlyph.new()
	_outcome_glyph.name = "OutcomeGlyph"
	_outcome_glyph.custom_minimum_size = Vector2(48.0, 48.0)
	title_row.add_child(_outcome_glyph)

	_title_label = MenuFrame.build_title(title_row, tr("RUN_END_TITLE"), UiTheme.TITLE, 320.0)
	MenuFrame.build_separator(_frame.column)

	_cause_label = _make_field_label("CauseLabel", 400.0)
	_cause_label.theme_type_variation = UiTheme.DIM
	_frame.column.add_child(_cause_label)

	var grid := HBoxContainer.new()
	grid.name = "StatGrid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.theme_type_variation = UiTheme.hbox("L")
	_frame.column.add_child(grid)

	# Follow-up (coordinator review): the sibling captions an earlier
	# version of this pass added here were removed -- each existing value
	# Label already carries its own caption baked into its text
	# ("Scrap held: 180"; that FORMAT is untouched, see show_summary()), so
	# a second, standalone "Scrap" caption above it just repeated the same
	# word. Each cell is now a UiTheme.ROW panel holding only the value
	# Label, centred, all three the same width so the grid reads even.
	_wave_cell = _build_stat_cell(grid, "Wave")
	_wave_label = _make_field_label("WaveLabel", STAT_CELL_MIN_WIDTH)
	_wave_label.theme_type_variation = UiTheme.VALUE
	_wave_cell.add_child(_wave_label)

	var scrap_cell: PanelContainer = _build_stat_cell(grid, "Scrap")
	_scrap_label = _make_field_label("ScrapLabel", STAT_CELL_MIN_WIDTH)
	_scrap_label.theme_type_variation = UiTheme.VALUE
	scrap_cell.add_child(_scrap_label)

	var time_cell: PanelContainer = _build_stat_cell(grid, "Time")
	_time_label = _make_field_label("TimeLabel", STAT_CELL_MIN_WIDTH)
	_time_label.theme_type_variation = UiTheme.VALUE
	time_cell.add_child(_time_label)

	# Meta layer core: the settlement card container -- see set_settlement()'s
	# own header for the styling it applies to each child it builds. Hidden
	# until set_settlement() has real lines to show.
	_settlement_box = VBoxContainer.new()
	_settlement_box.name = "SettlementBox"
	_settlement_box.visible = false
	_frame.column.add_child(_settlement_box)

	_bar = PausedChoiceBar.new()
	_bar.name = "ChoiceBar"
	# Meta layer core (build brief item 4): "Continue" is a new first choice
	# -> the Hub (see `continue_requested`'s own header). No tr() key exists
	# for it yet -- src/ui/theme/ui_strings.gd (where RUN_END_SETTINGS/
	# RUN_END_MAIN_MENU are registered) is off limits this session (HUD
	# visuals agent's exclusive scope, per this task's hard constraints) --
	# a plain literal, exactly like ABANDONED's cause_text in
	# run_flow_controller.gd, named as the same follow-up seam.
	_bar.set_options(["Continue", tr("RUN_END_SETTINGS"), tr("RUN_END_MAIN_MENU")])
	_bar.option_confirmed.connect(_on_option_confirmed)
	_frame.column.add_child(_bar)
	MenuFrame.style_choice_labels(_bar)

	var hold_footer: VBoxContainer = MenuFrame.build_hold_footer(_frame.column)
	MenuFrame.build_highlight_row(hold_footer, _bar)

	_fill_ring = DraftFillRing.new()
	_fill_ring.name = "HoldRing"
	_fill_ring.custom_minimum_size = Vector2(48, 48)
	MenuFrame.style_fill_ring(_fill_ring)
	hold_footer.add_child(_fill_ring)
	_bar.set_fill_ring(_fill_ring)


## One stat-grid cell: a `UiTheme.ROW` `PanelContainer` slot named
## `"%sCell" % node_prefix`, added to `grid`, consistent width
## (`STAT_CELL_MIN_WIDTH`) so the grid reads even. The caller adds the
## VALUE-styled field label into it afterward (still built by
## `_make_field_label()`, unchanged) -- the panel centres it via that
## label's own `horizontal_alignment`.
func _build_stat_cell(grid: HBoxContainer, node_prefix: String) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.name = "%sCell" % node_prefix
	cell.theme_type_variation = UiTheme.ROW
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(STAT_CELL_MIN_WIDTH, 0.0)
	grid.add_child(cell)
	return cell


func _make_field_label(node_name: String, min_width: float = 400.0) -> Label:
	var lbl := Label.new()
	lbl.name = node_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(min_width, 0)
	return lbl
