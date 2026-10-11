extends CanvasLayer
class_name PauseMenu

## Pause Menu. MASTER_SDLC.md > Provisional Values Register > "Interfaces" >
## "Platform input floor" (horizontal layout, hold-to-confirm) and > "v1.0
## Interface" > "Pause menu"; docs/19_UI_UX.md > "Input Map": "Pause Escape /
## Start"; docs/31 §8.2.
##
## ## One writer, this file only reacts
## This file NEVER pushes or pops a PauseAuthority reason and never writes
## `get_tree().paused`. `src/run/run_flow_controller.gd` owns that (pause
## action, focus loss, controller disconnect); this file presents and reports
## which option was picked (`resume_requested` / `settings_requested` /
## `main_menu_requested`). How to Play is shown by this file itself, as an
## overlay in the same layer: it changes no run state.
##
## ## v1.0 layout
## The four choices stay one horizontal `PausedChoiceBar` (Resume, Settings,
## How to Play, Abandon run), so the "every paused menu lays choices out
## horizontally and supports hold-to-confirm" floor still holds. Under it sit
## two panels read from the live run: Build (Battle Skill, abilities with
## levels, Tower abilities, passives with ranks, difficulty, seed) and Run stats
## (time, kills, elites, damage taken, Scrap repaired, estimated Cores; the
## Cores estimate that used to sit on the HUD). docs/31 §8.2 sketches a left
## column of choices; that vertical shape would break the horizontal floor, so
## it is not used (see the Review Decision Log row for this package).
##
## Data sources are found defensively (groups "ability_manager", "battle_skill",
## "wave_director", "hud") and show an empty state until they exist.

const PAUSE_MENU_CANVAS_LAYER: int = 18

const OPTION_RESUME: int = 0
const OPTION_SETTINGS: int = 1
const OPTION_HOW_TO_PLAY: int = 2
const OPTION_MAIN_MENU: int = 3
const ABANDON_OPTION_CANCEL: int = 0 ## the safe option is first, so it is the default highlight
const ABANDON_OPTION_CONFIRM: int = 1
const HOWTO_OPTION_BACK: int = 0
const HOWTO_CHROME_PX: float = 400.0 ## title, rule, Back row, hold ring and card padding

const CARD_MIN_WIDTH_PX: float = 1320.0
const PANEL_COLUMN_MIN_WIDTH_PX: float = 390.0

signal resume_requested()
signal settings_requested()
signal main_menu_requested()

var _root: Control
var _bar: PausedChoiceBar
var _fill_ring: DraftFillRing
var _title_label: Label
var _confirming_abandon: bool = false
var _frame: MenuFrame.Parts

var _panels_row: HBoxContainer
var _panels_scroll: ScrollContainer
var _build_column: VBoxContainer
var _passives_column: VBoxContainer
var _stats_column: VBoxContainer

var _howto_root: Control
var _howto_bar: PausedChoiceBar
var _howto_ring: DraftFillRing
var _howto_open: bool = false
var _howto_scroll: ScrollContainer


func _ready() -> void:
	layer = PAUSE_MENU_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


## `active` shows/hides the whole screen AND gates the choice bar's polling. The
## card's fade/scale-in is cosmetic and runs after these lines.
func set_active(active: bool) -> void:
	visible = active
	if not active or _confirming_abandon:
		_leave_abandon_confirmation() # always reopen on the main choices
	_close_how_to_play()
	_bar.set_active(active)
	if active:
		_refresh_panels()
		MenuFrame.animate_in(_frame)
		_fit_panels.call_deferred()
	else:
		MenuFrame.reset_motion(_frame)


func is_active_for_test() -> bool:
	return visible


func get_bar_for_test() -> PausedChoiceBar:
	return _bar


func get_build_column_for_test() -> VBoxContainer:
	return _build_column


func get_passives_column_for_test() -> VBoxContainer:
	return _passives_column


func get_stats_column_for_test() -> VBoxContainer:
	return _stats_column


func get_howto_bar_for_test() -> PausedChoiceBar:
	return _howto_bar


func is_how_to_play_open_for_test() -> bool:
	return _howto_open


