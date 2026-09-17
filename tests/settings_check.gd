extends SceneTree

## Settings check (Acceptance Test Matrix > Build Checks, first task P0.2).
##
## Scripted project audit. Asserts, against recorded EFFECTIVE values (Godot
## 4.7.1 strips default-valued keys from project.godot on save, so a key's
## absence from the file does not mean it is unpinned):
## 1. the engine version and the recorded config/features array, by full
##    equality (renderer included), not by containment (docs/20 > Version);
## 2. the pinned display/physics project settings (docs/20 > Project
##    Settings (pinned)): viewport width/height, stretch mode, stretch
##    aspect, physics ticks per second, max physics steps per frame,
##    physics interpolation, vsync mode;
## 3. run/main_scene equals the recorded entry scene AND that scene file
##    actually exists on disk;
## 4. the 16 collision layer names, in order (docs/20 binding table);
## 5. the EXACT SET of input/* keys ProjectSettings actually carries --
##    every project action present and nothing else beyond the engine's own
##    built-in ui_* actions -- and, for every project action, its exact
##    expected event set (physical keycodes, joypad button indices, joypad
##    axes with magnitude, mouse buttons, and key/mouse modifiers including
##    meta) plus its deadzone, not merely that some binding exists
##    (docs/19 > Input Map, plus the F1/F2 debug toggles);
## 6. the EXACT SET of autoload/* keys ProjectSettings actually carries --
##    only autoload/BootCheck, nothing else -- and that it points at
##    res://src/core/boot_check.gd;
## 7. the pinned 4.7.1 export templates are present.
## Exits 0 on pass, 1 on failure, so it can gate CI.

const LAYERS := [
	"PlayerBody", "EnemyBody", "TowerBody", "World",
	"PlayerProjectile", "TowerProjectile", "EnemyProjectile",
	"PlayerHurtbox", "EnemyHurtbox", "TowerHurtbox", "EnemyHitbox",
	"Pickup", "Hazard", "InteractionRadius", "ArenaBounds", "PlayerCollector",
]

const ACTIONS := [
	"move_up", "move_down", "move_left", "move_right",
	"draft_cycle_left", "draft_cycle_right",
	"draft_select_1", "draft_select_2", "draft_select_3",
	"confirm", "reroll",
	"console_cycle_next", "console_cycle_prev",
	"console_select_1", "console_select_2", "console_select_3", "console_select_4",
	"console_select_5", "console_select_6", "console_select_7",
	"console_cancel", "pause",
	"debug_overlay_toggle", "debug_pseudoloc_toggle",
]

