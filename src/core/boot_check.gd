extends Node

## Boot check required by docs/20_Technical_Architecture.md (Godot 4.x
## Implementation Standards > Version): project.godot records engine version
## 4.7 only, so this autoload asserts the running engine is exactly 4.7.1.
##
## The pin exists because the MCP tooling and the export templates are pinned to
## 4.7.1; a silent minor-version drift would change physics and rendering
## behaviour underneath every acceptance test. Change the pin only through
## document 20.

const REQUIRED_MAJOR := 4
const REQUIRED_MINOR := 7
const REQUIRED_PATCH := 1


func _ready() -> void:
	var info: Dictionary = Engine.get_version_info()
	var running := "%d.%d.%d" % [info.major, info.minor, info.patch]
	var required := "%d.%d.%d" % [REQUIRED_MAJOR, REQUIRED_MINOR, REQUIRED_PATCH]

	if info.major != REQUIRED_MAJOR or info.minor != REQUIRED_MINOR or info.patch != REQUIRED_PATCH:
		push_error(
			"Engine version mismatch: running %s, document 20 pins %s. " % [running, required]
			+ "Fix the engine or change the pin through document 20 - do not ignore this."
		)
	else:
		print("Boot check: Godot %s matches the pin in document 20." % running)