func _on_option_confirmed(index: int) -> void:
	# UX review item 7 (D134): "Abandon run" asks first.
	if _confirming_abandon:
		if index == ABANDON_OPTION_CONFIRM:
			_confirming_abandon = false
			main_menu_requested.emit()
		else:
			_leave_abandon_confirmation()
			_bar.set_active(true) # fresh lockout + neutral-return arming
		return
	if index == OPTION_RESUME:
		resume_requested.emit()
	elif index == OPTION_SETTINGS:
		settings_requested.emit()
	elif index == OPTION_HOW_TO_PLAY:
		_open_how_to_play()
	elif index == OPTION_MAIN_MENU:
		_enter_abandon_confirmation()


func _enter_abandon_confirmation() -> void:
	_confirming_abandon = true
	_title_label.text = tr("PAUSE_MENU_ABANDON_TITLE")
	_bar.set_options([tr("PAUSE_MENU_ABANDON_CANCEL"), tr("PAUSE_MENU_ABANDON_CONFIRM")])
	MenuFrame.style_choice_labels(_bar)
	_panels_scroll.visible = false
	_bar.set_active(true) # the held confirm that got us here must not instantly confirm "Abandon"


func _leave_abandon_confirmation() -> void:
	if _title_label == null:
		_confirming_abandon = false
		return
	_confirming_abandon = false
	_title_label.text = tr("PAUSE_MENU_TITLE")
	_bar.set_options(_main_options())
	MenuFrame.style_choice_labels(_bar)
	_panels_scroll.visible = true


func is_confirming_abandon_for_test() -> bool:
	return _confirming_abandon


func _main_options() -> Array[String]:
	return [tr("PAUSE_MENU_RESUME"), tr("PAUSE_MENU_SETTINGS"), tr("PAUSE_MENU_HOW_TO_PLAY"), tr("PAUSE_MENU_MAIN_MENU")]


# --- How to Play overlay ---------------------------------------------------------

func _open_how_to_play() -> void:
	_howto_open = true
	_frame.center.visible = false
	_howto_root.visible = true
	_bar.set_active(false)
	_howto_bar.set_active(true)
	_fit_how_to_play.call_deferred()


## Sizes the page to its text once laid out, leaving room for the card's title and Back row.
func _fit_how_to_play() -> void:
	if is_inside_tree() and _howto_scroll != null:
		await get_tree().process_frame
		HowToPlay.fit(_howto_scroll, get_viewport().get_visible_rect().size.y - HOWTO_CHROME_PX)


func _close_how_to_play() -> void:
	if _howto_root == null or not _howto_open:
		return
	_howto_open = false
	_howto_root.visible = false
	_howto_bar.set_active(false)
	_frame.center.visible = true
	_bar.set_active(visible) # fresh lockout and neutral-return arming


func _on_howto_confirmed(_index: int) -> void:
	_close_how_to_play()


# --- Build / Run stats panels ----------------------------------------------------

func _refresh_panels() -> void:
	_fill_build_column()
	_fill_passives_column()
	_fill_stats_column()


func _clear(column: Container) -> void:
	for child: Node in column.get_children():
		column.remove_child(child)
		child.queue_free()