# Every input/* key Godot 4.7.1 itself registers with no project action of
# ours behind it (captured by enumerating ProjectSettings.get_property_list()
# on the pinned 4.7.1 engine against this project's own real, reviewed
# project.godot). These are reserved by the engine, not by this project, so
# the exact-set check below allows them without requiring this script to
# restate every one of Godot's own default bindings. Anything under input/*
# that is neither in ACTIONS nor in this list is unexpected and fails.
const BUILTIN_UI_ACTIONS := [
	"ui_accept", "ui_accessibility_drag_and_drop", "ui_cancel", "ui_close_dialog",
	"ui_close_dialog.macos", "ui_colorpicker_delete_preset", "ui_copy", "ui_cut",
	"ui_down", "ui_end", "ui_filedialog_delete", "ui_filedialog_find",
	"ui_filedialog_focus_path", "ui_filedialog_focus_path.macos", "ui_filedialog_refresh", "ui_filedialog_show_hidden",
	"ui_filedialog_up_one_level", "ui_focus_mode", "ui_focus_next", "ui_focus_prev",
	"ui_graph_delete", "ui_graph_duplicate", "ui_graph_follow_left", "ui_graph_follow_left.macos",
	"ui_graph_follow_right", "ui_graph_follow_right.macos", "ui_home", "ui_left",
	"ui_menu", "ui_page_down", "ui_page_up", "ui_paste",
	"ui_redo", "ui_right", "ui_select", "ui_swap_input_direction",
	"ui_text_add_selection_for_next_occurrence", "ui_text_backspace", "ui_text_backspace_all_to_left", "ui_text_backspace_all_to_left.macos",
	"ui_text_backspace_word", "ui_text_backspace_word.macos", "ui_text_caret_add_above", "ui_text_caret_add_above.macos",
	"ui_text_caret_add_below", "ui_text_caret_add_below.macos", "ui_text_caret_document_end", "ui_text_caret_document_end.macos",
	"ui_text_caret_document_start", "ui_text_caret_document_start.macos", "ui_text_caret_down", "ui_text_caret_left",
	"ui_text_caret_line_end", "ui_text_caret_line_end.macos", "ui_text_caret_line_start", "ui_text_caret_line_start.macos",
	"ui_text_caret_page_down", "ui_text_caret_page_up", "ui_text_caret_right", "ui_text_caret_up",
	"ui_text_caret_word_left", "ui_text_caret_word_left.macos", "ui_text_caret_word_right", "ui_text_caret_word_right.macos",
	"ui_text_clear_carets_and_selection", "ui_text_completion_accept", "ui_text_completion_query", "ui_text_completion_replace",
	"ui_text_dedent", "ui_text_delete", "ui_text_delete_all_to_right", "ui_text_delete_all_to_right.macos",
	"ui_text_delete_word", "ui_text_delete_word.macos", "ui_text_indent", "ui_text_newline",
	"ui_text_newline_above", "ui_text_newline_blank", "ui_text_scroll_down", "ui_text_scroll_down.macos",
	"ui_text_scroll_up", "ui_text_scroll_up.macos", "ui_text_select_all", "ui_text_select_word_under_caret",
	"ui_text_select_word_under_caret.macos", "ui_text_skip_selection_for_next_occurrence", "ui_text_submit", "ui_text_toggle_insert_mode",
	"ui_undo", "ui_unicode_start", "ui_up",
]

# The only autoload this project defines (docs/20 > Godot 4.x Implementation
# Standards). Unlike input/*, ProjectSettings carries no engine-reserved
# autoload/* keys, so this set is asserted with no allowance list.
const AUTOLOADS := ["BootCheck"]

# Project Settings (pinned) (docs/20). "default" is the Godot 4.7.1 engine
# default, used only as a get_setting() fallback; "expected" is the pinned
# value from docs/20. These values must not be restated anywhere else in
# this script.
const PINNED_SETTINGS := [
	{"key": "display/window/size/viewport_width", "default": 1152, "expected": 1920},
	{"key": "display/window/size/viewport_height", "default": 648, "expected": 1080},
	{"key": "display/window/stretch/mode", "default": "disabled", "expected": "canvas_items"},
	{"key": "display/window/stretch/aspect", "default": "keep", "expected": "keep"},
	{"key": "physics/common/physics_ticks_per_second", "default": 60, "expected": 60},
	{"key": "physics/common/max_physics_steps_per_frame", "default": 8, "expected": 8},
	{"key": "physics/common/physics_interpolation", "default": false, "expected": false},
	{"key": "display/window/vsync/vsync_mode", "default": 1, "expected": 1},
]

const BOOTCHECK_PATH := "res://src/core/boot_check.gd"

# The project's recorded entry scene (Phase 00 P0.2 execution log, which
# records what was created to satisfy docs/20's project-skeleton pin); the
# only .tscn under scenes/ that is the game's entry point.
const MAIN_SCENE_PATH := "res://scenes/main.tscn"

# config/features (docs/20 > Version: "project.godot itself records only
# 4.7", not 4.4 -- Phase 00 finding F-03 -- carried alongside the project's
# actual renderer, Forward Plus, per the Phase 00 P0.2 execution log). This
# is the FULL expected array; checked by equality so a stray "4.4" landing
# alongside "4.7", or "Forward Plus" silently dropping, both fail.
const FEATURES_EXPECTED := ["4.7", "Forward Plus"]

