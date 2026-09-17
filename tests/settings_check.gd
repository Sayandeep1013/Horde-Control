extends SceneTree

## Settings check (Acceptance Test Matrix > Build Checks, first task P0.2).
##
## Scripted project audit. Asserts, against recorded EFFECTIVE values (Godot
## 4.7.1 strips default-valued keys from project.godot on save, so a key's
## absence from the file does not mean it is unpinned):
## 1. the engine version and the recorded config/features array (docs/20);
## 2. the pinned display/physics project settings (docs/20 > Project
##    Settings (pinned)): viewport width/height, stretch mode, stretch
##    aspect, physics ticks per second, max physics steps per frame,
##    physics interpolation, vsync mode;
## 3. the 16 collision layer names, in order (docs/20 binding table);
## 4. every input action's exact expected event set -- physical keycodes,
##    joypad button indices, joypad axes, mouse buttons, and key modifiers,
##    not merely that some binding exists (docs/19 > Input Map, plus the
##    F1/F2 debug toggles);
## 5. the autoload/BootCheck entry points at res://src/core/boot_check.gd;
## 6. the pinned 4.7.1 export templates are present.
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

# Each action's exact expected event set (docs/19 > Input Map, plus the
# F1/F2 debug toggles), as signatures matching _event_signature()'s format.
# A rebind, a dropped binding, or an added binding changes this set.
const ACTION_EVENTS := {
	"move_up": ["key:87:0:0:0", "key:4194320:0:0:0", "joyaxis:1:-"],
	"move_down": ["key:83:0:0:0", "key:4194322:0:0:0", "joyaxis:1:+"],
	"move_left": ["key:65:0:0:0", "key:4194319:0:0:0", "joyaxis:0:-"],
	"move_right": ["key:68:0:0:0", "key:4194321:0:0:0", "joyaxis:0:+"],
	"draft_cycle_left": ["key:65:0:0:0", "key:4194319:0:0:0", "joybutton:13", "joyaxis:0:-"],
	"draft_cycle_right": ["key:68:0:0:0", "key:4194321:0:0:0", "joybutton:14", "joyaxis:0:+"],
	"draft_select_1": ["key:49:0:0:0"],
	"draft_select_2": ["key:50:0:0:0"],
	"draft_select_3": ["key:51:0:0:0"],
	"confirm": ["key:32:0:0:0", "key:4194309:0:0:0", "mouse:1", "joybutton:0"],
	"reroll": ["key:82:0:0:0", "joybutton:2"],
	"console_cycle_next": ["key:4194306:0:0:0", "mouse:5", "joybutton:12", "joyaxis:3:+"],
	"console_cycle_prev": ["key:4194306:1:0:0", "mouse:4", "joybutton:11", "joyaxis:3:-"],
	"console_select_1": ["key:49:0:0:0"],
	"console_select_2": ["key:50:0:0:0"],
	"console_select_3": ["key:51:0:0:0"],
	"console_select_4": ["key:52:0:0:0"],
	"console_select_5": ["key:53:0:0:0"],
	"console_select_6": ["key:54:0:0:0"],
	"console_select_7": ["key:55:0:0:0"],
	"console_cancel": ["key:81:0:0:0", "joybutton:1"],
	"pause": ["key:4194305:0:0:0", "joybutton:6"],
	"debug_overlay_toggle": ["key:4194332:0:0:0"],
	"debug_pseudoloc_toggle": ["key:4194333:0:0:0"],
}

var _failures: Array[String] = []

func _fail(msg: String) -> void:
	_failures.append(msg)

# Canonical signature for one InputEvent: which physical key (plus
# modifiers), joypad button, joypad axis direction, or mouse button it is.
# Two events with the same signature are the same binding.
func _event_signature(event: InputEvent) -> String:
	if event is InputEventKey:
		var k := event as InputEventKey
		var code: int = int(k.physical_keycode) if k.physical_keycode != 0 else int(k.keycode)
		return "key:%d:%d:%d:%d" % [code, int(k.shift_pressed), int(k.ctrl_pressed), int(k.alt_pressed)]
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		return "joybutton:%d" % int(jb.button_index)
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		var sign_str: String = "+" if jm.axis_value >= 0.0 else "-"
		return "joyaxis:%d:%s" % [int(jm.axis), sign_str]
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return "mouse:%d" % int(mb.button_index)
	return "unknown:%s" % event.get_class()

func _init() -> void:
	# 1. Engine version pin (docs/20 > Version).
	var v := Engine.get_version_info()
	if not (v.major == 4 and v.minor == 7 and v.patch == 1):
		_fail("engine is %d.%d.%d, document 20 pins 4.7.1" % [v.major, v.minor, v.patch])

	# 1b. project.godot must RECORD 4.7, not just run on it. The MCP generator
	# writes 4.4 regardless of the running engine (Phase 00 finding F-03), so this
	# asserts the recorded value rather than trusting the tool that wrote it.
	var feats: PackedStringArray = ProjectSettings.get_setting("application/config/features", PackedStringArray())
	if not feats.has("4.7"):
		_fail("project.godot records features %s, expected to contain 4.7" % str(feats))

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

	# 3. The 16 collision layer names, in order (docs/20 binding table).
	for i in LAYERS.size():
		var layer_key := "layer_names/2d_physics/layer_%d" % (i + 1)
		var got_name := str(ProjectSettings.get_setting(layer_key, ""))
		if got_name != LAYERS[i]:
			_fail("%s is '%s', expected '%s'" % [layer_key, got_name, LAYERS[i]])

	# 4. Input map (docs/19 > Input Map, plus the F1/F2 debug toggles): each
	# action's exact expected event set, not just that some binding exists,
	# so a rebind (move_up's W becoming Z) or a dropped/added binding fails.
	for a in ACTIONS:
		var action_name: String = str(a)
		var setting: String = "input/" + action_name
		if not ProjectSettings.has_setting(setting):
			_fail("input action missing: %s" % action_name)
			continue
		var data: Dictionary = ProjectSettings.get_setting(setting)
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

	# 5. autoload/BootCheck must point at the script that carries the 4.7.1
	# pin into the exported build; deleting the autoload must fail this.
	if not ProjectSettings.has_setting("autoload/BootCheck"):
		_fail("autoload/BootCheck is missing, expected to point at %s" % BOOTCHECK_PATH)
	else:
		var raw_autoload: String = str(ProjectSettings.get_setting("autoload/BootCheck", ""))
		var autoload_path := raw_autoload.trim_prefix("*")
		if autoload_path != BOOTCHECK_PATH:
			_fail("autoload/BootCheck points at '%s', expected '%s'" % [autoload_path, BOOTCHECK_PATH])

	# 6. Pinned 4.7.1 export templates present.
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
