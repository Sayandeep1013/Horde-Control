extends SceneTree

## Settings check (Acceptance Test Matrix > Build Checks, first task P0.2).
##
## Scripted project audit: asserts the pinned engine version, the 16 collision
## layer names from docs/20, the full input map from docs/19 including the
## number keys 1-7 and the D78 debug toggles, and the presence of the pinned
## 4.7.1 export templates. Exits 0 on pass, 1 on failure, so it can gate CI.

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

var _failures: Array[String] = []

func _fail(msg: String) -> void:
	_failures.append(msg)

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

	# 2. The 16 collision layer names, in order (docs/20 binding table).
	for i in LAYERS.size():
		var key := "layer_names/2d_physics/layer_%d" % (i + 1)
		var got := str(ProjectSettings.get_setting(key, ""))
		if got != LAYERS[i]:
			_fail("%s is '%s', expected '%s'" % [key, got, LAYERS[i]])

	# 3. Input map (docs/19 > Input Map, plus D78 debug toggles).
	for a in ACTIONS:
		var setting: String = "input/" + str(a)
		if not ProjectSettings.has_setting(setting):
			_fail("input action missing: %s" % a)
		else:
			var events: Array = ProjectSettings.get_setting(setting).get("events", [])
			if events.is_empty():
				_fail("input action has no bindings: %s" % a)

	# 4. Pinned 4.7.1 export templates present.
	var tpl := OS.get_data_dir().path_join("Godot/export_templates/4.7.1.stable/version.txt")
	if not FileAccess.file_exists(tpl):
		_fail("export templates not found at %s" % tpl)
	else:
		var stamp := FileAccess.get_file_as_string(tpl).strip_edges()
		if stamp != "4.7.1.stable":
			_fail("export templates report '%s', expected '4.7.1.stable'" % stamp)

	if _failures.is_empty():
		print("Settings check: PASS (%d layers, %d actions, templates 4.7.1.stable)" % [LAYERS.size(), ACTIONS.size()])
		quit(0)
	else:
		for f in _failures:
			printerr("Settings check FAILURE: %s" % f)
		printerr("Settings check: FAIL (%d problems)" % _failures.size())
		quit(1)