# Every action in ACTIONS is pinned at Godot's own default deadzone (0.2),
# unchanged since action creation. Neither docs/19 nor docs/20 pins a
# different per-action deadzone, so this asserts that no deadzone drifted
# away from that unmodified default, rather than inventing a new number.
const EXPECTED_DEADZONE := 0.2

# Each action's exact expected event set (docs/19 > Input Map, plus the
# F1/F2 debug toggles), as signatures matching _event_signature()'s format.
# A rebind, a dropped binding, an added binding, or a modifier change
# (including Meta) changes this set.
const ACTION_EVENTS := {
	"move_up": ["key:87:0:0:0:0", "key:4194320:0:0:0:0", "joyaxis:1:-1.00"],
	"move_down": ["key:83:0:0:0:0", "key:4194322:0:0:0:0", "joyaxis:1:1.00"],
	"move_left": ["key:65:0:0:0:0", "key:4194319:0:0:0:0", "joyaxis:0:-1.00"],
	"move_right": ["key:68:0:0:0:0", "key:4194321:0:0:0:0", "joyaxis:0:1.00"],
	"draft_cycle_left": ["key:65:0:0:0:0", "key:4194319:0:0:0:0", "joybutton:13", "joyaxis:0:-1.00"],
	"draft_cycle_right": ["key:68:0:0:0:0", "key:4194321:0:0:0:0", "joybutton:14", "joyaxis:0:1.00"],
	"draft_select_1": ["key:49:0:0:0:0"],
	"draft_select_2": ["key:50:0:0:0:0"],
	"draft_select_3": ["key:51:0:0:0:0"],
	"confirm": ["key:32:0:0:0:0", "key:4194309:0:0:0:0", "mouse:1:0:0:0:0", "joybutton:0"],
	"reroll": ["key:82:0:0:0:0", "joybutton:2"],
	"console_cycle_next": ["key:4194306:0:0:0:0", "mouse:5:0:0:0:0", "joybutton:12", "joyaxis:3:1.00"],
	"console_cycle_prev": ["key:4194306:1:0:0:0", "mouse:4:0:0:0:0", "joybutton:11", "joyaxis:3:-1.00"],
	"console_select_1": ["key:49:0:0:0:0"],
	"console_select_2": ["key:50:0:0:0:0"],
	"console_select_3": ["key:51:0:0:0:0"],
	"console_select_4": ["key:52:0:0:0:0"],
	"console_select_5": ["key:53:0:0:0:0"],
	"console_select_6": ["key:54:0:0:0:0"],
	"console_select_7": ["key:55:0:0:0:0"],
	"console_cancel": ["key:81:0:0:0:0", "joybutton:1"],
	"pause": ["key:4194305:0:0:0:0", "joybutton:6"],
	"debug_overlay_toggle": ["key:4194332:0:0:0:0"],
	"debug_pseudoloc_toggle": ["key:4194333:0:0:0:0"],
}

var _failures: Array[String] = []

func _fail(msg: String) -> void:
	_failures.append(msg)

# Canonical signature for one InputEvent: which physical key (plus every
# modifier, including Meta), joypad button, joypad axis (with signed
# magnitude, not merely its sign), or mouse button (plus its modifiers) it
# is. Two events with the same signature are the same binding.
func _event_signature(event: InputEvent) -> String:
	if event is InputEventKey:
		var k := event as InputEventKey
		var code: int = int(k.physical_keycode) if k.physical_keycode != 0 else int(k.keycode)
		return "key:%d:%d:%d:%d:%d" % [code, int(k.shift_pressed), int(k.ctrl_pressed), int(k.alt_pressed), int(k.meta_pressed)]
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		return "joybutton:%d" % int(jb.button_index)
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		return "joyaxis:%d:%.2f" % [int(jm.axis), jm.axis_value]
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return "mouse:%d:%d:%d:%d:%d" % [int(mb.button_index), int(mb.shift_pressed), int(mb.ctrl_pressed), int(mb.alt_pressed), int(mb.meta_pressed)]
	return "unknown:%s" % event.get_class()