func _label(text: String, variation: StringName = UiTheme.HUD_VALUE, min_width: float = 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_OFF # a wrapping label with no width to claim breaks one letter per line
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	if min_width > 0.0:
		label.custom_minimum_size = Vector2(min_width, 0.0)
	return label


func _pair_row(parent: Container, key_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = UiTheme.hbox("M")
	var k := _label(key_text, UiTheme.DIM_PARCHMENT)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := _label(value_text, UiTheme.HUD_VALUE)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	parent.add_child(row)


func _fill_build_column() -> void:
	_clear(_build_column)
	var tree: SceneTree = get_tree()
	var manager: Node = tree.get_first_node_in_group("ability_manager") if tree != null else null

	_build_column.add_child(_label(tr("PAUSE_BUILD_TITLE"), UiTheme.HEADING))
	_pair_row(_build_column, tr("PAUSE_BUILD_SKILL"), AbilityNames.display(_battle_skill_id()))
	_pair_row(_build_column, tr("PAUSE_BUILD_DIFFICULTY"), RunConfig.get_difficulty().display_name)
	var seed_value: int = _run_seed()
	if seed_value >= 0:
		_pair_row(_build_column, tr("PAUSE_BUILD_SEED"), str(seed_value))
	_build_column.add_child(_label(tr("PAUSE_BUILD_ABILITIES"), UiTheme.DIM_PARCHMENT))
	_add_owned(_build_column, manager, "player")
	_build_column.add_child(_label(tr("PAUSE_BUILD_TOWER_ABILITIES"), UiTheme.DIM_PARCHMENT))
	_add_owned(_build_column, manager, "tower")


func _fill_passives_column() -> void:
	_clear(_passives_column)
	var tree: SceneTree = get_tree()
	var manager: Node = tree.get_first_node_in_group("ability_manager") if tree != null else null
	_passives_column.add_child(_label(tr("PAUSE_BUILD_PASSIVES"), UiTheme.HEADING))
	var passives: Array = []
	if manager != null and manager.has_method("get_passive_summary"):
		passives = manager.get_passive_summary()
	if passives.is_empty():
		_passives_column.add_child(_label(tr("PAUSE_BUILD_NONE"), UiTheme.HUD_VALUE))
	for entry: Dictionary in passives:
		var name_text: String = str(entry.get("display_name", AbilityNames.display(str(entry.get("id", "")))))
		_pair_row(_passives_column, name_text, "%d/%d" % [int(entry.get("rank", 1)), int(entry.get("max_rank", 1))])


func _add_owned(list: Container, manager: Node, slot_kind: String) -> void:
	var owned: Array = []
	if manager != null and manager.has_method("get_owned_abilities"):
		owned = manager.get_owned_abilities(slot_kind)
	if owned.is_empty():
		list.add_child(_label(tr("PAUSE_BUILD_NONE"), UiTheme.HUD_VALUE))
	for entry: Dictionary in owned:
		var row := HBoxContainer.new()
		row.theme_type_variation = UiTheme.hbox("M")
		var n := _label(AbilityNames.display(str(entry.get("id", ""))), UiTheme.HUD_VALUE)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var lv := _label(tr("PAUSE_LEVEL_RANK") % int(entry.get("level", 1)), UiTheme.HUD_VALUE)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(lv)
		list.add_child(row)
		var synergies: Array = manager.get_active_synergies(str(entry.get("id", ""))) if manager != null and manager.has_method("get_active_synergies") else []
		for line in synergies: # D204: a synergy shows once its partner is owned
			var syn := _label(str(line), UiTheme.DIM_PARCHMENT)
			syn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			syn.custom_minimum_size.x = 380.0
			list.add_child(syn)


func _fill_stats_column() -> void:
	_clear(_stats_column)
	_stats_column.add_child(_label(tr("PAUSE_STATS_TITLE"), UiTheme.HEADING))
	_pair_row(_stats_column, tr("PAUSE_STAT_TIME"), Hud.format_time(_elapsed_seconds()))
	_pair_row(_stats_column, tr("PAUSE_STAT_KILLS"), str(int(CombatStats.get_run_counter("kills"))))
	_pair_row(_stats_column, tr("PAUSE_STAT_ELITES"), str(int(CombatStats.get_run_counter("elite_kills"))))
	_pair_row(_stats_column, tr("PAUSE_STAT_DAMAGE_TAKEN"), str(int(round(CombatStats.get_run_counter("damage_taken")))))
	_pair_row(_stats_column, tr("PAUSE_STAT_SCRAP_REPAIRED"), str(int(CombatStats.get_run_counter("scrap_repaired"))))
	_pair_row(_stats_column, tr("PAUSE_STAT_CORES"), "~%d" % estimated_cores())


func _hud() -> Hud:
	var tree: SceneTree = get_tree()
	return tree.get_first_node_in_group("hud") as Hud if tree != null else null


func _battle_skill_id() -> String:
	var tree: SceneTree = get_tree()
	var node: Node = tree.get_first_node_in_group("battle_skill") if tree != null else null
	if node != null and node.has_method("get_state"):
		var id: String = str(node.get_state().get("skill_id", ""))
		if id != "":
			return id
	return RunConfig.battle_skill_id


func _run_seed() -> int:
	var parent: Node = get_parent()
	if parent != null and "run_seed" in parent:
		return int(parent.get("run_seed"))
	return -1


func _elapsed_seconds() -> float:
	var hud: Hud = _hud()
	return hud.get_elapsed_seconds() if hud != null else 0.0


## The Cores this run would settle to if it ended now (an estimate: the real
## settlement runs at run end). Review fix (D245): the figure comes from
## `MetaProgress.preview_settlement()` -- the same function `settle_run()` pays
## from -- so boss bounties, Victory, the Prospector and Founder bonuses and the
## difficulty multiplier can never drift between the estimate and the payout.
func estimated_cores() -> int:
	var parent: Node = get_parent()
	var summary: Dictionary = parent.get_live_summary() if parent != null and parent.has_method("get_live_summary") else _fallback_summary()
	return int(MetaProgress.preview_settlement(summary)["total_cores"])


## The run so far from the HUD and CombatStats, for a menu with no RunFlowController above it.
func _fallback_summary() -> Dictionary:
	var hud: Hud = _hud()
	var boss_kills: int = int(CombatStats.get_run_counter("boss_kills"))
	return {
		"sim_time_seconds": _elapsed_seconds(),
		"waves_cleared": maxi(0, (hud.get_wave_number() - 1) if hud != null else 0),
		"kills": int(CombatStats.get_run_counter("kills")),
		"elite_kills": int(CombatStats.get_run_counter("elite_kills")),
		"scrap_carried": hud.economy_state.scrap_current if hud != null else 0,
		"boss_kills": {"warchief": boss_kills} if boss_kills > 0 else {},
		"difficulty_id": RunConfig.difficulty_id,
	}


## The three panels scroll as one only when the screen is too short for them.
func _fit_panels() -> void:
	if not is_inside_tree() or _panels_scroll == null:
		return
	MenuFrame.fit_scroll(_frame, _panels_scroll, get_viewport().get_visible_rect().size.y)


func _build_ui() -> void:
	UiStrings.ensure_registered()
	_frame = MenuFrame.build(self, 0.6, "L")
	_root = _frame.root
	_frame.card.custom_minimum_size = Vector2(CARD_MIN_WIDTH_PX, 0.0)

	_title_label = MenuFrame.build_title(_frame.column, tr("PAUSE_MENU_TITLE"), UiTheme.HEADING, 320.0)
	MenuFrame.build_separator(_frame.column)

	_bar = PausedChoiceBar.new()
	_bar.name = "ChoiceBar"
	_bar.set_options(_main_options())
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

	_panels_scroll = ScrollContainer.new()
	_panels_scroll.name = "PanelsScroll"
	_panels_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.column.add_child(_panels_scroll)

	_panels_row = HBoxContainer.new()
	_panels_row.name = "PanelsRow"
	_panels_row.theme_type_variation = UiTheme.hbox("XL")
	_panels_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panels_scroll.add_child(_panels_row)

	_build_column = _make_panel_column("BuildPanel")
	_panels_row.add_child(_build_column)
	_panels_row.add_child(VSeparator.new())
	_passives_column = _make_panel_column("PassivesPanel")
	_panels_row.add_child(_passives_column)
	_panels_row.add_child(VSeparator.new())
	_stats_column = _make_panel_column("StatsPanel")
	_panels_row.add_child(_stats_column)

	_build_how_to_play_overlay()


func _make_panel_column(node_name: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = node_name
	column.theme_type_variation = UiTheme.vbox("XS")
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size = Vector2(PANEL_COLUMN_MIN_WIDTH_PX, 0.0)
	return column


func _build_how_to_play_overlay() -> void:
	_howto_root = Control.new()
	_howto_root.name = "HowToPlay"
	_howto_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_howto_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_howto_root.visible = false
	_root.add_child(_howto_root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_howto_root.add_child(center)

	var card := PanelContainer.new()
	card.theme_type_variation = UiTheme.CARD
	card.custom_minimum_size = Vector2(MenuFrame.CARD_MIN_WIDTH, 0.0)
	center.add_child(card)

	var column := VBoxContainer.new()
	column.theme_type_variation = UiTheme.vbox("L")
	card.add_child(column)

	MenuFrame.build_title(column, tr("PAUSE_MENU_HOW_TO_PLAY"), UiTheme.HEADING, 320.0)
	MenuFrame.build_separator(column)
	_howto_scroll = HowToPlay.build_content(column, 520.0)

	_howto_bar = PausedChoiceBar.new()
	_howto_bar.name = "HowToBar"
	_howto_bar.set_options([tr("HOWTO_BACK")])
	_howto_bar.option_confirmed.connect(_on_howto_confirmed)
	column.add_child(_howto_bar)
	MenuFrame.style_choice_labels(_howto_bar)

	var footer: VBoxContainer = MenuFrame.build_hold_footer(column)
	MenuFrame.build_highlight_row(footer, _howto_bar)
	_howto_ring = DraftFillRing.new()
	_howto_ring.name = "HowToRing"
	_howto_ring.custom_minimum_size = Vector2(48, 48)
	MenuFrame.style_fill_ring(_howto_ring)
	footer.add_child(_howto_ring)
	_howto_bar.set_fill_ring(_howto_ring)