# Returns every ProjectSettings property name that starts with prefix, with
# the prefix stripped, by walking get_property_list() -- the full recorded
# set, not just the keys this script already knows to look for.
func _keys_with_prefix(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for p in ProjectSettings.get_property_list():
		var full_name: String = str(p.get("name", ""))
		if full_name.begins_with(prefix):
			result.append(full_name.substr(prefix.length()))
	return result

# Set comparison: everything in actual that is not in allowed is "extra";
# everything in required that is not in actual is "missing". allowed must be
# a superset of required. Both returned lists are sorted for a stable,
# readable failure message.
func _extra_and_missing(actual: Array, allowed: Array, required: Array) -> Dictionary:
	var extra: Array[String] = []
	var missing: Array[String] = []
	for a in actual:
		if not allowed.has(a):
			extra.append(str(a))
	for r in required:
		if not actual.has(r):
			missing.append(str(r))
	extra.sort()
	missing.sort()
	return {"extra": extra, "missing": missing}

func _init() -> void:
	# 1. Engine version pin (docs/20 > Version).
	var v := Engine.get_version_info()
	if not (v.major == 4 and v.minor == 7 and v.patch == 1):
		_fail("engine is %d.%d.%d, document 20 pins 4.7.1" % [v.major, v.minor, v.patch])

	# 1b. project.godot must RECORD 4.7, not just run on it, AND must record
	# the full expected features array -- by equality, not containment. The
	# MCP generator writes 4.4 regardless of the running engine (Phase 00
	# finding F-03), so a stray "4.4" alongside "4.7" must fail even though
	# "4.7" is present, and a dropped renderer entry must fail too.
	var feats: PackedStringArray = ProjectSettings.get_setting("application/config/features", PackedStringArray())
	var feats_sorted: Array = Array(feats)
	feats_sorted.sort()
	var expected_features_sorted: Array = FEATURES_EXPECTED.duplicate()
	expected_features_sorted.sort()
	if feats_sorted != expected_features_sorted:
		_fail("project.godot records features %s, expected exactly %s" % [str(feats), str(FEATURES_EXPECTED)])

	# 2. Pinned project settings (docs/20 > Project Settings (pinned)), read as
	# EFFECTIVE values: a key stripped from project.godot because it equals
	# the Godot default must still be caught if the pinned value differs
	# from that default (for example viewport size or stretch mode).
	for entry in PINNED_SETTINGS:
		var key: String = entry["key"]
		var expected: Variant = entry["expected"]
		var default: Variant = entry["default"]
		var got: Variant = ProjectSettings.get_setting(key, default)
		if got != expected:
			_fail("%s is %s, docs/20 pins %s" % [key, str(got), str(expected)])

	# 3. run/main_scene must equal the recorded entry scene, AND that scene
	# file must actually exist -- a correct-looking path to a deleted or
	# renamed file is still a failure.
	var got_main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if got_main_scene != MAIN_SCENE_PATH:
		_fail("run/main_scene is '%s', expected '%s'" % [got_main_scene, MAIN_SCENE_PATH])
	if not FileAccess.file_exists(got_main_scene):
		_fail("run/main_scene '%s' does not exist on disk" % got_main_scene)

	# 4. The 16 collision layer names, in order (docs/20 binding table).
	for i in LAYERS.size():
		var layer_key := "layer_names/2d_physics/layer_%d" % (i + 1)
		var got_name := str(ProjectSettings.get_setting(layer_key, ""))
		if got_name != LAYERS[i]:
			_fail("%s is '%s', expected '%s'" % [layer_key, got_name, LAYERS[i]])

	# 5. Input map: the EXACT SET of input/* keys ProjectSettings carries --
	# every action in ACTIONS, nothing else beyond Godot's own built-in
	# ui_* actions -- so a rogue extra action is caught even though this
	# script never named it. Enumerated via get_property_list(), not by
	# probing only the keys this script already expects.
	var actual_input_names := _keys_with_prefix("input/")
	var allowed_input_names: Array = ACTIONS + BUILTIN_UI_ACTIONS
	var input_diff := _extra_and_missing(actual_input_names, allowed_input_names, ACTIONS)
	if not (input_diff["extra"] as Array).is_empty():
		_fail("unexpected input/* action(s) present: %s" % str(input_diff["extra"]))
	if not (input_diff["missing"] as Array).is_empty():
		_fail("expected input/* action(s) missing: %s" % str(input_diff["missing"]))

	# For every action ProjectSettings actually has, check its exact expected
	# event set, not just that some binding exists, so a rebind (move_up's W
	# becoming Z), a dropped/added binding, or a modifier change fails; and
	# check its deadzone, so a deadzone change (for example 0.2 to 0.95)
	# fails even though every event signature is untouched.
	for a in ACTIONS:
		var action_name: String = str(a)
		if not (actual_input_names as Array).has(action_name):
			continue # already reported as missing above
		var setting: String = "input/" + action_name
		var data: Dictionary = ProjectSettings.get_setting(setting)

		var deadzone: float = float(data.get("deadzone", -1.0))
		if not is_equal_approx(deadzone, EXPECTED_DEADZONE):
			_fail("%s deadzone is %s, expected %s" % [action_name, str(deadzone), str(EXPECTED_DEADZONE)])

		var events: Array = data.get("events", [])
		if events.is_empty():
			_fail("input action has no bindings: %s" % action_name)
			continue
		var got_sigs: Array[String] = []
		for e in events:
			var ev := e as InputEvent
			got_sigs.append(_event_signature(ev))
		got_sigs.sort()
		var raw_expected: Array = ACTION_EVENTS.get(action_name, [])
		var expected_sigs: Array[String] = []
		for s in raw_expected:
			expected_sigs.append(str(s))
		expected_sigs.sort()
		if got_sigs != expected_sigs:
			_fail("%s events are %s, docs/19 expects %s" % [action_name, str(got_sigs), str(expected_sigs)])

	# 6. autoload: the EXACT SET of autoload/* keys ProjectSettings carries
	# -- only BootCheck, nothing else -- so a rogue extra autoload is caught
	# even though this script never named it, then BootCheck's target path.
	var actual_autoload_names := _keys_with_prefix("autoload/")
	var autoload_diff := _extra_and_missing(actual_autoload_names, AUTOLOADS, AUTOLOADS)
	if not (autoload_diff["extra"] as Array).is_empty():
		_fail("unexpected autoload/* entry(ies) present: %s" % str(autoload_diff["extra"]))
	if not (autoload_diff["missing"] as Array).is_empty():
		_fail("expected autoload/* entry(ies) missing: %s" % str(autoload_diff["missing"]))
	if (actual_autoload_names as Array).has("BootCheck"):
		var raw_autoload: String = str(ProjectSettings.get_setting("autoload/BootCheck", ""))
		var autoload_path := raw_autoload.trim_prefix("*")
		if autoload_path != BOOTCHECK_PATH:
			_fail("autoload/BootCheck points at '%s', expected '%s'" % [autoload_path, BOOTCHECK_PATH])

	# 7. Pinned 4.7.1 export templates present.
	var tpl := OS.get_data_dir().path_join("Godot/export_templates/4.7.1.stable/version.txt")
	if not FileAccess.file_exists(tpl):
		_fail("export templates not found at %s" % tpl)
	else:
		var stamp := FileAccess.get_file_as_string(tpl).strip_edges()
		if stamp != "4.7.1.stable":
			_fail("export templates report '%s', expected '4.7.1.stable'" % stamp)

	if _failures.is_empty():
		print("Settings check: PASS (%d layers, %d actions, %d settings, templates 4.7.1.stable)" % [LAYERS.size(), ACTIONS.size(), PINNED_SETTINGS.size()])
		quit(0)
	else:
		for f in _failures:
			printerr("Settings check FAILURE: %s" % f)
		printerr("Settings check: FAIL (%d problems)" % _failures.size())
		quit(1)
